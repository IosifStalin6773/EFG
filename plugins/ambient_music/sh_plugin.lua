local PLUGIN = PLUGIN

PLUGIN.name = "Ambient Music"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Reproduce música ambiental en posiciones del mapa. Múltiples puntos comparten el mismo audio sincronizado y en bucle."

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

ix.command.Add("AmbientMusicAdd", {
	description = "Añade tu posición actual como punto de emisión de música ambiental.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("ambient_music")
		local pos = client:GetPos()

		table.insert(plugin.points, {pos.x, pos.y, pos.z})
		plugin:SaveConfig()
		plugin:SyncAll()

		client:ChatPrint("[AmbientMusic] Punto #" .. #plugin.points .. " añadido.")
	end
})

ix.command.Add("AmbientMusicRemove", {
	description = "Elimina el punto de emisión más cercano a tu posición.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("ambient_music")

		if (#plugin.points == 0) then
			client:ChatPrint("[AmbientMusic] No hay puntos configurados.")
			return
		end

		local pos = client:GetPos()
		local bestIndex, bestDist = 1, math.huge

		for i, p in ipairs(plugin.points) do
			local dist = pos:DistToSqr(Vector(p[1], p[2], p[3]))

			if (dist < bestDist) then
				bestIndex = i
				bestDist = dist
			end
		end

		table.remove(plugin.points, bestIndex)
		plugin:SaveConfig()
		plugin:SyncAll()

		client:ChatPrint("[AmbientMusic] Punto #" .. bestIndex .. " eliminado. Quedan " .. #plugin.points .. ".")
	end
})

ix.command.Add("AmbientMusicSound", {
	description = "Establece el archivo de sonido (ruta relativa a sound/).",
	adminOnly = true,
	arguments = {ix.type.text},
	OnRun = function(self, client, path)
		local plugin = ix.plugin.Get("ambient_music")

		plugin.soundPath = path
		plugin:SaveConfig()
		plugin:SyncAll()

		client:ChatPrint("[AmbientMusic] Sonido: " .. path)
	end
})

ix.command.Add("AmbientMusicRadius", {
	description = "Establece el radio de audición en unidades.",
	adminOnly = true,
	arguments = {ix.type.number},
	OnRun = function(self, client, radius)
		local plugin = ix.plugin.Get("ambient_music")

		plugin.radius = math.max(100, radius)
		plugin:SaveConfig()
		plugin:SyncAll()

		client:ChatPrint("[AmbientMusic] Radio: " .. plugin.radius .. " unidades.")
	end
})

ix.command.Add("AmbientMusicVolume", {
	description = "Establece el volumen máximo (0-100).",
	adminOnly = true,
	arguments = {ix.type.number},
	OnRun = function(self, client, vol)
		local plugin = ix.plugin.Get("ambient_music")

		plugin.maxVolume = math.Clamp(vol, 0, 100) / 100
		plugin:SaveConfig()
		plugin:SyncAll()

		client:ChatPrint("[AmbientMusic] Volumen: " .. math.Round(plugin.maxVolume * 100) .. "%.")
	end
})

ix.command.Add("AmbientMusicList", {
	description = "Lista los puntos de emisión y la configuración actual.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("ambient_music")

		client:ChatPrint("[AmbientMusic] Sonido: " .. (plugin.soundPath != "" and plugin.soundPath or "(ninguno)"))
		client:ChatPrint("[AmbientMusic] Radio: " .. plugin.radius .. " | Volumen: " .. math.Round(plugin.maxVolume * 100) .. "%")
		client:ChatPrint("[AmbientMusic] Puntos: " .. #plugin.points)

		for i, p in ipairs(plugin.points) do
			client:ChatPrint("  #" .. i .. ": " .. math.Round(p[1]) .. ", " .. math.Round(p[2]) .. ", " .. math.Round(p[3]))
		end
	end
})

ix.command.Add("AmbientMusicClear", {
	description = "Elimina todos los puntos y detiene la música.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("ambient_music")

		plugin.points = {}
		plugin.soundPath = ""
		plugin:SaveConfig()
		plugin:StopAll()

		client:ChatPrint("[AmbientMusic] Configuración limpiada.")
	end
})
