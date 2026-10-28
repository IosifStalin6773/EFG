-- Imágenes de "Tarkov Contents/Imgs" (UTILS) aplicadas a los ítems y a la UI.
-- Ítems:  materials/efg/utils/items/<archivo>.png
-- UI:     materials/efg/utils/ui/<archivo>.png
-- Tienen prioridad sobre los iconos de eftwiki (efg_eftdata), que quedan como
-- respaldo para los ítems sin imagen aquí.

ix.efg = ix.efg or {}
ix.efg.utils = ix.efg.utils or {}

local UTILS = ix.efg.utils

UTILS.itemDir = "efg/utils/items/"
UTILS.uiDir = "efg/utils/ui/"

-- uniqueID → archivo (sin .png). Las armas arc9_eft_* no hace falta listarlas:
-- su imagen se llama igual que el uniqueID.
UTILS.items = {
	armor_6b13 = "vivo_tarkov_item_6b13_flora",
	armor_6b2 = "vivo_tarkov_item_6b2",
	armor_6b23_1 = "vivo_tarkov_item_6b23",
	armor_6b43 = "vivo_tarkov_item_6b43_vest",
	armor_korund = "vivo_tarkov_item_korund",
	armor_paca = "vivo_tarkov_item_paca",
	armor_slick = "vivo_tarkov_item_slick_black",
	armor_trooper = "vivo_tarkov_item_trooper_tfo",
	armor_untar = "vivo_tarkov_item_untar_vest",
	helmet_6b47 = "vivo_tarkov_item_6b47",
	helmet_altyn = "vivo_tarkov_item_altyn",
	helmet_fast = "vivo_tarkov_item_fast_mt_black",
	helmet_kiver = "vivo_tarkov_item_kiverm",
	helmet_maska = "vivo_tarkov_item_shlem_maska_1sh",
	helmet_ssh68 = "vivo_tarkov_item_ssh_68",
	helmet_ulach = "vivo_tarkov_item_ulach_b",
	case_ammo = "danyaoxiang",
	case_med = "yiliaoxiang",
	case_weapon = "wuqixiang",
	case_item = "wupinxiang",
	secure_alpha = "vivo_tarkov_item_sc_alpha",
	secure_beta = "vivo_tarkov_item_sc_beta",
	secure_gamma = "vivo_tarkov_item_sc_gamma",
	secure_kappa = "vivo_tarkov_item_sc_kappa",
	placa_acero_c4 = "egp_armorplate",
	placa_ceramica_c3 = "egp_armorplate",
	placa_compuesta_c5 = "egp_armorplate",
	placa_pesada_c6 = "egp_armorplate",
	rig_6sh112 = "vivo_tarkov_item_umtbs_6sh112",
	rig_a18 = "vivo_tarkov_item_ars_arma_a18",
	rig_alpha = "vivo_tarkov_item_alpha_cr",
	rig_m2 = "vivo_tarkov_item_m2",
	rig_mkiii = "vivo_tarkov_item_mk3_chest_rig",
	rig_scav = "vivo_tarkov_item_scav_vest",
	rig_tarzan = "vivo_tarkov_item_tarzan",
	rig_tv109 = "vivo_tarkov_item_tv_109",
	rig_wild = "vivo_tarkov_item_thunderbolt",
	efg_armband_blue = "ent_jack_gmod_ezarmor_larmbandcolor",
	efg_armband_green = "ent_jack_gmod_ezarmor_larmbandcolor",
	efg_armband_red = "ent_jack_gmod_ezarmor_larmbandcolor",
	efg_eye_6b34 = "vivo_tarkov_item_6b34",
	efg_eye_aviator = "vivo_tarkov_item_aviator_glasses",
	efg_eye_ess = "vivo_tarkov_item_crossbow_glasses",
	efg_eye_oakley = "vivo_tarkov_item_gascan_glasses",
	efg_eye_rayban = "vivo_tarkov_item_raybench_glasses",
	efg_eye_tactical = "vivo_tarkov_item_tactical_glasses",
	efg_face_3m = "vivo_tarkov_item_respirator_3m",
	efg_face_balaclava_black = "vivo_tarkov_item_balaclava_black",
	efg_face_coldgear = "vivo_tarkov_item_cold_fear",
	efg_face_nomex = "vivo_tarkov_item_nomex_balaclava",
	efg_face_respirator = "vivo_tarkov_item_devtac_ronin",
	efg_face_scavbalaclava = "vivo_tarkov_item_smoke_balaclava",
	efg_face_shemagh = "vivo_tarkov_item_shemagh_green",
	efg_face_skullmask = "vivo_tarkov_item_deadly_skull",
	efg_face_sotr = "vivo_tarkov_item_sotr",
	efg_hat_police = "vivo_tarkov_item_police",
	efg_hat_slots = "vivo_tarkov_item_beanie",
	efg_hat_ufpro = "vivo_tarkov_item_usec_cap_tan",
	efg_hat_ushanka = "vivo_tarkov_item_ushanka",
	efg_headset_comtac2 = "vivo_tarkov_item_comtac",
	efg_headset_comtac4 = "vivo_tarkov_item_comtac_4",
	efg_headset_gssh01 = "vivo_tarkov_item_gssh_01",
	efg_headset_m32 = "vivo_tarkov_item_m32",
	efg_headset_msa = "vivo_tarkov_item_sordin",
	efg_headset_razor = "vivo_tarkov_item_razor",
	efg_headset_tsport = "vivo_tarkov_item_tactical_sport",
	efg_headset_xcel = "vivo_tarkov_item_xcel",
	ai2 = "ojs_ai2",
	analgin = "vivo_tarkov_item_med_analgin",
	car = "vivo_tarkov_item_med_car_first_aid",
	cms = "vivo_tarkov_item_med_cms",
	esmarch = "weapon_eft_esmarch",
	ferula = "vivo_tarkov_item_med_alusplint",
	salewa = "vivo_tarkov_item_med_salewa",
	adrenaline = "vivo_tarkov_item_med_adrenaline",
	augmentin = "vivo_tarkov_item_med_augmentin",
	ibuprofeno = "ojs_ibuprofen",
	morphine = "vivo_tarkov_item_med_morphine",
	vendas = "ojs_armybandage",
	stim_adrenaline = "vivo_tarkov_item_med_adrenaline",
	stim_morphine = "vivo_tarkov_item_med_morphine",
	ibuprofeno_efg = "ojs_ibuprofen",
	venda_militar = "ojs_armybandage",
	ferula_aluminio = "vivo_tarkov_item_med_alusplint",
	kit_reparacion_armadura = "ojs_armorrepairkit",
	bp_6sh118 = "vivo_tarkov_item_6sh118",
	bp_blackjack = "vivo_tarkov_item_blackjack",
	bp_daypack = "vivo_tarkov_item_lbt_8005a_day_pack",
	bp_pilgrim = "vivo_tarkov_item_pilgrim",
	bp_scav = "vivo_tarkov_item_scav_backpack",
	bp_trizip = "vivo_tarkov_item_tri_zip",
	nvg = "vivo_tarkov_item_pnv_10t_nvg",
}

