local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Menú radial"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Menú radial (adaptado de Multiverse Radial Menus) con acciones rápidas: mantén Z."

if (SERVER) then
	resource.AddFile("materials/efg/radial/lmb.png")
	resource.AddFile("materials/efg/radial/rmb.png")
end

ix.util.Include("cl_plugin.lua")
