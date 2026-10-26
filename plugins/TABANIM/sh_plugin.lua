PLUGIN.name = "Animacion TAB"
PLUGIN.author = "Iosif_Stalin"
PLUGIN.description = "Equipa la PDA al navegar el menú de Helix en tabs distintos a 'inventory'."

ix.util.Include("sh_stalker2_pda.lua")    -- Sonidos (compartido)
ix.util.Include("sh_pda_wep.lua")         -- SWEP registrado manualmente
ix.util.Include("sv_pda_helix.lua")       -- Servidor
ix.util.Include("cl_pda_helix.lua")       -- Cliente