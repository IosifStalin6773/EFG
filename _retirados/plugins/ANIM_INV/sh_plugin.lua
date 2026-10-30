PLUGIN.name        = "STALKER2 Backpack (BPA) para Helix"
PLUGIN.author      = "Iosif_Stalin"
PLUGIN.description = "Equipa/des-equipa la mochila al abrir/cerrar el Inventario de Helix."

-- Incluimos en orden: sonidos -> SWEP -> lógica cliente -> lógica server
ix.util.Include("sh_sounds.lua")
ix.util.Include("sh_swep_bpa.lua")
ix.util.Include("cl_bpa.lua")
ix.util.Include("sv_bpa.lua")