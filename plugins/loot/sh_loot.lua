-- ============================================================
--  loot  |  sh_loot.lua  (SHARED)
--  Sistema de tiers dinámico: definiciones por defecto,
--  resolución de tiers por área/preset y roll de loot.
-- ============================================================

-- ── Tiers por defecto (usados en migración si no hay datos) ──

ix.loot.defaultTiers = {
	["t1"] = {
		name = "Chatarra (zona tranquila)", color = {220, 120, 40}, order = 1,
		chances = {
			{55, "materias_primas"},
			{15, "materiales_procesados"},
			{20, "suministros"},
			{10, "medicinas"},
		}
	},
	["t2"] = {
		name = "Casas y oficinas", color = {200, 80, 40}, order = 2,
		chances = {
			{35, "materias_primas"},
			{15, "materiales_procesados"},
			{10, "herramientas"},
			{15, "suministros"},
			{10, "medicinas"},
			{10, "armamento"},
			{5,  "equipo"},
		}
	},
	["t3"] = {
		name = "Cajas de armas", color = {80, 180, 80}, order = 3,
		chances = {
			{10, "materiales_procesados"},
			{55, "armamento"},
			{20, "equipo"},
			{15, "componentes_raros"},
		}
	},
	["t4"] = {
		name = "Zona militar", color = {180, 60, 60}, order = 4,
		chances = {
			{10, "materiales_procesados"},
			{35, "armamento"},
			{25, "equipo"},
			{10, "medicinas"},
			{20, "componentes_raros"},
		}
	},
	["t5"] = {
		name = "Médico (botiquines)", color = {80, 160, 220}, order = 5,
		chances = {
			{70, "medicinas"},
			{20, "suministros"},
			{10, "componentes_raros"},
		}
	},
	["t6"] = {
		name = "Laboratorio", color = {180, 60, 220}, order = 6,
		chances = {
			{30, "armamento"},
			{30, "equipo"},
			{40, "componentes_raros"},
		}
	},
	["t7"] = {
		name = "Alijo (escondite oculto)", color = {220, 190, 60}, order = 7,
		chances = {
			{25, "materiales_procesados"},
			{25, "suministros"},
			{20, "medicinas"},
			{20, "armamento"},
			{10, "componentes_raros"},
		}
	},
}

-- ── Tablas de loot: {id, peso, maxCantidad} ─────────────────
-- Los ítems que no existan se ignoran al tirar el loot.

