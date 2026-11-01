PLUGIN.SpawnedDoors = {}
PLUGIN.DoorData = {nextID = 1, doors = {}}

local function GetSavePath()
	return "efg_doors/" .. game.GetMap() .. ".json"
end

-- Ruta de antes del cambio de nombre: se lee si aún no hay archivo nuevo
local function GetLegacyPath()
	return "metrorp_doors/" .. game.GetMap() .. ".json"
end

-- Persistencia -----------------------------------------------------------------

function PLUGIN:SaveDoors()
	file.CreateDir("efg_doors")

	local saveData = {
		nextID = self.DoorData.nextID,
		doors = {}
	}

	for id, data in pairs(self.DoorData.doors) do
		local entry = {
			id = id,
			type = data.type,
			pos = {data.pos.x, data.pos.y, data.pos.z},
			ang = {data.ang.p, data.ang.y, data.ang.r},
			factions = data.factions or {},
			locked = data.locked or false
		}

		if (data.customModel) then
			entry.customModel = data.customModel
		end

		saveData.doors[#saveData.doors + 1] = entry
	end

	file.Write(GetSavePath(), util.TableToJSON(saveData, true))
end

function PLUGIN:LoadDoors()
	local raw = file.Read(GetSavePath(), "DATA") or file.Read(GetLegacyPath(), "DATA")

	if (not raw) then
		self.DoorData = {nextID = 1, doors = {}}
		return
	end

	local parsed = util.JSONToTable(raw)

	if (not parsed) then
		self.DoorData = {nextID = 1, doors = {}}
		return
	end

	self.DoorData = {
		nextID = parsed.nextID or 1,
		doors = {}
	}

	for _, info in ipairs(parsed.doors or {}) do
		local factions = {}

		for _, fID in ipairs(info.factions or {}) do
			if (type(fID) == "string") then
				local faction = ix.faction.teams[fID]

				if (faction) then
					factions[#factions + 1] = faction.index
				end
			else
				factions[#factions + 1] = fID
			end
		end

		self.DoorData.doors[info.id] = {
			type = info.type,
			pos = Vector(info.pos[1], info.pos[2], info.pos[3]),
			ang = Angle(info.ang[1], info.ang[2], info.ang[3]),
			factions = factions,
			locked = info.locked or false,
			customModel = info.customModel
		}

		if (info.id >= self.DoorData.nextID) then
			self.DoorData.nextID = info.id + 1
		end
	end
end

-- Spawning ---------------------------------------------------------------------

function PLUGIN:GetDoorModel(data)
	if (data.customModel) then
		return data.customModel
	end

	local doorType = self:GetDoorType(data.type)

	return doorType and doorType.model
end

function PLUGIN:SpawnDoor(id, data)
	local doorType = self:GetDoorType(data.type)
	local model = self:GetDoorModel(data)

	if (not model) then return end

	local entity = ents.Create("prop_door_rotating")

	if (not IsValid(entity)) then return end

	entity:SetModel(model)
	entity:SetPos(data.pos)
	entity:SetAngles(data.ang)
	entity:SetKeyValue("distance", tostring(doorType and doorType.distance or 90))
	entity:SetKeyValue("speed", tostring(doorType and doorType.speed or 100))
	entity:SetKeyValue("returndelay", tostring(doorType and doorType.returnDelay or 3))
	entity:SetKeyValue("opendir", tostring(doorType and doorType.openDir or 0))
	entity:SetKeyValue("spawnflags", "8192")

	if (doorType and doorType.soundOpen) then
		entity:SetKeyValue("soundopenoverride", doorType.soundOpen)
	end

	if (doorType and doorType.soundClose) then
		entity:SetKeyValue("soundcloseoverride", doorType.soundClose)
	end

	entity:Spawn()
	entity:Activate()
	entity:SetCustomCollisionCheck(true)

	entity.ixDoorID = id
	entity.ixDoorType = data.type
	entity:SetNWInt("ixDoorID", id)
	entity:SetNWString("ixDoorType", data.type)

	self:UpdateDoorNetwork(id, entity, data)
	self.SpawnedDoors[id] = entity

	return entity
end

function PLUGIN:SpawnAllDoors()
	for _, entity in pairs(self.SpawnedDoors) do
		if (IsValid(entity)) then
			entity:Remove()
		end
	end

	self.SpawnedDoors = {}

	for id, data in pairs(self.DoorData.doors) do
		self:SpawnDoor(id, data)
	end
end

function PLUGIN:RemoveDoor(id)
	local entity = self.SpawnedDoors[id]

	if (IsValid(entity)) then
		entity:Remove()
	end

	self.SpawnedDoors[id] = nil
	self.DoorData.doors[id] = nil
	self:SaveDoors()
end

function PLUGIN:GetDoorData(id)
	return self.DoorData.doors[id]
end

function PLUGIN:UpdateDoorNetwork(id, entity, data)
	entity = entity or self.SpawnedDoors[id]
	data = data or self.DoorData.doors[id]

	if (not IsValid(entity) or not data) then return end

	entity:SetNWString("ixDoorFactions", table.concat(data.factions or {}, ","))
	entity:SetNWBool("ixDoorLocked", data.locked or false)
end

-- Hooks ------------------------------------------------------------------------

function PLUGIN:InitPostEntity()
	self:LoadDoors()
	self:SpawnAllDoors()
end

function PLUGIN:PostCleanupMap()
	timer.Simple(0.5, function()
		self:SpawnAllDoors()
	end)
end

function PLUGIN:ShouldCollide(ent1, ent2)
	if (ent1.ixDoorID or ent2.ixDoorID) then
		local other = ent1.ixDoorID and ent2 or ent1

		if (not other:IsPlayer()) then
			return false
		end
	end
end

function PLUGIN:PhysgunPickup(client, entity)
	if (entity.ixDoorPlacement and client:IsAdmin()) then
		return true
	end
end

function PLUGIN:PlayerUse(client, entity)
	if (not entity.ixDoorID) then return end

	local data = self:GetDoorData(entity.ixDoorID)

	if (not data) then return end

	if (data.locked) then
		client:EmitSound("doors/default_locked.wav")
		return false
	end

	if (data.factions and #data.factions > 0) then
		local char = client:GetCharacter()

		if (not char) then
			return false
		end

		if (not table.HasValue(data.factions, char:GetFaction())) then
			client:EmitSound("doors/default_locked.wav")
			return false
		end
	end
end
