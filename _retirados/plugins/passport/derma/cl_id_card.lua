local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
	self:SetTitle("Tarjeta de Identidad")
	self:SetSize(520, 460)
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
	addLine("Ciudadanía")
	addLine("Fecha de nacimiento")
	addLine("Número de ID")
	addLine("Emitido")
	addLine("Caduca")
end

function V:SetIDCardData(d)
	d = d or {}
	local lines = {
		d.holderName or "—",
		d.citizenship or "—",
		d.birthDate or "—",
		d.idNumber or "—",
		d.issuedWhen and os.date("%d/%m/%Y", d.issuedWhen) or "—",
		d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—",
	}
	for i, L in ipairs(self.labels or {}) do
		local base = L:GetText():match("^(.-):")
		L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
	end
end

local function regViewer()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixIDCardViewer", V, "ixFrame")
	else
		vgui.Register("ixIDCardViewer", V, "DFrame")
	end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_idcard_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
	self:SetTitle("Editar Tarjeta de Identidad")
	self:SetSize(600, 480)
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
	self.citizenEntry = addField("Ciudadanía", function() return sp:Add("DTextEntry") end)
	self.birthEntry = addField("Fecha de nacimiento", function() return sp:Add("DTextEntry") end)
	self.idNumEntry = addField("Número de ID", function() return sp:Add("DTextEntry") end)

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
			citizenship = panel.citizenEntry:GetText(),
			birthDate = panel.birthEntry:GetText(),
			idNumber = panel.idNumEntry:GetText()
		}
		net.Start("ix.pp.SaveIDCard")
			net.WriteUInt(panel.itemID, 32)
			net.WriteTable(data)
		net.SendToServer()
		panel:Close()
	end
end

function E:SetItem(item)
	self.itemID = item and item.id or 0
	local d = item and item:GetData("idcard", {}) or {}
	if (d.holderName) then self.nameEntry:SetText(d.holderName) end
	if (d.citizenship) then self.citizenEntry:SetText(d.citizenship) end
	if (d.birthDate) then self.birthEntry:SetText(d.birthDate) end
	if (d.idNumber) then self.idNumEntry:SetText(d.idNumber) end
end

local function regEditor()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixIDCardEditor", E, "ixFrame")
	else
		vgui.Register("ixIDCardEditor", E, "DFrame")
	end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_idcard_editor", regEditor)
