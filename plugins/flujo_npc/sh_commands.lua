ix.command.Add("FlujoValidar", {
	description = "Valida el grafo de flujo guardado con este id.",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, graphID)
		local graph = ix.flujo.graphs[graphID]
		if (!graph) then return "No existe el grafo " .. graphID .. "." end

		local ok, msg = ix.flujo.ValidateAny(graph)
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

ix.command.Add("FlujoImportar", {
	description = "Importa las misiones lineales de los comerciantes a grafos de flujo. Las que no caben se listan en consola.",
	adminOnly = true,
	OnRun = function(self, client)
		if (!ix.flujo.ImportMissions) then return "Importación disponible solo en el servidor." end

		local imported, skipped = ix.flujo.ImportMissions()
		for _, s in ipairs(skipped) do
			MsgN("[FlujoImportar] " .. s.id .. ": " .. s.reason)
		end

		return "Importadas " .. #imported .. " misiones. Sin importar: " .. #skipped .. " (motivos en consola del servidor)."
	end
})

ix.command.Add("FlujoProbar", {
	description = "Empieza el diálogo de un grafo ramificado para probarlo en el chat.",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, graphID)
		local character = client:GetCharacter()
		if (!character or !ix.flujo.Start) then return "Sin personaje." end

		local payload, msg = ix.flujo.Start(character, graphID)
		if (!payload) then return "No se pudo: " .. tostring(msg) end
		return ix.flujo.DescribePayload(payload)
	end
})

ix.command.Add("FlujoElegir", {
	description = "Elige una opción del diálogo de prueba por número. En un diálogo, 1 continúa.",
	adminOnly = true,
	arguments = {ix.type.number},
	OnRun = function(self, client, choice)
		local character = client:GetCharacter()
		if (!character or !ix.flujo.Advance) then return "Sin personaje." end

		local payload, msg = ix.flujo.Advance(character, choice)
		if (!payload) then return "No se pudo: " .. tostring(msg) end
		return ix.flujo.DescribePayload(payload)
	end
})
