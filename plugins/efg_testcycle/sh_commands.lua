local TC = ix.efg.testcycle

local SCENARIOS = {todo = true, extract = true, death = true, mia = true, abandon = true}

ix.command.Add("EFGTestCiclo", {
	description = "Lleva un bot por el ciclo de raid y comprueba cada paso: todo, extract, death, mia o abandon.",
	superAdminOnly = true,
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, scenario)
		scenario = string.lower(scenario or "todo")

		if (!SCENARIOS[scenario]) then
			return "Escenario no válido. Usa: todo, extract, death, mia o abandon."
		end

		TC.StartTest(client, scenario)
	end
})

ix.command.Add("EFGLogCiclo", {
	description = "Vuelca en la consola los últimos eventos del ciclo de raid (de un jugador o de todos).",
	adminOnly = true,
	arguments = {bit.bor(ix.type.player, ix.type.optional), bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, target, amount)
		local lines = TC.GetLines(IsValid(target) and target or nil, math.Clamp(amount or 40, 1, 300))

		client:PrintMessage(HUD_PRINTCONSOLE, ("── Ciclo de raid: %d evento(s) ──"):format(#lines))

		for _, line in ipairs(lines) do
			client:PrintMessage(HUD_PRINTCONSOLE, line)
		end

		return #lines > 0 and "Registro volcado en la consola." or "No hay eventos registrados."
	end
})
