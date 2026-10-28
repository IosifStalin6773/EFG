-- Stock inicial y lo que compra cada comerciante de EFT.
-- Solo se aplica la primera vez que se spawnea un trader (sin datos guardados);
-- después el admin lo puede cambiar todo desde /TraderAdmin.

-- minRep por nivel de lealtad (ver ix.traders.repLevels)
ix.traders.loyaltyRep = {0, 200, 500, 800}

-- {uniqueID, cantidad máxima, nivel de lealtad, precio (opcional)}
ix.traders.defaultStock = {
	prapor = {
		{"arc9_eft_pm", 6, 1}, {"arc9_eft_tt33", 5, 1}, {"arc9_eft_mr43", 4, 1}, {"arc9_eft_toz106", 4, 1},
		{"arc9_eft_aks74u", 4, 1}, {"arc9_eft_sks", 3, 1},
		{"arc9_eft_ak74", 3, 2}, {"arc9_eft_akm", 3, 2}, {"arc9_eft_pp1901", 3, 2}, {"arc9_eft_mp443", 3, 2},
		{"arc9_eft_ak74m", 2, 3}, {"arc9_eft_ak103", 2, 3}, {"arc9_eft_svds", 2, 3}, {"arc9_eft_rpk16", 1, 3},
		{"arc9_eft_ak12", 1, 4}, {"arc9_eft_pkm", 1, 4},
		{"ammo_pistol", 30, 1}, {"ammo_smg1", 30, 1}, {"ammo_ar2", 30, 1}, {"ammo_buckshot", 30, 1},
		{"ammo_357", 10, 3}
	},
	therapist = {
		{"analgin", 10, 1}, {"ai2", 10, 1}, {"esmarch", 10, 1}, {"ferula", 10, 1},
		{"water", 15, 1}, {"canned", 15, 1}, {"bread", 10, 1}, {"milk", 10, 1},
		{"car", 8, 2}, {"salewa", 5, 2}, {"energy", 8, 2},
		{"ifak", 5, 3}, {"cms", 4, 3},
		{"augmentin", 3, 4}
	},
	fence = {
		{"arc9_eft_mr133", 2, 1}, {"arc9_eft_kedr", 2, 1}, {"arc9_eft_ppsh41", 2, 1}, {"arc9_eft_mosin_infantry", 2, 1},
		{"bp_scav", 4, 1}, {"armor_paca", 2, 1}, {"helmet_ssh68", 3, 1}
	},
	skier = {
		{"arc9_eft_vpo136", 3, 1}, {"arc9_eft_kedr", 3, 1}, {"arc9_eft_mp153", 3, 1},
		{"arc9_eft_ak101", 2, 2}, {"arc9_eft_ak102", 2, 2}, {"arc9_eft_saiga12k", 2, 2}, {"arc9_eft_glock17", 3, 2},
		{"arc9_eft_ak104", 2, 3}, {"arc9_eft_vss", 1, 3}, {"arc9_eft_asval", 1, 3},
		{"arc9_eft_sr3", 1, 4}, {"arc9_eft_ash12", 1, 4},
		{"secure_beta", 1, 3, 600000}
	},
	peacekeeper = {
		{"arc9_eft_m9a3", 3, 1}, {"arc9_eft_m1911", 3, 1}, {"arc9_eft_ump", 3, 1},
		{"arc9_eft_mp5", 3, 2}, {"arc9_eft_m4a1", 2, 2}, {"arc9_eft_m870", 2, 2},
		{"arc9_eft_hk416", 2, 3}, {"arc9_eft_mp7a1", 2, 3}, {"arc9_eft_scarl", 2, 3}, {"arc9_eft_m700", 1, 3},
		{"arc9_eft_scarh", 1, 4}, {"arc9_eft_mk18_mjolnir", 1, 4}, {"arc9_eft_mcx", 1, 4}
	},
	mechanic = {
		{"arc9_eft_glock17", 3, 1}, {"arc9_eft_mp9", 2, 1},
		{"arc9_eft_tx15", 2, 2}, {"arc9_eft_mpx", 2, 2}, {"arc9_eft_g36", 2, 2},
		{"arc9_eft_sr25", 1, 3}, {"arc9_eft_rsass", 1, 3}, {"arc9_eft_vector45", 1, 3},
		{"arc9_eft_g28", 1, 4}, {"arc9_eft_t5000", 1, 4},
		{"kit_reparacion_armadura", 10, 1}
	},
	ragman = {
		{"bp_redfox", 5, 1}, {"bp_daypack", 4, 1}, {"armor_6b2", 3, 1}, {"helmet_kiver", 3, 1}, {"armor_untar", 3, 1},
		{"bp_trizip", 3, 2}, {"armor_6b23_1", 3, 2}, {"helmet_6b47", 3, 2}, {"helmet_ulach", 2, 2},
		{"bp_pilgrim", 2, 3}, {"armor_6b13", 2, 3}, {"armor_trooper", 2, 3}, {"helmet_fast", 2, 3},
		{"bp_blackjack", 1, 4}, {"bp_6sh118", 1, 4}, {"armor_korund", 1, 4}, {"armor_slick", 1, 4},
		{"armor_6b43", 1, 4}, {"helmet_maska", 1, 4}, {"helmet_altyn", 1, 4}
	},
	jaeger = {
		{"arc9_eft_mosin_infantry", 3, 1}, {"arc9_eft_mosin_sniper", 2, 1}, {"arc9_eft_svt", 2, 1},
		{"arc9_eft_sv98", 2, 2}, {"arc9_eft_vpo215", 2, 2}, {"arc9_eft_m1a", 1, 2},
		{"arc9_eft_dvl10", 1, 3}, {"arc9_eft_ai_axmc", 1, 4},
		{"canned", 10, 1}, {"sausage", 10, 1}, {"vodka", 5, 1},
		{"ammo_ar2", 30, 1}, {"ammo_357", 10, 2}
	}
}

