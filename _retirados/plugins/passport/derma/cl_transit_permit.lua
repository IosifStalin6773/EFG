local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
	self:SetTitle("Permiso de Tránsito")
	self:SetSize(520, 500)
	self:Center()
	self:MakePopup()

	self.body = self:Add("DScrollPanel")
	self.body:Dock(FILL)

	self.labels = {}
	local function addLine(label)
		local L = self.body:Add("DLabel")
		L:Dock(TOP)
		L:SetFont("ixPassportUI")
		L:SetText(label .. ": —")
		L:DockMargin(0, 2, 0, 0)
		self.labels[#self.labels + 1] = L
	end

	addLine("Titular")
	addLine("Origen")
	addLine("Destino")
	addLine("Motivo")
	addLine("Nº Tránsito")
	addLine("Emitido")
	addLine("Válido hasta")
end

function V:SetTransitData(d)
	d = d or {}
	local lines = {
		d.holderName or "—",
		d.origin or "—",
		d.destination or "—",
		d.purpose or "—",
		d.transitNumber or "—",
		d.issuedWhen and os.date("%d/%m/%Y %H:%M", d.issuedWhen) or "—",
		d.expiresAt and os.date("%d/%m/%Y %H:%M", d.expiresAt) or "—",
	}
	for i, L in ipairs(self.labels or {}) do
		local base = L:GetText():match("^(.-):")
		L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
	end
end

local function regViewer()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixTransitPermitViewer", V, "ixFrame")
	else
		vgui.Register("ixTransitPermitViewer", V, "DFrame")
	end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_transit_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
	self:SetTitle("Editar Permiso de Tránsito")
	self:SetSize(600, 540)
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
	self.originEntry = addField("Origen", function() return sp:Add("DTextEntry") end)
	self.destEntry = addField("Destino", function() return sp:Add("DTextEntry") end)

	self.purposeBox = addField("Motivo", function()
		local c = sp:Add("DComboBox")
		c:AddChoice("Tránsito")
		c:AddChoice("Comercio")
		c:AddChoice("Evacuación")
		c:AddChoice("Misión")
		c:SetValue("Tránsito")
		return c
	end)

	self.transitNumEntry = addField("Nº Tránsito", function() return sp:Add("DTextEntry") end)

	self.hoursEntry = addField("Duración (horas, 1-168)", function()
		local n = sp:Add("DNumberWang")
		n:SetMinMax(1, 168)
		n:SetValue(24)
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
			holderName = panel.nameEntry:GetText(),
			origin = panel.originEntry:GetText(),
			destination = panel.destEntry:GetText(),
			purpose = panel.purposeBox:GetValue(),
			transitNumber = panel.transitNumEntry:GetText(),
			validHours = tonumber(panel.hoursEntry:GetValue()) or 24
		}
		net.Start("ix.pp.SaveTransitPermit")
			net.WriteUInt(panel.itemID, 32)
			net.WriteTable(data)
		net.SendToServer()
		panel:Close()
	end
end

function E:SetItem(item)
	self.itemID = item and item.id or 0
	local d = item and item:GetData("transit", {}) or {}
	if (d.holderName) then self.nameEntry:SetText(d.holderName) end
	if (d.origin) then self.originEntry:SetText(d.origin) end
	if (d.destination) then self.destEntry:SetText(d.destination) end
	if (d.purpose) then self.purposeBox:SetValue(d.purpose) end
	if (d.transitNumber) then self.transitNumEntry:SetText(d.transitNumber) end
end

local function regEditor()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixTransitPermitEditor", E, "ixFrame")
	else
		vgui.Register("ixTransitPermitEditor", E, "DFrame")
	end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_transit_editor", regEditor)
