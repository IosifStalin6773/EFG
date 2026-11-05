local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Armas ARC9"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Convierte en ítems de Helix todas las armas ARC9 de la colección (arc9_eft_*)."

PLUGIN.prefixes = {"arc9_eft_", "arc9_wtt_"}

PLUGIN.skipAmmo = {
	grenade = true,
	smg1_grenade = true,
	rpg_round = true
}

PLUGIN.slotInfo = {
	[0] = {category = "melee",     w = 1, h = 2, weight = 0.6, price = 9000},
	[1] = {category = "secondary", w = 2, h = 1, weight = 0.9, price = 18000},
	[2] = {category = "primary",   w = 4, h = 2, weight = 3.2, price = 45000},
	[3] = {category = "primary",   w = 5, h = 2, weight = 4.5, price = 75000}
}

PLUGIN.prices = {
	arc9_eft_pm = 9000, arc9_eft_tt33 = 11000, arc9_eft_mp443 = 21000, arc9_eft_glock17 = 30000,
	arc9_eft_m1911 = 34000, arc9_eft_usp = 36000, arc9_eft_fn57 = 48000, arc9_eft_deagle_l6 = 70000,
	arc9_eft_toz106 = 11000, arc9_eft_mr133 = 20000, arc9_eft_mr43 = 16000, arc9_eft_mr153 = 26000,
	arc9_eft_kedr = 22000, arc9_eft_ppsh41 = 24000, arc9_eft_pp1901 = 28000, arc9_eft_mp5 = 45000,
	arc9_eft_aks74u = 32000, arc9_eft_sks = 30000, arc9_eft_vpo136 = 28000, arc9_eft_mosin_infantry = 35000,
	arc9_eft_ak74 = 42000, arc9_eft_akm = 45000, arc9_eft_ak74m = 55000, arc9_eft_ak103 = 60000,
	arc9_eft_m4a1 = 85000, arc9_eft_hk416 = 110000, arc9_eft_mdr = 120000, arc9_eft_scarh = 130000,
	arc9_eft_svds = 90000, arc9_eft_m700 = 100000, arc9_eft_dvl10 = 140000, arc9_eft_ai_axmc = 250000,
	arc9_eft_pkm = 180000, arc9_eft_rpk16 = 95000, arc9_eft_asval = 110000, arc9_eft_vss = 105000
}

