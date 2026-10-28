-- cl_inspection_desk.lua
-- Mesa de inspección estilo "Papers, Please":
--   - Drop-down stamp drawer with handle (top-left)
--   - Sellos físicos que se agarran y se golpean sobre el documento
--   - Bandeja con búsqueda, visor de docs, confiscar, etc.
--   - Cierre robusto: X propia, ESC y botón "Cerrar"
--   - Compatible con Helix (usa inventario si está) y DarkRP (fallback)

-------------------------------------------
-- Config/Helpers seguros (con fallback)
-------------------------------------------
local PLUGIN = rawget(_G, "PLUGIN") or {}

PLUGIN.PassportBaseW = PLUGIN.PassportBaseW or 800
PLUGIN.PassportBaseH = PLUGIN.PassportBaseH or 534
PLUGIN.PassportTemplate   = PLUGIN.PassportTemplate   or "metro/pasport.png"
PLUGIN.PassportStampRect  = PLUGIN.PassportStampRect  or { x=40, y=304, w=128, h=128 }

PLUGIN.PassportFields = PLUGIN.PassportFields or {
  { key="fullName",    label="Nombre completo",     x=470, y=96  },
  { key="nationality", label="Nacionalidad",        x=470, y=126 },
  { key="citizenship", label="Ciudadanía",          x=470, y=156 },
  { key="residence",   label="Lugar de residencia", x=470, y=186 },
  { key="issuedBy",    label="Emitido por",         x=470, y=216 },
  { key="issuedWhere", label="Lugar de emisión",    x=470, y=246 },
  { key="issuedWhen",  label="Fecha de emisión",    x=470, y=276 },
  { key="birth",       label="Fecha de nacimiento", x=470, y=336 },
}

PLUGIN.StampsFolder = PLUGIN.StampsFolder or "metro/stamp/"
PLUGIN.DeskApprovedStamp = PLUGIN.DeskApprovedStamp or "metro/stamp/Aprobado.png"
PLUGIN.DeskRejectedStamp = PLUGIN.DeskRejectedStamp or "metro/stamp/Denegado.png"

-------------------------------------------
-- Fuentes
-------------------------------------------
-- Definidas en libs/cl_fonts.lua, que Helix carga ANTES que derma/.
-- (El antiguo pcall(surface.SetFont, ...) era la causa del error
--  "'ixPassportFont' isn't a valid font": surface.SetFont imprime ese error en
--  consola y la fuente aún no existía porque cl_fonts vivía fuera de libs/.)
local FONT_MAIN = "ixPassportFont"
local FONT_UI   = "ixPassportUI"

-- ¿El jugador local pertenece a una facción de control (o Staff) y puede firmar?
-- Refleja la misma regla que el servidor (PLUGIN:GetInspectorInfo).
local function LocalCanInspect()
  local ply = LocalPlayer()
  if not IsValid(ply) then return false end

  local faction = ix.faction.indices[ply:Team()]
  local uid = faction and faction.uniqueID or ""

  if (PLUGIN.InspectorStamps and PLUGIN.InspectorStamps[uid]) then return true end
  if (uid == "staff") then return true end
  return false
end

-------------------------------------------
-- Utilidades de sello
-------------------------------------------
local function normStampPath(name)
  name = tostring(name or "")
  if name == "" then return "" end
  if name:find("/") then return name end
  return PLUGIN.StampsFolder .. name
end

-- Cache for materials to avoid reloading
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

-- Function to validate if a texture file exists
local function textureExists(path)
  local mat = Material(path)
  return mat and not mat:IsError()
end

-- Preload common textures
local function preloadTextures()
  -- Preload passport template
  if PLUGIN.PassportTemplate then
    getMaterial(PLUGIN.PassportTemplate)
  end
  
  -- Preload common stamps
  local commonStamps = {
    "metro/stamp/Aprobado.png",
    "metro/stamp/Denegado.png",
    "metro/stamp/polis.png"
  }
  
  for _, stampPath in ipairs(commonStamps) do
    getMaterial(stampPath)
  end
end

---------------------------------------------------------
-- Cámara de cara para DModelPanel (foto del pasaporte)
---------------------------------------------------------
local function ApplyFaceCamera(panel, ent)
  if not IsValid(panel) or not IsValid(ent) then return end
  local lookPos, lookAng
  local attId = ent:LookupAttachment("eyes") or -1
  if (attId > 0) then
    local t = ent:GetAttachment(attId)
    if (t and t.Pos) then lookPos = t.Pos; lookAng = t.Ang or Angle(0,0,0) end
  end
  if not lookPos then
    local bone = ent:LookupBone("ValveBiped.Bip01_Head1") or ent:LookupBone("Head")
    if bone then lookPos = ent:GetBonePosition(bone) or Vector(0,0,60); lookAng = Angle(0,0,0) end
  end
  if not lookPos then
    local mn, mx = ent:GetModelBounds()
    lookPos = Vector(0, 0, (mn.z + mx.z) * 0.6); lookAng = Angle(0,0,0)
  end
  local mn, mx = ent:GetModelBounds()
  local dist = math.max(1, mx.z - mn.z) * (PLUGIN.FaceDistanceScale or 0.18)
  local ang = lookAng or Angle(0,0,0)
  panel:SetLookAt(lookPos)
  panel:SetCamPos(lookPos + ang:Forward() * dist + ang:Up() * (PLUGIN.FaceUpOffset or 0))
  panel:SetFOV(PLUGIN.FaceFOV or 16)
end

---------------------------------------------------------
-- Render pasaporte
---------------------------------------------------------
local passportTemplateMat
local function drawPassportLike(data, w, h)
  -- Try to load passport template with error handling
  if not passportTemplateMat then
    local templatePath = PLUGIN.PassportTemplate or "metro/pasport.png"
    passportTemplateMat = getMaterial(templatePath)
  end
  
  -- Draw background
  surface.SetDrawColor(255,255,255)
  if passportTemplateMat then
    surface.SetMaterial(passportTemplateMat)
    surface.DrawTexturedRect(0,0,w,h)
  else
    -- Fallback: draw colored background if texture fails
    surface.SetDrawColor(220, 210, 190)
    surface.DrawRect(0,0,w,h)
    surface.SetDrawColor(150, 140, 120)
    surface.DrawOutlinedRect(0,0,w,h,2)
  end

  -- Draw stamps
  if data and data.stamp and data.stamp ~= "" then
    local r = PLUGIN.PassportStampRect
    local stampMat = getMaterial(normStampPath(data.stamp))
    
    if stampMat then
      surface.SetMaterial(stampMat)
      surface.SetDrawColor(255,255,255,230)
      surface.DrawTexturedRect(
        r.x * w / PLUGIN.PassportBaseW,
        r.y * h / PLUGIN.PassportBaseH,
        r.w * w / PLUGIN.PassportBaseW,
        r.h * h / PLUGIN.PassportBaseH
      )
    end
  end

  surface.SetFont(FONT_MAIN)
  surface.SetTextColor(40,30,10,255)
  for _, f in ipairs(PLUGIN.PassportFields or {}) do
    surface.SetTextPos(
      f.x * w / PLUGIN.PassportBaseW,
      f.y * h / PLUGIN.PassportBaseH
    )
    surface.DrawText(data and data.fields and data.fields[f.key] or "")
  end
end

---------------------------------------------------------
-- Documento draggable
---------------------------------------------------------
local SHEET_Z_COUNTER = 1
local OPEN_SHEETS = OPEN_SHEETS or {}

local DOC = {}
DOC.Type = ""
DOC.ItemID = 0
DOC.Data = nil

function DOC:Init()
  self:SetSize(520,350)
  self:SetCursor("sizeall")
  self:SetMouseInputEnabled(true)
end

function DOC:OnMousePressed(m)
  if m == MOUSE_LEFT then
    self.Dragging = true
    self:MouseCapture(true)

    SHEET_Z_COUNTER = SHEET_Z_COUNTER + 1
    self:SetZPos(SHEET_Z_COUNTER)

    if IsValid(self:GetParent()) then
      self:GetParent().ActiveSheet = self
    end

    local mx,my = gui.MousePos()
    local sx,sy = self:LocalToScreen(0,0)
    self._grabX = mx - sx
    self._grabY = my - sy

  elseif m == MOUSE_RIGHT then
      if self.OpenContext then
          self:OpenContext()
      end
  end

end

function DOC:OnMouseReleased(m)
  if m == MOUSE_LEFT then
    self.Dragging = false
    self:MouseCapture(false)
  end
end

function DOC:Think()
  if not self.Dragging then return end
  local mx,my = gui.MousePos()
  local parent = self:GetParent()
  if not IsValid(parent) then return end
  local px,py = parent:LocalToScreen(0,0)
  self:SetPos(
    math.Clamp(mx - px - self._grabX, 0, parent:GetWide() - self:GetWide()),
    math.Clamp(my - py - self._grabY, 0, parent:GetTall() - self:GetTall())
  )
end

