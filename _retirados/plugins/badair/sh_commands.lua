-- Comandos de administración de radiación. Se definen en el realm compartido
-- para que el cliente tenga autocompletado; el OnRun se ejecuta en el servidor.

-- Limpia por completo la radiación de un personaje.
ix.command.Add("LimpiarRadiacion", {
	description = "Pone la radiación de un personaje a 0.",
	adminOnly = true,
	arguments = {
		ix.type.player,
	},
	OnRun = function(self, client, target)
		local char = target:GetCharacter()
		if (!char) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		char:SetRadiation(0)

		target:Notify("Un administrador ha limpiado tu radiación.")
		client:Notify("Has limpiado la radiación de " .. target:Name() .. ".")
	end
})

-- Establece manualmente la radiación de un personaje (0-800).
ix.command.Add("SetRadiacion", {
	description = "Establece la radiación de un personaje a un valor concreto (0-800).",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number,
	},
	OnRun = function(self, client, target, amount)
		local char = target:GetCharacter()
		if (!char) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		local value = math.Clamp(math.floor(amount), 0, 800)
		char:SetRadiation(value)

		target:Notify("Un administrador ha establecido tu radiación en " .. value .. ".")
		client:Notify("Has establecido la radiación de " .. target:Name() .. " en " .. value .. ".")
	end
})
