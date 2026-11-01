PLUGIN.name = "Puertas Funcionales"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Sistema de puertas colocables con animación nativa y control de acceso por facción."

PLUGIN.DoorTypes = {
	["madera"] = {
		name = "Puerta de Madera",
		description = "Puerta de madera desgastada, habitual en las estaciones habitadas del metro.",
		model = "models/props_c17/door01_left.mdl",
		distance = 90,
		speed = 100,
		returnDelay = 3,
		openDir = 0
	},
	["metalica"] = {
		name = "Puerta Metálica",
		description = "Puerta de metal con ranuras, típica de instalaciones militares y búnkers.",
		model = "models/props_doors/door03_slotted_left.mdl",
		distance = 90,
		speed = 80,
		returnDelay = 4,
		openDir = 0
	},
	["reja"] = {
		name = "Reja Metálica",
		description = "Una reja metálica que permite ver al otro lado. Común en puestos fronterizos.",
		model = "models/props_c17/gate_door01a.mdl",
		distance = 90,
		speed = 120,
		returnDelay = 3,
		openDir = 0
	}
}

for _, doorType in pairs(PLUGIN.DoorTypes) do
	util.PrecacheModel(doorType.model)
end

function PLUGIN:GetDoorType(typeID)
	return self.DoorTypes[typeID]
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- Helpers compartidos para comandos --------------------------------------------

local function FindFaction(name)
	name = name:lower()

	for index, faction in pairs(ix.faction.indices) do
		if (faction.name:lower():find(name, 1, true)) then
			return index, faction
		end
	end
end

local function GetTargetDoor(client)
	local entity = client:GetEyeTraceNoCursor().Entity

	if (IsValid(entity) and entity.ixDoorID) then
		return entity
	end
end

local function GetTargetPlacement(client)
	local entity = client:GetEyeTraceNoCursor().Entity

	if (IsValid(entity) and entity.ixDoorPlacement) then
		return entity
	end
end

-- Comandos ---------------------------------------------------------------------

ix.command.Add("PuertaColocar", {
	description = "Coloca una puerta temporal. Tipo predefinido o modelo custom: /PuertaColocar madera | /PuertaColocar custom models/props/mipuerta.mdl",
	arguments = {ix.type.string, bit.bor(ix.type.string, ix.type.optional)},
	adminOnly = true,
	OnRun = function(self, client, typeOrModel, customModel)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local typeID = typeOrModel:lower()
			local model
			local displayName

			if (typeID == "custom") then
				if (not customModel or customModel == "") then
					return "Debes indicar la ruta del modelo: /PuertaColocar custom models/ruta/modelo.mdl"
				end

				if (not util.IsValidModel(customModel)) then
					return "Modelo no válido: " .. customModel
				end

				model = customModel
				displayName = string.GetFileFromFilename(customModel)
				typeID = "custom"
			else
				local doorType = plugin:GetDoorType(typeID)

				if (not doorType) then
					return "Tipo no válido. Usa /PuertaTipos para ver la lista, o /PuertaColocar custom <modelo>."
				end

				model = doorType.model
				displayName = doorType.name
			end

			local yaw = client:EyeAngles().y
			local forward = Angle(0, yaw, 0):Forward()
			local spawnPos = client:GetPos() + forward * 100

			local entity = ents.Create("prop_physics")

			if (not IsValid(entity)) then
				return "Error al crear la puerta."
			end

			entity:SetModel(model)
			entity:SetPos(spawnPos)
			entity:SetAngles(Angle(0, yaw + 90, 0))
			entity:Spawn()
			entity:Activate()

			local physObj = entity:GetPhysicsObject()

			if (IsValid(physObj)) then
				physObj:EnableMotion(false)
			end

			entity.ixDoorPlacement = true
			entity.ixDoorTypeID = typeID
			entity.ixDoorCustomModel = (typeID == "custom") and model or nil

			client:ChatPrint("[Puertas] '" .. displayName .. "' colocada. Muévela con la Physics Gun y usa /PuertaGuardar.")
		end
	end
})

ix.command.Add("PuertaGuardar", {
	description = "Guarda la posición de la puerta temporal que estás mirando y la convierte en puerta funcional.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local entity = GetTargetPlacement(client)

			if (not entity) then
				return "No estás mirando a una puerta temporal. Coloca una con /PuertaColocar."
			end

			local typeID = entity.ixDoorTypeID
			local customModel = entity.ixDoorCustomModel
			local pos = entity:GetPos()
			local ang = entity:GetAngles()

			entity:Remove()

			local id = plugin.DoorData.nextID
			plugin.DoorData.nextID = id + 1

			plugin.DoorData.doors[id] = {
				type = typeID,
				pos = pos,
				ang = ang,
				factions = {},
				locked = false,
				customModel = customModel
			}

			local door = plugin:SpawnDoor(id, plugin.DoorData.doors[id])

			if (IsValid(door)) then
				plugin:SaveDoors()
				client:ChatPrint("[Puertas] Puerta guardada (ID: " .. id .. ").")
			else
				plugin.DoorData.doors[id] = nil
				return "Error al crear la puerta definitiva."
			end
		end
	end
})

