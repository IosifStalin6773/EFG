-- Importa misiones lineales de ix.missions a grafos de flujo (fase 3).
-- Solo entran las que el grafo de fase 1 puede expresar. El resto se informa con su motivo.

local PLUGIN = PLUGIN

local IMPORTABLE_STEPS = {kill = true, deliver = true}

-- Devuelve el motivo por el que una misión no se puede importar, o nil si se puede.
function ix.flujo.ImportReason(mission)
	if (!istable(mission)) then return "no es una misión." end
	if (!isstring(mission.traderKey) or mission.traderKey == "") then return "sin comerciante." end
	if (mission.isDaily) then return "es diaria." end
	if (mission.repeatMode and mission.repeatMode != "once") then return "no es de una sola vez." end
	if (istable(mission.requires) and #mission.requires > 0) then return "tiene requisitos previos." end
	if (!istable(mission.steps) or #mission.steps == 0) then return "sin objetivos." end

	for i, step in ipairs(mission.steps) do
		if (!IMPORTABLE_STEPS[step.type]) then
			return "objetivo " .. i .. " de tipo no soportado (" .. tostring(step.type) .. ")."
		end
	end

	local opts = mission.rewardOptions
	if (!istable(opts) or #opts != 1) then return "necesita exactamente una opción de recompensa." end
	if (istable(opts[1].items) and #opts[1].items > 0) then return "la recompensa lleva objetos." end
	if (!isstring(mission.dialogue) or mission.dialogue == "") then return "sin texto de diálogo." end

	return nil
end

-- Grafo lineal equivalente a la misión. Guarda missionId para que al editarlo se sobrescriba la misma.
function ix.flujo.GraphFromMission(mission)
	local steps = {}
	for i, step in ipairs(mission.steps) do
		steps[i] = {type = step.type, npcGroup = step.npcGroup, itemID = step.itemID, count = step.count}
	end

	local reward = mission.rewardOptions[1]

	return {
		id = "imp_" .. tostring(mission.id),
		missionId = mission.id,
		traderKey = mission.traderKey,
		nodes = {
			a = {type = "inicio", data = {}},
			b = {type = "dialogo", data = {text = mission.dialogue}},
			c = {type = "mision", data = {name = mission.name, description = mission.description or "", steps = steps}},
			d = {type = "recompensa", data = {rublos = reward.rublos or 0, rep = reward.rep or 0}},
			e = {type = "fin", data = {}}
		},
		edges = {{from = "a", to = "b"}, {from = "b", to = "c"}, {from = "c", to = "d"}, {from = "d", to = "e"}}
	}
end

-- Comprueba que compilar el grafo devuelve la misma misión en los campos que el grafo representa.
function ix.flujo.CheckRoundTrip(mission, graph)
	local out = ix.flujo.Compile(graph)

	if (out.id != mission.id) then return false, "cambia el id." end
	if (out.name != mission.name) then return false, "cambia el nombre." end
	if (out.description != (mission.description or "")) then return false, "cambia la descripción." end
	if (out.dialogue != mission.dialogue) then return false, "cambia el diálogo." end
	if (out.traderKey != mission.traderKey) then return false, "cambia el comerciante." end
	if (out.rewardOptions[1].rublos != (mission.rewardOptions[1].rublos or 0)) then return false, "cambia los rublos." end
	if (out.rewardOptions[1].rep != (mission.rewardOptions[1].rep or 0)) then return false, "cambia la reputación." end
	if (#out.steps != #mission.steps) then return false, "cambia el número de objetivos." end

	for i, step in ipairs(out.steps) do
		local orig = mission.steps[i]
		if (step.type != orig.type or step.npcGroup != orig.npcGroup or step.itemID != orig.itemID or step.count != orig.count) then
			return false, "cambia el objetivo " .. i .. "."
		end
	end

	return true
end

-- Qué misión ya tiene un grafo que la cubre (creado en el editor o importado antes).
local function coveredByGraph(missionID)
	for _, graph in pairs(ix.flujo.graphs) do
		if ((graph.missionId or ("f_" .. tostring(graph.id))) == missionID) then return true end
	end

	return false
end

-- Importa todas las misiones que caben. No toca ix.missions.list: el grafo se guarda aparte.
function ix.flujo.ImportMissions()
	local imported, skipped = {}, {}

	for id, mission in pairs(ix.missions.list) do
		if (!coveredByGraph(id)) then
			local reason = ix.flujo.ImportReason(mission)
			local graph

			if (!reason) then
				graph = ix.flujo.GraphFromMission(mission)
				local ok, msg = ix.flujo.Validate(graph)
				if (ok) then
					ok, msg = ix.flujo.CheckRoundTrip(mission, graph)
				end

				if (!ok) then
					reason = msg
					graph = nil
				end
			end

			if (graph) then
				ix.flujo.graphs[graph.id] = graph
				imported[#imported + 1] = tostring(id)
			else
				skipped[#skipped + 1] = {id = tostring(id), reason = reason}
			end
		end
	end

	PLUGIN:SaveData()
	return imported, skipped
end
