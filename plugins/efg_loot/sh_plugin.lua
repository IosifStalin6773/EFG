local PLUGIN = PLUGIN

PLUGIN.name = "EFG Loot"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Núcleo del loot de EFT: tablas de datos por contenedor y cadáver, ponderación por precio y objetos de botín."

-- Carga antes que efg_loot_ai y efg_loot_ui (orden alfabético) y después de
-- efg_ai, efg_eftdata, efg_icons y efg_invrules. Lo que viene de plugins que
-- cargan más tarde (efg_ui, efg_raids, ix_invkey) solo se lee en tiempo de
-- ejecución.
ix.efg = ix.efg or {}
ix.efg.loot = ix.efg.loot or {}

-- Alias que usan los documentos de diseño (EFG.Loot.*)
EFG = EFG or {}
EFG.Loot = ix.efg.loot

ix.util.Include("sh_config.lua")
ix.util.Include("sh_loot_tables.lua")
ix.util.Include("sh_roll.lua")
ix.util.Include("sh_items.lua")

-- Las armas de efg_arc9, la munición de efg_ballistics y las llaves de
-- efg_maps se registran en InitializedPlugins: las piscinas se recalculan
-- un tick después para incluirlas.
function PLUGIN:InitializedPlugins()
	timer.Simple(0.2, function()
		ix.efg.loot.ResetCache()
	end)
end
