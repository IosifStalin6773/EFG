local PLUGIN = PLUGIN

PLUGIN.name        = "EFG IA"
PLUGIN.author      = "EFG"
PLUGIN.description = "Scavs, PMC y jefes controlados por la IA (VJ Base) que aparecen por oleadas en zonas del mapa mientras hay jugadores en raid."

ix.config.Add("efgAIWaveSeconds", 120, "Segundos entre oleadas de IA.", nil, {
	data = {min = 15, max = 1800},
	category = "EFG IA"
})

ix.config.Add("efgAIActivationDistance", 7000, "Una zona solo genera IA si hay un jugador en raid a menos de esta distancia.", nil, {
	data = {min = 500, max = 30000},
	category = "EFG IA"
})

ix.config.Add("efgAIMinPlayerDistance", 900, "La IA nunca aparece a menos de esta distancia de un jugador.", nil, {
	data = {min = 0, max = 5000},
	category = "EFG IA"
})

ix.config.Add("efgAIMax", 30, "Máximo de NPCs de IA vivos en todo el mapa.", nil, {
	data = {min = 1, max = 150},
	category = "EFG IA"
})

-- Tipos de zona: clases de NPC (addon [VJ] Escape From Tarkov SNPC's) y su relación
PLUGIN.zoneTypes = {
	scav = {
		name = "Scav",
		classes = {"npc_vj_mishawild_scav1", "npc_vj_mishawild_scav2", "npc_vj_mishawild_scav3",
			"npc_vj_mishawild_scav4", "npc_vj_mishawild_scav5", "npc_vj_mishawild_scav6"},
		weapons = {"weapon_vj_meft_toz", "weapon_vj_meft_pm", "weapon_vj_meft_mr43",
			"weapon_vj_meft_mp153", "weapon_vj_meft_kedr", "weapon_vj_meft_aks74u"},
		isScav = true
	},
	francotirador = {
		name = "Scav francotirador",
		classes = {"npc_vj_mishawild_sniper1"},
		isScav = true
	},
	pmc = {
		name = "PMC (IA)",
		classes = {"npc_vj_mishapmc_bear1", "npc_vj_mishapmc_bear2", "npc_vj_mishapmc_bear3",
			"npc_vj_mishapmc_usec1", "npc_vj_mishapmc_usec2", "npc_vj_mishapmc_usec3"}
	},
	jefe = {
		name = "Reshala y su escolta",
		boss = "npc_vj_mishawild_reshala1",
		classes = {"npc_vj_mishawild_bully_security1", "npc_vj_mishawild_bully_security2",
			"npc_vj_mishawild_bully_security3", "npc_vj_mishawild_bully_security4"},
		isScav = true,
		chance = 35 -- % de raids (por oleada) en que aparece el jefe
	},
	sanitar = {
		name = "Sanitar y su escolta",
		boss = "npc_vj_mishawild_sanitar1",
		classes = {"npc_vj_mishawild_sanitar_security1"},
		isScav = true,
		chance = 30
	}
}

ix.command.Add("IAZonaAdd", {
	description = "Añade una zona de IA donde estás. Tipos: scav, francotirador, pmc, jefe, sanitar.",
	adminOnly = true,
	arguments = {
		ix.type.string,
		bit.bor(ix.type.number, ix.type.optional),
		bit.bor(ix.type.number, ix.type.optional)
	},
	argumentNames = {"tipo", "máximo", "radio"},
	OnRun = function(self, client, kind, max, radius)
		kind = string.lower(kind)

		if (!PLUGIN.zoneTypes[kind]) then
			return "Tipo no válido. Usa: scav, francotirador, pmc, jefe o sanitar."
		end

		PLUGIN:AddZone({
			type = kind,
			pos = client:GetPos(),
			max = math.Clamp(max or 4, 1, 20),
			radius = math.Clamp(radius or 400, 0, 3000)
		})

		return ("Zona de IA \"%s\" añadida."):format(PLUGIN.zoneTypes[kind].name)
	end
})

ix.command.Add("IAZonaBorrar", {
	description = "Borra la zona de IA más cercana (a menos de 500 unidades).",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:RemoveNearestZone(client:GetPos())
	end
})

ix.command.Add("IALimpiar", {
	description = "Elimina toda la IA de raid del mapa.",
	adminOnly = true,
	OnRun = function(self, client)
		return ("%d NPCs eliminados."):format(PLUGIN:ClearAI())
	end
})

ix.util.Include("sv_plugin.lua")
