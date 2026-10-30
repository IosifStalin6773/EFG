local PLUGIN = PLUGIN

PLUGIN.name = "EFG Karma Scav"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Reputación con Fence (karma Scav): baja al matar Scavs siendo Scav, sube al extraer como Scav y cambia la espera y la hostilidad de la IA."

-- Fuente: https://escapefromtarkov.fandom.com/wiki/Fence#Scav_karma
-- Rango -7 a 6. Los cambios exactos son [VERIFICAR]: configurables.

ix.efg = ix.efg or {}
ix.efg.karma = ix.efg.karma or {}

local KARMA = ix.efg.karma

KARMA.min, KARMA.max = -7, 6

ix.config.Add("efgKarmaKillScav", -0.2, "[VERIFICAR wiki: Fence#Scav_karma] Cambio al matar un Scav de la IA siendo Scav.", nil, {
	data = {min = -2, max = 0, decimals = 2}, category = "EFG Karma"
})
ix.config.Add("efgKarmaKillPlayerScav", -0.2, "[VERIFICAR wiki: Fence#Scav_karma] Cambio al matar a otro jugador Scav siendo Scav.", nil, {
	data = {min = -2, max = 0, decimals = 2}, category = "EFG Karma"
})
ix.config.Add("efgKarmaExtract", 0.01, "[VERIFICAR wiki: Fence#Scav_karma] Cambio al extraer como Scav.", nil, {
	data = {min = 0, max = 1, decimals = 2}, category = "EFG Karma"
})
ix.config.Add("efgKarmaHostile", -1, "[VERIFICAR wiki: Fence#Scav_karma] Con karma por debajo de este valor los Scavs de la IA atacan a tu Scav.", nil, {
	data = {min = -7, max = 0, decimals = 1}, category = "EFG Karma"
})

function KARMA.Get(character)
	return tonumber(character and character:GetData("efgKarma", 0)) or 0
end

-- Espera del Scav run: cada punto positivo la acorta un 5 % y cada negativo la
-- alarga un 10 % [VERIFICAR wiki: Fence#Scav_karma].
function KARMA.CooldownMultiplier(character)
	local karma = KARMA.Get(character)

	return karma >= 0 and math.max(0.5, 1 - karma * 0.05) or (1 - karma * 0.1)
end

ix.command.Add("Karma", {
	description = "Muestra tu karma Scav (reputación con Fence).",
	OnRun = function(self, client)
		return ("Karma Scav: %.2f (de %d a %d)."):format(KARMA.Get(client:GetCharacter()), KARMA.min, KARMA.max)
	end
})

ix.util.Include("sv_plugin.lua")
