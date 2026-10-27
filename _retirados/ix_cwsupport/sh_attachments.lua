ATTACHMENT_SIGHT    = 1
ATTACHMENT_BARREL   = 2
ATTACHMENT_LASER    = 3
ATTACHMENT_MAGAZINE = 4
ATTACHMENT_GRIP     = 5
ATTACHMENT_SPECIAL  = 6  -- radiadores, condensadores

local attItems = {}

-- ═══════════════════════════════════════════════════════════════
--  TIER 1 — Revolver, Padonak, Duplet, Hellsing
-- ═══════════════════════════════════════════════════════════════
--
--  Revolver Attachments:
--    [1] Barrel → kry_metro_bigbarrel_revolver | kry_metro_glushak_revolver
--    [2] Stock  → kry_metro_revolver_stock
--
--  Padonak Attachments:
--    [1] Barrel → kry_metro_glushak_revolver | kry_metro_bigbarrel_padonak
--    [2] Stock  → kry_metro_revolver_stock
--
--  Duplet Attachments:
--    [1] Barrel → kry_metro_duplet_bigbarrel | kry_metro_duplet_silencer
--    [2] Stock  → kry_metro_duplet_stock
--
--  Hellsing Attachments:
--    [1] Sight  → metro2033_hellsing_sight
--    [2] Pneumo → metro2033_hellsing_pnevmo

attItems.att_silenciador_pistola = {
	name = "Silenciador de Pistola",
	desc = "Silenciador artesanal para pistolas. Amortigua el ruido del disparo.",
	slot = ATTACHMENT_BARREL,
	tier = 1,
	attSearch = {
		"kry_metro_glushak_revolver",  -- Revolver + Padonak
	}
}

attItems.att_canon_largo_pistola = {
	name = "Cañón Largo de Pistola",
	desc = "Cañón alargado para pistolas. Mejora la precisión y el alcance efectivo.",
	slot = ATTACHMENT_BARREL,
	tier = 1,
	attSearch = {
		"kry_metro_bigbarrel_revolver",  -- Revolver
		"kry_metro_bigbarrel_padonak",   -- Padonak
	}
}

attItems.att_stock_pistola = {
	name = "Stock de Pistola",
	desc = "Culata artesanal para pistolas del metro. Reduce el retroceso al disparar.",
	slot = ATTACHMENT_GRIP,
	tier = 1,
	attSearch = {
		"kry_metro_revolver_stock",  -- Revolver + Padonak
	}
}

attItems.att_stock_escopeta = {
	name = "Stock de Escopeta",
	desc = "Culata de madera para la Duplet. Facilita el control al disparar.",
	slot = ATTACHMENT_GRIP,
	tier = 1,
	attSearch = {
		"kry_metro_duplet_stock",  -- Duplet
	}
}

attItems.att_canon_largo_escopeta = {
	name = "Cañón Largo de Escopeta",
	desc = "Cañón recortado largo para la Duplet. Aumenta el alcance del perdigón.",
	slot = ATTACHMENT_BARREL,
	tier = 1,
	attSearch = {
		"kry_metro_duplet_bigbarrel",  -- Duplet
	}
}

attItems.att_condensador_hellsing = {
	name = "Condensador",
	desc = "Sistema neumático mejorado para la Hellsing. Aumenta la potencia de disparo.",
	slot = ATTACHMENT_SPECIAL,
	tier = 1,
	attSearch = {
		"metro2033_hellsing_pnevmo",  -- Hellsing
	}
}

-- ═══════════════════════════════════════════════════════════════
--  TIER 2 — Bastarda (Ubludok), Tikhar
--  Nota: el Shambler (Uboynik) no tiene attachments en el SWEP.
-- ═══════════════════════════════════════════════════════════════
--
--  Ubludok (Bastarda) Attachments:
--    [1] Sight    → kry_metro_kollimator | kry_metro_optika1 | kry_metro_optika_ir
--    [2] Barrel   → kry_metro_glushak
--    [3] Stock    → kry_metro_ubl_stock
--    [4] Laser    → kry_metro_laser
--    [5] Radiator → kry_metro_ubl_radiator
--
--  Tikhar Attachments:
--    [1] Sight    → kry_metro_kollimator

attItems.att_stock_bastarda = {
	name = "Culata Bastarda",
	desc = "Culata reforzada para la Bastarda. Mejora el control del retroceso.",
	slot = ATTACHMENT_GRIP,
	tier = 2,
	attSearch = {
		"kry_metro_ubl_stock",  -- Ubludok (Bastarda) slot [3]
	}
}

