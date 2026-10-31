-- ============================================================================
--  PMC de IA: looteo activo y extracción con botín (Documento A)
--    · Fuera de combate busca contenedores y cuerpos cercanos, va al de más
--      valor por distancia, tarda en registrarlo y se lleva lo más caro que le
--      quepa. Si efgLootPMCUpgrade está activo, cambia su arma, casco o
--      blindaje por uno más caro.
--    · Con efgLootPMCExtractValue RUB de botín o tras efgLootPMCExtractMinutes
--      va a la extracción más cercana de efg_raids y desaparece con todo.
--      Queda en data/efg/loot/pmc_extract_<fecha>.txt.
--  Los escondites (stashes) los ignora: se marcan con entity.efgLootNoAI.
-- ============================================================================

local PLUGIN = PLUGIN
local LOOT = ix.efg.loot
local AI = ix.efg.lootai

local THINK_INTERVAL = 3
local nextThink = 0

local function moveTo(npc, pos)
	npc:SetLastPosition(pos)

	if (npc.SCHEDULE_GOTO_POSITION) then
		npc:SCHEDULE_GOTO_POSITION("TASK_RUN_PATH")
	else
		npc:SetSchedule(SCHED_FORCED_GO_RUN)
	end
end

local function lootSections(entity)
	local list = {}

	for _, section in ipairs(entity.efgLoot and entity.efgLoot.sections or {}) do
		if (section.inventory and ix.item.inventories[section.inventory:GetID()] == section.inventory) then
			list[#list + 1] = section.inventory
		end
	end

	return list
end

-- Valor de lo que hay en un contenedor o cadáver
local function entityValue(entity)
	local total = 0

	for _, item in ipairs(LOOT.ItemsOf(lootSections(entity))) do
		total = total + LOOT.GetPrice(item.uniqueID, item.data)
	end

	return total
end

local function findTarget(npc, loadout)
	local pos = npc:GetPos()
	local best, bestScore

	loadout.visited = loadout.visited or {}

	for _, entity in ipairs(ents.FindInSphere(pos, AI.LOOT_RADIUS)) do
		if (entity.efgLoot and entity.efgLoot.sections and !entity.efgLootNoAI and !loadout.visited[entity]) then
			local value = entityValue(entity)

			if (value > 0) then
				local score = value / (1 + pos:Distance(entity:GetPos()) / 500)

				if (!bestScore or score > bestScore) then
					best, bestScore = entity, score
				end
			end
		end
	end

	return best
end

local function gearSlotOf(item)
	if (item.isWeapon or item.isARC9) then return "weapon" end

	local kind = ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)

	if (kind == "helmet" or kind == "armor") then
		return kind
	end
end

local function cleanData(item)
	local data = table.Copy(item.data or {})
	data.id, data.equip, data.insured, data.rot = nil, nil, nil, nil

	return data
end

