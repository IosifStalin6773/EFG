ix.command.Add("FlujoValidar", {
	description = "Valida el grafo de flujo guardado con este id.",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, graphID)
		local graph = ix.flujo.graphs[graphID]
		if (!graph) then return "No existe el grafo " .. graphID .. "." end

		local ok, msg = ix.flujo.Validate(graph)
		return ok and "Grafo válido." or ("Grafo no válido: " .. msg)
	end
})

ix.command.Add("FlujoEjemplo", {
	description = "Crea y compila un grafo lineal de ejemplo para un comerciante (pruebas).",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, traderKey)
		local id = "ej_" .. traderKey
		local graph = {
			id = id,
			traderKey = traderKey,
			nodes = {
				a = {type = "inicio", data = {}},
				b = {type = "dialogo", data = {text = "Necesito que elimines a unos Scavs."}},
				c = {type = "mision", data = {name = "Ejemplo de flujo", description = "Misión de prueba.", steps = {{type = "kill", npcGroup = "scav", count = 3}}}},
				d = {type = "recompensa", data = {rublos = 10000, rep = 10}},
				e = {type = "fin", data = {}}
			},
			edges = {{from = "a", to = "b"}, {from = "b", to = "c"}, {from = "c", to = "d"}, {from = "d", to = "e"}}
		}

		local ok, msg = ix.flujo.Save(graph)
		return ok and ("Grafo " .. id .. " compilado.") or ("No se pudo: " .. msg)
	end
})
