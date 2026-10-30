PLUGIN.name = "EFG Inventario HTML"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Inventario de EFT en DHTML (equipo, táctico y alijo) con arrastrar y soltar sobre ix.inventory."

ix.efg = ix.efg or {}
ix.efg.invhtml = ix.efg.invhtml or {}

ix.config.Add("efgInvHTML", true, "TAB abre el inventario HTML de EFT en vez del de VGUI.", nil, {
	category = "EFG Interfaz"
})

ix.util.Include("cl_html.lua")
ix.util.Include("cl_plugin.lua")