ix.loot.tables = {
	materias_primas = {
		{"piezas_metalicas", 5, 2}, {"componentes_mecanicos", 4, 2}, {"retales_tela", 4, 2},
		{"madera_humeda", 3, 2}, {"residuos_organicos", 3, 2}, {"restos_mezclados", 2, 2},
		{"botella_cristal", 2, 2}, {"basura_electronica", 2, 2}, {"botella_lejia", 1, 2},
	},

	materiales_procesados = {
		{"hierro", 4, 1}, {"tornillos", 4, 1}, {"tela", 4, 1},
		{"muelles", 3, 1}, {"cuero", 3, 1}, {"madera", 3, 1}, {"quimicos", 3, 1},
		{"plomo", 2, 1}, {"polvora", 2, 1}, {"cobre", 2, 1}, {"vidrio", 2, 1}, {"azufre", 2, 1},
		{"engranajes", 1, 1}, {"placas_metalicas", 1, 1}, {"plastico", 1, 1}, {"circuitos", 1, 1},
	},

	herramientas = {
		{"martillo", 2, 1}, {"llave_inglesa", 2, 1}, {"destornillador", 2, 1}, {"flashlight", 1, 1},
	},

	suministros = {
		{"water", 2, 1}, {"canned", 2, 1}, {"bread", 1.5, 1}, {"sausage", 1.5, 1},
		{"milk", 1, 1}, {"energy", 1, 1}, {"vodka", 0.5, 1},
		{"ammo_pistol", 1, 1}, {"ammo_buckshot", 1, 1}, {"bala", 1.5, 1},
	},

	medicinas = {
		{"venda_militar", 4, 2}, {"analgin", 3, 1}, {"ai2", 3, 1}, {"esmarch", 2, 1}, {"ferula", 2, 1},
		{"car", 1.5, 1}, {"ibuprofeno_efg", 1.5, 1}, {"salewa", 1, 1}, {"ifak", 0.8, 1},
		{"cms", 0.6, 1}, {"stim_morphine", 0.5, 1}, {"stim_adrenaline", 0.4, 1}, {"augmentin", 0.4, 1},
	},

	armamento = {
		{"arc9_eft_pm", 3, 1}, {"arc9_eft_tt33", 2, 1}, {"arc9_eft_mr43", 2, 1}, {"arc9_eft_toz106", 2, 1},
		{"arc9_eft_mr133", 2, 1}, {"arc9_eft_kedr", 1.5, 1}, {"arc9_eft_aks74u", 1.5, 1}, {"arc9_eft_sks", 1, 1},
		{"arc9_eft_vpo136", 1, 1}, {"arc9_eft_mosin_infantry", 1, 1}, {"arc9_eft_ak74", 0.8, 1},
		{"arc9_eft_akm", 0.6, 1}, {"arc9_eft_mp5", 0.6, 1}, {"arc9_eft_m4a1", 0.3, 1},
		{"ammo_pistol", 3, 2}, {"ammo_smg1", 3, 2}, {"ammo_ar2", 3, 2}, {"ammo_buckshot", 2, 2}, {"ammo_357", 0.5, 1},
	},

	equipo = {
		{"bp_scav", 3, 1}, {"bp_redfox", 2, 1}, {"bp_daypack", 1.5, 1}, {"bp_trizip", 0.5, 1},
		{"armor_paca", 2, 1}, {"armor_6b2", 2, 1}, {"armor_untar", 1, 1}, {"armor_6b23_1", 0.8, 1},
		{"armor_6b13", 0.4, 1}, {"helmet_ssh68", 2, 1}, {"helmet_kiver", 1.5, 1}, {"helmet_6b47", 0.8, 1},
		{"helmet_ulach", 0.4, 1}, {"helmet_fast", 0.3, 1},
	},

	componentes_raros = {
		{"componentes_militares", 3, 1}, {"herramientas_precision", 3, 1},
		{"aleacion_reforzada", 2, 1}, {"bateria", 2, 1},
		{"desfibrilador_roto", 2, 1}, {"plano_prototipo", 2, 1},
		{"kit_reparacion_armadura", 1, 1}, {"arc9_eft_svds", 0.3, 1}, {"arc9_eft_hk416", 0.2, 1},
		{"armor_trooper", 0.4, 1}, {"armor_korund", 0.15, 1}, {"helmet_altyn", 0.15, 1},
		{"bp_pilgrim", 0.4, 1}, {"bp_blackjack", 0.1, 1},
	},
}

-- ── Nombres por defecto de las tablas de loot ────────────────

ix.loot.defaultTableNames = {
	materias_primas        = "Chatarra",
	materiales_procesados  = "Material de trueque",
	herramientas           = "Herramientas",
	suministros            = "Comida y bebida",
	medicinas              = "Medicinas",
	armamento              = "Armas y munición",
	equipo                 = "Chalecos, cascos y mochilas",
	componentes_raros      = "Objetos valiosos",
}

-- ── Helpers ──────────────────────────────────────────────────

function ix.loot.GetTableName(tableKey)
	local plugin = ix.plugin.Get("loot")
	if (plugin and plugin.data and plugin.data.tableNames and plugin.data.tableNames[tableKey]) then
		return plugin.data.tableNames[tableKey]
	end
	return ix.loot.defaultTableNames[tableKey] or tableKey
end

-- Cache de tiers en el cliente (poblado via net desde sv_plugin)
ix.loot.clientTierCache = ix.loot.clientTierCache or nil

function ix.loot.GetTierData(tierID)
	local plugin = ix.plugin.Get("loot")
	if (plugin and plugin.data and plugin.data.customTiers and plugin.data.customTiers[tierID]) then
		return plugin.data.customTiers[tierID]
	end
	if (CLIENT and ix.loot.clientTierCache and ix.loot.clientTierCache[tierID]) then
		return ix.loot.clientTierCache[tierID]
	end
	return ix.loot.defaultTiers[tierID]
end

function ix.loot.GetAllTiers()
	local plugin = ix.plugin.Get("loot")
	if (plugin and plugin.data and plugin.data.customTiers and next(plugin.data.customTiers)) then
		return plugin.data.customTiers
	end
	if (CLIENT and ix.loot.clientTierCache and next(ix.loot.clientTierCache)) then
		return ix.loot.clientTierCache
	end
	return ix.loot.defaultTiers
end