attItems.att_radiador_bastarda = {
	name = "Radiador Bastarda",
	desc = "Módulo de ventilación para la Bastarda. Reduce el sobrecalentamiento entre ráfagas.",
	slot = ATTACHMENT_SPECIAL,
	tier = 2,
	attSearch = {
		"kry_metro_ubl_radiator",  -- Ubludok (Bastarda) slot [5]
	}
}

attItems.att_laser = {
	name = "Puntero Láser",
	desc = "Punto de mira láser rojo. Mejora la puntería en combate cercano.",
	slot = ATTACHMENT_LASER,
	tier = 2,
	attSearch = {
		"kry_metro_laser",    -- Ubludok, Kalash, Saiga
		"metro2033_laser",    -- VSV
	}
}

attItems.att_mira_holografica = {
	name = "Mira Holográfica",
	desc = "Colimador de punto rojo de fabricación metro. Requiere materiales de calidad.",
	slot = ATTACHMENT_SIGHT,
	tier = 2,
	price = 800,
	attSearch = {
		"kry_metro_kollimator",  -- Ubludok (Bastarda), Tikhar, Kalash
	}
}

-- ═══════════════════════════════════════════════════════════════
--  TIER 3 — Kalash (AK), VSV, Saiga, Ventil
-- ═══════════════════════════════════════════════════════════════
--
--  Kalash (cw_kry_metro_2k33_ak) Attachments:
--    [1] Sight  → kry_metro_kollimator | kry_metro_optika1
--    [2] Barrel → kry_metro_glushak
--    [3] Mag    → kry_metro_ak_mag_45
--    [4] Laser  → kry_metro_laser
--
--  VSV (cw_metro2033_vsv) Attachments:
--    [1] Sight  → metro2033_sight_collimator
--    [2] Barrel → metro2033_silencer
--    [3] Laser  → metro2033_laser
--
--  Saiga (cw_kry_metro_2k33_saiga) Attachments:
--    [1] Barrel → kry_metro_glushak
--    [2] Clip   → kry_metro_saiga_mag_20
--    [3] Laser  → kry_metro_laser
--
--  Ventil (cw_kry_metro_2k33_ventil) Attachments:
--    [1] Sight  → kry_metro_ventil_optika
--    [2] Barrel → kry_metro_ventil_flach
--    [3] Mag    → kry_metro_ventil_mag

attItems.att_cargador_extendido = {
	name = "Cargador Extendido",
	desc = "Cargador de alta capacidad. Compatible con Kalash, Saiga y Ventil.",
	slot = ATTACHMENT_MAGAZINE,
	tier = 3,
	attSearch = {
		"kry_metro_ak_mag_45",    -- Kalash
		"kry_metro_saiga_mag_20", -- Saiga
		"kry_metro_ventil_mag",   -- Ventil
	}
}

attItems.att_mira_x4 = {
	name = "Mira x4",
	desc = "Mira telescópica de 4 aumentos para rifles de asalto.",
	slot = ATTACHMENT_SIGHT,
	tier = 3,
	attSearch = {
		"kry_metro_optika1",  -- Kalash (también acepta Ubludok Bastarda)
	}
}

attItems.att_mira_x4_ventil = {
	name = "Mira x4 (Ventil)",
	desc = "Mira telescópica de 4 aumentos adaptada específicamente para la Ventil.",
	slot = ATTACHMENT_SIGHT,
	tier = 3,
	attSearch = {
		"kry_metro_ventil_optika",  -- Ventil
	}
}

attItems.att_compensador = {
	name = "Compensador",
	desc = "Compensador de retroceso. Compatible con Kalash, VSV, Saiga y Ventil.",
	slot = ATTACHMENT_BARREL,
	tier = 3,
	attSearch = {
		"kry_metro_glushak",       -- Kalash, Saiga (y Bastarda si T3 player la usa)
		"kry_metro_ventil_flach",  -- Ventil
		"metro2033_silencer",      -- VSV
	}
}

-- ═══════════════════════════════════════════════════════════════
--  LÓGICA DE EQUIPADO
-- ═══════════════════════════════════════════════════════════════

-- util.TableToJSON/JSONToTable puede convertir claves string "2" a numéricas 2
-- tras el round-trip a la DB. Esta función las normaliza siempre a strings.
local function normalizeMods(mods)
	if (!mods) then return {} end
	local out = {}
	for k, v in pairs(mods) do
		out[tostring(k)] = v
	end
	return out
