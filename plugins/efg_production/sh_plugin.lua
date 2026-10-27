local PLUGIN = PLUGIN

PLUGIN.name = "EFG Producción"
PLUGIN.author = "EFG"
PLUGIN.description = "Fabricación del escondite con tiempo: los materiales se gastan al empezar y el resultado llega al alijo al terminar."

-- Fuente: https://escapefromtarkov.fandom.com/wiki/Hideout#Production
-- Cada receta puede fijar BLUEPRINT.craftTime (segundos). Las que no lo fijan y
-- dependen de un módulo del escondite (BLUEPRINT.oficio) tardan
-- efgCraftMinutes × nivel requerido [VERIFICAR: cada receta de EFT tiene su tiempo].

ix.config.Add("efgCraftMinutes", 5, "Minutos de fabricación por nivel de receta (si la receta no fija craftTime). 0 = instantáneo.", nil, {
	data = {min = 0, max = 240}, category = "EFG"
})

ix.util.Include("sv_plugin.lua")
