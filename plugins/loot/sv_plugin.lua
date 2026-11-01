-- ============================================================
--  loot  |  sv_plugin.lua  (SERVER)
--  Persistencia de datos, spawn de contenedores, lógica de
--  loot por área y tier dinámico. Panel de admin via net.
-- ============================================================

local PLUGIN = PLUGIN

util.AddNetworkString("ixLootPickup")
util.AddNetworkString("ixLootAdminOpen")
util.AddNetworkString("ixLootAdminSave")
util.AddNetworkString("ixLootPointsData")
util.AddNetworkString("ixLootAreaCreateMode")
util.AddNetworkString("ixLootAreaCreate")
util.AddNetworkString("ixLootSearchStart")
util.AddNetworkString("ixLootSearchCancel")
util.AddNetworkString("ixLootSearchSnd")
util.AddNetworkString("ixLootTierSync")

PLUGIN.data           = PLUGIN.data           or {}
PLUGIN.showingPlayers = PLUGIN.showingPlayers  or {}
PLUGIN.activeSearches = PLUGIN.activeSearches  or {}

local SEARCH_SOUND = "efg/search_body.wav"

-- ── Helpers ───────────────────────────────────────────────────

local function PosToTable(vec)
	return { x = vec.x, y = vec.y, z = vec.z }
end

local function TableToPos(t)
	if (!t) then return nil end
	return Vector(t.x or 0, t.y or 0, t.z or 0)
end

-- ── Lógica de aleatoriedad ────────────────────────────────────

local _u = 0
local function SafeRand(x, y)
	_u = _u + 1
	math.randomseed(os.time() + _u)
	if (x != nil and y != nil) then
		return math.floor(x + (math.random() * (y - x)))
	end
	return math.floor(math.random() * 100)
end

local function Shuffle(tbl)
	local shuffled = table.Copy(tbl)
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

