-- Comandos de contenedores del mundo. Los de prueba (/LootTest*, /LootDump)
-- llegan en la fase 4.

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
