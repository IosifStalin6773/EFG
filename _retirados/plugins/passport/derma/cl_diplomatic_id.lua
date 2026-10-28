local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
	self:SetTitle("Documento Diplomático")
	self:SetSize(520, 480)
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
	addLine("Cargo")
	addLine("Embajada")
	addLine("Nº Acreditación")
	addLine("Emitido")
	addLine("Caduca")
end

function V:SetDiplomaticData(d)
	d = d or {}
	local lines = {
		d.holderName or "—",
		d.position or "—",
		d.embassy or "—",
		d.accreditationNumber or "—",
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
		vgui.Register("ixDiplomaticIDViewer", V, "ixFrame")
	else
		vgui.Register("ixDiplomaticIDViewer", V, "DFrame")
	end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_diplomatic_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
	self:SetTitle("Editar ID Diplomático")
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
	self.positionEntry = addField("Cargo", function() return sp:Add("DTextEntry") end)
	self.embassyEntry = addField("Embajada", function() return sp:Add("DTextEntry") end)
	self.accredEntry = addField("Nº Acreditación", function() return sp:Add("DTextEntry") end)

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
			position = panel.positionEntry:GetText(),
			embassy = panel.embassyEntry:GetText(),
			accreditationNumber = panel.accredEntry:GetText()
		}
		net.Start("ix.pp.SaveDiplomaticID")
			net.WriteUInt(panel.itemID, 32)
			net.WriteTable(data)
		net.SendToServer()
		panel:Close()
	end
end

function E:SetItem(item)
	self.itemID = item and item.id or 0
	local d = item and item:GetData("diplomatic", {}) or {}
	if (d.holderName) then self.nameEntry:SetText(d.holderName) end
	if (d.position) then self.positionEntry:SetText(d.position) end
	if (d.embassy) then self.embassyEntry:SetText(d.embassy) end
	if (d.accreditationNumber) then self.accredEntry:SetText(d.accreditationNumber) end
end

local function regEditor()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixDiplomaticIDEditor", E, "ixFrame")
	else
		vgui.Register("ixDiplomaticIDEditor", E, "DFrame")
	end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_diplomatic_editor", regEditor)
