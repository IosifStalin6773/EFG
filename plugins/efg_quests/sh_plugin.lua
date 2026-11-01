local PLUGIN = PLUGIN

PLUGIN.name = "EFG Tareas de EFT"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Tareas iniciales de los comerciantes basadas en las de EFT, cargadas en el plugin missions."

-- Fuente: https://escapefromtarkov.fandom.com/wiki/Quests
-- Los objetivos que dependen de un mapa concreto de EFT se han simplificado a
-- eliminar IA o entregar objetos encontrados en raid. Las recompensas son
-- aproximadas [VERIFICAR] y se pueden cambiar luego con /MisionAdmin.

ix.util.Include("sv_plugin.lua")