function ix.loot.GetSortedTierIDs()
	local tiers = ix.loot.GetAllTiers()
	local sorted = {}
	for id, def in pairs(tiers) do
		sorted[#sorted + 1] = {id = id, order = def.order or 99}
	end
	table.sort(sorted, function(a, b)
		if (a.order == b.order) then return a.id < b.id end
		return a.order < b.order
	end)
	local result = {}
	for _, entry in ipairs(sorted) do
		result[#result + 1] = entry.id
	end
	return result
end

function ix.loot.GetTierColor(tierID)
	local def = ix.loot.GetTierData(tierID)
	if (def and def.color) then
		return Color(def.color[1] or 160, def.color[2] or 160, def.color[3] or 160)
	end
	return Color(160, 160, 160)
end

-- ── Resolución de tiers para un área ─────────────────────────
-- Devuelve lista de {id=tierID, weight=peso}
-- Prioridad: areaTiers override > preset.tiers > fallback

function ix.loot.ResolveTiers(areaName)
	local plugin = ix.plugin.Get("loot")
	if (!plugin or !plugin.data) then return {{id = "t1", weight = 100}} end

	local areaTiers = plugin.data.areaTiers and plugin.data.areaTiers[areaName]
	if (areaTiers and istable(areaTiers) and #areaTiers > 0) then
		local first = areaTiers[1]
		if (istable(first) and first.id) then
			return areaTiers
		end
	end

	return {{id = "t1", weight = 100}}
end

-- ── Roll de loot (2 etapas de ponderación) ───────────────────
-- Recibe lista de {id, weight}, devuelve tierID elegido y itemID

function ix.loot.RollLoot(tierList)
	if (!tierList or #tierList == 0) then return nil, nil end

	-- Etapa 1: elegir tier por peso
	local totalWeight = 0
	for _, entry in ipairs(tierList) do
		totalWeight = totalWeight + (tonumber(entry.weight) or 1)
	end

	local roll = math.random() * totalWeight
	local cumul = 0
	local chosenTierID = tierList[1].id

	for _, entry in ipairs(tierList) do
		cumul = cumul + (tonumber(entry.weight) or 1)
		if (roll < cumul) then
			chosenTierID = entry.id
			break
		end
	end

	-- Etapa 2: dentro del tier, elegir tabla de loot por peso
	local tierDef = ix.loot.GetTierData(chosenTierID)
	if (!tierDef or !tierDef.chances or #tierDef.chances == 0) then
		return chosenTierID, nil
	end

	local chancesTotal = 0
	for _, ch in ipairs(tierDef.chances) do
		chancesTotal = chancesTotal + (tonumber(ch[1]) or 1)
	end

	local chRoll = math.random() * chancesTotal
	local chCumul = 0
	local chosenTableKey = tierDef.chances[1][2]

	for _, ch in ipairs(tierDef.chances) do
		chCumul = chCumul + (tonumber(ch[1]) or 1)
		if (chRoll < chCumul) then
			chosenTableKey = ch[2]
			break
		end
	end

	-- Etapa 3: elegir item de la tabla
	-- Formato: "item" | {"item", peso} | {"item", peso, maxCantidad}
	local lootTable = ix.loot.tables[chosenTableKey]
	if (!lootTable or #lootTable == 0) then
		return chosenTierID, nil, 1
	end

	-- peso 0 para los ítems que no existen (addon no instalado, plugin retirado).
	-- Las entradas sin peso explícito usan el peso de su rareza (efg_icons):
	-- un objeto legendario sale mucho menos que uno común de la misma tabla.
	local function entryWeight(entry)
		local id = istable(entry) and entry[1] or entry
		local item = ix.item.list[id]
		if (!item) then return 0 end
		if (istable(entry) and tonumber(entry[2])) then return tonumber(entry[2]) end

		local rarityWeight = ix.efg and ix.efg.rarityWeight
		-- normalizado para que un común valga 1, igual que antes de la rareza
		return rarityWeight and (rarityWeight[item.rarity or "common"] or 100) / 100 or 1
	end

	local totalItemWeight = 0
	for _, entry in ipairs(lootTable) do
		totalItemWeight = totalItemWeight + entryWeight(entry)
	end

	if (totalItemWeight <= 0) then
		return chosenTierID, nil, 1
	end

	local itemRoll = math.random() * totalItemWeight
	local itemCumul = 0
	local itemID = istable(lootTable[1]) and lootTable[1][1] or lootTable[1]
	local itemMaxQty = 1

	for _, entry in ipairs(lootTable) do
		local id = istable(entry) and entry[1] or entry
		local w = entryWeight(entry)
		itemCumul = itemCumul + w
		if (w > 0 and itemRoll < itemCumul) then
			itemID = id
			itemMaxQty = istable(entry) and math.max(1, tonumber(entry[3]) or 1) or 1
			break
		end
	end

	local qty = itemMaxQty > 1 and math.random(1, itemMaxQty) or 1
	return chosenTierID, itemID, qty
end
