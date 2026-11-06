-- Equipo visible con PAC3 (integración pac.lua de Helix: ix.pac, AddPart,
-- RemovePart). Los objetos de equipo sin modelo con esqueleto (efgAttach)
-- reciben un pacData que pega su modelo al hueso de su ranura. Para afinarlo:
-- editor de PAC con el objeto puesto, exportar la parte y copiarla al objeto
-- como ITEM.pacData, o mover solo la posición con ITEM.pacOffset.
local outfits = ix.efg.outfits

-- TODO: AR/CR en el torso. Los modelos de ropa (eft_bear_clothes, eft_usec_clothes)
-- solo tienen el grupo Body (9 y 12 chaquetas); no hay variante de chaleco ni de rig.
-- Hace falta un modelo de torso con grupo de variantes, o decidir cambiar de torso.

-- TODO: cascos, visores, mandíbulas y montura NVG no tienen bodygroup en los modelos
-- PMC ni de ropa. Quedan en inventario y en efg_ballistics; añadir bodygroup aquí cuando
-- haya un modelo que lo tenga.

-- ranura → hueso de PAC y posición inicial (pos, ang, escala)
outfits.pacSlots = {
	helmet    = {bone = "head", pos = Vector(1.5, -0.5, 0), ang = Angle(0, -80, -90), scale = 1},
	headset   = {bone = "head", pos = Vector(1, -0.5, 0), ang = Angle(0, -80, -90), scale = 1},
	eyewear   = {bone = "head", pos = Vector(3.5, -4, 0), ang = Angle(0, -80, -90), scale = 1},
	facecover = {bone = "head", pos = Vector(1, -4, 0), ang = Angle(0, -80, -90), scale = 1},
	armor     = {bone = "spine 2", pos = Vector(-2, 1.5, 0), ang = Angle(0, 90, 90), scale = 1},
	rig       = {bone = "spine 2", pos = Vector(-2, 3, 0), ang = Angle(0, 90, 90), scale = 1},
	backpack  = {bone = "spine 2", pos = Vector(-1, -6, 0), ang = Angle(0, 90, 90), scale = 1},
}

-- Offsets de montaje tomados de la tabla armotable de JMod (joffset_eftpmc.lua, solo
-- como referencia de datos; el addon JMod no se usa). Huesos: el cuerpo va al
-- ValveBiped.Bip01_Spine4 (PAC: "spine 4") y los cascos al hueso de la cabeza.
-- "bon" es el nombre de hueso de GMod que usa cl_fx.lua (el principio de JMod).
-- [VERIFICAR] en partida: la escala y los ángulos son los de JMod, no los de nuestros modelos.
local jmodBody = {bone = "spine 4", bon = "ValveBiped.Bip01_Spine4", pos = Vector(-4, -3.15, 0), ang = Angle(-80, 0, 90), scale = 0.95}
local jmodHead = {bone = "head", bon = "ValveBiped.Bip01_Head1", pos = Vector(0.35, 1.75, 0), ang = Angle(-75, 0, -90), scale = 0.95}

