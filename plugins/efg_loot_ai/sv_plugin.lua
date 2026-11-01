-- ============================================================================
--  Equipo y botín de la IA (Documento A)
--    · Al aparecer: equipo (fijo por perfil o por nivel en los PMC) y botín
--      repartido por contenedor (bolsillos, chaleco, mochila, cuerpo). Solo
--      son datos: los objetos se crean al morir, en el cadáver.
--    · Al morir: VJ Base crea el cadáver y llama a OnCreateDeathCorpse; ahí se
--      crean los inventarios. Si no hay cadáver de VJ, se crea uno.
-- ============================================================================

local PLUGIN = PLUGIN
local LOOT = ix.efg.loot
local AI = ix.efg.lootai

AI.pmcs = AI.pmcs or {}

local function pickWeighted(list)
	local total = 0

	for _, entry in ipairs(list or {}) do
		if (entry[1] == false or ix.item.list[entry[1]]) then
			total = total + entry[2]
		end
	end

	if (total <= 0) then return end

	local roll = math.random() * total

	for _, entry in ipairs(list) do
		if (entry[1] == false or ix.item.list[entry[1]]) then
			roll = roll - entry[2]

			if (roll <= 0) then
				return entry[1] or nil
			end
		end
	end
end

function AI.ProfileFor(zoneKey, zoneType, bBoss)
	if (bBoss) then return "boss" end

	-- efg_ai pasa la clave de la zona; su tabla está en efg_ai.zoneTypes
	if (isstring(zoneType)) then
		local efgAI = ix.plugin.Get("efg_ai")
		zoneType = efgAI and efgAI.zoneTypes and efgAI.zoneTypes[zoneType]
	end

	return AI.ZoneProfiles[zoneKey] or ((zoneType and zoneType.isScav) and "scav" or "pmc")
end

-- Nivel del jugador en raid más cercano (Documento A: el bot va de su nivel
-- a +10)
local function nearestRaiderLevel(pos)
	local best, bestDist

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and client.InRaid and client:InRaid()) then
			local dist = client:GetPos():DistToSqr(pos)

			if (!bestDist or dist < bestDist) then
				best, bestDist = character, dist
			end
		end
	end

	return best and best.GetEFGLevel and best:GetEFGLevel() or 1
end

local function tierFor(tiers, level)
	local chosen = tiers[1]

	for _, tier in ipairs(tiers) do
		if (level >= tier.minLevel) then
			chosen = tier
		end
	end

	return chosen
end

local function cellsOf(uniqueID)
	local stock = ix.item.list[uniqueID]
	return stock and (stock.width or 1) * (stock.height or 1) or 1
end

-- Casillas de la mochila según el objeto de su ranura
function AI.BackpackCells(loadout)
	local backpack = loadout.gear.backpack
	local stock = backpack and ix.item.list[backpack.uniqueID]

	return stock and (stock.invWidth or 4) * (stock.invHeight or 4) or 0
end

function AI.UsedCells(list)
	local used = 0

	for _, entry in ipairs(list) do
		used = used + cellsOf(entry.uniqueID)
	end

	return used
end

-- Valor de todo lo que lleva (equipo y botín), en RUB
function AI.Value(loadout)
	local total = 0

	for _, entry in pairs(loadout.gear) do
		total = total + LOOT.GetPrice(entry.uniqueID, entry.data)
	end

	for _, list in pairs(loadout.lists) do
		total = total + LOOT.ValueOf(list)
	end

	return total
end