ix.command.Add("PuertaEliminar", {
	description = "Elimina la puerta que estás mirando (guardada o temporal).",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")

			-- Intentar puerta guardada
			local door = GetTargetDoor(client)

			if (door) then
				local id = door.ixDoorID
				plugin:RemoveDoor(id)
				client:ChatPrint("[Puertas] Puerta #" .. id .. " eliminada.")
				return
			end

			-- Intentar puerta temporal
			local placement = GetTargetPlacement(client)

			if (placement) then
				placement:Remove()
				client:ChatPrint("[Puertas] Puerta temporal eliminada.")
				return
			end

			return "No estás mirando a una puerta del sistema."
		end
	end
})

ix.command.Add("PuertaFaccion", {
	description = "Asigna o quita una facción de la puerta que estás mirando.",
	arguments = {ix.type.string},
	adminOnly = true,
	OnRun = function(self, client, factionName)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local door = GetTargetDoor(client)

			if (not door) then
				return "No estás mirando a una puerta guardada."
			end

			local factionID, faction = FindFaction(factionName)

			if (not factionID) then
				return "Facción '" .. factionName .. "' no encontrada."
			end

			local data = plugin:GetDoorData(door.ixDoorID)

			if (not data) then return end

			data.factions = data.factions or {}

			local index = table.KeyFromValue(data.factions, factionID)

			if (index) then
				table.remove(data.factions, index)
				client:ChatPrint("[Puertas] Facción '" .. faction.name .. "' removida de puerta #" .. door.ixDoorID .. ".")
			else
				data.factions[#data.factions + 1] = factionID
				client:ChatPrint("[Puertas] Facción '" .. faction.name .. "' asignada a puerta #" .. door.ixDoorID .. ".")
			end

			plugin:UpdateDoorNetwork(door.ixDoorID)
			plugin:SaveDoors()
		end
	end
})

ix.command.Add("PuertaCerrar", {
	description = "Bloquea o desbloquea la puerta que estás mirando para todos.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local door = GetTargetDoor(client)

			if (not door) then
				return "No estás mirando a una puerta guardada."
			end

			local data = plugin:GetDoorData(door.ixDoorID)

			if (not data) then return end

			data.locked = not data.locked
			plugin:UpdateDoorNetwork(door.ixDoorID)
			plugin:SaveDoors()

			local status = data.locked and "BLOQUEADA" or "DESBLOQUEADA"
			client:ChatPrint("[Puertas] Puerta #" .. door.ixDoorID .. " " .. status .. ".")
		end
	end
})

ix.command.Add("PuertaRotar", {
	description = "Rota la puerta que estás mirando X grados en horizontal.",
	arguments = {ix.type.number},
	adminOnly = true,
	OnRun = function(self, client, degrees)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local door = GetTargetDoor(client)

			if (not door) then
				return "No estás mirando a una puerta guardada."
			end

			local data = plugin:GetDoorData(door.ixDoorID)

			if (not data) then return end

			data.ang = data.ang + Angle(0, degrees, 0)

			if (IsValid(plugin.SpawnedDoors[door.ixDoorID])) then
				plugin.SpawnedDoors[door.ixDoorID]:Remove()
			end

			plugin:SpawnDoor(door.ixDoorID, data)
			plugin:SaveDoors()

			client:ChatPrint("[Puertas] Puerta #" .. door.ixDoorID .. " rotada " .. degrees .. "°.")
		end
	end
})

ix.command.Add("PuertaTipos", {
	description = "Lista los tipos de puertas disponibles.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")

			client:ChatPrint("[Puertas] === Tipos disponibles ===")

			for typeID, data in SortedPairs(plugin.DoorTypes) do
				client:ChatPrint("  " .. typeID .. " — " .. data.name)
			end
		end
	end
})

ix.command.Add("PuertaInfo", {
	description = "Muestra información de la puerta que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")
			local door = GetTargetDoor(client)

			if (not door) then
				return "No estás mirando a una puerta guardada."
			end

			local data = plugin:GetDoorData(door.ixDoorID)

			if (not data) then return end

			local doorType = plugin:GetDoorType(data.type)
			local typeName = doorType and doorType.name or data.type

			client:ChatPrint("[Puertas] === Puerta #" .. door.ixDoorID .. " ===")
			client:ChatPrint("  Tipo: " .. typeName)
			client:ChatPrint("  Estado: " .. (data.locked and "Bloqueada" or "Desbloqueada"))

			if (#(data.factions or {}) > 0) then
				local names = {}

				for _, fID in ipairs(data.factions) do
					local f = ix.faction.teams[fID]

					if (f) then
						names[#names + 1] = f.name
					end
				end

				client:ChatPrint("  Facciones: " .. table.concat(names, ", "))
			else
				client:ChatPrint("  Facciones: Ninguna (pública)")
			end
		end
	end
})

ix.command.Add("PuertaListar", {
	description = "Lista todas las puertas colocadas en el mapa actual.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas")

			if (table.IsEmpty(plugin.DoorData.doors)) then
				return "No hay puertas colocadas en este mapa."
			end

			client:ChatPrint("[Puertas] === Puertas en " .. game.GetMap() .. " ===")

			for id, data in SortedPairs(plugin.DoorData.doors) do
				local doorType = plugin:GetDoorType(data.type)
				local typeName = doorType and doorType.name or data.type
				local status = data.locked and "BLOQUEADA" or "OK"
				local fCount = #(data.factions or {})
				local fText = fCount > 0 and (fCount .. " facciones") or "pública"

				client:ChatPrint(string.format("  [%d] %s | %s | %s", id, typeName, status, fText))
			end
		end
	end
})