local function matchesPrefix(class)
	for _, prefix in ipairs(PLUGIN.prefixes) do
		if (class:sub(1, #prefix) == prefix) then return true end
	end
	return false
end

-- Pistolas de EFT (ranura PISTOLERA). Va por clase porque el Slot de ARC9 no
-- viene en todas, y sin Slot caían en PRINCIPAL.
PLUGIN.pistols = {
	arc9_eft_pm = true, arc9_eft_tt33 = true, arc9_eft_mp443 = true, arc9_eft_glock17 = true,
	arc9_eft_m1911 = true, arc9_eft_usp = true, arc9_eft_fn57 = true, arc9_eft_deagle_l6 = true
}

-- Categoría de ranura de EFT de un SWEP: "secondary" (pistolera), "melee" (vaina) o "primary".
-- Orden: lista de pistolas, después HoldType/PrimaryBash, después Slot de ARC9.
function PLUGIN:GetCategory(swep, class)
	if (self.pistols[class]) then return "secondary" end

	local hold = string.lower(tostring(swep.HoldType or ""))

	if (class:find("melee") or swep.PrimaryBash or hold == "melee" or hold == "melee2" or hold == "knife" or hold == "fist") then
		return "melee"
	end

	if (hold == "pistol" or hold == "revolver") then return "secondary" end

	if (swep.Slot == 0) then return "melee" end
	if (swep.Slot == 1) then return "secondary" end

	return "primary"
end

-- Ergonomía: 95 - peso * 14, entre 20 y 90
local function ergonomicsFor(weight)
	return math.Clamp(math.Round(95 - weight * 14), 20, 90)
end

-- Configura Equip/Unequip/OnLoadout para armas primarias de forma que soporten
-- dos ranuras: "primary" (PRINCIPAL) y "primary2" (PRINCIPAL 2).
local function setupPrimary(ITEM)
	local origEquip   = ITEM.functions and ITEM.functions.Equip   and ITEM.functions.Equip.OnRun
	local origUnequip = ITEM.functions and ITEM.functions.Unequip and ITEM.functions.Unequip.OnRun
	local origLoadout = ITEM.OnLoadout

	ITEM.functions = ITEM.functions or {}
	ITEM.functions.Equip = ITEM.functions.Equip or {}
	ITEM.functions.Equip.OnRun = function(item)
		local client = item.player
		if (not IsValid(client)) then return end

		-- Elige la ranura libre: "primary" primero, luego "primary2"
		local carry = client.carryWeapons or {}
		local slot
		if (not carry["primary"]) then
			slot = "primary"
		elseif (not carry["primary2"]) then
			slot = "primary2"
		else
			client:Notify("Ya llevas dos armas primarias.")
			return false
		end

		item:SetData("efgSlot", slot)
		item.weaponCategory = slot

		if (origEquip) then return origEquip(item) end
	end

	ITEM.functions.Unequip = ITEM.functions.Unequip or {}
	ITEM.functions.Unequip.OnRun = function(item)
		local slot = item:GetData("efgSlot") or "primary"
		item.weaponCategory = slot
		item:SetData("efgSlot", nil)
		if (origUnequip) then return origUnequip(item) end
	end

	ITEM.OnLoadout = function(item, client)
		local slot = item:GetData("efgSlot") or "primary"
		item.weaponCategory = slot
		if (origLoadout) then return origLoadout(item, client) end
	end
end


-- Aplica el modificador de ergonomía al SWEP cuando se equipa.
-- Ergo alta (90) = ADS más rápido; ergo baja (20) = ADS más lento.
-- Fórmula: mult = 1 - (ergo - 55) * 0.008 ; rango ~0.72x a ~1.28x
local function applyErgonomics(item, client, weapon)
	-- con efg_mods la ergonomía incluye los accesorios instalados
	local ergo = item.GetErgonomics and item:GetErgonomics() or item.ergonomics or 55
	local mult = math.Clamp(1.0 - (ergo - 55) * 0.008, 0.5, 1.5)

	if (isnumber(weapon.AimDownSightsTime)) then
		weapon.AimDownSightsTime = weapon.AimDownSightsTime * mult
	end

	if (isnumber(weapon.AimDownSightsTimeIronsight)) then
		weapon.AimDownSightsTimeIronsight = weapon.AimDownSightsTimeIronsight * mult
	end

	-- retroceso de los accesorios (efg_mods). Sin probar con ARC9: solo se
	-- toca si el SWEP expone RecoilUp/RecoilSide como números.
	local recoil = ix.efg and ix.efg.mods and ix.efg.mods.GetRecoilMult(item) or 1

	if (recoil != 1) then
		for _, key in ipairs({"RecoilUp", "RecoilSide"}) do
			if (isnumber(weapon[key])) then weapon[key] = weapon[key] * recoil end
		end
	end
end

function PLUGIN:InitializedPlugins()
	local count = 0

	for _, stored in ipairs(weapons.GetList()) do
		local class = (stored.ClassName or ""):lower()

		if (matchesPrefix(class) and !class:find("base") and !ix.item.list[class]) then
			local swep = weapons.Get(class) or stored
			local ammo = tostring(swep.Ammo or (swep.Primary and swep.Primary.Ammo) or ""):lower()

			if (swep.Spawnable != false and !self.skipAmmo[ammo]) then
				local category = self:GetCategory(swep, class)
				local info = self.slotInfo[2]
				if (category == "melee") then
					info = self.slotInfo[0]
				elseif (category == "secondary") then
					info = self.slotInfo[1]
				elseif (swep.Slot == 3) then
					info = self.slotInfo[3]
				end

				-- con arc9_support: base nativa (presets de accesorios, banco, stats EFT)
				local base = ix.item.base["base_arc9_weapons"] and "base_arc9_weapons" or "base_weapons"
				local ITEM = ix.item.Register(class, base, nil, nil, true)
				ITEM.name           = isstring(swep.PrintName) and swep.PrintName or class
				ITEM.description    = isstring(swep.Description) and swep.Description or (isstring(swep.Class) and swep.Class or "Arma")
				ITEM.model          = swep.WorldModel or "models/weapons/w_rif_ak47.mdl"
				ITEM.class          = class
				ITEM.weaponCategory = category
				ITEM.width          = info.w
				ITEM.height         = info.h
				ITEM.weight         = info.weight
				ITEM.price          = self.prices[class] or info.price
				ITEM.category       = "Armas"
				ITEM.isARC9         = true
				ITEM.bDropOnDeath   = true
				ITEM.ammoType       = ammo
				ITEM.ergonomics     = ergonomicsFor(info.weight)
				ITEM.OnEquipWeapon  = applyErgonomics

				ITEM.GetDescription = function(item)
					local caliber = item.ammoType and item.ammoType ~= "" and item.ammoType or "—"
					return ("%s\n\nErgonomía: %d  |  Calibre: %s  |  Peso: %.1f kg"):format(
						item.description, item.ergonomics or 55, caliber, item.weight or 0)
				end

				if (category == "primary") then setupPrimary(ITEM) end

				count = count + 1
			end
		end
	end

	if (SERVER and count > 0) then
		MsgC(Color(120, 200, 90), "[EFG] ", color_white, count .. " armas ARC9 registradas como ítems\n")
	end
end

ix.util.Include("cl_plugin.lua")