-- Quita lo que no cabe en la capacidad de la mochila
local function trimToCells(list, cells)
	local kept, used = {}, 0

	for _, entry in ipairs(list) do
		local size = cellsOf(entry.uniqueID)

		if (used + size <= cells) then
			kept[#kept + 1] = entry
			used = used + size
		end
	end

	return kept
end

-- levelOverride: nivel fijo para las pruebas (/LootTestPMC)
function AI.BuildLoadout(npc, profileID, levelOverride)
	local profile = AI.Profiles[profileID]
	if (!profile) then return end

	local loadout = {
		profile = profileID,
		kind = profile.looter and "pmc" or (profileID == "scav" and "scav" or profileID),
		nameKey = profile.nameKey,
		spawnTime = CurTime(),
		gear = {},
		lists = {}
	}

	local gearTable = profile.gear

	if (profile.tiers) then
		local level

		if (levelOverride) then
			level = math.Clamp(levelOverride, 1, 79)
		else
			local base = nearestRaiderLevel(npc:GetPos())
			local offset = profile.level or {0, 0}
			level = math.Clamp(base + math.random(offset[1], offset[2]), profile.minLevel or 1, 79)
		end

		loadout.level = level
		gearTable = tierFor(profile.tiers, level)
	end

	for _, slot in ipairs({"weapon", "helmet", "armor", "rig", "backpack"}) do
		local uniqueID = gearTable and pickWeighted(gearTable[slot])

		if (uniqueID) then
			loadout.gear[slot] = {uniqueID = uniqueID, data = {}}
		end
	end

	loadout.lists.pockets = profile.pockets and LOOT.Roll(profile.pockets) or {}
	loadout.lists.vest = (profile.vest and loadout.gear.rig) and LOOT.Roll(profile.vest) or {}
	loadout.lists.body = profile.body and LOOT.Roll(profile.body) or {}

	if (profile.backpack and loadout.gear.backpack) then
		loadout.lists.backpack = trimToCells(LOOT.Roll(profile.backpack), AI.BackpackCells(loadout))
	else
		loadout.lists.backpack = {}
	end

	-- Documento A: un objeto raro posible por Scav
	if (profile.rare and math.random(100) <= ix.config.Get("efgLootScavRareChance", 20)) then
		local rare = LOOT.Roll("scav_rare", {rolls = 1})[1]

		if (rare) then
			local target = cellsOf(rare.uniqueID) == 1 and loadout.lists.pockets
				or (#loadout.lists.body > 0 and loadout.lists.body) or loadout.lists.backpack

			table.insert(target, rare)
			loadout.rare = rare.uniqueID
		end
	end

	return loadout
end

-- ─── Aparición ──────────────────────────────────────────────────────────────
function PLUGIN:EFGAISpawned(npc, zoneType, bBoss)
	if (!IsValid(npc)) then return end

	local profileID = AI.ProfileFor(npc.efgAIType, zoneType, bBoss)
	local loadout = AI.BuildLoadout(npc, profileID)
	if (!loadout) then return end

	npc.efgLoot = loadout

	-- el arma la deja el cadáver como objeto; VJ no debe soltar la suya, y el
	-- cuerpo no debe desvanecerse con el botín dentro
	npc.DropWeaponOnDeath = false
	npc.DeathCorpseFade = false

	-- el PMC lleva el arma de su equipo si hay versión de VJ; el Scav deja
	-- como objeto el arma de VJ que le haya dado efg_ai
	local weapon = loadout.gear.weapon
	local npcClass = weapon and AI.NPCWeapons[weapon.uniqueID]

	if (npcClass and (weapons.GetStored(npcClass) or list.Get("Weapon")[npcClass])) then
		npc:Give(npcClass)
	end

	timer.Simple(0.5, function()
		if (!IsValid(npc) or loadout.gear.weapon) then return end

		local active = npc:GetActiveWeapon()
		local itemID = IsValid(active) and AI.WeaponItems[active:GetClass()]

		if (itemID and ix.item.list[itemID]) then
			loadout.gear.weapon = {uniqueID = itemID, data = {}}
		end
	end)

	-- VJ llama a este método al crear el cadáver
	local original = npc.OnCreateDeathCorpse

	npc.OnCreateDeathCorpse = function(this, dmginfo, hitgroup, corpse)
		if (original) then
			original(this, dmginfo, hitgroup, corpse)
		end

		AI.BuildCorpse(this, corpse)
	end

	if (loadout.kind == "pmc") then
		AI.pmcs[npc] = true
	end

	LOOT.Log("raid", ("raid %d · aparece %s (%s%s) · equipo %s · botín %s · valor %s RUB"):format(LOOT.raidSerial,
		npc:GetClass(), profileID, loadout.level and (" nv " .. loadout.level) or "",
		AI.DescribeGear(loadout), LOOT.Describe(AI.AllLoot(loadout)), string.Comma(AI.Value(loadout))))
end

-- NPC puestos a mano (menú Q, npc_presets...) sin zona de efg_ai: se busca su
-- clase en las zonas de efg_ai y, si no está, se deduce por el nombre.
local function classProfile(class)
	local efgAI = ix.plugin.Get("efg_ai")

	for key, zoneType in pairs(efgAI and efgAI.zoneTypes or {}) do
		if (zoneType.boss == class) then
			return key, true
		end

		if (table.HasValue(zoneType.classes or {}, class)) then
			return key, false
		end
	end

	if (class:find("scav", 1, true)) then return "scav", false end
	if (class:find("pmc", 1, true) or class:find("usec", 1, true) or class:find("bear", 1, true)) then return "pmc", false end
end

function PLUGIN:OnEntityCreated(entity)
	if (!IsValid(entity) or !entity:IsNPC()) then return end

	timer.Simple(0, function()
		if (!IsValid(entity) or entity.efgLoot or !entity.IsVJBaseSNPC) then return end

		local key, bBoss = classProfile(entity:GetClass())
		if (!key) then return end

		entity.efgAIType = entity.efgAIType or key
		self:EFGAISpawned(entity, key, bBoss)
	end)
end

function AI.DescribeGear(loadout)
	local parts = {}

	for _, slot in ipairs({"weapon", "helmet", "armor", "rig", "backpack"}) do
		if (loadout.gear[slot]) then
			parts[#parts + 1] = loadout.gear[slot].uniqueID
		end
	end

	return #parts > 0 and table.concat(parts, ", ") or "(nada)"
end

function AI.AllLoot(loadout)
	local all = {}

	for _, name in ipairs({"pockets", "vest", "backpack", "body"}) do
		for _, entry in ipairs(loadout.lists[name] or {}) do
			all[#all + 1] = entry
		end
	end

	return all
end

-- ─── Cadáver ────────────────────────────────────────────────────────────────
local warnedFade = false

local function warnFade()
	if (warnedFade) then return end

	local fade = GetConVar("vj_npc_corpse_fade")

	if (fade and fade:GetInt() == 1) then
		warnedFade = true
		MsgC(Color(230, 120, 60), "[EFG Loot] vj_npc_corpse_fade = 1: los cadáveres de IA desaparecen con su botín. Pon vj_npc_corpse_fade 0.\n")
	end
end

function AI.BuildCorpse(npc, corpse)
	local loadout = npc.efgLoot
	if (!loadout or loadout.corpseDone or !IsValid(corpse)) then return end

	loadout.corpseDone = true
	warnFade()

	-- VJ deja el cuerpo como escombro (COLLISION_GROUP_DEBRIS): con WEAPON se
	-- sigue atravesando pero el +use y las trazas lo encuentran
	corpse:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	local equip = LOOT.NewInventory(LOOT.CORPSE_EQUIP_W, LOOT.CORPSE_EQUIP_H)
	local pockets = LOOT.NewInventory(AI.POCKET_CELLS, 1)

	corpse.efgLoot = {
		kind = loadout.kind,
		nameKey = loadout.nameKey,
		serial = LOOT.raidSerial,
		sections = {
			{id = "equip", labelKey = "efgLootSectionEquip", inventory = equip},
			{id = "pockets", labelKey = "efgLootSectionPockets", inventory = pockets, single = true}
		}
	}

	-- Documento B: el Scav tiene un contenedor genérico 4x4 ("Dead Scav")
	if (#(loadout.lists.body or {}) > 0 or loadout.kind == "scav") then
		local body = LOOT.NewInventory(4, 4)

		LOOT.Fill(body, loadout.lists.body)
		table.insert(corpse.efgLoot.sections, 1, {id = "body", labelKey = "efgLootSectionBody", inventory = body})
	end

	LOOT.Fill(pockets, loadout.lists.pockets)

	local contents = {rig = loadout.lists.vest, backpack = loadout.lists.backpack}

	for _, slot in ipairs({"weapon", "helmet", "armor", "rig", "backpack"}) do
		local entry = loadout.gear[slot]

		if (entry) then
			LOOT.AddItem(equip, entry.uniqueID, entry.data, function(item)
				if (!contents[slot] or #contents[slot] == 0) then return end

				LOOT.WhenContainerReady(item, function(inventory)
					LOOT.Fill(inventory, contents[slot])

					if (IsValid(corpse) and corpse.efgLoot) then
						table.insert(corpse.efgLoot.sections, {
							id = "bag_" .. item.id,
							label = item:GetName(),
							inventory = inventory,
							nested = true,
							parentItem = item.id,
							parentInventory = equip:GetID()
						})
					end
				end)
			end)
		end
	end

	corpse:CallOnRemove("efgLoot", function(ragdoll)
		LOOT.ClearEntity(ragdoll)
	end)
end

-- Sin cadáver de VJ (otra base de NPC, gibs, OnCreateDeathCorpse pisado):
-- se usa self.Corpse si existe o se crea un ragdoll con su modelo.
function PLUGIN:OnNPCKilled(npc)
	local loadout = npc.efgLoot
	if (!loadout) then return end

	AI.pmcs[npc] = nil

	local pos, ang, model = npc:GetPos(), npc:GetAngles(), npc:GetModel()
	local delay = (tonumber(npc.DeathDelayTime) or 0) + 6

	timer.Simple(delay, function()
		if (loadout.corpseDone) then return end

		local corpse = IsValid(npc) and IsValid(npc.Corpse) and npc.Corpse

		if (!corpse) then
			corpse = ents.Create("prop_ragdoll")
			if (!IsValid(corpse)) then return end

			corpse:SetModel(model)
			corpse:SetPos(pos)
			corpse:SetAngles(ang)
			corpse:Spawn()
		end

		AI.BuildCorpse({efgLoot = loadout}, corpse)
	end)
end
