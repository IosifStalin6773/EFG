-- ============================================================================
--  Datos del loot de la IA. Sin lógica: la lee sv_plugin.lua.
--
--  Perfiles (AI.Profiles)
--    pockets, vest, backpack, body   tabla de efg_loot para cada contenedor
--                                    (vest va dentro del chaleco táctico y
--                                    backpack dentro de la mochila: sin ellos
--                                    no se genera)
--    rare     true = tirada de scav_rare con efgLootScavRareChance
--    gear     ranura -> {{uniqueID, peso}, {false, peso}}  (false = nada)
--    tiers    equipo por nivel (PMC): el de minLevel más alto que no supere
--             el nivel del bot
--    level    {mín, máx} sobre el nivel del jugador más cercano (Documento A:
--             hasta 10 niveles por encima)
--    minLevel nivel mínimo del perfil
--    looter   true = busca loot activamente y extrae (PMC de IA)
--    nameKey  nombre del cadáver (clave de idioma)
--
--  Equipo y precios [VERIFICAR] contra la wiki de EFT.
-- ============================================================================

local AI = ix.efg.lootai

local SCAV_GEAR = {
	helmet = {{"helmet_ssh68", 15}, {"helmet_kiver", 5}, {false, 80}},
	armor = {{"armor_paca", 12}, {"armor_6b2", 8}, {false, 80}},
	rig = {{"rig_scav", 40}, {"rig_wild", 15}, {false, 45}},
	backpack = {{"bp_scav", 25}, {"bp_redfox", 8}, {false, 67}}
}

AI.PMCTiers = {
	{
		minLevel = 1,
		weapon = {{"arc9_eft_aks74u", 30}, {"arc9_eft_mp5", 25}, {"arc9_eft_kedr", 15}, {"arc9_eft_mp153", 15}, {"arc9_eft_akms", 15}},
		helmet = {{"helmet_ssh68", 30}, {"helmet_kiver", 30}, {"helmet_6b47", 10}, {false, 30}},
		armor = {{"armor_paca", 35}, {"armor_6b2", 30}, {"armor_untar", 15}, {false, 20}},
		rig = {{"rig_alpha", 40}, {"rig_m2", 30}, {"rig_scav", 30}},
		backpack = {{"bp_daypack", 40}, {"bp_redfox", 35}, {"bp_scav", 25}}
	},
	{
		minLevel = 15,
		weapon = {{"arc9_eft_ak74", 30}, {"arc9_eft_akm", 25}, {"arc9_eft_m4a1", 20}, {"arc9_eft_mp5", 15}, {"arc9_eft_sks", 10}},
		helmet = {{"helmet_6b47", 40}, {"helmet_ulach", 20}, {"helmet_kiver", 20}, {false, 20}},
		armor = {{"armor_6b23_1", 30}, {"armor_6b13", 30}, {"armor_untar", 25}, {"armor_trooper", 15}},
		rig = {{"rig_mkiii", 35}, {"rig_tv109", 25}, {"rig_a18", 25}, {"rig_m2", 15}},
		backpack = {{"bp_trizip", 40}, {"bp_daypack", 35}, {"bp_pilgrim", 25}}
	},
	{
		minLevel = 30,
		weapon = {{"arc9_eft_m4a1", 30}, {"arc9_eft_hk416", 20}, {"arc9_eft_ak103", 20}, {"arc9_eft_mcx", 15}, {"arc9_eft_ak12", 15}},
		helmet = {{"helmet_fast", 40}, {"helmet_ulach", 30}, {"helmet_maska", 20}, {"helmet_6b47", 10}},
		armor = {{"armor_trooper", 30}, {"armor_6b13", 25}, {"armor_korund", 25}, {"armor_6b43", 20}},
		rig = {{"rig_tarzan", 35}, {"rig_6sh112", 25}, {"rig_tv109", 25}, {"rig_mkiii", 15}},
		backpack = {{"bp_pilgrim", 40}, {"bp_trizip", 30}, {"bp_blackjack", 20}, {"bp_6sh118", 10}}
	},
	{
		minLevel = 45,
		weapon = {{"arc9_eft_hk416", 30}, {"arc9_eft_mcx", 25}, {"arc9_eft_ak12", 20}, {"arc9_eft_svds", 15}, {"arc9_eft_ash12", 10}},
		helmet = {{"helmet_altyn", 30}, {"helmet_maska", 35}, {"helmet_fast", 35}},
		armor = {{"armor_slick", 25}, {"armor_6b43", 30}, {"armor_korund", 30}, {"armor_trooper", 15}},
		rig = {{"rig_6sh112", 40}, {"rig_tarzan", 40}, {"rig_tv109", 20}},
		backpack = {{"bp_6sh118", 40}, {"bp_blackjack", 40}, {"bp_pilgrim", 20}}
	}
}