function DOC:OpenContext()
  local menu = DermaMenu()
  
  -- Add document-specific options
  if self.Type == "passport" then
    menu:AddOption("Ver Pasaporte Completo", function()
      -- Open detailed passport viewer
      if vgui.GetControlTable("ixMultiPagePassport") and PLUGIN.OpenMultiPagePassport then
        local passportData = self.Data or {}
        PLUGIN:OpenMultiPagePassport(self.ItemID, passportData)
      else
        local base = vgui.GetControlTable("ixFrame") and "ixFrame" or "DFrame"
        local fr = vgui.Create("ixPassportViewer") or vgui.Create(base)
        if fr.SetPassportData then fr:SetPassportData(self.Data or {}) end
        if fr.SetSize then fr:SetSize(880, 560) end
        if fr.Center then fr:Center() end
        if fr.MakePopup then fr:MakePopup() end
        if fr.SetTitle then fr:SetTitle("Pasaporte Detallado") end
      end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Pasaporte", function()
      -- Return passport to inventory
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
    menu:AddSpacer()
    
    menu:AddOption("Limpiar Sellos", function()
      -- Clear all stamps from passport
      self:ClearStamps()
    end):SetIcon("icon16/eraser.png")
    
  elseif self.Type == "entry_permit" then
    menu:AddOption("Ver Permiso Detallado", function()
      local v = vgui.Create("ixEntryPermitViewer")
      if v and v.SetPermitData then v:SetPermitData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Permiso", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "work_pass" then
    menu:AddOption("Ver Pase Detallado", function()
      local v = vgui.Create("ixWorkPassViewer")
      if v and v.SetWorkPassData then v:SetWorkPassData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Pase", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "id_card" then
    menu:AddOption("Ver Tarjeta Detallada", function()
      local v = vgui.Create("ixIDCardViewer")
      if v and v.SetIDCardData then v:SetIDCardData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Tarjeta", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "diplomatic_id" then
    menu:AddOption("Ver ID Diplomático", function()
      local v = vgui.Create("ixDiplomaticIDViewer")
      if v and v.SetDiplomaticData then v:SetDiplomaticData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver ID", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "transit_permit" then
    menu:AddOption("Ver Permiso Detallado", function()
      local v = vgui.Create("ixTransitPermitViewer")
      if v and v.SetTransitData then v:SetTransitData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Permiso", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "access_ticket" then
    menu:AddOption("Ver Boleto Detallado", function()
      local v = vgui.Create("ixAccessTicketViewer")
      if v and v.SetTicketData then v:SetTicketData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Boleto", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
    
  elseif self.Type == "vaccine_documents" then
    menu:AddOption("Ver Documentos Detallados", function()
      local v = vgui.Create("ixVaccineDocumentsViewer")
      if v and v.SetVaccineData then v:SetVaccineData(self.Data or {}) end
    end):SetIcon("icon16/page.png")
    
    menu:AddOption("Devolver Documentos", function()
      self:ReturnToInventory()
    end):SetIcon("icon16/arrow_undo.png")
  end
  
  -- Common options for all documents
  menu:AddSpacer()
  
  menu:AddOption("Rotar Documento", function()
    -- Rotate the document 90 degrees
    local currentW, currentH = self:GetSize()
    self:SetSize(currentH, currentW)
  end):SetIcon("icon16/arrow_rotate_clockwise.png")
  
  menu:AddOption("Centrar en Mesa", function()
    -- Center the document on the work area
    local parent = self:GetParent()
    if IsValid(parent) then
      local parentW, parentH = parent:GetSize()
      local docW, docH = self:GetSize()
      self:SetPos((parentW - docW) / 2, (parentH - docH) / 2)
    end
  end):SetIcon("icon16/arrow_in.png")
  
  menu:AddSpacer()
  
  menu:AddOption("Confiscar Documento", function()
    -- Confiscate the document (requires server-side handling)
    Derma_Query(
      "¿Estás seguro de que quieres confiscar este documento?\nEsta acción no se puede deshacer.",
      "Confirmar Confiscación",
      "Sí, Confiscar", function()
        self:ConfiscateDocument()
      end,
      "Cancelar", function()
        -- Do nothing
      end
    )
  end):SetIcon("icon16/delete.png")
  
  menu:Open()
end

function DOC:ReturnToInventory()
  if not self.ItemID then return end
  
  -- Send request to server to return document to inventory
  net.Start("ix.pp.ReturnDocument")
    net.WriteUInt(self.ItemID, 32)
    net.WriteString(self.Type or "")
  net.SendToServer()
  
  -- Remove from display
  self:Remove()
  
  chat.AddText(Color(120, 200, 120), "[Mesa] ", color_white, "Documento devuelto al inventario")
end

function DOC:ClearStamps()
  if not self.ItemID or self.Type ~= "passport" then return end
  
  Derma_Query(
    "¿Estás seguro de que quieres limpiar todos los sellos del pasaporte?\nEsta acción no se puede deshacer.",
    "Confirmar Limpieza",
    "Sí, Limpiar", function()
      net.Start("ix.pp.ClearPassportStamps")
        net.WriteUInt(self.ItemID, 32)
      net.SendToServer()
      
      -- Limpiar sellos de viaje localmente (NO tocar stamp de emisión)
      if (self.Data and self.Data.pages) then
        for _, page in ipairs(self.Data.pages) do
          page.stationStamps = {}
        end
      end
      self:InvalidateLayout(true)

      chat.AddText(Color(120, 200, 120), "[Mesa] ", color_white, "Sellos de viaje limpiados")
    end,
    "Cancelar", function()
      -- Do nothing
    end
  )
end

function DOC:ConfiscateDocument()
  if not self.ItemID then return end
  
  -- Send confiscation request to server
  net.Start("ix.pp.ConfiscateDoc")
    net.WriteUInt(self.ItemID, 32)
    net.WriteString(self.Type or "")
  net.SendToServer()
  
  -- Remove from display immediately
  self:Remove()
  
  chat.AddText(Color(200, 120, 120), "[Mesa] ", color_white, "Documento confiscado")
end

function DOC:OnRemove()
  if self.ItemID then
    OPEN_SHEETS[self.ItemID] = nil
  end
  
  -- Remove from document tracking
  local parent = self:GetParent()
  while IsValid(parent) and not parent.DocumentsOnDesk do
    parent = parent:GetParent()
  end
  
  if IsValid(parent) and parent.DocumentsOnDesk then
    for i, doc in ipairs(parent.DocumentsOnDesk) do
      if doc == self then
        table.remove(parent.DocumentsOnDesk, i)
        parent.DocumentCount = #parent.DocumentsOnDesk
        break
      end
    end
  end
end

function DOC:SendStamp(stamp)
  net.Start("ix.pp.StampDoc")
    net.WriteUInt(self.ItemID or 0, 32)
    net.WriteString(stamp or "")
    net.WriteString(self.Type or "")
  net.SendToServer()
end

function DOC:SendStampWithPosition(stamp, relX, relY)
  -- Guardar la posición del sello para renderizado personalizado
  self.StampX = relX
  self.StampY = relY
  self.StampPath = stamp
  
  -- Enviar al servidor igual que antes
  net.Start("ix.pp.StampDoc")
    net.WriteUInt(self.ItemID or 0, 32)
    net.WriteString(stamp or "")
    net.WriteString(self.Type or "")
  net.SendToServer()
end

function DOC:Paint(w,h)
  -- Bordered Paper Document Style Background
  surface.SetDrawColor(220, 210, 190)
  surface.DrawRect(0,0,w,h)
  
  -- Borde estilo documento
  surface.SetDrawColor(150, 140, 120)
  surface.DrawOutlinedRect(0,0,w,h,1)
  
  -- Get the inspection desk parent to access current page info
  local desk = self:GetParent()
  while IsValid(desk) and desk:GetParent() do
    if desk.SetCurrentDocument then
      break
    end
    desk = desk:GetParent()
  end
  
  if self.Type == "passport" then
    -- Check if we have page info from the inspection desk
    local currentPage = 1
    local passportPages = self.Data.pages or {
      {
        pageNumber = 1,
        stationStamps = {},
        notes = ""
      }
    }
    
    if IsValid(desk) and desk.CurrentPassportPage then
      currentPage = desk.CurrentPassportPage
      passportPages = desk.CurrentPassportPages or passportPages
    end
    
    -- Draw the current page
    local pageData = passportPages[currentPage]
    if pageData then
      if pageData.pageNumber == 1 then
        -- Draw main passport page
        drawPassportLike(self.Data or {}, w, h)

        -- Foto del modelo (si existe el DModelPanel)
        if IsValid(self._photoPanel) then
          local r = PLUGIN.PassportPhotoRect
          local px = r.x * w / PLUGIN.PassportBaseW
          local py = r.y * h / PLUGIN.PassportBaseH
          local pw = r.w * w / PLUGIN.PassportBaseW
          local ph = r.h * h / PLUGIN.PassportBaseH
          self._photoPanel:SetPos(px, py)
          self._photoPanel:SetSize(pw, ph)
          local sx, sy = self._photoPanel:LocalToScreen(0, 0)
          render.SetScissorRect(sx, sy, sx + pw, sy + ph, true)
            self._photoPanel:PaintManual()
          render.SetScissorRect(0, 0, 0, 0, false)
        end
      else
        -- Draw station record page
        self:DrawStationPage(w, h, pageData)
      end
    end
    
  elseif self.Type == "entry_permit" then
    -- Mostrar información del permiso de entrada
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    
    local data = self.Data or {}
    local yPos = 30
    
    -- Título
    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("PERMISO DE ENTRADA")
    yPos = yPos + 35
    
    -- Campos del permiso
    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.nationality then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Nacionalidad: " .. data.nationality)
      yPos = yPos + 22
    end
    if data.purpose then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Propósito: " .. data.purpose)
      yPos = yPos + 22
    end
    if data.issuingCity then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Ciudad de emisión: " .. data.issuingCity)
      yPos = yPos + 22
    end
    if data.durationDays then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Duración: " .. tostring(data.durationDays) .. " días")
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.expiresAt then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Caduca: " .. os.date("%d/%m/%Y", data.expiresAt))
      yPos = yPos + 22
    end

    -- Stamp if it exists (with custom position)
    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)

      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)

        local stampX = self.StampX or (w - 150)
        local stampY = self.StampY or (h - 150)

        surface.DrawTexturedRect(stampX, stampY, 128, 128)
      end
    end

  elseif self.Type == "work_pass" then
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)

    local data = self.Data or {}
    local yPos = 30

    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("PASE DE TRABAJO")
    yPos = yPos + 35

    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.employer then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Empleador: " .. data.employer)
      yPos = yPos + 22
    end
    if data.occupation then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Ocupación: " .. data.occupation)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.expiresAt then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Caduca: " .. os.date("%d/%m/%Y", data.expiresAt))
      yPos = yPos + 22
    end

    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)

      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)

        local stampX = self.StampX or (w - 150)
        local stampY = self.StampY or (h - 150)

        surface.DrawTexturedRect(stampX, stampY, 128, 128)
      end
    end
    
  elseif self.Type == "id_card" then
    -- Mostrar información de la tarjeta de identidad
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    
    local data = self.Data or {}
    local yPos = 30
    
    -- Título
    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("TARJETA DE IDENTIDAD")
    yPos = yPos + 35
    
    -- Campos de la tarjeta
    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.citizenship then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Ciudadanía: " .. data.citizenship)
      yPos = yPos + 22
    end
    if data.birthDate then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Fecha de nacimiento: " .. data.birthDate)
      yPos = yPos + 22
    end
    if data.idNumber then
      surface.SetTextPos(15, yPos)
      surface.DrawText("ID: " .. data.idNumber)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.expiresAt then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Caduca: " .. os.date("%d/%m/%Y", data.expiresAt))
      yPos = yPos + 22
    end

    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)
      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)
        local stampX = self.StampX or (w - 120)
        local stampY = self.StampY or (h - 120)
        surface.DrawTexturedRect(stampX, stampY, 100, 100)
      end
    end

  elseif self.Type == "diplomatic_id" then
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    local data = self.Data or {}
    local yPos = 30

    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("IDENTIDAD DIPLOMÁTICA")
    yPos = yPos + 35

    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.position then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Cargo: " .. data.position)
      yPos = yPos + 22
    end
    if data.embassy then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Embajada: " .. data.embassy)
      yPos = yPos + 22
    end
    if data.accreditationNumber then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Acreditación: " .. data.accreditationNumber)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.expiresAt then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Caduca: " .. os.date("%d/%m/%Y", data.expiresAt))
      yPos = yPos + 22
    end
    
    -- Sello si existe
    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)
      
      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)
        local stampX = self.StampX or (w - 120)
        local stampY = self.StampY or (h - 120)
        surface.DrawTexturedRect(stampX, stampY, 100, 100)
      end
    end
    
  elseif self.Type == "transit_permit" then
    -- Mostrar información del permiso de tránsito
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    
    local data = self.Data or {}
    local yPos = 30
    
    -- Título
    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("PERMISO DE TRÁNSITO")
    yPos = yPos + 35
    
    -- Campos del permiso
    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.origin then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Origen: " .. data.origin)
      yPos = yPos + 22
    end
    if data.destination then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Destino: " .. data.destination)
      yPos = yPos + 22
    end
    if data.purpose then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Motivo: " .. data.purpose)
      yPos = yPos + 22
    end
    if data.transitNumber then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Tránsito #: " .. data.transitNumber)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y %H:%M", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.expiresAt then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Válido hasta: " .. os.date("%d/%m/%Y %H:%M", data.expiresAt))
      yPos = yPos + 22
    end

    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)
      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)
        local stampX = self.StampX or (w - 120)
        local stampY = self.StampY or (h - 120)
        surface.DrawTexturedRect(stampX, stampY, 100, 100)
      end
    end

  elseif self.Type == "access_ticket" then
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    local data = self.Data or {}
    local yPos = 30

    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("BOLETO DE ACCESO")
    yPos = yPos + 35

    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.accessLevel then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Nivel: " .. data.accessLevel)
      yPos = yPos + 22
    end
    if data.validDate then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Fecha válida: " .. data.validDate)
      yPos = yPos + 22
    end
    if data.purpose then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Motivo: " .. data.purpose)
      yPos = yPos + 22
    end
    if data.ticketNumber then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Boleto #: " .. data.ticketNumber)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end

    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)
      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)
        local stampX = self.StampX or (w - 100)
        local stampY = self.StampY or (h - 100)
        surface.DrawTexturedRect(stampX, stampY, 80, 80)
      end
    end
    
  elseif self.Type == "vaccine_documents" then
    -- Mostrar información de documentos de vacunas
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    
    local data = self.Data or {}
    local yPos = 30
    
    -- Título
    surface.SetFont(FONT_MAIN)
    surface.SetTextPos(15, yPos)
    surface.DrawText("DOCUMENTOS DE VACUNAS")
    yPos = yPos + 35
    
    -- Campos del certificado
    surface.SetFont(FONT_MAIN)
    if data.holderName then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Titular: " .. data.holderName)
      yPos = yPos + 22
    end
    if data.certificateNumber then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Certificado: " .. data.certificateNumber)
      yPos = yPos + 22
    end
    if data.issuedWhen then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Emitido: " .. os.date("%d/%m/%Y", data.issuedWhen))
      yPos = yPos + 22
    end
    if data.validUntil then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Válido hasta: " .. os.date("%d/%m/%Y", data.validUntil))
      yPos = yPos + 22
    end

    if data.vaccines and type(data.vaccines) == "table" then
      surface.SetTextPos(15, yPos)
      surface.DrawText("Vacunas registradas: " .. #data.vaccines)
      yPos = yPos + 22

      for i = 1, math.min(3, #data.vaccines) do
        local vac = data.vaccines[i]
        if vac then
          local txt = type(vac) == "table" and (vac.name or "") .. " — " .. (vac.date or "") or tostring(vac)
          surface.SetTextPos(25, yPos)
          surface.DrawText("• " .. txt)
          yPos = yPos + 20
        end
      end

      if #data.vaccines > 3 then
        surface.SetTextPos(25, yPos)
        surface.DrawText("... y " .. (#data.vaccines - 3) .. " más")
        yPos = yPos + 20
      end
    end
    
    -- Sello si existe
    if data.stamp and data.stamp ~= "" then
      local stampPath = normStampPath(data.stamp)
      local stampMat = getMaterial(stampPath)
      
      if stampMat then
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 200)
        local stampX = self.StampX or (w - 120)
        local stampY = self.StampY or (h - 120)
        surface.DrawTexturedRect(stampX, stampY, 100, 100)
      end
    end
    
  else
    -- Para otros documentos, mostrar información básica sin el tipo
    surface.SetFont(FONT_MAIN)
    surface.SetTextColor(30, 25, 20)
    surface.SetTextPos(15, 15)
    surface.DrawText("DOCUMENTO OFICIAL")
  end
end

function DOC:DrawStationPage(w, h, pageData)
  -- Page header
  surface.SetFont(FONT_MAIN)
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
      local typeText = "ENTRADA"
      if stamp.stampType == "deny" then
        typeText = "DENEGADO"
      elseif stamp.stampType == "exit" then
        typeText = "SALIDA"
      elseif stamp.stampType == "transit" then
        typeText = "TRÁNSITO"
      end
      surface.DrawText(string.format("Tipo: %s", typeText))
      
      -- Sello visual: el sello de la facción que aprobó/denegó (stampImage); si no
      -- existe, cae al genérico Aprobado/Denegado.
      local stampRel = stamp.stampImage
      if (not stampRel or stampRel == "") then
        stampRel = (stamp.stampType == "deny") and "Denegado.png" or "Aprobado.png"
      end

      local stampMat = getMaterial(normStampPath(stampRel))
      if stampMat then
        local sw, sh = 96, 96
        local sx = math.min(280, w - sw - 20)
        local sy = yPos - 5
        surface.SetMaterial(stampMat)
        surface.SetDrawColor(255, 255, 255, 230)
        surface.DrawTexturedRect(sx, sy, sw, sh)
      end
      
      yPos = yPos + 110
    end
  else
    -- No stamps message
    surface.SetFont(FONT_UI)
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

---------------------------------------------------------
-- INTERACTIVE PHYSICAL STAMP (Papers, Please)
---------------------------------------------------------
local STAMP = {}
STAMP.Icon = nil
STAMP.StampPath = ""
STAMP.Held = false
STAMP.OffsetX = 0
STAMP.OffsetY = 0
STAMP.ReturnX = 0
STAMP.ReturnY = 0

function STAMP:Init()
  self:SetSize(64, 64)
  self:SetCursor("hand")
  self:SetMouseInputEnabled(true)
end

function STAMP:Setup(iconPath, stampPath)
  self.Icon = Material(iconPath, "smooth")
  self.StampPath = stampPath or ""
end

function STAMP:OnMousePressed(m)
  if m == MOUSE_LEFT then
    self.Held = true
    local mx, my = gui.MousePos()
    local sx, sy = self:LocalToScreen(0, 0)
    self.OffsetX = mx - sx
    self.OffsetY = my - sy

    self.ReturnX, self.ReturnY = self:GetPos()
    self:SetZPos(99999)
    self:MouseCapture(true)
  end
end

function STAMP:OnMouseReleased(m)
  if m == MOUSE_LEFT and self.Held then
    self.Held = false
    self:MouseCapture(false)

    local mx, my = gui.MousePos()
    local canvas = self:GetParent()
    if not IsValid(canvas) then
      self:SetPos(self.ReturnX, self.ReturnY)
      return
    end

    local frame = canvas:GetParent()
    if not IsValid(frame) or not IsValid(frame.WorkArea) then
      self:SetPos(self.ReturnX, self.ReturnY)
      return
    end

    -- Buscar todos los documentos en el área de trabajo
    local hitDocs = {}
    for _, child in ipairs(frame.WorkArea:GetChildren()) do
      if IsValid(child) and child.ItemID then
        local x, y = child:LocalToScreen(0, 0)
        if mx >= x and mx <= x + child:GetWide() and my >= y and my <= y + child:GetTall() then
          table.insert(hitDocs, child)
        end
      end
    end

    -- Si hay documentos, aplicar sello al que esté más cerca del cursor
    if #hitDocs > 0 then
      -- Encontrar el documento más cercano al cursor
      local closestDoc = nil
      local closestDist = math.huge
      
      for _, doc in ipairs(hitDocs) do
        local docX, docY = doc:LocalToScreen(doc:GetWide()/2, doc:GetTall()/2)
        local dist = math.sqrt((mx - docX)^2 + (my - docY)^2)
        if dist < closestDist then
          closestDist = dist
          closestDoc = doc
        end
      end
      
      if IsValid(closestDoc) then
        -- Calcular posición relativa dentro del documento
        local docX, docY = closestDoc:LocalToScreen(0, 0)
        local relX = mx - docX
        local relY = my - docY
        
        -- Aplicar sello con posición personalizada
        closestDoc:SendStampWithPosition(self.StampPath, relX, relY)
        surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
        
        -- Mensaje de debug
        chat.AddText(Color(120,200,120), "[Sello] ", color_white, "Aplicado: " .. string.GetFileFromFilename(self.StampPath or ""))
      end
    end

    self:SetPos(self.ReturnX, self.ReturnY)
  end
end

function STAMP:Think()
  if self.Held then
    local mx, my = gui.MousePos()
    local px, py = self:GetParent():LocalToScreen(0, 0)
    self:SetPos(mx - px - self.OffsetX, my - py - self.OffsetY)
  end
end

function STAMP:Paint(w, h)
  if self.Icon then
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(self.Icon)
    surface.DrawTexturedRect(0, 0, w, h)
  else
    surface.SetDrawColor(80, 80, 80)
    surface.DrawRect(0, 0, w, h)
  end
end

vgui.Register("ixStampTool", STAMP, "DPanel")
vgui.Register("ixDocSheet", DOC, "DPanel")

---------------------------------------------------------
-- Crear una hoja de documento en el área de trabajo.
-- A nivel de archivo para que la usen TANTO la bandeja (ixDocTray) COMO los
-- botones rápidos del panel principal. (Antes era local a TRAY:Rebuild, por lo
-- que los botones rápidos del panel derecho daban error al pulsarlos.)
---------------------------------------------------------
local DOC_SIZES = {
  passport          = { 520, 350, "passport" },
  entry_permit      = { 420, 280, "permit" },
  work_pass         = { 420, 260, "workpass" },
  id_card           = { 400, 240, "idcard" },
  diplomatic_id     = { 440, 280, "diplomatic" },
  transit_permit    = { 420, 260, "transit" },
  access_ticket     = { 380, 220, "ticket" },
  vaccine_documents = { 440, 300, "vaccine" },
}

local function spawnSheetOnCanvas(canvas, item)
  if not IsValid(canvas) or not item then return end

  local spec = DOC_SIZES[item.uniqueID]
  if not spec then return end

  local sheet = vgui.Create("ixDocSheet", canvas)
  if not IsValid(sheet) then return end

  sheet.ItemID = item.id
  sheet.Type = item.uniqueID
  sheet.Data = item:GetData(spec[3], {}) or {}
  sheet:SetSize(spec[1], spec[2])

  -- Foto del pasaporte: DModelPanel con la cara del modelo guardado.
  if (item.uniqueID == "passport" and PLUGIN.UsePlayerModelPhoto) then
    local pdata = sheet.Data
    local mdl = pdata.model or ""
    if (mdl != "") then
      local mp = vgui.Create("DModelPanel", sheet)
      mp:SetModel(mdl)
      mp:SetMouseInputEnabled(false)
      mp.LayoutEntity = function() end
      mp:SetPaintedManually(true)
      sheet._photoPanel = mp

      local ent = mp:GetEntity()
      if IsValid(ent) then
        ent:SetSkin(tonumber(pdata.skin or 0) or 0)
        for id, val in pairs(pdata.bodygroups or {}) do
          ent:SetBodygroup(tonumber(id) or id, tonumber(val) or 0)
        end
        ApplyFaceCamera(mp, ent)
      end
    end
  end

  local w, h = canvas:GetWide(), canvas:GetTall()
  sheet:SetPos(
    math.random(8, math.max(8, w - sheet:GetWide() - 8)),
    math.random(8, math.max(8, h - sheet:GetTall() - 8))
  )
  SHEET_Z_COUNTER = SHEET_Z_COUNTER + 1
  sheet:SetZPos(SHEET_Z_COUNTER)
  if sheet.ItemID then OPEN_SHEETS[sheet.ItemID] = sheet end

  -- Localizar la mesa para registrar el documento activo
  local desk = canvas:GetParent()
  while IsValid(desk) and desk:GetParent() and not desk.SetCurrentDocument do
    desk = desk:GetParent()
  end

  if IsValid(desk) and desk.SetCurrentDocument then
    desk:SetCurrentDocument(sheet)

    if desk.DocumentsOnDesk then
      table.insert(desk.DocumentsOnDesk, sheet)
      desk.DocumentCount = #desk.DocumentsOnDesk
    end
  end

  return sheet
end

---------------------------------------------------------
-- Bandeja (Helix inventario) + búsqueda
---------------------------------------------------------
local TRAY = {}
function TRAY:Init()
  self:SetTall(240)
  self.search = self:Add("DTextEntry")
  self.search:Dock(TOP); self.search:SetTall(24)
  self.search:DockMargin(6, 6, 6, 4); self.search:SetFont(FONT_UI)
  self.search:SetPlaceholderText("Buscar: nombre, titular, nacionalidad, empleador...")
  self.search:SetUpdateOnType(true)
  self.search.OnValueChange = function(_, val) self:SetFilter(val or ""); self:Rebuild() end

  self.scroll = self:Add("DScrollPanel")
  self.scroll:Dock(FILL); self.scroll:DockMargin(0,2,0,6)
  local vbar = self.scroll:GetVBar()
  function vbar:Paint(w,h) draw.RoundedBox(4,0,0,w,h,Color(18,18,18,160)) end
  function vbar.btnUp:Paint(w,h) draw.RoundedBox(4,0,0,w,h,Color(80,80,80,180)) end
  function vbar.btnDown:Paint(w,h) draw.RoundedBox(4,0,0,w,h,Color(80,80,80,180)) end
  function vbar.btnGrip:Paint(w,h) draw.RoundedBox(4,2,0,w-4,h,Color(150,150,150,200)) end

  self.list = self.scroll:Add("DIconLayout")
  self.list:Dock(FILL); self.list:SetSpaceX(6); self.list:SetSpaceY(6); self.list:SetBorder(6)

  self.filterTerm = ""; self:Rebuild()
end

function TRAY:Paint(w,h)
  draw.RoundedBox(6,0,0,w,h,Color(28,26,24,235))
  surface.SetDrawColor(255,255,255,10); surface.DrawOutlinedRect(0,0,w,h,1)
end

function TRAY:ClearIcons()
  if IsValid(self.list) then self.list:Clear() end
  if IsValid(self.scroll) then self.scroll:GetVBar():SetScroll(0) end
end

function TRAY:SetFilter(text) self.filterTerm = string.Trim(string.lower(tostring(text or ""))) end
local function termInText(term, ...)
  if term == "" then return true end
  local t = string.lower(term)
  for i=1, select("#", ...) do
    local v = tostring(select(i, ...) or "")
    if v ~= "" and string.find(string.lower(v), t, 1, true) then return true end
  end
  return false
end

function TRAY:Rebuild()
  if not IsValid(self.list) then return end
  self.list:Clear()

  local hasHelix = istable(ix) and LocalPlayer and LocalPlayer().GetCharacter
  if not hasHelix then
    local info = self.list:Add("DLabel")
    info:SetText("Inventario de Helix no disponible.\n(La bandeja requiere Helix)")
    info:SetFont(FONT_UI); info:SizeToContents()
    if IsValid(self.scroll) then self.scroll:GetVBar():SetScroll(0) end
    return
  end

  local char = LocalPlayer():GetCharacter(); if not char then return end
  local inv  = char:GetInventory(); if not inv then return end
  local items = inv:GetItems(true) or {}
  local parentPanel = self:GetParent()

  local function addIconFor(item, label, searchableText)
    if not termInText(self.filterTerm, label, searchableText) then return end
    local pnl = self.list:Add("DButton")
    pnl:SetText(""); pnl:SetSize(110,84)
    pnl.Paint = function(_, w,h)
      surface.SetDrawColor(65,62,58,255); surface.DrawRect(0,0,w,h)
      draw.SimpleText(label, FONT_UI, w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    pnl.DoClick = function()
      -- Find main inspection desk frame by going up the hierarchy
      local frame = self
      while IsValid(frame) and frame:GetParent() do
        local parent = frame:GetParent()
        if parent and IsValid(parent) and parent.GetClass and parent:GetClass() == "ixInspectionDesk" then
          frame = parent
          break
        end
        frame = parent
      end
      
      -- Alternative: search up for WorkArea
      local searchParent = self
      while IsValid(searchParent) do
        if IsValid(searchParent.WorkArea) then
          frame = searchParent
          break
        end
        searchParent = searchParent:GetParent()
      end
      
      if not (IsValid(frame) and IsValid(frame.WorkArea)) then return end
      spawnSheetOnCanvas(frame.WorkArea, item)
    end
    pnl.DoRightClick = function()
      -- Only open external viewers on right-click
      if item.uniqueID == "passport" then
        if vgui.GetControlTable("ixMultiPagePassport") and PLUGIN.OpenMultiPagePassport then
          local passportData = item:GetData("passport", {}) or {}
          PLUGIN:OpenMultiPagePassport(item.id, passportData)
        else
          local base = vgui.GetControlTable("ixFrame") and "ixFrame" or "DFrame"
          local fr   = vgui.Create("ixPassportViewer") or vgui.Create(base)
          if fr.SetPassportData then fr:SetPassportData(item:GetData("passport", {}) or {}) end
          if fr.SetSize then fr:SetSize(880, 560) end
          if fr.Center then fr:Center() end
          if fr.MakePopup then fr:MakePopup() end
          if fr.SetTitle then fr:SetTitle("Pasaporte") end
        end
      elseif item.uniqueID == "entry_permit" then
        local v = vgui.Create("ixEntryPermitViewer")
        if v and v.SetPermitData then v:SetPermitData(item:GetData("permit", {}) or {}) end
      elseif item.uniqueID == "work_pass" then
        local v = vgui.Create("ixWorkPassViewer")
        if v and v.SetWorkPassData then v:SetWorkPassData(item:GetData("workpass", {}) or {}) end
      end
    end
  end

  for _, it in pairs(items) do
    if it.uniqueID == "passport" then
      local d = it:GetData("passport", {}) or {}; local f = d.fields or {}
      local searchable = table.concat({f.fullName or "", f.nationality or "", f.citizenship or "", f.residence or "", f.issuedBy or "", f.issuedWhere or ""}, " ")
      addIconFor(it, "Pasaporte", searchable)
    elseif it.uniqueID == "entry_permit" then
      local d = it:GetData("permit", {}) or {}
      local searchable = table.concat({d.holderName or "", d.nationality or "", d.purpose or "", d.issuingCity or ""}, " ")
      addIconFor(it, "Permiso", searchable)
    elseif it.uniqueID == "work_pass" then
      local d = it:GetData("workpass", {}) or {}
      local searchable = table.concat({d.holderName or "", d.employer or "", d.occupation or ""}, " ")
      addIconFor(it, "Trabajo", searchable)
    elseif it.uniqueID == "id_card" then
      local d = it:GetData("idcard", {}) or {}
      local searchable = table.concat({d.holderName or "", d.citizenship or "", d.idNumber or ""}, " ")
      addIconFor(it, "ID", searchable)
    elseif it.uniqueID == "diplomatic_id" then
      local d = it:GetData("diplomatic", {}) or {}
      local searchable = table.concat({d.holderName or "", d.position or "", d.embassy or ""}, " ")
      addIconFor(it, "Diplomático", searchable)
    elseif it.uniqueID == "transit_permit" then
      local d = it:GetData("transit", {}) or {}
      local searchable = table.concat({d.holderName or "", d.origin or "", d.destination or ""}, " ")
      addIconFor(it, "Tránsito", searchable)
    elseif it.uniqueID == "access_ticket" then
      local d = it:GetData("ticket", {}) or {}
      local searchable = table.concat({d.holderName or "", d.accessLevel or "", d.purpose or ""}, " ")
      addIconFor(it, "Boleto", searchable)
    elseif it.uniqueID == "vaccine_documents" then
      local d = it:GetData("vaccine", {}) or {}
      local searchable = table.concat({d.holderName or "", d.certificateNumber or ""}, " ")
      addIconFor(it, "Vacunas", searchable)
    end
  end

  if IsValid(self.scroll) then self.scroll:GetVBar():SetScroll(0) end
end

vgui.Register("ixDocTray", TRAY, "EditablePanel")

---------------------------------------------------------
-- Panel principal + animación de entrada
---------------------------------------------------------
local PANEL = {}
local g_InspectionDesk

-- ===============================
-- GUI FUNCTIONS FOR FIELD SELECTION
-- ===============================
-- GUI for field selection
local function Desk_ShowFieldSelectionGUI(desk, passportFields)
  -- Create field selection frame
  if IsValid(desk.FieldSelectionFrame) then
    desk.FieldSelectionFrame:Close()
  end
  
  desk.FieldSelectionFrame = vgui.Create("DFrame")
  local frame = desk.FieldSelectionFrame
  frame:SetTitle("Seleccionar Campo para Comparar")
  frame:SetSize(400, 500)
  frame:Center()
  frame:MakePopup()
  frame:SetBackgroundBlur(true)
  
  -- Main panel
  local mainPanel = frame:Add("DPanel")
  mainPanel:Dock(FILL)
  mainPanel:DockPadding(10, 10, 10, 10)
  
  -- Title label
  local titleLabel = mainPanel:Add("DLabel")
  titleLabel:SetFont("ixPassportUI")
  titleLabel:SetColor(Color(255, 255, 255))
  titleLabel:SetText("Selecciona el campo del pasaporte que quieres comparar:")
  titleLabel:Dock(TOP)
  titleLabel:SetTall(30)
  
  -- Scroll panel for field buttons
  local scrollPanel = mainPanel:Add("DScrollPanel")
  scrollPanel:Dock(FILL)
  
  -- Create field buttons
  for i, field in ipairs(PLUGIN.PassportFields or {}) do
    local fieldValue = passportFields[field.key] or "(vacío)"
    
    local fieldPanel = scrollPanel:Add("DPanel")
    fieldPanel:SetTall(50)
    fieldPanel:Dock(TOP)
    fieldPanel:DockMargin(0, 0, 0, 5)
    fieldPanel.Paint = function(_, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 70, 200))
      surface.SetDrawColor(255, 255, 255, 10)
      surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    -- Field number
    local numberLabel = fieldPanel:Add("DLabel")
    numberLabel:SetFont("ixPassportUI")
    numberLabel:SetColor(Color(200, 200, 200))
    numberLabel:SetText("[" .. i .. "]")
    numberLabel:SetPos(5, 5)
    numberLabel:SetSize(30, 20)
    
    -- Field name
    local nameLabel = fieldPanel:Add("DLabel")
    nameLabel:SetFont("ixPassportUI")
    nameLabel:SetColor(Color(255, 255, 255))
    nameLabel:SetText(field.label)
    nameLabel:SetPos(40, 5)
    nameLabel:SetSize(250, 20)
    
    -- Field value
    local valueLabel = fieldPanel:Add("DLabel")
    valueLabel:SetFont("ixPassportUI")
    valueLabel:SetColor(fieldValue ~= "(vacío)" and Color(100, 255, 100) or Color(200, 200, 200))
    valueLabel:SetText(fieldValue)
    valueLabel:SetPos(40, 25)
    valueLabel:SetSize(250, 20)
    
    -- Select button
    local selectBtn = fieldPanel:Add("DButton")
    selectBtn:SetFont("ixPassportUI")
    selectBtn:SetText("Comparar")
    selectBtn:SetSize(80, 20)
    selectBtn:SetPos(300, 25)
    selectBtn.DoClick = function()
      Desk_CompareSelectedFieldGUI(desk, i, passportFields)
      frame:Close()
    end
  end
  
  -- Instructions label
  local instructionsLabel = mainPanel:Add("DLabel")
  instructionsLabel:SetFont("ixPassportUI")
  instructionsLabel:SetColor(Color(150, 150, 255))
  instructionsLabel:SetText("Clic en 'Comparar' para verificar este campo con los demás documentos")
  instructionsLabel:Dock(BOTTOM)
  instructionsLabel:SetTall(40)
  instructionsLabel:DockMargin(0, 5, 0, 0)
end

-- Function to compare selected field using GUI selection
function Desk_CompareSelectedFieldGUI(desk, fieldIndex, passportFields)
  if not desk.PassportForComparison then
    Desk_ShowResultsGUI(desk, "Error", {"No hay pasaporte disponible"}, Color(200, 150, 100))
    return
  end
  
  local selectedField = PLUGIN.PassportFields and PLUGIN.PassportFields[fieldIndex]
  if not selectedField then
    Desk_ShowResultsGUI(desk, "Error", {"Campo no válido"}, Color(200, 150, 100))
    return
  end
  
  local passportValue = passportFields[selectedField.key] or ""
  local documents = desk.DocumentsOnDesk
  local discrepancies = {}
  local matches = {}
  
  -- Compare selected field with other documents
  for _, doc in ipairs(documents) do
    if doc ~= desk.PassportForComparison then
      local docValue = ""
      
      if doc.Type == "entry_permit" then
        local permitFields = doc.Data and doc.Data.fields or {}
        if selectedField.key == "fullName" then
          docValue = permitFields.holderName or ""
        elseif selectedField.key == "nationality" then
          docValue = permitFields.nationality or ""
        end
      elseif doc.Type == "work_pass" then
        local workFields = doc.Data or {}
        if selectedField.key == "fullName" then
          docValue = workFields.holderName or ""
        end
      end
      
      if docValue ~= "" then
        if string.lower(passportValue) == string.lower(docValue) then
          table.insert(matches, {
            type = doc.Type,
            value = docValue,
            document = doc
          })
        else
          table.insert(discrepancies, {
            type = "field_mismatch",
            field = selectedField.label,
            passport = passportValue,
            other = docValue,
            documentType = doc.Type,
            severity = "high"
          })
        end
      end
    end
  end
  
  -- Display results in GUI instead of chat
  local results = {}
  local fieldName = selectedField and selectedField.label or "Campo Desconocido"
  local title = string.format("Comparación de Campo: %s", fieldName)
  
  if #discrepancies > 0 then
    table.insert(results, {text = "DISCREPANCIAS ENCONTRADAS:", color = Color(220, 100, 100)})
    
    for _, disc in ipairs(discrepancies) do
      table.insert(results, {
        text = string.format("  [ALTA] %s (%s): %s ≠ %s", disc.field, disc.documentType, disc.passport, disc.other),
        color = Color(255, 100, 100)
      })
    end
  else
    table.insert(results, {text = "✓ Todos los documentos coinciden en este campo", color = Color(100, 200, 100)})
  end
  
  if #matches > 0 then
    table.insert(results, {text = "DATOS COINCIDENTES:", color = Color(100, 200, 100)})
    for _, match in ipairs(matches) do
      table.insert(results, {
        text = string.format("  ✓ %s (%s): %s", match.type, match.documentType or "documento", match.value),
        color = Color(100, 200, 100)
      })
    end
  end
  
  Desk_ShowResultsGUI(desk, title, results, Color(100, 150, 200))
end

-- ===============================
-- INSPECTION SYSTEM FUNCTIONS
-- ===============================
-- Automatic inspection when documents are placed
function Desk_AutoInspect(desk)
  timer.Simple(0.5, function()
    if IsValid(desk) then
      Desk_InspectDocuments(desk)
    end
  end)
end

-- Enhanced document inspection system with GUI field selection
function Desk_InspectDocuments(desk)
  if not desk.DocumentsOnDesk or #desk.DocumentsOnDesk < 2 then
    Desk_ShowResultsGUI(desk, "Información", {"Se necesitan al menos 2 documentos para inspeccionar"}, Color(200, 150, 100))
    return
  end
  
  local documents = desk.DocumentsOnDesk
  local discrepancies = {}
  local matches = {}
  
  -- Find passport for field selection
  local passport = nil
  local entryPermit = nil
  local workPass = nil
  
  for _, doc in ipairs(documents) do
    if doc.Type == "passport" then
      passport = doc
    elseif doc.Type == "entry_permit" then
      entryPermit = doc
    elseif doc.Type == "work_pass" then
      workPass = doc
    end
  end
  
  -- If no passport, show general info
  if not passport then
    Desk_ShowResultsGUI(desk, "Información", {"No hay pasaporte para seleccionar campos"}, Color(200, 150, 100))
    return
  end
  
  -- Show field selection GUI
  local passportFields = passport.Data and passport.Data.fields or {}
  Desk_ShowFieldSelectionGUI(desk, passportFields)
end

-- GUI for field selection
local function Desk_ShowFieldSelectionGUI(desk, passportFields)
  -- Create field selection frame
  if IsValid(desk.FieldSelectionFrame) then
    desk.FieldSelectionFrame:Close()
  end
  
  desk.FieldSelectionFrame = vgui.Create("DFrame")
  local frame = desk.FieldSelectionFrame
  frame:SetTitle("Seleccionar Campo para Comparar")
  frame:SetSize(400, 500)
  frame:Center()
  frame:MakePopup()
  frame:SetBackgroundBlur(true)
  
  -- Main panel
  local mainPanel = frame:Add("DPanel")
  mainPanel:Dock(FILL)
  mainPanel:DockPadding(10, 10, 10, 10)
  
  -- Title label
  local titleLabel = mainPanel:Add("DLabel")
  titleLabel:SetFont("ixPassportUI")
  titleLabel:SetColor(Color(255, 255, 255))
  titleLabel:SetText("Selecciona el campo del pasaporte que quieres comparar:")
  titleLabel:Dock(TOP)
  titleLabel:SetTall(30)
  
  -- Scroll panel for field buttons
  local scrollPanel = mainPanel:Add("DScrollPanel")
  scrollPanel:Dock(FILL)
  
  -- Create field buttons
  for i, field in ipairs(PLUGIN.PassportFields or {}) do
    local fieldValue = passportFields[field.key] or "(vacío)"
    
    local fieldPanel = scrollPanel:Add("DPanel")
    fieldPanel:SetTall(50)
    fieldPanel:Dock(TOP)
    fieldPanel:DockMargin(0, 0, 0, 5)
    fieldPanel.Paint = function(_, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 70, 200))
      surface.SetDrawColor(255, 255, 255, 10)
      surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    -- Field number
    local numberLabel = fieldPanel:Add("DLabel")
    numberLabel:SetFont("ixPassportUI")
    numberLabel:SetColor(Color(200, 200, 200))
    numberLabel:SetText("[" .. i .. "]")
    numberLabel:SetPos(5, 5)
    numberLabel:SetSize(30, 20)
    
    -- Field name
    local nameLabel = fieldPanel:Add("DLabel")
    nameLabel:SetFont("ixPassportUI")
    nameLabel:SetColor(Color(255, 255, 255))
    nameLabel:SetText(field.label)
    nameLabel:SetPos(40, 5)
    nameLabel:SetSize(250, 20)
    
    -- Field value
    local valueLabel = fieldPanel:Add("DLabel")
    valueLabel:SetFont("ixPassportUI")
    valueLabel:SetColor(fieldValue ~= "(vacío)" and Color(100, 255, 100) or Color(200, 200, 200))
    valueLabel:SetText(fieldValue)
    valueLabel:SetPos(40, 25)
    valueLabel:SetSize(250, 20)
    
    -- Select button
    local selectBtn = fieldPanel:Add("DButton")
    selectBtn:SetFont("ixPassportUI")
    selectBtn:SetText("Comparar")
    selectBtn:SetSize(80, 20)
    selectBtn:SetPos(300, 25)
    selectBtn.DoClick = function()
      Desk_CompareSelectedFieldGUI(desk, i, passportFields)
      frame:Close()
    end
  end
  
  -- Instructions label
  local instructionsLabel = mainPanel:Add("DLabel")
  instructionsLabel:SetFont("ixPassportUI")
  instructionsLabel:SetColor(Color(150, 150, 255))
  instructionsLabel:SetText("Clic en 'Comparar' para verificar este campo con los demás documentos")
  instructionsLabel:Dock(BOTTOM)
  instructionsLabel:SetTall(40)
  instructionsLabel:DockMargin(0, 5, 0, 0)
end

-- Function to compare selected field using GUI selection
function Desk_CompareSelectedFieldGUI(desk, fieldIndex, passportFields)
  if not desk.PassportForComparison then
    Desk_ShowResultsGUI(desk, "Error", {"No hay pasaporte disponible"}, Color(200, 150, 100))
    return
  end
  
  local selectedField = PLUGIN.PassportFields and PLUGIN.PassportFields[fieldIndex]
  if not selectedField then
    Desk_ShowResultsGUI(desk, "Error", {"Campo no válido"}, Color(200, 150, 100))
    return
  end
  
  local passportValue = passportFields[selectedField.key] or ""
  local documents = desk.DocumentsOnDesk
  local discrepancies = {}
  local matches = {}
  
  -- Compare selected field with other documents
  for _, doc in ipairs(documents) do
    if doc ~= desk.PassportForComparison then
      local docValue = ""
      
      if doc.Type == "entry_permit" then
        local permitFields = doc.Data and doc.Data.fields or {}
        if selectedField.key == "fullName" then
          docValue = permitFields.holderName or ""
        elseif selectedField.key == "nationality" then
          docValue = permitFields.nationality or ""
        end
      elseif doc.Type == "work_pass" then
        local workFields = doc.Data or {}
        if selectedField.key == "fullName" then
          docValue = workFields.holderName or ""
        end
      end
      
      if docValue ~= "" then
        if string.lower(passportValue) == string.lower(docValue) then
          table.insert(matches, {
            type = doc.Type,
            value = docValue,
            document = doc
          })
        else
          table.insert(discrepancies, {
            type = "field_mismatch",
            field = selectedField.label,
            passport = passportValue,
            other = docValue,
            documentType = doc.Type,
            severity = "high"
          })
        end
      end
    end
  end
  
  -- Display results in GUI instead of chat
  local results = {}
  local fieldName = selectedField and selectedField.label or "Campo Desconocido"
  local title = string.format("Comparación de Campo: %s", fieldName)
  
  if #discrepancies > 0 then
    table.insert(results, {text = "DISCREPANCIAS ENCONTRADAS:", color = Color(220, 100, 100)})
    
    for _, disc in ipairs(discrepancies) do
      table.insert(results, {
        text = string.format("  [ALTA] %s (%s): %s ≠ %s", disc.field, disc.documentType, disc.passport, disc.other),
        color = Color(255, 100, 100)
      })
    end
  else
    table.insert(results, {text = "✓ Todos los documentos coinciden en este campo", color = Color(100, 200, 100)})
  end
  
  if #matches > 0 then
    table.insert(results, {text = "DATOS COINCIDENTES:", color = Color(100, 200, 100)})
    for _, match in ipairs(matches) do
      table.insert(results, {
        text = string.format("  ✓ %s (%s): %s", match.type, match.documentType or "documento", match.value),
        color = Color(100, 200, 100)
      })
    end
  end
  
  Desk_ShowResultsGUI(desk, title, results, Color(100, 150, 200))
end

-- ===============================
-- PANEL CONFIGURATION
-- ===============================
local SLIDE_TIME = 0.35
local SLIDE_EASE = 6

-- ===============================
-- Helper: calcular tamaño/posición
-- ===============================
local function CalcDeskRect()
  local sw, sh = ScrW(), ScrH()

  local w = math.floor(sw * 0.9)
  local h = math.floor(sh * 0.48)

  w = math.Clamp(w, 900, sw - 40)
  h = math.Clamp(h, 420, sh - math.floor(sh * 0.5) - 20)

  local x = math.floor((sw - w) / 2)
  local y = math.floor(sh * 0.5)

  return x, y, w, h
end

-- ===============================
-- INIT
-- ===============================
function PANEL:Init()
    self:SetTitle("Mesa de Inspección")
    self:SetDeleteOnClose(true)
    self:ShowCloseButton(false)

    if self.CloseOnEscape then
        self:CloseOnEscape(true)
    end

    self:MakePopup()

    if self.SetBackgroundBlur then
        self:SetBackgroundBlur(false)
    end

    self.bDrawBlur = false

    if IsValid(g_InspectionDesk) and g_InspectionDesk ~= self then
        g_InspectionDesk:Close()
    end
    g_InspectionDesk = self

    -- Initialize document tracking
    self.DocumentsOnDesk = {}
    self.DocumentCount = 0
    self.SelectedField = nil
    self.PassportForComparison = nil
    self.FieldSelectionFrame = nil

    -- Tamaño y animación de entrada
    local x, y, w, h = CalcDeskRect()
    self.TargetX = x
    self.TargetY = y

    self:SetSize(w, h)
    self:SetPos(x, ScrH() + h)

    self.AnimStart = SysTime()
    self.Animating = true

    -- Botón cerrar
    self.CloseBtn = vgui.Create("DButton", self)
    self.CloseBtn:SetText("✕")
    self.CloseBtn:SetFont("ixPassportUI")
    self.CloseBtn:SetSize(24, 24)
    self.CloseBtn:SetZPos(9999)
    self.CloseBtn.DoClick = function()
        self:Close()
    end
    self.CloseBtn.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h,
            s:IsHovered() and Color(180,60,60) or Color(60,60,60)
        )
        draw.SimpleText("✕", "ixPassportUI", w/2, h/2, color_white,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -------------------------------------------------
    -- MAIN CANVAS (TABLE) - OCCUPIES REMAINING SPACE
    -------------------------------------------------
    self.Canvas = self:Add("DPanel")
    self.Canvas:Dock(FILL)
    self.Canvas:DockMargin(0, 0, 0, 0)
    self.Canvas:DockPadding(8, 8, 8, 8)

    self.Canvas.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(55,52,48,220))
        surface.SetDrawColor(255,255,255,18)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    -------------------------------------------------
    -- UPPER CONTROL PANEL (Navigation and Seals)
    -------------------------------------------------
    self.ControlPanel = self.Canvas:Add("DPanel")
    self.ControlPanel:Dock(TOP)
    self.ControlPanel:SetTall(60)
    self.ControlPanel:DockMargin(0, 0, 0, 8)
    self.ControlPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(35, 32, 30, 240))
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    -- Navegación de páginas
    self.PageNavPanel = self.ControlPanel:Add("DPanel")
    self.PageNavPanel:SetSize(300, 50)
    self.PageNavPanel:SetPos(10, 5)
    self.PageNavPanel.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 45, 40, 180))
    end
    
    self.PrevPageBtn = self.PageNavPanel:Add("DButton")
    self.PrevPageBtn:SetText("← Pág Ant")
    self.PrevPageBtn:SetFont(FONT_UI)
    self.PrevPageBtn:SetSize(80, 25)
    self.PrevPageBtn:SetPos(5, 5)
    self.PrevPageBtn:SetEnabled(false)
    self.PrevPageBtn.DoClick = function()
        self:NavigatePage(-1)
    end
    
    self.NextPageBtn = self.PageNavPanel:Add("DButton")
    self.NextPageBtn:SetText("Pág Sig →")
    self.NextPageBtn:SetFont(FONT_UI)
    self.NextPageBtn:SetSize(80, 25)
    self.NextPageBtn:SetPos(90, 5)
    self.NextPageBtn:SetEnabled(false)
    self.NextPageBtn.DoClick = function()
        self:NavigatePage(1)
    end
    
    self.PageLabel = self.PageNavPanel:Add("DLabel")
    self.PageLabel:SetFont(FONT_UI)
    self.PageLabel:SetColor(color_white)
    self.PageLabel:SetText("Página 1/1")
    self.PageLabel:SizeToContents()
    self.PageLabel:SetPos(180, 8)
    
    self.AddPageBtn = self.PageNavPanel:Add("DButton")
    self.AddPageBtn:SetText("+ Página")
    self.AddPageBtn:SetFont(FONT_UI)
    self.AddPageBtn:SetSize(80, 25)
    self.AddPageBtn:SetPos(5, 30)
    self.AddPageBtn:SetEnabled(false)
    self.AddPageBtn.DoClick = function()
        self:AddNewPage()
    end
    
    -- Panel de sellos de aprobación
    self.StampPanel = self.ControlPanel:Add("DPanel")
    self.StampPanel:SetSize(400, 50)
    self.StampPanel:SetPos(320, 5)
    self.StampPanel.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 50, 40, 180))
    end
    
    self.ApproveBtn = self.StampPanel:Add("DButton")
    self.ApproveBtn:SetText("✓ APROBAR ENTRADA")
    self.ApproveBtn:SetFont(FONT_UI)
    self.ApproveBtn:SetSize(180, 25)
    self.ApproveBtn:SetPos(5, 5)
    self.ApproveBtn:SetEnabled(false)
    self.ApproveBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, 
            s:IsEnabled() and (s:IsHovered() and Color(80, 150, 80) or Color(60, 120, 60)) 
            or Color(80, 80, 80))
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.ApproveBtn.DoClick = function()
        self:StampDocument("approve")
    end
    
    self.DenyBtn = self.StampPanel:Add("DButton")
    self.DenyBtn:SetText("✕ DENEGAR ENTRADA")
    self.DenyBtn:SetFont(FONT_UI)
    self.DenyBtn:SetSize(180, 25)
    self.DenyBtn:SetPos(190, 5)
    self.DenyBtn:SetEnabled(false)
    self.DenyBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, 
            s:IsEnabled() and (s:IsHovered() and Color(150, 80, 80) or Color(120, 60, 60)) 
            or Color(80, 80, 80))
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.DenyBtn.DoClick = function()
        self:StampDocument("deny")
    end
    
    -- Estación actual (para mostrar en el sello)
    self.CurrentStationLabel = self.StampPanel:Add("DLabel")
    self.CurrentStationLabel:SetFont(FONT_UI)
    self.CurrentStationLabel:SetColor(Color(200, 200, 200))
    self.CurrentStationLabel:SetText("Estación: [Sin definir]")
    self.CurrentStationLabel:SizeToContents()
    self.CurrentStationLabel:SetPos(5, 30)
    
    -------------------------------------------------
    -- RIGHT PANEL (TRAY + BUTTONS)
    -------------------------------------------------
    self.RightPanel = self:Add("DPanel")
    self.RightPanel:Dock(RIGHT)
    self.RightPanel:DockPadding(8, 8, 8, 8)
    self.RightPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20,20,20,240))
    end

    -- Document buttons above the tray
    local docButtons = self.RightPanel:Add("DPanel")
    docButtons:Dock(TOP)
    docButtons:SetTall(140)
    docButtons:DockMargin(0, 0, 0, 8)
    docButtons.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
    end
    
    -- Search bar at the top
    local searchBar = docButtons:Add("DTextEntry")
    searchBar:Dock(TOP)
    searchBar:SetTall(25)
    searchBar:DockMargin(5, 5, 5, 5)
    searchBar:SetPlaceholderText("Buscar: nombre, titular, nacionalidad, en...")
    searchBar:SetFont("ixSmallFont")
    
    -- First row of buttons
    local buttonRow1 = docButtons:Add("DPanel")
    buttonRow1:Dock(TOP)
    buttonRow1:SetTall(30)
    buttonRow1:DockMargin(5, 0, 5, 5)
    buttonRow1.Paint = nil
    
    local btnWork = buttonRow1:Add("DButton")
    btnWork:SetSize(80, 30)
    btnWork:Dock(LEFT)
    btnWork:DockMargin(0, 0, 5, 0)
    btnWork:SetText("Trabajo")
    btnWork:SetTextColor(Color(255, 255, 255))
    btnWork.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnWork.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first work_pass item
        for _, item in pairs(items) do
            if item.uniqueID == "work_pass" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnPermit = buttonRow1:Add("DButton")
    btnPermit:SetSize(80, 30)
    btnPermit:Dock(LEFT)
    btnPermit:DockMargin(0, 0, 5, 0)
    btnPermit:SetText("Permiso")
    btnPermit:SetTextColor(Color(255, 255, 255))
    btnPermit.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnPermit.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first entry_permit item
        for _, item in pairs(items) do
            if item.uniqueID == "entry_permit" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnPassport = buttonRow1:Add("DButton")
    btnPassport:SetSize(80, 30)
    btnPassport:Dock(LEFT)
    btnPassport:SetText("Pasaporte")
    btnPassport:SetTextColor(Color(255, 255, 255))
    btnPassport.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnPassport.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first passport item
        for _, item in pairs(items) do
            if item.uniqueID == "passport" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    -- Second row of buttons (new documents)
    local buttonRow2 = docButtons:Add("DPanel")
    buttonRow2:Dock(TOP)
    buttonRow2:SetTall(30)
    buttonRow2:DockMargin(5, 0, 5, 5)
    buttonRow2.Paint = nil
    
    local btnIDCard = buttonRow2:Add("DButton")
    btnIDCard:SetSize(60, 30)
    btnIDCard:Dock(LEFT)
    btnIDCard:DockMargin(0, 0, 5, 0)
    btnIDCard:SetText("ID")
    btnIDCard:SetTextColor(Color(255, 255, 255))
    btnIDCard.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnIDCard.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first id_card item
        for _, item in pairs(items) do
            if item.uniqueID == "id_card" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnDiplomatic = buttonRow2:Add("DButton")
    btnDiplomatic:SetSize(75, 30)
    btnDiplomatic:Dock(LEFT)
    btnDiplomatic:DockMargin(0, 0, 5, 0)
    btnDiplomatic:SetText("Diplomático")
    btnDiplomatic:SetTextColor(Color(255, 255, 255))
    btnDiplomatic.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnDiplomatic.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first diplomatic_id item
        for _, item in pairs(items) do
            if item.uniqueID == "diplomatic_id" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnTransit = buttonRow2:Add("DButton")
    btnTransit:SetSize(70, 30)
    btnTransit:Dock(LEFT)
    btnTransit:DockMargin(0, 0, 5, 0)
    btnTransit:SetText("Tránsito")
    btnTransit:SetTextColor(Color(255, 255, 255))
    btnTransit.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnTransit.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first transit_permit item
        for _, item in pairs(items) do
            if item.uniqueID == "transit_permit" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnAccess = buttonRow2:Add("DButton")
    btnAccess:SetSize(60, 30)
    btnAccess:Dock(LEFT)
    btnAccess:DockMargin(0, 0, 5, 0)
    btnAccess:SetText("Acceso")
    btnAccess:SetTextColor(Color(255, 255, 255))
    btnAccess.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnAccess.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first access_ticket item
        for _, item in pairs(items) do
            if item.uniqueID == "access_ticket" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end
    
    local btnVaccine = buttonRow2:Add("DButton")
    btnVaccine:SetSize(65, 30)
    btnVaccine:Dock(LEFT)
    btnVaccine:SetText("Vacunas")
    btnVaccine:SetTextColor(Color(255, 255, 255))
    btnVaccine.Paint = function(_, w, h)
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(0, 0, w, h)
    end
    btnVaccine.DoClick = function()
        local char = LocalPlayer():GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end
        local items = inv:GetItems(true) or {}
        
        -- Find first vaccine_documents item
        for _, item in pairs(items) do
            if item.uniqueID == "vaccine_documents" then
                local frame = self:GetParent()
                while IsValid(frame) and not frame.WorkArea do
                    frame = frame:GetParent()
                end
                if IsValid(frame) and frame.WorkArea then
                    spawnSheetOnCanvas(frame.WorkArea, item)
                    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
                end
                break
            end
        end
    end

    self.Tray = self.RightPanel:Add("ixDocTray")
    self.Tray:Dock(TOP)
    self.Tray:SetTall(240)

    local controls = self.RightPanel:Add("DPanel")
    controls:Dock(TOP)
    controls:SetTall(44)
    controls.Paint = nil

    local refresh = controls:Add("DButton")
    refresh:Dock(LEFT)
    refresh:SetWide(140)
    refresh:SetText("Actualizar Bandeja")
    refresh.DoClick = function()
        if IsValid(self.Tray) then self.Tray:Rebuild() end
        surface.PlaySound("buttons/button15.wav")
    end

    local inspectBtn = controls:Add("DButton")
    inspectBtn:Dock(LEFT)
    inspectBtn:DockMargin(8,0,0,0)
    inspectBtn:SetWide(120)
    inspectBtn:SetText("Inspeccionar")
    inspectBtn.DoClick = function()
        Desk_InspectDocuments(self)
        surface.PlaySound("buttons/button14.wav")
    end

    local closeBtn = controls:Add("DButton")
    closeBtn:Dock(LEFT)
    closeBtn:DockMargin(8,0,0,0)
    closeBtn:SetWide(80)
    closeBtn:SetText("Cerrar")
    closeBtn.DoClick = function()
        self:Close()
    end

    -------------------------------------------------
    -- FLOATING DROPDOWN OF STAMPS - OVERLAPS THE WORK AREA
    -------------------------------------------------
    self.StampDropdown = self:Add("DPanel")
    self.StampDropdown:SetSize(200, 120)
    self.StampDropdown:SetPos(100, 100) -- Posición inicial
    self.StampDropdown:SetVisible(false)
    self.StampDropdown:SetZPos(9999) -- Siempre encima
    
    self.StampDropdown.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40,38,36,250))
        surface.SetDrawColor(255,255,255,30)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        
        -- Título
        draw.SimpleText("SELECCIONAR SELLO", "ixPassportUI", w/2, 15, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Hacer el dropdown arrastrable
    self.StampDropdown.Dragging = false
    self.StampDropdown.DragOffsetX = 0
    self.StampDropdown.DragOffsetY = 0

    self.StampDropdown.OnMousePressed = function(s, m)
        if m == MOUSE_LEFT then
            s.Dragging = true
            s:MouseCapture(true)
            local mx, my = gui.MousePos()
            local sx, sy = s:LocalToScreen(0, 0)
            s.DragOffsetX = mx - sx
            s.DragOffsetY = my - sy
            s:SetZPos(10000) -- Traer al frente mientras se arrastra
        end
    end

    self.StampDropdown.OnMouseReleased = function(s, m)
        if m == MOUSE_LEFT then
            s.Dragging = false
            s:MouseCapture(false)
            s:SetZPos(9999) -- Volver a Z normal
        end
    end

    self.StampDropdown.Think = function(s)
        if s.Dragging then
            local mx, my = gui.MousePos()
            local parent = s:GetParent()
            if IsValid(parent) then
                local px, py = parent:LocalToScreen(0, 0)
                s:SetPos(
                    math.Clamp(mx - px - s.DragOffsetX, 0, parent:GetWide() - s:GetWide()),
                    math.Clamp(my - py - s.DragOffsetY, 0, parent:GetTall() - s:GetTall())
                )
            end
        end
    end

    -- Botón para abrir/cerrar el dropdown flotante
    self.StampToggle = self:Add("DButton")
    self.StampToggle:SetSize(150, 30)
    self.StampToggle:SetPos(10, 10)
    self.StampToggle:SetText("🔨 SELLOS")
    self.StampToggle:SetFont("ixPassportUI")
    self.StampToggle:SetZPos(9998)

    self.StampToggle.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, 
            s:IsHovered() and Color(80,70,60) or Color(60,50,40))
        surface.SetDrawColor(255,255,255,20)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    self.StampToggle.DoClick = function()
        self.StampDropdown:SetVisible(not self.StampDropdown:IsVisible())
        if self.StampDropdown:IsVisible() then
            surface.PlaySound("buttons/button14.wav")
        end
    end

    -- Contenido del dropdown flotante
    self.StampSelector = self.StampDropdown:Add("DComboBox")
    self.StampSelector:Dock(FILL)
    self.StampSelector:DockMargin(5, 35, 5, 5)
    self.StampSelector:SetFont("ixPassportUI")
    self.StampSelector:SetValue("Seleccionar acción...")

    -- Firma AUTOMÁTICA por facción: el inspector solo decide APROBAR (sella con el
    -- sello de su facción) o DENEGAR. El servidor valida la autoridad y el sello.
    self.StampSelector:AddChoice("APROBAR (sello de mi facción)", "approve")
    self.StampSelector:AddChoice("DENEGAR ENTRADA", "deny")

    self.StampSelector.OnSelect = function(_, index, value, data)
        if (data == "approve" or data == "deny") then
            self:StampDocument(data)
        end
        self.StampSelector:SetValue("Seleccionar acción...")
        self.StampDropdown:SetVisible(false)
    end

    -- Botón para cerrar el dropdown flotante (X)
    self.StampCloseBtn = self.StampDropdown:Add("DButton")
    self.StampCloseBtn:SetSize(20, 20)
    self.StampCloseBtn:SetPos(180, 5)
    self.StampCloseBtn:SetText("✕")
    self.StampCloseBtn:SetFont("ixPassportUI")
    self.StampCloseBtn.DoClick = function()
        self.StampDropdown:SetVisible(false)
    end
    self.StampCloseBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, 
            s:IsHovered() and Color(180,60,60) or Color(120,40,40))
        draw.SimpleText("✕", "ixPassportUI", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -------------------------------------------------
    -- ÁREA DE TRABAJO (DOCUMENTOS)
    -------------------------------------------------
    self.WorkArea = self.Canvas:Add("DPanel")
    self.WorkArea:Dock(FILL)

    self.WorkArea.Paint = function(_, w, h)
        surface.SetDrawColor(64,59,52,200)
        surface.DrawRect(0,0,w,h)

        surface.SetDrawColor(0,0,0,14)
        for y = 0, h, 12 do
            surface.DrawLine(0, y, w, y)
        end

        -- Boletín del día + veredicto de asistencia (esquina superior izquierda)
        local lines = {}

        if (PLUGIN.GetBulletinSummary) then
            local stFaction = ""
            if (IsValid(self.DeskEntity) and self.DeskEntity.GetStationFaction) then
                stFaction = self.DeskEntity:GetStationFaction() or ""
            end
            for _, l in ipairs(PLUGIN:GetBulletinSummary(nil, stFaction)) do
                lines[#lines + 1] = { text = l, col = Color(220, 210, 180) }
            end
        end

        if (self.VerdictReasons and #self.VerdictReasons > 0) then
            lines[#lines + 1] = { text = "", col = color_white }
            for _, r in ipairs(self.VerdictReasons) do
                lines[#lines + 1] = { text = "- " .. r, col = Color(235, 175, 150) }
            end
        end

        if (#lines > 0) then
            local pad = 6
            surface.SetFont(FONT_UI)
            local boxW = 0
            for _, l in ipairs(lines) do
                local tw = surface.GetTextSize(l.text)
                if (tw > boxW) then boxW = tw end
            end
            local _, lineH = surface.GetTextSize("Ay")
            lineH = lineH + 1

            draw.RoundedBox(4, pad, pad, boxW + pad * 2, #lines * lineH + pad * 2, Color(20, 18, 16, 230))
            for i, l in ipairs(lines) do
                surface.SetTextColor(l.col)
                surface.SetTextPos(pad + 4, pad + 2 + (i - 1) * lineH)
                surface.DrawText(l.text)
            end
        end
    end
end

-- ===============================
-- NAVIGATION FUNCTIONS AND SEALS
-- ===============================
function PANEL:NavigatePage(direction)
    if not self.CurrentPassportPages or #self.CurrentPassportPages == 0 then return end
    
    self.CurrentPassportPage = (self.CurrentPassportPage or 1) + direction
    self.CurrentPassportPage = math.Clamp(self.CurrentPassportPage, 1, #self.CurrentPassportPages)
    
    self:UpdatePageControls()
    self:RefreshDocumentDisplay()
end

function PANEL:AddNewPage()
    if not self.CurrentPassportPages then return end
    
    local newPage = {
        pageNumber = #self.CurrentPassportPages + 1,
        stationStamps = {},
        notes = ""
    }
    
    table.insert(self.CurrentPassportPages, newPage)
    self.CurrentPassportPage = #self.CurrentPassportPages
    
    -- Save to server
    if self.CurrentPassportItemID then
        self:SavePagesToServer()
    end
    
    self:UpdatePageControls()
    self:RefreshDocumentDisplay()
end

function PANEL:UpdatePageControls()
    if not self.CurrentPassportPages or #self.CurrentPassportPages == 0 then
        if IsValid(self.PrevPageBtn) then self.PrevPageBtn:SetEnabled(false) end
        if IsValid(self.NextPageBtn) then self.NextPageBtn:SetEnabled(false) end
        if IsValid(self.AddPageBtn) then self.AddPageBtn:SetEnabled(false) end
        if IsValid(self.PageLabel) then self.PageLabel:SetText("Página 0/0") end
        return
    end
    
    local currentPage = self.CurrentPassportPage or 1
    local totalPages = #self.CurrentPassportPages
    local currentPageData = self.CurrentPassportPages[currentPage]
    local currentStamps = 0
    local maxStamps = PLUGIN.MultiPagePassport.MaxStampsPerPage or 2
    
    if currentPageData and currentPageData.stationStamps then
        currentStamps = #currentPageData.stationStamps
    end
    
    if IsValid(self.PrevPageBtn) then 
        self.PrevPageBtn:SetEnabled(currentPage > 1)
    end
    if IsValid(self.NextPageBtn) then 
        self.NextPageBtn:SetEnabled(currentPage < totalPages)
    end
    if IsValid(self.AddPageBtn) then 
        self.AddPageBtn:SetEnabled(totalPages < (PLUGIN.MultiPagePassport and PLUGIN.MultiPagePassport.MaxPages or 50))
    end
    if IsValid(self.PageLabel) then 
        self.PageLabel:SetText(string.format("Página %d/%d - Sellos: %d/%d", currentPage, totalPages, currentStamps, maxStamps))
    end
    
    -- Aprobar/Denegar dependen solo de tener documento activo y autoridad de firma
    -- (el sello de frontera crea página nueva automáticamente, sin límite por página).
    local canStamp = LocalCanInspect()
    if IsValid(self.ApproveBtn) then
        self.ApproveBtn:SetEnabled(canStamp and self.CurrentDocument ~= nil)
    end
    if IsValid(self.DenyBtn) then 
        self.DenyBtn:SetEnabled(canStamp and self.CurrentDocument ~= nil)
    end
end

-- itemIDs de todos los documentos colocados en la mesa (para validación servidor).
function PANEL:GetDeskItemIDs()
    local ids = {}
    if self.DocumentsOnDesk then
        for _, doc in ipairs(self.DocumentsOnDesk) do
            if IsValid(doc) and doc.ItemID then
                ids[#ids + 1] = doc.ItemID
            end
        end
    end
    return ids
end

function PANEL:StampDocument(action)
    if not IsValid(self.CurrentDocument) then
        chat.AddText(Color(220, 120, 120), "[Mesa] ", color_white, "No hay un documento activo para sellar.")
        return
    end

    action = (action == "approve") and "approve" or "deny"

    local ids = self:GetDeskItemIDs()
    local pageNum = (self.CurrentDocument.Type == "passport") and (self.CurrentPassportPage or 1) or 0

    -- El servidor valida la autoridad de la facción, aplica el sello correcto,
    -- comprueba el boletín del día y multa si la decisión es errónea.
    net.Start("ix.pp.DeskDecision")
        net.WriteEntity(self.DeskEntity)
        net.WriteString(action)
        net.WriteUInt(self.CurrentDocument.ItemID or 0, 32)
        net.WriteUInt(pageNum, 8)
        net.WriteUInt(math.min(#ids, 12), 8)
        for i = 1, math.min(#ids, 12) do
            net.WriteUInt(ids[i], 32)
        end
    net.SendToServer()

    surface.PlaySound("physics/cardboard/cardboard_box_impact_hard2.wav")
end

-- Pide al servidor un veredicto de asistencia (no sella) para los documentos
-- actualmente en la mesa, y lo muestra de forma pasiva.
function PANEL:RequestVerdict()
    if not IsValid(self.DeskEntity) then return end

    local ids = self:GetDeskItemIDs()

    net.Start("ix.pp.RequestVerdict")
        net.WriteEntity(self.DeskEntity)
        net.WriteUInt(math.min(#ids, 12), 8)
        for i = 1, math.min(#ids, 12) do
            net.WriteUInt(ids[i], 32)
        end
    net.SendToServer()
end

function PANEL:GetCurrentStationName()
    if (IsValid(self.DeskEntity) and self.DeskEntity.GetStationName) then
        local name = self.DeskEntity:GetStationName()
        if (name and name != "") then return name end
    end
    local stationName = "Sin definir"
    
    return stationName
end

function PANEL:SavePagesToServer()
    -- This would sync the pages to the server
    -- For now, the individual stamp operations handle this
end

function PANEL:RefreshDocumentDisplay()
    -- Refresh the display of the current document
    if IsValid(self.CurrentDocument) then
        self.CurrentDocument:InvalidateLayout(true)
    end
end

function PANEL:SetCurrentDocument(doc)
    self.CurrentDocument = doc
    
    -- Update passport page info if it's a passport
    if doc and doc.Type == "passport" then
        self.CurrentPassportItemID = doc.ItemID
        self.CurrentPassportPages = doc.Data.pages or {
            {
                pageNumber = 1,
                stationStamps = {},
                notes = ""
            }
        }
        self.CurrentPassportPage = 1
    else
        self.CurrentPassportItemID = nil
        self.CurrentPassportPages = nil
        self.CurrentPassportPage = nil
    end
    
    -- Update controls
    self:UpdatePageControls()
    
    -- Habilitar sellos solo si hay documento Y el jugador tiene autoridad de firma
    local canStamp = IsValid(doc) and LocalCanInspect()
    if IsValid(self.ApproveBtn) then self.ApproveBtn:SetEnabled(canStamp) end
    if IsValid(self.DenyBtn) then self.DenyBtn:SetEnabled(canStamp) end
    
    -- Update station label
    if IsValid(self.CurrentStationLabel) then
        local stFaction = ""
        if (IsValid(self.DeskEntity) and self.DeskEntity.GetStationFaction) then
            stFaction = self.DeskEntity:GetStationFaction() or ""
        end
        local label = "Estación: " .. self:GetCurrentStationName()
        if (stFaction != "") then
            local display = string.gsub(stFaction, ",", ", ")
            label = label .. " (" .. display .. ")"
        end
        self.CurrentStationLabel:SetText(label)
        self.CurrentStationLabel:SizeToContents()
    end

    -- Pedir veredicto solo si hay al menos 2 documentos en la mesa (evita el
    -- "falta passport" cuando acabas de poner el primero y aún no has puesto el resto).
    if (self.DocumentsOnDesk and #self.DocumentsOnDesk >= 2) then
        self:RequestVerdict()
    else
        self.Verdict = nil
        self.VerdictReasons = nil
    end
end

-- Guarda el veredicto recibido del servidor para mostrarlo en el área de trabajo.
function PANEL:SetVerdict(verdict, reasons, final)
    self.Verdict = verdict
    self.VerdictReasons = reasons or {}
    self.VerdictFinal = final or false
end

-- ===============================
-- THINK: ANIMACIÓN DE DESLIZAMIENTO
-- ===============================
function PANEL:Think()
  -- Actualizar etiqueta de estación en tiempo real (NetworkVar puede cambiar)
  if (IsValid(self.CurrentStationLabel) and IsValid(self.DeskEntity)) then
    local stName = self.DeskEntity.GetStationName and self.DeskEntity:GetStationName() or "Sin definir"
    local stFaction = self.DeskEntity.GetStationFaction and self.DeskEntity:GetStationFaction() or ""
    local label = "Estación: " .. (stName != "" and stName or "Sin definir")
    if (stFaction != "") then
      local display = string.gsub(stFaction, ",", ", ")
      label = label .. " (" .. display .. ")"
    end
    self.CurrentStationLabel:SetText(label)
    self.CurrentStationLabel:SizeToContents()
  end

  if not self.Animating then return end

  local frac = math.Clamp((SysTime() - self.AnimStart) / SLIDE_TIME, 0, 1)
  local ease = 1 - math.exp(-SLIDE_EASE * frac)

  local _, yTarget = self.TargetX, self.TargetY
  local startY = ScrH() + self:GetTall()
  local curY = Lerp(ease, startY, yTarget)

  self:SetPos(self.TargetX, curY)

  if frac >= 1 then
    self:SetPos(self.TargetX, yTarget)
    self.Animating = false
  end
end

-- ===============================
-- Layout dinámico (responsive)
-- ===============================
function PANEL:PerformLayout(w, h)
  local rightW = math.floor(w * 0.26)
  rightW = math.Clamp(rightW, 260, 360)

  if IsValid(self.RightPanel) then
    self.RightPanel:SetWide(rightW)
  end

  if IsValid(self.CloseBtn) then
    self.CloseBtn:SetPos(w - 28, 4)
  end
end

function PANEL:OnScreenSizeChanged()
  if not IsValid(self) then return end
  local x, y, w, h = CalcDeskRect()
  self:SetSize(w, h)
  self:SetPos(x, y)
end

function PANEL:OnRemove()
  if g_InspectionDesk == self then
    g_InspectionDesk = nil
  end
end

-- ===============================
-- Registro
-- ===============================
local function registerDesk()
  local base = vgui.GetControlTable("ixFrame") and "ixFrame" or "DFrame"
  vgui.Register("ixInspectionDesk", PANEL, base)
end
timer.Simple(0, registerDesk)

---------------------------------------------------------
-- Red
---------------------------------------------------------
net.Receive("ix.passport.OpenDesk", function()
  local ent = net.ReadEntity()
  if IsValid(g_InspectionDesk) then g_InspectionDesk:Close() end
  local f = vgui.Create("ixInspectionDesk")
  if IsValid(f) then f.DeskEntity = ent; g_InspectionDesk = f end
end)

net.Receive("ix.pp.ConfiscateResult", function()
  local ok  = net.ReadBool()
  local msg = net.ReadString() or ""
  chat.AddText(ok and Color(120,200,120) or Color(220,120,120), "[Mesa] ", color_white, msg)
end)

net.Receive("ix.pp.StampResult", function()
  local ok     = net.ReadBool()
  local msg    = net.ReadString() or ""
  local itemID = net.ReadUInt(32) or 0
  local stamp  = net.ReadString() or ""
  local docTyp = net.ReadString() or ""
  if msg ~= "" then chat.AddText(ok and Color(120,200,120) or Color(220,120,120), "[Mesa] ", color_white, msg) end
  if not ok or itemID == 0 then return end
  local pane = OPEN_SHEETS[itemID]
  if not IsValid(pane) then return end
  pane.Data = pane.Data or {}; pane.Data.stamp = stamp; pane:InvalidateLayout(true)
  
  -- Update inspection desk if this passport is currently displayed
  for _, desk in ipairs(vgui.GetWorldPanel():GetChildren()) do
    if IsValid(desk) and desk.SetCurrentDocument and desk.CurrentDocument and desk.CurrentDocument.ItemID == itemID then
      desk:RefreshDocumentDisplay()
      break
    end
  end
end)

net.Receive("ix.pp.StationStampResult", function()
  local ok = net.ReadBool()
  local msg = net.ReadString() or ""
  
  chat.AddText(
    ok and Color(120, 200, 120) or Color(220, 120, 120),
    "[Mesa] ",
    color_white,
    msg
  )
  
  -- Update any open inspection desks with the passport
  for _, desk in ipairs(vgui.GetWorldPanel():GetChildren()) do
    if IsValid(desk) and desk.SetCurrentDocument and desk.CurrentDocument and desk.CurrentDocument.Type == "passport" then
      -- Request updated pages from server
      if desk.CurrentPassportItemID then
        net.Start("ix.pp.GetPassportPages")
          net.WriteUInt(desk.CurrentPassportItemID, 32)
        net.SendToServer()
      end
      break
    end
  end
end)

net.Receive("ix.pp.PassportPagesData", function()
  local pages = net.ReadTable() or {}
  
  -- Update any open inspection desks with the passport
  for _, desk in ipairs(vgui.GetWorldPanel():GetChildren()) do
    if IsValid(desk) and desk.SetCurrentDocument and desk.CurrentDocument and desk.CurrentDocument.Type == "passport" then
      desk.CurrentPassportPages = pages
      desk.CurrentDocument.Data.pages = pages
      -- Saltar a la última página, donde acaba de aparecer el sello de frontera.
      desk.CurrentPassportPage = math.max(1, #pages)
      desk:UpdatePageControls()
      desk:RefreshDocumentDisplay()
      break
    end
  end
end)

net.Receive("ix.passport.DeskPassportData", function() end)

-- Veredicto de asistencia (no vinculante): solo actualiza la sugerencia mostrada.
net.Receive("ix.pp.AssistVerdict", function()
  local verdict = net.ReadString()
  local n = net.ReadUInt(5)
  local reasons = {}
  for i = 1, n do reasons[i] = net.ReadString() end

  if IsValid(g_InspectionDesk) and g_InspectionDesk.SetVerdict then
    g_InspectionDesk:SetVerdict(verdict, reasons, false)
  end
end)

-- Resultado de la decisión del inspector: sello aplicado + acierto/multa.
net.Receive("ix.pp.DeskResult", function()
  local action = net.ReadString()
  local itemID = net.ReadUInt(32)
  local stamp  = net.ReadString()
  local uid    = net.ReadString()
  local pages  = net.ReadTable() or {}

  -- Actualizar el documento en la mesa
  local pane = OPEN_SHEETS[itemID]
  if IsValid(pane) then
    pane.Data = pane.Data or {}
    if (uid == "passport") then
      -- Aplicar páginas actualizadas directamente (sin round-trip extra)
      pane.Data.pages = pages
    else
      pane.Data.stamp = stamp
    end
    pane:InvalidateLayout(true)
  end

  chat.AddText(
    (action == "approve") and Color(120,200,120) or Color(220,150,120),
    "[Frontera] ", color_white,
    string.format("Has %s el documento.", (action == "approve") and "APROBADO" or "DENEGADO")
  )

  -- Actualizar la mesa en tiempo real
  if IsValid(g_InspectionDesk) then
    if (uid == "passport") then
      g_InspectionDesk.CurrentPassportPages = pages
      if IsValid(g_InspectionDesk.CurrentDocument) then
        g_InspectionDesk.CurrentDocument.Data.pages = pages
      end
      -- Saltar a la última página (donde está el sello nuevo)
      g_InspectionDesk.CurrentPassportPage = math.max(1, #pages)
      g_InspectionDesk:UpdatePageControls()
    end
    g_InspectionDesk:RefreshDocumentDisplay()
  end
end)

-- Preload textures when the file loads
timer.Simple(0, function()
  preloadTextures()
end)

local function Desk_CompareFields(desk)
  local slots = desk.CompareSlots or {}
  local a, b = slots[1], slots[2]
  desk.CompareSlots = {}
  if not a or not b or a.key ~= b.key then return end
  local va = a.doc and a.doc.Data and a.doc.Data.fields and a.doc.Data.fields[a.key]
  local vb = b.doc and b.doc.Data and b.doc.Data.fields and b.doc.Data.fields[b.key]
  if tostring(va) == tostring(vb) then
    chat.AddText(Color(120,200,120), "[Comparación] Coinciden: ", color_white, tostring(va))
  else
    chat.AddText(Color(220,120,120), "[Comparación] NO coinciden: ", color_white, tostring(va), " ≠ ", tostring(vb))
  end
end

-- GUI for displaying inspection results
function Desk_ShowResultsGUI(desk, title, results, titleColor)
  -- Close any existing results frame
  if IsValid(desk.ResultsFrame) then
    desk.ResultsFrame:Close()
  end
  
  desk.ResultsFrame = vgui.Create("DFrame")
  local frame = desk.ResultsFrame
  frame:SetTitle(title)
  frame:SetSize(500, 400)
  frame:Center()
  frame:MakePopup()
  frame:SetBackgroundBlur(true)
  
  -- Main panel
  local mainPanel = frame:Add("DPanel")
  mainPanel:Dock(FILL)
  mainPanel:DockPadding(10, 10, 10, 10)
  
  -- Title label
  local titleLabel = mainPanel:Add("DLabel")
  titleLabel:SetFont("ixPassportUI")
  titleLabel:SetColor(titleColor or Color(255, 255, 255))
  titleLabel:SetText(title)
  titleLabel:Dock(TOP)
  titleLabel:SetTall(30)
  
  -- Scroll panel for results
  local scrollPanel = mainPanel:Add("DScrollPanel")
  scrollPanel:Dock(FILL)
  
  -- Display results
  for i, result in ipairs(results) do
    local resultLabel = scrollPanel:Add("DLabel")
    resultLabel:SetFont("ixPassportUI")
    local text = isstring(result) and result or (result.text or "")
    local col = istable(result) and result.color or Color(255, 255, 255)
    resultLabel:SetColor(col)
    resultLabel:SetText(text)
    resultLabel:Dock(TOP)
    resultLabel:SetTall(25)
    resultLabel:DockMargin(0, 0, 0, 2)
  end
  
  -- Close button
  local closeBtn = mainPanel:Add("DButton")
  closeBtn:SetFont("ixPassportUI")
  closeBtn:SetText("Cerrar")
  closeBtn:SetTall(30)
  closeBtn:Dock(BOTTOM)
  closeBtn:DockMargin(0, 10, 0, 0)
  closeBtn.DoClick = function()
    frame:Close()
  end
end

-- (El registro de ixInspectionDesk lo hace registerDesk() más arriba, eligiendo
--  ixFrame si está disponible; no lo dupliques aquí con base DFrame.)

