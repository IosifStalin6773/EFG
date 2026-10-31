-- Equipo visible con PAC3 (integración pac.lua de Helix: ix.pac, AddPart,
-- RemovePart). Los objetos de equipo sin modelo con esqueleto (efgAttach)
-- reciben un pacData que pega su modelo al hueso de su ranura. Para afinarlo:
-- editor de PAC con el objeto puesto, exportar la parte y copiarla al objeto
-- como ITEM.pacData, o mover solo la posición con ITEM.pacOffset.
local outfits = ix.efg.outfits

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
			if (!istable(item.pacData) or table.IsEmpty(item.pacData)) then item.pacData = buildPacData(item, slot) end

			ix.pac.RegisterPart(uniqueID, item.pacData)
			outfits.pacItems[uniqueID] = true
		end
	end
end
