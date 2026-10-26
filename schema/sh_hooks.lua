
-- Here is where all of your shared hooks should go.

-- Disable entity driving.
function Schema:CanDrive(client, entity)
	return false
end

-- Cualquier rango por encima del usuario estándar puede tener hasta 4 personajes;
-- el usuario estándar se queda con el límite normal (ix.config "maxCharacters").
function Schema:GetMaxPlayerCharacter(client)
	if (IsValid(client) and client:GetUserGroup() != "user") then
		return 4
	end
end

-- Solo se puede borrar UN personaje por cuenta en toda su vida (evita abusar de
-- mecánicas ligadas a la creación/borrado de personajes). Reseteable por un
-- admin con el comando "CharResetDeleteLimit".
ix.command.Add("CharResetDeleteLimit", {
	description = "Permite a un jugador volver a borrar un personaje (le resetea el límite de borrado único).",
	adminOnly = true,
	arguments = {ix.type.player},
	OnRun = function(self, client, target)
		if (SERVER) then
			local steamID = target:SteamID64()
			local used = ix.data.Get("charDeletesUsed", {}, true, true)
			used[steamID] = nil
			ix.data.Set("charDeletesUsed", used, true, true)

			client:Notify("Se ha reseteado el límite de borrado de personaje de " .. target:Name() .. ".")
			target:Notify("Un administrador te ha dado una nueva oportunidad para borrar un personaje.")
		end
	end
})

-- Mensajes de conexión/desconexión solo visibles para admins.
if (SERVER) then
	local function adminOnlyHear(self, speaker, listener)
		return listener:IsAdmin()
	end

	ix.chat.classes["connect"].CanHear = adminOnlyHear
	ix.chat.classes["disconnect"].CanHear = adminOnlyHear
end
