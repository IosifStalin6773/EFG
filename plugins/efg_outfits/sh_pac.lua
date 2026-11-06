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
-- [VERIFICAR] en partida: la escala y los ángulos son los de JMod, no los de nuestros modelos.
local jmodBody = {bone = "spine 4", pos = Vector(-4, -3.15, 0), ang = Angle(-80, 0, 90), scale = 0.95}
local jmodHead = {bone = "head", pos = Vector(0.35, 1.75, 0), ang = Angle(-75, 0, -90), scale = 0.95}

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
	helmet_ulach = jmodHead, -- "ULACH B"
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

		if (slot and !item.efgAttach and isstring(item.model) and item.model:find("%.mdl$")) then
			-- las bases de mochila y armadura traen pacData = {} (vacío)
			if (!item.pacOffset and outfits.jmodOffsets[uniqueID]) then item.pacOffset = outfits.jmodOffsets[uniqueID] end
			if (!istable(item.pacData) or table.IsEmpty(item.pacData)) then item.pacData = buildPacData(item, slot) end

			ix.pac.RegisterPart(uniqueID, item.pacData)
			outfits.pacItems[uniqueID] = true
		end
	end
end
