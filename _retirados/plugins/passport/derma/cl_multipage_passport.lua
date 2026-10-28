-- cl_multipage_passport.lua
-- Multi-page passport viewer with station stamping support
-- Supports unlimited pages with station entry/exit records

local PLUGIN = PLUGIN or {}

local FONT_PASSPORT = "ixPassportFont"
local FONT_UI = "ixPassportUI"

-- Helper functions for material loading (copied from inspection desk)
local materialCache = {}

local function getMaterial(path)
  if not materialCache[path] then
    -- Try different material parameters for better compatibility
    local mat = Material(path, "smooth noclamp")
    
    -- Check if material is valid
    if not mat or mat:IsError() then
      -- Try with different parameters
      mat = Material(path, "smooth")
      if not mat or mat:IsError() then
        -- Try without parameters
        mat = Material(path)
        if not mat or mat:IsError() then
          print("[ERROR] Failed to load material: " .. tostring(path))
          return nil
        end
      end
    end
    
    materialCache[path] = mat
  end
  return materialCache[path]
end

local function normStampPath(name)
  name = tostring(name or "")
  if name == "" then return "" end
  if name:find("/") then return name end
  return "metro/stamp/" .. name
end

---------------------------------------------------------
-- Multi-Page Passport Viewer Panel
---------------------------------------------------------
local PANEL = {}

function PANEL:Init()
    self:SetTitle("Pasaporte Multi-Página")
    self:SetSize(900, 650)
    self:Center()
    self:MakePopup()
    
    -- Data storage
    self.PassportData = {}
    self.Pages = {}
    self.CurrentPage = 1
    
    -- Main layout
    self:CreateLayout()
end

