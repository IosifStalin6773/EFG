PLUGIN.name = "EFG Inventario"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Inventario estilo EFT con TAB: ranuras de equipo, bolsillos, mochila y contenedor seguro. Menú base de Helix disponible para admins via /openHelixMenu."

-- ─── Inventario de equipo ────────────────────────────────────────────────────
-- NO se registra como bolsa (4º param): si lo fuera, su vars.isBag dispararía el
-- bloqueo "nestedBags" al intentar meter una mochila/rig dentro.
ix.EQUIP_INV_W, ix.EQUIP_INV_H = 20, 10

-- Nombres de ranura de EFT (clave → label en español)
ix.EQUIP_SLOT_NAMES = {
	headset  = "auriculares",
	helmet   = "casco",
	facecover= "cubrecaras",
	eyewear  = "gafas",
	armband  = "brazalete",
	armor    = "chaleco",
	rig      = "chaleco táctico",
	backpack = "mochila",
	secure   = "contenedor seguro",
}

-- Devuelve la ranura de equipo de EFT a la que pertenece el ítem (nil si ninguna).
function ix.GetEquipSlotKind(item)
	if (not item) then return nil end
	if (item.isSecureContainer) then return "secure" end
	-- Wearables específicos (auriculares, gafas, cubrecaras, brazalete, rig)
	if (item.efgSlot and ix.EQUIP_SLOT_NAMES[item.efgSlot]) then return item.efgSlot end
	-- Bolsas sin flag especial → mochila
	if (item.isBag and not item.efgCase) then return "backpack" end
	-- Armor / helmets del sistema de outfits
	if (item.outfitCategory == "model")   then return "armor" end
	if (item.outfitCategory == "helmet")  then return "helmet" end
end

if (ix.inventory and ix.inventory.Register) then
	ix.inventory.Register("ix_equipinv", ix.EQUIP_INV_W, ix.EQUIP_INV_H)
end

-- Devuelve el inventario de equipo del personaje (o nil).
-- Limpia vars.isBag para que no bloquee meter mochilas/rigs dentro.
function ix.GetEquipInventory(char)
	if (not char) then return nil end
	local id = char:GetData("equipInvID")
	if (not id) then return nil end
	local inv = ix.item.inventories[id]
	if (inv) then
		inv.vars.isEquipment = true
		inv.vars.isBag = nil
	end
	return inv
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
