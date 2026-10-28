local PLUGIN = PLUGIN
PLUGIN.name = "Sistema de Temperatura"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Zonas frías creadas por admin. El frío acumula congelación; las armaduras dan tolerancia según su umbral en grados."

-- Lista de zonas frías. Cada entrada: { vMin (Vector), vMax (Vector), temp (number) }.
-- Solo existe/se rellena en servidor (ver sv_plugin.lua), pero el campo se declara
-- aquí para que ambos realms lo referencien sin error.
PLUGIN.coldAreas = PLUGIN.coldAreas or {}

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sh_commands.lua")

-- Nivel de congelación del personaje (0-100). isLocal = solo se envía a su dueño.
-- bNoDisplay = no aparece como atributo en el menú de personaje.
ix.char.RegisterVar("congelacion", {
	field = "congelacion",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true,
})

-- ─── Tunables (ajustables en vivo desde la config de Helix) ───────────────────

-- Temperatura (°C) ambiente de todo el mapa, salvo dentro de una zona marcada.
ix.config.Add("frio_temp_ambiente", 5, "Temperatura (°C) ambiente de todo el mapa (salvo dentro de una zona marcada).", nil, {
	data = {min = -50, max = 30},
	category = "Temperatura"
})

-- Grados (°C) que el jugador tolera SIN armadura. Por encima de esto no pasa frío.
ix.config.Add("frio_tolerancia_base", 10, "Temperatura (°C) que un jugador tolera sin armadura antes de empezar a congelarse.", nil, {
	data = {min = -50, max = 30},
	category = "Temperatura"
})

-- Congelación base ganada por tick (3 s) mientras estás por debajo de tu umbral.
-- Calibrado para que el caso ambiente (5 °C, sin abrigo) tarde ~10 min en llegar
-- a 100 (muerte): 0.3 + 0.04*5 = 0.5/tick → 200 ticks * 3 s = 600 s.
ix.config.Add("frio_ganancia", 0.3, "Congelación base ganada por tick en una zona fría.", nil, {
	data = {min = 0, max = 20, decimals = 2},
	category = "Temperatura"
})

-- Congelación extra por tick por cada grado que la zona está por debajo del umbral.
ix.config.Add("frio_ganancia_grado", 0.04, "Congelación extra por tick por cada °C por debajo de tu umbral de protección.", nil, {
	data = {min = 0, max = 5, decimals = 2},
	category = "Temperatura"
})

-- Congelación recuperada por tick cuando estás en un sitio cálido / fuera de zona.
ix.config.Add("frio_recuperacion", 2, "Congelación recuperada por tick al estar caliente (fuera de zona o zona templada).", nil, {
	data = {min = 0, max = 20},
	category = "Temperatura"
})

-- Radio (unidades) alrededor de una fuente de calor donde no pasas frío.
ix.config.Add("frio_hoguera_radio", 200, "Radio (unidades) alrededor de una hoguera/fuente de calor donde no pasas frío.", nil, {
	data = {min = 50, max = 1000},
	category = "Temperatura"
})

-- Clases de entidades que emiten calor y anulan el frío a su alrededor.
-- Ampliable: añade aquí calefactores, barriles ardiendo, etc.
PLUGIN.heatSources = PLUGIN.heatSources or {
	["sent_vj_campfire"] = true,
}

-- ─── Ralentización por congelación (componible, sin cachear velocidad) ─────────
-- SetupMove corre en cliente y servidor para que la predicción coincida con la
-- autoridad. A partir de 50 de congelación el jugador se ralentiza. Usa
-- SetMaxClientSpeed en vez de SetWalkSpeed/SetRunSpeed para no pisar la caché de
-- velocidad de otros sistemas (p. ej. la ralentización por radiación de badair).
hook.Add("SetupMove", "ixTemperatura_speed", function(client, mv)
	local char = client:GetCharacter()
	if (not char) then return end

	local cong = char:GetCongelacion()
	if (cong < 50) then return end

	-- 50 → x1.0 ; 100 → x0.6 (interpolación lineal)
	local mult = Lerp((cong - 50) / 50, 1, 0.6)
	if (mult < 1) then
		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
	end
end)
