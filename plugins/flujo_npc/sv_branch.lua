-- Grafos ramificados en servidor (fase 4): compilación, requisitos y recorrido del diálogo.
-- El estado del diálogo vive en memoria del servidor (por personaje y grafo).

ix.flujo.sessions = ix.flujo.sessions or {}

-- Compila cada nodo "mision" a una misión de ix.missions. Su recompensa es el nodo que le sigue.
function ix.flujo.CompileBranch(graph)
	local missions = {}

	for id, node in pairs(graph.nodes) do
		if (node.type == "mision") then
			local data = node.data or {}
			local reward = graph.nodes[ix.flujo.Successor(graph, id)]
			local rdata = reward and reward.data or {}

			local steps = {}
			for i, step in ipairs(data.steps) do
				steps[i] = {
					type = step.type,
					npcGroup = step.npcGroup,
					itemID = step.itemID,
					fir = step.type == "deliver" or nil,
					count = step.count
				}
			end

			missions[#missions + 1] = {
				id = "f_" .. graph.id .. "_" .. id,
				name = data.name,
				description = data.description or "",
				dialogue = data.dialogue or "",
				factions = {graph.traderKey},
				traderKey = graph.traderKey,
				traderName = ix.traders and ix.traders.names and ix.traders.names[graph.traderKey] or graph.traderKey,
				adminName = "Flujo",
				allowedFactions = {},
				repeatMode = "once",
				cooldown = 0,
				isDaily = false,
				requires = {},
				steps = steps,
				rewardOptions = {{rublos = rdata.rublos or 0, rep = rdata.rep or 0, items = {}}}
			}
		end
	end

	return missions
end

-- Cuántos objetos de un tipo lleva el PMC: inventario principal y dentro de las mochilas y chalecos.
function ix.flujo.CountItem(character, itemID)
	local total = 0

	local function walk(inv)
		for _, item in pairs(inv:GetItems()) do
			if (item.uniqueID == itemID) then
				total = total + (item.GetQuantity and item:GetQuantity() or 1)
			end

			local bag = item.GetInventory and item:GetInventory()
			if (bag) then walk(bag) end
		end
	end

	local inv = character:GetInventory()
	if (inv) then walk(inv) end

	return total
end

-- Evalúa un requisito. Devuelve true si se cumple.
function ix.flujo.CheckRequirement(character, graph, data)
	local kind, value = data.kind, data.value

	if (kind == "level") then
		return (character:GetEFGLevel() or 1) >= value
	elseif (kind == "rep") then
		return ix.traders.GetEffectiveRep(character, graph.traderKey) >= value
	elseif (kind == "loyalty") then
		local lvl = ix.traders.GetRepLevel(ix.traders.GetEffectiveRep(character, graph.traderKey))
		local idx = 1
		for i, entry in ipairs(ix.traders.repLevels) do
			if (entry == lvl) then idx = i end
		end
		return idx >= value
	elseif (kind == "mission") then
		return (character:GetMissionRecord() or {})[value] != nil
	elseif (kind == "item") then
		return ix.flujo.CountItem(character, data.itemID) >= (data.count or 1)
	end

	return false
end

-- Avanza solo por los nodos que no hablan (inicio, misión, recompensa, requisito).
-- Se para en diálogo, respuesta o fin.
local function settle(character, graph, nodeID)
	for _ = 1, ix.flujo.MAX_NODES + 1 do
		if (!nodeID) then return nil, "Camino sin salida." end

		local node = graph.nodes[nodeID]
		if (node.type == "dialogo" or node.type == "respuesta" or node.type == "fin") then
			return nodeID
		elseif (node.type == "requisito") then
			local passed = ix.flujo.CheckRequirement(character, graph, node.data or {})
			nodeID = ix.flujo.Successor(graph, nodeID, passed and "si" or "no")
		else
			nodeID = ix.flujo.Successor(graph, nodeID)
		end
	end

	return nil, "Bucle en el grafo."
end

-- Lo que el jugador ve en un nodo que habla.
local function payloadFor(graph, nodeID)
	local node = graph.nodes[nodeID]
	local out = {node = nodeID, type = node.type, text = "", options = {}}

	if (node.type == "dialogo") then
		out.text = node.data.text or ""
		out.options = {"Continuar"}
	elseif (node.type == "respuesta") then
		out.text = node.data.text or ""
		for i, opt in ipairs(node.data.options or {}) do out.options[i] = opt.text end
	end

	return out
end

local function keyFor(character)
	return tostring(character:GetID())
end

-- Empieza el diálogo del grafo para el personaje. Devuelve el primer nodo que habla.
function ix.flujo.Start(character, graphID)
	local graph = ix.flujo.graphs[graphID]
	if (!graph) then return nil, "No existe el grafo " .. tostring(graphID) .. "." end

	local start = nil
	for id, node in pairs(graph.nodes) do
		if (node.type == "inicio") then start = id end
	end
	if (!start) then return nil, "El grafo no tiene Inicio." end

	local landed, msg = settle(character, graph, ix.flujo.Successor(graph, start))
	if (!landed) then return nil, msg end

	ix.flujo.sessions[keyFor(character)] = {graphID = graphID, nodeID = landed}
	if (graph.nodes[landed].type == "fin") then
		ix.flujo.sessions[keyFor(character)] = nil
		return {node = landed, type = "fin", text = "", options = {}}
	end

	return payloadFor(graph, landed)
end

-- Avanza el diálogo activo. choice = número de opción (respuesta) o nil (diálogo "Continuar").
function ix.flujo.Advance(character, choice)
	local sess = ix.flujo.sessions[keyFor(character)]
	if (!sess) then return nil, "No hay un diálogo activo." end

	local graph = ix.flujo.graphs[sess.graphID]
	if (!graph) then return nil, "El grafo ya no existe." end

	local node = graph.nodes[sess.nodeID]
	local nextID

	if (node.type == "respuesta") then
		if (!isnumber(choice)) then return nil, "Elige una opción." end
		nextID = ix.flujo.Successor(graph, sess.nodeID, choice)
	elseif (node.type == "dialogo") then
		nextID = ix.flujo.Successor(graph, sess.nodeID)
	else
		return nil, "Este nodo no espera respuesta."
	end

	if (!nextID) then return nil, "Opción no válida." end

	local landed, msg = settle(character, graph, nextID)
	if (!landed) then
		ix.flujo.sessions[keyFor(character)] = nil
		return nil, msg
	end

	if (graph.nodes[landed].type == "fin") then
		ix.flujo.sessions[keyFor(character)] = nil
		return {node = landed, type = "fin", text = "", options = {}}
	end

	sess.nodeID = landed
	return payloadFor(graph, landed)
end

function ix.flujo.EndSession(character)
	ix.flujo.sessions[keyFor(character)] = nil
end

-- Texto plano de un nodo, para el chat de prueba.
function ix.flujo.DescribePayload(payload)
	if (payload.type == "fin") then return "[Fin del diálogo]" end

	local parts = {}
	for i, opt in ipairs(payload.options or {}) do parts[#parts + 1] = i .. ") " .. opt end
	return payload.text .. (#parts > 0 and (" | " .. table.concat(parts, " ")) or "")
end
