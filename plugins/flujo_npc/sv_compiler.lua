-- Compila un grafo lineal validado a la forma de misión de ix.missions.

function ix.flujo.Compile(graph)
	local byType = {}
	for id, node in pairs(graph.nodes) do
		byType[node.type] = node.data or {}
	end

	local dialogo = byType.dialogo
	local mision = byType.mision
	local recompensa = byType.recompensa

	local traderName = ix.traders and ix.traders.names and ix.traders.names[graph.traderKey] or graph.traderKey

	local steps = {}
	for i, step in ipairs(mision.steps) do
		steps[i] = {
			type = step.type,
			npcGroup = step.npcGroup,
			itemID = step.itemID,
			fir = step.type == "deliver" or nil,
			count = step.count
		}
	end

	return {
		id = graph.missionId or ("f_" .. graph.id),
		name = mision.name,
		description = mision.description or "",
		dialogue = dialogo.text,
		factions = {graph.traderKey},
		traderKey = graph.traderKey,
		traderName = traderName,
		adminName = "Flujo",
		allowedFactions = {},
		repeatMode = "once",
		cooldown = 0,
		isDaily = false,
		requires = {},
		steps = steps,
		rewardOptions = {{rublos = recompensa.rublos or 0, rep = recompensa.rep or 0, items = {}}}
	}
end
