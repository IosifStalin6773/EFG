local PLUGIN = PLUGIN

-- Al crear el personaje, asignar automáticamente Tier 1 si se eligió un oficio válido.
function PLUGIN:OnCharacterCreated(client, character)
	local oficio = character:GetOficio()
	if (oficio and oficio != "" and oficio != "ninguno") then
		character:SetOficioTier(1)
	end
end

-- Migración: chatarrero dejó de ser un oficio elegible (ahora es transversal).
-- Los personajes que lo tenían elegido pasan a "ninguno", pero conservan el nivel
-- de chatarrero que habían alcanzado, trasladándolo a la nueva variable transversal.
function PLUGIN:PlayerLoadedCharacter(client, character, currentChar)
	if (character:GetOficio() == "chatarrero") then
		local oldTier = math.Clamp(character:GetOficioTier() or 1, 1, 3)
		if ((character:GetChatarreroTier() or 1) < oldTier) then
			character:SetChatarreroTier(oldTier)
		end

		character:SetOficio("ninguno")
		character:SetOficioTier(0)
	end
end

-- Comando admin: /setoficios <jugador> <oficio> <tier>
-- Ejemplo: /setoficios "Manolo" armero 2
ix.command.Add("SetOficio", {
	description = "Establece el oficio y tier de un personaje.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.string,
		ix.type.number,
	},
	OnRun = function(self, client, target, oficio, tier)
		oficio = oficio:lower()

		if (!ix.oficios or !ix.oficios.lista[oficio]) then
			local validos = {}
			for id, _ in pairs(ix.oficios.lista) do
				validos[#validos + 1] = id
			end
			table.sort(validos)
			return client:NotifyLocalized("Oficio inválido. Opciones: " .. table.concat(validos, ", "))
		end

		tier = math.Round(tier)
		if (tier < 1 or tier > 3) then
			return client:NotifyLocalized("El tier debe ser entre 1 y 3.")
		end

		local character = target:GetCharacter()
		if (!character) then
			return client:NotifyLocalized("El jugador no tiene un personaje activo.")
		end

		character:SetOficio(oficio)
		character:SetOficioTier(tier)

		local nombre = ix.oficios.lista[oficio]
		target:Notify("Tu oficio ha sido cambiado a " .. nombre .. " (Tier " .. tier .. ") por un administrador.")
		client:Notify("Oficio de " .. target:Name() .. " establecido a " .. nombre .. " Tier " .. tier .. ".")
	end
})

-- Comando admin: /SetChatarrero <jugador> <tier>
-- Ajusta el tier del oficio transversal Chatarrero (que todos poseen).
ix.command.Add("SetChatarrero", {
	description = "Establece el tier de Chatarrero (transversal) de un personaje.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number,
	},
	OnRun = function(self, client, target, tier)
		tier = math.Round(tier)
		if (tier < 1 or tier > 3) then
			return client:NotifyLocalized("El tier debe ser entre 1 y 3.")
		end

		local character = target:GetCharacter()
		if (!character) then
			return client:NotifyLocalized("El jugador no tiene un personaje activo.")
		end

		character:SetChatarreroTier(tier)

		target:Notify("Tu nivel de Chatarrero ha sido establecido a Tier " .. tier .. " por un administrador.")
		client:Notify("Chatarrero de " .. target:Name() .. " establecido a Tier " .. tier .. ".")
	end
})
