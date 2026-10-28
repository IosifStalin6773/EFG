local PLUGIN = PLUGIN

-- ======== VIEWER ========
local V = {}
function V:Init()
	self:SetTitle("Documentos de Vacunas")
	self:SetSize(520, 520)
	self:Center()
	self:MakePopup()

	self.body = self:Add("DScrollPanel")
	self.body:Dock(FILL)

	self.headerLabels = {}
	local function addLine(label)
		local L = self.body:Add("DLabel")
		L:Dock(TOP)
		L:SetFont("ixPassportUI")
		L:SetText(label .. ": —")
		L:DockMargin(0, 2, 0, 0)
		self.headerLabels[#self.headerLabels + 1] = L
	end

	addLine("Titular")
	addLine("Nº Certificado")
	addLine("Emitido")
	addLine("Válido hasta")

	self.vaccineTitle = self.body:Add("DLabel")
	self.vaccineTitle:Dock(TOP)
	self.vaccineTitle:SetFont("ixPapersTitle")
	self.vaccineTitle:SetText("Vacunas aplicadas:")
	self.vaccineTitle:DockMargin(0, 10, 0, 4)

	self.vaccineList = self.body:Add("DPanel")
	self.vaccineList:Dock(TOP)
	self.vaccineList:SetTall(200)
end

function V:SetVaccineData(d)
	d = d or {}
	local lines = {
		d.holderName or "—",
		d.certificateNumber or "—",
		d.issuedWhen and os.date("%d/%m/%Y", d.issuedWhen) or "—",
		d.validUntil and os.date("%d/%m/%Y", d.validUntil) or "—",
	}
	for i, L in ipairs(self.headerLabels or {}) do
		local base = L:GetText():match("^(.-):")
		L:SetText(string.format("%s: %s", base or "", lines[i] or "—"))
	end

	self.vaccineList:Clear()
	local vaccines = d.vaccines
	if (vaccines and type(vaccines) == "table" and #vaccines > 0) then
		local totalH = 0
		for i, vac in ipairs(vaccines) do
			local lbl = self.vaccineList:Add("DLabel")
			lbl:Dock(TOP)
			lbl:SetFont("ixPassportUI")
			local dateStr = vac.date or "—"
			lbl:SetText(string.format("  %d. %s — %s", i, vac.name or "—", dateStr))
			lbl:DockMargin(0, 1, 0, 0)
			totalH = totalH + 20
		end
		self.vaccineList:SetTall(math.max(totalH, 20))
	else
		local lbl = self.vaccineList:Add("DLabel")
		lbl:Dock(TOP)
		lbl:SetFont("ixPassportUI")
		lbl:SetText("  Sin vacunas registradas.")
		self.vaccineList:SetTall(20)
	end
end

local function regViewer()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixVaccineDocumentsViewer", V, "ixFrame")
	else
		vgui.Register("ixVaccineDocumentsViewer", V, "DFrame")
	end
end
timer.Simple(0, regViewer)
hook.Add("LoadedLocalSchema", "pp_register_vaccine_viewer", regViewer)

-- ======== EDITOR ========
local E = {}
function E:Init()
	self:SetTitle("Editar Documentos de Vacunas")
	self:SetSize(600, 580)
	self:Center()
	self:MakePopup()

	self.itemID = 0
	self.vaccines = {}
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
	self.certEntry = addField("Nº Certificado", function() return sp:Add("DTextEntry") end)

	self.yearsEntry = addField("Validez (años, 1-10)", function()
		local n = sp:Add("DNumberWang")
		n:SetMinMax(1, 10)
		n:SetValue(5)
		return n
	end)

	-- Sección de vacunas
	local vacTitle = sp:Add("DLabel")
	vacTitle:Dock(TOP)
	vacTitle:SetFont("ixPapersTitle")
	vacTitle:SetText("Vacunas:")
	vacTitle:DockMargin(0, 10, 0, 4)

	self.vaccineListPanel = sp:Add("DPanel")
	self.vaccineListPanel:Dock(TOP)
	self.vaccineListPanel:SetTall(10)
	self.vaccineListPanel.Paint = function() end

	-- Controles para añadir vacuna
	local addRow = sp:Add("DPanel")
	addRow:Dock(TOP)
	addRow:SetTall(26)
	addRow:DockMargin(0, 4, 0, 0)
	addRow.Paint = function() end

	self.vacNameEntry = addRow:Add("DTextEntry")
	self.vacNameEntry:Dock(LEFT)
	self.vacNameEntry:SetWide(250)
	self.vacNameEntry:SetPlaceholderText("Nombre de vacuna...")

	self.vacDateEntry = addRow:Add("DTextEntry")
	self.vacDateEntry:Dock(LEFT)
	self.vacDateEntry:SetWide(120)
	self.vacDateEntry:DockMargin(4, 0, 0, 0)
	self.vacDateEntry:SetPlaceholderText("DD/MM/AAAA")

	local addBtn = addRow:Add("DButton")
	addBtn:Dock(LEFT)
	addBtn:SetWide(60)
	addBtn:DockMargin(4, 0, 0, 0)
	addBtn:SetText("Añadir")
	addBtn:SetFont("ixPassportUI")
	function addBtn:DoClick()
		local vName = panel.vacNameEntry:GetText()
		if (vName == "") then return end
		local vDate = panel.vacDateEntry:GetText()
		if (vDate == "") then vDate = os.date("%d/%m/%Y") end
		table.insert(panel.vaccines, {name = vName, date = vDate})
		panel:RebuildVaccineList()
		panel.vacNameEntry:SetText("")
		panel.vacDateEntry:SetText("")
	end

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
			certificateNumber = panel.certEntry:GetText(),
			validYears = tonumber(panel.yearsEntry:GetValue()) or 5,
			vaccines = panel.vaccines
		}
		net.Start("ix.pp.SaveVaccineDocuments")
			net.WriteUInt(panel.itemID, 32)
			net.WriteTable(data)
		net.SendToServer()
		panel:Close()
	end
end

function E:RebuildVaccineList()
	self.vaccineListPanel:Clear()
	local totalH = 0
	for i, vac in ipairs(self.vaccines) do
		local row = self.vaccineListPanel:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(22)
		row.Paint = function() end

		local lbl = row:Add("DLabel")
		lbl:Dock(FILL)
		lbl:SetFont("ixPassportUI")
		lbl:SetText(string.format("  %d. %s — %s", i, vac.name or "—", vac.date or "—"))

		local del = row:Add("DButton")
		del:Dock(RIGHT)
		del:SetWide(20)
		del:SetText("X")
		del:SetFont("ixPapersSmall")
		local panel = self
		local idx = i
		function del:DoClick()
			table.remove(panel.vaccines, idx)
			panel:RebuildVaccineList()
		end

		totalH = totalH + 22
	end
	self.vaccineListPanel:SetTall(math.max(totalH, 10))
end

function E:SetItem(item)
	self.itemID = item and item.id or 0
	local d = item and item:GetData("vaccine", {}) or {}
	if (d.holderName) then self.nameEntry:SetText(d.holderName) end
	if (d.certificateNumber) then self.certEntry:SetText(d.certificateNumber) end
	if (d.vaccines and type(d.vaccines) == "table") then
		self.vaccines = table.Copy(d.vaccines)
	else
		self.vaccines = {}
	end
	self:RebuildVaccineList()
end

local function regEditor()
	if vgui.GetControlTable("ixFrame") then
		vgui.Register("ixVaccineDocumentsEditor", E, "ixFrame")
	else
		vgui.Register("ixVaccineDocumentsEditor", E, "DFrame")
	end
end
timer.Simple(0, regEditor)
hook.Add("LoadedLocalSchema", "pp_register_vaccine_editor", regEditor)
