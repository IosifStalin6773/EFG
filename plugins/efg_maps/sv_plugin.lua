local PLUGIN = PLUGIN

if (!SERVER) then return end

local MAPS = ix.efg.maps

function MAPS.SetClock(seconds)
	SetNetVar("efgClockBase", seconds % 86400)
	SetNetVar("efgClockStart", CurTime())
end

function MAPS.SetWeather(weather)
	SetNetVar("efgWeather", weather)
end

function PLUGIN:InitPostEntity()
	-- la raid empieza a una hora aleatoria, como el reloj de EFT
	MAPS.SetClock(math.random(0, 86399))
	MAPS.SetWeather("despejado")
end

-- Duración de la raid según la localización (efg_raids)
function PLUGIN:EFGGetRaidMinutes(client, side)
	local location = MAPS.Current()
	if (!location) then return end

	if (side == "scav" and location.scavMinutes > 0) then
		return location.scavMinutes
	end

	return location.minutes
end

-- ─── Iluminación de día y noche ─────────────────────────────────────────────
-- engine.LightStyle va de "a" (oscuro) a "m" (normal) y "z" (muy claro).
local lastStyle
local nextLight, nextWeather = 0, 0

function PLUGIN:Think()
	if (nextLight <= CurTime()) then
		nextLight = CurTime() + 10

		if (ix.config.Get("efgDayNight", true)) then
			local letter = string.char(string.byte("b") + math.floor(MAPS.Daylight() * 11))

			if (letter != lastStyle) then
				lastStyle = letter
				engine.LightStyle(0, letter)

				net.Start("ixEFGRelight")
				net.Broadcast()
			end
		elseif (lastStyle) then
			lastStyle = nil
			engine.LightStyle(0, "m")
		end
	end

	-- el clima cambia cada 20-40 min de juego real
	if (ix.config.Get("efgWeather", true) and nextWeather <= CurTime()) then
		nextWeather = CurTime() + math.random(1200, 2400)

		local roll = math.random(100)
		MAPS.SetWeather(roll <= 50 and "despejado" or roll <= 75 and "nublado" or roll <= 88 and "lluvia" or "niebla")
	end
end

util.AddNetworkString("ixEFGRelight")
