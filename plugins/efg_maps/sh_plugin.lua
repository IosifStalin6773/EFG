local PLUGIN = PLUGIN

PLUGIN.name = "EFG Mapas"
PLUGIN.author = "EFG"
PLUGIN.description = "Datos de cada localización de EFT (duración, jefes, noche), reloj de raid acelerado con día y noche, clima, llaves y puertas cerradas."

-- Fuentes (wiki de EFT): Map pages, Time, Weather, Keys.
-- [VERIFICAR] Duraciones y probabilidades de memoria.

ix.efg = ix.efg or {}
ix.efg.maps = ix.efg.maps or {}

local MAPS = ix.efg.maps

-- patrones = nombres de mapa de GMod que corresponden a la localización
MAPS.locations = {
	customs = {name = "Aduanas", patterns = {"customs"}, minutes = 40, scavMinutes = 25, players = "8-12",
		bosses = {reshala = 38, goons = 30, cultists = 25}},
	factory = {name = "Fábrica", patterns = {"factory"}, minutes = 20, scavMinutes = 15, players = "4-6",
		bosses = {tagilla = 30, cultists = 20}},
	woods = {name = "Bosque", patterns = {"woods"}, minutes = 40, scavMinutes = 25, players = "8-14",
		bosses = {shturman = 40, goons = 30, cultists = 25, partisan = 30}},
	shoreline = {name = "Costa", patterns = {"shoreline"}, minutes = 45, scavMinutes = 30, players = "10-13",
		bosses = {sanitar = 35, goons = 30, cultists = 25, partisan = 30}},
	interchange = {name = "Intercambiador", patterns = {"interchange"}, minutes = 40, scavMinutes = 25, players = "10-14",
		bosses = {killa = 35}},
	reserve = {name = "Reserva", patterns = {"reserve", "rezerv"}, minutes = 40, scavMinutes = 25, players = "9-12",
		bosses = {glukhar = 35, raiders = 40}},
	lighthouse = {name = "Faro", patterns = {"lighthouse"}, minutes = 40, scavMinutes = 25, players = "9-12",
		bosses = {zryachiy = 100, rogues = 100, goons = 30, partisan = 30}},
	streets = {name = "Calles de Tarkov", patterns = {"streets", "tarkov_city"}, minutes = 50, scavMinutes = 35, players = "12-16",
		bosses = {kaban = 40, kollontay = 30}},
	groundzero = {name = "Zona cero", patterns = {"ground_zero", "groundzero"}, minutes = 35, scavMinutes = 20, players = "9-12",
		bosses = {kollontay = 20}},
	labs = {name = "Laboratorio", patterns = {"labs", "laboratory"}, minutes = 35, scavMinutes = 0, players = "6-10",
		bosses = {raiders = 100}, alwaysDay = true, keycard = true}
}

-- Localización del mapa cargado (nil si el mapa no es de EFT)
function MAPS.Current()
	if (MAPS.current != nil) then return MAPS.current or nil end

	local map = game.GetMap():lower()

	for id, location in pairs(MAPS.locations) do
		for _, pattern in ipairs(location.patterns) do
			if (map:find(pattern, 1, true)) then
				location.id = id
				MAPS.current = location
				return location
			end
		end
	end

	MAPS.current = false
end

-- Probabilidad (%) de que aparezca un jefe en este mapa (nil = no está aquí)
function MAPS.BossChance(bossID)
	local location = MAPS.Current()
	return location and location.bosses[bossID] or nil
end

ix.config.Add("efgTimeScale", 7, "Velocidad del reloj de la raid (EFT: 7 horas por hora real).", nil, {
	data = {min = 1, max = 60}, category = "EFG Mapas"
})
ix.config.Add("efgDayNight", true, "Ciclo de día y noche (oscurece el mapa de noche).", nil, {
	category = "EFG Mapas"
})
ix.config.Add("efgWeather", true, "Clima variable (niebla y lluvia).", nil, {
	category = "EFG Mapas"
})

-- ─── Reloj de raid (Time) ───────────────────────────────────────────────────
-- Hora del juego en segundos (0-86400). EFT ofrece dos horas separadas 12 h:
-- aquí el servidor tiene una y la otra es informativa en el selector de raid.
function MAPS.GetClock()
	local base = GetNetVar("efgClockBase", 0)
	local start = GetNetVar("efgClockStart", 0)
	local location = MAPS.Current()

	if (location and location.alwaysDay) then return 12 * 3600 end

	return (base + (CurTime() - start) * ix.config.Get("efgTimeScale", 7)) % 86400
end

function MAPS.FormatClock(seconds)
	seconds = seconds % 86400
	return ("%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- Noche: de 22:00 a 05:00
function MAPS.IsNight(seconds)
	seconds = seconds or MAPS.GetClock()
	local hour = seconds / 3600
	return hour >= 22 or hour < 5
end

-- 0 (noche cerrada) a 1 (mediodía)
function MAPS.Daylight(seconds)
	local hour = (seconds or MAPS.GetClock()) / 3600
	return math.Clamp(math.sin((hour - 6) / 24 * math.pi * 2) * 0.5 + 0.5 + 0.15, 0, 1)
end

ix.efg.time = {GetClock = MAPS.GetClock, IsNight = MAPS.IsNight, Format = MAPS.FormatClock}

ix.command.Add("Hora", {
	description = "Muestra la hora de la raid y el clima.",
	OnRun = function(self, client)
		local clock = MAPS.GetClock()
		local location = MAPS.Current()

		return ("%s · %s (otra hora: %s) · clima: %s"):format(location and location.name or game.GetMap(),
			MAPS.FormatClock(clock), MAPS.FormatClock(clock + 12 * 3600), GetNetVar("efgWeather", "despejado"))
	end
})

ix.command.Add("HoraFijar", {
	description = "Fija la hora del reloj de la raid (0-23).",
	adminOnly = true,
	arguments = ix.type.number,
	OnRun = function(self, client, hour)
		MAPS.SetClock(math.Clamp(hour, 0, 23.99) * 3600)
		return "Hora fijada: " .. MAPS.FormatClock(hour * 3600)
	end
})

ix.command.Add("Clima", {
	description = "Cambia el clima: despejado, nublado, niebla o lluvia.",
	adminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, weather)
		if (!MAPS.weathers[weather]) then return "Climas: despejado, nublado, niebla, lluvia." end
		MAPS.SetWeather(weather)
	end
})

MAPS.weathers = {
	despejado = {fog = 0, rain = 0},
	nublado = {fog = 0.25, rain = 0},
	niebla = {fog = 0.75, rain = 0},
	lluvia = {fog = 0.4, rain = 1}
}

ix.util.Include("sh_keys.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
