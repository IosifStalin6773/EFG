local SAVE_DIR = "tunnel_lights"
local spawnedLights = {}

local DEFAULT_BRIGHTNESS = 1
local DEFAULT_DISTANCE = 400
local DEFAULT_COLOR = "180 170 160 40"

local function GetSaveFile()
	return SAVE_DIR .. "/" .. game.GetMap() .. ".json"
end

local function LoadLightData()
	local path = GetSaveFile()

	if (file.Exists(path, "DATA")) then
		local raw = file.Read(path, "DATA")
		local data = util.JSONToTable(raw or "")

		if (data) then return data end

		ErrorNoHalt("[TunnelLights] Archivo corrupto, intentando backup...\n")
	end

	local bakPath = path .. ".bak"
	if (file.Exists(bakPath, "DATA")) then
		local raw = file.Read(bakPath, "DATA")
		local data = util.JSONToTable(raw or "")

		if (data) then
			ErrorNoHalt("[TunnelLights] Restaurado desde backup.\n")
			file.Write(path, raw)
			return data
		end
	end

	return {}
end

local function SaveLightData(lights)
	file.CreateDir(SAVE_DIR)

	local savePath = GetSaveFile()
	local tempPath = savePath .. ".tmp"
	local json = util.TableToJSON(lights, true)
	file.Write(tempPath, json)

	local written = file.Read(tempPath, "DATA")
	local ok = written and written != "" and pcall(util.JSONToTable, written)

	if (!ok) then
		ErrorNoHalt("[TunnelLights] Fallo al guardar: JSON temporal inválido.\n")
		file.Delete(tempPath)
		return
	end

	if (file.Exists(savePath, "DATA")) then
		local existing = file.Read(savePath, "DATA")
		if (existing and existing != "") then
			file.Write(savePath .. ".bak", existing)
		end
		file.Delete(savePath)
	end

	file.Rename(tempPath, savePath)
end

local function RemoveSpawnedLights()
	for _, ent in ipairs(spawnedLights) do
		if (IsValid(ent)) then
			ent:Remove()
		end
	end

	spawnedLights = {}
end

local function SpawnLights()
	RemoveSpawnedLights()

	local lights = LoadLightData()

	for _, data in ipairs(lights) do
		local ent = ents.Create("light_dynamic")

		if (IsValid(ent)) then
			ent:SetPos(Vector(data.x, data.y, data.z))
			ent:SetKeyValue("_light", data.color or DEFAULT_COLOR)
			ent:SetKeyValue("brightness", tostring(data.brightness or DEFAULT_BRIGHTNESS))
			ent:SetKeyValue("distance", tostring(data.distance or DEFAULT_DISTANCE))
			ent:SetKeyValue("style", "0")
			ent:Spawn()
			ent:Activate()
			ent:Fire("TurnOn")

			table.insert(spawnedLights, ent)
		end
	end

	if (#spawnedLights > 0) then
		print("[TunnelLights] " .. #spawnedLights .. " luces spawneadas en " .. game.GetMap())
	end
end

function PLUGIN:InitPostEntity()
	SpawnLights()
end

function PLUGIN:PostCleanupMap()
	timer.Simple(1, function()
		SpawnLights()
	end)
end

ix.command.Add("LuzAgregar", {
	description = "Agrega una luz ambiental tenue en tu posición.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.number, ix.type.optional),
		bit.bor(ix.type.number, ix.type.optional)
	},
	argumentNames = {"brillo (def: 1)", "distancia (def: 400)"},
	OnRun = function(self, client, brightness, distance)
		local pos = client:GetPos() + Vector(0, 0, 64)
		local lights = LoadLightData()

		table.insert(lights, {
			x = math.Round(pos.x, 1),
			y = math.Round(pos.y, 1),
			z = math.Round(pos.z, 1),
			brightness = brightness or DEFAULT_BRIGHTNESS,
			distance = distance or DEFAULT_DISTANCE,
			color = DEFAULT_COLOR
		})

		SaveLightData(lights)
		SpawnLights()

		client:Notify("Luz ambiental agregada. Total: " .. #lights)
	end
})

ix.command.Add("LuzEliminar", {
	description = "Elimina la luz más cercana a tu posición.",
	adminOnly = true,
	OnRun = function(self, client)
		local pos = client:GetPos()
		local lights = LoadLightData()
		local closest, closestDist = nil, math.huge

		for i, data in ipairs(lights) do
			local dist = pos:Distance(Vector(data.x, data.y, data.z))

			if (dist < closestDist) then
				closest = i
				closestDist = dist
			end
		end

		if (closest and closestDist < 600) then
			table.remove(lights, closest)
			SaveLightData(lights)
			SpawnLights()

			client:Notify("Luz eliminada. Restantes: " .. #lights)
		else
			client:Notify("No hay luces cercanas (radio: 600u).")
		end
	end
})

ix.command.Add("LuzRecargar", {
	description = "Recarga todas las luces del mapa.",
	adminOnly = true,
	OnRun = function(self, client)
		SpawnLights()
		client:Notify("Luces recargadas: " .. #spawnedLights)
	end
})

ix.command.Add("LuzListar", {
	description = "Muestra todas las luces guardadas para este mapa.",
	adminOnly = true,
	OnRun = function(self, client)
		local lights = LoadLightData()

		if (#lights == 0) then
			client:Notify("No hay luces guardadas para este mapa.")
			return
		end

		for i, data in ipairs(lights) do
			local pos = Vector(data.x, data.y, data.z)
			local dist = math.Round(client:GetPos():Distance(pos))
			client:ChatPrint("[" .. i .. "] Pos: " .. tostring(pos) .. " | Dist: " .. dist .. "u | Brillo: " .. (data.brightness or DEFAULT_BRIGHTNESS))
		end
	end
})

ix.command.Add("LuzBrillo", {
	description = "Ajusta el brillo de la luz más cercana.",
	adminOnly = true,
	arguments = {ix.type.number},
	argumentNames = {"brillo"},
	OnRun = function(self, client, brightness)
		local pos = client:GetPos()
		local lights = LoadLightData()
		local closest, closestDist = nil, math.huge

		for i, data in ipairs(lights) do
			local dist = pos:Distance(Vector(data.x, data.y, data.z))

			if (dist < closestDist) then
				closest = i
				closestDist = dist
			end
		end

		if (closest and closestDist < 600) then
			lights[closest].brightness = brightness
			SaveLightData(lights)
			SpawnLights()

			client:Notify("Brillo ajustado a " .. brightness)
		else
			client:Notify("No hay luces cercanas.")
		end
	end
})
