local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
    self:SetTitle("Permiso de Entrada")
    self:SetSize(520, 460)
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

    -- Placeholder; se rellena en SetPermitData
    addLine("Titular", "")
    addLine("Nacionalidad", "")
    addLine("Propósito", "")
    addLine("Duración (días)", "")
    addLine("Ciudad emisora", "")
    addLine("Emitido", "")
    addLine("Caduca", "")
end

function V:SetPermitData(d)
    d = d or {}
    local lines = {
        d.holderName or "—",
        d.nationality or "—",
        d.purpose or "—",
        tostring(d.durationDays or "—"),
        d.issuingCity or "—",
        d.issuedWhen and os.date("%d/%m/%Y", d.issuedWhen) or "—",
        d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—",
    }
    for i, L in ipairs(self.labels or {}) do
        local base = L:GetText():match("^(.-):")
        L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
    end
end

-- Registrar viewer
local function regViewer()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixEntryPermitViewer", V, "ixFrame")
    else
        vgui.Register("ixEntryPermitViewer", V, "DFrame")
    end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_entry_permit_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
    self:SetTitle("Editar Permiso de Entrada")
    self:SetSize(600, 520)
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
    self.natEntry  = addField("Nacionalidad", function() return sp:Add("DTextEntry") end)

    self.purposeBox = addField("Propósito", function()
        local c = sp:Add("DComboBox")
        c:AddChoice("Visita")
        c:AddChoice("Trabajo")
        c:AddChoice("Tránsito")
        c:AddChoice("Residencia")
        c:SetValue("Visita")
        return c
    end)

    self.durEntry = addField("Duración (días)", function()
        local n = sp:Add("DNumberWang")
        n:SetMinMax(1, 180)
        n:SetValue(7)
        return n
    end)

    self.cityEntry = addField("Ciudad emisora", function() return sp:Add("DTextEntry") end)

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
            nationality = panel.natEntry:GetText(),
            purpose     = panel.purposeBox:GetValue() or "Visita",
            durationDays= tonumber(panel.durEntry:GetValue()) or 7,
            issuingCity = panel.cityEntry:GetText()
        }
        net.Start("ix.pp.SaveEntryPermit")
            net.WriteUInt(panel.itemID, 32)
            net.WriteTable(data)
        net.SendToServer()
        panel:Close()
    end
end

function E:SetItem(item)
    self.itemID = item and item.id or 0
    local d = item and item:GetData("permit", {}) or {}
    if (d.holderName) then self.nameEntry:SetText(d.holderName) end
    if (d.nationality) then self.natEntry:SetText(d.nationality) end
    if (d.purpose) then self.purposeBox:SetValue(d.purpose) end
    if (d.durationDays) then self.durEntry:SetValue(d.durationDays) end
    if (d.issuingCity) then self.cityEntry:SetText(d.issuingCity) end
end

-- Registrar editor
local function regEditor()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixEntryPermitEditor", E, "ixFrame")
    else
        vgui.Register("ixEntryPermitEditor", E, "DFrame")
    end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_entry_permit_editor", regEditor)