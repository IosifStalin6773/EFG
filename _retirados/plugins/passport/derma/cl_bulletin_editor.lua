-- derma/cl_bulletin_editor.lua
-- Panel VGUI para editar boletines de frontera (solo admins).
local PLUGIN = PLUGIN

local FONT_UI = "ixPassportUI"
local DOC_TYPES = {
	{ id = "passport",          label = "Pasaporte" },
	{ id = "entry_permit",      label = "Permiso de Entrada" },
	{ id = "work_pass",         label = "Pase de Trabajo" },
	{ id = "id_card",           label = "Tarjeta de Identidad" },
	{ id = "diplomatic_id",     label = "ID Diplomático" },
	{ id = "transit_permit",    label = "Permiso de Tránsito" },
	{ id = "access_ticket",     label = "Boleto de Acceso" },
	{ id = "vaccine_documents", label = "Doc. Vacunas" },
}

local g_BulletinEditor

---------------------------------------------------------
-- Panel principal
---------------------------------------------------------
local PANEL = {}

function PANEL:Init()
	self:SetTitle("Editor de Boletines de Frontera")
	self:SetSize(700, 520)
	self:Center()
	self:MakePopup()

	if IsValid(g_BulletinEditor) then g_BulletinEditor:Close() end
	g_BulletinEditor = self

	self.Bulletins = {}

	-- Lista izquierda
	self.LeftPanel = self:Add("DPanel")
	self.LeftPanel:Dock(LEFT)
	self.LeftPanel:SetWide(200)
	self.LeftPanel:DockMargin(0, 0, 8, 0)
	self.LeftPanel.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(30, 28, 26, 240))
	end

	local listLabel = self.LeftPanel:Add("DLabel")
	listLabel:Dock(TOP)
	listLabel:SetFont(FONT_UI)
	listLabel:SetText("Boletines")
	listLabel:SetTall(24)
	listLabel:DockMargin(8, 4, 8, 0)

	self.BulletinList = self.LeftPanel:Add("DScrollPanel")
	self.BulletinList:Dock(FILL)
	self.BulletinList:DockMargin(4, 4, 4, 4)

	local btnNew = self.LeftPanel:Add("DButton")
	btnNew:Dock(BOTTOM)
	btnNew:SetTall(28)
	btnNew:SetText("+ Nuevo Boletín")
	btnNew:SetFont(FONT_UI)
	btnNew:DockMargin(4, 0, 4, 4)
	btnNew.DoClick = function()
		self:CreateNewBulletin()
	end

	-- Editor derecho
	self.RightPanel = self:Add("DPanel")
	self.RightPanel:Dock(FILL)
	self.RightPanel.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(35, 32, 30, 240))
	end

	self:BuildEditorPanel()
	self:RequestData()
end

function PANEL:RequestData()
	net.Start("ix.pp.RequestBulletins")
	net.SendToServer()
end

