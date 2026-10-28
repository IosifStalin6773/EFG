local PLUGIN = PLUGIN

PLUGIN.name = "Vía de Draisina"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Sustituye el movimiento físico del addon de la draisina (CBH's Metro Dresine) por un camino de waypoints, para que no dependa de la geometría real del rail del mapa."

ix.dresinavia = ix.dresinavia or {}

-- Nombre del vehículo tal y como lo registra el addon original en list.Set("Vehicles", ...)
ix.dresinavia.vehicleListName = "M2033 HandCar"

-- Ruta en la que aparece siempre una draisina recién spawneada (fija, no se
-- cambia con /DresinaViaRuta — esa solo cambia qué ruta EDITAN los comandos).
ix.dresinavia.activeRouteId = "main"

-- Ruta que editan actualmente /DresinaViaWP, /DresinaViaQuitar, /DresinaViaLoop
-- y /DresinaViaMostrar. Se cambia con /DresinaViaRuta <nombre>.
ix.dresinavia.editingRouteId = "main"

-- Movimiento
ix.dresinavia.accel = 150       -- u/s², al pulsar adelante/atrás
ix.dresinavia.brake = 300       -- u/s², al soltar
ix.dresinavia.maxSpeed = 300    -- u/s
ix.dresinavia.heightOffset = 0  -- Z añadido a la posición interpolada del camino; calibrar en el mapa
ix.dresinavia.seatHeightOffset = 25 -- Z local del jugador sobre el prop de asiento; calibrado con /DresinaViaAlturaAsiento
ix.dresinavia.seatedViewOffset = 40 -- Altura (Z) de la cámara sentado, más baja que la de pie (ViewOffset estándar ~64-72u); valor de respaldo, el real es el ix.config de abajo

-- Corrección de yaw de la vista al sentarse, POR ASIENTO (0-3, ver
-- props[5..8] en sv_plugin.lua). El ángulo de los props de asiento no está
-- pensado para "hacia dónde mira el jugador" (son los cubos de colisión de
-- MHCCreate, orientados a lo que le hiciera falta al addon original), así
-- que hace falta esta corrección para que cada uno mire hacia el centro del
-- vagón en vez de de lado. ix.config (no una tabla ix.dresinavia normal)
-- para que se pueda ajustar en caliente desde el panel de admin sin
-- reiniciar el servidor.
-- Asientos 1 y 2 (índices 0 y 1, props[5]/[6]) confirmados con
-- /DresinaViaDebugAsiento a 90. Asientos 3 y 4 (índices 2 y 3, props[7]/[8])
-- probados en el juego con /DresinaViaDebugAsiento: 90 seguía sin ser
-- correcto, hace falta otros 90 más encima (180 en total) para dejar de
-- mirar hacia el propio maniquí.
local SEAT_YAW_DEFAULTS = {[0] = 90, [1] = 90, [2] = 180, [3] = 180}

for i = 0, 3 do
	ix.config.Add("dresinaSeatYaw" .. i, SEAT_YAW_DEFAULTS[i], "Corrección de ángulo (yaw) de la cámara al sentarte en el asiento " .. (i + 1) .. " de la draisina.", nil, {
		data = {min = -180, max = 180},
		category = "Vía de Draisina"
	})
end

-- Altura y adelanto de la cámara sentado, en ix.config para poder calibrarlos
-- en caliente con dresina_seatview (ver sv_plugin.lua) sin tocar código.
-- dresinaSeatViewForward existe porque la altura sola (Z) no basta: el
-- maniquí visual (CreatePlayerReplica) ocupa el mismo punto base que la
-- cámara del jugador real (mismo SetLocalPos), así que si la cabeza del
-- maniquí en su pose sentada queda más adelantada que el ojo de la cámara,
-- se ve el propio cuerpo/cabeza en primer plano ("verse en tercera persona").
-- Empujar la cámara hacia delante (a lo largo de su propio ángulo) la saca
-- de detrás del maniquí sin tener que mover el punto base de ambos.
ix.config.Add("dresinaSeatViewHeight", ix.dresinavia.seatedViewOffset, "Altura (Z) de la cámara al sentarte en la draisina.", nil, {
	data = {min = -20, max = 100},
	category = "Vía de Draisina"
})
ix.config.Add("dresinaSeatViewForward", 0, "Cuánto se adelanta la cámara al sentarte en la draisina, para no ver tu propio maniquí.", nil, {
	data = {min = -50, max = 50},
	category = "Vía de Draisina"
})

-- Colocación de waypoints (mismos umbrales que npcPatrullaWP/npcEliminarWP)
ix.dresinavia.wpInsertRange = 300
ix.dresinavia.wpRemoveRange = 200

-- Geometría del modelo: distancia aprox. entre ejes según los offsets de
-- MHCCreate en sv_plugin.lua (Vector(56,...) / Vector(-57,...)). Un radio de
-- curva menor a minTurnRadius hace que el modelo gire más de lo que su
-- longitud permitiría en la realidad ("curvas ficticias"); /DresinaViaSuavizar
-- usa este valor por defecto para ensanchar esos tramos.
ix.dresinavia.vehicleLength = 115
ix.dresinavia.minTurnRadius = ix.dresinavia.vehicleLength * 3

-- Agujas (bifurcaciones)
ix.dresinavia.switchEndpointTolerance = 150  -- distancia máx. entre la aguja y el extremo de cada ruta que conecta
ix.dresinavia.switchLeverAngleOffset = 45    -- valor de respaldo del offset de pitch; el real son los ix.config de abajo

-- Cuánto se inclina la palanca (models/props_wasteland/tram_lever01.mdl) al
-- pasar a la rama B, en los 3 ejes por separado. Pitch por defecto (inclinar
-- hacia delante/atrás, como tirar de una palanca de verdad) en vez de yaw
-- (que solo la hace girar sobre sí misma en el sitio, sin parecer que la
-- estás accionando). Ajustable en caliente con dresina_leverangle (ver
-- sv_plugin.lua) mientras se calibra en el mapa.
ix.config.Add("dresinaLeverOffsetPitch", ix.dresinavia.switchLeverAngleOffset, "Inclinación (pitch) de la palanca de aguja al pasar a la rama B.", nil, {
	data = {min = -90, max = 90},
	category = "Vía de Draisina"
})
ix.config.Add("dresinaLeverOffsetYaw", 0, "Giro (yaw) de la palanca de aguja al pasar a la rama B.", nil, {
	data = {min = -90, max = 90},
	category = "Vía de Draisina"
})
ix.config.Add("dresinaLeverOffsetRoll", 0, "Inclinación lateral (roll) de la palanca de aguja al pasar a la rama B.", nil, {
	data = {min = -90, max = 90},
	category = "Vía de Draisina"
})

-- Modelos adicionales de draisina: mismo sistema de vía por waypoints, ruedas/
-- palancas/asientos con los mismos huecos que el modelo original del addon
-- ("models/main/mhc.mdl"/"models/auxsize/mhc.mdl"). Si alguno de estos se ve
-- mal encajado (ruedas flotando, asientos desplazados) es porque sus
-- proporciones no coinciden con las del modelo original — avisa cuál y se le
-- da un offset propio en vez de reusar el genérico.
-- Se registran en el menú de vehículos del sandbox (categoría "CBH's Trains",
-- junto al original) para poder spawnearlos igual que la draisina del addon.
ix.dresinavia.extraModels = {
	{name = "Draisina Quadro",              model = "models/magma/props/quadro.mdl"},
	{name = "Draisina de Pareja (pequeña)", model = "models/magma/props/drezina_par_small.mdl"},
	{name = "Draisina Reginna",              model = "models/magma/props/reginna.mdl"},
	{name = "Draisina Khan",                 model = "models/magma/props/drezina_khan.mdl"},
}

for _, info in ipairs(ix.dresinavia.extraModels) do
	list.Set("Vehicles", info.name, {
		Name = info.name,
		Class = "prop_physics",
		Model = info.model,
		Category = "CBH's Trains",
		Author = "Metro RP By Cono y Manperra",
		Information = "Variante visual de la draisina, sobre el mismo sistema de vía por waypoints.",
	})
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
