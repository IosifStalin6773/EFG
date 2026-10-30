PLUGIN.name = "EFG Inventario VGUI"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Inventario de EFT en VGUI: rejillas con encaje, rotación con R al arrastrar, equipo, táctico, alijo, acceso rápido y menú contextual."

ix.efg = ix.efg or {}
ix.efg.invgrid = ix.efg.invgrid or {}

ix.config.Add("efgInvEFT", true, "La pestaña EQUIPO del TAB usa el inventario VGUI de EFT (si no, el HTML o la rejilla antigua).", nil, {
	category = "EFG Interfaz"
})

ix.util.Include("cl_grid.lua")
ix.util.Include("cl_page.lua")