function PANEL:BuildEditorPanel()
	if IsValid(self.EditorScroll) then self.EditorScroll:Remove() end

	self.EditorScroll = self.RightPanel:Add("DScrollPanel")
	self.EditorScroll:Dock(FILL)
	self.EditorScroll:DockMargin(8, 8, 8, 8)

	local sp = self.EditorScroll

	-- Nombre
	local nameLabel = sp:Add("DLabel")
	nameLabel:Dock(TOP)
	nameLabel:SetFont(FONT_UI)
	nameLabel:SetText("Nombre del boletín:")
	nameLabel:SetTall(20)

	self.NameEntry = sp:Add("DTextEntry")
	self.NameEntry:Dock(TOP)
	self.NameEntry:SetFont(FONT_UI)
	self.NameEntry:SetTall(26)
	self.NameEntry:DockMargin(0, 2, 0, 8)

	-- Max días
	local daysLabel = sp:Add("DLabel")
	daysLabel:Dock(TOP)
	daysLabel:SetFont(FONT_UI)
	daysLabel:SetText("Permiso máximo (días):")
	daysLabel:SetTall(20)

	self.DaysEntry = sp:Add("DNumberWang")
	self.DaysEntry:Dock(TOP)
	self.DaysEntry:SetFont(FONT_UI)
	self.DaysEntry:SetTall(26)
	self.DaysEntry:SetMinMax(1, 365)
	self.DaysEntry:SetValue(30)
	self.DaysEntry:DockMargin(0, 2, 0, 8)

	-- Documentos requeridos
	local docsLabel = sp:Add("DLabel")
	docsLabel:Dock(TOP)
	docsLabel:SetFont(FONT_UI)
	docsLabel:SetText("Documentos requeridos:")
	docsLabel:SetTall(20)
	docsLabel:DockMargin(0, 0, 0, 4)

	self.DocChecks = {}
	for _, dt in ipairs(DOC_TYPES) do
		local row = sp:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(26)
		row:DockMargin(0, 0, 0, 2)
		row.Paint = nil

		local cb = row:Add("DCheckBox")
		cb:SetPos(4, 4)
		cb:SetValue(false)

		local lbl = row:Add("DLabel")
		lbl:SetFont(FONT_UI)
		lbl:SetText(dt.label)
		lbl:SetPos(26, 3)
		lbl:SizeToContents()

		local combo = row:Add("DComboBox")
		combo:SetSize(120, 22)
		combo:SetPos(200, 2)
		combo:SetFont(FONT_UI)
		combo:AddChoice("Obligatorio", "required")
		combo:AddChoice("Condicional*", "conditional")
		combo:ChooseOptionID(1)

		self.DocChecks[dt.id] = { check = cb, combo = combo }
	end

	-- Reglas POR ESTACIÓN (por facción propietaria)
	local stLabel = sp:Add("DLabel")
	stLabel:Dock(TOP)
	stLabel:SetFont(FONT_UI)
	stLabel:SetText("Reglas por estación (facción propietaria):")
	stLabel:SetTall(20)
	stLabel:DockMargin(0, 8, 0, 4)

	-- Selector de estación
	local stRow = sp:Add("DPanel")
	stRow:Dock(TOP)
	stRow:SetTall(28)
	stRow:DockMargin(0, 0, 0, 4)
	stRow.Paint = nil

	self.StationCombo = stRow:Add("DComboBox")
	self.StationCombo:SetFont(FONT_UI)
	self.StationCombo:SetSize(200, 26)
	self.StationCombo:SetPos(0, 0)
	self.StationCombo:SetValue("Seleccionar estación...")

	-- Todas las facciones conocidas + _default
	local stationKeys = { "_default" }
	for _, f in ipairs(PLUGIN.KnownFactions or {}) do
		stationKeys[#stationKeys + 1] = f
	end
	for _, key in ipairs(stationKeys) do
		local label = (key == "_default") and "(Por defecto)" or key
		self.StationCombo:AddChoice(label, key)
	end

	self.StationCombo.OnSelect = function(_, _, _, data)
		self:LoadStationRules(data)
	end

	-- Checkboxes de permitidos/vetados para la estación seleccionada
	local allowLabel = sp:Add("DLabel")
	allowLabel:Dock(TOP)
	allowLabel:SetFont(FONT_UI)
	allowLabel:SetText("Permitidos (vacío = todos):")
	allowLabel:SetTall(18)
	allowLabel:DockMargin(0, 4, 0, 2)

	self.AllowedChecks = {}
	for _, fname in ipairs(PLUGIN.KnownFactions or {}) do
		local row = sp:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(22)
		row:DockMargin(0, 0, 0, 1)
		row.Paint = nil

		local cb = row:Add("DCheckBox")
		cb:SetPos(4, 2)
		cb:SetValue(false)

		local lbl = row:Add("DLabel")
		lbl:SetFont(FONT_UI)
		lbl:SetText(fname)
		lbl:SetPos(26, 1)
		lbl:SizeToContents()

		self.AllowedChecks[fname] = cb
	end

	local banLabel = sp:Add("DLabel")
	banLabel:Dock(TOP)
	banLabel:SetFont(FONT_UI)
	banLabel:SetText("Vetados:")
	banLabel:SetTall(18)
	banLabel:DockMargin(0, 6, 0, 2)

	self.BannedChecks = {}
	for _, fname in ipairs(PLUGIN.KnownFactions or {}) do
		local row = sp:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(22)
		row:DockMargin(0, 0, 0, 1)
		row.Paint = nil

		local cb = row:Add("DCheckBox")
		cb:SetPos(4, 2)
		cb:SetValue(false)

		local lbl = row:Add("DLabel")
		lbl:SetFont(FONT_UI)
		lbl:SetText(fname)
		lbl:SetPos(26, 1)
		lbl:SizeToContents()

		self.BannedChecks[fname] = cb
	end

	-- Guardar reglas de la estación seleccionada al cambiar checks
	self.CurrentStationKey = "_default"
	self.StationRulesCache = {}

	-- Botones
	local btnPanel = sp:Add("DPanel")
	btnPanel:Dock(TOP)
	btnPanel:SetTall(36)
	btnPanel:DockMargin(0, 12, 0, 0)
	btnPanel.Paint = nil

	local btnSave = btnPanel:Add("DButton")
	btnSave:Dock(LEFT)
	btnSave:SetWide(140)
	btnSave:SetText("Guardar")
	btnSave:SetFont(FONT_UI)
	btnSave.DoClick = function()
		self:SaveCurrent()
	end

	local btnDelete = btnPanel:Add("DButton")
	btnDelete:Dock(LEFT)
	btnDelete:SetWide(120)
	btnDelete:SetText("Eliminar")
	btnDelete:SetFont(FONT_UI)
	btnDelete:DockMargin(8, 0, 0, 0)
	btnDelete.DoClick = function()
		if (not self.EditingIdx) then return end
		Derma_Query(
			"¿Eliminar este boletín?", "Confirmar",
			"Sí", function()
				net.Start("ix.pp.DeleteBulletin")
					net.WriteUInt(self.EditingIdx, 8)
				net.SendToServer()
			end,
			"No", function() end
		)
	end

	local btnActivate = btnPanel:Add("DButton")
	btnActivate:Dock(LEFT)
	btnActivate:SetWide(140)
	btnActivate:SetText("Activar este día")
	btnActivate:SetFont(FONT_UI)
	btnActivate:DockMargin(8, 0, 0, 0)
	btnActivate.DoClick = function()
		if (not self.EditingIdx) then return end
		RunConsoleCommand("ix", "FronteraDia", tostring(self.EditingIdx))
	end

	self.EditingIdx = nil
end

function PANEL:PopulateList()
	self.BulletinList:Clear()

	local sorted = {}
	for idx, b in pairs(self.Bulletins) do
		sorted[#sorted + 1] = { idx = idx, name = b.name or "Sin nombre" }
	end
	table.sort(sorted, function(a, b) return a.idx < b.idx end)

	for _, entry in ipairs(sorted) do
		local btn = self.BulletinList:Add("DButton")
		btn:Dock(TOP)
		btn:SetTall(28)
		btn:DockMargin(0, 0, 0, 2)
		btn:SetFont(FONT_UI)

		local isActive = (PLUGIN.CurrentDay == entry.idx)
		btn:SetText(string.format("[%d] %s%s", entry.idx, entry.name, isActive and " (ACTIVO)" or ""))

		btn.Paint = function(s, w, h)
			local bg = isActive and Color(60, 90, 60) or Color(50, 48, 45)
			if (s:IsHovered()) then bg = Color(bg.r + 20, bg.g + 20, bg.b + 20) end
			draw.RoundedBox(4, 0, 0, w, h, bg)
		end

		btn.DoClick = function()
			self:LoadBulletin(entry.idx)
		end
	end
end

function PANEL:LoadBulletin(idx)
	local b = self.Bulletins[idx]
	if (not b) then return end

	self.EditingIdx = idx
	self.NameEntry:SetText(b.name or "")
	self.DaysEntry:SetValue(b.maxPermitDays or 30)

	for docId, ctrl in pairs(self.DocChecks) do
		local mode = b.docs and b.docs[docId]
		ctrl.check:SetValue(mode != nil)
		if (mode == "conditional") then
			ctrl.combo:ChooseOptionID(2)
		else
			ctrl.combo:ChooseOptionID(1)
		end
	end

	-- Cargar reglas de estación
	self.StationRulesCache = b.stationRules or {}
	self.CurrentStationKey = "_default"
	if IsValid(self.StationCombo) then self.StationCombo:ChooseOptionID(1) end
	self:LoadStationRules("_default")
end

function PANEL:LoadStationRules(key)
	-- Guardar la estación anterior antes de cambiar
	if (self.CurrentStationKey and self.CurrentStationKey != key) then
		self:SaveCurrentStationRules()
	end

	self.CurrentStationKey = key or "_default"
	local sr = self.StationRulesCache[self.CurrentStationKey] or { allowed = {}, banned = {} }

	local allowedSet = {}
	for _, f in ipairs(sr.allowed or {}) do allowedSet[f] = true end
	for fname, cb in pairs(self.AllowedChecks or {}) do
		cb:SetValue(allowedSet[fname] or false)
	end

	local bannedSet = {}
	for _, f in ipairs(sr.banned or {}) do bannedSet[f] = true end
	for fname, cb in pairs(self.BannedChecks or {}) do
		cb:SetValue(bannedSet[fname] or false)
	end
end

function PANEL:SaveCurrentStationRules()
	if (not self.CurrentStationKey) then return end

	local allowed = {}
	for fname, cb in pairs(self.AllowedChecks or {}) do
		if (cb:GetChecked()) then allowed[#allowed + 1] = fname end
	end

	local banned = {}
	for fname, cb in pairs(self.BannedChecks or {}) do
		if (cb:GetChecked()) then banned[#banned + 1] = fname end
	end

	self.StationRulesCache[self.CurrentStationKey] = { allowed = allowed, banned = banned }
end

function PANEL:SaveCurrent()
	local idx = self.EditingIdx
	if (not idx) then
		chat.AddText(Color(220, 120, 120), "[Frontera] ", color_white, "Selecciona un boletín primero.")
		return
	end

	local docs = {}
	for docId, ctrl in pairs(self.DocChecks) do
		if (ctrl.check:GetChecked()) then
			local _, mode = ctrl.combo:GetSelected()
			docs[docId] = mode or "required"
		end
	end

	-- Guardar la estación actual antes de enviar
	self:SaveCurrentStationRules()

	net.Start("ix.pp.SaveBulletin")
		net.WriteUInt(idx, 8)
		net.WriteTable({
			name = self.NameEntry:GetText(),
			maxPermitDays = self.DaysEntry:GetValue(),
			docs = docs,
			stationRules = self.StationRulesCache or {}
		})
	net.SendToServer()
end

function PANEL:CreateNewBulletin()
	local maxIdx = 0
	for idx in pairs(self.Bulletins) do
		if (idx > maxIdx) then maxIdx = idx end
	end

	local newIdx = maxIdx + 1
	self.Bulletins[newIdx] = { name = "Nuevo Boletín", docs = {}, maxPermitDays = 30 }
	self:PopulateList()
	self:LoadBulletin(newIdx)
end

function PANEL:SetBulletinsData(data)
	self.Bulletins = data or {}
	self:PopulateList()

	local first = next(self.Bulletins)
	if (first and not self.EditingIdx) then
		self:LoadBulletin(first)
	end
end

function PANEL:OnRemove()
	if (g_BulletinEditor == self) then g_BulletinEditor = nil end
end

local function registerEditor()
	local base = vgui.GetControlTable("ixFrame") and "ixFrame" or "DFrame"
	vgui.Register("ixBulletinEditor", PANEL, base)
end
timer.Simple(0, registerEditor)

---------------------------------------------------------
-- Red
---------------------------------------------------------
net.Receive("ix.pp.BulletinsData", function()
	local data = net.ReadTable() or {}
	if IsValid(g_BulletinEditor) then
		g_BulletinEditor:SetBulletinsData(data)
	end
end)

net.Receive("ix.pp.OpenBulletinEditor", function()
	if IsValid(g_BulletinEditor) then g_BulletinEditor:Close() end
	local f = vgui.Create("ixBulletinEditor")
	if IsValid(f) then g_BulletinEditor = f end
end)
