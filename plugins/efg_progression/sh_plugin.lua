local PLUGIN = PLUGIN

PLUGIN.name = "EFG Progresión"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Curva de nivel del PMC de EFT y experiencia por acciones: examinar, botear, curar y bajas a la cabeza."

-- Fuentes (wiki de EFT): Character_skills, Experience.
-- [VERIFICAR wiki: Experience] XP total por nivel, de memoria.

ix.efg = ix.efg or {}

-- XP total necesaria para cada nivel (nivel 1 = 0)
local EFT_LEVELS = {
	0, 1000, 4017, 8432, 14256, 21477, 30023, 39936, 51204, 63723,
	77563, 92713, 111881, 134674, 161139, 191417, 225194, 262366, 302484, 345751,
	391649, 440444, 492366, 547896, 609066, 675913, 748474, 826786, 910885, 1000809,
	1096593, 1198275, 1309251, 1429580, 1559321, 1698532, 1847272, 2005600, 2173575, 2351255,
	2538699, 2735966, 2946585, 3170637, 3408202, 3659361, 3924195, 4202784, 4495210, 4801553,
	5121894, 5456314, 5809667, 6182063, 6573613, 6984426, 7414613, 7864284, 8333549, 8831052,
	9360623, 9928578, 10541848, 11206300, 11946977, 12789143, 13820522, 15229487, 17206065, 19706065,
	22706065, 26206065, 30206065, 34706065, 39706065, 45206065, 51206065, 58206065, 68206065
}

ix.config.Add("efgEFTLevelCurve", true, "Usar la curva de experiencia de EFT (79 niveles).", nil, {
	category = "EFG Progresión"
})

-- XP por acción [VERIFICAR wiki: Experience]
ix.efg.actionXP = {
	examine = {min = 2, max = 30},   -- examinar un objeto nuevo (según precio)
	loot = 1,                        -- coger un objeto en raid por primera vez
	heal = 0.5,                      -- por punto de vida curado
	headshot = 1.2,                  -- multiplicador de la XP por baja a la cabeza
	survivedMult = 1.3,              -- bonificación de raid sobrevivida sobre la XP ganada
	foundInRaid = 0                  -- reservado
}

function PLUGIN:InitializedPlugins()
	if (ix.config.Get("efgEFTLevelCurve", true) and ix.efg.levels) then
		for i, xp in ipairs(EFT_LEVELS) do
			ix.efg.levels[i] = xp
		end

		for i = #EFT_LEVELS + 1, #ix.efg.levels do
			ix.efg.levels[i] = nil
		end
	end
end

ix.util.Include("sv_plugin.lua")
