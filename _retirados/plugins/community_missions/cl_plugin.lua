-- ============================================================
--  community_missions  |  cl_plugin.lua  (CLIENT)
--  HUD de progreso, panel de administración y hooks del
--  diálogo del trader para misiones comunitarias.
-- ============================================================

if (not CLIENT) then return end

ix.communityMissions = ix.communityMissions or {}
ix.communityMissions._state          = nil
ix.communityMissions._joined         = false
ix.communityMissions._myContribution = 0
ix.communityMissions._claimed        = false
ix.communityMissions._adminDefs      = {}
ix.communityMissions._adminActive    = {}

-- ── Fuentes (mismos nombres que MetroUI; idempotente) ───────────────────────────
local function registerFonts()
	surface.CreateFont("Metro UI.Button", {
		font = "MBender", extended = true, size = SScale(10), weight = 500, antialias = true,
	})
	surface.CreateFont("Metro UI.CharFields", {
		font = "MBender", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
	surface.CreateFont("ixSmallFont", {
		font = "MBender", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "cmission.Fonts", registerFonts)

-- ── Helpers de estilo ────────────────────────────────────────────────────────────
local PAD = 8
local GAP = 6

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

-- ── Selector de ítem (modal con búsqueda) ───────────────────────────────────────
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

-- ============================================================
--  Receptores de red
-- ============================================================

net.Receive("cmission_State", function()
	local hasActive = net.ReadBool()
	if (hasActive) then
		ix.communityMissions._state = {
			id               = net.ReadString(),
			name             = net.ReadString(),
			description      = net.ReadString(),
			type             = net.ReadString(),
			target           = net.ReadString(),
			targetName       = net.ReadString(),
			goalCount        = net.ReadUInt(32),
			progress         = net.ReadUInt(32),
			participantCount = net.ReadUInt(16),
			completed        = net.ReadBool(),
			rewardOptions    = util.JSONToTable(net.ReadString()) or {},
		}

		local s = ix.communityMissions._state
		if (s.type == "kill") then
			s.npcClass = s.target
		end
		s.deliverItems    = util.JSONToTable(net.ReadString()) or {}
		s.deliverProgress = util.JSONToTable(net.ReadString()) or {}
	else
		ix.communityMissions._state          = nil
		ix.communityMissions._joined         = false
		ix.communityMissions._myContribution = 0
		ix.communityMissions._claimed        = false
	end
end)

net.Receive("cmission_PlayerState", function()
	ix.communityMissions._joined         = net.ReadBool()
	ix.communityMissions._myContribution = net.ReadUInt(32)
	ix.communityMissions._claimed        = net.ReadBool()
end)

-- ============================================================
--  Hooks del diálogo del trader
-- ============================================================

hook.Add("TraderDialogueOptions", "communityMissions", function(pages, traderEnt, factionKey)
	local state   = ix.communityMissions._state
	local joined  = ix.communityMissions._joined
	local claimed = ix.communityMissions._claimed

	-- Si no hay misión activa, solo mostrar opción admin
	if (!state or !state.id) then
		if (LocalPlayer():IsAdmin()) then
			table.insert(pages.root.options, #pages.root.options, {
				text   = "[ADMIN] Misiones comunitarias",
				action = "communityAdmin",
			})
		end
		return
	end

	-- Construir texto del estado de la misión para la página de diálogo
	local statusText = state.description or ""
	if (statusText != "") then statusText = statusText .. " " end

	if (state.completed) then
		statusText = statusText .. "¡La misión ha sido completada! "
	end

	-- Progreso por ítem para entregas, o global para eliminaciones
	if (state.type == "deliver" and state.deliverItems and #state.deliverItems > 0) then
		local itemParts = {}
		for _, di in ipairs(state.deliverItems) do
			local d = ix.item.list[di.id]
			local name = d and d.name or di.id
			local done = state.deliverProgress and state.deliverProgress[di.id] or 0
			table.insert(itemParts, name .. " " .. done .. "/" .. (di.count or 1))
		end
		statusText = statusText .. "Progreso: " .. table.concat(itemParts, ", ") .. ". "
	else
		local pct = math.floor(((state.progress or 0) / math.max(state.goalCount or 1, 1)) * 100)
		statusText = statusText .. "Progreso: " .. (state.progress or 0) .. "/" .. (state.goalCount or 1) .. " (" .. pct .. "%). "
	end

	statusText = statusText .. (state.participantCount or 0) .. " participantes."

	if (joined) then
		statusText = statusText .. " Tu aporte personal: " .. ix.communityMissions._myContribution .. "."
	end

	-- Recompensa
	local reward = state.rewardOptions and state.rewardOptions[1]
	if (reward) then
		local parts = {}
		if ((reward.balas or 0) > 0) then table.insert(parts, reward.balas .. " Balas") end
		if ((reward.rep or 0) > 0)   then table.insert(parts, "+" .. reward.rep .. " Rep") end
		if (reward.items and #reward.items > 0) then
			for _, entry in ipairs(reward.items) do
				local d = ix.item.list[entry.id]
				local n = d and d.name or entry.id
				table.insert(parts, (entry.qty or 1) .. "x " .. n)
			end
		end
		if (#parts > 0) then
			statusText = statusText .. " Recompensa: " .. table.concat(parts, ", ") .. "."
		end
	end

	-- Opciones de la página de misión comunitaria
	local cmOptions = {}

	if (!joined and !state.completed) then
		table.insert(cmOptions, {text = "Quiero participar en esta misión.", action = "communityJoin"})
	end

	if (joined and !state.completed and state.type == "deliver") then
		table.insert(cmOptions, {text = "Traigo suministros para la misión.", action = "communityDeliver"})
	end

	if (state.completed and joined and !claimed) then
		table.insert(cmOptions, {text = "Quiero reclamar mi recompensa.", action = "communityClaim"})
	end

	if (state.completed and joined and claimed) then
		table.insert(cmOptions, {text = "Ya he reclamado mi recompensa. Gracias.", nextPage = "root"})
	end

	table.insert(cmOptions, {text = "← Volver.", nextPage = "root"})

	pages.communityMission = {
		text    = statusText,
		options = cmOptions,
	}

	-- Opción en la página raíz
	local closeOpt = #pages.root.options
	local optText

	if (state.completed and joined and !claimed) then
		optText = "Quiero reclamar mi recompensa de la misión de la estación."
	else
		optText = "¿Cómo va la misión de la estación?"
	end

	table.insert(pages.root.options, closeOpt, {
		text     = optText,
		nextPage = "communityMission",
	})
	closeOpt = closeOpt + 1

	if (LocalPlayer():IsAdmin()) then
		table.insert(pages.root.options, closeOpt, {
			text   = "[ADMIN] Misiones de la estación",
			action = "communityAdmin",
		})
	end
end)

hook.Add("TraderDialogueAction", "communityMissions", function(action, traderEnt, closeAll)
	if (action == "communityJoin") then
		closeAll()
		net.Start("cmission_Join")
		net.SendToServer()
		return true
	elseif (action == "communityDeliver") then
		closeAll()
		net.Start("cmission_Deliver")
			net.WriteEntity(traderEnt)
		net.SendToServer()
		return true
	elseif (action == "communityClaim") then
		closeAll()
		net.Start("cmission_Claim")
		net.SendToServer()
		return true
	elseif (action == "communityAdmin") then
		closeAll()
		ix.communityMissions.OpenAdmin()
		return true
	end
end)

-- ============================================================
--  Panel de administración
-- ============================================================

local function blankDefinition()
	return {
		id          = "",
		name        = "Nueva misión comunitaria",
		description = "",
		type        = "kill",
		npcClass    = "",
		itemID      = "",
		targetName  = "",
		goalCount   = 50,
		rewardOptions = {{balas = 0, rep = 0, items = {}}},
	}
end

local function buildCMAdminEditor(panel)
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

	-- Nombre
	section("Nombre")
	local eName = makeEntry(scroll, m.name)
	eName:Dock(TOP); eName:SetTall(SScale(20))
	eName.OnChange = function(s) m.name = s:GetValue() end

	-- Descripción
	section("Descripción")
	local eDesc = makeEntry(scroll, m.description)
	eDesc:Dock(TOP); eDesc:SetTall(SScale(40)); eDesc:SetMultiline(true)
	eDesc.OnChange = function(s) m.description = s:GetValue() end

	-- Tipo
	section("Tipo de misión")
	local typeCombo = scroll:Add("DComboBox")
	typeCombo:Dock(TOP); typeCombo:SetTall(SScale(20)); typeCombo:SetFont("Metro UI.CharFields")
	typeCombo.Paint = paintDarkEntry
	for _, t in ipairs(ix.communityMissions.types) do
		typeCombo:AddChoice(t.name .. " — " .. t.desc, t.key, m.type == t.key)
	end
	typeCombo.OnSelect = function(_, _, _, data)
		m.type = data
		buildCMAdminEditor(panel)
	end

	-- Objetivo según tipo
	if (m.type == "kill") then
		section("Clase de NPC (ej: npc_zombie)")
		local eClass = makeEntry(scroll, m.npcClass or "")
		eClass:Dock(TOP); eClass:SetTall(SScale(20))
		eClass:SetPlaceholderText("Clase de entidad del NPC")
		eClass.OnChange = function(s) m.npcClass = s:GetValue() end

		section("Nombre visible del objetivo (ej: Mutantes)")
		local eTName = makeEntry(scroll, m.targetName or "")
		eTName:Dock(TOP); eTName:SetTall(SScale(20))
		eTName:SetPlaceholderText("Nombre que ve el jugador")
		eTName.OnChange = function(s) m.targetName = s:GetValue() end

		section("Cantidad objetivo (total entre todos los jugadores)")
		local eGoal = makeEntry(scroll, m.goalCount or 50)
		eGoal:Dock(TOP); eGoal:SetTall(SScale(20))
		eGoal.OnChange = function(s) m.goalCount = math.max(1, math.floor(tonumber(s:GetValue()) or 1)) end

	elseif (m.type == "deliver") then
		section("Objetos a entregar (total entre todos los jugadores)")
		m.deliverItems = m.deliverItems or {}

		for idx, entry in ipairs(m.deliverItems) do
			local itemData = ix.item.list[entry.id]
			local itemName = itemData and itemData.name or ("??? — " .. (entry.id or "vacío"))
			local idxCap   = idx

			local iRow = scroll:Add("DPanel")
			iRow:Dock(TOP); iRow:DockMargin(0, 2, 0, 0); iRow:SetTall(SScale(22))
			iRow.Paint = function(_, w, h)
				surface.SetDrawColor(40, 40, 40, 180); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(112, 128, 130, 80); surface.DrawRect(0, 0, SScale(3), h)
				surface.SetDrawColor(66, 66, 66, 60); surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(itemName, "Metro UI.CharFields",
					SScale(8), h / 2, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			local eQ = makeEntry(iRow, entry.count or 1)
			eQ:SetPos(W - SScale(78), SScale(2)); eQ:SetSize(SScale(48), SScale(18))
			eQ:SetPlaceholderText("Cant.")
			eQ.OnChange = function(s) entry.count = math.max(1, math.floor(tonumber(s:GetValue()) or 1)) end

			makeBtn(iRow, "X", 130, 30, 30, function()
				table.remove(m.deliverItems, idxCap)
				buildCMAdminEditor(panel)
			end):SetBounds(W - SScale(26), SScale(2), SScale(20), SScale(18))
		end

		local btnAddDeliver = makeBtn(scroll, "+ Añadir ítem a entregar...", 30, 80, 30, function()
			openItemPicker(function(uid)
				table.insert(m.deliverItems, {id = uid, count = 1})
				buildCMAdminEditor(panel)
			end)
		end)
		btnAddDeliver:Dock(TOP); btnAddDeliver:DockMargin(0, SScale(2), 0, 0); btnAddDeliver:SetTall(SScale(20))
	end

	-- Recompensa
	section("Recompensa (cada participante recibe esto)")
	m.rewardOptions = m.rewardOptions or {{balas = 0, rep = 0, items = {}}}
	local opt = m.rewardOptions[1] or {balas = 0, rep = 0, items = {}}
	m.rewardOptions[1] = opt

	local rewRow = scroll:Add("DPanel")
	rewRow:Dock(TOP); rewRow:SetTall(SScale(20)); rewRow.Paint = nil

	local lB = makeLabel(rewRow, "Balas", "ixSmallFont", Color(199, 197, 179))
	lB:SetPos(0, SScale(3)); lB:SetSize(SScale(40), SScale(14))
	local eBalas = makeEntry(rewRow, opt.balas or 0)
	eBalas:SetPos(SScale(42), 0); eBalas:SetSize(SScale(60), SScale(18))
	eBalas.OnChange = function(s) opt.balas = math.max(0, math.floor(tonumber(s:GetValue()) or 0)) end

	local lR = makeLabel(rewRow, "Rep", "ixSmallFont", Color(120, 200, 120))
	lR:SetPos(SScale(112), SScale(3)); lR:SetSize(SScale(30), SScale(14))
	local eRep = makeEntry(rewRow, opt.rep or 0)
	eRep:SetPos(SScale(144), 0); eRep:SetSize(SScale(60), SScale(18))
	eRep.OnChange = function(s) opt.rep = math.max(0, math.floor(tonumber(s:GetValue()) or 0)) end

	-- Ítems de recompensa
	opt.items = opt.items or {}
	for idx, entry in ipairs(opt.items) do
		local itemData = ix.item.list[entry.id]
		local itemName = itemData and itemData.name or ("??? — " .. (entry.id or "vacío"))
		local idxCap   = idx

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

		makeBtn(iRow, "X", 130, 30, 30, function()
			table.remove(opt.items, idxCap)
			buildCMAdminEditor(panel)
		end):SetBounds(W - SScale(26), SScale(2), SScale(20), SScale(18))
	end

	-- Añadir ítem de recompensa (modal con búsqueda)
	local btnAddReward = makeBtn(scroll, "+ Añadir ítem de recompensa...", 30, 80, 30, function()
		openItemPicker(function(uid)
			table.insert(opt.items, {id = uid, qty = 1})
			buildCMAdminEditor(panel)
		end)
	end)
	btnAddReward:Dock(TOP); btnAddReward:DockMargin(0, SScale(2), 0, 0); btnAddReward:SetTall(SScale(20))

	-- Guardar
	local btnSave = makeBtn(scroll, "Guardar definición", 30, 140, 30, function()
		panel.selectedId = m.id
		net.Start("cmission_AdminSave")
			net.WriteTable(m)
		net.SendToServer()
		chat.AddText(Color(80, 200, 80), "[Comunitarias] Definición guardada.")
	end)
	btnSave:Dock(TOP); btnSave:DockMargin(0, SScale(6), 0, 0); btnSave:SetTall(SScale(26))

	-- Iniciar esta misión
	local active = ix.communityMissions._adminActive
	local isActive = (istable(active) and active.id == m.id)

	if (!istable(active) or !active.id or active.id == "") then
		local btnStart = makeBtn(scroll, "INICIAR ESTA MISIÓN", 30, 100, 180, function()
			if (!m.id or m.id == "") then
				chat.AddText(Color(154, 136, 102), "[Comunitarias] Guarda la definición primero.")
				return
			end
			net.Start("cmission_AdminStart")
				net.WriteString(m.id)
			net.SendToServer()
		end)
		btnStart:Dock(TOP); btnStart:DockMargin(0, SScale(2), 0, 0); btnStart:SetTall(SScale(26))
	elseif (isActive) then
		local lActive = makeLabel(scroll, "Esta misión está activa — " .. (active.progress or 0) .. "/" .. (active.goalCount or 0), "ixSmallFont", Color(120, 220, 120))
		lActive:Dock(TOP); lActive:DockMargin(0, SScale(4), 0, 0); lActive:SetTall(SScale(14))
	end

	scroll:InvalidateLayout(true)
end

local function buildCMAdminList(panel)
	panel.listScroll:Clear()

	local sorted = {}
	for id, def in pairs(ix.communityMissions._adminDefs) do
		table.insert(sorted, {id = id, def = def})
	end
	table.sort(sorted, function(a, b) return (a.def.name or "") < (b.def.name or "") end)

	for _, entry in ipairs(sorted) do
		local id  = entry.id
		local def = entry.def
		local active = ix.communityMissions._adminActive
		local isActive = (istable(active) and active.id == id)
		local selected = (panel.selectedId == id)

		local row = panel.listScroll:Add("DButton")
		row:Dock(TOP); row:DockMargin(0, 0, 0, 2); row:SetTall(SScale(30))
		row:SetText("")
		row.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 40, selected and 240 or (s:IsHovered() and 180 or 120))
			surface.DrawRect(0, 0, w, h)
			if (selected) then surface.SetDrawColor(154, 136, 102, 220); surface.DrawRect(0, 0, SScale(3), h) end
			if (isActive) then surface.SetDrawColor(80, 180, 80, 100); surface.DrawRect(w - SScale(6), 0, SScale(6), h) end
			surface.SetDrawColor(66, 66, 66, 70); surface.DrawOutlinedRect(0, 0, w, h, 1)

			draw.SimpleText(def.name or id, "Metro UI.CharFields",
				SScale(8), SScale(4), Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local typeInfo = ix.communityMissions.GetTypeInfo(def.type)
			draw.SimpleText((typeInfo and typeInfo.name or def.type) .. " • " .. (def.goalCount or 0), "ixSmallFont",
				SScale(8), SScale(17), Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		row.DoClick = function()
			panel.selectedId = id
			panel.working    = table.Copy(def)
			buildCMAdminList(panel)
			buildCMAdminEditor(panel)
		end
	end
end

function ix.communityMissions.OpenAdmin()
	if (!LocalPlayer():IsAdmin()) then return end

	if (IsValid(ix.communityMissions._adminPanel)) then ix.communityMissions._adminPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(660), sw - SScale(40))
	local H = math.min(SScale(460), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.communityMissions._adminPanel = frame

	local title = makeLabel(frame, "Misiones Comunitarias — Admin", "Metro UI.Button", Color(225, 225, 225))
	title:SetPos(PAD, PAD); title:SetSize(W - SScale(80), SScale(20))

	makeBtn(frame, "Cerrar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	-- Estado de la misión activa
	local statusY = SScale(30)
	local statusH = SScale(24)
	local statusPnl = frame:Add("DPanel")
	statusPnl:SetPos(PAD, statusY); statusPnl:SetSize(W - PAD * 2, statusH)
	statusPnl.Paint = function(_, w, h)
		surface.SetDrawColor(35, 35, 35, 220); surface.DrawRect(0, 0, w, h)
		local active = ix.communityMissions._adminActive
		if (istable(active) and active.id and active.id != "") then
			local pct = math.Clamp((active.progress or 0) / math.max(active.goalCount or 1, 1), 0, 1)
			surface.SetDrawColor(80, 140, 80, 60)
			surface.DrawRect(0, 0, math.floor(w * pct), h)
			local statusTxt = active.completed and "COMPLETADA" or "ACTIVA"
			draw.SimpleText("● " .. statusTxt .. ": " .. (active.name or active.id) .. "  (" .. (active.progress or 0) .. "/" .. (active.goalCount or 0) .. ")", "ixSmallFont",
				SScale(6), h / 2, Color(120, 220, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("Sin misión activa", "ixSmallFont",
				SScale(6), h / 2, Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- Botón de detener
	local active = ix.communityMissions._adminActive
	if (istable(active) and active.id and active.id != "") then
		makeBtn(statusPnl, "Detener", 130, 30, 30, function()
			Derma_Query("¿Detener la misión comunitaria activa?", "Confirmar",
				"Sí", function()
					net.Start("cmission_AdminStop")
					net.SendToServer()
				end,
				"No", function() end)
		end):SetBounds(W - PAD * 2 - SScale(60), SScale(2), SScale(56), SScale(20))
	end

	-- Columnas
	local listW = SScale(180)
	local topY  = statusY + statusH + GAP

	-- Lista izquierda
	frame.listScroll = frame:Add("DScrollPanel")
	frame.listScroll:SetPos(PAD, topY)
	frame.listScroll:SetSize(listW, H - topY - SScale(34) - PAD)
	frame.listScroll:GetVBar():SetWide(SScale(3))

	makeBtn(frame, "+ Nueva", 30, 100, 30, function()
		frame.selectedId = nil
		frame.working    = blankDefinition()
		buildCMAdminList(frame)
		buildCMAdminEditor(frame)
	end):SetBounds(PAD, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	makeBtn(frame, "Eliminar", 130, 30, 30, function()
		if (!frame.selectedId) then return end
		Derma_Query("¿Eliminar esta definición?", "Confirmar",
			"Sí", function()
				net.Start("cmission_AdminDelete")
					net.WriteString(frame.selectedId)
				net.SendToServer()
				frame.selectedId = nil; frame.working = nil
				frame.editScroll:Clear()
			end,
			"No", function() end)
	end):SetBounds(PAD + listW / 2 + 2, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	-- Editor derecho
	local editX = PAD + listW + GAP
	frame.editScroll = frame:Add("DScrollPanel")
	frame.editScroll:SetPos(editX, topY)
	frame.editScroll:SetSize(W - editX - PAD, H - topY - PAD)
	frame.editScroll:GetVBar():SetWide(SScale(3))

	buildCMAdminList(frame)

	-- Pedir datos al servidor
	net.Start("cmission_AdminRequest")
	net.SendToServer()
end

net.Receive("cmission_OpenAdmin", function()
	ix.communityMissions.OpenAdmin()
end)

net.Receive("cmission_AdminData", function()
	ix.communityMissions._adminDefs   = net.ReadTable()
	ix.communityMissions._adminActive = net.ReadTable()

	local panel = ix.communityMissions._adminPanel
	if (!IsValid(panel)) then return end

	buildCMAdminList(panel)

	if (panel.selectedId and ix.communityMissions._adminDefs[panel.selectedId]) then
		panel.working = table.Copy(ix.communityMissions._adminDefs[panel.selectedId])
		buildCMAdminEditor(panel)
	end
end)
