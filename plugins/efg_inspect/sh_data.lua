-- Datos de inspección: stats base de las armas, accesorios compatibles por
-- arma y tabla de balística de la munición. El cálculo de stats con
-- accesorios (ix.efg.inspect.Calc) lo usan la ventana y efg_mods.

ix.efg = ix.efg or {}
ix.efg.inspect = ix.efg.inspect or {}

local INS = ix.efg.inspect

-- ─── Stats base por categoría (si el arma no tiene entrada propia) ───────────
-- ergo 0-100, retroceso vertical/horizontal (puntos EFT), precisión en MOA
-- (menos es mejor), peso en kg (si falta, el weight del ítem).
INS.categoryBase = {
	primary   = {ergo = 45, recoilV = 140, recoilH = 330, accuracy = 3.0},
	primary2  = {ergo = 45, recoilV = 140, recoilH = 330, accuracy = 3.0},
	secondary = {ergo = 75, recoilV = 380, recoilH = 260, accuracy = 8.0},
	melee     = {ergo = 90, recoilV = 0,   recoilH = 0,   accuracy = 0},
}

-- ─── Armas ───────────────────────────────────────────────────────────────────
-- stats_base: sobrescribe los de la categoría.
-- attachments: por ranura, lista de uniqueID compatibles. Si un arma no
-- tiene attachments, acepta cualquier accesorio de las ranuras de su
-- categoría (ix.efg.mods.weaponSlots). Si la ranura no está en la lista, el
-- arma no la tiene.
local AK_MUZZLE = {"bocacha_freno", "bocacha_supresor"}
local SIGHTS = {"mira_reflejo", "mira_aumento"}

INS.weapons = {
	arc9_eft_ak74 = {
		stats_base = {ergo = 40, recoilV = 145, recoilH = 333, accuracy = 3.4, weight = 3.3},
		attachments = {sight = SIGHTS, muzzle = AK_MUZZLE, grip = {"empunadura_vertical"}, stock = {"culata_ajustable"},
			tactical = {"tactico_linterna"}, mag = {"cargador_ampliado"}}
	},
	arc9_eft_akm = {
		stats_base = {ergo = 38, recoilV = 160, recoilH = 380, accuracy = 3.8, weight = 3.5},
		attachments = {sight = SIGHTS, muzzle = AK_MUZZLE, grip = {"empunadura_vertical"}, stock = {"culata_ajustable"},
			tactical = {"tactico_linterna"}, mag = {"cargador_ampliado"}}
	},
	arc9_eft_ak74m = {stats_base = {ergo = 44, recoilV = 140, recoilH = 330, accuracy = 3.3, weight = 3.4}},
	arc9_eft_aks74u = {
		stats_base = {ergo = 52, recoilV = 163, recoilH = 342, accuracy = 5.2, weight = 2.7},
		attachments = {sight = {"mira_reflejo"}, muzzle = {"bocacha_supresor"}, stock = {"culata_ajustable"}, mag = {"cargador_ampliado"}}
	},
	arc9_eft_m4a1 = {stats_base = {ergo = 50, recoilV = 120, recoilH = 290, accuracy = 2.6, weight = 2.9}},
	arc9_eft_hk416 = {stats_base = {ergo = 48, recoilV = 115, recoilH = 280, accuracy = 2.4, weight = 3.3}},
	arc9_eft_mp5 = {
		stats_base = {ergo = 70, recoilV = 52, recoilH = 165, accuracy = 6.0, weight = 2.6},
		attachments = {sight = {"mira_reflejo"}, muzzle = {"bocacha_supresor"}, tactical = {"tactico_linterna"}, mag = {"cargador_ampliado"}}
	},
	arc9_eft_svds = {stats_base = {ergo = 30, recoilV = 380, recoilH = 210, accuracy = 1.2, weight = 4.5}},
	arc9_eft_m700 = {stats_base = {ergo = 33, recoilV = 400, recoilH = 180, accuracy = 0.6, weight = 4.1}},
	arc9_eft_glock17 = {
		stats_base = {ergo = 85, recoilV = 400, recoilH = 250, accuracy = 7.5, weight = 0.7},
		attachments = {sight = {"mira_reflejo"}, muzzle = {"bocacha_supresor"}, tactical = {"tactico_linterna"}, mag = {"cargador_ampliado"}}
	},
	arc9_eft_pm = {stats_base = {ergo = 82, recoilV = 410, recoilH = 290, accuracy = 9.0, weight = 0.7}},
}

