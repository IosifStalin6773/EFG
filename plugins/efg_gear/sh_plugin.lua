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
ix.config.Add("efgArmorModular", true, "Equipo modular: placas por ranura (frontal, trasera, laterales) y módulos de casco. Apagado, vuelve al comportamiento monolítico.", nil, {
	category = "armas"
})

ix.config.Add("efgArmorWearMultiplier", 1.0, "Multiplicador global del desgaste de placas y chalecos por impacto. [VERIFICAR] Ajuste para afinar sin tocar las tablas.", nil, {
	data = {min = 0, max = 5, decimals = 2},
	category = "armas"
})

ix.util.Include("libs/sh_equipment.lua")
ix.util.Include("libs/sh_slots.lua")
ix.util.Include("libs/sh_recalc.lua")
ix.util.Include("libs/sh_backpack.lua")
ix.util.Include("libs/sv_slotactions.lua")
ix.util.Include("libs/sh_wearable.lua")
