local PLUGIN = PLUGIN

PLUGIN.doors = PLUGIN.doors or {}
PLUGIN.buttonToDoor = PLUGIN.buttonToDoor or {}
PLUGIN.nextDoorID = PLUGIN.nextDoorID or 1

local DATA_PATH = "metrorp/puertas_brecheables.json"
local COUNTDOWN_DURATION = 10
local RESPAWN_DURATION = 15 * 60

util.AddNetworkString("PB_SendDoorList")

--------------------------------------------------------------------------------
-- Persistencia
--------------------------------------------------------------------------------

function PLUGIN:SaveConfig()
	if (!file.Exists("metrorp", "DATA")) then
		file.CreateDir("metrorp")
	end
	local config = { nextID = self.nextDoorID, doors = {} }
	for id, info in pairs(self.doors) do
		config.doors[tostring(id)] = {
			mapCreationID    = info.mapCreationID,
			linkedButtonMCID = info.linkedButtonMCID,
			destroyedAt      = info.destroyedAt,
		}
	end

	local tempPath = DATA_PATH .. ".tmp"
	local json = util.TableToJSON(config)
	file.Write(tempPath, json)

	local written = file.Read(tempPath, "DATA")
	local ok = written and written != "" and pcall(util.JSONToTable, written)

	if (!ok) then
		ErrorNoHalt("[PuertasBrecheables] Fallo al guardar: JSON temporal inválido.\n")
		file.Delete(tempPath)
		return
	end

	if (file.Exists(DATA_PATH, "DATA")) then
		local existing = file.Read(DATA_PATH, "DATA")
		if (existing and existing != "") then
			file.Write(DATA_PATH .. ".bak", existing)
		end
		file.Delete(DATA_PATH)
	end

	file.Rename(tempPath, DATA_PATH)
end

local function FindEntityByMCID(mCID)
	if (!mCID or mCID == -1) then return nil end
	for _, ent in ipairs(ents.GetAll()) do
		if (ent:MapCreationID() == mCID) then
			return ent
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Utilidades internas
--------------------------------------------------------------------------------

function PLUGIN:RebuildButtonMap()
	self.buttonToDoor = {}
	for id, info in pairs(self.doors) do
		if (info.linkedButtonMCID) then
			local btn = FindEntityByMCID(info.linkedButtonMCID)
			if (IsValid(btn)) then
				self.buttonToDoor[btn:EntIndex()] = id
			end
		end
	end
end

function PLUGIN:GetDoorByEntity(ent)
	if (!IsValid(ent)) then return nil end
	for _, info in pairs(self.doors) do
		if (info.entity == ent) then
			return info
		end
	end
	return nil
end

function PLUGIN:HideDoor(ent)
	if (!IsValid(ent)) then return end
	ent:SetNoDraw(true)
	ent:SetNotSolid(true)
	ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- necesario para brush entities como func_door
end

function PLUGIN:ShowDoor(ent)
	if (!IsValid(ent)) then return end
	ent:SetNoDraw(false)
	ent:SetNotSolid(false)
	ent:SetCollisionGroup(COLLISION_GROUP_NONE)
end

--------------------------------------------------------------------------------
-- Lógica principal
--------------------------------------------------------------------------------

function PLUGIN:PlaceExplosive(client, ent)
	local doorInfo = self:GetDoorByEntity(ent)
	if (!doorInfo) then
		return false, "Esta puerta no está registrada como brecha."
	end
	if (doorInfo.isDestroyed) then
		return false, "Esta puerta ya ha sido destruida."
	end
	if (doorInfo.hasExplosive) then
		return false, "Ya hay un explosivo colocado en esta puerta."
	end
	if (client:GetPos():Distance(ent:GetPos()) > 250) then
		return false, "Estás demasiado lejos de la puerta."
	end

	doorInfo.hasExplosive = true

	local doorPos = ent:GetPos()

	sound.Play("buttons/button17.wav", doorPos, 100, 100, 1)

	timer.Create("PB_Explode_" .. doorInfo.id, COUNTDOWN_DURATION, 1, function()
		self:ExplodeDoor(doorInfo)
	end)

	return true
end

function PLUGIN:ExplodeDoor(doorInfo)
	if (!doorInfo) then return end

	doorInfo.hasExplosive = false
	doorInfo.isDestroyed  = true
	doorInfo.destroyedAt  = os.time()
	self:SaveConfig()

	local ent = doorInfo.entity
	local pos = IsValid(ent) and ent:GetPos() or Vector(0, 0, 0)

	local fx = EffectData()
	fx:SetOrigin(pos)
	fx:SetMagnitude(2)
	fx:SetRadius(200)
	util.Effect("Explosion", fx)

	sound.Play("ambient/explosions/explode_" .. math.random(1, 9) .. ".wav", pos, 150, 100, 1)
	util.ScreenShake(pos, 12, 5, 2, 600)

	for _, ply in ipairs(player.GetAll()) do
		local dist = ply:GetPos():Distance(pos)
		if (dist < 300) then
			local dmg = DamageInfo()
			dmg:SetDamage(math.Clamp((1 - dist / 300) * 120, 0, 120))
			dmg:SetDamageType(DMG_BLAST)
			dmg:SetInflictor(game.GetWorld())
			dmg:SetAttacker(game.GetWorld())
			ply:TakeDamageInfo(dmg)
		end
	end

	self:HideDoor(ent)

	timer.Create("PB_Respawn_" .. doorInfo.id, RESPAWN_DURATION, 1, function()
		self:RespawnDoor(doorInfo)
	end)
