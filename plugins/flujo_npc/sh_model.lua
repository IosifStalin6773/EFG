-- Validación del grafo lineal (fase 1). Devuelve true o false, mensaje.

function ix.flujo.Validate(graph)
	if (!istable(graph) or !istable(graph.nodes)) then return false, "Grafo vacío." end
	if (!isstring(graph.traderKey) or graph.traderKey == "") then return false, "Falta el comerciante." end

	-- exactamente un nodo de cada tipo lineal, en el orden de ix.flujo.linearOrder
	local byType = {}
	for id, node in pairs(graph.nodes) do
		if (!ix.flujo.nodeTypes[node.type]) then return false, "Tipo de nodo desconocido: " .. tostring(node.type) end
		if (byType[node.type]) then return false, "Hay más de un nodo de tipo " .. node.type .. "." end
		byType[node.type] = {id = id, node = node}
	end

	for _, t in ipairs(ix.flujo.linearOrder) do
		if (!byType[t]) then return false, "Falta el nodo " .. ix.flujo.nodeTypes[t].name .. "." end
	end

	-- el camino debe ser exactamente lineal: una arista por cada paso
	local edgeFrom, edgeTo = {}, {}
	for _, e in ipairs(graph.edges or {}) do
		if (edgeFrom[e.from]) then return false, "Un nodo tiene más de una salida." end
		if (edgeTo[e.to]) then return false, "Un nodo tiene más de una entrada." end
		edgeFrom[e.from] = e.to
		edgeTo[e.to] = e.from
	end

	for i = 1, #ix.flujo.linearOrder - 1 do
		local a = byType[ix.flujo.linearOrder[i]].id
		local b = byType[ix.flujo.linearOrder[i + 1]].id
		if (edgeFrom[a] != b) then return false, "Falta la conexión entre " .. ix.flujo.nodeTypes[ix.flujo.linearOrder[i]].name .. " y " .. ix.flujo.nodeTypes[ix.flujo.linearOrder[i + 1]].name .. "." end
	end

	local count = 0
	for _ in pairs(edgeFrom) do count = count + 1 end
	if (count != #ix.flujo.linearOrder - 1) then return false, "Hay conexiones que no forman el camino." end

	-- datos de cada nodo
	local dialogo = byType.dialogo.node.data or {}
	if (!isstring(dialogo.text) or dialogo.text == "") then return false, "El diálogo no tiene texto." end

	local mision = byType.mision.node.data or {}
	if (!isstring(mision.name) or mision.name == "") then return false, "La misión no tiene nombre." end
	if (!istable(mision.steps) or #mision.steps == 0) then return false, "La misión no tiene objetivos." end

	for i, step in ipairs(mision.steps) do
		if (!table.HasValue(ix.flujo.stepTypes, step.type)) then return false, "Objetivo " .. i .. ": tipo no válido." end
		if (!isnumber(step.count) or step.count < 1) then return false, "Objetivo " .. i .. ": cantidad no válida." end

		if (step.type == "kill" and !table.HasValue(ix.flujo.groups, step.npcGroup)) then
			return false, "Objetivo " .. i .. ": grupo de NPC no válido."
		end

		if (step.type == "deliver" and (!isstring(step.itemID) or step.itemID == "")) then
			return false, "Objetivo " .. i .. ": falta el objeto."
		end
	end

	local recompensa = byType.recompensa.node.data or {}
	if ((recompensa.rublos or 0) < 0 or (recompensa.rep or 0) < 0) then return false, "La recompensa no puede ser negativa." end

	return true
end