local function TblRand(t)
	if (!t or #t == 0) then return nil end
	local rk = math.random(#t)
	return t[rk]
end

-- ── Migración de datos legacy ────────────────────────────────

local function migrateData(data)
	-- 1. Crear customTiers si no existen
	if (!data.customTiers or !next(data.customTiers)) then
		data.customTiers = table.Copy(ix.loot.defaultTiers)
	end

	-- 2. Migrar areaTiers numéricos al formato nuevo {id, weight}
	if (data.areaTiers) then
		for areaName, tiers in pairs(data.areaTiers) do
			if (istable(tiers) and #tiers > 0) then
				local first = tiers[1]
				if (!istable(first)) then
					-- Formato legacy: {1, 3, 4} → {{id="t1", weight=N}, ...}
					local sorted = {}
					for _, t in ipairs(tiers) do
						local n = tonumber(t) or 1
						if (n == 2) then n = 1 end
						local tierID = "t" .. n
						if (data.customTiers[tierID]) then
							sorted[#sorted + 1] = tierID
						end
					end

					-- Deduplicar
					local seen = {}
					local unique = {}
					for _, id in ipairs(sorted) do
						if (!seen[id]) then
							seen[id] = true
							unique[#unique + 1] = id
						end
					end

					-- Asignar pesos con formula armonica (mantener comportamiento previo)
					local N = #unique
					local newTiers = {}
					for i, id in ipairs(unique) do
						local weight = math.floor(((N - i + 1) / (N * (N + 1) / 2)) * 100)
						if (weight < 1) then weight = 1 end
						newTiers[#newTiers + 1] = {id = id, weight = weight}
					end

					if (#newTiers == 0) then
						newTiers = {{id = "t1", weight = 100}}
					end

					data.areaTiers[areaName] = newTiers
				end
			end
		end
	end

	-- 3. Migrar presets: asegurar campo tiers
	if (data.presets) then
		for name, preset in pairs(data.presets) do
			if (!preset.tiers) then
				preset.tiers = {}
			end
		end
	end

	return data
end

-- ── Spawn de entidades ix_loot en el área ────────────────────

local function spawnLootForArea(areaName)
	local plugin = ix.plugin.Get("loot")
	if (!plugin) then return end

	local spawnPoints = plugin.data.spawnPoints and plugin.data.spawnPoints[areaName]
	if (!spawnPoints or #spawnPoints == 0) then return end

	local presetName = plugin.data.areaPresets and plugin.data.areaPresets[areaName]
	local preset     = presetName and plugin.data.presets and plugin.data.presets[presetName]
	local models     = preset and preset.models

	if (!models or #models == 0) then return end

	-- Resolver tiers para esta área
	local tierList = ix.loot.ResolveTiers(areaName)

	-- Spawn count: configurable por área, limitado por puntos disponibles
	local wantedCount = plugin.data.spawnCounts and plugin.data.spawnCounts[areaName] or #models
	local shuffled    = Shuffle(spawnPoints)
	local count       = math.min(wantedCount, #shuffled)

	for i = 1, count do
		local pt  = shuffled[i]
		local pos = TableToPos(pt)
		if (!pos) then continue end

		-- Verificar que la posición no esté dentro de geometría
		local tr = util.TraceHull({
			start  = pos + Vector(0, 0, 4),
			endpos = pos + Vector(0, 0, 4),
			mins   = Vector(-8, -8, 0),
			maxs   = Vector(8, 8, 16),
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (tr.StartSolid) then continue end

		-- Elegir tier para este prop
		local chosenTierID = "t1"
		if (#tierList > 0) then
			local totalWeight = 0
			for _, entry in ipairs(tierList) do
				totalWeight = totalWeight + (tonumber(entry.weight) or 1)
			end
			local roll = math.random() * totalWeight
			local cumul = 0
			for _, entry in ipairs(tierList) do
				cumul = cumul + (tonumber(entry.weight) or 1)
				if (roll < cumul) then
					chosenTierID = entry.id
					break
				end
			end
		end

		local tierColor = ix.loot.GetTierColor(chosenTierID)
		local modelPick = models[math.random(#models)]

		local ent = ents.Create("ix_loot")
		if (!IsValid(ent)) then continue end

		ent:SetModel(modelPick)
		ent:SetPos(pos + Vector(0, 0, 2))
		ent:SetAngles(Angle(0, pt.yaw or 0, 0))
		ent:Spawn()
		ent:SetNetVar("areaName", areaName)
		ent:SetNetVar("name", areaName)
		ent:SetNetVar("tier", chosenTierID)
		ent:SetNetVar("color", tierColor)
		ent:DrawShadow(false)

		local physObj = ent:GetPhysicsObject()
		if (IsValid(physObj)) then
			physObj:Wake()
			physObj:EnableMotion(false)
		end

		local mins = ent:OBBMins()
		local trFloor = util.TraceLine({
			start  = pos + Vector(0, 0, 32),
			endpos = pos - Vector(0, 0, 256),
			filter = ent,
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (trFloor.HitWorld) then
			ent:SetPos(Vector(pos.x, pos.y, trFloor.HitPos.z - mins.z + 1))
		else
			ent:DropToFloor()
		end
	end
end

-- ── pushPointsUpdate ─────────────────────────────────────────

local function pushPointsUpdate(targetClient, isToggle)
	local plugin = ix.plugin.Get("loot")
	if (!plugin) then return end

	local areasData  = {}
	local pointsData = {}

	if (plugin.data.spawnPoints) then
		for areaName, points in pairs(plugin.data.spawnPoints) do
			local tierList = ix.loot.ResolveTiers(areaName)
			local tierIDs = {}
			for _, entry in ipairs(tierList) do
				tierIDs[#tierIDs + 1] = entry.id
			end
			areasData[#areasData + 1] = {
				name       = areaName,
				presetName = plugin.data.areaPresets and plugin.data.areaPresets[areaName] or "",
				tiers      = tierIDs,
				pointCount = #points,
			}
			for _, pt in ipairs(points) do
				pointsData[#pointsData + 1] = { areaName = areaName, pos = pt }
			end
		end
	end

	local payload = {
		toggle   = isToggle == true,
		areas    = areasData,
		points   = pointsData,
		tierDefs = plugin.data.customTiers or {},
	}

	local function sendTo(ply)
		if (!IsValid(ply)) then return end
		net.Start("ixLootPointsData")
			ix.loot.WriteCompressed(payload)
		net.Send(ply)
	end

	if (targetClient) then
		sendTo(targetClient)
		return
	end

	if (!next(plugin.showingPlayers)) then return end

	for ply, _ in pairs(plugin.showingPlayers) do
		if (IsValid(ply)) then
			sendTo(ply)
		else
			plugin.showingPlayers[ply] = nil
		end
	end
end

PLUGIN.pushPointsUpdate = pushPointsUpdate

-- ── Sincronización de tiers al cliente ───────────────────────

local function sendTierSync(client)
	local plugin = ix.plugin.Get("loot")
	if (!plugin or !plugin.data or !plugin.data.customTiers) then return end

	net.Start("ixLootTierSync")
		ix.loot.WriteCompressed(plugin.data.customTiers)
	net.Send(client)
end

function PLUGIN:PlayerInitialSpawn(client)
	timer.Simple(5, function()
		if (IsValid(client)) then
			sendTierSync(client)
		end
	end)
end

-- ── ix.loot.StartSearch / LootContainer ──────────────────────

function ix.loot.StartSearch(target, entity)
	if (!IsValid(target) or !IsValid(entity)) then return end

	local character = target:GetCharacter()
	if (!character) then return end

	if (entity:GetNetVar("NextLoot", os.time() - 1) > os.time()) then
		net.Start("ixLootPickup")
			net.WriteUInt(3, 3)
		net.Send(target)
		return
	end

	if (entity.searchingPlayer and IsValid(entity.searchingPlayer)) then return end

	entity.searchingPlayer = target

	local plugin = ix.plugin.Get("loot")
	if (plugin) then plugin.activeSearches[target] = entity end

	net.Start("ixLootSearchStart")
		net.WriteEntity(entity)
	net.Send(target)

	target:EmitSound(SEARCH_SOUND, 75, 100, 1)

	net.Start("ixLootSearchSnd")
		net.WriteBool(true)
	net.Send(target)

	local searchTime = hook.Run("GetTiempoSaqueo", character, 3) or 3
	target:SetAction("Rebuscando...", searchTime, function(ply)
		if (!IsValid(ply) or !IsValid(entity)) then return end
		ply:StopSound(SEARCH_SOUND)
		net.Start("ixLootSearchSnd")
			net.WriteBool(false)
		net.Send(ply)
		entity.searchingPlayer = nil
		if (plugin) then plugin.activeSearches[ply] = nil end
		net.Start("ixLootSearchCancel")
		net.Send(ply)
		ix.loot.LootContainer(ply, entity)
	end)
end

function ix.loot.LootContainer(target, entity)
	if (!IsValid(target)) then return end

	local character = target:GetCharacter()
	if (!character) then return end

	local areaName   = IsValid(entity) and entity:GetNetVar("areaName", "") or ""
	local propTierID = IsValid(entity) and entity:GetNetVar("tier", "t1") or "t1"
	local plugin     = ix.plugin.Get("loot")

	local chosenTierID, pick, qty = ix.loot.RollLoot({{id = propTierID, weight = 100}})

	local areaMaxQty = plugin and plugin.data.maxLootQty and plugin.data.maxLootQty[areaName]
	if (areaMaxQty and areaMaxQty > 0 and qty > areaMaxQty) then
		qty = areaMaxQty
	end

	if (!pick) then
		net.Start("ixLootPickup")
			net.WriteUInt(2, 3)
		net.Send(target)
		return
	end

	local inventory = character:GetInventory()
	local addedCount = 0
	local totalQty = qty or 1
	local itemDef = ix.item.list[pick]
	local maxS = itemDef and itemDef.maxstack
	local isRublos = (pick == "rublos")
	local dataKey = isRublos and "count" or "Amount"

	if (maxS and maxS > 1) or isRublos then
		local remaining = totalQty

		for _, v in pairs(inventory:GetItems()) do
			if (remaining <= 0) then break end
			if (v.uniqueID == pick) then
				local current = v:GetData(dataKey, 1)
				local cap = maxS or math.huge
				if (current < cap) then
					local toAdd = math.min(remaining, cap - current)
					v:SetData(dataKey, current + toAdd)
					remaining = remaining - toAdd
				end
			end
		end

		while (remaining > 0) do
			local stackAmt = maxS and math.min(remaining, maxS) or remaining
			local ok = inventory:Add(pick, 1, {[dataKey] = stackAmt})
			if (ok) then
				remaining = remaining - stackAmt
			else
				break
			end
		end

		addedCount = totalQty - remaining
	else
		for i = 1, totalQty do
			local item = inventory:Add(pick, 1)
			if (item) then
				addedCount = addedCount + 1
			else
				break
			end
		end
	end

	if (addedCount > 0) then
		hook.Run("OnContenedorSaqueado", target)

		target:EmitSound("sound/inv_open.mp3")
		net.Start("ixLootPickup")
			net.WriteUInt(1, 3)
			net.WriteString(itemDef and itemDef.name or pick)
			net.WriteUInt(addedCount, 8)
		net.Send(target)
		if (IsValid(entity)) then
			local respawn = (plugin and plugin.data.respawnTimes and plugin.data.respawnTimes[areaName]) or 600
			entity:SetNetVar("NextLoot", os.time() + respawn)
		end
	else
		net.Start("ixLootPickup")
			net.WriteUInt(2, 3)
		net.Send(target)
	end
end

-- ── Persistencia ─────────────────────────────────────────────

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	ix.data.SetSafe(self.uniqueID, self.data)
end

function PLUGIN:LoadData()
	local saved = self:GetData({})

	self.data = {
		spawnPoints   = saved.spawnPoints   or {},
		presets       = saved.presets       or {},
		areaPresets   = saved.areaPresets   or {},
		areaTiers     = saved.areaTiers     or {},
		spawnCounts   = saved.spawnCounts   or {},
		respawnTimes  = saved.respawnTimes  or {},
		maxLootQty    = saved.maxLootQty    or {},
		lootTables    = saved.lootTables    or {},
		customTiers   = saved.customTiers   or nil,
		tableNames    = saved.tableNames    or {},
	}

	-- Migración automática
	self.data = migrateData(self.data)

	-- Aplicar overrides de lootTables sobre ix.loot.tables en runtime
	for key, tbl in pairs(self.data.lootTables) do
		if (istable(tbl)) then
			ix.loot.tables[key] = tbl
		end
	end

	-- Spawnear props de loot para cada área configurada
	timer.Simple(1, function()
		for areaName, _ in pairs(self.data.spawnPoints) do
			spawnLootForArea(areaName)
		end
	end)
end

-- ── Limpieza al desconectar ───────────────────────────────────

function PLUGIN:PlayerDisconnected(client)
	PLUGIN.showingPlayers[client] = nil
	local ent = PLUGIN.activeSearches[client]
	if (IsValid(ent)) then
		ent.searchingPlayer = nil
	end
	client:StopSound(SEARCH_SOUND)
	client:SetAction(false)
	PLUGIN.activeSearches[client] = nil
end

-- ── Receptores de red ─────────────────────────────────────────

net.Receive("ixLootAdminSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local plugin  = ix.plugin.Get("loot")
	if (!plugin) then return end

	local incoming = ix.loot.ReadCompressed()
	if (!istable(incoming)) then return end

	-- Presets (modelos + tiers)
	if (istable(incoming.presets)) then
		plugin.data.presets = {}
		for name, preset in pairs(incoming.presets) do
			if (istable(preset) and istable(preset.models)) then
				local newPreset = { models = preset.models, tiers = {} }
				if (istable(preset.tiers)) then
					for _, tierEntry in ipairs(preset.tiers) do
						if (istable(tierEntry) and tierEntry.id) then
							newPreset.tiers[#newPreset.tiers + 1] = {
								id = tostring(tierEntry.id),
								weight = tonumber(tierEntry.weight) or 100,
							}
						end
					end
				end
				plugin.data.presets[tostring(name)] = newPreset
			end
		end
	end

	if (istable(incoming.areaPresets)) then
		plugin.data.areaPresets = {}
		for area, preset in pairs(incoming.areaPresets) do
			plugin.data.areaPresets[tostring(area)] = tostring(preset)
		end
	end

	-- areaTiers (formato nuevo: lista de {id, weight})
	if (istable(incoming.areaTiers)) then
		plugin.data.areaTiers = {}
		for area, tiers in pairs(incoming.areaTiers) do
			if (istable(tiers)) then
				local cleaned = {}
				for _, entry in ipairs(tiers) do
					if (istable(entry) and entry.id) then
						cleaned[#cleaned + 1] = {
							id = tostring(entry.id),
							weight = tonumber(entry.weight) or 100,
						}
					end
				end
				-- Validar que el total de pesos no supere 100
				if (#cleaned > 0) then
					local wTotal = 0
					for _, e in ipairs(cleaned) do
						wTotal = wTotal + e.weight
					end
					if (wTotal > 100) then
						local scale = 100 / wTotal
						for _, e in ipairs(cleaned) do
							e.weight = math.max(1, math.floor(e.weight * scale))
						end
					end
					plugin.data.areaTiers[tostring(area)] = cleaned
				end
			end
		end
	end

	if (istable(incoming.spawnCounts)) then
		plugin.data.spawnCounts = {}
		for area, count in pairs(incoming.spawnCounts) do
			local n = tonumber(count)
			if (n and n >= 1) then
				plugin.data.spawnCounts[tostring(area)] = math.floor(n)
			end
		end
	end

	if (istable(incoming.respawnTimes)) then
		plugin.data.respawnTimes = {}
		for area, t in pairs(incoming.respawnTimes) do
			local n = tonumber(t)
			if (n and n >= 1) then
				plugin.data.respawnTimes[tostring(area)] = math.floor(n)
			end
		end
	end

	if (istable(incoming.maxLootQty)) then
		plugin.data.maxLootQty = {}
		for area, q in pairs(incoming.maxLootQty) do
			local n = tonumber(q)
			if (n and n >= 0) then
				plugin.data.maxLootQty[tostring(area)] = math.floor(n)
			end
		end
	end

	if (istable(incoming.lootTables)) then
		plugin.data.lootTables = {}
		for key, tbl in pairs(incoming.lootTables) do
			if (istable(tbl)) then
				plugin.data.lootTables[tostring(key)] = tbl
				ix.loot.tables[tostring(key)] = tbl
			end
		end
	end

	-- Table Names
	if (istable(incoming.tableNames)) then
		plugin.data.tableNames = {}
		for key, name in pairs(incoming.tableNames) do
			if (isstring(name) and name != "") then
				plugin.data.tableNames[tostring(key)] = name
			end
		end
	end

	-- Custom Tiers
	if (istable(incoming.customTiers)) then
		plugin.data.customTiers = {}
		for tierID, def in pairs(incoming.customTiers) do
			if (istable(def)) then
				local cleanTier = {
					name    = tostring(def.name or tierID),
					color   = {
						tonumber(def.color and def.color[1]) or 160,
						tonumber(def.color and def.color[2]) or 160,
						tonumber(def.color and def.color[3]) or 160,
					},
					order   = tonumber(def.order) or 99,
					chances = {},
				}
				if (istable(def.chances)) then
					for _, ch in ipairs(def.chances) do
						if (istable(ch) and tonumber(ch[1]) and ch[2]) then
							cleanTier.chances[#cleanTier.chances + 1] = {
								tonumber(ch[1]),
								tostring(ch[2]),
							}
						end
					end
				end
				-- Validar que el total de chances no supere 100
				local chTotal = 0
				for _, ch in ipairs(cleanTier.chances) do
					chTotal = chTotal + ch[1]
				end
				if (chTotal > 100 and #cleanTier.chances > 0) then
					local scale = 100 / chTotal
					for _, ch in ipairs(cleanTier.chances) do
						ch[1] = math.max(1, math.floor(ch[1] * scale))
					end
				end

				plugin.data.customTiers[tostring(tierID)] = cleanTier
			end
		end
	end

	plugin:SaveData()

	-- Respawnear loot
	for _, ent in ipairs(ents.FindByClass("ix_loot")) do
		if (IsValid(ent)) then ent:Remove() end
	end

	timer.Simple(0.1, function()
		for areaName, _ in pairs(plugin.data.spawnPoints) do
			spawnLootForArea(areaName)
		end
	end)

	-- Sincronizar tiers a todos los clientes conectados
	net.Start("ixLootTierSync")
		ix.loot.WriteCompressed(plugin.data.customTiers or {})
	net.Broadcast()

	client:ChatPrint("[Loot] Datos guardados. Props respawneados.")
end)

net.Receive("ixLootSearchCancel", function(len, client)
	if (!IsValid(client)) then return end
	local plugin = ix.plugin.Get("loot")
	local ent    = plugin and plugin.activeSearches[client]
	if (IsValid(ent)) then
		ent.searchingPlayer = nil
	end
	client:StopSound(SEARCH_SOUND)
	net.Start("ixLootSearchSnd")
		net.WriteBool(false)
	net.Send(client)
	if (plugin) then plugin.activeSearches[client] = nil end
	client:SetAction(false)
	net.Start("ixLootSearchCancel")
	net.Send(client)
end)

net.Receive("ixLootAreaCreate", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local name = net.ReadString()
	local vMin = net.ReadVector()
	local vMax = net.ReadVector()

	if (name == "" or !name) then
		client:ChatPrint("[Loot] Nombre de área inválido.")
		return
	end

	if (ix.area.stored and ix.area.stored[name]) then
		client:ChatPrint("[Loot] Ya existe un área con ese nombre.")
		return
	end

	ix.area.Create(name, "loot_zone", vMin, vMax, false, { color = Color(255, 165, 0), display = false })

	local plugin = ix.plugin.Get("loot")
	if (plugin) then
		plugin.data.spawnPoints = plugin.data.spawnPoints or {}
		plugin.data.spawnPoints[name] = plugin.data.spawnPoints[name] or {}
		plugin:SaveData()
	end

	client:ChatPrint("[Loot] Zona de loot '" .. name .. "' creada.")
end)