end

function PLUGIN:RespawnDoor(doorInfo)
	if (!doorInfo) then return end

	doorInfo.isDestroyed = false
	doorInfo.destroyedAt = nil
	self:SaveConfig()

	local ent = doorInfo.entity
	self:ShowDoor(ent)

	if (IsValid(ent)) then
		ent:Fire("Close", "", 0)

		local pos = ent:GetPos()
		for _, ply in ipairs(player.GetAll()) do
			if (ply:GetPos():Distance(pos) < 600) then
				ply:Notify("Una puerta cercana ha sido reparada.")
			end
		end
	end
end

function PLUGIN:SendDoorListTo(client)
	net.Start("PB_SendDoorList")
		net.WriteUInt(table.Count(self.doors), 8)
		for id, info in pairs(self.doors) do
			net.WriteUInt(id, 8)
			net.WriteVector(IsValid(info.entity) and info.entity:GetPos() or Vector(0, 0, 0))
			net.WriteBool(info.isDestroyed)
			net.WriteBool(info.hasExplosive)
			net.WriteString(IsValid(info.entity) and info.entity:GetClass() or "desconocida")
			local hasButton = info.linkedButtonMCID != nil
			net.WriteBool(hasButton)
			if (hasButton) then
				local btn = FindEntityByMCID(info.linkedButtonMCID)
				net.WriteVector(IsValid(btn) and btn:GetPos() or Vector(0, 0, 0))
			end
		end
	net.Send(client)
end

--------------------------------------------------------------------------------
-- Inicialización
--------------------------------------------------------------------------------

function PLUGIN:Initialize()
	if (!file.Exists(DATA_PATH, "DATA")) then return end

	local config = util.JSONToTable(file.Read(DATA_PATH, "DATA") or "")

	if (!config) then
		local bakPath = DATA_PATH .. ".bak"
		if (file.Exists(bakPath, "DATA")) then
			local raw = file.Read(bakPath, "DATA")
			config = util.JSONToTable(raw or "")

			if (config) then
				ErrorNoHalt("[PuertasBrecheables] Archivo corrupto, restaurado desde backup.\n")
				file.Write(DATA_PATH, raw)
			end
		end
	end

	if (!config) then return end

	self.nextDoorID = config.nextID or 1

	-- Solo carga datos crudos; las entidades se resuelven en InitPostEntity
	for idStr, saved in pairs(config.doors or {}) do
		local id = tonumber(idStr)
		self.doors[id] = {
			id               = id,
			mapCreationID    = saved.mapCreationID,
			entity           = nil,
			isDestroyed      = false,
			hasExplosive     = false,
			destroyedAt      = saved.destroyedAt,
			linkedButtonMCID = saved.linkedButtonMCID,
		}
	end
end

-- Resuelve entidades y restaura estados una vez que el mapa está completamente cargado
function PLUGIN:InitPostEntity()
	local needsSave = false

	for id, info in pairs(self.doors) do
		info.entity = FindEntityByMCID(info.mapCreationID)

		if (info.destroyedAt) then
			local remaining = RESPAWN_DURATION - (os.time() - info.destroyedAt)
			if (remaining > 0) then
				info.isDestroyed = true
				self:HideDoor(info.entity)
				local capturedInfo = info
				timer.Create("PB_Respawn_" .. id, remaining, 1, function()
					self:RespawnDoor(capturedInfo)
				end)
			else
				-- El tiempo de reaparición venció mientras el servidor estaba caído
				info.isDestroyed = false
				info.destroyedAt = nil
				self:ShowDoor(info.entity)
				needsSave = true
			end
		end
	end

	self:RebuildButtonMap()

	if (needsSave) then
		self:SaveConfig()
	end
end

function PLUGIN:PostCleanupMap()
	for _, info in pairs(self.doors) do
		info.entity = FindEntityByMCID(info.mapCreationID)
		if (!info.isDestroyed) then
			self:ShowDoor(info.entity)
		else
			self:HideDoor(info.entity)
		end
	end
	self:RebuildButtonMap()
end

--------------------------------------------------------------------------------
-- Hook: botón vinculado abre la puerta
--------------------------------------------------------------------------------

function PLUGIN:PlayerUse(client, entity)
	if (!IsValid(entity)) then return end

	local doorID = self.buttonToDoor[entity:EntIndex()]
	if (!doorID) then return end

	local info = self.doors[doorID]
	if (!info or info.isDestroyed) then return end

	local door = info.entity
	if (!IsValid(door)) then return end

	door:Fire("Open", "", 0)
end
