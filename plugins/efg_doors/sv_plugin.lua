local PLUGIN = PLUGIN
local DOORS = ix.efg.doors

util.AddNetworkString("efgDoorAction")
util.AddNetworkString("efgDoorNotice")
util.AddNetworkString("efgDoorKeyhole")

DOORS.list = DOORS.list or {}

local SOUND_LOCKED = "doors/default_locked.wav"
local SOUND_LATCH = "doors/door_latch3.wav"
local SOUND_KICK = "physics/wood/wood_panel_impact_hard1.wav"
local SOUND_BREACH = "physics/wood/wood_crate_break3.wav"
local SOUND_LOCKSHOT = "physics/metal/metal_box_break1.wav"

local function notice(client, key, red)
	if (!IsValid(client)) then return end

	net.Start("efgDoorNotice")
		net.WriteString(key)
		net.WriteBool(red == true)
	net.Send(client)
end

-- ─── Valores del mapa ────────────────────────────────────────────────────────
-- Distancia y velocidad originales: entreabrir y patear las cambian y hay
-- que devolverlas al cerrar.
function PLUGIN:EntityKeyValue(entity, key, value)
	local class = entity:GetClass()
	key = string.lower(key)

	if (class == "prop_door_rotating") then
		if (key == "distance") then
			entity.efgDoorDistance = tonumber(value)
		elseif (key == "speed") then
			entity.efgDoorSpeed = tonumber(value)
		end
	elseif (class == "func_areaportal" and key == "target") then
		entity.efgDoorTarget = value
	end
end

local function baseDistance(door)
	return door.efgDoorDistance or tonumber(door:GetInternalVariable("distance")) or 90
end

local function baseSpeed(door)
	return door.efgDoorSpeed or tonumber(door:GetInternalVariable("speed")) or 100
end

local function restore(door)
	if (door:GetClass() != "prop_door_rotating") then return end

	door:Fire("SetSpeed", tostring(baseSpeed(door)))
	door:Fire("SetRotationDistance", tostring(baseDistance(door)))
	door.efgDoorDirty = nil
end

-- ─── Estado ──────────────────────────────────────────────────────────────────
local function isOpen(door)
	if (door:GetClass() == "prop_door_rotating") then
		-- m_eDoorState: 0 cerrada, 1 abriendo, 2 abierta, 3 cerrando, 4 entornada
		return door:GetInternalVariable("m_eDoorState") != 0
	end

	-- func_door_rotating, m_toggle_state: 1 = abajo (cerrada)
	return door:GetInternalVariable("m_toggle_state") != 1
end

local function updateState(door)
	local locked = door:GetInternalVariable("m_bLocked") == true
	local state = DOORS.STATE_CLOSED

	if (isOpen(door)) then
		state = door.efgDoorPeek and DOORS.STATE_PEEK or DOORS.STATE_OPEN
	else
		door.efgDoorPeek = nil

		if (door.efgDoorDirty) then
			restore(door)
		end
	end

	if (door:GetNW2Int("efgDoorState", -1) != state) then
		door:SetNW2Int("efgDoorState", state)
	end

	if (door:GetNW2Bool("efgDoorLocked", false) != locked) then
		door:SetNW2Bool("efgDoorLocked", locked)
	end
end

