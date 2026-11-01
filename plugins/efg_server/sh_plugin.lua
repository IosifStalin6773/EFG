local PLUGIN = PLUGIN

PLUGIN.name = "EFG Servidor"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Infraestructura: wipe, modo PvE/PvP, búsqueda de grupo, anticheat de velocidad y saqueo, descarga del contenido propio y autodiagnóstico."

ix.efg = ix.efg or {}

ix.config.Add("efgPvE", false, "Modo PvE: los jugadores no se hacen daño entre sí (solo IA).", nil, {
	category = "EFG Servidor"
})
ix.config.Add("efgWipeID", 1, "Número de wipe actual. Lo sube /EFGWipe; cada personaje se reinicia al entrar si su wipe es anterior.", nil, {
	data = {min = 1, max = 10000}, category = "EFG Servidor"
})
ix.config.Add("efgWipeMoney", 500000, "Rublos con los que empieza cada personaje tras un wipe.", nil, {
	data = {min = 0, max = 10000000}, category = "EFG Servidor"
})
ix.config.Add("efgAntiSpeed", true, "Anticheat: devuelve a su sitio a quien se mueve más rápido de lo posible.", nil, {
	category = "EFG Servidor"
})
ix.config.Add("efgLootDistance", 160, "Distancia máxima para coger objetos del suelo (anticheat).", nil, {
	data = {min = 60, max = 1000}, category = "EFG Servidor"
})

ix.config.Add("efgAutoWorkshop", true, "Manda a cada jugador al entrar todos los addons de Workshop que monta el servidor (su colección).", nil, {
	category = "EFG Servidor"
})

-- PvE: sin daño entre jugadores
function PLUGIN:PlayerShouldTakeDamage(client, attacker)
	if (ix.config.Get("efgPvE", false) and IsValid(attacker) and attacker:IsPlayer() and attacker != client) then
		return false
	end
end

ix.command.Add("EFGWipe", {
	description = "Wipe de todos los personajes (nivel, alijo, escondite, misiones). Escribe CONFIRMAR.",
	superAdminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, confirm)
		if (confirm != "CONFIRMAR") then
			return "Escribe /EFGWipe CONFIRMAR. No se puede deshacer."
		end

		ix.config.Set("efgWipeID", ix.config.Get("efgWipeID", 1) + 1)

		for _, target in ipairs(player.GetAll()) do
			local character = target:GetCharacter()
			if (character) then PLUGIN:WipeCharacter(target, character) end
		end

		return "Wipe hecho. Cada personaje se reinicia al entrar."
	end
})

ix.command.Add("BuscarGrupo", {
	description = "Entra o sale de la cola para formar grupo de raid con otros jugadores.",
	OnRun = function(self, client)
		if (SERVER) then return PLUGIN:ToggleQueue(client) end
	end
})

ix.command.Add("EFGDiagnostico", {
	description = "Comprueba addons, plugins y datos de EFG y muestra lo que falta.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then PLUGIN:Diagnose(client) end
	end
})

ix.util.Include("sv_plugin.lua")
