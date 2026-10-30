-- ============================================================
--  loot  |  cl_plugin.lua  (CLIENT)
--  HUD de notificaciones de loot, visualización de puntos y
--  panel de administración con tiers dinámicos. Estética MetroUI.
-- ============================================================

if (not CLIENT) then return end

-- ── Polyfill SetBounds ────────────────────────────────────────
local _PNL = FindMetaTable("Panel")
if (_PNL and not _PNL.SetBounds) then
	_PNL.SetBounds = function(self, x, y, w, h)
		self:SetPos(x, y); self:SetSize(w, h); return self
	end
end

-- ── Fuentes ───────────────────────────────────────────────────
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
	surface.CreateFont("ixLootNotif", {
		font      = "MBender",
		size      = ScreenScale(8),
		weight    = 500,
		antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "ixLoot.Fonts", registerFonts)

-- ── Helpers de estilo ─────────────────────────────────────────
local PAD = 8
local GAP = 6

local function paintFrame(self, w, h)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(28, 28, 28, 240)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(145, 148, 108, 200)
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

-- ============================================================
--  SECCIÓN 1 — HUD DE NOTIFICACIONES DE LOOT
-- ============================================================

local pickupNotifs = {}

net.Receive("ixLootPickup", function()
	local msgType = net.ReadUInt(3)
	local text

	if (msgType == 1) then
		local name = net.ReadString()
		local qty = net.ReadUInt(8)
		if (qty < 1) then qty = 1 end
		text = "+" .. qty .. "  " .. name
	elseif (msgType == 2) then
		text = "No has encontrado nada"
	elseif (msgType == 3) then
		text = "No has encontrado nada"
	elseif (msgType == 4) then
		text = "No es seguro ponerme a buscar, será mejor limpiar la zona"
	end

	if (text) then
		pickupNotifs[#pickupNotifs + 1] = {
			text      = text,
			startTime = CurTime(),
			duration  = 2.5,
		}
	end
end)

function PLUGIN:HUDPaint()
	if (#pickupNotifs == 0) then return end

	local now      = CurTime()
	local lineH    = ScreenScale(8) + 6
	local toRemove = {}

	for i, notif in ipairs(pickupNotifs) do
		local elapsed = now - notif.startTime

		if (elapsed >= notif.duration) then
			toRemove[#toRemove + 1] = i
		else
			local alpha     = 255
			local fadeStart = notif.duration - 0.6

			if (elapsed > fadeStart) then
				alpha = math.floor(255 * (1 - (elapsed - fadeStart) / 0.6))
			end

			local yPos = ScrH() - 330 - (i - 1) * lineH

			surface.SetFont("ixLootNotif")
			ix.util.DrawText(notif.text, ScrW() / 2, yPos, Color(145, 148, 108, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	for i = #toRemove, 1, -1 do
		table.remove(pickupNotifs, toRemove[i])
	end
end

-- ============================================================
--  SECCIÓN 1b — BÚSQUEDA CON PROGRESS BAR (bloqueo de movimiento)
-- ============================================================

local _searchEnt    = nil
local _searchMaxDist = 120

net.Receive("ixLootSearchStart", function()
	_searchEnt = net.ReadEntity()
end)

hook.Add("CreateMove", "ixLoot.SearchLock", function(cmd)
	if (!IsValid(_searchEnt)) then
		_searchEnt = nil
		return
	end
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetUpMove(0)

	-- NearestPoint (punto más cercano del bounding box), no GetPos() (el
	-- pivote/origen del modelo): en props pequeños el origen siempre está
	-- cerca de donde te paras a interactuar, pero en modelos grandes (coches,
	-- 150-250+ unidades) el origen puede quedar a más de 120 unidades del
	-- jugador aunque esté tocando el modelo, cancelando la búsqueda casi al
	-- instante de empezarla.
	local closest = _searchEnt:NearestPoint(LocalPlayer():GetPos())
	if (LocalPlayer():GetPos():Distance(closest) > _searchMaxDist) then
		net.Start("ixLootSearchCancel")
		net.SendToServer()
		_searchEnt = nil
	end
end)

net.Receive("ixLootSearchCancel", function()
	_searchEnt = nil
end)

local _lootSearchSnd = nil

net.Receive("ixLootSearchSnd", function()
	if (net.ReadBool()) then
		if (_lootSearchSnd) then _lootSearchSnd:Stop() end
		_lootSearchSnd = CreateSound(LocalPlayer(), "metrorp/search_body.wav")
		_lootSearchSnd:PlayEx(1, 100)
	elseif (_lootSearchSnd) then
		_lootSearchSnd:Stop()
		_lootSearchSnd = nil
	end
end)

-- ============================================================
--  SECCIÓN 2 — VISUALIZACIÓN DE PUNTOS EN EL MUNDO
-- ============================================================

local _showPoints  = false
local _pointsData  = {}
local _areasData   = {}
local _cachedTiers = {}

-- Recibir tiers al conectar o cuando el admin los actualiza
net.Receive("ixLootTierSync", function()
	local tiers = ix.loot.ReadCompressed()
	if (tiers and next(tiers)) then
		_cachedTiers = tiers
		ix.loot.clientTierCache = tiers
	end
end)

net.Receive("ixLootPointsData", function()
	local payload = ix.loot.ReadCompressed()

	if (payload.tierDefs and next(payload.tierDefs)) then
		_cachedTiers = payload.tierDefs
		ix.loot.clientTierCache = payload.tierDefs
	end

	if (payload.toggle) then
		_showPoints = not _showPoints
		if (_showPoints) then
			_pointsData = payload.points or {}
			_areasData  = payload.areas  or {}
			LocalPlayer():Notify("[Loot] Mostrando " .. #_pointsData .. " punto(s) de spawn.")
		else
			_pointsData = {}
			_areasData  = {}
			LocalPlayer():Notify("[Loot] Puntos ocultos.")
		end
	else
		if (_showPoints) then
			_pointsData = payload.points or {}
			_areasData  = payload.areas  or {}
		end
	end
end)

local _SPHERE_MAT = CreateMaterial("ixloot_sphere_mat", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$model"]       = 1,
	["$translucent"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$nocull"]      = 1,
})

local TIER_COL_DEFAULT = Color(160, 160, 160, 255)

local function resolveTierDef(tierID)
	if (_cachedTiers and _cachedTiers[tierID]) then
		return _cachedTiers[tierID]
	end
	return ix.loot.defaultTiers and ix.loot.defaultTiers[tierID]
end

local function getTierColorSingle(tierID)
	local def = resolveTierDef(tierID)
	if (def and def.color) then
		return Color(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160, 255)
	end
	return TIER_COL_DEFAULT
end

local function getTierColor(tiers)
	if (!tiers or #tiers == 0) then return TIER_COL_DEFAULT end
	return getTierColorSingle(tiers[#tiers])
end

local function buildTierLabel(tiers)
	if (!tiers or #tiers == 0) then return "" end
	local parts = {}
	for _, t in ipairs(tiers) do
		local def = resolveTierDef(t)
		parts[#parts + 1] = def and def.name or t
	end
	return table.concat(parts, " + ")
end

hook.Add("PostDrawTranslucentRenderables", "ixLoot.DrawPoints", function(_, bSkybox)
	if (bSkybox) then return end
	if (!_showPoints) then return end
	if (!IsValid(LocalPlayer())) then return end

	local clientPos = LocalPlayer():GetPos()
	local VIEW_RANGE_SQ = 4000 * 4000

	local areaIndex = {}
	for _, ad in ipairs(_areasData) do
		areaIndex[ad.name] = ad
	end

	if (ix.area and ix.area.stored) then
		for areaName, info in pairs(ix.area.stored) do
			if (info.type != "loot_zone") then continue end
			local ad    = areaIndex[areaName]
			local tiers = ad and ad.tiers or {}
			local col   = getTierColor(tiers)

			local s      = info.startPosition
			local e      = info.endPosition
			local center = LerpVector(0.5, s, e)
			local mn     = WorldToLocal(s, angle_zero, center, angle_zero)
			local mx     = WorldToLocal(e, angle_zero, center, angle_zero)
			render.DrawWireframeBox(center, angle_zero, mn, mx, col)

			cam.Start2D()
				local screen = center:ToScreen()
				if (screen.visible) then
					-- Nombre del area en blanco
					draw.SimpleText(areaName, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(areaName, "BudgetLabel", screen.x,     screen.y,     Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					-- Cada tier con su color propio
					local yOff = 13
					for _, tierID in ipairs(tiers) do
						local tierCol  = getTierColorSingle(tierID)
						local tierDef  = resolveTierDef(tierID)
						local tierName = tierDef and tierDef.name or tierID
						draw.SimpleText(tierName, "BudgetLabel", screen.x + 1, screen.y + yOff + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.SimpleText(tierName, "BudgetLabel", screen.x,     screen.y + yOff,     tierCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						yOff = yOff + 12
					end
				end
			cam.End2D()
		end
	end

	render.SetMaterial(_SPHERE_MAT)

	for _, pt in ipairs(_pointsData) do
		local pos = Vector(pt.pos.x or 0, pt.pos.y or 0, pt.pos.z or 0)
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
		local ad  = areaIndex[pt.areaName or ""]
		local col = getTierColor(ad and ad.tiers or {})
		render.DrawSphere(pos + Vector(0, 0, 8), 8, 8, 8, ColorAlpha(col, 200))
	end

	cam.Start2D()
		for _, pt in ipairs(_pointsData) do
			local pos    = Vector(pt.pos.x or 0, pt.pos.y or 0, pt.pos.z or 0)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local screen = (pos + Vector(0, 0, 30)):ToScreen()
			if (!screen.visible) then continue end
			local ad    = areaIndex[pt.areaName or ""]
			local tiers = ad and ad.tiers or {}
			-- Nombre del area
			draw.SimpleText(pt.areaName or "?", "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(pt.areaName or "?", "BudgetLabel", screen.x,     screen.y,     Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			-- Tier names con color
			local yOff = 13
			for _, tierID in ipairs(tiers) do
				local tierCol  = getTierColorSingle(tierID)
				local tierDef  = resolveTierDef(tierID)
				local tierName = tierDef and tierDef.name or tierID
				draw.SimpleText(tierName, "BudgetLabel", screen.x + 1, screen.y + yOff + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(tierName, "BudgetLabel", screen.x,     screen.y + yOff,     tierCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				yOff = yOff + 12
			end
		end
	cam.End2D()
end)

-- ============================================================
--  SECCIÓN 3 — PANEL DE ADMINISTRACIÓN
-- ============================================================

-- ── Helpers para nombres de tablas y sorted tier IDs ─────────

local function getTableDisplayName(tableKey, workData)
	if (workData and workData.tableNames and workData.tableNames[tableKey]) then
		return workData.tableNames[tableKey]
	end
	return ix.loot.defaultTableNames and ix.loot.defaultTableNames[tableKey] or tableKey
end

local function getSortedTierIDsFromData(customTiers)
	local sorted = {}
	for id, def in pairs(customTiers) do
		sorted[#sorted + 1] = {id = id, order = def.order or 99}
	end
	table.sort(sorted, function(a, b)
		if (a.order == b.order) then return a.id < b.id end
		return a.order < b.order
	end)
	local result = {}
	for _, entry in ipairs(sorted) do
		result[#result + 1] = entry.id
	end
	return result
end

local function openAdminPanel(data, itemList)
	if (IsValid(ix.loot._adminPanel)) then ix.loot._adminPanel:Remove() end

	local sw, sh  = ScrW(), ScrH()
	local W       = math.min(SScale(760), sw - SScale(20))
	local H       = math.min(SScale(520), sh - SScale(40))
	local topY    = SScale(34)
	local btnH    = SScale(30)
	local bodyH   = H - topY - btnH - PAD * 2
	local inner   = W - PAD * 2 - GAP * 2
	local rColW   = math.floor(inner * 0.30)
	local colW    = math.floor((inner - rColW) / 2)

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.loot._adminPanel = frame

	local workData = {
		spawnPoints   = table.Copy(data.spawnPoints   or {}),
		presets       = table.Copy(data.presets       or {}),
		areaPresets   = table.Copy(data.areaPresets   or {}),
		areaTiers     = table.Copy(data.areaTiers     or {}),
		spawnCounts   = table.Copy(data.spawnCounts   or {}),
		respawnTimes  = table.Copy(data.respawnTimes  or {}),
		maxLootQty    = table.Copy(data.maxLootQty    or {}),
		lootTables    = table.Copy(data.lootTables    or {}),
		tableNames    = table.Copy(data.tableNames    or {}),
		customTiers   = table.Copy(data.customTiers and next(data.customTiers) and data.customTiers or ix.loot.defaultTiers),
	}

	makeLabel(frame, "Administracion del Sistema de Loot", "Metro UI.Button", Color(225, 225, 225))
		:SetBounds(PAD, PAD, W - SScale(80), SScale(20))

	makeBtn(frame, "Cerrar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	-- ══════════════════════════════════════════════════════════
	--  FORWARD DECLARATIONS
	-- ══════════════════════════════════════════════════════════

	local selectedArea       = nil
	local selectedPreset     = nil
	local selectedTier       = nil
	local buildAreaList, updateAreaDetail, refreshPresetCombo
	local buildPresetList, buildModelList
	local buildTierList, buildTierDetail
	local buildAreaTierList

	-- ══════════════════════════════════════════════════════════
	--  COLUMNA IZQUIERDA — ÁREAS
	-- ══════════════════════════════════════════════════════════

	local colAreaX = PAD
	local areaListH = math.floor(bodyH * 0.35)
	local detailH   = bodyH - areaListH - GAP

	makeLabel(frame, "Areas de Loot", "Metro UI.CharFields", Color(175, 177, 148))
		:SetBounds(colAreaX, topY, colW, SScale(16))

	local areaScroll = frame:Add("DScrollPanel")
	areaScroll:SetBounds(colAreaX, topY + SScale(18), colW, areaListH)
	areaScroll:GetVBar():SetWide(SScale(3))

	local detailY      = topY + SScale(18) + areaListH + GAP
	local areaDetailScroll = frame:Add("DScrollPanel")
	areaDetailScroll:SetBounds(colAreaX, detailY, colW, detailH)
	areaDetailScroll:GetVBar():SetWide(SScale(3))
	areaDetailScroll.Paint = function(_, w, h)
		surface.SetDrawColor(28, 28, 28, 220); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(145, 148, 108, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local selectedArea   = nil
	local areaTierPanel  = nil

	local function applyAreaChanges()
		if (!selectedArea) then return end
	end

	local function rebuildAreaDetail()
		areaDetailScroll:Clear()
		if (!selectedArea) then
			local lblNone = makeLabel(areaDetailScroll, "Selecciona un area", "Metro UI.CharFields", Color(160, 160, 160))
			lblNone:Dock(TOP); lblNone:DockMargin(PAD, PAD, PAD, 0)
			return
		end

		local aName = selectedArea
		local ptCount = workData.spawnPoints[aName] and #workData.spawnPoints[aName] or 0

		-- Header
		local lblSel = makeLabel(areaDetailScroll, aName .. "  (" .. ptCount .. " pts)", "Metro UI.CharFields", Color(220, 180, 80))
		lblSel:Dock(TOP); lblSel:DockMargin(PAD, PAD, PAD, 4)

		-- Preset combo
		local presetRow = areaDetailScroll:Add("DPanel")
		presetRow:Dock(TOP); presetRow:DockMargin(PAD, 0, PAD, 4); presetRow:SetTall(SScale(20))
		presetRow.Paint = function() end

		local lblPreset = makeLabel(presetRow, "Preset:", "Metro UI.CharFields", Color(160, 160, 160))
		lblPreset:Dock(LEFT); lblPreset:SetWide(SScale(44))

		local areaPresetCombo = presetRow:Add("DComboBox")
		areaPresetCombo:Dock(FILL)
		areaPresetCombo:SetFont("Metro UI.CharFields")
		local ap = workData.areaPresets[aName] or ""
		areaPresetCombo:SetValue(ap != "" and ap or "-- ninguno --")
		areaPresetCombo.Paint = function(s, w, h)
			surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(88, 88, 88, 160); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(s:GetValue(), "Metro UI.CharFields", PAD, h / 2, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		areaPresetCombo:Clear()
		areaPresetCombo:AddChoice("-- ninguno --")
		for pName, _ in pairs(workData.presets) do
			areaPresetCombo:AddChoice(pName)
		end
		areaPresetCombo:SetValue(ap != "" and ap or "-- ninguno --")
		areaPresetCombo.OnSelect = function(_, _, val)
			workData.areaPresets[aName] = (val != "-- ninguno --" and val != "") and val or nil
		end

		-- Spawn count + Respawn time row
		local numsRow = areaDetailScroll:Add("DPanel")
		numsRow:Dock(TOP); numsRow:DockMargin(PAD, 0, PAD, 4); numsRow:SetTall(SScale(20))
		numsRow.Paint = function() end

		local lblSp = makeLabel(numsRow, "Spawns:", "Metro UI.CharFields", Color(160, 160, 160))
		lblSp:Dock(LEFT); lblSp:SetWide(SScale(48))
		local spawnCountEntry = numsRow:Add("DTextEntry")
		spawnCountEntry:SetFont("Metro UI.CharFields")
		spawnCountEntry:SetText(tostring(workData.spawnCounts and workData.spawnCounts[aName] or 1))
		spawnCountEntry:Dock(LEFT); spawnCountEntry:SetWide(SScale(32)); spawnCountEntry:DockMargin(0, 1, GAP, 1)
		spawnCountEntry.Paint = paintDarkEntry
		local function saveSpawn(s)
			local sc = math.max(1, math.floor(tonumber(s:GetValue()) or 1))
			s:SetText(tostring(sc))
			workData.spawnCounts[aName] = sc
		end
		spawnCountEntry.OnEnter = saveSpawn
		spawnCountEntry.OnLoseFocus = saveSpawn

		local lblRt = makeLabel(numsRow, "Respawn:", "Metro UI.CharFields", Color(160, 160, 160))
		lblRt:Dock(LEFT); lblRt:SetWide(SScale(54))
		local respawnTimeEntry = numsRow:Add("DTextEntry")
		respawnTimeEntry:SetFont("Metro UI.CharFields")
		respawnTimeEntry:SetText(tostring(workData.respawnTimes and workData.respawnTimes[aName] or 600))
		respawnTimeEntry:Dock(LEFT); respawnTimeEntry:SetWide(SScale(36)); respawnTimeEntry:DockMargin(0, 1, 0, 1)
		respawnTimeEntry.Paint = paintDarkEntry
		local function saveRespawn(s)
			local rt = math.max(1, math.floor(tonumber(s:GetValue()) or 600))
			s:SetText(tostring(rt))
			workData.respawnTimes[aName] = rt
		end
		respawnTimeEntry.OnEnter = saveRespawn
		respawnTimeEntry.OnLoseFocus = saveRespawn

		-- Max loot quantity row
		local qtyRow = areaDetailScroll:Add("DPanel")
		qtyRow:Dock(TOP); qtyRow:DockMargin(PAD, 0, PAD, 4); qtyRow:SetTall(SScale(20))
		qtyRow.Paint = function() end

		local lblMq = makeLabel(qtyRow, "Max loot:", "Metro UI.CharFields", Color(160, 160, 160))
		lblMq:Dock(LEFT); lblMq:SetWide(SScale(54))
		local maxQtyEntry = qtyRow:Add("DTextEntry")
		maxQtyEntry:SetFont("Metro UI.CharFields")
		maxQtyEntry:SetText(tostring(workData.maxLootQty and workData.maxLootQty[aName] or 0))
		maxQtyEntry:Dock(LEFT); maxQtyEntry:SetWide(SScale(32)); maxQtyEntry:DockMargin(0, 1, GAP, 1)
		maxQtyEntry.Paint = paintDarkEntry

		local lblMqH = makeLabel(qtyRow, "(0 = sin limite)", "ixSmallFont", Color(120, 120, 120))
		lblMqH:Dock(LEFT); lblMqH:SetWide(SScale(80))

		local function saveMaxQty(s)
			local mq = math.max(0, math.floor(tonumber(s:GetValue()) or 0))
			s:SetText(tostring(mq))
			workData.maxLootQty[aName] = mq
		end
		maxQtyEntry.OnEnter = saveMaxQty
		maxQtyEntry.OnLoseFocus = saveMaxQty

		-- Separator
		local sep = areaDetailScroll:Add("DPanel")
		sep:Dock(TOP); sep:SetTall(1); sep:DockMargin(PAD, 2, PAD, 4)
		sep.Paint = function(_, w, h)
			surface.SetDrawColor(145, 148, 108, 100); surface.DrawRect(0, 0, w, h)
		end

		-- Tiers header + total
		local tiersHeader = areaDetailScroll:Add("DPanel")
		tiersHeader:Dock(TOP); tiersHeader:DockMargin(PAD, 0, PAD, 2); tiersHeader:SetTall(SScale(14))
		tiersHeader.Paint = function() end

		local lblTiers = makeLabel(tiersHeader, "Tiers:", "ixSmallFont", Color(160, 200, 160))
		lblTiers:Dock(LEFT); lblTiers:SetWide(SScale(34))

		local lblAreaTotal = tiersHeader:Add("DLabel")
		lblAreaTotal:SetFont("ixSmallFont")
		lblAreaTotal:Dock(FILL); lblAreaTotal:DockMargin(2, 0, 0, 0)

		local function updateAreaTiersTotal()
			local t = 0
			local at = workData.areaTiers[aName]
			if (at and istable(at)) then
				for _, e in ipairs(at) do
					t = t + (tonumber(e.weight) or 0)
				end
			end
			lblAreaTotal:SetText("Total: " .. t .. "/100")
			lblAreaTotal:SetTextColor(t > 100 and Color(255, 60, 60) or (t == 100 and Color(60, 200, 60) or Color(175, 177, 148)))
		end
		updateAreaTiersTotal()

		-- Tier checkboxes with weights
		local sortedIDs = getSortedTierIDsFromData(workData.customTiers)

		-- Build lookup of currently assigned tiers
		local currentTiers = workData.areaTiers[aName]
		local assignedLookup = {}
		if (currentTiers and istable(currentTiers)) then
			for _, entry in ipairs(currentTiers) do
				if (istable(entry) and entry.id) then
					assignedLookup[entry.id] = entry.weight or 100
				end
			end
		end

		for _, tierID in ipairs(sortedIDs) do
			local def = workData.customTiers[tierID]
			if (!def) then continue end

			local capturedID = tierID
			local isChecked  = assignedLookup[tierID] != nil
			local curWeight  = assignedLookup[tierID] or 100

			local row = areaDetailScroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(PAD, 1, PAD, 1); row:SetTall(SScale(20))
			row.Paint = function(_, w, h)
				surface.SetDrawColor(38, 38, 38, 180); surface.DrawRect(0, 0, w, h)
			end

			local cb = row:Add("DButton")
			cb:SetText("")
			cb:Dock(LEFT); cb:SetWide(SScale(14)); cb:DockMargin(2, 2, 4, 2)
			cb.Paint = function(s, w, h)
				surface.SetDrawColor(44, 44, 44, 200); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160, s:IsHovered() and 180 or 80)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				if (isChecked) then
					surface.SetDrawColor(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160, 200)
					surface.DrawRect(2, 2, w - 4, h - 4)
				end
			end

			local lbl = row:Add("DLabel")
			lbl:SetFont("ixSmallFont")
			lbl:SetTextColor(Color(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160))
			lbl:SetText(def.name or capturedID)
			lbl:Dock(FILL); lbl:DockMargin(2, 0, 0, 0)

			local weightEntry = row:Add("DTextEntry")
			weightEntry:SetFont("ixSmallFont")
			weightEntry:SetText(tostring(curWeight))
			weightEntry:Dock(RIGHT); weightEntry:SetWide(SScale(32)); weightEntry:DockMargin(2, 2, 2, 2)
			weightEntry.Paint = paintDarkEntry
			weightEntry:SetEnabled(isChecked)

			local function syncAreaTiers()
				if (!workData.areaTiers[aName]) then workData.areaTiers[aName] = {} end
				local tiers = workData.areaTiers[aName]
				-- Remove old entry
				for i = #tiers, 1, -1 do
					if (istable(tiers[i]) and tiers[i].id == capturedID) then
						table.remove(tiers, i)
					end
				end
				-- Add if checked
				if (isChecked) then
					tiers[#tiers + 1] = {id = capturedID, weight = math.max(1, math.floor(tonumber(weightEntry:GetValue()) or 100))}
				end
				-- If empty, remove key
				if (#tiers == 0) then
					workData.areaTiers[aName] = nil
				end
			end

			cb.DoClick = function()
				isChecked = not isChecked
				weightEntry:SetEnabled(isChecked)
				syncAreaTiers()
				updateAreaTiersTotal()
			end

			local function saveAreaTierWeight(s)
				local val = math.max(1, math.floor(tonumber(s:GetValue()) or 100))
				s:SetText(tostring(val))
				syncAreaTiers()
				updateAreaTiersTotal()
			end
			weightEntry.OnEnter = saveAreaTierWeight
			weightEntry.OnLoseFocus = saveAreaTierWeight
		end
	end

	updateAreaDetail = function(aName)
		selectedArea = aName
		rebuildAreaDetail()
	end

	refreshPresetCombo = function()
	end

	buildAreaList = function()
		areaScroll:Clear()

		if (!ix.area or !ix.area.stored) then
			makeLabel(areaScroll, "No hay zonas loot_zone.", "Metro UI.CharFields", Color(140, 140, 140)):Dock(TOP)
			return
		end

		local sorted = {}
		for name, area in pairs(ix.area.stored) do
			if (area.type == "loot_zone") then sorted[#sorted + 1] = name end
		end
		table.sort(sorted)

		if (#sorted == 0) then
			makeLabel(areaScroll, "No hay zonas loot_zone.", "Metro UI.CharFields", Color(140, 140, 140)):Dock(TOP)
			return
		end

		for _, aName in ipairs(sorted) do
			local captured = aName
			local row = areaScroll:Add("DButton")
			row:SetText("")
			row:Dock(TOP); row:DockMargin(0, 0, 0, 2); row:SetTall(SScale(28))
			row.Paint = function(s, w, h)
				local sel = selectedArea == captured
				surface.SetDrawColor(sel and 80 or 38, sel and 50 or 38, sel and 20 or 38, 200)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(145, 148, 108, sel and 180 or 50)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				local ptCount = workData.spawnPoints[captured] and #workData.spawnPoints[captured] or 0
				draw.SimpleText(captured, "Metro UI.CharFields", PAD, h / 2, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(ptCount .. " pts", "ixSmallFont", w - PAD, h / 2, Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			row.DoClick = function()
				updateAreaDetail(captured)
				buildAreaList()
			end
		end
	end

	buildAreaList()
	refreshPresetCombo()

	-- ══════════════════════════════════════════════════════════
	--  COLUMNA CENTRAL — PRESETS
	-- ══════════════════════════════════════════════════════════

	local colPresetX = colAreaX + colW + GAP
	makeLabel(frame, "Presets de Props", "Metro UI.CharFields", Color(175, 177, 148))
		:SetBounds(colPresetX, topY, colW, SScale(16))

	local presetScroll = frame:Add("DScrollPanel")
	presetScroll:SetBounds(colPresetX, topY + SScale(18), colW, bodyH)
	presetScroll:GetVBar():SetWide(SScale(3))

	local presetModelPanel   = nil

	buildModelList = function()
		if (!IsValid(presetModelPanel)) then return end
		presetModelPanel:Clear()
		presetModelPanel:SetTall(0)
		if (!selectedPreset or !workData.presets[selectedPreset]) then return end

		local models = workData.presets[selectedPreset].models or {}
		for i, mdl in ipairs(models) do
			local row = presetModelPanel:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 1, 0, 1); row:SetTall(SScale(22))
			row.Paint = function(_, w, h)
				surface.SetDrawColor(44, 44, 44, 200); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(66, 66, 66, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			local capturedI   = i
			local capturedMdl = mdl

			local btnDel = row:Add("DButton")
			btnDel:SetText("x")
			btnDel:SetFont("Metro UI.CharFields")
			btnDel:SetTextColor(Color(200, 80, 80))
			btnDel:Dock(RIGHT); btnDel:SetWide(SScale(20)); btnDel:DockMargin(2, 1, 1, 1)
			btnDel.Paint = function(bs, w, h)
				surface.SetDrawColor(130, 30, 30, bs:IsHovered() and 40 or 12); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(160, 50, 50, bs:IsHovered() and 100 or 40); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			btnDel.DoClick = function()
				table.remove(workData.presets[selectedPreset].models, capturedI)
				buildModelList()
			end

			local lbl = row:Add("DLabel")
			lbl:SetFont("ixSmallFont")
			lbl:SetTextColor(Color(180, 180, 180))
			lbl:SetText(capturedI .. ". " .. capturedMdl)
			lbl:Dock(FILL); lbl:DockMargin(PAD, 0, 0, 0)
		end

		presetModelPanel:SetTall(math.max(1, #models * SScale(24)))
		presetModelPanel:InvalidateLayout(true)
	end

	buildPresetList = function()
		presetScroll:Clear()

		local sorted = {}
		for pName, _ in pairs(workData.presets) do
			sorted[#sorted + 1] = pName
		end
		table.sort(sorted)

		for _, pName in ipairs(sorted) do
			local captured   = pName
			local modelCount = workData.presets[pName] and #(workData.presets[pName].models or {}) or 0
			local row        = presetScroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 0, 0, 2); row:SetTall(SScale(28))
			row.Paint = function(s, w, h)
				local sel = selectedPreset == captured
				surface.SetDrawColor(sel and 60 or 38, sel and 60 or 38, sel and 80 or 38, 200)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(80, 80, 143, sel and 180 or 50)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			-- Botón eliminar
			local btnDel = row:Add("DButton")
			btnDel:SetText("x")
			btnDel:SetFont("Metro UI.CharFields")
			btnDel:SetTextColor(Color(220, 80, 80))
			btnDel:Dock(RIGHT); btnDel:SetWide(SScale(20)); btnDel:DockMargin(1, 2, 2, 2)
			btnDel.Paint = function(s, w, h)
				surface.SetDrawColor(130, 30, 30, s:IsHovered() and 50 or 14)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(160, 50, 50, s:IsHovered() and 120 or 40)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			btnDel.DoClick = function()
				workData.presets[captured] = nil
				for area, pn in pairs(workData.areaPresets) do
					if (pn == captured) then workData.areaPresets[area] = nil end
				end
				if (selectedPreset == captured) then selectedPreset = nil end
				buildPresetList()
				refreshPresetCombo()
			end

			-- Botón renombrar
			local btnRen = row:Add("DButton")
			btnRen:SetText("~")
			btnRen:SetFont("Metro UI.CharFields")
			btnRen:SetTextColor(Color(200, 200, 80))
			btnRen:Dock(RIGHT); btnRen:SetWide(SScale(20)); btnRen:DockMargin(1, 2, 1, 2)
			btnRen.Paint = function(s, w, h)
				surface.SetDrawColor(100, 100, 30, s:IsHovered() and 50 or 14)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(140, 140, 40, s:IsHovered() and 120 or 40)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			btnRen.DoClick = function()
				local pw, ph = SScale(300), SScale(90)
				local pop = vgui.Create("DFrame")
				pop:SetSize(pw, ph); pop:Center()
				pop:SetTitle(""); pop:SetDraggable(true)
				pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
				pop.Paint = function(s, w, h) paintFrame(s, w, h) end
				makeLabel(pop, "Nuevo nombre:", "Metro UI.CharFields", Color(200, 200, 200))
					:SetBounds(PAD, SScale(10), pw - PAD * 2, SScale(14))
				local eNombre = makeEntry(pop, captured)
				eNombre:SetBounds(PAD, SScale(26), pw - PAD * 2, SScale(20))
				makeBtn(pop, "Renombrar", 30, 100, 30, function()
					local newName = eNombre:GetValue():Trim()
					if (newName != "" and newName != captured and !workData.presets[newName]) then
						workData.presets[newName] = workData.presets[captured]
						workData.presets[captured] = nil
						for area, pn in pairs(workData.areaPresets) do
							if (pn == captured) then workData.areaPresets[area] = newName end
						end
						if (selectedPreset == captured) then selectedPreset = newName end
						buildPresetList()
						refreshPresetCombo()
					end
					pop:Remove()
				end):SetBounds(PAD, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
				makeBtn(pop, "Cancelar", 130, 30, 30, function() pop:Remove() end)
					:SetBounds(PAD * 2 + (pw - PAD * 3) / 2, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
			end

			-- Área clicable central
			local btnSel = row:Add("DButton")
			btnSel:SetText("")
			btnSel:Dock(FILL); btnSel:DockMargin(0, 0, 0, 0)
			btnSel.Paint = function(s, w, h)
				draw.SimpleText(captured, "Metro UI.CharFields", PAD, h / 2, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(modelCount .. " mdl", "ixSmallFont", w - PAD, h / 2, Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			btnSel.DoClick = function()
				selectedPreset = captured
				buildPresetList()
				buildModelList()
				rebuildAreaDetail()
				refreshPresetCombo()
			end
		end

		-- Separador y panel de modelos del preset seleccionado
		local sep = presetScroll:Add("DPanel")
		sep:Dock(TOP); sep:SetTall(SScale(1)); sep:DockMargin(0, 4, 0, 4)
		sep.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 180); surface.DrawRect(0, 0, w, h) end

		if (selectedPreset) then
			makeLabel(presetScroll, "Modelos de: " .. selectedPreset, "ixSmallFont", Color(160, 160, 200))
				:Dock(TOP)

			presetModelPanel = presetScroll:Add("DPanel")
			presetModelPanel:Dock(TOP)
			presetModelPanel:SetTall(0)
			presetModelPanel.Paint = function() end

			buildModelList()

			-- Botón añadir modelo
			local btnAddModel = makeBtn(presetScroll, "+ Anadir modelo", 30, 80, 130, function()
				local pw, ph = SScale(340), SScale(100)
				local pop    = vgui.Create("DFrame")
				pop:SetSize(pw, ph); pop:Center()
				pop:SetTitle(""); pop:SetDraggable(true)
				pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
				pop.Paint = function(s, w, h) paintFrame(s, w, h) end
				makeLabel(pop, "Ruta del modelo (.mdl):", "Metro UI.CharFields", Color(200, 200, 200))
					:SetBounds(PAD, SScale(10), pw - PAD * 2, SScale(14))
				local eModel = makeEntry(pop, "models/")
				eModel:SetBounds(PAD, SScale(26), pw - PAD * 2, SScale(20))
				makeBtn(pop, "Confirmar", 30, 100, 30, function()
					local mdl = eModel:GetValue():Trim()
					if (mdl != "" and workData.presets[selectedPreset]) then
						table.insert(workData.presets[selectedPreset].models, mdl)
						buildModelList()
					end
					pop:Remove()
				end):SetBounds(PAD, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
				makeBtn(pop, "Cancelar", 130, 30, 30, function() pop:Remove() end)
					:SetBounds(PAD * 2 + (pw - PAD * 3) / 2, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
			end)
			btnAddModel:Dock(TOP)
			btnAddModel:SetTall(SScale(22))
			btnAddModel:DockMargin(0, GAP, 0, 0)

		end

		-- Botón nuevo preset
		local btnNew = makeBtn(presetScroll, "+ Nuevo preset", 30, 80, 30, function()
			local pw, ph = SScale(300), SScale(90)
			local pop    = vgui.Create("DFrame")
			pop:SetSize(pw, ph); pop:Center()
			pop:SetTitle(""); pop:SetDraggable(true)
			pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
			pop.Paint = function(s, w, h) paintFrame(s, w, h) end
			makeLabel(pop, "Nombre del nuevo preset:", "Metro UI.CharFields", Color(200, 200, 200))
				:SetBounds(PAD, SScale(10), pw - PAD * 2, SScale(14))
			local eName = makeEntry(pop, "")
			eName:SetBounds(PAD, SScale(26), pw - PAD * 2, SScale(20))
			makeBtn(pop, "Crear", 30, 100, 30, function()
				local nombre = eName:GetValue():Trim()
				if (nombre != "" and !workData.presets[nombre]) then
					workData.presets[nombre] = { models = {}, tiers = {} }
					selectedPreset = nombre
					buildPresetList()
					refreshPresetCombo()
				end
				pop:Remove()
			end):SetBounds(PAD, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
			makeBtn(pop, "Cancelar", 130, 30, 30, function() pop:Remove() end)
				:SetBounds(PAD * 2 + (pw - PAD * 3) / 2, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
		end)
		btnNew:Dock(TOP); btnNew:SetTall(SScale(22)); btnNew:DockMargin(0, GAP, 0, 0)
	end

	buildPresetList()

	-- ══════════════════════════════════════════════════════════
	--  COLUMNA DERECHA — TIER MANAGER
	-- ══════════════════════════════════════════════════════════

	local colLootX = colPresetX + colW + GAP
	makeLabel(frame, "Gestor de Tiers", "Metro UI.CharFields", Color(175, 177, 148))
		:SetBounds(colLootX, topY, rColW, SScale(16))

	local tierScroll = frame:Add("DScrollPanel")
	tierScroll:SetBounds(colLootX, topY + SScale(18), rColW, bodyH)
	tierScroll:GetVBar():SetWide(SScale(3))

	local tierDetailPanel = nil

	buildTierDetail = function()
		if (!IsValid(tierDetailPanel)) then return end
		tierDetailPanel:Clear()
		tierDetailPanel:SetTall(0)
		if (!selectedTier or !workData.customTiers[selectedTier]) then return end

		local def = workData.customTiers[selectedTier]
		local capturedTierID = selectedTier
		local rowCount = 0

		-- Nombre
		local rowName = tierDetailPanel:Add("DPanel")
		rowName:Dock(TOP); rowName:DockMargin(0, 0, 0, 2); rowName:SetTall(SScale(20))
		rowName.Paint = function() end

		local lblNombre = makeLabel(rowName, "Nombre:", "ixSmallFont", Color(160, 160, 160))
		lblNombre:Dock(LEFT); lblNombre:SetWide(SScale(44))
		local nameEntry = rowName:Add("DTextEntry")
		nameEntry:SetFont("ixSmallFont"); nameEntry:SetText(def.name or "")
		nameEntry:Dock(FILL); nameEntry:DockMargin(2, 1, 0, 1)
		nameEntry.Paint = paintDarkEntry
		local function saveTierName(s)
			def.name = s:GetValue():Trim()
		end
		nameEntry.OnEnter = saveTierName
		nameEntry.OnLoseFocus = saveTierName
		rowCount = rowCount + 1

		-- Color RGB
		local rowColor = tierDetailPanel:Add("DPanel")
		rowColor:Dock(TOP); rowColor:DockMargin(0, 0, 0, 2); rowColor:SetTall(SScale(20))
		rowColor.Paint = function() end

		local lblColor = makeLabel(rowColor, "Color:", "ixSmallFont", Color(160, 160, 160))
		lblColor:Dock(LEFT); lblColor:SetWide(SScale(44))

		local colorLabels = {"R", "G", "B"}
		local colorEntries = {}
		for ci = 1, 3 do
			local cLabel = rowColor:Add("DLabel")
			cLabel:SetFont("ixSmallFont"); cLabel:SetText(colorLabels[ci])
			cLabel:SetTextColor(Color(120, 120, 120))
			cLabel:Dock(LEFT); cLabel:SetWide(SScale(8)); cLabel:DockMargin(2, 0, 0, 0)

			local cEntry = rowColor:Add("DTextEntry")
			cEntry:SetFont("ixSmallFont"); cEntry:SetText(tostring(def.color[ci] or 160))
			cEntry:Dock(LEFT); cEntry:SetWide(SScale(24)); cEntry:DockMargin(0, 1, 2, 1)
			cEntry.Paint = paintDarkEntry
			local function saveColor(s)
				def.color[ci] = math.Clamp(tonumber(s:GetValue()) or 160, 0, 255)
				s:SetText(tostring(def.color[ci]))
			end
			cEntry.OnEnter = saveColor
			cEntry.OnLoseFocus = saveColor
			colorEntries[ci] = cEntry
		end

		-- Color preview swatch
		local swatch = rowColor:Add("DPanel")
		swatch:Dock(LEFT); swatch:SetWide(SScale(16)); swatch:DockMargin(4, 2, 0, 2)
		swatch.Paint = function(_, w, h)
			surface.SetDrawColor(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160, 255)
			surface.DrawRect(0, 0, w, h)
		end
		rowCount = rowCount + 1

		-- Order
		local rowOrder = tierDetailPanel:Add("DPanel")
		rowOrder:Dock(TOP); rowOrder:DockMargin(0, 0, 0, 4); rowOrder:SetTall(SScale(20))
		rowOrder.Paint = function() end

		local lblOrder = makeLabel(rowOrder, "Orden:", "ixSmallFont", Color(160, 160, 160))
		lblOrder:Dock(LEFT); lblOrder:SetWide(SScale(44))
		local orderEntry = rowOrder:Add("DTextEntry")
		orderEntry:SetFont("ixSmallFont"); orderEntry:SetText(tostring(def.order or 1))
		orderEntry:Dock(LEFT); orderEntry:SetWide(SScale(30)); orderEntry:DockMargin(2, 1, 0, 1)
		orderEntry.Paint = paintDarkEntry
		local function saveOrder(s)
			def.order = math.max(1, math.floor(tonumber(s:GetValue()) or 1))
			s:SetText(tostring(def.order))
		end
		orderEntry.OnEnter = saveOrder
		orderEntry.OnLoseFocus = saveOrder
		rowCount = rowCount + 1

		-- Separator
		local sepCh = tierDetailPanel:Add("DPanel")
		sepCh:Dock(TOP); sepCh:SetTall(SScale(1)); sepCh:DockMargin(0, 2, 0, 4)
		sepCh.Paint = function(_, w, h)
			surface.SetDrawColor(66, 66, 66, 180); surface.DrawRect(0, 0, w, h)
		end
		rowCount = rowCount + 1

		-- Chances header + total
		local chancesHeader = tierDetailPanel:Add("DPanel")
		chancesHeader:Dock(TOP); chancesHeader:DockMargin(0, 0, 0, 2); chancesHeader:SetTall(SScale(14))
		chancesHeader.Paint = function() end

		local lblChances = makeLabel(chancesHeader, "Entradas de loot:", "ixSmallFont", Color(180, 180, 180))
		lblChances:Dock(LEFT); lblChances:SetWide(SScale(80))

		local lblTotal = chancesHeader:Add("DLabel")
		lblTotal:SetFont("ixSmallFont")
		lblTotal:Dock(FILL); lblTotal:DockMargin(4, 0, 0, 0)

		local function updateChancesTotal()
			local t = 0
			for _, ch in ipairs(def.chances or {}) do
				t = t + (tonumber(ch[1]) or 0)
			end
			lblTotal:SetText("Total: " .. t .. "/100")
			lblTotal:SetTextColor(t > 100 and Color(255, 60, 60) or (t == 100 and Color(60, 200, 60) or Color(175, 177, 148)))
		end
		updateChancesTotal()
		rowCount = rowCount + 1

		-- Chance entries
		if (!def.chances) then def.chances = {} end
		for i, ch in ipairs(def.chances) do
			local capturedIdx = i
			local chRow = tierDetailPanel:Add("DPanel")
			chRow:Dock(TOP); chRow:DockMargin(0, 1, 0, 1); chRow:SetTall(SScale(20))
			chRow.Paint = function(_, w, h)
				surface.SetDrawColor(44, 44, 44, 180); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(66, 66, 66, 60); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			-- Weight input
			local wEntry = chRow:Add("DTextEntry")
			wEntry:SetFont("ixSmallFont"); wEntry:SetText(tostring(ch[1] or 50))
			wEntry:Dock(LEFT); wEntry:SetWide(SScale(30)); wEntry:DockMargin(2, 1, 2, 1)
			wEntry.Paint = paintDarkEntry
			local function saveChanceWeight(s)
				local val = math.max(1, math.floor(tonumber(s:GetValue()) or 1))
				ch[1] = val
				s:SetText(tostring(val))
				updateChancesTotal()
			end
			wEntry.OnEnter = saveChanceWeight
			wEntry.OnLoseFocus = saveChanceWeight

			-- Delete button
			local btnChDel = chRow:Add("DButton")
			btnChDel:SetText("x"); btnChDel:SetFont("ixSmallFont")
			btnChDel:SetTextColor(Color(200, 80, 80))
			btnChDel:Dock(RIGHT); btnChDel:SetWide(SScale(16)); btnChDel:DockMargin(1, 1, 1, 1)
			btnChDel.Paint = function(s, w, h)
				surface.SetDrawColor(130, 30, 30, s:IsHovered() and 40 or 12); surface.DrawRect(0, 0, w, h)
			end
			btnChDel.DoClick = function()
				table.remove(def.chances, capturedIdx)
				buildTierDetail()
			end

			-- Table name label (display name + id)
			local tblLbl = chRow:Add("DLabel")
			tblLbl:SetFont("ixSmallFont")
			tblLbl:SetTextColor(Color(175, 177, 148))
			tblLbl:SetText(getTableDisplayName(ch[2], workData) .. "  [" .. (ch[2] or "?") .. "]")
			tblLbl:Dock(FILL); tblLbl:DockMargin(4, 0, 0, 0)

			rowCount = rowCount + 1
		end

		-- Add chance entry button
		local btnAddCh = makeBtn(tierDetailPanel, "+ Entrada", 30, 80, 30, function()
			-- Popup: seleccionar tabla de loot existente o crear nueva
			local allTables = {}
			for tblKey, _ in pairs(ix.loot.tables) do
				allTables[#allTables + 1] = tblKey
			end
			for tblKey, _ in pairs(workData.lootTables) do
				if (!ix.loot.tables[tblKey]) then
					allTables[#allTables + 1] = tblKey
				end
			end
			table.sort(allTables)

			local pw, ph = SScale(300), SScale(340)
			local pop = vgui.Create("DFrame")
			pop:SetSize(pw, ph); pop:Center()
			pop:SetTitle(""); pop:SetDraggable(true)
			pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
			pop.Paint = function(s, w, h) paintFrame(s, w, h) end

			makeLabel(pop, "Seleccionar tabla de loot", "Metro UI.Button", Color(225, 225, 225))
				:SetBounds(PAD, PAD, pw - SScale(70), SScale(20))
			makeBtn(pop, "Cerrar", 130, 30, 30, function() pop:Remove() end)
				:SetBounds(pw - SScale(60) - PAD, PAD, SScale(60), SScale(20))

			-- Weight input
			makeLabel(pop, "Peso:", "Metro UI.CharFields", Color(160, 160, 160))
				:SetBounds(PAD, SScale(34), SScale(40), SScale(16))
			local wInput = makeEntry(pop, "50")
			wInput:SetBounds(SScale(44), SScale(34), SScale(40), SScale(18))

			-- New table: ID + display name
			makeLabel(pop, "O crear nueva tabla (ID):", "Metro UI.CharFields", Color(160, 160, 160))
				:SetBounds(PAD, SScale(56), pw - PAD * 2, SScale(14))
			local newTblEntry = makeEntry(pop, "")
			newTblEntry:SetBounds(PAD, SScale(70), SScale(120), SScale(18))

			makeLabel(pop, "Nombre:", "Metro UI.CharFields", Color(160, 160, 160))
				:SetBounds(SScale(128), SScale(56), SScale(50), SScale(14))
			local newTblNameEntry = makeEntry(pop, "")
			newTblNameEntry:SetBounds(SScale(128), SScale(70), pw - SScale(198) - PAD, SScale(18))

			makeBtn(pop, "Crear", 30, 80, 130, function()
				local tblID   = newTblEntry:GetValue():Trim():lower():gsub("%s+", "_")
				local tblName = newTblNameEntry:GetValue():Trim()
				local weight  = math.max(1, math.floor(tonumber(wInput:GetValue()) or 50))
				if (tblID != "") then
					if (!ix.loot.tables[tblID] and !workData.lootTables[tblID]) then
						workData.lootTables[tblID] = {}
						ix.loot.tables[tblID] = {}
					end
					if (tblName != "") then
						workData.tableNames[tblID] = tblName
					end
					def.chances[#def.chances + 1] = {weight, tblID}
					buildTierDetail()
					pop:Remove()
				end
			end):SetBounds(pw - SScale(60) - PAD, SScale(70), SScale(60), SScale(18))

			-- Existing tables list
			local tblScroll = pop:Add("DScrollPanel")
			tblScroll:SetBounds(PAD, SScale(94), pw - PAD * 2, ph - SScale(94) - PAD)
			tblScroll:GetVBar():SetWide(SScale(3))

			for _, tblKey in ipairs(allTables) do
				local capturedKey = tblKey
				local displayName = getTableDisplayName(tblKey, workData)
				local itemCount = 0
				if (ix.loot.tables[tblKey]) then itemCount = #ix.loot.tables[tblKey] end

				local tRow = tblScroll:Add("DButton")
				tRow:SetText("")
				tRow:Dock(TOP); tRow:DockMargin(0, 0, 0, 2); tRow:SetTall(SScale(22))
				tRow.Paint = function(s, w, h)
					surface.SetDrawColor(38, 38, 38, 220); surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(80, 80, 80, s:IsHovered() and 80 or 30); surface.DrawOutlinedRect(0, 0, w, h, 1)
					draw.SimpleText(displayName, "Metro UI.CharFields", PAD, h / 2, Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(itemCount .. " items", "ixSmallFont", w - PAD, h / 2, Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
				tRow:SetTooltip(capturedKey)
				tRow.DoClick = function()
					local weight = math.max(1, math.floor(tonumber(wInput:GetValue()) or 50))
					def.chances[#def.chances + 1] = {weight, capturedKey}
					buildTierDetail()
					pop:Remove()
				end
			end
		end)
		btnAddCh:Dock(TOP); btnAddCh:SetTall(SScale(20)); btnAddCh:DockMargin(0, GAP, 0, 0)
		rowCount = rowCount + 1

		-- ── Editar items de tablas usadas por este tier ───────

		local sepItems = tierDetailPanel:Add("DPanel")
		sepItems:Dock(TOP); sepItems:SetTall(SScale(1)); sepItems:DockMargin(0, GAP, 0, GAP)
		sepItems.Paint = function(_, w, h)
			surface.SetDrawColor(66, 66, 66, 180); surface.DrawRect(0, 0, w, h)
		end
		rowCount = rowCount + 1

		-- Collect unique tables used by this tier
		local usedTables = {}
		local seenTbl = {}
		for _, ch in ipairs(def.chances) do
			if (ch[2] and !seenTbl[ch[2]]) then
				seenTbl[ch[2]] = true
				usedTables[#usedTables + 1] = ch[2]
			end
		end
		table.sort(usedTables)

		for _, tblKey in ipairs(usedTables) do
			local capturedTblKey = tblKey
			local tblItems = (workData.lootTables[tblKey] and #workData.lootTables[tblKey] > 0) and workData.lootTables[tblKey] or ix.loot.tables[tblKey] or {}

			local tblDisplayName = getTableDisplayName(capturedTblKey, workData)

			local tblHeader = tierDetailPanel:Add("DPanel")
			tblHeader:Dock(TOP); tblHeader:DockMargin(0, 0, 0, 2); tblHeader:SetTall(SScale(26))
			tblHeader.Paint = function(_, w, h)
				surface.SetDrawColor(50, 50, 50, 180); surface.DrawRect(0, 0, w, h)
			end

			-- Rename button
			local btnRenTbl = tblHeader:Add("DButton")
			btnRenTbl:SetText("~"); btnRenTbl:SetFont("ixSmallFont")
			btnRenTbl:SetTextColor(Color(200, 200, 80))
			btnRenTbl:Dock(RIGHT); btnRenTbl:SetWide(SScale(16)); btnRenTbl:DockMargin(1, 1, 1, 1)
			btnRenTbl.Paint = function(s, w, h)
				surface.SetDrawColor(100, 100, 30, s:IsHovered() and 50 or 14); surface.DrawRect(0, 0, w, h)
			end
			btnRenTbl:SetTooltip("Renombrar tabla")
			btnRenTbl.DoClick = function()
				local rpw, rph = SScale(300), SScale(90)
				local rpop = vgui.Create("DFrame")
				rpop:SetSize(rpw, rph); rpop:Center()
				rpop:SetTitle(""); rpop:SetDraggable(true)
				rpop:ShowCloseButton(false); rpop:MakePopup(); rpop:SetDeleteOnClose(true)
				rpop.Paint = function(s, w, h) paintFrame(s, w, h) end
				makeLabel(rpop, "Nombre para '" .. capturedTblKey .. "':", "Metro UI.CharFields", Color(200, 200, 200))
					:SetBounds(PAD, SScale(10), rpw - PAD * 2, SScale(14))
				local eRenTbl = makeEntry(rpop, tblDisplayName)
				eRenTbl:SetBounds(PAD, SScale(26), rpw - PAD * 2, SScale(20))
				makeBtn(rpop, "Guardar", 30, 100, 30, function()
					local newName = eRenTbl:GetValue():Trim()
					if (newName != "") then
						workData.tableNames[capturedTblKey] = newName
					end
					rpop:Remove()
					buildTierDetail()
				end):SetBounds(PAD, rph - SScale(26) - PAD, (rpw - PAD * 3) / 2, SScale(22))
				makeBtn(rpop, "Cancelar", 130, 30, 30, function() rpop:Remove() end)
					:SetBounds(PAD * 2 + (rpw - PAD * 3) / 2, rph - SScale(26) - PAD, (rpw - PAD * 3) / 2, SScale(22))
			end

			-- Edit items button (main area)
			local btnEditTbl = tblHeader:Add("DButton")
			btnEditTbl:SetText("")
			btnEditTbl:Dock(FILL)
			btnEditTbl.Paint = function(s, w, h)
				draw.SimpleText(tblDisplayName .. " (" .. #tblItems .. ")", "ixSmallFont", PAD, h / 2 - SScale(3),
					Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText("id: " .. capturedTblKey, "ixSmallFont", PAD, h / 2 + SScale(5),
					Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(s:IsHovered() and "items" or "", "ixSmallFont", w - PAD, h / 2,
					Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			btnEditTbl.DoClick = function()
				-- Open item editor popup for this table
				local pw, ph = math.min(SScale(400), sw - SScale(40)), math.min(SScale(460), sh - SScale(40))
				local pop = vgui.Create("DFrame")
				pop:SetSize(pw, ph); pop:Center()
				pop:SetTitle(""); pop:SetDraggable(true)
				pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
				pop.Paint = function(s, w, h) paintFrame(s, w, h) end

				makeLabel(pop, "Items: " .. tblDisplayName, "Metro UI.Button", Color(225, 225, 225))
					:SetBounds(PAD, PAD, pw - SScale(70), SScale(20))
				makeBtn(pop, "Cerrar", 130, 30, 30, function() pop:Remove() end)
					:SetBounds(pw - SScale(60) - PAD, PAD, SScale(60), SScale(20))

				-- Ensure override table exists
				if (!workData.lootTables[capturedTblKey]) then
					workData.lootTables[capturedTblKey] = table.Copy(ix.loot.tables[capturedTblKey] or {})
				end
				local editTable = workData.lootTables[capturedTblKey]

				local itemEditScroll = pop:Add("DScrollPanel")
				itemEditScroll:SetBounds(PAD, SScale(34), pw - PAD * 2, ph - SScale(70))
				itemEditScroll:GetVBar():SetWide(SScale(3))

				local function buildItemEditList()
					itemEditScroll:Clear()
					for idx, entry in ipairs(editTable) do
						local capturedItemIdx = idx
						local itemID = istable(entry) and entry[1] or entry
						local itemWeight = istable(entry) and (tonumber(entry[2]) or 1) or 1
						local itemMaxQty = istable(entry) and (tonumber(entry[3]) or 1) or 1

						local iRow = itemEditScroll:Add("DPanel")
						iRow:Dock(TOP); iRow:DockMargin(0, 1, 0, 1); iRow:SetTall(SScale(20))
						iRow.Paint = function(_, w, h)
							surface.SetDrawColor(38, 38, 38, 200); surface.DrawRect(0, 0, w, h)
							surface.SetDrawColor(66, 66, 66, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
						end

						local btnItemDel = iRow:Add("DButton")
						btnItemDel:SetText("x"); btnItemDel:SetFont("ixSmallFont")
						btnItemDel:SetTextColor(Color(200, 80, 80))
						btnItemDel:Dock(RIGHT); btnItemDel:SetWide(SScale(16)); btnItemDel:DockMargin(1, 1, 1, 1)
						btnItemDel.Paint = function(s, w, h)
							surface.SetDrawColor(130, 30, 30, s:IsHovered() and 40 or 12); surface.DrawRect(0, 0, w, h)
						end
						btnItemDel.DoClick = function()
							table.remove(editTable, capturedItemIdx)
							buildItemEditList()
						end

						local qtyEntry = iRow:Add("DTextEntry")
						qtyEntry:SetFont("ixSmallFont"); qtyEntry:SetText(tostring(itemMaxQty))
						qtyEntry:Dock(RIGHT); qtyEntry:SetWide(SScale(22)); qtyEntry:DockMargin(1, 1, 1, 1)
						qtyEntry:SetTooltip("Cantidad maxima (1 a N)")
						qtyEntry.Paint = paintDarkEntry

						local lblQ = iRow:Add("DLabel")
						lblQ:SetFont("ixSmallFont"); lblQ:SetText("max")
						lblQ:SetTextColor(Color(120, 120, 120))
						lblQ:Dock(RIGHT); lblQ:SetWide(SScale(16)); lblQ:DockMargin(2, 0, 0, 0)

						local wEntry = iRow:Add("DTextEntry")
						wEntry:SetFont("ixSmallFont"); wEntry:SetText(tostring(itemWeight))
						wEntry:Dock(RIGHT); wEntry:SetWide(SScale(22)); wEntry:DockMargin(1, 1, 1, 1)
						wEntry:SetTooltip("Peso (mayor = mas frecuente)")
						wEntry.Paint = paintDarkEntry

						local lblW = iRow:Add("DLabel")
						lblW:SetFont("ixSmallFont"); lblW:SetText("w")
						lblW:SetTextColor(Color(120, 120, 120))
						lblW:Dock(RIGHT); lblW:SetWide(SScale(8)); lblW:DockMargin(2, 0, 0, 0)

						local function saveItemEntry()
							local w = math.max(1, math.floor(tonumber(wEntry:GetValue()) or 1))
							local q = math.max(1, math.floor(tonumber(qtyEntry:GetValue()) or 1))
							wEntry:SetText(tostring(w))
							qtyEntry:SetText(tostring(q))
							editTable[capturedItemIdx] = {itemID, w, q}
						end
						wEntry.OnEnter = saveItemEntry
						wEntry.OnLoseFocus = saveItemEntry
						qtyEntry.OnEnter = saveItemEntry
						qtyEntry.OnLoseFocus = saveItemEntry

						local itemDef = itemList[itemID]
						local iLbl = iRow:Add("DLabel")
						iLbl:SetFont("ixSmallFont")
						iLbl:SetTextColor(Color(175, 177, 148))
						iLbl:SetText((itemDef and itemDef.category or "?") .. " - " .. (itemDef and itemDef.name or itemID))
						iLbl:Dock(FILL); iLbl:DockMargin(PAD, 0, 0, 0)
					end

					-- Add item button
					local btnAddItem = makeBtn(itemEditScroll, "+ Anadir item", 30, 80, 30, function()
						local apw, aph = math.min(SScale(380), sw - SScale(40)), math.min(SScale(420), sh - SScale(40))
						local addPop = vgui.Create("DFrame")
						addPop:SetSize(apw, aph); addPop:Center()
						addPop:SetTitle(""); addPop:SetDraggable(true)
						addPop:ShowCloseButton(false); addPop:MakePopup(); addPop:SetDeleteOnClose(true)
						addPop.Paint = function(s, w, h) paintFrame(s, w, h) end

						makeLabel(addPop, "Seleccionar item", "Metro UI.Button", Color(225, 225, 225))
							:SetBounds(PAD, PAD, apw - SScale(70), SScale(20))
						makeBtn(addPop, "Cerrar", 130, 30, 30, function() addPop:Remove() end)
							:SetBounds(apw - SScale(60) - PAD, PAD, SScale(60), SScale(20))

						local search = makeEntry(addPop, "")
						search:SetBounds(PAD, SScale(34), apw - PAD * 2, SScale(20))
						search:SetPlaceholderText("Buscar...")

						local addScroll = addPop:Add("DScrollPanel")
						addScroll:SetBounds(PAD, SScale(58), apw - PAD * 2, aph - SScale(58) - PAD)
						addScroll:GetVBar():SetWide(SScale(3))

						local function buildAddList(filter)
							addScroll:Clear()
							local sortedItems = {}
							for id, iDef in pairs(itemList) do
								sortedItems[#sortedItems + 1] = { id = id, name = iDef.name, category = iDef.category }
							end
							table.sort(sortedItems, function(a, b) return (a.category .. a.name) < (b.category .. b.name) end)
							local filterLow = filter and filter:lower() or ""
							for _, entry in ipairs(sortedItems) do
								if (filterLow != "" and !entry.name:lower():find(filterLow, 1, true) and !entry.category:lower():find(filterLow, 1, true)) then
									continue
								end
								local capturedAddID = entry.id
								local aRow = addScroll:Add("DButton")
								aRow:SetText("")
								aRow:Dock(TOP); aRow:DockMargin(0, 0, 0, 2); aRow:SetTall(SScale(22))
								aRow.Paint = function(s, w, h)
									surface.SetDrawColor(38, 38, 38, 220); surface.DrawRect(0, 0, w, h)
									surface.SetDrawColor(80, 80, 80, s:IsHovered() and 80 or 30); surface.DrawOutlinedRect(0, 0, w, h, 1)
									draw.SimpleText(entry.category .. " - " .. entry.name, "Metro UI.CharFields",
										PAD, h / 2, Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
								end
								aRow.DoClick = function()
									table.insert(editTable, {capturedAddID, 1, 1})
									addPop:Remove()
									buildItemEditList()
								end
							end
						end

						buildAddList("")
						search.OnChange = function(s) buildAddList(s:GetValue()) end
					end)
					btnAddItem:Dock(TOP); btnAddItem:SetTall(SScale(20)); btnAddItem:DockMargin(0, GAP, 0, 0)
				end

				buildItemEditList()

				-- Apply changes on close
				pop.OnRemove = function()
					ix.loot.tables[capturedTblKey] = editTable
					buildTierDetail()
				end
			end
			rowCount = rowCount + 1
		end

		tierDetailPanel:SetTall(math.max(1, rowCount * SScale(24) + SScale(20)))
		tierDetailPanel:InvalidateLayout(true)
	end

	buildTierList = function()
		tierScroll:Clear()

		local sortedIDs = getSortedTierIDsFromData(workData.customTiers)

		for _, tierID in ipairs(sortedIDs) do
			local def = workData.customTiers[tierID]
			if (!def) then continue end
			local capturedID = tierID

			local row = tierScroll:Add("DButton")
			row:SetText("")
			row:Dock(TOP); row:DockMargin(0, 0, 0, 2); row:SetTall(SScale(32))
			row.Paint = function(s, w, h)
				local sel = selectedTier == capturedID
				local r, g, b = def.color[1] or 160, def.color[2] or 160, def.color[3] or 160
				surface.SetDrawColor(sel and r or 38, sel and g or 38, sel and b or 38, sel and 40 or 200)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(r, g, b, sel and 180 or 50)
				surface.DrawOutlinedRect(0, 0, w, h, sel and 2 or 1)
				-- Color swatch
				surface.SetDrawColor(r, g, b, 255)
				surface.DrawRect(3, 3, SScale(10), h - 6)
				-- Name + ID
				draw.SimpleText((def.name or capturedID) .. "  ", "Metro UI.CharFields", SScale(16), h / 2 - SScale(2), Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText("id: " .. capturedID, "ixSmallFont", SScale(16), h / 2 + SScale(6), Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				-- Chances count
				local chCount = def.chances and #def.chances or 0
				draw.SimpleText(chCount .. " ent", "ixSmallFont", w - SScale(22), h / 2, Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			-- Delete tier button
			local btnTDel = row:Add("DButton")
			btnTDel:SetText("x"); btnTDel:SetFont("ixSmallFont")
			btnTDel:SetTextColor(Color(200, 80, 80))
			btnTDel:Dock(RIGHT); btnTDel:SetWide(SScale(18)); btnTDel:DockMargin(1, 2, 2, 2)
			btnTDel.Paint = function(s, w, h)
				surface.SetDrawColor(130, 30, 30, s:IsHovered() and 50 or 14); surface.DrawRect(0, 0, w, h)
			end
			btnTDel.DoClick = function()
				workData.customTiers[capturedID] = nil
				-- Clean references in presets
				for _, preset in pairs(workData.presets) do
					if (preset.tiers) then
						for i = #preset.tiers, 1, -1 do
							if (preset.tiers[i].id == capturedID) then
								table.remove(preset.tiers, i)
							end
						end
					end
				end
				-- Clean references in areaTiers
				for area, tiers in pairs(workData.areaTiers) do
					if (istable(tiers)) then
						for i = #tiers, 1, -1 do
							if (istable(tiers[i]) and tiers[i].id == capturedID) then
								table.remove(tiers, i)
							end
						end
					end
				end
				if (selectedTier == capturedID) then selectedTier = nil end
				buildTierList()
				rebuildAreaDetail()
			end

			row.DoClick = function()
				selectedTier = capturedID
				buildTierList()
				buildTierDetail()
			end
		end

		-- Separator
		local sep = tierScroll:Add("DPanel")
		sep:Dock(TOP); sep:SetTall(SScale(1)); sep:DockMargin(0, 4, 0, 4)
		sep.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 180); surface.DrawRect(0, 0, w, h) end

		-- Tier detail panel
		if (selectedTier and workData.customTiers[selectedTier]) then
			makeLabel(tierScroll, "Editar: " .. (workData.customTiers[selectedTier].name or selectedTier), "ixSmallFont", Color(160, 200, 160))
				:Dock(TOP)

			tierDetailPanel = tierScroll:Add("DPanel")
			tierDetailPanel:Dock(TOP)
			tierDetailPanel:SetTall(0)
			tierDetailPanel.Paint = function() end

			buildTierDetail()
		end

		-- New tier button
		local btnNewTier = makeBtn(tierScroll, "+ Nuevo Tier", 30, 80, 30, function()
			local pw, ph = SScale(300), SScale(120)
			local pop = vgui.Create("DFrame")
			pop:SetSize(pw, ph); pop:Center()
			pop:SetTitle(""); pop:SetDraggable(true)
			pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
			pop.Paint = function(s, w, h) paintFrame(s, w, h) end

			makeLabel(pop, "ID del nuevo tier:", "Metro UI.CharFields", Color(200, 200, 200))
				:SetBounds(PAD, SScale(10), pw - PAD * 2, SScale(14))
			local eID = makeEntry(pop, "")
			eID:SetBounds(PAD, SScale(26), pw - PAD * 2, SScale(20))

			makeLabel(pop, "Nombre:", "Metro UI.CharFields", Color(200, 200, 200))
				:SetBounds(PAD, SScale(50), pw - PAD * 2, SScale(14))
			local eName = makeEntry(pop, "")
			eName:SetBounds(PAD, SScale(64), pw - PAD * 2, SScale(20))

			makeBtn(pop, "Crear", 30, 100, 30, function()
				local newID   = eID:GetValue():Trim():lower():gsub("%s+", "_")
				local newName = eName:GetValue():Trim()
				if (newID != "" and newName != "" and !workData.customTiers[newID]) then
					local maxOrder = 0
					for _, d in pairs(workData.customTiers) do
						if ((d.order or 0) > maxOrder) then maxOrder = d.order or 0 end
					end
					workData.customTiers[newID] = {
						name    = newName,
						color   = {160, 160, 160},
						order   = maxOrder + 1,
						chances = {},
					}
					selectedTier = newID
					buildTierList()
					buildTierDetail()
					rebuildAreaDetail()
				end
				pop:Remove()
			end):SetBounds(PAD, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
			makeBtn(pop, "Cancelar", 130, 30, 30, function() pop:Remove() end)
				:SetBounds(PAD * 2 + (pw - PAD * 3) / 2, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
		end)
		btnNewTier:Dock(TOP); btnNewTier:SetTall(SScale(22)); btnNewTier:DockMargin(0, GAP, 0, 0)
	end

	buildTierList()

	-- ══════════════════════════════════════════════════════════
	--  BOTÓN GUARDAR
	-- ══════════════════════════════════════════════════════════

	makeBtn(frame, "Guardar cambios", 30, 130, 30, function()
		applyAreaChanges()
		net.Start("ixLootAdminSave")
			ix.loot.WriteCompressed(workData)
		net.SendToServer()
		frame:Remove()
	end):SetBounds(W / 2 - SScale(80), H - btnH - PAD, SScale(160), SScale(26))
end

-- ── Receptor de red para abrir panel ─────────────────────────

-- ============================================================
--  OCULTAR loot_zone DE LA UI DE USUARIOS
-- ============================================================

function PLUGIN:ShouldDisplayArea(id)
	local area = ix.area.stored and ix.area.stored[id]
	if (area and area.type == "loot_zone") then
		return false
	end
end

-- ============================================================
--  OCULTAR loot_zone DEL /areaedit DE HELIX
-- ============================================================

function PLUGIN:InitPostEntity()
	timer.Simple(0.1, function()
		local hooks = hook.GetTable()["PostDrawTranslucentRenderables"]
		if (!hooks or !hooks["area"]) then return end

		local origFn = hooks["area"]
		hooks["area"] = function(bDepth, bSkybox)
			if (!ix.area.bEditing) then
				return origFn(bDepth, bSkybox)
			end
			local hidden = {}
			for name, area in pairs(ix.area.stored or {}) do
				if (area.type == "loot_zone") then
					hidden[name] = area
					ix.area.stored[name] = nil
				end
			end
			local result = origFn(bDepth, bSkybox)
			for name, area in pairs(hidden) do
				ix.area.stored[name] = area
			end
			return result
		end
	end)
end

-- ============================================================
--  MODO DE COLOCACIÓN VISUAL DE ÁREA DE LOOT
-- ============================================================

local _placingArea  = false
local _placeCorner1 = nil

local function cancelAreaPlace()
	_placingArea  = false
	_placeCorner1 = nil
end

net.Receive("ixLootAreaCreateMode", function()
	if (_placingArea) then
		cancelAreaPlace()
		LocalPlayer():ChatPrint("[Loot] Colocación cancelada.")
		return
	end
	_placingArea  = true
	_placeCorner1 = nil
	LocalPlayer():ChatPrint("[Loot] Clic izquierdo = primera esquina. Clic derecho = cancelar.")
end)

hook.Add("PostDrawTranslucentRenderables", "ixLoot.AreaPlace", function(_, bSkybox)
	if (bSkybox or not _placingArea) then return end

	local trace  = LocalPlayer():GetEyeTraceNoCursor()
	local hitPos = trace.HitPos

	if (_placeCorner1) then
		render.DrawSphere(_placeCorner1, 8, 12, 12, Color(145, 148, 108, 200))
		local center = LerpVector(0.5, _placeCorner1, hitPos)
		local min    = WorldToLocal(_placeCorner1, angle_zero, center, angle_zero)
		local max    = WorldToLocal(hitPos, angle_zero, center, angle_zero)
		render.DrawWireframeBox(center, angle_zero, min, max, Color(145, 148, 108, 200))
	else
		render.DrawSphere(hitPos, 6, 12, 12, Color(255, 200, 50, 220))
	end
end)

hook.Add("HUDPaint", "ixLoot.CrosshairDot", function()
	if (not _showPoints) then return end

	local cx, cy = ScrW() * 0.5, ScrH() * 0.5
	local r      = 4

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(cx - r - 1, cy - 1, (r * 2) + 2, 3)
	surface.DrawRect(cx - 1, cy - r - 1, 3, (r * 2) + 2)

	surface.SetDrawColor(145, 148, 108, 255)
	surface.DrawRect(cx - r, cy - 1, r * 2, 2)
	surface.DrawRect(cx - 1, cy - r, 2, r * 2)

	surface.DrawRect(cx - 1, cy - 1, 3, 3)
end)

hook.Add("HUDPaint", "ixLoot.AreaPlaceHUD", function()
	if (not _placingArea) then return end

	local cx   = ScrW() * 0.5
	local step = _placeCorner1 and "Clic izq en la SEGUNDA esquina" or "Clic izq en la PRIMERA esquina"

	draw.SimpleText("[LootArea]  " .. step, "BudgetLabel", cx + 1, 81, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("[LootArea]  " .. step, "BudgetLabel", cx,     80, Color(255, 165, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (_placeCorner1) then
		local v = _placeCorner1
		local s = string.format("Esquina 1:  %.0f  %.0f  %.0f", v.x, v.y, v.z)
		draw.SimpleText(s, "BudgetLabel", cx, 96, Color(200, 200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText("Clic derecho para cancelar", "BudgetLabel", cx, 112, Color(200, 90, 90, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("PlayerBindPress", "ixLoot.AreaPlaceInput", function(_, bind, bPressed)
	if (not _placingArea or not bPressed) then return end

	if (bind:find("attack2")) then
		cancelAreaPlace()
		LocalPlayer():ChatPrint("[Loot] Colocación cancelada.")
		return true
	end

	if (bind:find("attack") and not bind:find("attack2")) then
		local hitPos = LocalPlayer():GetEyeTraceNoCursor().HitPos

		if (not _placeCorner1) then
			_placeCorner1 = hitPos
			local v = hitPos
			LocalPlayer():ChatPrint(string.format("[Loot] Esquina 1: %.0f %.0f %.0f — ahora clic en la segunda.", v.x, v.y, v.z))
		else
			local c1 = _placeCorner1
			local c2 = hitPos
			cancelAreaPlace()

			local pw, ph = SScale(300), SScale(90)
			local pop = vgui.Create("DFrame")
			pop:SetSize(pw, ph); pop:Center()
			pop:SetTitle(""); pop:SetDraggable(true)
			pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
			pop.Paint = function(s, w, h) paintFrame(s, w, h) end

			makeLabel(pop, "Nombre de la zona de loot:", "Metro UI.CharFields", Color(200, 200, 200))
				:SetBounds(PAD, SScale(10), pw - PAD * 2, SScale(14))
			local eNombre = makeEntry(pop, "")
			eNombre:SetBounds(PAD, SScale(26), pw - PAD * 2, SScale(20))

			makeBtn(pop, "Crear", 30, 100, 30, function()
				local nombre = eNombre:GetValue():Trim()
				if (nombre != "") then
					local vMin = Vector(math.min(c1.x, c2.x), math.min(c1.y, c2.y), math.min(c1.z, c2.z))
					local vMax = Vector(math.max(c1.x, c2.x), math.max(c1.y, c2.y), math.max(c1.z, c2.z))
					net.Start("ixLootAreaCreate")
						net.WriteString(nombre)
						net.WriteVector(vMin)
						net.WriteVector(vMax)
					net.SendToServer()
				end
				pop:Remove()
			end):SetBounds(PAD, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))

			makeBtn(pop, "Cancelar", 130, 30, 30, function() pop:Remove() end)
				:SetBounds(PAD * 2 + (pw - PAD * 3) / 2, ph - SScale(26) - PAD, (pw - PAD * 3) / 2, SScale(22))
		end
		return true
	end
end)

-- ── Receptor de red para abrir panel ─────────────────────────

net.Receive("ixLootAdminOpen", function()
	local data     = ix.loot.ReadCompressed()
	local itemList = ix.loot.ReadCompressed()
	if (data.customTiers and next(data.customTiers)) then
		ix.loot.clientTierCache = data.customTiers
		_cachedTiers = data.customTiers
	end
	openAdminPanel(data, itemList)
end)