function DOORS.Rebuild()
	DOORS.list = {}

	for class in pairs(DOORS.classes) do
		for _, door in ipairs(ents.FindByClass(class)) do
			DOORS.list[#DOORS.list + 1] = door
		end
	end
end

function PLUGIN:InitPostEntity()
	DOORS.Rebuild()
end

function PLUGIN:PostCleanupMap()
	DOORS.Rebuild()
end

function PLUGIN:OnEntityCreated(entity)
	if (!DOORS.classes[entity:GetClass()]) then return end

	-- al cargar el mapa salen cientos seguidas: una sola reconstrucción
	timer.Create("efgDoors.Rebuild", 0, 1, DOORS.Rebuild)
end

-- ─── Mirilla ─────────────────────────────────────────────────────────────────
local function handleY(door)
	local mins, maxs = door:OBBMins(), door:OBBMaxs()

	-- el pomo está en el canto más lejano de la bisagra (origen del modelo)
	if (math.abs(maxs.y) >= math.abs(mins.y)) then
		return maxs.y - 5
	end

	return mins.y + 5
end

local function setPortals(door, open)
	local name = door:GetName()
	if (!name or name == "") then return end

	for _, portal in ipairs(ents.FindByClass("func_areaportal")) do
		if (portal.efgDoorTarget == name) then
			portal:Fire(open and "Open" or "Close")
		end
	end
end

function DOORS.EndKeyhole(client)
	local data = IsValid(client) and client.efgKeyhole
	if (!data) then return end

	client.efgKeyhole = nil

	if (IsValid(client)) then
		client:Freeze(false)

		net.Start("efgDoorKeyhole")
			net.WriteBool(false)
		net.Send(client)
	end

	local door = data.door

	if (IsValid(door)) then
		door.efgKeyholeBy = nil

		if (!isOpen(door)) then
			setPortals(door, false)
		end
	end
end

local function startKeyhole(client, door)
	if (IsValid(door.efgKeyholeBy) and door.efgKeyholeBy != client) then
		notice(client, "efgDoorKeyholeBusy", true)
		return
	end

	local side = door:WorldToLocal(client:GetPos()).x >= 0 and -1 or 1
	local center = door:OBBCenter()
	local pos = door:LocalToWorld(Vector(side * 6, handleY(door), center.z + 4))
	local ang = (door:GetForward() * side):Angle()

	client.efgKeyhole = {
		door = door,
		pos = pos,
		ends = CurTime() + ix.config.Get("efgDoorKeyholeTime", 8)
	}

	door.efgKeyholeBy = client
	setPortals(door, true)
	client:Freeze(true)

	net.Start("efgDoorKeyhole")
		net.WriteBool(true)
		net.WriteVector(pos)
		net.WriteAngle(ang)
	net.Send(client)
end

function PLUGIN:SetupPlayerVisibility(client)
	if (client.efgKeyhole) then
		AddOriginToPVS(client.efgKeyhole.pos)
	end
end

net.Receive("efgDoorKeyhole", function(_, client)
	DOORS.EndKeyhole(client)
end)

function PLUGIN:PlayerDeath(client)
	DOORS.EndKeyhole(client)
end

function PLUGIN:PlayerDisconnected(client)
	DOORS.EndKeyhole(client)
end

timer.Create("efgDoors.State", 0.25, 0, function()
	for i = #DOORS.list, 1, -1 do
		local door = DOORS.list[i]

		if (IsValid(door)) then
			updateState(door)
		else
			table.remove(DOORS.list, i)
		end
	end

	for _, client in ipairs(player.GetAll()) do
		local data = client.efgKeyhole

		if (data and (!client:Alive() or !IsValid(data.door) or data.ends < CurTime() or isOpen(data.door)
			or client:GetPos():Distance(data.door:GetPos()) > DOORS.range * 2)) then
			DOORS.EndKeyhole(client)
		end
	end
end)

-- ─── Acciones ────────────────────────────────────────────────────────────────
local function openAway(door, client)
	if (door:GetClass() == "prop_door_rotating") then
		door:Fire("OpenAwayFrom", "!activator", 0, client, client)
	else
		door:Fire("Open", "", 0, client, client)
	end
end

local function finishFast(door)
	timer.Create("efgDoors.Speed." .. door:EntIndex(), 1.5, 1, function()
		if (IsValid(door) and door:GetClass() == "prop_door_rotating") then
			door:Fire("SetSpeed", tostring(baseSpeed(door)))
		end
	end)
end

local function kickOpen(door, client, peek)
	if (door:GetClass() == "prop_door_rotating") then
		door:Fire("SetSpeed", tostring(baseSpeed(door) * ix.config.Get("efgDoorKickSpeed", 4)))
		door.efgDoorDirty = true

		if (peek) then
			door:Fire("MoveToRotationDistance", tostring(baseDistance(door)))
		else
			door:Fire("SetRotationDistance", tostring(baseDistance(door)))
			openAway(door, client)
		end

		finishFast(door)
	else
		openAway(door, client)
	end

	door.efgDoorPeek = nil
end

local handlers = {}

function handlers.open(client, door, state, locked)
	if (locked) then
		door:EmitSound(SOUND_LOCKED)
		notice(client, "efgDoorLocked", true)
		return
	end

	if (state == DOORS.STATE_PEEK) then
		door:Fire("SetSpeed", tostring(baseSpeed(door)))
		door:Fire("MoveToRotationDistance", tostring(baseDistance(door)))
		door.efgDoorPeek = nil
		return
	end

	if (door.efgDoorDirty) then
		restore(door)
	end

	openAway(door, client)
end

function handlers.close(client, door)
	door:Fire("Close", "", 0, client, client)
end

function handlers.peek(client, door, state, locked)
	if (locked) then return end

	if (door:GetClass() == "prop_door_rotating") then
		local angle = ix.config.Get("efgDoorPeekAngle", 22)

		door:Fire("SetSpeed", tostring(math.max(angle, 15)))
		door:Fire("SetRotationDistance", tostring(angle))
		door.efgDoorPeek = true
		door.efgDoorDirty = true
	end

	openAway(door, client)
end

function handlers.kick(client, door, state, locked)
	if ((door.efgDoorKickNext or 0) > CurTime()) then
		notice(client, "efgDoorTooFast")
		return
	end

	door.efgDoorKickNext = CurTime() + 0.9
	client:ViewPunch(Angle(-3, math.Rand(-1, 1), 0))

	if (locked) then
		if ((door.efgDoorKickReset or 0) < CurTime()) then
			door.efgDoorKicks = 0
		end

		door.efgDoorKicks = (door.efgDoorKicks or 0) + 1
		door.efgDoorKickReset = CurTime() + 30

		if (door.efgDoorKicks < ix.config.Get("efgDoorKickHits", 3)) then
			door:EmitSound(SOUND_KICK, 80, math.random(90, 105))
			util.ScreenShake(door:WorldSpaceCenter(), 2, 10, 0.3, 200)
			notice(client, "efgDoorKickHit")
			return
		end

		door.efgDoorKicks = 0
		door:Fire("Unlock")
		door:EmitSound(SOUND_BREACH, 85)
		notice(client, "efgDoorBreached")
	else
		door:EmitSound(SOUND_KICK, 80, math.random(100, 115))
	end

	-- el Unlock se procesa antes que la apertura (misma cola de entradas)
	kickOpen(door, client, state == DOORS.STATE_PEEK)
end

function handlers.keyhole(client, door)
	startKeyhole(client, door)
end

function handlers.lock(client, door)
	if (hook.Run("CanPlayerToggleEFGDoorLock", client, door) == false) then return end

	door:Fire("Lock")
	door:EmitSound(SOUND_LATCH)
	notice(client, "efgDoorLockedNow")
end

function handlers.unlock(client, door)
	if (hook.Run("CanPlayerToggleEFGDoorLock", client, door) == false) then return end

	door:Fire("Unlock")
	door:EmitSound(SOUND_LATCH)
	notice(client, "efgDoorUnlockedNow")
end

net.Receive("efgDoorAction", function(_, client)
	local door = net.ReadEntity()
	local action = net.ReadString()

	if (!ix.config.Get("efgDoors", true) or !IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end
	if (client.efgKeyhole or client:IsRestricted()) then return end
	if ((client.efgDoorNext or 0) > CurTime()) then return end
	if (!DOORS.IsManaged(door) or !handlers[action]) then return end

	client.efgDoorNext = CurTime() + 0.3

	local shootPos = client:GetShootPos()
	if (shootPos:Distance(door:NearestPoint(shootPos)) > DOORS.range + 16) then return end

	if (hook.Run("CanPlayerUseDoor", client, door) == false) then return end

	updateState(door)

	if (!table.HasValue(DOORS.GetActions(door), action)) then return end

	local state, locked = DOORS.GetState(door)
	handlers[action](client, door, state, locked)

	hook.Run("EFGDoorAction", client, door, action)
end)

-- El uso normal (E) lo sustituye la lista del cursor; los NPC siguen igual.
function PLUGIN:PlayerUse(client, entity)
	if (ix.config.Get("efgDoors", true) and DOORS.IsManaged(entity)) then
		return false
	end
end

-- ─── Cerradura a tiros ───────────────────────────────────────────────────────
function PLUGIN:EntityTakeDamage(target, damage)
	if (target:GetClass() != "prop_door_rotating" or !damage:IsBulletDamage()) then return end
	if (!DOORS.IsManaged(target) or target:GetInternalVariable("m_bLocked") != true) then return end

	local health = ix.config.Get("efgDoorLockHealth", 60)
	if (health <= 0) then return end

	local hit = target:WorldToLocal(damage:GetDamagePosition())
	local lockY, lockZ = handleY(target), target:OBBCenter().z - 10

	if (math.Distance(hit.y, hit.z, lockY, lockZ) > 6) then return end

	target.efgDoorLockHP = (target.efgDoorLockHP or health) - damage:GetDamage()

	if (target.efgDoorLockHP <= 0) then
		target.efgDoorLockHP = nil
		target:Fire("Unlock")
		target:EmitSound(SOUND_LOCKSHOT, 80)

		local attacker = damage:GetAttacker()

		if (IsValid(attacker) and attacker:IsPlayer()) then
			notice(attacker, "efgDoorLockShot")
		end
	end
end
