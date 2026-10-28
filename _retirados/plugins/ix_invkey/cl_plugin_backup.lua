if (not CLIENT) then return end

-- ─── Constantes de layout ─────────────────────────────────────────────────────

local COL_LEFT  = 340
local COL_RIGHT = 440
local HEADER_H  = 44
local GAP       = 5
local MAX_ICON  = 96
local MIN_ICON  = 52

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function drawBg(w, h, r, g, b, a, border)
	draw.RoundedBox(0, 0, 0, w, h, Color(r, g, b, a or 220))
	if (border) then
		surface.SetDrawColor(50, 50, 50, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

local function drawSectionHdr(w, h, text)
	draw.RoundedBox(6, 0, 0, w, h, Color(38, 28, 18, 255))
	surface.SetFont("ixSmallFont")
	local tw, th = surface.GetTextSize(text)
	surface.SetTextColor(215, 168, 72, 255)
	surface.SetTextPos(8, h / 2 - th / 2)
	surface.DrawText(text)
end

-- Obtiene el icono de facción del plugin HUD (ya cargado en memoria).
local function getFactionIcon(factionIndex)
	local hud = ix.plugin.Get("hud")
	return hud and hud.FACTION_ICONS and hud.FACTION_ICONS[factionIndex]
end

-- ─── Panel ────────────────────────────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
	local sw, sh = ScrW(), ScrH()

	self:SetPos(0, 0)
	self:SetSize(sw, sh)
	self:SetMouseInputEnabled(true)
	-- NO SetKeyboardInputEnabled(true): si el panel exterior captura teclado,
	-- los DTextEntry hijos nunca reciben los eventos aunque tengan foco.

	local char = LocalPlayer():GetCharacter()
	if (not char) then self:Remove() return end

	local inv = char:GetInventory()
	if (not inv) then self:Remove() return end

	-- ── Datos de facción ─────────────────────────────────────────────────
	local factionIndex = char:GetFaction()
	local factionData  = ix.faction and ix.faction.indices and ix.faction.indices[factionIndex]
	local factionName  = (factionData and factionData.name) or "Desconocida"
	local factionColor = (factionData and factionData.color) or Color(160, 160, 160)
	local factionIcon  = getFactionIcon(factionIndex)

	-- ── Descripción del personaje ─────────────────────────────────────────
	local charDesc = ""
	if (char.GetDescription) then charDesc = char:GetDescription() or ""
	elseif (char.GetDesc)    then charDesc = char:GetDesc() or "" end

	-- ── HEADER ────────────────────────────────────────────────────────────
	local header = self:Add("DPanel")
	header:SetPos(0, 0)
	header:SetSize(sw, HEADER_H)

	-- Variables capturadas para el Paint del header (sin closures sobre mutables)
	local charName   = char:GetName() or "Desconocido"
	local headerIcon = factionIcon  -- referencia estática

	header.Paint = function(_, w, h)
		surface.SetDrawColor(16, 16, 16, 255)
		surface.DrawRect(0, 0, w, h)
		-- Textura de barra superior metroui
		surface.SetDrawColor(255, 255, 255, 140)
		surface.SetMaterial(ix.util.GetMaterial('metroui/spawnmenu/Menu/1.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(factionColor.r, factionColor.g, factionColor.b, 180)
		surface.DrawRect(0, h - 2, w, 2)

		-- Medir nombre para centrar con icono
		surface.SetFont("MetroHUD_Name")
		local tw, th = surface.GetTextSize(charName)
		tw = tw or 0
		th = th or 14
		local iconW  = headerIcon and 32 or 0
		local gap    = headerIcon and 8 or 0
		local totalW = iconW + gap + tw
		local startX = w / 2 - totalW / 2

		-- Icono de facción
		if (headerIcon) then
			surface.SetDrawColor(255, 255, 255, 220)
			surface.SetMaterial(headerIcon)
			surface.DrawTexturedRect(startX, h / 2 - 16, 32, 32)
		end

		-- Nombre del personaje
		surface.SetFont("MetroHUD_Name")
		surface.SetTextColor(235, 235, 235, 255)
		surface.SetTextPos(startX + iconW + gap, h / 2 - th / 2)
		surface.DrawText(charName)
	end

	-- Botón cerrar
	local closeBtn = header:Add("DButton")
	closeBtn:SetPos(sw - 36, 6)
	closeBtn:SetSize(30, 32)
	closeBtn:SetText("X")
	closeBtn:SetFont("ixMediumFont")
	closeBtn:SetTextColor(Color(200, 200, 200))
	closeBtn.Paint = function(s, w, h)
		if (s:IsHovered()) then
			surface.SetDrawColor(160, 40, 40, 230)
			surface.DrawRect(0, 0, w, h)
		end
	end
	closeBtn.DoClick = function() self:Remove() end

	-- ── Dimensiones del cuerpo ────────────────────────────────────────────
	local bodyY = HEADER_H
	local bodyH = sh - HEADER_H

	-- ── COLUMNA IZQUIERDA: modelo + bodygroups ────────────────────────────
	local leftCol = self:Add("DPanel")
	leftCol:SetPos(0, bodyY)
	leftCol:SetSize(COL_LEFT, bodyH)
	leftCol.Paint = function(_, w, h)
		drawBg(w, h, 18, 18, 18, 240, true)
		surface.SetDrawColor(143, 73, 28, 60)
		surface.SetMaterial(ix.util.GetMaterial('metroui/mainmenu_card.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, w, SScale(8))
	end

	local modelH    = math.floor(bodyH * 0.65)
	local saveBtnH  = 28
	local bgHdrH    = 20
	local bgScrollH = bodyH - modelH - bgHdrH - saveBtnH - GAP * 3

	-- Panel 3D
	local modelPanel = leftCol:Add("DAdjustableModelPanel")
	modelPanel:SetPos(0, 0)
	modelPanel:SetSize(COL_LEFT, modelH)
	modelPanel:SetModel(LocalPlayer():GetModel())
	modelPanel:SetCamPos(Vector(42, 42, 52))
	modelPanel:SetLookAng(Angle(10, 225, 0))
	modelPanel:SetFOV(30)
	function modelPanel:LayoutEntity(ent)
		ent:SetAngles(Angle(0, 45, 0))
		local seq = ent:SelectWeightedSequence(ACT_IDLE)
		if (seq > 0) then ent:ResetSequence(seq) end
	end

	timer.Simple(0.15, function()
		if (IsValid(modelPanel) and IsValid(modelPanel.Entity)) then
			for i = 0, LocalPlayer():GetNumBodyGroups() - 1 do
				modelPanel.Entity:SetBodygroup(i, LocalPlayer():GetBodygroup(i))
			end
		end
	end)

	-- Cabecera bodygroups
	local bgHdr = leftCol:Add("DPanel")
	bgHdr:SetPos(0, modelH)
	bgHdr:SetSize(COL_LEFT, bgHdrH)
	bgHdr.Paint = function(_, w, h) drawSectionHdr(w, h, "APARIENCIA") end

	-- Scroll bodygroups
	local bgScroll = leftCol:Add("DScrollPanel")
	bgScroll:SetPos(0, modelH + bgHdrH)
	bgScroll:SetSize(COL_LEFT, bgScrollH)
	bgScroll:GetVBar():SetWide(4)

	local bgData = {}
	for _, bg in ipairs(LocalPlayer():GetBodyGroups()) do
		if (bg.id == 0) then continue end
		local cur = {value = LocalPlayer():GetBodygroup(bg.id)}
		bgData[bg.id] = cur

		local row = bgScroll:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(3, 2, 3, 0)
		row:SetTall(26)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(28, 28, 28, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local lbl = row:Add("DLabel")
		lbl:SetPos(5, 0)
		lbl:SetSize(COL_LEFT - 82, 26)
		lbl:SetFont("ixSmallFont")
		lbl:SetTextColor(Color(185, 185, 185))
		lbl:SetContentAlignment(4)
		lbl:SetText(bg.name:sub(1,1):upper() .. bg.name:sub(2))

		local valLbl = row:Add("DLabel")
		valLbl:SetPos(COL_LEFT - 57, 0)
		valLbl:SetSize(22, 26)
		valLbl:SetFont("ixSmallFont")
		valLbl:SetTextColor(Color(220, 220, 220))
		valLbl:SetContentAlignment(5)
		valLbl:SetText(tostring(cur.value))

		local prevBtn = row:Add("DButton")
		prevBtn:SetPos(COL_LEFT - 80, 3)
		prevBtn:SetSize(22, 20)
		prevBtn:SetText("<")
		prevBtn:SetFont("ixSmallFont")
		prevBtn.Paint = function(s, w, h)
			surface.SetDrawColor(s:IsHovered() and 65 or 38, 38, 38, 220)
			surface.DrawRect(0, 0, w, h)
		end
		prevBtn.DoClick = function()
			if (cur.value > 0) then
				cur.value = cur.value - 1
				valLbl:SetText(tostring(cur.value))
				if (IsValid(modelPanel.Entity)) then modelPanel.Entity:SetBodygroup(bg.id, cur.value) end
			end
		end

		local nextBtn = row:Add("DButton")
		nextBtn:SetPos(COL_LEFT - 32, 3)
		nextBtn:SetSize(22, 20)
		nextBtn:SetText(">")
		nextBtn:SetFont("ixSmallFont")
		nextBtn.Paint = function(s, w, h)
			surface.SetDrawColor(s:IsHovered() and 65 or 38, 38, 38, 220)
			surface.DrawRect(0, 0, w, h)
		end
		nextBtn.DoClick = function()
			local maxVal = LocalPlayer():GetBodygroupCount(bg.id) - 1
			if (cur.value < maxVal) then
				cur.value = cur.value + 1
				valLbl:SetText(tostring(cur.value))
				if (IsValid(modelPanel.Entity)) then modelPanel.Entity:SetBodygroup(bg.id, cur.value) end
			end
		end
	end

	-- Botón guardar apariencia
	local saveAppBtn = leftCol:Add("DButton")
	saveAppBtn:SetPos(3, bodyH - saveBtnH - GAP)
	saveAppBtn:SetSize(COL_LEFT - 6, saveBtnH)
	saveAppBtn:SetText("Guardar Apariencia")
	saveAppBtn:SetFont("ixSmallFont")
	saveAppBtn:SetTextColor(Color(200, 225, 200))
	saveAppBtn.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and 38 or 25, s:IsHovered() and 65 or 48, s:IsHovered() and 38 or 25, 230)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(45, 80, 45, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	saveAppBtn.DoClick = function()
		local bgTable = {}
		for id, data in pairs(bgData) do bgTable[id] = data.value end
		net.Start("ixBodygroupTableSet")
			net.WriteEntity(LocalPlayer())
			net.WriteTable(bgTable)
		net.SendToServer()
	end

	-- ── COLUMNA CENTRAL: inventario ───────────────────────────────────────
	local centerX = COL_LEFT + GAP
	local centerW = sw - COL_LEFT - COL_RIGHT - GAP * 3

	local centerCol = self:Add("DPanel")
	centerCol:SetPos(centerX, bodyY)
	centerCol:SetSize(centerW, bodyH)
	centerCol.Paint = function(_, w, h)
		drawBg(w, h, 16, 16, 16, 235, false)
		-- Marco decorativo de inventario metroui
		surface.SetDrawColor(255, 255, 255, 200)
		surface.SetMaterial(ix.util.GetMaterial('metroui/spawnmenu/Menu/2.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, w, h)
	end

	-- Tamaño de icono escalado al espacio disponible
	local invW, invH = inv:GetSize()
	invW = invW or 6
	invH = invH or 6

	-- Icono sin cap para que llene la columna completa
	local iconSize = math.min(
		math.floor((bodyH - 44) / invH),   -- deja 44px para la barra de peso
		math.floor((centerW - 12) / invW)  -- rellena el ancho con margen mínimo
	)
	iconSize = math.max(iconSize, MIN_ICON)

	local gridPixW = invW * iconSize + 8
	local gridPixH = invH * iconSize + 10

	local invPanel = centerCol:Add("ixInventory")
	invPanel:SetPos(6, 4)
	invPanel:SetDraggable(false)
	invPanel:SetSizable(false)
	invPanel:SetTitle(nil)
	invPanel.bNoBackgroundBlur = true
	invPanel.childPanels       = {}
	invPanel.Paint = function(_, w, h)
		draw.RoundedBox(3, 0, 0, w, h, Color(26, 26, 26, 210))
	end
	invPanel:SetIconSize(iconSize)
	invPanel:SetInventory(inv)
	ix.gui.inv1 = invPanel

	if (ix.option.Get("openBags", true)) then
		for _, item in pairs(inv:GetItems()) do
			if (item.isBag and item.functions and item.functions.View) then
				item.functions.View.OnClick(item)
			end
		end
	end

	-- Barra de peso debajo del grid, ancho completo de la columna
	local wBarY    = gridPixH + 12
	local maxWeight = ix.config.Get("maxWeight", 30)
	local wBar = centerCol:Add("DPanel")
	wBar:SetPos(4, wBarY)
	wBar:SetSize(centerW - 8, 26)
	wBar.Paint = function(_, w, h)
		local carry = char:GetData("carry", 0)
		local frac  = math.Clamp(carry / maxWeight, 0, 1)

		-- Color de relleno según porcentaje (igual que DrawBar del HUD para vida)
		local fillColor
		if (frac < 0.60) then
			fillColor = Color(80, 200, 80, 255)
		elseif (frac < 0.85) then
			fillColor = Color(220, 200, 50, 255)
		else
			fillColor = Color(200, 50, 50, 255)
		end

		-- Fondo de la barra
		draw.RoundedBox(3, 0, 0, w, h, Color(40, 40, 40, 200))

		-- Relleno principal
		if (frac > 0) then
			draw.RoundedBox(3, 0, 0, math.max(0, math.floor(w * frac)), h, fillColor)
		end

		-- Capa de sobrepeso (en rojo encima del relleno si supera el máximo)
		local maxOver  = ix.config.Get("maxOverWeight", 20)
		local overFrac = math.Clamp((carry - maxWeight) / maxOver, 0, 1)
		if (overFrac > 0) then
			draw.RoundedBox(3, 0, 0, math.floor(w * overFrac), h, Color(200, 40, 40, 220))
		end

		-- Texto centrado
		surface.SetFont("ixSmallFont")
		local txt    = math.Round(carry, 1) .. " / " .. maxWeight .. " kg"
		local tw, th = surface.GetTextSize(txt)
		surface.SetTextColor(240, 240, 240, 255)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
		surface.DrawText(txt)
	end

	-- ── COLUMNA DERECHA: info del personaje ───────────────────────────────
	local rightX = sw - COL_RIGHT
	local rightCol = self:Add("DPanel")
	rightCol:SetPos(rightX, bodyY)
	rightCol:SetSize(COL_RIGHT, bodyH)
	rightCol.Paint = function(_, w, h)
		drawBg(w, h, 18, 18, 18, 240, true)
		surface.SetDrawColor(143, 73, 28, 60)
		surface.SetMaterial(ix.util.GetMaterial('metroui/mainmenu_card.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, w, SScale(8))
	end

	local ry = 8  -- cursor Y (solo para posicionar hijos, NO usado en Paint)

	-- ── Filas de info (Facción, Oficio, Dinero) ───────────────────────────
	local function addInfoRow(label, value, valueColor)
		local row = rightCol:Add("DPanel")
		row:SetPos(4, ry)
		row:SetSize(COL_RIGHT - 8, 24)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(28, 28, 28, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local kl = row:Add("DLabel")
		kl:SetPos(6, 0)
		kl:SetSize(80, 24)
		kl:SetFont("ixSmallFont")
		kl:SetTextColor(Color(185, 148, 70))
		kl:SetContentAlignment(4)
		kl:SetText(label)

		local vl = row:Add("DLabel")
		vl:SetPos(88, 0)
		vl:SetSize(COL_RIGHT - 96, 24)
		vl:SetFont("ixSmallFont")
		vl:SetTextColor(valueColor or Color(210, 210, 210))
		vl:SetContentAlignment(4)
		vl:SetText(value)

		ry = ry + 27
		return row
	end

	-- Facción con color de facción
	addInfoRow("Facción", factionName, Color(factionColor.r, factionColor.g, factionColor.b))

	local oficio = char.GetOficio and char:GetOficio()
	if (oficio and oficio != "ninguno") then
		local lista  = ix.oficios and ix.oficios.lista
		local nombre = (lista and lista[oficio]) or oficio
		local tier   = (char.GetOficioTier and char:GetOficioTier()) or 0
		addInfoRow("Oficio", nombre .. "  (Tier " .. tier .. ")")
	end

	local moneyStr = tostring(char:GetMoney()) .. " " .. (ix.currency.plural or "Balas")
	addInfoRow("Dinero", moneyStr, Color(215, 175, 55))
	ry = ry + 4

	-- Barra de exhaustion
	local lootMax = ((ix.loot and ix.loot.limit) or 15) * 10
	local exBar   = rightCol:Add("DPanel")
	exBar:SetPos(4, ry)
	exBar:SetSize(COL_RIGHT - 8, 22)
	exBar.Paint = function(_, w, h)
		local exh  = char:GetData("exhaustion", 0)
		local frac = math.Clamp(exh / lootMax, 0, 1)
		draw.RoundedBox(3, 0, 0, w, h, Color(40, 40, 40, 200))
		if (frac > 0) then
			draw.RoundedBox(3, 0, 0, math.max(0, math.floor(w * frac)), h, Color(175, 115, 30, 220))
		end
		surface.SetFont("ixSmallFont")
		local txt    = "Exhaustion (" .. exh .. " / " .. lootMax .. ")"
		local tw, th = surface.GetTextSize(txt)
		surface.SetTextColor(220, 220, 220, 255)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
		surface.DrawText(txt)
	end
	ry = ry + 28

	-- ── Descripción (display + botón editar) ─────────────────────────────
	local descHdrPanel = rightCol:Add("DPanel")
	descHdrPanel:SetPos(4, ry)
	descHdrPanel:SetSize(COL_RIGHT - 8, 20)
	descHdrPanel.Paint = function(_, w, h) drawSectionHdr(w, h, "DESCRIPCIÓN") end
	ry = ry + 24

	-- Texto de descripción actual (solo lectura, clickable para abrir editor)
	local descH       = 80
	local descDisplay = rightCol:Add("DPanel")
	descDisplay:SetPos(4, ry)
	descDisplay:SetSize(COL_RIGHT - 8, descH)
	descDisplay:SetMouseInputEnabled(true)
	descDisplay:SetCursor("hand")

	local currentDesc = {text = charDesc != "" and charDesc or "Sin descripción."}

	descDisplay.Paint = function(_, w, h)
		draw.RoundedBox(3, 0, 0, w, h, Color(24, 24, 24, 220))
		surface.SetDrawColor(55, 55, 55, 180)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	-- DLabel con wrap para mostrar la descripción sin salirse del cuadro
	local descLabel = descDisplay:Add("DLabel")
	descLabel:SetPos(6, 6)
	descLabel:SetSize(COL_RIGHT - 24, descH - 12)
	descLabel:SetFont("ixSmallFont")
	descLabel:SetTextColor(Color(185, 185, 185))
	descLabel:SetWrap(true)
	descLabel:SetAutoStretchVertical(false)
	descLabel:SetText(currentDesc.text)

	-- Abre un DFrame propio con DTextEntry (el único pattern fiable en GMod)
	function descDisplay:DoClick()
		if (IsValid(ix.gui.descEditor)) then ix.gui.descEditor:Remove() end

		local frame = vgui.Create("DFrame")
		ix.gui.descEditor = frame
		frame:SetTitle("Editar Descripción")
		frame:SetSize(420, 200)
		frame:Center()
		frame:MakePopup()
		frame:SetDeleteOnClose(true)

		local entry = frame:Add("DTextEntry")
		entry:SetPos(8, 32)
		entry:SetSize(404, 110)
		entry:SetMultiline(true)
		entry:SetFont("ixSmallFont")
		entry:SetText(currentDesc.text != "Sin descripción." and currentDesc.text or "")
		entry:RequestFocus()

		local saveBtn = frame:Add("DButton")
		saveBtn:SetPos(8, 150)
		saveBtn:SetSize(200, 28)
		saveBtn:SetText("Guardar")
		saveBtn.DoClick = function()
			local newDesc = entry:GetValue()
			if (newDesc == "") then newDesc = "Sin descripción." end
			currentDesc.text = newDesc
			if (IsValid(descLabel)) then descLabel:SetText(newDesc) end
			net.Start("ixInvSaveDesc")
				net.WriteString(newDesc)
			net.SendToServer()
			frame:Remove()
		end

		local cancelBtn = frame:Add("DButton")
		cancelBtn:SetPos(214, 150)
		cancelBtn:SetSize(200, 28)
		cancelBtn:SetText("Cancelar")
		cancelBtn.DoClick = function() frame:Remove() end
	end
	ry = ry + descH + 4

	-- Botón editar descripción
	local editDescBtnH = 24
	local editDescBtn  = rightCol:Add("DButton")
	editDescBtn:SetPos(4, ry)
	editDescBtn:SetSize(COL_RIGHT - 8, editDescBtnH)
	editDescBtn:SetText("Editar Descripción")
	editDescBtn:SetFont("ixSmallFont")
	editDescBtn:SetTextColor(Color(200, 225, 200))
	editDescBtn.Paint = function(s, w, h)
		draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(38, 65, 38, 230) or Color(25, 48, 25, 230))
		surface.SetDrawColor(45, 80, 45, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	editDescBtn.DoClick = function() descDisplay:DoClick() end
	ry = ry + editDescBtnH + 6

	-- ── Atributos ─────────────────────────────────────────────────────────
	local attHdr = rightCol:Add("DPanel")
	attHdr:SetPos(4, ry)
	attHdr:SetSize(COL_RIGHT - 8, 20)
	attHdr.Paint = function(_, w, h) drawSectionHdr(w, h, "ATRIBUTOS") end
	ry = ry + 24

	local attScrollH = bodyH - ry - GAP
	local attScroll  = rightCol:Add("DScrollPanel")
	attScroll:SetPos(4, ry)
	attScroll:SetSize(COL_RIGHT - 8, attScrollH)
	attScroll:GetVBar():SetWide(4)

	for attID, attrib in SortedPairs((ix.attributes and ix.attributes.list) or {}) do
		local aID   = attID
		local aName = attrib.name or attID

		local aRow = attScroll:Add("DPanel")
		aRow:Dock(TOP)
		aRow:DockMargin(0, 0, 0, 2)
		aRow:SetTall(22)
		aRow.Paint = function(_, w, h)
			local val  = char:GetAttribute(aID, 0)
			local frac = math.Clamp(val / 100, 0, 1)
			draw.RoundedBox(3, 0, 0, w, h, Color(40, 40, 40, 200))
			if (frac > 0) then
				draw.RoundedBox(3, 0, 0, math.max(0, math.floor(w * frac)), h, Color(60, 95, 150, 220))
			end
			surface.SetFont("ixSmallFont")
			local pct    = math.Round(frac * 100, 1)
			local txt    = aName .. "  " .. val .. " / 100  (" .. pct .. "%)"
			local tw, th = surface.GetTextSize(txt)
			surface.SetTextColor(215, 215, 215, 255)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(txt)
		end
	end

	self:MakePopup()
	-- Desactivar teclado en el panel raíz DESPUÉS de MakePopup,
	-- para que los DTextEntry hijos puedan recibir input libremente.
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 220))
	-- Fondo de textura metroui
	surface.SetDrawColor(255, 255, 255, 100)
	surface.SetMaterial(ix.util.GetMaterial('metroui/spawnmenu/Menu/3.png', 'noclamp smooth'))
	surface.DrawTexturedRect(0, 0, w, h)
end

local _escDown = false
function PANEL:Think()
	if (IsValid(ix.gui.menu)) then self:Remove() end

	-- ESC via input.IsKeyDown porque OnKeyCodePressed ya no dispara
	-- (SetKeyboardInputEnabled(false) en el panel raíz)
	local esc = input.IsKeyDown(KEY_ESCAPE)
	if (esc and not _escDown) then
		_escDown = true
		self:Remove()
	elseif (not esc) then
		_escDown = false
	end
end

-- OnKeyCodePressed ya no se necesita (el panel raíz no captura teclado)

function PANEL:OnRemove()
	if (ix.gui.metroInventory == self) then
		ix.gui.metroInventory = nil
	end
end

vgui.Register("ixMetroInventory", PANEL, "Panel")

-- ─── Tecla TAB ────────────────────────────────────────────────────────────────

local invKeyDown = false

hook.Add("Think", "ixMetroInventoryKey", function()
	local isDown = input.IsKeyDown(KEY_I)

	if (isDown and not invKeyDown) then
		invKeyDown = true

		local lp = LocalPlayer()
		if (not IsValid(lp) or not lp:GetCharacter()) then return end

		-- No actuar si el editor de descripción está abierto o hay un TextEntry con foco
		if (IsValid(ix.gui.descEditor)) then return end
		local focus = vgui.GetKeyboardFocus()
		if (IsValid(focus) and focus:GetClassName():find("Entry")) then return end

		if (IsValid(ix.gui.metroInventory)) then
			ix.gui.metroInventory:Remove()
			return
		end

		if (IsValid(ix.gui.menu)) then ix.gui.menu:Remove() end

		ix.gui.metroInventory = vgui.Create("ixMetroInventory")

	elseif (not isDown) then
		invKeyDown = false
	end
end)
