local PLUGIN = PLUGIN

PLUGIN.name = "EFG Loot UI"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Ventana de saqueo de EFT: búsqueda progresiva por sección, examen con la rueda del ratón y tres diseños (Scav, réplica de PMC y contenedor)."

-- Carga después de efg_loot y efg_loot_ai (orden alfabético). efg_invgrid
-- (iconos y rejilla), efg_invrules (examinar) e ix_invkey (ranuras de equipo)
-- solo se usan en tiempo de ejecución.
ix.efg = ix.efg or {}
ix.efg.lootwin = ix.efg.lootwin or {}

ix.config.Add("efgLootWindow", true, "Usa la ventana de saqueo de EFT (búsqueda por sección y examen) para cuerpos y contenedores de efg_loot. Apagado vuelve a la cadena de ventanas de almacenamiento.", nil, {
	category = "EFG Loot"
})

ix.util.Include("sh_layout.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