function PANEL:CreateLayout()
    -- Top navigation bar
    self.NavBar = self:Add("DPanel")
    self.NavBar:Dock(TOP)
    self.NavBar:SetTall(50)
    self.NavBar.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(40, 38, 36, 240))
        surface.SetDrawColor(255, 255, 255, 30)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    -- Page navigation buttons
    self.PrevBtn = self.NavBar:Add("DButton")
    self.PrevBtn:SetText("← Página Anterior")
    self.PrevBtn:SetFont(FONT_UI)
    self.PrevBtn:SetSize(150, 30)
    self.PrevBtn:SetPos(10, 10)
    self.PrevBtn.DoClick = function()
        if self.CurrentPage > 1 then
            self.CurrentPage = self.CurrentPage - 1
            self:UpdatePageDisplay()
        end
    end
    
    self.NextBtn = self.NavBar:Add("DButton")
    self.NextBtn:SetText("Siguiente Página →")
    self.NextBtn:SetFont(FONT_UI)
    self.NextBtn:SetSize(150, 30)
    self.NextBtn:SetPos(170, 10)
    self.NextBtn.DoClick = function()
        self.CurrentPage = self.CurrentPage + 1
        self:UpdatePageDisplay()
    end
    
    -- Page counter
    self.PageLabel = self.NavBar:Add("DLabel")
    self.PageLabel:SetFont(FONT_UI)
    self.PageLabel:SetColor(color_white)
    self.PageLabel:SetText("Página 1 de 1")
    self.PageLabel:SizeToContents()
    self.PageLabel:SetPos(350, 15)
    
    -- Add new page button
    self.AddPageBtn = self.NavBar:Add("DButton")
    self.AddPageBtn:SetText("+ Añadir Página")
    self.AddPageBtn:SetFont(FONT_UI)
    self.AddPageBtn:SetSize(120, 30)
    self.AddPageBtn:SetPos(500, 10)
    self.AddPageBtn.DoClick = function()
        self:AddNewPage()
    end
    
    -- Station stamping controls
    self.StationPanel = self.NavBar:Add("DPanel")
    self.StationPanel:SetSize(250, 35)
    self.StationPanel:SetPos(630, 7)
    self.StationPanel.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 50, 40, 200))
    end
    
    self.StationEntry = self.StationPanel:Add("DTextEntry")
    self.StationEntry:SetFont(FONT_UI)
    self.StationEntry:SetSize(150, 25)
    self.StationEntry:SetPos(5, 5)
    self.StationEntry:SetPlaceholderText("Nombre estación...")
    
    self.StampBtn = self.StationPanel:Add("DButton")
    self.StampBtn:SetText("Sellar")
    self.StampBtn:SetFont(FONT_UI)
    self.StampBtn:SetSize(60, 25)
    self.StampBtn:SetPos(160, 5)
    self.StampBtn.DoClick = function()
        self:AddStationStamp()
    end
    
    -- Main content area
    self.ContentPanel = self:Add("DPanel")
    self.ContentPanel:Dock(FILL)
    self.ContentPanel:DockMargin(0, 5, 0, 0)
    
    self.ContentPanel.Paint = function(_, w, h)
        -- Paper texture background
        surface.SetDrawColor(245, 240, 230)
        surface.DrawRect(0, 0, w, h)
        
        -- Subtle border
        surface.SetDrawColor(180, 170, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
    
    -- Passport display area
    self.PassportDisplay = self.ContentPanel:Add("DPanel")
    self.PassportDisplay:Dock(FILL)
    self.PassportDisplay:DockMargin(20, 20, 20, 20)
    
    self.PassportDisplay.Paint = function(_, w, h)
        self:DrawPassportPage(w, h)
    end
end

function PANEL:SetPassportData(data)
    self.PassportData = data or {}
    
    -- Initialize pages if they don't exist
    if not self.PassportData.pages or #self.PassportData.pages == 0 then
        self.PassportData.pages = {
            {
                pageNumber = 1,
                stationStamps = {},
                notes = ""
            }
        }
    end
    
    self.Pages = self.PassportData.pages
    self.CurrentPage = 1
    self:UpdatePageDisplay()
end

function PANEL:AddNewPage()
    local newPage = {
        pageNumber = #self.Pages + 1,
        stationStamps = {},
        notes = ""
    }
    
    table.insert(self.Pages, newPage)
    self.CurrentPage = #self.Pages
    self:UpdatePageDisplay()
    
    -- Save to server
    self:SavePagesToServer()
end

function PANEL:AddStationStamp()
    local stationName = string.Trim(self.StationEntry:GetText() or "")
    if stationName == "" then
        chat.AddText(Color(220, 120, 120), "[Pasaporte] ", color_white, "Debes ingresar el nombre de la estación.")
        return
    end
    
    if not self.ItemID then
        chat.AddText(Color(220, 120, 120), "[Pasaporte] ", color_white, "Error: ID de pasaporte no válido.")
        return
    end
    
    -- Send to server
    net.Start("ix.pp.AddStationStamp")
        net.WriteUInt(self.ItemID, 32)
        net.WriteString(stationName)
        net.WriteString("entry") -- Default stamp type
        net.WriteUInt(self.CurrentPage, 8)
    net.SendToServer()
    
    -- Clear input
    self.StationEntry:SetText("")
end

function PANEL:UpdatePageDisplay()
    local totalPages = #self.Pages
    self.CurrentPage = math.Clamp(self.CurrentPage, 1, totalPages)
    
    -- Update navigation
    self.PrevBtn:SetEnabled(self.CurrentPage > 1)
    self.NextBtn:SetEnabled(self.CurrentPage < totalPages)
    
    -- Update page label
    self.PageLabel:SetText(string.format("Página %d de %d", self.CurrentPage, totalPages))
    
    -- Update station panel
    self.StationPanel:SetVisible(self.CurrentPage > 1) -- Only allow stamping on pages after the first
    
    -- Refresh display
    self.PassportDisplay:InvalidateLayout()
end

function PANEL:DrawPassportPage(w, h)
    if not self.Pages or #self.Pages == 0 then return end
    
    local currentPage = self.Pages[self.CurrentPage]
    if not currentPage then return end
    
    -- Draw passport background for page 1
    if currentPage.pageNumber == 1 then
        self:DrawMainPassportPage(w, h)
    else
        self:DrawStationPage(w, h, currentPage)
    end
end

function PANEL:DrawMainPassportPage(w, h)
    -- Draw passport template
    local passportTemplateMat = Material(PLUGIN.PassportTemplate or "metro/pasport.png", "smooth")
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(passportTemplateMat)
    surface.DrawTexturedRect(0, 0, w, h)
    
    -- Draw passport fields
    surface.SetFont(FONT_PASSPORT)
    surface.SetTextColor(40, 30, 10, 255)
    
    for _, field in ipairs(PLUGIN.PassportFields or {}) do
        local x = field.x * w / PLUGIN.PassportBaseW
        local y = field.y * h / PLUGIN.PassportBaseH
        
        surface.SetTextPos(x, y)
        surface.DrawText(self.PassportData.fields and self.PassportData.fields[field.key] or "")
    end
    
    -- Draw main stamp if exists
    if self.PassportData.stamp and self.PassportData.stamp ~= "" then
        local r = PLUGIN.PassportStampRect
        surface.SetMaterial(Material(self.PassportData.stamp, "smooth"))
        surface.SetDrawColor(255, 255, 255, 230)
        surface.DrawTexturedRect(
            r.x * w / PLUGIN.PassportBaseW,
            r.y * h / PLUGIN.PassportBaseH,
            r.w * w / PLUGIN.PassportBaseW,
            r.h * h / PLUGIN.PassportBaseH
        )
    end
end

function PANEL:DrawStationPage(w, h, pageData)
    -- Page header
    surface.SetFont(FONT_PASSPORT)
    surface.SetTextColor(40, 30, 10, 255)
    
    local headerText = string.format("REGISTRO DE VIAJES - PÁGINA %d", pageData.pageNumber)
    local headerWidth = surface.GetTextSize(headerText)
    surface.SetTextPos((w - headerWidth) / 2, 30)
    surface.DrawText(headerText)
    
    -- Draw station stamps
    if pageData.stationStamps and #pageData.stationStamps > 0 then
        local yPos = 80
        surface.SetFont(FONT_UI)
        
        for _, stamp in ipairs(pageData.stationStamps) do
            -- Station name
            surface.SetTextColor(20, 20, 20, 255)
            surface.SetTextPos(50, yPos)
            surface.DrawText(string.format("Estación: %s", stamp.stationName))
            
            -- Date and time
            local dateStr = os.date("%d/%m/%Y %H:%M", stamp.timestamp)
            surface.SetTextPos(50, yPos + 25)
            surface.DrawText(string.format("Fecha: %s", dateStr))
            
            -- Stamped by
            surface.SetTextPos(50, yPos + 50)
            surface.DrawText(string.format("Sellado por: %s", stamp.stampedBy or "Sistema"))
            
            -- Type
            surface.SetTextPos(50, yPos + 75)
            surface.DrawText(string.format("Tipo: %s", stamp.stampType == "entry" and "ENTRADA" or "SALIDA"))
            
            -- Sello visual: sello de la facción que selló (stampImage); si no, genérico.
            local stampRel = stamp.stampImage
            if (not stampRel or stampRel == "") then
                stampRel = (stamp.stampType == "deny") and "Denegado.png" or "Aprobado.png"
            end

            local stampMat = getMaterial(normStampPath(stampRel))
            local sw, sh = 96, 96
            local stampX = math.min(280, w - sw - 20)
            local stampY = yPos - 5
            if stampMat then
                surface.SetMaterial(stampMat)
                surface.SetDrawColor(255, 255, 255, 230)
                surface.DrawTexturedRect(stampX, stampY, sw, sh)
            else
                surface.SetDrawColor(255, 100, 100, 180)
                surface.DrawRect(stampX, stampY, sw, sh)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawOutlinedRect(stampX, stampY, sw, sh, 2)
            end
            
            yPos = yPos + 110
        end
    else
        -- No stamps message
        surface.SetTextColor(150, 150, 150, 255)
        local noStampsText = "No hay sellos de estación en esta página"
        local textWidth = surface.GetTextSize(noStampsText)
        surface.SetTextPos((w - textWidth) / 2, h / 2)
        surface.DrawText(noStampsText)
    end
    
    -- Draw notes if exist
    if pageData.notes and pageData.notes ~= "" then
        surface.SetFont(FONT_UI)
        surface.SetTextColor(60, 60, 60, 255)
        surface.SetTextPos(50, h - 60)
        surface.DrawText("Notas: " .. pageData.notes)
    end
end

function PANEL:SavePagesToServer()
    if not self.ItemID then return end
    
    -- Update local data
    self.PassportData.pages = self.Pages
    
    -- This would typically sync with the server
    -- For now, the server handles the data persistence
end

function PANEL:SetItemID(itemID)
    self.ItemID = itemID
end

-- Register the panel
vgui.Register("ixMultiPagePassport", PANEL, "DFrame")

---------------------------------------------------------
-- Client-side network handlers
---------------------------------------------------------
net.Receive("ix.pp.StationStampResult", function()
    local ok = net.ReadBool()
    local msg = net.ReadString() or ""
    
    chat.AddText(
        ok and Color(120, 200, 120) or Color(220, 120, 120),
        "[Pasaporte] ",
        color_white,
        msg
    )
    
    -- Refresh the current passport viewer if it exists
    for _, v in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if IsValid(v) and (v.ClassName == "ixMultiPagePassport" or v:GetClassName() == "ixMultiPagePassport") then
            -- Request updated pages
            if v.ItemID then
                net.Start("ix.pp.GetPassportPages")
                    net.WriteUInt(v.ItemID, 32)
                net.SendToServer()
            end
            break
        end
    end
end)

net.Receive("ix.pp.PassportPagesData", function()
    local pages = net.ReadTable() or {}
    
    -- Update any open passport viewers
    for _, v in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if IsValid(v) and (v.ClassName == "ixMultiPagePassport" or v:GetClassName() == "ixMultiPagePassport") then
            v.Pages = pages
            v.PassportData.pages = pages
            v:UpdatePageDisplay()
            break
        end
    end
end)

---------------------------------------------------------
-- Helper function to open multi-page passport
---------------------------------------------------------
function PLUGIN:OpenMultiPagePassport(itemID, passportData)
    local frame = vgui.Create("ixMultiPagePassport")
    if IsValid(frame) then
        frame:SetItemID(itemID)
        frame:SetPassportData(passportData)
    end
    return frame
end