-- Registra el objetivo: se queda lo mejor que le quepa
function AI.TakeLoot(npc, loadout, entity)
	local items = LOOT.ItemsOf(lootSections(entity))
	local upgrade = ix.config.Get("efgLootPMCUpgrade", true)
	local taken = {}

	table.sort(items, function(a, b)
		return LOOT.GetPrice(a.uniqueID, a.data) > LOOT.GetPrice(b.uniqueID, b.data)
	end)

	local backpackFree = AI.BackpackCells(loadout) - AI.UsedCells(loadout.lists.backpack)
	local pocketFree = AI.POCKET_CELLS - AI.UsedCells(loadout.lists.pockets)

	for _, item in ipairs(items) do
		local price = LOOT.GetPrice(item.uniqueID, item.data)

		-- las mochilas y chalecos con contenido no se los lleva
		if (price > 0 and !item:GetData("id")) then
			local slot = upgrade and gearSlotOf(item)
			local current = slot and loadout.gear[slot]
			local entry = {uniqueID = item.uniqueID, data = cleanData(item)}
			local cells = (item.width or 1) * (item.height or 1)

			if (slot and (!current or price > LOOT.GetPrice(current.uniqueID, current.data))) then
				-- cambio de equipo: lo viejo va a la mochila si cabe
				if (current and AI.UsedCells({current}) <= backpackFree) then
					table.insert(loadout.lists.backpack, current)
					backpackFree = backpackFree - AI.UsedCells({current})
				end

				loadout.gear[slot] = entry
				taken[#taken + 1] = entry
				item:Remove()

				local npcClass = slot == "weapon" and AI.NPCWeapons[entry.uniqueID]

				if (npcClass and (weapons.GetStored(npcClass) or list.Get("Weapon")[npcClass])) then
					npc:Give(npcClass)
					npc:SelectWeapon(npcClass)
				end
			elseif (cells == 1 and pocketFree >= 1) then
				table.insert(loadout.lists.pockets, entry)
				pocketFree = pocketFree - 1
				taken[#taken + 1] = entry
				item:Remove()
			elseif (cells <= backpackFree) then
				table.insert(loadout.lists.backpack, entry)
				backpackFree = backpackFree - cells
				taken[#taken + 1] = entry
				item:Remove()
			end
		end
	end

	if (#taken > 0) then
		LOOT.Log("raid", ("raid %d · %s (nv %s) saquea %s · %s"):format(LOOT.raidSerial, npc:GetClass(), loadout.level or "?",
			entity.efgLoot and entity.efgLoot.kind or entity:GetClass(), LOOT.Describe(taken)))
	end
end

-- Extracción más cercana de efg_raids (las de PMC o sin bando)
local function nearestExtract(pos)
	local raids = ix.plugin.Get("efg_raids")
	local data = raids and raids.GetMapData and raids:GetMapData()
	local best, bestDist

	for _, extract in ipairs(data and data.extracts or {}) do
		if (extract.pos and (extract.side == nil or extract.side == "pmc" or extract.side == "all")) then
			local dist = pos:Distance(extract.pos)

			if (!bestDist or dist < bestDist) then
				best, bestDist = extract, dist
			end
		end
	end

	return best
end

function AI.Extract(npc, loadout, reason, extract)
	local minutes = math.floor((CurTime() - loadout.spawnTime) / 60)

	LOOT.Log("pmc_extract", ("%s · %s nv %s · %s · extracción %s · %d min · valor %s RUB · equipo %s · botín %s"):format(
		game.GetMap(), npc:GetClass(), loadout.level or "?", reason, extract and extract.name or "(sin punto)", minutes,
		string.Comma(AI.Value(loadout)), AI.DescribeGear(loadout), LOOT.Describe(AI.AllLoot(loadout))))

	AI.pmcs[npc] = nil
	npc:Remove()
end

local function think(npc, loadout)
	-- el combate manda: se olvida del loot mientras tenga enemigo
	if (IsValid(npc:GetEnemy())) then
		if (loadout.state == "loot") then
			loadout.state, loadout.target = nil, nil
		end

		return
	end

	local now = CurTime()

	if (loadout.state != "extract") then
		local value = AI.Value(loadout)
		local byValue = value >= ix.config.Get("efgLootPMCExtractValue", 250000)
		local byTime = now - loadout.spawnTime >= ix.config.Get("efgLootPMCExtractMinutes", 25) * 60

		if (byValue or byTime) then
			loadout.state = "extract"
			loadout.reason = byValue and "valor" or "tiempo"
			loadout.extract = nearestExtract(npc:GetPos())

			if (!loadout.extract) then
				AI.Extract(npc, loadout, loadout.reason)
				return
			end
		end
	end

	if (loadout.state == "extract") then
		local extract = loadout.extract

		if (npc:GetPos():Distance(extract.pos) <= (tonumber(extract.radius) or AI.EXTRACT_RADIUS)) then
			AI.Extract(npc, loadout, loadout.reason, extract)
		else
			moveTo(npc, extract.pos)
		end

		return
	end

	if (loadout.state == "loot") then
		local target = loadout.target

		if (!IsValid(target) or now - loadout.stateTime > AI.LOOT_GIVEUP) then
			if (IsValid(target)) then loadout.visited[target] = true end

			loadout.state, loadout.target, loadout.searchUntil = nil, nil, nil
			return
		end

		if (npc:GetPos():Distance(target:GetPos()) > AI.LOOT_REACH) then
			moveTo(npc, target:GetPos())
			return
		end

		-- registrar lleva el mismo tiempo que a un jugador
		if (!loadout.searchUntil) then
			local count = #LOOT.ItemsOf(lootSections(target))
			loadout.searchUntil = now + ix.config.Get("efgSearchBase", 1.5) + count * ix.config.Get("efgSearchPerItem", 0.35)
			npc:StopMoving()
			return
		end

		if (now >= loadout.searchUntil) then
			AI.TakeLoot(npc, loadout, target)
			loadout.visited[target] = true
			loadout.state, loadout.target, loadout.searchUntil = nil, nil, nil
		end

		return
	end

	local target = findTarget(npc, loadout)

	if (target) then
		loadout.state, loadout.target, loadout.stateTime = "loot", target, now
		moveTo(npc, target:GetPos())
	end
end

function PLUGIN:Think()
	if (nextThink > CurTime()) then return end
	nextThink = CurTime() + THINK_INTERVAL

	for npc in pairs(AI.pmcs) do
		if (!IsValid(npc) or npc:Health() <= 0 or !npc.efgLoot) then
			AI.pmcs[npc] = nil
		else
			think(npc, npc.efgLoot)
		end
	end
end
