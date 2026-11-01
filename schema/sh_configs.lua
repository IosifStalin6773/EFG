ix.currency.symbol = ""
ix.currency.singular = "Rublo"
ix.currency.plural = "Rublos"

ix.config.language = "spanish"

ix.config.SetDefault("scoreboardRecognition", false)
ix.config.SetDefault("music", "weapons/guitar/guitar_2.mp3")

-- Tiempo "inconsciente" tras morir antes de reaparecer automáticamente: da
-- margen a que un médico llegue a reanimar con el desfibrilador (ver plugin medico).
ix.config.SetDefault("spawnTime", 10)

-- Forzar reaparición manteniendo F (ver schema/sv_hooks.lua y menu_ui/cl_skin.lua):
-- segundos DESPUÉS de que aparece el texto "Estás inconsciente" (no desde que
-- mueres) antes de que la opción esté disponible, y segundos que hay que
-- mantener pulsada la tecla para saltarse el resto de la espera.
ix.config.Add("forceRespawnDelay", 10, "Segundos tras aparecer el texto de inconsciencia antes de poder mantener F para forzar la reaparición.", nil, {
	data = {min = 0, max = 120},
	category = "EFG"
})

ix.config.Add("forceRespawnHold", 10, "Segundos que hay que mantener pulsada F para forzar la reaparición.", nil, {
	data = {min = 1, max = 30},
	category = "EFG"
})



ix.option.Add("minimalTooltips", ix.type.bool, true, {
    category = "appearance"
})