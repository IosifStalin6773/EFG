local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Inspección"
PLUGIN.author      = "EFG"
PLUGIN.description = "Ventana de inspección (DHTML) con clic derecho y pantalla de modding de armas de ARC9 al estilo EFT: árbol de ranuras, piezas compatibles y stats en vivo."

ix.config.Add("efgModInRaid", false, "Permite cambiar accesorios de armas durante la raid.", nil, {
	category = "EFG Inspección"
})

ix.util.Include("sh_data.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_html.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_modhtml.lua")
ix.util.Include("cl_modding.lua")
