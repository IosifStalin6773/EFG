-- ============================================================
--  missions  |  cl_plugin.lua  (CLIENT)
--  Panel de administración CRUD y navegador de misiones del
--  jugador. Estética MetroUI coherente con el panel del trader.
-- ============================================================

if (not CLIENT) then return end

ix.missions = ix.missions or {}
ix.missions._adminData  = ix.missions._adminData  or {}
ix.missions._traderList = ix.missions._traderList or {}
ix.missions._dailyState = ix.missions._dailyState or {}

-- ── Polyfill SetBounds (no es un método VGUI estándar) ───────────────────────────
local _PNL = FindMetaTable("Panel")
if (_PNL and not _PNL.SetBounds) then
	_PNL.SetBounds = function(self, x, y, w, h)
		self:SetPos(x, y); self:SetSize(w, h); return self
	end
end

-- ── Fuentes (mismos nombres que el plugin de traders; idempotente) ───────────────
local function registerFonts()
	surface.CreateFont("Metro UI.Button", {
		font = "EFGX Body", extended = true, size = SScale(10), weight = 500, antialias = true,
	})
	surface.CreateFont("Metro UI.CharFields", {
		font = "EFGX Body", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
	surface.CreateFont("ixSmallFont", {
		font = "EFGX Body", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "missions.Fonts", registerFonts)

-- ── Helpers de estilo ────────────────────────────────────────────────────────────
local PAD = 8
local GAP = 6

local matMoney = Material("efgui/icons/money.png", "noclamp smooth")  -- icono de Balas (panel de recompensas)

local function paintFrame(self, w, h, accent)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(28, 28, 28, 240)
	surface.DrawRect(0, 0, w, h)
	accent = accent or Color(154, 136, 102)
	surface.SetDrawColor(accent.r, accent.g, accent.b, 200)
	surface.DrawRect(0, 0, w, SScale(3))
	surface.SetDrawColor(66, 66, 66, 88)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function paintDarkEntry(self, w, h)
	surface.SetDrawColor(44, 44, 44, 220)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(88, 88, 88, 160)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	self:DrawTextEntryText(Color(220, 220, 220), Color(112, 128, 130, 180), Color(220, 220, 220))
end

local function makeBtn(parent, text, r, g, b, cb)
	local btn = parent:Add("DButton")
	btn:SetText(text)
	btn:SetFont("Metro UI.CharFields")
	btn:SetTextColor(Color(math.min(r + 120, 255), math.min(g + 120, 255), math.min(b + 120, 255)))
	btn.Paint = function(s, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 30 or 14)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 80 or 30)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	btn.DoClick = cb or function() end
	return btn
end

local function makeLabel(parent, text, font, col)
	local l = parent:Add("DLabel")
	l:SetText(text)
	l:SetFont(font or "Metro UI.CharFields")
	l:SetTextColor(col or Color(200, 200, 200))
	return l
end

local function makeEntry(parent, value)
	local e = parent:Add("DTextEntry")
	e:SetFont("Metro UI.CharFields")
	e:SetText(tostring(value or ""))
	e.Paint = paintDarkEntry
	return e
end

-- ── Datos compartidos ────────────────────────────────────────────────────────────
local FACTION_COLORS = {
	prapor      = Color(170, 60, 50),
	therapist   = Color(200, 80, 120),
	fence       = Color(120, 120, 120),
	skier       = Color(154, 136, 102),
	peacekeeper = Color(112, 128, 130),
	mechanic    = Color(90, 170, 90),
	ragman      = Color(150, 90, 200),
	jaeger      = Color(50, 140, 80),
	staff       = Color(220, 220, 60),
}

local FACTION_NAMES = {
	prapor = "El Intendente", therapist = "La Doctora", fence = "El Chatarrero", skier = "El Contrabandista",
	peacekeeper = "El Agregado", mechanic = "El Armero", ragman = "La Costurera", jaeger = "El Montero",
	staff = "Staff",
}

local FACTION_ORDER = {"prapor", "therapist", "fence", "skier", "peacekeeper", "mechanic", "ragman", "jaeger", "staff"}

-- ============================================================
--  PANEL DE ADMINISTRACIÓN
-- ============================================================

local function blankMission()
	-- id único generado en cliente (prefijo distinto al contador del servidor para
	-- evitar colisiones). El servidor lo respeta si viene relleno.
	return {
		id = "m" .. os.time() .. "_" .. math.random(1000, 9999),
		name = "Nueva misión", description = "",
		adminName       = "",
		factions        = {},
		traderKey       = "",
		traderName      = "",
		isDaily         = false,
		allowedFactions = {},
		repeatMode = "once", cooldown = 0,
		rewardOptions = {{balas = 0, rep = 0, items = {}}},
		steps    = {},
		requires = {},
	}
end

-- ── Selector de ítem (estilo panel admin del trader) ────────────────────────────
-- onSelect(uid, itemData) se llama al confirmar la selección.
local function openItemPicker(onSelect)
	local sw, sh = ScrW(), ScrH()
	local PW      = SScale(280)
	local PSRCH_H = SScale(22)
	local PROW_H  = SScale(28)
	local PLIST_H = SScale(200)
	local PBTN_H  = SScale(24)
	local PH      = SScale(28) + PAD + PSRCH_H + GAP + PLIST_H + GAP + PBTN_H + PAD

	local pop = vgui.Create("DFrame")
	pop:SetSize(PW, PH); pop:Center()
	pop:SetTitle(""); pop:SetDraggable(true)
	pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
	pop.Paint = function(self, w, h)
		paintFrame(self, w, h)
		draw.SimpleText("Seleccionar ítem", "Metro UI.Button",
			PAD, PAD, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local searchBox = pop:Add("DTextEntry")
	searchBox:SetPos(PAD, SScale(26) + PAD)
	searchBox:SetSize(PW - PAD * 2, PSRCH_H)
	searchBox:SetFont("Metro UI.CharFields")
	searchBox.Paint = function(self, w, h)
		paintDarkEntry(self, w, h)
		if (self:GetValue() == "") then
			draw.SimpleText("Buscar por nombre o categoría...", "ixSmallFont",
				SScale(4), h / 2, Color(100, 100, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local listY = SScale(26) + PAD + PSRCH_H + GAP
	local itemScroll = pop:Add("DScrollPanel")
	itemScroll:SetPos(PAD, listY)
	itemScroll:SetSize(PW - PAD * 2, PLIST_H)
	itemScroll:GetVBar():SetWide(SScale(3))

	local selUID = {v = nil}

	local function buildList(filter)
		itemScroll:Clear()
		local sorted = {}
		for uid, data in pairs(ix.item.list) do
			local cat  = data.category or "Sin categoría"
			local filt = filter and filter:lower() or ""
			if (filt == "" or (data.name or ""):lower():find(filt, 1, true) or cat:lower():find(filt, 1, true)) then
				table.insert(sorted, {uid = uid, cat = cat, name = data.name or uid})
			end
		end
		table.sort(sorted, function(a, b) return (a.cat .. a.name) < (b.cat .. b.name) end)

		for _, entry in ipairs(sorted) do
			local uid = entry.uid
			local eRow = itemScroll:Add("DPanel")
			eRow:Dock(TOP); eRow:DockMargin(0, 0, 0, SScale(2)); eRow:SetTall(PROW_H)
			eRow:SetCursor("hand")
			eRow.Paint = function(me, w, h)
				local sel = (selUID.v == uid)
				surface.SetDrawColor(40, 40, 40, sel and 220 or (me:IsHovered() and 160 or 100))
				surface.DrawRect(0, 0, w, h)
				if (sel) then surface.SetDrawColor(154, 136, 102, 200); surface.DrawRect(0, 0, SScale(3), h) end
				surface.SetDrawColor(66, 66, 66, sel and 160 or (me:IsHovered() and 80 or 44))
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(entry.cat, "ixSmallFont",
					SScale(6), SScale(4), Color(185, 175, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText(entry.name, "Metro UI.CharFields",
					SScale(6), SScale(15), Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
			eRow.OnMousePressed = function(me, mc)
				if (mc == MOUSE_LEFT) then selUID.v = uid end
			end
		end
	end
	buildList(nil)
	searchBox.OnChange = function(s) buildList(s:GetValue()) end

	local btnY = listY + PLIST_H + GAP
	local BW1  = math.floor((PW - PAD * 3) * 2 / 3)
	local BW2  = PW - PAD * 3 - BW1

	makeBtn(pop, "Seleccionar", 30, 140, 30, function()
		if (!selUID.v) then return end
		if (onSelect) then onSelect(selUID.v, ix.item.list[selUID.v]) end
		pop:Remove()
	end):SetBounds(PAD, btnY, BW1, PBTN_H)

	makeBtn(pop, "Cancelar", 120, 30, 30, function() pop:Remove() end)
		:SetBounds(PAD + BW1 + PAD, btnY, BW2, PBTN_H)
end

-- Reconstruye el editor de la misión seleccionada
local function buildEditor(panel)
	panel.editScroll:Clear()
	local m = panel.working
	if (!m) then return end

	local scroll = panel.editScroll
	local W = scroll:GetWide()

	local function section(text)
		local l = scroll:Add("DLabel")
		l:Dock(TOP); l:DockMargin(0, GAP, 0, 2); l:SetTall(SScale(16))
		l:SetText(text); l:SetFont("Metro UI.CharFields"); l:SetTextColor(Color(185, 175, 140))
	end

	-- Nombre administrativo (solo panel admin)
	section("Nombre administrativo (solo admin)")
	local eAdminName = makeEntry(scroll, m.adminName or "")
	eAdminName:Dock(TOP); eAdminName:SetTall(SScale(20))
	eAdminName:SetPlaceholderText("Nombre interno para organizar (no visible al jugador)")
	eAdminName.Paint = function(self, w, h)
		paintDarkEntry(self, w, h)
		-- Borde naranja para diferenciar visualmente de campos públicos
		surface.SetDrawColor(200, 130, 30, 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	eAdminName.OnChange = function(s) m.adminName = s:GetValue() end

	-- Nombre (visible al jugador)
	section("Nombre (visible al jugador)")
	local eName = makeEntry(scroll, m.name)
	eName:Dock(TOP); eName:SetTall(SScale(20))
	eName.OnChange = function(s) m.name = s:GetValue() end

	-- Descripción
	section("Descripción")
	local eDesc = makeEntry(scroll, m.description)
	eDesc:Dock(TOP); eDesc:SetTall(SScale(40)); eDesc:SetMultiline(true)
	eDesc.OnChange = function(s) m.description = s:GetValue() end

	-- Trader asignado
	section("Trader que la ofrece")

	m.traderKey  = m.traderKey  or ""
	m.traderName = m.traderName or ""

	-- Estado actual de la asignación
	local assignRow = scroll:Add("DPanel")
	assignRow:Dock(TOP); assignRow:DockMargin(0, 0, 0, 2); assignRow:SetTall(SScale(22))
	assignRow.Paint = function(_, w, h)
		surface.SetDrawColor(40, 40, 40, 200); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 60);  surface.DrawOutlinedRect(0, 0, w, h, 1)
		if (m.traderKey != "") then
			local label = (m.traderName != "") and m.traderName or m.traderKey
			surface.SetDrawColor(30, 160, 30, 150); surface.DrawRect(0, 0, SScale(3), h)
			draw.SimpleText("+  " .. label, "Metro UI.CharFields",
				SScale(8), h / 2, Color(120, 210, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("Sin asignar — ningún trader ofrecerá esta misión", "ixSmallFont",
				SScale(8), h / 2, Color(160, 100, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- Selector de trader: dropdown con todos los traders existentes
	local traderList = ix.missions._traderList or {}
	if (#traderList > 0) then
		local combo = scroll:Add("DComboBox")
		combo:Dock(TOP)
		combo:DockMargin(0, SScale(2), 0, 0)
		combo:SetTall(SScale(22))
		combo:SetFont("Metro UI.CharFields")
		combo.Paint = paintDarkEntry

		local comboVal = "Seleccionar trader..."
		if (m.traderKey != "") then
			comboVal = (m.traderName != "") and m.traderName or m.traderKey
		end
		combo:SetValue(comboVal)

		for _, td in ipairs(traderList) do
			combo:AddChoice(td.name .. "  [" .. td.factionKey .. "]", td)
		end
		combo.OnSelect = function(_, _, _, td)
			m.traderKey  = td.key
			m.traderName = td.name
			buildEditor(panel)
		end
	elseif (panel.contextTrader and IsValid(panel.contextTrader)) then
		-- Fallback: botón de asignación rápida si no hay lista de traders aún
		local ctKey  = panel.contextTrader:GetNetVar("traderKey",  "")
		local ctName = panel.contextTrader:GetNetVar("traderName", "Comerciante")
		if (ctKey != "") then
			local btnAssign = makeBtn(scroll, "Asignar: " .. ctName, 30, 110, 30, function()
				m.traderKey  = ctKey
				m.traderName = ctName
				buildEditor(panel)
			end)
			btnAssign:Dock(TOP)
			btnAssign:DockMargin(0, SScale(2), 0, 0)
			btnAssign:SetTall(SScale(22))
		else
			local lWarn = makeLabel(scroll, "Este trader no tiene clave asignada — usa /TraderSpawn para spawnearlo.", "ixSmallFont", Color(154, 136, 102))
			lWarn:Dock(TOP); lWarn:DockMargin(0, SScale(2), 0, 0); lWarn:SetTall(SScale(24)); lWarn:SetWrap(true)
		end
	else
		local lNone = makeLabel(scroll, "No hay traders creados. Usa /TraderSpawn para crear uno.", "ixSmallFont", Color(120, 120, 120))
		lNone:Dock(TOP); lNone:DockMargin(0, SScale(2), 0, 0); lNone:SetTall(SScale(14))
	end

	-- Botón: limpiar asignación
	if (m.traderKey != "") then
		local btnClear = makeBtn(scroll, "Limpiar asignación", 110, 30, 30, function()
			m.traderKey  = ""
			m.traderName = ""
			m.isDaily    = false
			buildEditor(panel)
		end)
		btnClear:Dock(TOP)
		btnClear:DockMargin(0, SScale(2), 0, 0)
		btnClear:SetTall(SScale(22))

		-- Misión diaria: el trader sólo ofrece UNA misión de su pool "diaria" a la
		-- vez, que rota cada 24h o al reiniciar el servidor.
		local togDaily = scroll:Add("DButton")
		togDaily:Dock(TOP); togDaily:DockMargin(0, SScale(2), 0, 0); togDaily:SetTall(SScale(20))
		togDaily:SetText(""); togDaily.on = (m.isDaily == true)
		togDaily.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 40, s.on and 200 or (s:IsHovered() and 130 or 70))
			surface.DrawRect(0, 0, w, h)
			if (s.on) then surface.SetDrawColor(112, 128, 130, 180); surface.DrawRect(0, 0, SScale(3), h) end
			surface.SetDrawColor(66, 66, 66, s.on and 140 or (s:IsHovered() and 70 or 36))
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText((s.on and "+  " or "    ") .. "Misión diaria (rota cada 24h o al reiniciar)", "ixSmallFont",
				SScale(8), h / 2,
				s.on and Color(120, 190, 230) or Color(150, 150, 150),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		togDaily.DoClick = function(s)
			s.on = !s.on
			m.isDaily = s.on
			buildEditor(panel)
		end

		if (m.isDaily) then
			local activeId = ix.missions._dailyState[m.traderKey] and ix.missions._dailyState[m.traderKey].missionId
			local isActive = (activeId == m.id)
			local lDaily = makeLabel(scroll,
				isActive and "+ Esta es la misión diaria activa actualmente para este trader."
					or "En espera — rotará cuando le toque su turno en el pool diario.",
				"ixSmallFont", isActive and Color(120, 220, 120) or Color(160, 160, 100))
			lDaily:Dock(TOP); lDaily:DockMargin(0, SScale(2), 0, 0); lDaily:SetTall(SScale(14))
		end
	end

	-- Facciones permitidas del jugador (restricción opcional)
	section("Facciones del jugador que pueden aceptarla (vacío = todas)")
	m.allowedFactions = m.allowedFactions or {}

	-- Nota informativa
	local lFacHint = makeLabel(scroll, "Si no se selecciona ninguna, cualquier facción puede aceptar esta misión.", "ixSmallFont", Color(120, 120, 120))
	lFacHint:Dock(TOP); lFacHint:DockMargin(0, 0, 0, SScale(2)); lFacHint:SetTall(SScale(12))

	-- Cuadrícula de toggles (5 por fila → 2 filas para 9 facciones)
	local BTN_W   = SScale(80)
	local BTN_H   = SScale(20)
	local BTN_SP  = SScale(2)
	local facRows = math.ceil(#FACTION_ORDER / 5)
	local facWrap = scroll:Add("DIconLayout")
	facWrap:Dock(TOP); facWrap:DockMargin(0, 0, 0, 0)
	facWrap:SetTall(facRows * (BTN_H + BTN_SP) + BTN_SP)
	facWrap:SetSpaceX(BTN_SP); facWrap:SetSpaceY(BTN_SP)

	for _, fk in ipairs(FACTION_ORDER) do
		local fname = FACTION_NAMES[fk] or fk
		local fc    = FACTION_COLORS[fk] or Color(150, 150, 150)
		local tog   = facWrap:Add("DButton")
		tog:SetSize(BTN_W, BTN_H)
		tog:SetText("")
		tog.on = table.HasValue(m.allowedFactions, fk)
		tog.Paint = function(s, w, h)
			surface.SetDrawColor(fc.r, fc.g, fc.b, s.on and 70 or 14)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(fc.r, fc.g, fc.b, s.on and 180 or 50)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(fname, "ixSmallFont",
				w / 2, h / 2,
				s.on and Color(220, 220, 220) or Color(120, 120, 120),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		tog.DoClick = function(s)
			s.on = !s.on
			if (s.on) then
				if (!table.HasValue(m.allowedFactions, fk)) then table.insert(m.allowedFactions, fk) end
			else
				table.RemoveByValue(m.allowedFactions, fk)
			end
		end
	end

	-- Repetición
	section("Repetición")
	local repCombo = scroll:Add("DComboBox")
	repCombo:Dock(TOP); repCombo:SetTall(SScale(20)); repCombo:SetFont("Metro UI.CharFields")
	repCombo.Paint = paintDarkEntry
	for _, rm in ipairs(ix.missions.repeatModes) do
		repCombo:AddChoice(rm.name, rm.key, m.repeatMode == rm.key)
	end
	repCombo.OnSelect = function(_, _, _, data) m.repeatMode = data end

	local eCd = makeEntry(scroll, m.cooldown)
	eCd:Dock(TOP); eCd:DockMargin(0, 2, 0, 0); eCd:SetTall(SScale(18))
	eCd:SetPlaceholderText("Espera en segundos (solo 'Repetible con espera')")
	eCd.OnChange = function(s) m.cooldown = math.max(0, math.floor(tonumber(s:GetValue()) or 0)) end

	-- Prerrequisitos — misiones que el jugador debe haber completado antes
	section("Prerrequisitos")
	m.requires = m.requires or {}
	local otherMissions = {}
	for id, om in SortedPairsByMemberValue(ix.missions._adminData, "name") do
		if (id != m.id) then
			otherMissions[#otherMissions + 1] = {id = id, name = om.name or id}
		end
	end
	if (#otherMissions == 0) then
		local lNone = makeLabel(scroll, "No hay otras misiones guardadas aún.", "ixSmallFont", Color(120, 120, 120))
		lNone:Dock(TOP); lNone:SetTall(SScale(14))
	else
		for _, om in ipairs(otherMissions) do
			local isReq = table.HasValue(m.requires, om.id)
			local omId  = om.id; local omName = om.name
			local tog = scroll:Add("DButton")
			tog:Dock(TOP); tog:DockMargin(0, 2, 0, 0); tog:SetTall(SScale(20))
			tog:SetText(""); tog.on = isReq
			tog.Paint = function(s, w, h)
				surface.SetDrawColor(40, 40, 40, s.on and 200 or (s:IsHovered() and 130 or 70))
				surface.DrawRect(0, 0, w, h)
				if (s.on) then surface.SetDrawColor(154, 136, 102, 180); surface.DrawRect(0, 0, SScale(3), h) end
				surface.SetDrawColor(66, 66, 66, s.on and 140 or (s:IsHovered() and 70 or 36))
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText((s.on and "+  " or "    ") .. omName, "ixSmallFont",
					SScale(8), h / 2,
					s.on and Color(199, 197, 179) or Color(150, 150, 150),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			tog.DoClick = function(s)
				s.on = !s.on
				if (s.on) then
					if (!table.HasValue(m.requires, omId)) then table.insert(m.requires, omId) end
				else
					table.RemoveByValue(m.requires, omId)
				end
			end
		end
	end

	-- Recompensas (múltiples opciones a elegir)
	section("Opciones de recompensa (el jugador elige una al completar)")

	-- Compatibilidad con misiones antiguas que solo tienen .rewards
	m.rewardOptions = m.rewardOptions or (m.rewards and {m.rewards}) or {{balas=0, rep=0, items={}}}

	for optIdx, opt in ipairs(m.rewardOptions) do
		local optIdxCap = optIdx

		-- Cabecera de opción
		local optHdr = scroll:Add("DPanel")
		optHdr:Dock(TOP); optHdr:DockMargin(0, GAP, 0, 0); optHdr:SetTall(SScale(18))
		optHdr.Paint = function(_, w, h)
			surface.SetDrawColor(35, 35, 55, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(80, 80, 200, 150); surface.DrawRect(0, 0, SScale(3), h)
			surface.SetDrawColor(66, 66, 100, 80);  surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("Opción " .. optIdxCap, "Metro UI.CharFields",
				SScale(8), h / 2, Color(180, 180, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		if (#m.rewardOptions > 1) then
			makeBtn(optHdr, "Eliminar", 130, 30, 30, function()
				table.remove(m.rewardOptions, optIdxCap)
				buildEditor(panel)
			end):SetBounds(W - SScale(58), SScale(1), SScale(54), SScale(16))
		end

		-- Fila Balas / Rep
		opt.items = opt.items or {}
		local rewRow = scroll:Add("DPanel")
		rewRow:Dock(TOP); rewRow:SetTall(SScale(20)); rewRow.Paint = nil
		local lB = makeLabel(rewRow, "Rublos", "ixSmallFont", Color(199, 197, 179))
		lB:SetPos(0, SScale(3)); lB:SetSize(SScale(40), SScale(14))
		local eBalas = makeEntry(rewRow, opt.balas or 0)
		eBalas:SetPos(SScale(42), 0); eBalas:SetSize(SScale(60), SScale(18))
		eBalas.OnChange = function(s) opt.balas = math.max(0, math.floor(tonumber(s:GetValue()) or 0)) end
		local lR = makeLabel(rewRow, "Rep", "ixSmallFont", Color(120, 200, 120))
		lR:SetPos(SScale(112), SScale(3)); lR:SetSize(SScale(30), SScale(14))
		local eRepO = makeEntry(rewRow, opt.rep or 0)
		eRepO:SetPos(SScale(144), 0); eRepO:SetSize(SScale(60), SScale(18))
		eRepO.OnChange = function(s) opt.rep = math.max(0, math.floor(tonumber(s:GetValue()) or 0)) end

		-- Ítems de esta opción
		for idx, entry in ipairs(opt.items) do
			local itemData = ix.item.list[entry.id]
			local itemName = itemData and itemData.name or ("??? — " .. (entry.id or "vacío"))
			local iRow = scroll:Add("DPanel")
			iRow:Dock(TOP); iRow:DockMargin(0, 2, 0, 0); iRow:SetTall(SScale(22))
			iRow.Paint = function(_, w, h)
				surface.SetDrawColor(40, 40, 40, 180); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(154, 136, 102, 80);  surface.DrawRect(0, 0, SScale(3), h)
				surface.SetDrawColor(66, 66, 66, 60);   surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(itemName, "Metro UI.CharFields",
					SScale(8), h / 2, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			local eQ = makeEntry(iRow, entry.qty or 1)
			eQ:SetPos(W - SScale(78), SScale(2)); eQ:SetSize(SScale(48), SScale(18))
			eQ:SetPlaceholderText("Cant.")
			eQ.OnChange = function(s) entry.qty = math.max(1, math.floor(tonumber(s:GetValue()) or 1)) end
			local idxCap = idx
			makeBtn(iRow, "X", 130, 30, 30, function()
				table.remove(m.rewardOptions[optIdxCap].items, idxCap)
				buildEditor(panel)
			end):SetBounds(W - SScale(26), SScale(2), SScale(20), SScale(18))
		end

		local btnAddItemO = makeBtn(scroll, "Añadir ítem a opción " .. optIdx .. "...", 30, 80, 30, function()
			openItemPicker(function(uid)
				table.insert(m.rewardOptions[optIdxCap].items, {id = uid, qty = 1})
				buildEditor(panel)
			end)
		end)
		btnAddItemO:Dock(TOP); btnAddItemO:DockMargin(0, SScale(2), 0, 0); btnAddItemO:SetTall(SScale(20))
	end

	-- Botón para añadir nueva opción de recompensa
	local btnAddOpt = makeBtn(scroll, "+ Añadir opción de recompensa", 30, 100, 100, function()
		table.insert(m.rewardOptions, {balas = 0, rep = 0, items = {}})
		buildEditor(panel)
	end)
	btnAddOpt:Dock(TOP); btnAddOpt:DockMargin(0, SScale(4), 0, 0); btnAddOpt:SetTall(SScale(22))

	-- Pasos
	section("Pasos de la misión")
	for i, step in ipairs(m.steps) do
		local typeInfo = ix.missions.GetStepType(step.type) or {name = step.type, command = "?"}
		local isActive = (panel.activeStep == i and m.id == panel.activeMissionId)

		local sRow = scroll:Add("DPanel")
		sRow:Dock(TOP); sRow:DockMargin(0, 2, 0, 0); sRow:SetTall(SScale(76))
		sRow.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 40, 220); surface.DrawRect(0, 0, w, h)
			if (isActive) then
				surface.SetDrawColor(66, 166, 66, 200); surface.DrawRect(0, 0, SScale(3), h)
			end
			surface.SetDrawColor(66, 66, 66, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("#" .. i .. "  " .. typeInfo.name, "Metro UI.CharFields",
				SScale(6), SScale(5), Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- Parámetros según tipo
		if (step.type == "kill") then
			local eClass = makeEntry(sRow, step.npcClass or "")
			eClass:SetPos(SScale(6), SScale(20)); eClass:SetSize(W - SScale(120), SScale(16))
			eClass:SetPlaceholderText("clase npc (ej: npc_zombie)")
			eClass.OnChange = function(s) step.npcClass = s:GetValue() end
			local eCnt = makeEntry(sRow, step.count or 1)
			eCnt:SetPos(W - SScale(110), SScale(20)); eCnt:SetSize(SScale(34), SScale(16))
			eCnt.OnChange = function(s) step.count = math.max(1, math.floor(tonumber(s:GetValue()) or 1)) end
		elseif (step.type == "fetch" or step.type == "deliver") then
			local pickedData = step.itemID and ix.item.list[step.itemID]
			local pickedLabel = pickedData and pickedData.name or (step.itemID or "Seleccionar ítem...")
			local btnItem = makeBtn(sRow, pickedLabel, 30, 80, 30, function()
				openItemPicker(function(uid)
					step.itemID = uid
					buildEditor(panel)
				end)
			end)
			btnItem:SetPos(SScale(6), SScale(20)); btnItem:SetSize(W - SScale(120), SScale(16))
			local eCnt = makeEntry(sRow, step.count or 1)
			eCnt:SetPos(W - SScale(110), SScale(20)); eCnt:SetSize(SScale(34), SScale(16))
			eCnt.OnChange = function(s) step.count = math.max(1, math.floor(tonumber(s:GetValue()) or 1)) end
		end

		-- Descripción visible al jugador en el checklist de misión
		local eStepDesc = makeEntry(sRow, step.description or "")
		eStepDesc:SetPos(SScale(6), SScale(40)); eStepDesc:SetSize(W - SScale(12), SScale(16))
		eStepDesc:SetPlaceholderText("Descripción del paso (visible al jugador en el inventario)")
		eStepDesc.OnChange = function(s)
			local v = s:GetValue()
			step.description = (v != "") and v or nil
		end

		-- Estado de captura del mundo
		local needsWorld = (step.type == "explore" or step.type == "fetch")
		local hasPos     = (step.pos != nil)
		if (needsWorld) then
			local statusTxt = hasPos and "Punto fijado +" or ("Sin fijar — usa " .. typeInfo.command)
			local lStat = makeLabel(sRow, statusTxt, "ixSmallFont", hasPos and Color(120, 200, 120) or Color(200, 120, 60))
			lStat:SetPos(SScale(6), SScale(59)); lStat:SetSize(W - SScale(160), SScale(14))
		end

		-- Botones: activar para captura + eliminar
		makeBtn(sRow, isActive and "● Activo" or "Activar", 66, 100, 166, function()
			if (!ix.missions._adminData[m.id]) then
				chat.AddText(Color(154, 136, 102), "[Misiones] Guarda la misión antes de capturar datos del mundo.")
				return
			end
			panel.activeStep = i
			panel.activeMissionId = m.id
			net.Start("missions_SetActiveStep")
				net.WriteString(m.id)
				net.WriteUInt(i, 8)
			net.SendToServer()
			buildEditor(panel)
		end):SetBounds(W - SScale(72), SScale(20), SScale(66), SScale(16))

		makeBtn(sRow, "Eliminar paso", 130, 30, 30, function()
			table.remove(m.steps, i); buildEditor(panel)
		end):SetBounds(W - SScale(72), SScale(59), SScale(66), SScale(16))
	end

	-- Añadir paso (selector de tipo)
	local addStep = scroll:Add("DComboBox")
	addStep:Dock(TOP); addStep:DockMargin(0, GAP, 0, 0); addStep:SetTall(SScale(20))
	addStep:SetFont("Metro UI.CharFields"); addStep.Paint = paintDarkEntry
	addStep:SetValue("+ Añadir paso...")
	for _, st in ipairs(ix.missions.stepTypes) do
		addStep:AddChoice(st.name .. " — " .. st.desc, st.key)
	end
	addStep.OnSelect = function(_, _, _, data)
		table.insert(m.steps, {type = data, count = 1})
		buildEditor(panel)
	end

	-- Guardar
	local btnSave = makeBtn(scroll, "+ Guardar misión", 30, 140, 30, function()
		panel.selectedId = m.id
		net.Start("missions_AdminSave")
			net.WriteTable(m)
		net.SendToServer()
		chat.AddText(Color(80, 200, 80), "[Misiones] Misión guardada.")
	end)
	btnSave:Dock(TOP)
	btnSave:DockMargin(0, SScale(4), 0, 0)
	btnSave:SetTall(SScale(26))
	scroll:InvalidateLayout(true)
end

-- Reconstruye la lista de misiones (columna izquierda)
-- Ordena misiones: primero por adminName (si lo tiene), luego por name
local function sortMissions(data)
	local list = {}
	for id, mission in pairs(data) do
		table.insert(list, {id = id, mission = mission})
	end
	table.sort(list, function(a, b)
		local keyA = (a.mission.adminName and a.mission.adminName != "") and a.mission.adminName or a.mission.name
		local keyB = (b.mission.adminName and b.mission.adminName != "") and b.mission.adminName or b.mission.name
		return keyA < keyB
	end)
	return list
end

local function buildMissionList(panel)
	panel.listScroll:Clear()
	for _, entry in ipairs(sortMissions(ix.missions._adminData)) do
		local id      = entry.id
		local mission = entry.mission
		local hasAdmin = mission.adminName and mission.adminName != ""
		local rowH     = hasAdmin and SScale(38) or SScale(26)

		local row = panel.listScroll:Add("DButton")
		row:Dock(TOP); row:DockMargin(0, 0, 0, 2); row:SetTall(rowH)
		row:SetText("")
		local selected = (panel.selectedId == id)
		row.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 40, selected and 240 or (s:IsHovered() and 180 or 120))
			surface.DrawRect(0, 0, w, h)
			if (selected) then surface.SetDrawColor(154, 136, 102, 220); surface.DrawRect(0, 0, SScale(3), h) end
			surface.SetDrawColor(66, 66, 66, 70); surface.DrawOutlinedRect(0, 0, w, h, 1)
			if (hasAdmin) then
				-- Nombre admin (naranja, pequeño, arriba)
				draw.SimpleText(mission.adminName, "ixSmallFont",
					SScale(8), SScale(6), Color(154, 136, 102), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				-- Nombre público (gris, abajo)
				draw.SimpleText(mission.name, "Metro UI.CharFields",
					SScale(8), SScale(20), Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			else
				draw.SimpleText(mission.name, "Metro UI.CharFields",
					SScale(8), h / 2, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
		row.DoClick = function()
			panel.selectedId = id
			panel.working    = table.Copy(mission)
			buildMissionList(panel)
			buildEditor(panel)
		end
	end
end

function ix.missions.OpenAdmin(traderEnt)
	if (!LocalPlayer():IsAdmin()) then return end

	if (IsValid(ix.missions._adminPanel)) then ix.missions._adminPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(760), sw - SScale(40))
	local H = math.min(SScale(520), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.missions._adminPanel = frame

	local title = makeLabel(frame, "Administración de Misiones", "Metro UI.Button", Color(225, 225, 225))
	title:SetPos(PAD, PAD); title:SetSize(W - SScale(80), SScale(20))

	makeBtn(frame, "Cerrar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	local listW = SScale(200)
	local topY  = SScale(34)

	-- Columna izquierda: lista + acciones
	frame.listScroll = frame:Add("DScrollPanel")
	frame.listScroll:SetPos(PAD, topY)
	frame.listScroll:SetSize(listW, H - topY - SScale(34) - PAD)
	frame.listScroll:GetVBar():SetWide(SScale(3))

	makeBtn(frame, "+ Nueva misión", 30, 100, 30, function()
		frame.selectedId = nil
		frame.working    = blankMission()
		buildMissionList(frame)
		buildEditor(frame)
	end):SetBounds(PAD, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	makeBtn(frame, "Eliminar", 130, 30, 30, function()
		if (!frame.selectedId) then return end
		Derma_Query("¿Eliminar esta misión?", "Confirmar",
			"Sí", function()
				net.Start("missions_AdminDelete")
					net.WriteString(frame.selectedId)
				net.SendToServer()
				frame.selectedId = nil; frame.working = nil
			end,
			"No", function() end)
	end):SetBounds(PAD + listW / 2 + 2, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	-- Columna derecha: editor
	local editX = PAD + listW + GAP
	frame.editScroll = frame:Add("DScrollPanel")
	frame.editScroll:SetPos(editX, topY)
	frame.editScroll:SetSize(W - editX - PAD, H - topY - PAD)
	frame.editScroll:GetVBar():SetWide(SScale(3))

	frame.activeStep      = nil
	frame.activeMissionId = nil
	frame.contextTrader   = IsValid(traderEnt) and traderEnt or nil

	buildMissionList(frame)

	-- Pedir datos al servidor
	net.Start("missions_AdminRequest")
	net.SendToServer()
end

net.Receive("missions_OpenAdmin", function()
	ix.missions.OpenAdmin()
end)

net.Receive("missions_TraderList", function()
	ix.missions._traderList = net.ReadTable()
	local panel = ix.missions._adminPanel
	if (IsValid(panel) and panel.working) then
		buildEditor(panel)
	end
end)

net.Receive("missions_AdminData", function()
	ix.missions._adminData  = net.ReadTable()
	ix.missions._dailyState = net.ReadTable()

	local panel = ix.missions._adminPanel
	if (!IsValid(panel)) then return end

	buildMissionList(panel)

	-- Si hay una misión seleccionada y sigue existiendo, recargar copia de trabajo
	-- (recoge posiciones capturadas por comandos). El flujo guarda antes de capturar.
	if (panel.selectedId and ix.missions._adminData[panel.selectedId]) then
		panel.working = table.Copy(ix.missions._adminData[panel.selectedId])
		buildEditor(panel)
	end
end)

-- ============================================================
--  SELECCIÓN DE RECOMPENSA AL COMPLETAR MISIÓN
-- ============================================================

net.Receive("missions_ShowRewards", function()
	local traderEnt = net.ReadEntity()
	local options   = net.ReadTable()

	if (!IsValid(traderEnt) or !options or #options == 0) then return end
	if (IsValid(ix.missions._rewardChoicePanel)) then ix.missions._rewardChoicePanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(420), sw - SScale(40))

	-- Misma tonalidad gris/naranja que el resto de paneles MetroUI (paintFrame)
	local ACCENT       = Color(154, 136, 102)
	local ACCENT_LIGHT = Color(243, 173, 128)

	-- Calcula la altura de cada card según su contenido (compacta)
	local function cardHeight(opt)
		local h = SScale(18)  -- título + sep
		if ((opt.balas or 0) > 0) then h = h + SScale(10) end
		if ((opt.rep   or 0) > 0) then h = h + SScale(10) end
		if (opt.items and #opt.items > 0) then h = h + SScale(10) * #opt.items end
		h = h + SScale(22)  -- botón ELEGIR
		return math.max(h, SScale(46))
	end

	local totalCards = -GAP  -- compensa el GAP extra de la última card
	for _, opt in ipairs(options) do totalCards = totalCards + cardHeight(opt) + GAP end
	local H = math.min(SScale(44) + totalCards + SScale(44), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:SetDraggable(false)
	frame:ShowCloseButton(false); frame:MakePopup(); frame:SetDeleteOnClose(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.missions._rewardChoicePanel = frame

	-- Título centrado
	local lTitle = makeLabel(frame, "— ELIGE TU RECOMPENSA —", "Metro UI.CharFields", ACCENT_LIGHT)
	lTitle:SetPos(0, SScale(10)); lTitle:SetSize(W, SScale(16))
	lTitle:SetContentAlignment(5)

	local scroll = frame:Add("DScrollPanel")
	scroll:SetPos(PAD, SScale(32))
	scroll:SetSize(W - PAD * 2, math.max(1, H - SScale(32) - SScale(40) - PAD))
	scroll:GetVBar():SetWide(SScale(3))

	for i, opt in ipairs(options) do
		local iCap = i
		local ch   = cardHeight(opt)
		local card = scroll:Add("DPanel")
		card:Dock(TOP); card:DockMargin(0, 0, 0, GAP); card:SetTall(ch)

		card.Paint = function(s, w, h)
			local hover = s:IsHovered()
			surface.SetDrawColor(40, 40, 40, hover and 230 or 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, hover and 220 or 140)
			surface.DrawRect(0, 0, SScale(3), h)
			surface.SetDrawColor(66, 66, 66, hover and 120 or 70)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		-- Número de opción alineado a la izquierda
		local lOpt = makeLabel(card, "OPCIÓN  " .. i, "Metro UI.CharFields", ACCENT_LIGHT)
		lOpt:SetBounds(SScale(12), SScale(4), W - SScale(24), SScale(11))

		-- Separador fino
		local sep = card:Add("DPanel")
		sep:SetBounds(SScale(12), SScale(16), W - SScale(24), 1)
		sep.Paint = function(_, w, h)
			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 60); surface.DrawRect(0, 0, w, h)
		end

		local cy = SScale(20)

		-- Balas
		if ((opt.balas or 0) > 0) then
			local iconSize = SScale(9)
			local icon = card:Add("DPanel")
			icon:SetBounds(SScale(12), cy, iconSize, iconSize)
			icon.Paint = function(_, w, h)
				surface.SetDrawColor(199, 190, 150, 255)
				surface.SetMaterial(matMoney)
				surface.DrawTexturedRect(0, 0, w, h)
			end

			makeLabel(card, opt.balas .. " RUB", "ixSmallFont", Color(199, 190, 150))
				:SetBounds(SScale(12) + iconSize + SScale(4), cy, W - SScale(24) - iconSize - SScale(4), SScale(9))
			cy = cy + SScale(10)
		end

		-- Reputación
		if ((opt.rep or 0) > 0) then
			makeLabel(card, "^  +" .. opt.rep .. " Reputación", "ixSmallFont", Color(120, 210, 120))
				:SetBounds(SScale(12), cy, W - SScale(24), SScale(9))
			cy = cy + SScale(10)
		end

		-- Ítems — uno por línea
		if (opt.items and #opt.items > 0) then
			for _, entry in ipairs(opt.items) do
				local d   = ix.item.list[entry.id]
				local qty = entry.qty or 1
				local name = (d and d.name or entry.id) .. (qty > 1 and "  ×" .. qty or "")
				makeLabel(card, "◆  " .. name, "ixSmallFont", Color(170, 210, 200))
					:SetBounds(SScale(12), cy, W - SScale(24), SScale(9))
				cy = cy + SScale(10)
			end
		end

		-- Botón ELEGIR — barra completa al fondo de la card
		makeBtn(card, "ELEGIR ESTA RECOMPENSA", 30, 140, 30, function()
			net.Start("missions_RewardChoice")
				net.WriteEntity(traderEnt)
				net.WriteUInt(iCap, 8)
			net.SendToServer()
			frame:Remove()
		end):SetBounds(SScale(12), ch - SScale(18), W - SScale(24), SScale(16))
	end

	makeBtn(frame, "Cancelar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W / 2 - SScale(44), H - SScale(36), SScale(88), SScale(24))
end)

-- ============================================================
--  NAVEGADOR DE MISIONES DEL JUGADOR
-- ============================================================

function ix.missions.RequestList(traderEnt)
	if (!IsValid(traderEnt)) then return end
	ix.missions._traderEnt = traderEnt
	net.Start("missions_RequestList")
		net.WriteEntity(traderEnt)
	net.SendToServer()
end

net.Receive("missions_OfferList", function()
	local traderEnt      = net.ReadEntity()
	local offers         = net.ReadTable()
	local communityOffers = net.ReadTable() or {}

	if (!IsValid(traderEnt)) then return end
	if (IsValid(ix.missions._offerPanel)) then ix.missions._offerPanel:Remove() end

	local fk = traderEnt:GetNetVar("factionKey", "prapor")
	local fc = FACTION_COLORS[fk] or Color(154, 136, 102)
	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(440), sw - SScale(40))
	local H = math.min(SScale(420), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h, fc) end
	ix.missions._offerPanel = frame

	local title = makeLabel(frame, "Tablón de misiones", "Metro UI.Button", Color(225, 225, 225))
	title:SetPos(PAD, PAD); title:SetSize(W - SScale(80), SScale(20))

	makeBtn(frame, "Cerrar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	-- La entrega de objetos de misión ya se ofrece desde el diálogo del
	-- trader (primera opción si el jugador lleva el ítem pedido), así que
	-- este botón duplicado del tablón se elimina.
	local scroll = frame:Add("DScrollPanel")
	scroll:SetPos(PAD, SScale(36))
	scroll:SetSize(W - PAD * 2, H - SScale(36) - PAD)
	scroll:GetVBar():SetWide(SScale(3))

	-- ── Misiones comunitarias (arriba del todo) ─────────────────────────────────
	for _, cm in ipairs(communityOffers) do
		local accentCol = cm.completed and Color(80, 180, 80) or Color(112, 128, 130)

		-- Calcular alto dinámico: más alto si hay múltiples ítems de entrega
		local hasMultiItems = (cm.type == "deliver" and cm.deliverItems and #cm.deliverItems > 0)
		local extraItemRows = hasMultiItems and #cm.deliverItems or 0
		local cardH = SScale(110) + extraItemRows * SScale(10)

		local card = scroll:Add("DPanel")
		card:Dock(TOP); card:DockMargin(0, 0, 0, GAP); card:SetTall(cardH)
		card.Paint = function(s, w, h)
			surface.SetDrawColor(35, 35, 45, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 100); surface.DrawRect(0, 0, SScale(3), h)
			surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 60);  surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		-- Nombre + etiqueta
		local tag = cm.completed and "  [Completada]" or "  [Comunitaria]"
		local lName = makeLabel(card, (cm.name or "") .. tag, "Metro UI.CharFields", accentCol)
		lName:SetPos(SScale(8), SScale(5)); lName:SetSize(W - SScale(40), SScale(16))

		-- Descripción
		local lDesc = makeLabel(card, cm.description or "", "ixSmallFont", Color(160, 160, 160))
		lDesc:SetPos(SScale(8), SScale(20)); lDesc:SetSize(W - SScale(40), SScale(20)); lDesc:SetWrap(true)

		-- Progreso: barras individuales por ítem o barra global
		local progressY = SScale(42)

		if (hasMultiItems) then
			for _, di in ipairs(cm.deliverItems) do
				local d = ix.item.list[di.id]
				local itemName = d and d.name or di.id
				local done  = cm.deliverProgress and cm.deliverProgress[di.id] or 0
				local goal  = di.count or 1
				local iPct  = math.Clamp(done / math.max(goal, 1), 0, 1)

				local iBar = card:Add("DPanel")
				iBar:SetPos(SScale(8), progressY); iBar:SetSize(W - PAD * 2 - SScale(16), SScale(8))
				iBar.Paint = function(_, w, h)
					surface.SetDrawColor(30, 30, 30, 220); surface.DrawRect(0, 0, w, h)
					if (iPct > 0) then
						surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 180)
						surface.DrawRect(0, 0, math.floor(w * iPct), h)
					end
					draw.SimpleText(itemName .. "  " .. done .. "/" .. goal, "ixSmallFont",
						SScale(4), h / 2, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				progressY = progressY + SScale(10)
			end
		else
			local barW = W - PAD * 2 - SScale(16)
			local barH = SScale(10)
			local pct  = math.Clamp((cm.progress or 0) / math.max(cm.goalCount or 1, 1), 0, 1)

			local barPanel = card:Add("DPanel")
			barPanel:SetPos(SScale(8), progressY); barPanel:SetSize(barW, barH)
			barPanel.Paint = function(_, w, h)
				surface.SetDrawColor(30, 30, 30, 220); surface.DrawRect(0, 0, w, h)
				if (pct > 0) then
					surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 180)
					surface.DrawRect(0, 0, math.floor(w * pct), h)
				end
				draw.SimpleText((cm.progress or 0) .. " / " .. (cm.goalCount or 1), "ixSmallFont",
					w / 2, h / 2, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			progressY = progressY + SScale(12)
		end

		-- Info de participación
		local infoY = progressY + SScale(2)
		if (cm.joined) then
			makeLabel(card, "Tu aporte: " .. (cm.myContribution or 0), "ixSmallFont", Color(120, 200, 120))
				:SetBounds(SScale(8), infoY, SScale(200), SScale(12))
		end

		makeLabel(card, (cm.participantCount or 0) .. " participantes", "ixSmallFont", Color(120, 120, 120))
			:SetBounds(SScale(8), infoY + SScale(12), SScale(200), SScale(12))

		-- Recompensa
		local rew = cm.rewardOptions and cm.rewardOptions[1] or {}
		local rewParts = {}
		if ((rew.balas or 0) > 0) then table.insert(rewParts, rew.balas .. " RUB") end
		if ((rew.rep or 0) > 0)   then table.insert(rewParts, "+" .. rew.rep .. " Rep") end
		if (rew.items and #rew.items > 0) then table.insert(rewParts, #rew.items .. " ítem(s)") end
		if (#rewParts > 0) then
			makeLabel(card, "Recompensa: " .. table.concat(rewParts, " • "), "ixSmallFont", Color(199, 197, 179))
				:SetBounds(SScale(8), infoY + SScale(24), W - SScale(120), SScale(12))
		end

		-- Botón de acción (posición dinámica basada en contenido)
		local btnY = cardH - SScale(30)
		if (cm.completed and cm.joined) then
			makeBtn(card, "Reclamar", 30, 160, 30, function()
				net.Start("cmission_Claim")
				net.SendToServer()
				frame:Remove()
			end):SetBounds(W - SScale(96) - PAD, btnY, SScale(80), SScale(26))
		elseif (!cm.completed and !cm.joined) then
			makeBtn(card, "Unirse", 30, 100, 180, function()
				net.Start("cmission_Join")
				net.SendToServer()
				frame:Remove()
			end):SetBounds(W - SScale(96) - PAD, btnY, SScale(80), SScale(26))
		elseif (!cm.completed and cm.joined and cm.type == "deliver") then
			makeBtn(card, "Entregar", 100, 100, 30, function()
				net.Start("cmission_Deliver")
					net.WriteEntity(traderEnt)
				net.SendToServer()
				frame:Remove()
			end):SetBounds(W - SScale(96) - PAD, btnY, SScale(80), SScale(26))
		elseif (!cm.completed and cm.joined) then
			local lStatus = makeLabel(card, "Participando", "ixSmallFont", Color(120, 200, 120))
			lStatus:SetBounds(W - SScale(96) - PAD, btnY + SScale(6), SScale(80), SScale(14))
			lStatus:SetContentAlignment(5)
		end
	end

	-- ── Misiones individuales ───────────────────────────────────────────────────
	if (#offers == 0 and #communityOffers == 0) then
		local l = makeLabel(scroll, "Este comerciante no tiene misiones disponibles.", "Metro UI.CharFields", Color(150, 150, 150))
		l:Dock(TOP); l:SetTall(SScale(20))
		return
	end

	for _, offer in ipairs(offers) do
		local card = scroll:Add("DPanel")
		card:Dock(TOP); card:DockMargin(0, 0, 0, GAP); card:SetTall(SScale(86))
		card.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 40, 230); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(fc.r, fc.g, fc.b, 60); surface.DrawRect(0, 0, SScale(3), h)
			surface.SetDrawColor(66, 66, 66, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local nameTxt = offer.name
		if (offer.isDaily) then nameTxt = nameTxt .. "  [Diaria]" end

		local lName = makeLabel(card, nameTxt, "Metro UI.CharFields", offer.isDaily and Color(120, 220, 120) or Color(225, 225, 225))
		lName:SetPos(SScale(8), SScale(5)); lName:SetSize(W - SScale(40), SScale(16))

		local lDesc = makeLabel(card, offer.description or "", "ixSmallFont", Color(160, 160, 160))
		lDesc:SetPos(SScale(8), SScale(22)); lDesc:SetSize(W - SScale(40), SScale(28)); lDesc:SetWrap(true)

		local options = offer.rewardOptions or {}
		local lRew
		if (#options > 1) then
			lRew = makeLabel(card, "Recompensa: elige entre " .. #options .. " opciones", "ixSmallFont", Color(199, 197, 179))
		else
			local rew = options[1] or {}
			local rewTxt = {}
			if ((rew.balas or 0) > 0) then table.insert(rewTxt, rew.balas .. " RUB") end
			if ((rew.rep or 0) > 0)   then table.insert(rewTxt, "+" .. rew.rep .. " Rep") end
			if (rew.items and #rew.items > 0) then table.insert(rewTxt, #rew.items .. " ítem(s)") end
			local rewStr = table.concat(rewTxt, "  •  ")
			lRew = makeLabel(card, "Recompensa: " .. (rewStr != "" and rewStr or "—"), "ixSmallFont", Color(199, 197, 179))
		end
		lRew:SetPos(SScale(8), SScale(52)); lRew:SetSize(W - SScale(120), SScale(14))

		local lSteps = makeLabel(card, (offer.stepCount or 0) .. " paso(s)", "ixSmallFont", Color(120, 120, 120))
		lSteps:SetPos(SScale(8), SScale(66)); lSteps:SetSize(SScale(200), SScale(14))

		makeBtn(card, "Aceptar", 30, 140, 30, function()
			net.Start("missions_Accept")
				net.WriteEntity(traderEnt)
				net.WriteString(offer.id)
			net.SendToServer()
			frame:Remove()
		end):SetBounds(W - SScale(96) - PAD, SScale(56), SScale(80), SScale(22))
	end
end)
