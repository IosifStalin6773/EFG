-- Grafos ramificados (fase 4): respuesta y requisito. Validación compartida.
-- Un grafo es ramificado si tiene algún nodo "respuesta" o "requisito".
-- Las aristas llevan label: en "respuesta" es el número de opción (1..n),
-- en "requisito" es "si" o "no".

ix.flujo.MAX_OPTIONS = 4
ix.flujo.MAX_NODES   = 64
ix.flujo.reqKinds    = {"level", "loyalty", "rep", "mission", "item"}

ix.flujo.nodeTypes.respuesta = {name = "Respuesta"}
ix.flujo.nodeTypes.requisito = {name = "Requisito"}

function ix.flujo.IsBranching(graph)
	if (!istable(graph) or !istable(graph.nodes)) then return false end

	for _, node in pairs(graph.nodes) do
		if (node.type == "respuesta" or node.type == "requisito") then return true end
	end

	return false
end

-- Valida un grafo ramificado. Devuelve true o false, mensaje.
function ix.flujo.ValidateBranch(graph)
	if (!istable(graph.nodes)) then return false, "Grafo vacío." end
	if (!isstring(graph.traderKey) or graph.traderKey == "") then return false, "Falta el comerciante." end

	local count = 0
	local inicio, hasFin = nil, false
	for id, node in pairs(graph.nodes) do
		count = count + 1
		if (!ix.flujo.nodeTypes[node.type]) then return false, "Tipo de nodo desconocido: " .. tostring(node.type) end
		if (node.type == "inicio") then
			if (inicio) then return false, "Hay más de un nodo Inicio." end
			inicio = id
		end
		if (node.type == "fin") then hasFin = true end
	end

	if (count > ix.flujo.MAX_NODES) then return false, "El grafo supera " .. ix.flujo.MAX_NODES .. " nodos." end
	if (!inicio) then return false, "Falta el nodo Inicio." end
	if (!hasFin) then return false, "Falta un nodo Fin." end

	-- aristas por nodo
	local out = {}
	for _, e in ipairs(graph.edges or {}) do
		if (!graph.nodes[e.from] or !graph.nodes[e.to]) then return false, "Hay una conexión a un nodo que no existe." end
		out[e.from] = out[e.from] or {}
		table.insert(out[e.from], e)
	end

	for id, node in pairs(graph.nodes) do
		local edges = out[id] or {}
		local data = node.data or {}

		if (node.type == "fin") then
			if (#edges > 0) then return false, "Fin no puede tener salidas." end
		elseif (node.type == "respuesta") then
			local opts = data.options or {}
			if (#opts < 1 or #opts > ix.flujo.MAX_OPTIONS) then return false, "Una respuesta necesita entre 1 y " .. ix.flujo.MAX_OPTIONS .. " opciones." end
			if (#edges != #opts) then return false, "Cada opción de respuesta necesita una salida." end
			for i, opt in ipairs(opts) do
				if (!isstring(opt.text) or opt.text == "") then return false, "Opción " .. i .. " sin texto." end
			end
			local seen = {}
			for _, e in ipairs(edges) do
				if (!isnumber(e.label) or e.label < 1 or e.label > #opts or seen[e.label]) then return false, "Salida de respuesta no válida." end
				seen[e.label] = true
			end
		elseif (node.type == "requisito") then
			if (!table.HasValue(ix.flujo.reqKinds, data.kind)) then return false, "Requisito sin tipo válido." end
			if (data.kind == "item") then
				if (!isstring(data.itemID) or data.itemID == "") then return false, "Requisito de objeto sin objeto." end
			elseif (data.value == nil) then
				return false, "Requisito sin valor."
			end
			if (#edges != 2) then return false, "Un requisito necesita salida Sí y salida No." end
			local labels = {}
			for _, e in ipairs(edges) do labels[e.label] = true end
			if (!labels["si"] or !labels["no"]) then return false, "Un requisito necesita salida Sí y salida No." end
		else
			if (node.type != "inicio" and #edges != 1) then return false, ix.flujo.nodeTypes[node.type].name .. " necesita exactamente una salida." end
			if (node.type == "inicio" and #edges != 1) then return false, "Inicio necesita una salida." end
		end

		if (node.type == "dialogo" and (!isstring(data.text) or data.text == "")) then return false, "Un diálogo no tiene texto." end
		if (node.type == "mision") then
			if (!isstring(data.name) or data.name == "") then return false, "Una misión no tiene nombre." end
			if (!istable(data.steps) or #data.steps == 0) then return false, "Una misión no tiene objetivos." end
			for i, step in ipairs(data.steps) do
				if (!table.HasValue(ix.flujo.stepTypes, step.type)) then return false, "Objetivo " .. i .. ": tipo no válido." end
				if (!isnumber(step.count) or step.count < 1) then return false, "Objetivo " .. i .. ": cantidad no válida." end
			end
			-- una misión siempre va seguida de su recompensa
			local nextEdge = edges[1]
			if (!nextEdge or graph.nodes[nextEdge.to].type != "recompensa") then return false, "Una misión debe ir seguida de una recompensa." end
		end
		if (node.type == "recompensa" and ((data.rublos or 0) < 0 or (data.rep or 0) < 0)) then return false, "La recompensa no puede ser negativa." end
	end

	-- alcanzables desde Inicio y sin ciclos
	local state = {}
	local function visit(id)
		if (state[id] == "doing") then return false, "Hay un ciclo en el grafo." end
		if (state[id] == "done") then return true end
		state[id] = "doing"
		for _, e in ipairs(out[id] or {}) do
			local ok, msg = visit(e.to)
			if (!ok) then return false, msg end
		end
		state[id] = "done"
		return true
	end

	local ok, msg = visit(inicio)
	if (!ok) then return false, msg end

	for id in pairs(graph.nodes) do
		if (!state[id]) then return false, "Hay un nodo que no se alcanza desde Inicio." end
	end

	return true
end

-- Valida cualquier grafo (lineal o ramificado) con la regla que le toca.
function ix.flujo.ValidateAny(graph)
	if (ix.flujo.IsBranching(graph)) then return ix.flujo.ValidateBranch(graph) end
	return ix.flujo.Validate(graph)
end

-- Destino de una salida de un nodo, por label (opcional).
function ix.flujo.Successor(graph, nodeID, label)
	for _, e in ipairs(graph.edges or {}) do
		if (e.from == nodeID and (label == nil or e.label == label)) then return e.to end
	end

	return nil
end
