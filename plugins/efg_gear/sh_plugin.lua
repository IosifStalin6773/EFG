local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Equipo"
PLUGIN.author      = "EFG"
PLUGIN.description = "Equipo de EFT: chalecos y cascos por clases, mochilas, contenedores seguros, accesorios (auriculares, gafas, cubrecaras, brazalete) y chalecos tácticos con rejilla."

-- Registrar el inventario interno de los chalecos tácticos (rigs).
-- Usamos el tamaño del rig más grande; cada ítem ajustará el suyo al abrir.
-- NO se marca como bolsa (4º param) para que puedan meterse bolsas dentro.
function PLUGIN:InitializedPlugins()
	if (ix.inventory and ix.inventory.Register) then
		ix.inventory.Register("efg_rig", 4, 4)
	end
end

ix.util.Include("libs/sh_armor.lua")
ix.util.Include("libs/sh_wearable.lua")
