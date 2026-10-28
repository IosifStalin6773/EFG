local PLUGIN = PLUGIN

PLUGIN.name = "Médico"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Sistema de heridas y curación. Solo los médicos pueden usar el botiquín para curar a otros supervivientes y tratar sus heridas acumuladas."

-- ============================================================
--  CONFIGURACIÓN
-- ============================================================

-- Porcentaje de capacidad vital que se pierde por cada muerte.
ix.config.Add("medico_herida_porcentaje", 10, "Porcentaje de vida máxima perdido por cada muerte.", nil, {
	data = {min = 1, max = 50},
	category = "Médico"
})

-- Porcentaje máximo de heridas que un personaje puede acumular.
ix.config.Add("medico_herida_max", 90, "Tope de heridas acumuladas en porcentaje (siempre queda algo de vida).", nil, {
	data = {min = 10, max = 90},
	category = "Médico"
})

-- Vida máxima base del jugador sano (sin heridas).
ix.config.Add("medico_vida_base", 100, "Vida máxima de un personaje totalmente sano.", nil, {
	data = {min = 50, max = 500},
	category = "Médico"
})

-- Usos disponibles en un botiquín nuevo.
ix.config.Add("medico_botiquin_usos", 15, "Número de usos de un botiquín antes de gastarse.", nil, {
	data = {min = 1, max = 100},
	category = "Médico"
})

-- Vida que restaura cada uso de "Curar" del botiquín (no es una curación total).
ix.config.Add("medico_botiquin_curacion", 60, "Puntos de vida que restaura cada uso de Curar del botiquín.", nil, {
	data = {min = 1, max = 200},
	category = "Médico"
})

-- Radiación que retira cada uso de "Rebajar Radiación" del botiquín.
ix.config.Add("medico_botiquin_rads", 20, "Puntos de radiación que retira cada uso de Rebajar Radiación del botiquín.", nil, {
	data = {min = 1, max = 100},
	category = "Médico"
})

-- Distancia máxima (en unidades) para curar a otro jugador.
ix.config.Add("medico_botiquin_rango", 150, "Distancia máxima para curar o tratar a otro jugador con el botiquín.", nil, {
	data = {min = 50, max = 400},
	category = "Médico"
})

-- Rango (en unidades) en el que un jugador médico inhabilita al NPC médico de guardia.
ix.config.Add("medico_npc_rango_medico", 1500, "Si hay un médico (jugador) dentro de este rango, el NPC de guardia no atenderá.", nil, {
	data = {min = 200, max = 5000},
	category = "Médico"
})

-- Tiempo de espera (en segundos) entre curaciones del NPC de guardia por jugador.
ix.config.Add("medico_npc_cooldown", 60, "Segundos de espera entre curaciones del NPC médico de guardia por jugador.", nil, {
	data = {min = 0, max = 600},
	category = "Médico"
})

-- Precio (en Balas) que cobra el NPC de guardia por restaurar la vida.
ix.config.Add("medico_npc_precio_curar", 100, "Balas que cobra el NPC médico de guardia por curar la vida.", nil, {
	data = {min = 0, max = 10000},
	category = "Médico"
})

-- Precio (en Balas) que cobra el NPC de guardia por tratar las heridas.
ix.config.Add("medico_npc_precio_heridas", 200, "Balas que cobra el NPC médico de guardia por tratar las heridas.", nil, {
	data = {min = 0, max = 10000},
	category = "Médico"
})

-- ============================================================
--  REANIMACIÓN (DESFIBRILADOR)
-- ============================================================

-- Vida con la que un superviviente vuelve tras ser reanimado.
ix.config.Add("medico_revivir_vida", 10, "Puntos de vida con los que revive un superviviente reanimado.", nil, {
	data = {min = 1, max = 100},
	category = "Médico"
})

-- Tiempo mínimo (en segundos) entre dos reanimaciones del mismo superviviente.
ix.config.Add("medico_revivir_cooldown", 600, "Segundos que debe esperar un superviviente entre dos reanimaciones.", nil, {
	data = {min = 0, max = 3600},
	category = "Médico"
})

-- Probabilidad de que la reanimación tenga éxito.
ix.config.Add("medico_revivir_probabilidad", 100, "Probabilidad (en %) de que un desfibrilador consiga reanimar al superviviente.", nil, {
	data = {min = 1, max = 100},
	category = "Médico"
})

-- El desfibrilador solo puede reanimar mientras el cadáver siga en pie de "muerto"
-- (antes del respawn automático). Se amplía la ventana de Helix (5s por defecto)
-- para dar tiempo real a que un médico llegue y actúe.
ix.config.SetDefault("spawnTime", 60)

-- ============================================================
--  VARIABLE DE PERSONAJE: HERIDAS
-- ============================================================

-- Heridas acumuladas en porcentaje (0, 10, 20, ...). Reduce la vida
-- máxima del personaje hasta que un médico las trate con un botiquín.
ix.char.RegisterVar("heridas", {
	field = "heridas",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true,
})

-- ============================================================
--  HELPERS COMPARTIDOS
-- ============================================================

-- Comprueba si un personaje ejerce el oficio de médico.
function PLUGIN:EsMedico(character)
	if (!character) then return false end
	return character:GetOficio() == "medico"
end

-- Calcula la vida máxima resultante según las heridas acumuladas.
function PLUGIN:CalcularVidaMaxima(heridas)
	local base = ix.config.Get("medico_vida_base", 100)
	local frac = 1 - (math.Clamp(heridas or 0, 0, 100) / 100)
	return math.max(1, math.floor(base * frac))
end

ix.util.Include("sh_commands.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")