-- Categorías de ítems que compra cada uno (se compara el principio del nombre)
ix.traders.buyCategories = {
	prapor      = {"Armas", "Municion", "Accesorios"},
	therapist   = {"Medicamentos", "Comestibles", "Bebidas", "Drogas"},
	skier       = {"Armas", "Accesorios", "Recursos", "Herramientas", "Datos Técnicos"},
	peacekeeper = {"Armas", "Accesorios", "Datos Técnicos"},
	mechanic    = {"Armas", "Accesorios", "Herramientas", "Recursos"},
	ragman      = {"Chalecos", "Cascos", "Mochilas", "Equipamiento"},
	jaeger      = {"Comestibles", "Bebidas", "Recursos", "Herramientas"}
	-- fence compra todo
}

local function categoryMatches(category, list)
	if (!category) then return false end

	for _, prefix in ipairs(list) do
		if (category:sub(1, #prefix) == prefix) then
			return true
		end
	end

	return false
end

-- Rellena stock y lista de compra de un trader recién creado
function ix.traders.ApplyDefaultStock(traderEnt, factionKey)
	local inventory = {}

	for _, entry in ipairs(ix.traders.defaultStock[factionKey] or {}) do
		local itemID, qty, loyalty, price = entry[1], entry[2], entry[3], entry[4]

		if (ix.item.list[itemID]) then
			price = price or ix.traders.GetGlobalPrice(itemID)

			inventory[#inventory + 1] = {
				itemID = itemID,
				qty = qty,
				maxQty = qty,
				price = (price and price > 0) and price or 1000,
				buyPrice = 0,
				minRep = ix.traders.loyaltyRep[loyalty] or 0,
				playerStock = false
			}
		end
	end

	local buyList = {}
	local categories = ix.traders.buyCategories[factionKey]

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (!itemTable.noBusiness and !itemTable.noLoot and itemTable.category != "Misión"
			and (factionKey == "fence" or (categories and categoryMatches(itemTable.category, categories)))) then
			buyList[#buyList + 1] = uniqueID
		end
	end

	table.sort(buyList)

	traderEnt.inventory = inventory
	traderEnt.buyWhitelist = buyList
	traderEnt.maxSlots = math.max(traderEnt.maxSlots or 20, #inventory + 10)
end
