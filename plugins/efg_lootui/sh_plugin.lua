PLUGIN.name = "EFG Saqueo estilo Tarkov"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Ventana de cadáver y alijo al estilo de EFT: rejilla del botín a la izquierda y tu equipo a la derecha. Clic izquierdo pasa el objeto al otro lado; clic derecho abre el menú."

ix.efg = ix.efg or {}
ix.efg.lootui = ix.efg.lootui or {}

ix.config.Add("efgLootUI", true, "Usa la ventana de saqueo estilo Tarkov para cadáveres y alijos (si no, la ventana clásica).", nil, {
	category = "EFG Interfaz"
})

ix.util.Include("cl_plugin.lua")
