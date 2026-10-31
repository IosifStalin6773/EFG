-- Comandos de contenedores del mundo y /LootDump. Los cuerpos de prueba
-- (/LootTestScav, /LootTestPMC, /LootTestPlayer) están en efg_loot_ai.

local function typeList()
	local names = {}

	for id in SortedPairs(ix.efg.loot.ContainerTypes) do
		names[#names + 1] = id
	end

	return table.concat(names, ", ")
end

ix.command.Add("LootContainerAdd", {
	description = "@cmdLootContainerAdd",
	adminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, lootType)
		local LOOT = ix.efg.loot
		lootType = string.lower(lootType)

		if (!LOOT.ContainerTypes[lootType]) then
			return "@efgLootBadType", typeList()
		end

		local trace = client:GetEyeTraceNoCursor()

		if (!trace.Hit or trace.HitPos:Distance(client:GetShootPos()) > 300) then
			return "@efgLootTooFar"
		end

		local entity = LOOT.SpawnContainer(lootType, trace.HitPos + trace.HitNormal * 4, Angle(0, client:EyeAngles().y + 180, 0))

		if (!IsValid(entity)) then
			return "@efgLootBadType", typeList()
		end

		ix.plugin.Get("efg_loot"):SaveContainers()

		return "@efgLootContainerAdded", LOOT.ContainerTypes[lootType].name
	end
})

ix.command.Add("LootContainerRemove", {
	description = "@cmdLootContainerRemove",
	adminOnly = true,
	OnRun = function(self, client)
		local LOOT = ix.efg.loot
		local best, bestDist

		for _, entity in ipairs(LOOT.GetContainers()) do
			local dist = entity:GetPos():Distance(client:GetPos())

			if (dist < 300 and (!bestDist or dist < bestDist)) then
				best, bestDist = entity, dist
			end
		end

		if (!best) then
			return "@efgLootNoContainer"
		end

		local name = best:GetLootName()
		best:Remove()

		timer.Simple(0, function()
			ix.plugin.Get("efg_loot"):SaveContainers()
		end)

		return "@efgLootContainerRemoved", name
	end
})

ix.command.Add("LootContainerList", {
	description = "@cmdLootContainerList",
	adminOnly = true,
	OnRun = function(self, client)
		local LOOT = ix.efg.loot
		local list = LOOT.GetContainers()

		client:ChatPrint(("[Loot] raid %d · %d contenedores"):format(LOOT.raidSerial, #list))

		for _, entity in ipairs(list) do
			local items = entity.efgLoot and #LOOT.ItemsOf({entity.efgLoot.sections[1].inventory}) or 0
			local pos = entity:GetPos()

			client:ChatPrint(("  #%d %s · %d objetos · %d m · (%d, %d, %d)"):format(entity:EntIndex(), entity:GetLootName(),
				items, math.floor(pos:Distance(client:GetPos()) / 52.5), pos.x, pos.y, pos.z))
		end
	end
})

-- Tira una tabla muchas veces y apunta qué sale, con qué frecuencia y cuánto
-- vale de media. Sin argumentos lista las tablas.
ix.command.Add("LootDump", {
	description = "@cmdLootDump",
	adminOnly = true,
	arguments = {bit.bor(ix.type.string, ix.type.optional), bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, tableID, rolls)
		local LOOT = ix.efg.loot

		if (!tableID or !LOOT.Tables[tableID]) then
			local names = {}

			for id in SortedPairs(LOOT.Tables) do
				names[#names + 1] = id
			end

			client:ChatPrint(table.concat(names, ", "))
			return "@efgLootDumpUsage"
		end

		rolls = math.Clamp(math.floor(rolls or 200), 1, 2000)

		local counts, totalItems, totalValue = {}, 0, 0

		for _ = 1, rolls do
			local rolled = LOOT.Roll(tableID)

			totalItems = totalItems + #rolled
			totalValue = totalValue + LOOT.ValueOf(rolled)

			for _, entry in ipairs(rolled) do
				counts[entry.uniqueID] = (counts[entry.uniqueID] or 0) + 1
			end
		end

		local list = {}

		for uniqueID, count in pairs(counts) do
			list[#list + 1] = {id = uniqueID, count = count}
		end

		table.sort(list, function(a, b) return a.count > b.count end)

		local header = ("%s · %s · %d tiradas · %.2f objetos por tirada · valor medio %s RUB · %d objetos distintos"):format(
			game.GetMap(), tableID, rolls, totalItems / rolls, string.Comma(math.Round(totalValue / rolls)), #list)

		LOOT.Log("dump", "── " .. header .. " ──")

		for _, entry in ipairs(list) do
			LOOT.Log("dump", ("  %-40s %5d  (%.1f%% de las tiradas)  %s RUB"):format(entry.id, entry.count,
				entry.count / rolls * 100, string.Comma(LOOT.GetPrice(entry.id))))
		end

		client:ChatPrint(header)

		for i = 1, math.min(10, #list) do
			client:ChatPrint(("  %s · %.1f%%"):format(list[i].id, list[i].count / rolls * 100))
		end

		return "@efgLootDumpDone", os.date("%Y-%m-%d")
	end
})

