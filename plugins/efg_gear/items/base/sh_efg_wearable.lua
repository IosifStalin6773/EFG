-- items/base/sh_efg_wearable.lua
-- Ítem base para todos los accesorios de EFT (auriculares, gafas, cubrecaras, brazalete).
-- Los chalecos tácticos (rigs) heredan de aquí pero añaden un inventario interno.

ITEM.name        = "Wearable EFG"
ITEM.description = "Accesorio de equipo personal."
ITEM.model       = "models/props_junk/garbage_bag001a.mdl"
ITEM.width       = 1
ITEM.height      = 1
ITEM.weight      = 0.1
ITEM.category    = "Equipo"
ITEM.bDropOnDeath = true

-- Ranura de equipo a la que va este ítem (se sobreescribe en cada ítem)
ITEM.efgSlot     = "headset"

-- Multiplicador de rango auditivo de NPCs (solo auriculares; defecto = 1 = sin cambio)
ITEM.efgHearing  = 1

function ITEM:GetDescription()
	local base = self.description
	if (self.efgHearing and self.efgHearing != 1) then
		base = base .. "\n[Oído: ×" .. self.efgHearing .. "]"
	end
	return base
end

if (ix.efg and ix.efg.gear) then
	ix.efg.gear.AddEquipAction(ITEM)
	ix.efg.gear.AddUnequipAction(ITEM)
end
