local PLUGIN = PLUGIN
PLUGIN.name = "Sistema de Generadores"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Generadores diésel con área de energía. Consumen combustible (bidones); al agotarse cortan la luz y enfrían la zona."

-- Lista autoritativa de generadores. Cada entrada:
--   { id, vMin, vMax, pos, ang, fuel (segundos), powered (bool), ent }
-- El combustible (fuel) se decrementa en vivo por un timer del servidor, así el
-- tiempo restante se PAUSA durante un restart en vez de seguir consumiéndose.
PLUGIN.generators = PLUGIN.generators or {}
PLUGIN.nextGenID = PLUGIN.nextGenID or 1

GENERATOR_MODEL = "models/z-o-m-b-i-e/metro_2033/electro/m33_diesel_generator_01.mdl"
GENERATOR_FUEL_ITEM = "gasolina"

-- Formatea segundos de combustible como "Xh Ym" (usado en servidor y cliente).
function GeneratorFormatFuel(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)

	return h .. "h " .. m .. "m"
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")

-- Combustible máximo almacenable (tanque lleno).
ix.config.Add("gen_max_horas", 24, "Horas máximas de combustible que puede almacenar un generador (tanque lleno).", nil, {
	data = {min = 1, max = 168},
	category = "Generadores"
})

-- Horas que añade cada bidón de combustible.
ix.config.Add("gen_horas_bidon", 6, "Horas de autonomía que añade cada bidón de combustible.", nil, {
	data = {min = 1, max = 48},
	category = "Generadores"
})

-- Temperatura (°C) que sufre el área cuando el generador está sin energía.
ix.config.Add("gen_frio_temp", -15, "Temperatura (°C) del área de un generador cuando se queda sin energía.", nil, {
	data = {min = -50, max = 10},
	category = "Generadores"
})

-- Altura (unidades) que se eleva el área desde el suelo. Debe cubrir el techo para
-- incluir sus luces y a los jugadores de pie.
ix.config.Add("gen_area_altura", 320, "Altura (unidades) que se eleva el área del generador desde el suelo (cubre techo y jugadores).", nil, {
	data = {min = 64, max = 1024},
	category = "Generadores"
})
