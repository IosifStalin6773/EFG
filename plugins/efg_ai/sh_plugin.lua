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
		name = "El Cacique y su escolta",
		boss = "npc_vj_mishawild_reshala1",
		classes = {"npc_vj_mishawild_bully_security1", "npc_vj_mishawild_bully_security2",
			"npc_vj_mishawild_bully_security3", "npc_vj_mishawild_bully_security4"},
		isScav = true,
		chance = 35 -- % de raids (por oleada) en que aparece el jefe
	},
	sanitar = {
		name = "El Curandero y su escolta",
		boss = "npc_vj_mishawild_sanitar1",
		classes = {"npc_vj_mishawild_sanitar_security1"},
		isScav = true,
		chance = 30,
		mapBoss = "sanitar"
	},
	-- H6: resto de jefes y facciones de EFT. Las clases de NPC que no estén
	-- instaladas se ignoran (aviso en consola); /IAClases lista las que hay.
	-- [VERIFICAR] nombres de clase del addon de SNPC y probabilidades (wiki: Bosses).
	killa = {name = "Killa", boss = "npc_vj_mishawild_killa1", classes = {}, isScav = true, chance = 35, mapBoss = "killa"},
	tagilla = {name = "Tagilla", boss = "npc_vj_mishawild_tagilla1", classes = {}, isScav = true, chance = 30, mapBoss = "tagilla"},
	shturman = {name = "Shturman y su escolta", boss = "npc_vj_mishawild_shturman1",
		classes = {"npc_vj_mishawild_shturman_security1"}, isScav = true, chance = 40, mapBoss = "shturman"},
	glukhar = {name = "Glukhar y su escolta", boss = "npc_vj_mishawild_glukhar1",
		classes = {"npc_vj_mishawild_glukhar_security1", "npc_vj_mishawild_glukhar_security2"}, isScav = true, chance = 35, mapBoss = "glukhar"},
	kaban = {name = "Kaban y su escolta", boss = "npc_vj_mishawild_kaban1",
		classes = {"npc_vj_mishawild_kaban_security1"}, isScav = true, chance = 40, mapBoss = "kaban"},
	kollontay = {name = "Kollontay y su escolta", boss = "npc_vj_mishawild_kollontay1",
		classes = {"npc_vj_mishawild_kollontay_security1"}, isScav = true, chance = 30, mapBoss = "kollontay"},
	zryachiy = {name = "Zryachiy y su escolta", boss = "npc_vj_mishawild_zryachiy1",
		classes = {"npc_vj_mishawild_zryachiy_security1"}, isScav = true, chance = 100, mapBoss = "zryachiy"},
	goons = {name = "Los Goons (Knight, Birdeye, Big Pipe)", boss = "npc_vj_mishawild_knight1",
		classes = {"npc_vj_mishawild_birdeye1", "npc_vj_mishawild_bigpipe1"}, chance = 30, mapBoss = "goons"},
	partisan = {name = "Partisan", boss = "npc_vj_mishawild_partisan1", classes = {}, chance = 30, mapBoss = "partisan"},
	raider = {name = "Raiders", classes = {"npc_vj_mishawild_raider1", "npc_vj_mishawild_raider2", "npc_vj_mishapmc_usec1"}, mapBoss = "raiders"},
	rogue = {name = "Rogues", classes = {"npc_vj_mishawild_rogue1", "npc_vj_mishapmc_usec2", "npc_vj_mishapmc_usec3"}, mapBoss = "rogues"},
	cultist = {name = "Cultistas (solo de noche)", boss = "npc_vj_mishawild_cultist_priest1",
		classes = {"npc_vj_mishawild_cultist1"}, isScav = false, chance = 25, mapBoss = "cultists", nightOnly = true,
		toxicKnife = true}
}

-- Probabilidad de jefe: la del mapa (efg_maps) manda sobre la del tipo
function PLUGIN:GetBossChance(zoneType)
	local fromMap = zoneType.mapBoss and ix.efg.maps and ix.efg.maps.BossChance(zoneType.mapBoss)
	return fromMap or zoneType.chance or 100
end

ix.command.Add("IAClases", {
	description = "Lista las clases de NPC instaladas que contienen un texto (por defecto, de EFT).",
	adminOnly = true,
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, filter)
		filter = (filter or "misha"):lower()
		local found = {}

		for class in pairs(list.Get("NPC")) do
			if (class:lower():find(filter, 1, true)) then found[#found + 1] = class end
		end

		table.sort(found)

		for _, class in ipairs(found) do client:ChatPrint(class) end

		return #found .. " clases."
	end
})

ix.command.Add("IAZonaAdd", {
	description = "Añade una zona de IA donde estás. Tipos: scav, francotirador, pmc, jefe, sanitar, killa, tagilla, shturman, glukhar, kaban, kollontay, zryachiy, goons, partisan, raider, rogue, cultist.",
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
			return "Tipo no válido. Usa: " .. table.concat(table.GetKeys(PLUGIN.zoneTypes), ", ")
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
