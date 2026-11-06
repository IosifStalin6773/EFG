ix.command.Add("TareasDiariasReset", {
	description = "Borra las tareas diarias de tu personaje para que los comerciantes asignen otras nuevas.",
	adminOnly = true,
	OnRun = function(self, client)
		local character = client:GetCharacter()
		if (!character) then return "Sin personaje activo." end

		character:SetTareasDiarias({})
		return "Tareas diarias reiniciadas."
	end
})

ix.command.Add("TareasDiariasAceptar", {
	description = "Acepta la tarea diaria del comerciante indicado (prapor, therapist, fence...). Para pruebas.",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, traderKey)
		local character = client:GetCharacter()
		if (!character) then return "Sin personaje activo." end

		ix.tareasDiarias.GetForTrader(character, traderKey)
		local ok, msg = ix.tareasDiarias.Accept(client, traderKey)
		return msg
	end
})

ix.command.Add("TareasDiariasEstado", {
	description = "Muestra las tareas diarias de tu personaje.",
	adminOnly = true,
	OnRun = function(self, client)
		local character = client:GetCharacter()
		if (!character) then return "Sin personaje activo." end

		local lines = {}
		for traderKey, entry in pairs(character:GetTareasDiarias() or {}) do
			local task = entry.task
			if (task) then
				lines[#lines + 1] = ("%s: %s [%s] %d/%d"):format(traderKey, task.title, task.status, task.progress or 0, task.steps[1].count)
			end
		end

		return #lines > 0 and table.concat(lines, " | ") or "Sin tareas diarias."
	end
})
