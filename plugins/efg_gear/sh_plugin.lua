local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Equipo"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Equipo: chalecos y cascos por clases, mochilas, contenedores seguros, accesorios (auriculares, gafas, cubrecaras, brazalete) y chalecos tácticos con rejilla."

-- Registrar el inventario interno de los chalecos tácticos (rigs).
-- Usamos el tamaño del rig más grande; cada ítem ajustará el suyo al abrir.
-- NO se marca como bolsa (4º param) para que puedan meterse bolsas dentro.
function PLUGIN:InitializedPlugins()
	if (ix.inventory and ix.inventory.Register) then
		ix.inventory.Register("efg_rig", 4, 4)
	end
end

-- En los bolsillos de un chaleco táctico no entran mochilas, chalecos ni
-- contenedores (como en EFT)
function PLUGIN:CanTransferItem(item, oldInv, newInv)
	if (!newInv or !ix.efg.rig or !ix.efg.rig.ForInventory(newInv)) then return end

	if (item.isBag or item.efgCase or item.isSecureContainer or item.efgPockets) then
		if (SERVER and IsValid(item.player)) then
			item.player:Notify("Eso no cabe en los bolsillos del chaleco.")
		end

		return false
	end
end

ix.util.Include("libs/sh_armor.lua")
ix.util.Include("libs/sh_wearable.lua")