-- ─── Balística ───────────────────────────────────────────────────────────────
-- clave = tipo de munición de GMod/ARC9 en minúsculas (item.ammo de los
-- ítems de munición, item.ammoType de las armas). pen sale de la tabla de
-- efg_gear (armor.ammoPen) si no se pone aquí.
--   damage    daño a la carne
--   pen       penetración de blindaje (0-100)
--   armorDmg  % de daño a la armadura
--   speed     velocidad inicial (m/s)
--   frag      probabilidad de fragmentación (%)
INS.ballistics = {
	["9x18pm"]   = {name = "9x18 mm PM Pst gzh", damage = 50, armorDmg = 26, speed = 298, frag = 15},
	["9x19para"] = {name = "9x19 mm Pst gzh",    damage = 54, armorDmg = 33, speed = 457, frag = 15},
	["9x19"]     = {name = "9x19 mm Pst gzh",    damage = 54, armorDmg = 33, speed = 457, frag = 15},
	["pistol"]   = {name = "Munición de pistola", damage = 52, armorDmg = 30, speed = 380, frag = 15},
	["357"]      = {name = ".357 Magnum JHP",    damage = 88, armorDmg = 30, speed = 440, frag = 20},
	["smg1"]     = {name = "Munición de subfusil", damage = 50, armorDmg = 35, speed = 420, frag = 10},
	["4.6x30"]   = {name = "4.6x30 mm FMJ SX",   damage = 43, armorDmg = 41, speed = 620, frag = 10},
	["5.7x28"]   = {name = "5.7x28 mm SS190",    damage = 49, armorDmg = 43, speed = 715, frag = 20},
	["545x39"]   = {name = "5.45x39 mm PS gs",   damage = 56, armorDmg = 52, speed = 890, frag = 40},
	["5.45x39"]  = {name = "5.45x39 mm PS gs",   damage = 56, armorDmg = 52, speed = 890, frag = 40},
	["556x45"]   = {name = "5.56x45 mm M855",    damage = 54, armorDmg = 53, speed = 922, frag = 40},
	["5.56x45"]  = {name = "5.56x45 mm M855",    damage = 54, armorDmg = 53, speed = 922, frag = 40},
	["ar2"]      = {name = "Munición de fusil",  damage = 56, armorDmg = 52, speed = 880, frag = 30},
	["762x39"]   = {name = "7.62x39 mm PS",      damage = 57, armorDmg = 52, speed = 700, frag = 25},
	["7.62x39"]  = {name = "7.62x39 mm PS",      damage = 57, armorDmg = 52, speed = 700, frag = 25},
	["762x51"]   = {name = "7.62x51 mm M80",     damage = 80, armorDmg = 66, speed = 833, frag = 17},
	["7.62x51"]  = {name = "7.62x51 mm M80",     damage = 80, armorDmg = 66, speed = 833, frag = 17},
	["762x54r"]  = {name = "7.62x54R LPS gzh",   damage = 81, armorDmg = 78, speed = 853, frag = 18},
	["7.62x54r"] = {name = "7.62x54R LPS gzh",   damage = 81, armorDmg = 78, speed = 853, frag = 18},
	["sniperround"] = {name = "Munición de francotirador", damage = 82, armorDmg = 70, speed = 850, frag = 15},
	["338lapua"] = {name = ".338 Lapua Magnum AP", damage = 115, armorDmg = 83, speed = 849, frag = 5},
	["12g"]      = {name = "12/70 perdigón 7mm", damage = 39 * 8, armorDmg = 26, speed = 415, frag = 0, pellets = 8},
	["buckshot"] = {name = "12/70 perdigón 7mm", damage = 39 * 8, armorDmg = 26, speed = 415, frag = 0, pellets = 8},
	["default"]  = {name = "Munición",           damage = 50, armorDmg = 35, speed = 600, frag = 10},
}

