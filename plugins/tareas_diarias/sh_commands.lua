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
