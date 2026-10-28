local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
	self:SetTitle("Boleto de Acceso")
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
	addLine("Nivel de acceso")
	addLine("Fecha válida")
	addLine("Motivo")
	addLine("Nº Boleto")
	addLine("Emitido")
end

function V:SetTicketData(d)
	d = d or {}
	local lines = {
		d.holderName or "—",
		d.accessLevel or "—",
		d.validDate or "—",
		d.purpose or "—",
		d.ticketNumber or "—",
		d.issuedWhen and os.date("%d/%m/%Y", d.issuedWhen) or "—",
	}
	for i, L in ipairs(self.labels or {}) do
		local base = L:GetText():match("^(.-):")
		L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
	end
end

local function regViewer()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixAccessTicketViewer", V, "ixFrame")
	else
		vgui.Register("ixAccessTicketViewer", V, "DFrame")
	end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_ticket_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
	self:SetTitle("Editar Boleto de Acceso")
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

	self.levelBox = addField("Nivel de acceso", function()
		local c = sp:Add("DComboBox")
		c:AddChoice("General")
		c:AddChoice("Restringido")
		c:AddChoice("Militar")
		c:AddChoice("VIP")
		c:SetValue("General")
		return c
	end)

	self.dateEntry = addField("Fecha válida (DD/MM/AAAA)", function() return sp:Add("DTextEntry") end)

	self.purposeEntry = addField("Motivo", function() return sp:Add("DTextEntry") end)

	self.ticketNumEntry = addField("Nº Boleto", function() return sp:Add("DTextEntry") end)

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
			accessLevel = panel.levelBox:GetValue(),
			validDate = panel.dateEntry:GetText(),
			purpose = panel.purposeEntry:GetText(),
			ticketNumber = panel.ticketNumEntry:GetText()
		}
		net.Start("ix.pp.SaveAccessTicket")
			net.WriteUInt(panel.itemID, 32)
			net.WriteTable(data)
		net.SendToServer()
		panel:Close()
	end
end

function E:SetItem(item)
	self.itemID = item and item.id or 0
	local d = item and item:GetData("ticket", {}) or {}
	if (d.holderName) then self.nameEntry:SetText(d.holderName) end
	if (d.accessLevel) then self.levelBox:SetValue(d.accessLevel) end
	if (d.validDate) then self.dateEntry:SetText(d.validDate) end
	if (d.purpose) then self.purposeEntry:SetText(d.purpose) end
	if (d.ticketNumber) then self.ticketNumEntry:SetText(d.ticketNumber) end
end

local function regEditor()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixAccessTicketEditor", E, "ixFrame")
	else
		vgui.Register("ixAccessTicketEditor", E, "DFrame")
	end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_ticket_editor", regEditor)