-- datos de balística de un tipo de munición (con la pen de efg_gear)
function INS.AmmoStats(ammoName)
	local key = string.lower(ammoName or "")
	local data = table.Copy(INS.ballistics[key] or INS.ballistics.default)
	local armor = ix.efg.armor

	data.key = key
	data.pen = data.pen or (armor and armor.GetBulletPen and armor.GetBulletPen(key)) or 25

	return data
end

-- ─── Ranuras y compatibilidad ────────────────────────────────────────────────
function INS.WeaponData(weapon)
	return INS.weapons[weapon.uniqueID] or {}
end

-- ranuras del arma: las de su tabla attachments o las de su categoría
function INS.GetSlots(weapon)
	local data = INS.WeaponData(weapon)
	local mods = ix.efg.mods
	local base = mods and mods.GetSlots(weapon) or {}

	if (!data.attachments) then return base end

	local out = {}
	for _, slot in ipairs(base) do
		if (data.attachments[slot]) then out[#out + 1] = slot end
	end

	return out
end

-- ¿se puede montar este accesorio (tabla de ítem) en el arma?
function INS.IsCompatible(weapon, mod)
	if (!mod or !mod.isEFGMod) then return false end
	if (!table.HasValue(INS.GetSlots(weapon), mod.modSlot)) then return false end

	local data = INS.WeaponData(weapon)
	if (!data.attachments) then return true end

	return table.HasValue(data.attachments[mod.modSlot] or {}, mod.uniqueID)
end

-- ─── Cálculo de stats ────────────────────────────────────────────────────────
-- stats base del arma sin accesorios
function INS.BaseStats(weapon)
	local base = table.Copy(INS.categoryBase[weapon.weaponCategory] or INS.categoryBase.primary)
	local own = INS.WeaponData(weapon).stats_base

	if (own) then table.Merge(base, own) end

	if (!own or !own.ergo) then base.ergo = weapon.ergonomics or base.ergo end
	base.weight = base.weight or weapon.weight or 0

	return base
end

-- Suma o resta los accesorios: modsBySlot = {slot = uniqueID} (por defecto
-- los instalados). ergoDelta suma, recoilMult y accuracyMult multiplican,
-- weight suma.
function INS.Calc(weapon, modsBySlot)
	local stats = INS.BaseStats(weapon)
	local recoil, accuracy = 1, 1

	modsBySlot = modsBySlot or (ix.efg.mods and ix.efg.mods.GetMods(weapon)) or {}

	for _, uniqueID in pairs(modsBySlot) do
		local mod = ix.item.list[uniqueID]

		if (mod) then
			stats.ergo = stats.ergo + (mod.ergoDelta or 0)
			stats.weight = stats.weight + (mod.weight or 0)
			recoil = recoil * (mod.recoilMult or 1)
			accuracy = accuracy * (mod.accuracyMult or 1)
		end
	end

	stats.ergo = math.Clamp(math.Round(stats.ergo), 0, 100)
	stats.recoilV = math.Round(stats.recoilV * recoil)
	stats.recoilH = math.Round(stats.recoilH * recoil)
	stats.accuracy = math.Round(stats.accuracy * accuracy, 2)
	stats.weight = math.Round(stats.weight, 3)

	return stats
end

-- stats si se monta (mod) o se quita (mod = false) algo en una ranura
function INS.CalcWith(weapon, slot, uniqueID)
	local installed = table.Copy(ix.efg.mods and ix.efg.mods.GetMods(weapon) or {})
	installed[slot] = uniqueID or nil

	return INS.Calc(weapon, installed)
end
