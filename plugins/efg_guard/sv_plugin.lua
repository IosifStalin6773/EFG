local PLUGIN = PLUGIN

if (!SERVER) then return end

-- Cada receptor de net.Receivers se envuelve con un contador por jugador y
-- segundo. Por encima de efgNetLimit se descartan los mensajes; por encima de
-- efgNetKick se expulsa (inundación de red / exploits de net).
local counts = {}

local function allowed(client, name)
	if (!IsValid(client)) then return true end

	local now = math.floor(CurTime())
	local entry = counts[client]

	if (!entry or entry.second != now) then
		entry = {second = now, count = 0}
		counts[client] = entry
	end

	entry.count = entry.count + 1

	local kick = ix.config.Get("efgNetKick", 600)

	if (kick > 0 and entry.count > kick and !entry.kicked) then
		entry.kicked = true
		ix.log.AddRaw(("[EFG Guardia] %s (%s) expulsado: %d mensajes de red en 1 s (último: %s)"):format(client:Name(), client:SteamID(), entry.count, name))
		client:Kick("Demasiados mensajes de red")

		return false
	end

	if (entry.count > ix.config.Get("efgNetLimit", 150)) then
		if (!entry.warned) then
			entry.warned = true
			ix.log.AddRaw(("[EFG Guardia] %s (%s) supera el límite de red (%s)"):format(client:Name(), client:SteamID(), name))
		end

		return false
	end

	return true
end

local function wrapAll()
	for name, fn in pairs(net.Receivers) do
		if (isfunction(fn) and !PLUGIN.wrapped[name]) then
			PLUGIN.wrapped[name] = true

			net.Receivers[name] = function(length, client)
				if (allowed(client, name)) then
					return fn(length, client)
				end
			end
		end
	end
end

PLUGIN.wrapped = PLUGIN.wrapped or {}

-- tras cargar todo (y otra vez al empezar el mapa, por los receptores tardíos)
function PLUGIN:InitializedPlugins()
	wrapAll()
end

function PLUGIN:InitPostEntity()
	timer.Simple(5, wrapAll)
end

function PLUGIN:PlayerDisconnected(client)
	counts[client] = nil
end