outfits.jmodOffsets = {
	armor_6b13   = jmodBody, -- "6B13"
	armor_6b2    = jmodBody, -- "6B2"
	armor_6b23_1 = jmodBody, -- "6B23"
	armor_6b43   = jmodBody, -- "6B43 Vest"
	armor_korund = jmodBody, -- "Korund"
	armor_paca   = jmodBody, -- "PACA"
	armor_slick  = jmodBody, -- "Slick Black"
	armor_trooper = jmodBody, -- "Trooper TFO"
	armor_untar  = jmodBody, -- "Untar Vest"
	helmet_6b47  = jmodHead, -- "6B47"
	helmet_altyn = jmodHead, -- "Altyn"
	helmet_fast  = jmodHead, -- "Fast MT Black"
	helmet_kiver = jmodHead, -- "KiverM"
	helmet_maska = jmodHead, -- "Shlem Maska 1SH"
	helmet_ssh68 = jmodHead, -- "SSh-68"
	helmet_ulach = jmodHead, -- "ULACH B",
	jmod_module_3m = jmodBody, -- "Module 3M",
	jmod_kora_kulon = jmodBody, -- "Kora-Kulon",
	jmod_kirasa_n = jmodBody, -- "Kirasa-N",
	jmod_6b13_flora = jmodBody, -- "6B13 Flora",
	jmod_6b13_m = jmodBody, -- "6B13 M",
	jmod_redut_m = jmodBody, -- "Redut-M",
	jmod_gzhel_k = jmodBody, -- "Gzhel-K",
	jmod_defender_2 = jmodBody, -- "Defender-2",
	jmod_redut_t5 = jmodBody, -- "Redut-T5 Vest",
	jmod_zhuk_6a = jmodBody, -- "BNTI Zhuk-6a",
	jmod_zhuk3_press = jmodBody, -- "Zhuk3 Press",
	jmod_rbav_af = jmodBody, -- "RBAV-AF",
	jmod_iotv_gen4 = jmodBody, -- "IOTV Gen4 Vest",
	jmod_tackek_fast_mt = jmodHead, -- "Tac-Kek FAST MT",
	jmod_kolpak_1s = jmodHead, -- "Kolpak-1S",
	jmod_shpm_firefighter = jmodHead, -- "SHPM Firefighter Helmet",
	jmod_psh97_djeta = jmodHead, -- "PSh-97 DJETA",
	jmod_msa_ach_tc2001 = jmodHead, -- "MSA ACH TC-2001",
	jmod_msa_ach_tc2002 = jmodHead, -- "MSA ACH TC-2002",
	jmod_achhc_black = jmodHead, -- "ACHHC Black",
	jmod_tc800 = jmodHead, -- "TC 800",
	jmod_sfera_s = jmodHead, -- "SFERA-S",
	jmod_untar = jmodHead, -- "Untar Helmet",
	jmod_zsh_1_2m = jmodHead, -- "ZSH-1-2M",
	jmod_vulkan_5 = jmodHead, -- "Vulkan-5",
	jmod_lshz = jmodHead, -- "LShZ",
	jmod_hjelm = jmodHead, -- "HJELM",
	jmod_tor2 = jmodHead, -- "Tor2",
	jmod_fast_mt_tan = jmodHead, -- "Fast MT Tan",
	jmod_ulach_c = jmodHead, -- "ULACH C",
	jmod_tsh_4m_l = jmodHead, -- "TSh-4M-L",
}

local function buildPacData(item, slot)
	local offset = item.pacOffset or {}
	local id = "efg_" .. item.uniqueID

	return {
		{
			self = {ClassName = "group", UniqueID = id .. "_grupo", Name = item.uniqueID, EditorExpand = true},
			children = {
				{
					self = {
						ClassName = "model",
						UniqueID = id .. "_modelo",
						Model = item.model,
						Bone = offset.bone or slot.bone,
						Position = offset.pos or slot.pos,
						Angles = offset.ang or slot.ang,
						Size = offset.scale or slot.scale,
					},
					children = {}
				}
			}
		}
	}
end

-- uniqueIDs con pacData puesto por este plugin (lo que el servidor sincroniza)
outfits.pacItems = outfits.pacItems or {}

function outfits.SetupPAC()
	if (!ix.pac or !ix.GetEquipSlotKind) then return end

	for uniqueID, item in pairs(ix.item.list) do
		local kind = ix.GetEquipSlotKind(item)
		local slot = kind and outfits.pacSlots[kind]

		-- chalecos y cascos con offset de JMod los dibuja cl_fx.lua, no PAC
		if (slot and !item.efgAttach and !outfits.jmodOffsets[uniqueID] and isstring(item.model) and item.model:find("%.mdl$")) then
			-- las bases de mochila y armadura traen pacData = {} (vacío)
			if (!istable(item.pacData) or table.IsEmpty(item.pacData)) then item.pacData = buildPacData(item, slot) end

			ix.pac.RegisterPart(uniqueID, item.pacData)
			outfits.pacItems[uniqueID] = true
		end
	end
end