-- Icono vacío de cada ranura de equipo (kind de ix.GetEquipSlotKind / weaponCategory).
UTILS.slots = {
	headset = "headphones", helmet = "head", facecover = "face", eyewear = "eye", armor = "armor",
	rig = "rig_slot", backpack = "backpack_slot", secure = "secure_slot",
	primary = "primary_sling", primary2 = "primary_back", secondary = "holster", melee = "scabbard",
}

-- Habilidad (ix.perks id) → icono de habilidad EFT.
UTILS.perks = {
	aguante = "vitality", fuerza = "strength", resistencia = "endurance", medicina = "surgery",
	explorador = "perception", superviviente = "metabolism", radiacion = "immunity",
}

-- Categoría de Helix → icono de categoría EFT (flea).
UTILS.categories = {
	["Armas"] = "assault_rifles", ["Medicamentos"] = "heal", ["Comestibles"] = "food", ["Bebidas"] = "water",
	["Chalecos"] = "armor", ["Cascos"] = "head", ["Mochilas"] = "backpack_slot", ["Contenedores"] = "secure_slot",
	["Equipamiento"] = "health",
}

-- Insignia de nivel del PMC (rangos de EFT).
function UTILS.LevelBadge(level)
	level = math.max(tonumber(level) or 1, 1)
	if (level < 5) then return UTILS.uiDir .. "1-4.png" end
	if (level >= 75) then return UTILS.uiDir .. "75-~.png" end

	local from = math.floor(level / 5) * 5
	return UTILS.uiDir .. from .. "-" .. (from + 4) .. ".png"
end

function UTILS.UIPath(name)
	return name and (UTILS.uiDir .. name .. ".png")
end

-- Ruta del icono de un ítem si la imagen está en el disco.
function UTILS.ItemPath(uniqueID)
	local name = UTILS.items[uniqueID] or (uniqueID:find("^arc9_eft_") and uniqueID)
	if (!name) then return end

	local path = UTILS.itemDir .. name .. ".png"
	if (file.Exists("materials/" .. path, "GAME")) then return path end
end

-- Después de efg_eftdata (timer 0) y de las armas de efg_arc9.
function UTILS.Apply()
	local n = 0

	for uniqueID, item in pairs(ix.item.list) do
		local path = UTILS.ItemPath(uniqueID)

		if (path) then
			item.iconMaterial = path
			n = n + 1
		end
	end

	if (ix.efg.icons.Reset) then ix.efg.icons.Reset() end

	return n
end

if (CLIENT) then
	local mats = {}

	-- Dibuja una imagen de UI ajustada al rectángulo sin deformarla.
	function UTILS.DrawUI(name, x, y, w, h, col)
		local path = UTILS.UIPath(name)
		if (!path) then return false end

		if (mats[path] == nil) then
			local mat = Material(path, "smooth mips")
			mats[path] = !mat:IsError() and mat or false
		end

		local mat = mats[path]
		if (!mat) then return false end

		local tw, th = mat:Width(), mat:Height()
		local scale = math.min(w / math.max(tw, 1), h / math.max(th, 1))
		local dw, dh = tw * scale, th * scale

		surface.SetMaterial(mat)
		surface.SetDrawColor(col or color_white)
		surface.DrawTexturedRect(math.floor(x + (w - dw) / 2), math.floor(y + (h - dh) / 2), math.floor(dw), math.floor(dh))

		return true
	end
end
