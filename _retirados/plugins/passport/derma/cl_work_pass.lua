local PLUGIN = PLUGIN

-- ======== VIEWER ========
local VW = {}
function VW:Init()
    self:SetTitle("Pase de Trabajo")
    self:SetSize(520, 420)
    self:Center()
    self:MakePopup()

    self.body = self:Add("DScrollPanel")
    self.body:Dock(FILL)

    self.labels = {}
    local function addLine(label, value)
        local L = self.body:Add("DLabel")
        L:Dock(TOP)
        L:SetFont("ixPassportUI")
        L:SetText(label .. ": " .. (value or "—"))
        L:DockMargin(0, 2, 0, 0)
        self.labels[#self.labels+1] = L
    end

    addLine("Titular", "")
    addLine("Empleador", "")
    addLine("Puesto", "")
    addLine("Emitido", "")
    addLine("Caduca", "")
end

function VW:SetWorkPassData(d)
    d = d or {}
    local lines = {
        d.holderName or "—",
        d.employer or "—",
        d.occupation or "—",
        d.issuedWhen and os.date("%d/%m/%Y", d.issuedWhen) or "—",
        d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—",
    }
    for i, L in ipairs(self.labels or {}) do
        local base = L:GetText():match("^(.-):")
        L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
    end
end

local function regWorkViewer()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixWorkPassViewer", VW, "ixFrame")
    else
        vgui.Register("ixWorkPassViewer", VW, "DFrame")
    end
end
timer.Simple(0, regWorkViewer)
hook.Add("LoadedLocalSchema", "pp_register_workpass_viewer", regWorkViewer)

-- ======== EDITOR ========
local EW = {}
function EW:Init()
    self:SetTitle("Editar Pase de Trabajo")
    self:SetSize(600, 420)
    self:Center()
    self:MakePopup()

    self.itemID = 0
    local panel = self

    local sp = self:Add("DScrollPanel")
    sp:Dock(FILL)

    local function addField(text, controlCreator)
        local lbl = sp:Add("DLabel")
        lbl:SetFont("ixPassportUI")
        lbl:SetText(text)
        lbl:Dock(TOP)
        lbl:DockMargin(0, 6, 0, 0)
        local ctrl = controlCreator()
        ctrl:Dock(TOP)
        return ctrl
    end

    self.nameEntry = addField("Titular", function() return sp:Add("DTextEntry") end)
    self.empEntry  = addField("Empleador", function() return sp:Add("DTextEntry") end)
    self.occEntry  = addField("Puesto", function() return sp:Add("DTextEntry") end)

    self.daysEntry = addField("Duración (días, por defecto 30)", function()
        local n = sp:Add("DNumberWang")
        n:SetMinMax(1, 365)
        n:SetValue(30)
        return n
    end)

    local save = sp:Add("DButton")
    save:Dock(TOP)
    save:DockMargin(0, 12, 0, 0)
    save:SetText("Guardar")
    save:SetFont("ixPassportUI")
    save:SetTall(28)

    function save:DoClick()
        if (panel.itemID == 0) then return end
        local data = {
            holderName  = panel.nameEntry:GetText(),
            employer    = panel.empEntry:GetText(),
            occupation  = panel.occEntry:GetText(),
            durationDays= tonumber(panel.daysEntry:GetValue()) or 30
        }
        net.Start("ix.pp.SaveWorkPass")
            net.WriteUInt(panel.itemID, 32)
            net.WriteTable(data)
        net.SendToServer()
        panel:Close()
    end
end

function EW:SetItem(item)
    self.itemID = item and item.id or 0
    local d = item and item:GetData("workpass", {}) or {}
    if (d.holderName) then self.nameEntry:SetText(d.holderName) end
    if (d.employer) then self.empEntry:SetText(d.employer) end
    if (d.occupation) then self.occEntry:SetText(d.occupation) end
end

local function regWorkEditor()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixWorkPassEditor", EW, "ixFrame")
    else
        vgui.Register("ixWorkPassEditor", EW, "DFrame")
    end
end
timer.Simple(0, regWorkEditor)
hook.Add("LoadedLocalSchema", "pp_register_workpass_editor", regWorkEditor)