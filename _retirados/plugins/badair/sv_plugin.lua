local PLUGIN = PLUGIN

-- Acumula radiación cada 7 segundos para jugadores en zonas tóxicas.
-- Fórmula: 0.25 + 0.75 * armorRad
--   armorRad = 0 (hazmat, protección total) → 0.25 rad/tick
--   armorRad = 1 (sin protección)           → 1.0 rad/tick
timer.Create("badairRadiation", 7, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then continue end

		local clientPos = client:GetPos() + client:OBBCenter()
		local inZone = false

		for _, vec in ipairs((ix.badair.getAll() or {})) do
			if (clientPos:WithinAABox(vec[1], vec[2])) then
				inZone = true
				break
			end
		end

		client:SetNetVar("inRadZone", inZone)

		if (inZone) then
			local armorRad = 1
			local items = char:GetInventory():GetItems()

			for _, item in pairs(items) do
				if (item.base == "base_armor" and item:GetData("equip")) then
					armorRad = (item.damage ~= nil and item.damage[5] ~= nil) and item.damage[5] or 1
					break
				end
			end

			local X = 0.25 + 0.75 * armorRad

			-- La droga antirradiación (plugin "drogas") reduce drásticamente la
			-- radiación absorbida mientras su efecto esté activo.
			if (client:GetNetVar("drogaRadResist", 0) > CurTime()) then
				X = X * 0.15
			end

			-- Técnico de radiación: reduce la radiación absorbida y otorga XP por
			-- mantenerse vivo en la zona.
			X = X * (hook.Run("AdjustRadiationIntake", client, char) or 1)
			hook.Run("OnRadiacionTick", client, char)

			char:SetRadiation(math.min(800, char:GetRadiation() + X))
		end
	end
end)

-- Los tramos de radiación (sano/irradiado/contaminado/crítico) viven en
-- ix.badair.radStates (sh_plugin.lua) — fuente de verdad única compartida con
-- el cliente, en vez de umbrales duplicados en cada archivo.

-- Aplica efectos de radiación cada 2 segundos.
timer.Create("badairEffects", 2, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then continue end

		local rad = char:GetRadiation()

		-- Muerte al llegar a 800 de radiación
		if (rad >= 800) then
			client:Notify("La radiación ha destruido tu organismo por completo.")
			client:Kill()
			continue
		end

		-- Reducción de salud máxima a partir de 400 de radiación
		if (rad >= 400) then
			local maxHPReduction = math.min(75, math.floor((rad - 400) / 20))
			local newMaxHP = math.max(25, 100 - maxHPReduction)
			client:SetMaxHealth(newMaxHP)
			if (client:Health() > newMaxHP) then
				client:SetHealth(newMaxHP)
			end
		elseif (client:GetMaxHealth() < 100) then
			client:SetMaxHealth(100)
		end

		-- Aviso claro (no solo el /it de sabor aleatorio de abajo) al CRUZAR
		-- hacia arriba de estado — nombrando el estado en vez de un número, para
		-- que se entienda de un vistazo. Entrar en "crítico" es el paso previo
		-- directo a la muerte instantánea a 800: así es imposible llegar a morir
		-- sin verlo venir con tiempo de sobra.
		local stateIndex = ix.badair.GetRadiationStateIndex(rad)
		if (stateIndex > (client.ixRadStateIndex or 0)) then
			-- GetRadiationStateIndex es 0-based (0=sano..3=crítico) pero
			-- ix.badair.radStates es 1-based (radStates[1]=sano): +1 para
			-- resolver la fila correcta.
			local state = ix.badair.radStates[stateIndex + 1]

			if (state.id == "critico") then
				client:Notify("¡ALERTA! Estado CRÍTICO: sin tratamiento, morirás.")
			else
				client:Notify("Has pasado a estar " .. state.name:upper() .. " — " .. state.desc)
			end
		end
		client.ixRadStateIndex = stateIndex
	end
end)

-- Mensajes de sabor del /it, uno por estado (sin contar "sano", que no tiene).
local radMessages = {
	irradiado = {
		"siente un ligero mareo y náuseas.",
		"parpadea con esfuerzo, notando un sabor metálico en la boca.",
		"se lleva la mano a la cabeza, sintiendo un zumbido leve.",
		"fruce el ceño mientras un leve mareo le nubla la visión por un instante.",
		"nota un hormigueo extraño en las yemas de los dedos.",
	},
	contaminado = {
		"siente un leve mareo pasajero.",
		"nota un ligero cosquilleo en la cabeza.",
		"parpadea un momento, algo desorientado.",
		"siente un ligero peso detrás de los ojos.",
		"nota un sabor metálico tenue en la boca.",
	},
	critico = {
		"cae de rodillas, incapaz de ignorar el devastador mareo que lo consume.",
		"vomita con violencia, su cuerpo rechazando la radiación que lo destruye por dentro.",
		"tiembla incontrolablemente, la piel ardiendo como si estuviese en llamas.",
		"suelta un gemido ahogado mientras la radiación quema cada célula de su cuerpo.",
		"pierde el equilibrio y se aferra a lo que tiene cerca, apenas consciente.",
	},
}

-- Envía un /it de síntomas de radiación cada 2 minutos a jugadores por encima
-- del estado "sano".
timer.Create("badairRadiationIT", 20, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then continue end

		local stateIndex = ix.badair.GetRadiationStateIndex(char:GetRadiation())
		if (stateIndex == 0) then continue end

		local state = ix.badair.radStates[stateIndex + 1] -- ver comentario en badairEffects
		local pool = radMessages[state.id]
		local msg = pool[math.random(#pool)]
		ix.chat.Send(client, "it", msg)

		-- Mareo/blur de cámara (intensidad según estado) + tambaleo aleatorio de
		-- W/A/S/D en contaminado/crítico. El cliente decide la intensidad.
		netstream.Start(client, "badair_radiationStumble", stateIndex)
	end
end)

-- La radiación SOLO baja tomando los medicamentos establecidos (ver
-- badairAntiRad más abajo) — morir ya no la reduce. Al morir se limpia el
-- estado de seguimiento y cualquier dosis de antirradiación pendiente sin
-- consumir (el personaje respawnea, no tiene sentido arrastrarla).
hook.Add("DoPlayerDeath", "badair_radiation_reset", function(client)
	client.ixAntiRadRemaining = nil
	client.ixRadStateIndex = nil
end)

-- Los ítems establecen client.ixAntiRadRemaining; este timer lo descuenta.
timer.Create("badairAntiRad", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client)) then continue end
		if (!(client.ixAntiRadRemaining) or client.ixAntiRadRemaining <= 0) then continue end

		local char = client:GetCharacter()
		if (!char) then continue end

		local toRemove = math.min(3, client.ixAntiRadRemaining)
		char:SetRadiation(math.max(0, char:GetRadiation() - toRemove))
		client.ixAntiRadRemaining = client.ixAntiRadRemaining - toRemove
		if (client.ixAntiRadRemaining <= 0) then
			client.ixAntiRadRemaining = nil
		end
	end
end)
