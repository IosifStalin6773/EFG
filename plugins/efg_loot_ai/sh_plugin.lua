local PLUGIN = PLUGIN

PLUGIN.name = "EFG Loot IA"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Loot de Scav y PMC de IA: equipo y botín al aparecer, nivel del PMC, looteo activo, cambio de equipo y extracción con botín."

-- Depende de efg_loot (carga antes) y de efg_ai (carga antes, lanza
-- EFGAISpawned). VJ Base: el cadáver lo crea ENT:FinishDeath y avisa con
-- ENT:OnCreateDeathCorpse(dmginfo, hitgroup, corpse).
ix.efg = ix.efg or {}
ix.efg.lootai = ix.efg.lootai or {}

ix.util.Include("sh_ai_tables.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_behavior.lua")
ix.util.Include("sv_tests.lua")
ix.util.Include("sh_commands.lua")