end

local function attachment(item, data, combine)
	local client = item.player

	if (!IsValid(client)) then return false end

	local char = client:GetCharacter()
	if (!char) then return false end

	local inv = char:GetInventory()
	if (!inv) then return false end

	local items = inv:GetItems()

	local target = data

	for k, invItem in pairs(items) do
		if (data) then
			if (invItem:GetID() == data) then
				target = invItem
				break
			end
		else
			if (invItem.isWeapon and invItem.isCW) then
				target = invItem
				break
			end
		end
	end

	if (!target or isnumber(target)) then
		client:NotifyLocalized("noWeapon")
		return false
	end

	local class = target.class
	local SWEP = weapons.Get(class)

	if (!SWEP) then
		client:NotifyLocalized("noWeapon")
		return false
	end

	if (target.isCW) then
		local atts = SWEP.Attachments
		local mods = normalizeMods(target:GetData("mod", {}))

		if (atts) then
			local slotKey = tostring(item.slot)

			if (mods[slotKey]) then
				client:NotifyLocalized("alreadyAttached")
				return false
			end

			local pokemon

			for atcat, data in pairs(atts) do
				if (pokemon) then break end

				for k, name in pairs(data.atts) do
					if (pokemon) then break end

					for _, doAtt in pairs(item.attSearch) do
						if (name == doAtt) then
							pokemon = doAtt
							break
						end
					end
				end
			end

			if (!pokemon) then
				client:NotifyLocalized("cantAttached")
				return false
			end

			mods[slotKey] = {item.uniqueID, pokemon, item.name}
			target:SetData("mod", mods)

			local wepon = client:GetActiveWeapon()
			if (IsValid(wepon) and wepon:GetClass() == target.class) then
				wepon:attachSpecificAttachment(pokemon)
				if (wepon.recalculateStats) then
					wepon:recalculateStats()
					netstream.Start(client, "nutUpdateWeapon", wepon)
				end
			end

			for _, wep in pairs(client:GetWeapons()) do
				if (wep:GetClass() == target.class) then
					wep.attLoadedHash = nil
				end
			end

			-- Sincroniza los accesorios al modelo de mundo (visible para todos,
			-- ver sh_worldattachments.lua). mods[k][2] es el nombre del accesorio.
			if (ix.cwsupport and ix.cwsupport.SyncWorldAttsForPlayer) then
				local attNames = {}
				for _, m in pairs(mods) do
					table.insert(attNames, m[2])
				end
				ix.cwsupport.SyncWorldAttsForPlayer(client, target.class, attNames)
			end

			client:EmitSound("stalkersound/inv_attach_addon.mp3")

			return true
		else
			client:NotifyLocalized("notCW")
		end
	end

	client:NotifyLocalized("noWeapon")
	return false
end

-- ═══════════════════════════════════════════════════════════════
--  REGISTRO DE ÍTEMS
-- ═══════════════════════════════════════════════════════════════

for className, v in pairs(attItems) do
	local ITEM = ix.item.Register(className, nil, nil, nil, true)
	ITEM.name        = v.name or className
	ITEM.description = v.desc
	ITEM.price       = v.price or 300
	ITEM.model       = "models/lostsignalproject/items/misc/grooming.mdl"
	ITEM.width       = 1
	ITEM.height      = 1
	ITEM.isAttachment = true
	ITEM.tier        = v.tier or 1
	ITEM.category    = "Accesorios T" .. (v.tier or 1)
	ITEM.attSearch   = v.attSearch
	ITEM.slot        = v.slot

	ITEM.functions.use = {
		name  = "Equipar",
		tip   = "useTip",
		icon  = "icon16/wrench.png",
		isMulti = true,
		multiOptions = function(item, client)
			local targets = {}
			local char = client:GetCharacter()

			if (char) then
				local inv = char:GetInventory()

				if (inv) then
					for k, v in pairs(inv:GetItems()) do
						if (v.isWeapon and v.isCW) then
							table.insert(targets, {
								name = L(v.name),
								data = { v:GetID() },
							})
						end
					end
				end
			end

			return targets
		end,
		OnCanRun = function(item)
			local client = item.player
			return !IsValid(item.entity) and IsValid(client) and item.invID == client:GetCharacter():GetInventory():GetID()
		end,
		OnRun = function(item, data)
			return attachment(item, data[1], false)
		end,
	}
end