AI.Profiles = {
	scav = {
		pockets = "scav_pockets", vest = "scav_vest", backpack = "scav_backpack", body = "scav_body",
		rare = true,
		gear = SCAV_GEAR,
		nameKey = "efgLootDeadScav"
	},
	boss = {
		pockets = "scav_pockets", vest = "pmc_vest", backpack = "pmc_backpack", body = "boss_body",
		rare = true,
		gear = {
			helmet = {{"helmet_altyn", 35}, {"helmet_maska", 35}, {false, 30}},
			armor = {{"armor_korund", 40}, {"armor_6b43", 30}, {"armor_trooper", 30}},
			rig = {{"rig_6sh112", 50}, {"rig_tarzan", 50}},
			backpack = {{"bp_blackjack", 40}, {"bp_pilgrim", 30}, {false, 30}}
		},
		nameKey = "efgLootDeadBoss"
	},
	pmc = {
		pockets = "pmc_pockets", vest = "pmc_vest", backpack = "pmc_backpack",
		tiers = AI.PMCTiers,
		level = {0, 10},
		looter = true,
		nameKey = "efgLootDeadPMC"
	},
	raider = {
		pockets = "pmc_pockets", vest = "pmc_vest", backpack = "pmc_backpack",
		tiers = AI.PMCTiers,
		level = {5, 15},
		minLevel = 30,
		nameKey = "efgLootDeadRaider"
	}
}

-- Tipo de zona de efg_ai -> perfil. Los jefes (bBoss) usan siempre "boss";
-- lo que no esté aquí usa "scav" si la zona es de Scavs y "pmc" si no.
AI.ZoneProfiles = {
	scav = "scav",
	francotirador = "scav",
	cultist = "scav",
	pmc = "pmc",
	raider = "raider",
	rogue = "raider",
	goons = "raider",
	partisan = "raider"
}

-- Arma de VJ que lleva el NPC -> objeto de Helix que deja en el cadáver, y al
-- revés para darle al NPC el arma de su equipo cuando exista.
AI.WeaponItems = {
	weapon_vj_meft_toz = "arc9_eft_toz106",
	weapon_vj_meft_pm = "arc9_eft_pm",
	weapon_vj_meft_mr43 = "arc9_eft_mr43",
	weapon_vj_meft_mp153 = "arc9_eft_mp153",
	weapon_vj_meft_kedr = "arc9_eft_kedr",
	weapon_vj_meft_aks74u = "arc9_eft_aks74u"
}

AI.NPCWeapons = {}

for npcClass, itemID in pairs(AI.WeaponItems) do
	AI.NPCWeapons[itemID] = npcClass
end

-- Looteo activo y extracción del PMC de IA
AI.LOOT_RADIUS = 1500        -- unidades a las que busca contenedores y cuerpos
AI.LOOT_REACH = 90           -- distancia para empezar a saquear
AI.LOOT_GIVEUP = 60          -- segundos antes de abandonar un objetivo
AI.POCKET_CELLS = 4          -- casillas de bolsillo
AI.RIG_CELLS = 4             -- casillas que aporta el chaleco táctico
AI.EXTRACT_RADIUS = 200      -- si la extracción no trae radio
