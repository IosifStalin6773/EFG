-- ============================================================
--  npc_presets  |  sv_plugin.lua  (SERVER)
--  Persistencia de presets y puntos de spawn, timer de spawn
--  automático, comandos de admin.
-- ============================================================

local PLUGIN = PLUGIN

util.AddNetworkString("npcpresets_AdminOpen")
util.AddNetworkString("npcpresets_AdminData")
util.AddNetworkString("npcpresets_AdminRequest")
util.AddNetworkString("npcpresets_AdminSave")
util.AddNetworkString("npcpresets_AdminDelete")
util.AddNetworkString("npcpresets_SpawnOpen")
util.AddNetworkString("npcpresets_SpawnConfirm")
util.AddNetworkString("npcpresets_PointsData")
util.AddNetworkString("npcpresets_HordeOpen")
util.AddNetworkString("npcpresets_HordeActivate")
util.AddNetworkString("npcpresets_PlayAlarm")
util.AddNetworkString("npcpresets_AlarmOpen")
util.AddNetworkString("npcpresets_AlarmConfirm")
util.AddNetworkString("npcpresets_HordeTargetOpen")
util.AddNetworkString("npcpresets_HordeTargetConfirm")

util.PrecacheSound("ambient/alarms/warningbell1.wav")
util.PrecacheSound("ambient/alarms/warningbell2.wav")

-- Estado en memoria
ix.npcpresets             = ix.npcpresets or {}
ix.npcpresets.presets     = ix.npcpresets.presets     or {}  -- [id] = preset
ix.npcpresets.points      = ix.npcpresets.points      or {}  -- lista de puntos de spawn
ix.npcpresets.alarmPoints = ix.npcpresets.alarmPoints or {}  -- lista de puntos de alarma

PLUGIN.spawnState          = PLUGIN.spawnState          or {}  -- [pointId] = {entities, lastDeath, currentWaypoint}
PLUGIN.pendingSpawn        = PLUGIN.pendingSpawn        or {}  -- [client]  = Vector capturada
PLUGIN.pendingAlarm        = PLUGIN.pendingAlarm        or {}  -- [client]  = Vector capturada (alarma)
PLUGIN.pendingHordeTarget  = PLUGIN.pendingHordeTarget  or {}  -- [client]  = Vector capturada (objetivo)
PLUGIN.pendingPatrolPoint  = PLUGIN.pendingPatrolPoint  or {}  -- [client]  = pointId seleccionado para waypoints
PLUGIN.showingPlayers      = PLUGIN.showingPlayers      or {}  -- [client]  = true si tiene /npcMostrar activo
PLUGIN.spawnReady         = false  -- true tras 5 min desde el arranque del servidor

timer.Simple(300, function()
	PLUGIN.spawnReady = true
end)

local PROXIMITY_RADIUS    = 800   -- radio de no-spawn: no spawnea si el jugador está más cerca que esto
local PROXIMITY_RADIUS_SQ = PROXIMITY_RADIUS * PROXIMITY_RADIUS
local DEFAULT_SPAWN_RADIUS = 2500  -- radio de presencia: NPCs solo existen mientras haya jugadores dentro
local SCATTER_RADIUS      = 100  -- radio de dispersión horizontal
local MAX_NPCS            = 100  -- límite global de NPCs vivos en el mapa
local NPC_FORCE_CLEANUP_TIME = 90  -- segundos fuera de rango tras los que se limpia un wave sí o sí
local MIN_NPC_SEP         = 40   -- separación mínima entre NPCs del mismo wave
local NPC_HULL_MINS       = Vector(-16, -16, 0)
local NPC_HULL_MAXS       = Vector(16, 16, 72)

-- ── Override de dificultad para los NPCs VJ Base (Metro 2033 Redux) ──
-- El addon original apunta casi sin fallar y pega muy fuerte para un
-- servidor de RP.
--
-- Puntería: usamos el propio control de VJ Base (ENT.Weapon_Accuracy) en vez
-- de interceptar FireBullets a mano: VJ Base ya calcula su propia dispersión
-- dinámica (distancia/movimiento/supresión) y multiplicarla desde fuera la
-- disparaba hasta el punto de que los NPCs no acertaban ningún disparo.
--
-- Daño: NO usamos vj_npc_difficulty (VJ.DIFFICULTY_x). Esa convar usa la
-- misma función (ENT:ScaleByDifficulty) tanto para el daño que hacen como
-- para su StartHealth, así que bajarla también les recorta la vida máxima
-- (mueren de 1 bala). En su lugar escalamos solo el daño que reciben los
-- jugadores de estos NPCs, sin tocar la vida del NPC.
local NPC_VJ_ACCURACY        = 1.5   -- ENT.Weapon_Accuracy de VJ Base: 1 = normal, >1 = peor puntería
local NPC_VJ_SNIPER_ACCURACY = 5.0   -- francotiradores: mucho peor puntería que el resto
local NPC_VJ_DAMAGE_SCALE    = 0.75  -- multiplicador de daño de NPCs VJ contra jugadores

-- Se detecta por ARMA, no por clase de NPC: el VSV (francotirador real) también
-- sale en el pool de armas aleatorias de soldados/pesados normales (ver
-- NPC_DEFAULT_WEAPONS más abajo), así que un "npc_vj_reich_soldier" al que le
-- toque VSV cuenta igual como francotirador.
local NPC_VJ_SNIPER_WEAPONS = {
	["weapon_vj_prevedredux"] = true,
	["weapon_vj_ventilredux"] = true,
	["weapon_vj_vsv"]         = true,
	["weapon_vj_vsv_att"]     = true,
}

-- Cono de dispersión de TODOS los NPC VJ Base (antes solo se aplicaba a los
-- francotiradores). Weapon_Accuracy es solo un multiplicador sobre la
-- dispersión dinámica que calcula VJ Base internamente, y sumarle un extra
-- por encima de esa base desconocida es impredecible (con +0.08 encima de lo
-- que ya ponía VJ Base, el cono final salía enorme: 0/15). En vez de sumar,
-- se REEMPLAZA el spread entero en EntityFireBullets (el hook nativo justo
-- antes del trazado del disparo), así el único número que decide la puntería
-- es este, sin depender de lo que VJ Base calculara por dentro — para TODOS
-- los NPC VJ, no solo francotiradores, así fallan más tiros de forma
-- consistente en vez de depender del multiplicador poco fiable.
-- Referencia: el SMG de NPCs de HL2 usa ~0.03-0.05; esto empieza bastante más
-- abierto para que fallen la mayoría de los tiros.
local NPC_VJ_SPREAD         = 0.025 -- soldados/pesados normales
local NPC_VJ_SNIPER_SPREAD  = 0.04  -- francotiradores: aún peor puntería que el resto

-- Cadencia de disparo. VJ Base sostiene el gatillo a la cadencia NATIVA del
-- arma (las SWEP de CW2 Redux llegan a ~600 RPM, pensadas para un jugador
-- reaccionando/cubriéndose), así que aunque fallen más tiros (ver spread de
-- arriba) seguían acribillando a la mayoría de jugadores sin darles opción.
-- Se limita la cadencia EFECTIVA devolviendo true en EntityFireBullets
-- (GMod suprime ese disparo en concreto, sin gastar munición) cuando no ha
-- pasado suficiente tiempo desde el último tiro de ese NPC. El sonido/fogonazo
-- del arma puede seguir su ritmo normal (los controla la SWEP, no este hook),
-- así que se oye disparar más de lo que realmente sale bala; es un precio
-- aceptable a cambio de que el jugador tenga margen real de reacción.
local NPC_VJ_SHOT_INTERVAL        = 0.9  -- soldados/pesados normales (~1 disparo real por segundo)
local NPC_VJ_SNIPER_SHOT_INTERVAL = 2.5  -- francotiradores: tiro aislado, con pausa larga entre disparos

local function ApplyVJAccuracy(ent)
	if (!IsValid(ent)) then return end

	local weapon = ent:GetActiveWeapon()
	local isSniper = IsValid(weapon) and NPC_VJ_SNIPER_WEAPONS[weapon:GetClass()] or false

	ent.Weapon_Accuracy = isSniper and NPC_VJ_SNIPER_ACCURACY or NPC_VJ_ACCURACY
	ent.ixVJSniper = isSniper
end

-- DEBUG TEMPORAL: activar con "vj_firerate_debug 1" en consola para confirmar
-- que EntityFireBullets realmente intercepta el disparo de estos NPCs (si no
-- se ve nada en consola al disparar un NPC VJ, el addon no dispara por esta
-- vía y hay que buscar otro punto de intercepción). Quitar tras confirmar.
concommand.Add("vj_firerate_debug", function() ix.vjFirerateDebug = !ix.vjFirerateDebug end)

hook.Add("EntityFireBullets", "npcpresets_vj_spread", function(ent, bulletData)
	if (!IsValid(ent) or !string.StartWith(ent:GetClass(), "npc_vj_")) then return end

	local interval = ent.ixVJSniper and NPC_VJ_SNIPER_SHOT_INTERVAL or NPC_VJ_SHOT_INTERVAL
	local suppressed = CurTime() < (ent.ixVJNextShot or 0)

	if (ix.vjFirerateDebug) then
		print(("[DBG vj firerate] %s (%s) suppressed=%s interval=%.2f"):format(
			tostring(ent), ent:GetClass(), tostring(suppressed), interval))
	end

	if (suppressed) then
		return true
	end
	ent.ixVJNextShot = CurTime() + interval

	local spread = ent.ixVJSniper and NPC_VJ_SNIPER_SPREAD or NPC_VJ_SPREAD
	bulletData.Spread = Vector(spread, spread, 0)
end)

-- Sin granadas y sin chatter/voces (deja gruñidos de dolor/muerte: eso no es
-- "hablar"). CanRangeAttack2 NO es el flag real de granada en esta versión de
-- VJ Base (comprobado en el código fuente del addon, entities/npc_vj_human_base/
-- init.lua): el ataque de granada se decide con "self.HasGrenadeAttack"
-- (ai/core.lua, "if selfData.HasGrenadeAttack and ..."), que la mayoría de
-- clases del pack Metro 2033 Redux traen en true de fábrica
-- (npc_vj_reich_soldier, npc_vj_ganza_officer, etc.). Se desactiva aquí. Los
-- Enable*Sounds cubren las distintas categorías de voz que usa VJ Base —
-- poner una que este NPC en concreto no tenga no hace nada, así que no hay
-- riesgo en desactivarlas todas de golpe.
hook.Add("OnEntityCreated", "npcpresets_vj_accuracy", function(ent)
	if (!IsValid(ent) or !string.StartWith(ent:GetClass(), "npc_vj_")) then return end

	ent.CanRangeAttack2 = false
	ent.HasGrenadeAttack = false

	ent.EnableIdleSounds      = false
	ent.EnableAlertSounds     = false
	ent.EnableEnemySounds     = false
	ent.EnableLostEnemySounds = false
	ent.EnableAnnoyedSounds   = false
	ent.EnableCombatSounds    = false

	-- El arma (additionalequipment) no siempre está lista en el mismo tick que
	-- el spawn: se reintenta varias veces hasta detectarla y fijar la puntería.
	timer.Simple(0,   function() ApplyVJAccuracy(ent) end)
	timer.Simple(0.5, function() ApplyVJAccuracy(ent) end)
	timer.Simple(1.5, function() ApplyVJAccuracy(ent) end)
end)

-- ── Override de vida para NPCs concretos (Metro 2033 Redux) ──
local NPC_HEALTH_OVERRIDES = {
	["npc_bibliotekar_redux"]       = 2250,
	["npc_bibliotekar_black_redux"] = 3000,
}

hook.Add("OnEntityCreated", "npcpresets_health_override", function(ent)
	timer.Simple(0, function()
		if (!IsValid(ent)) then return end

		local health = NPC_HEALTH_OVERRIDES[ent:GetClass()]
		if (health) then
			ent:SetMaxHealth(health)
			ent:SetHealth(health)
		end
	end)
end)

function PLUGIN:EntityTakeDamage(target, dmgInfo)
	if (!IsValid(target) or !target:IsPlayer()) then return end

	local attacker = dmgInfo:GetAttacker()
	if (IsValid(attacker) and string.StartWith(attacker:GetClass(), "npc_vj_")) then
		dmgInfo:ScaleDamage(NPC_VJ_DAMAGE_SCALE)
	end
end

-- Armas aleatorias por clase de NPC (se usa cuando el preset no especifica arma)
local NPC_DEFAULT_WEAPONS = {
	["npc_vj_reich_soldier"]  = {
		"weapon_vj_aks74uredux_att", "weapon_vj_aks74uredux", "weapon_vj_saigaredux_att",
		"weapon_vj_saigaredux", "weapon_vj_ak74redux", "weapon_vj_ubludokredux",
		"weapon_vj_uboynikredux", "weapon_vj_ak74redux_att", "weapon_vj_ak74redux_att2",
		"weapon_vj_ubludokredux_att", "weapon_vj_uboynikredux_att", "weapon_vj_vsv",
		"weapon_vj_vsv_att", "weapon_vj_uboynikredux_att2", "weapon_vj_dupletredux",
		"weapon_vj_dupletredux_att",
	},
	["npc_vj_reich_sniper"]   = { "weapon_vj_prevedredux", "weapon_vj_ventilredux" },
	["npc_vj_reich_soldier2"] = {
		"weapon_vj_aks74uredux_att", "weapon_vj_aks74uredux", "weapon_vj_saigaredux_att",
		"weapon_vj_saigaredux", "weapon_vj_ak74redux", "weapon_vj_ubludokredux",
		"weapon_vj_uboynikredux", "weapon_vj_ak74redux_att", "weapon_vj_ak74redux_att2",
		"weapon_vj_ubludokredux_att", "weapon_vj_uboynikredux_att", "weapon_vj_vsv",
		"weapon_vj_vsv_att", "weapon_vj_uboynikredux_att2", "weapon_vj_dupletredux",
		"weapon_vj_dupletredux_att",
	},
	["npc_vj_reich_soldier3"] = {
		"weapon_vj_aks74uredux_att", "weapon_vj_aks74uredux", "weapon_vj_saigaredux_att",
		"weapon_vj_saigaredux", "weapon_vj_ak74redux", "weapon_vj_ubludokredux",
		"weapon_vj_uboynikredux", "weapon_vj_ak74redux_att", "weapon_vj_ak74redux_att2",
		"weapon_vj_ubludokredux_att", "weapon_vj_uboynikredux_att", "weapon_vj_vsv",
		"weapon_vj_vsv_att", "weapon_vj_uboynikredux_att2", "weapon_vj_dupletredux",
		"weapon_vj_dupletredux_att",
	},
	["npc_vj_reich_officer"]  = { "weapon_vj_ak74redux" },
	["npc_vj_reich_heavy"]    = {
		"weapon_vj_rpkredux_att", "weapon_vj_rpkredux", "weapon_vj_aks74uredux_att",
		"weapon_vj_saigaredux_att", "weapon_vj_saigaredux", "weapon_vj_abzacredux",
		"weapon_vj_ak74redux", "weapon_vj_uboynikredux", "weapon_vj_ak74redux_att",
		"weapon_vj_ak74redux_att2", "weapon_vj_ubludokredux_att", "weapon_vj_uboynikredux_att",
		"weapon_vj_vsv", "weapon_vj_vsv_att", "weapon_vj_uboynikredux_att2",
		"weapon_vj_dupletredux", "weapon_vj_dupletredux_att",
	},
	["npc_vj_reich_heavy2"]   = { "weapon_vj_gatlingredux" },
	["npc_vj_bandos1"] = {"weapon_vj_ashotredux_att","weapon_vj_ak74redux","weapon_vj_ubludokredux","weapon_vj_dupletredux","weapon_vj_dupletredux","weapon_vj_aks74uredux"},	
	["npc_vj_bandos2"] = {"weapon_vj_ashotredux_att","weapon_vj_ak74redux","weapon_vj_ubludokredux","weapon_vj_dupletredux","weapon_vj_dupletredux","weapon_vj_aks74uredux"},	
	["npc_vj_bandos3"] = {"weapon_vj_ashotredux_att","weapon_vj_ak74redux","weapon_vj_ubludokredux","weapon_vj_dupletredux","weapon_vj_dupletredux","weapon_vj_aks74uredux"}
}

-- ── Helpers ──────────────────────────────────────────────────

local function PosToTable(vec)
	return { x = vec.x, y = vec.y, z = vec.z }
end

local function TableToPos(t)
	if (!t) then return nil end
	return Vector(t.x or 0, t.y or 0, t.z or 0)
end

local function generateId(prefix)
	return prefix .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Algunos addons registran "variantes" de NPC en el spawnmenu (ej. DeformedNosach,
-- AggressiveNosach) cuya entidad real es otra clase con KeyValues extra
-- (ej. Class = "npc_nosach_samec", KeyValues = {NosachType = 4}).
-- Esto resuelve esos alias a la clase real y sus KeyValues.
local function resolveNPCClass(class)
	local listEntry = list.Get("NPC")[class]
	if (listEntry and listEntry.Class) then
		return listEntry.Class, listEntry.KeyValues
	end
	return class, nil
end

local function savePlugin()
	local plugin = ix.plugin.Get("npc_presets")
	if (plugin) then plugin:SaveData() end
end

local function pushPointsUpdate()
	if (!next(PLUGIN.showingPlayers)) then return end

	local pointsWithPreset = {}
	for _, point in ipairs(ix.npcpresets.points) do
		local preset = ix.npcpresets.presets[point.presetId]
		table.insert(pointsWithPreset, {
			id          = point.id,
			pos         = point.pos,
			presetName  = preset and preset.name or "?",
			isHorde     = preset and preset.isHorde == true or false,
			isPatrol    = preset and preset.isPatrol == true or false,
			radius      = preset and (preset.radius or 800) or 800,
			spawnRadius = preset and (preset.spawnRadius or 2500) or 2500,
		})
	end

	local alarmPointsData = {}
	for _, ap in ipairs(ix.npcpresets.alarmPoints) do
		local preset = ix.npcpresets.presets[ap.presetId]
		table.insert(alarmPointsData, {
			pos        = ap.pos,
			presetName = preset and preset.name or "?",
		})
	end

	local hordeTargetsData = {}
	for _, ht in ipairs(ix.npcpresets.hordeTargets) do
		local preset = ix.npcpresets.presets[ht.presetId]
		table.insert(hordeTargetsData, {
			pos        = ht.pos,
			presetName = preset and preset.name or "?",
		})
	end

	local patrolWPData = {}
	for pointId, waypoints in pairs(ix.npcpresets.patrolWaypoints) do
		local presetName = "?"
		for _, pt in ipairs(ix.npcpresets.points) do
			if (pt.id == pointId) then
				local preset = ix.npcpresets.presets[pt.presetId]
				presetName = preset and preset.name or "?"
				break
			end
		end
		for idx, wp in ipairs(waypoints) do
			table.insert(patrolWPData, {
				pos        = wp.pos,
				presetName = presetName,
				index      = idx,
				total      = #waypoints,
				pointId    = pointId,
			})
		end
	end

	local payload = {
		points         = pointsWithPreset,
		alarmPoints    = alarmPointsData,
		hordeTargets   = hordeTargetsData,
		patrolWaypoints = patrolWPData,
		isUpdate       = true,
	}

	for ply, _ in pairs(PLUGIN.showingPlayers) do
		if (IsValid(ply)) then
			net.Start("npcpresets_PointsData")
				ix.npcpresets.WriteCompressed(payload)
			net.Send(ply)
		else
			PLUGIN.showingPlayers[ply] = nil
		end
	end
end
PLUGIN.pushPointsUpdate = pushPointsUpdate  -- accesible desde sh_commands (OnRun es server-only)

local function sendAdminData(client)
	net.Start("npcpresets_AdminData")
		ix.npcpresets.WriteCompressed(ix.npcpresets.presets)
	net.Send(client)
end

-- ── Persistencia ─────────────────────────────────────────────

function PLUGIN:LoadData()
	local data = self:GetData() or {}
	ix.npcpresets.presets         = data.presets         or {}
	ix.npcpresets.points          = data.points          or {}
	ix.npcpresets.alarmPoints     = data.alarmPoints     or {}
	ix.npcpresets.hordeTargets    = data.hordeTargets    or {}
	ix.npcpresets.patrolWaypoints = data.patrolWaypoints or {}

	-- Migration: waypoints were keyed by presetId (prefix "p_"), now by pointId (prefix "sp_")
	local needsMigration = false
	for key, _ in pairs(ix.npcpresets.patrolWaypoints) do
		if (string.sub(key, 1, 3) != "sp_") then
			needsMigration = true
			break
		end
	end

	if (needsMigration) then
		local newWaypoints = {}
		for key, wps in pairs(ix.npcpresets.patrolWaypoints) do
			if (string.sub(key, 1, 3) != "sp_") then
				for _, point in ipairs(ix.npcpresets.points) do
					if (point.presetId == key and !newWaypoints[point.id]) then
						newWaypoints[point.id] = table.Copy(wps)
					end
				end
			else
				newWaypoints[key] = wps
			end
		end
		ix.npcpresets.patrolWaypoints = newWaypoints
		self:SaveData()
	end
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData({
		presets         = ix.npcpresets.presets,
		points          = ix.npcpresets.points,
		alarmPoints     = ix.npcpresets.alarmPoints,
		hordeTargets    = ix.npcpresets.hordeTargets,
		patrolWaypoints = ix.npcpresets.patrolWaypoints,
	})
end

-- ── Conteo global de NPCs vivos del plugin ───────────────────

local function getTotalAliveNPCs()
	local count = 0
	for _, state in pairs(PLUGIN.spawnState) do
		if (state.entities) then
			for _, ent in ipairs(state.entities) do
				if (IsValid(ent)) then count = count + 1 end
			end
		end
	end
	return count
end

-- ── Buscar posición válida de spawn (sin clipping, con separación) ──

local function findValidSpawnPos(basePos, radius, usedPositions)
	for _ = 1, 15 do
		local candidate = basePos + Vector(
			math.Rand(-radius, radius),
			math.Rand(-radius, radius),
			0
		)

		-- Encontrar el suelo real bajo el candidato
		local groundTr = util.TraceLine({
			start  = candidate + Vector(0, 0, 80),
			endpos = candidate + Vector(0, 0, -80),
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (!groundTr.HitWorld) then continue end

		local groundPos = groundTr.HitPos + Vector(0, 0, 2)

		-- Comprobar separación mínima respecto a posiciones ya usadas en este wave
		local tooClose = false
		local minSepSq = MIN_NPC_SEP * MIN_NPC_SEP
		for _, used in ipairs(usedPositions) do
			if (groundPos:DistToSqr(used) < minSepSq) then
				tooClose = true; break
			end
		end
		if (tooClose) then continue end

		-- Comprobar que el hueco está libre de geometría
		local clearTr = util.TraceHull({
			start  = groundPos,
			endpos = groundPos,
			mins   = NPC_HULL_MINS,
			maxs   = NPC_HULL_MAXS,
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (!clearTr.Hit) then
			return groundPos
		end
	end
	return nil
end

-- ── Helper: spawnear un preset en un punto concreto (secuencial) ──

local SPAWN_INTERVAL = 0.4  -- segundos entre cada NPC
local MAX_POS_RETRIES = 3   -- intentos de posición antes de saltar un NPC

local function spawnNPCsAtPoint(point, preset)
	local spawnPos = TableToPos(point.pos)
	if (!spawnPos) then return end

	-- Construir cola plana de tareas: un entry por NPC individual
	local queue = {}
	for _, npcInfo in ipairs(preset.npcs or {}) do
		local class = npcInfo.class or ""
		if (class == "") then continue end
		for i = 1, math.max(1, npcInfo.count or 1) do
			table.insert(queue, npcInfo)
		end
	end
	if (#queue == 0) then return end

	-- Inicializar estado con lista vacía; se irá llenando conforme spawneen
	timer.Remove("npcpresets_cleanup_" .. point.id)
	local entities = {}
	PLUGIN.spawnState[point.id] = { entities = entities }

	local usedPositions = {}
	local queueIdx = 1
	local retries  = 0

	local function trySpawnNext()
		-- Si el estado fue reseteado externamente (eliminar punto, nuevo wave), parar
		local currentState = PLUGIN.spawnState[point.id]
		if (!currentState or currentState.entities != entities) then return end
		if (queueIdx > #queue) then return end

		local npcInfo = queue[queueIdx]
		local pos     = findValidSpawnPos(spawnPos, SCATTER_RADIUS, usedPositions)

		if (pos) then
			retries = 0
			table.insert(usedPositions, pos)

			local npcClass, npcKeyValues = resolveNPCClass(npcInfo.class)

			local ent = ents.Create(npcClass)
			if (IsValid(ent)) then
				if (npcKeyValues) then
					for key, val in pairs(npcKeyValues) do
						ent:SetKeyValue(key, tostring(val))
					end
				end

				local weapon = (npcInfo.weapon and npcInfo.weapon != "") and npcInfo.weapon or nil
				if (!weapon) then
					local defaults = NPC_DEFAULT_WEAPONS[npcClass]
					if (defaults) then weapon = defaults[math.random(#defaults)] end
				end
				if (weapon) then ent:SetKeyValue("additionalequipment", weapon) end

				ent:SetPos(pos)
				ent:Spawn()
				local capturedEnt = ent
				timer.Simple(0, function()
					if (IsValid(capturedEnt)) then capturedEnt:Activate() end
				end)
				table.insert(entities, capturedEnt)
			end
			queueIdx = queueIdx + 1
		else
			retries = retries + 1
			if (retries >= MAX_POS_RETRIES) then
				-- Sin hueco tras varios intentos: saltar este NPC
				queueIdx = queueIdx + 1
				retries  = 0
			end
		end

		if (queueIdx <= #queue) then
			timer.Simple(SPAWN_INTERVAL, trySpawnNext)
		end
	end

	trySpawnNext()  -- primer NPC spawnea inmediatamente
end

-- ── Controlador de patrulla: mueve NPCs a través de waypoints ──

local PATROL_WAYPOINT_REACH_DIST_SQ = 200 * 200
local PATROL_STUCK_THRESHOLD = 50 * 50

local function startPatrolController(point, preset)
	local waypoints = ix.npcpresets.patrolWaypoints[point.id]
	if (!waypoints or #waypoints == 0) then return end

	local controllerName = "npcpresets_patrolai_" .. point.id
	local capturedPointId = point.id

	-- Per-NPC state to avoid spamming SCHED_FORCED_GO (which blocks enemy detection)
	local npcTracking = {}

	timer.Create(controllerName, 3, 0, function()
		local state = PLUGIN.spawnState[capturedPointId]
		if (!state or !state.entities) then timer.Remove(controllerName); return end

		local wps = ix.npcpresets.patrolWaypoints[capturedPointId]
		if (!wps or #wps == 0) then timer.Remove(controllerName); return end

		local targetIdx = state.currentWaypoint or 1
		if (targetIdx > #wps) then targetIdx = 1 end
		local targetPos = TableToPos(wps[targetIdx].pos)
		if (!targetPos) then return end

		local anyAlive = false
		local allReached = true

		for _, ent in ipairs(state.entities) do
			if (IsValid(ent) and ent:IsNPC()) then
				anyAlive = true
				local idx = ent:EntIndex()
				local track = npcTracking[idx]
				if (!track) then
					track = { ordered = false, hadEnemy = false, lastPos = ent:GetPos(), stuckTicks = 0 }
					npcTracking[idx] = track
				end

				local hasEnemy = IsValid(ent:GetEnemy())
				local justLeftCombat = track.hadEnemy and !hasEnemy

				if (ent:GetPos():DistToSqr(targetPos) > PATROL_WAYPOINT_REACH_DIST_SQ) then
					allReached = false

					if (!hasEnemy) then
						local movedSq = ent:GetPos():DistToSqr(track.lastPos)
						if (movedSq < PATROL_STUCK_THRESHOLD) then
							track.stuckTicks = track.stuckTicks + 1
						else
							track.stuckTicks = 0
						end

						local needsOrder = !track.ordered or justLeftCombat or track.stuckTicks >= 3
						if (needsOrder) then
							ent:SetLastPosition(targetPos)
							ent:SetSchedule(SCHED_FORCED_GO)
							track.ordered = true
							track.stuckTicks = 0
						end
					else
						track.stuckTicks = 0
					end
				end

				track.hadEnemy = hasEnemy
				track.lastPos = ent:GetPos()
			end
		end

		if (!anyAlive) then timer.Remove(controllerName); return end

		if (allReached) then
			local nextIdx = (targetIdx % #wps) + 1
			if (nextIdx == 1) then state.patrolLapDone = true end
			state.currentWaypoint = nextIdx
			for _, track in pairs(npcTracking) do
				track.ordered = false
			end
		end
	end)
end

-- ── Timer de spawn (tick cada 5 s) ────────────────────────────

timer.Create("npcpresets_Tick", 5, 0, function()
	-- No spawnear hasta que hayan pasado 5 min desde el arranque del servidor
	if (!PLUGIN.spawnReady) then return end

	-- Parar si ya se alcanzó el límite global
	if (getTotalAliveNPCs() >= MAX_NPCS) then return end

	for _, point in ipairs(ix.npcpresets.points) do
		-- Re-comprobar el límite dentro del bucle: cada punto puede añadir varios NPCs
		if (getTotalAliveNPCs() >= MAX_NPCS) then break end

		local preset = ix.npcpresets.presets[point.presetId]
		if (!preset) then continue end
		if (preset.isHorde) then continue end  -- las hordas solo se activan manualmente
		-- Las patrullas se gestionan abajo en el mismo tick, no se saltan

		local state    = PLUGIN.spawnState[point.id]
		local spawnPos = TableToPos(point.pos)
		if (!spawnPos) then continue end

		-- ── Radio externo (spawnRadius): los NPCs solo existen mientras haya un jugador aquí
		local outerRadius   = preset.spawnRadius or DEFAULT_SPAWN_RADIUS
		local outerRadiusSq = outerRadius * outerRadius

		-- Posiciones a comprobar: spawn point + waypoints de patrulla
		local checkPositions = { spawnPos }
		if (preset.isPatrol) then
			local wps = ix.npcpresets.patrolWaypoints[point.id]
			if (wps) then
				for _, wp in ipairs(wps) do
					local wpPos = TableToPos(wp.pos)
					if (wpPos) then table.insert(checkPositions, wpPos) end
				end
			end
		end

		local playerInRange = false
		for _, client in ipairs(player.GetAll()) do
			if (!IsValid(client)) then continue end
			local clientPos = client:GetPos()
			for _, checkPos in ipairs(checkPositions) do
				if (clientPos:DistToSqr(checkPos) < outerRadiusSq) then
					playerInRange = true
					break
				end
			end
			if (playerInRange) then break end
		end

		-- Sin jugadores en el radio externo: eliminar los NPCs que no estén en combate
		if (!playerInRange) then
			-- Cuánto tiempo lleva este wave sin jugadores en rango; pasado
			-- NPC_FORCE_CLEANUP_TIME se fuerza la limpieza total sin excepciones,
			-- para que una patrulla atascada o un NPC con GetEnemy() nunca
			-- limpiado no se queden vivos para siempre (contando contra MAX_NPCS)
			local forceCleanup = false
			if (state) then
				state.outOfRangeSince = state.outOfRangeSince or CurTime()
				forceCleanup = (CurTime() - state.outOfRangeSince) > NPC_FORCE_CLEANUP_TIME
			end

			-- Las patrullas no se limpian por ausencia de jugadores hasta completar
			-- al menos una vuelta entera a sus waypoints (si no, desaparecen a mitad de ruta)
			if (preset.isPatrol and state and !state.patrolLapDone and !forceCleanup) then continue end

			if (state and state.entities) then
				local remaining  = {}
				local removedAny = false

				for _, ent in ipairs(state.entities) do
					if (!IsValid(ent)) then continue end

					if (!forceCleanup and IsValid(ent:GetEnemy())) then
						-- Sigue enfrentando a un jugador fuera de rango: no lo eliminamos
						table.insert(remaining, ent)
					else
						ent:Remove()
						removedAny = true
					end
				end

				state.entities = remaining

				if (#remaining == 0 and removedAny) then
					-- No queda ningún NPC vivo del wave: liberar el punto sin cooldown
					-- (el despawn por ausencia de jugadores no cuenta como muerte)
					PLUGIN.spawnState[point.id] = nil
					timer.Remove("npcpresets_cleanup_" .. point.id)
					timer.Remove("npcpresets_patrolai_" .. point.id)
				end
			end
			continue
		end

		-- Hay un jugador en rango: resetear el contador de "fuera de rango"
		if (state) then state.outOfRangeSince = nil end

		-- Comprobar que todos los NPCs del último spawn han muerto
		if (state and state.entities) then
			local anyAlive = false
			for _, ent in ipairs(state.entities) do
				if (IsValid(ent)) then anyAlive = true; break end
			end
			if (anyAlive) then continue end

			-- Primera vez que detectamos que todos murieron: registrar momento y programar limpieza
			if (!state.lastDeath) then
				state.lastDeath = CurTime()

				-- Capturar ragdolls y armas caídas cerca del punto en este momento
				local cleanRadiusSq = 2000 * 2000
				local toClean = {}
				for _, ent in ents.Iterator() do
					if (!IsValid(ent)) then continue end
					local class = ent:GetClass()
					-- Solo limpiar armas CAÍDAS (sin dueño); nunca las que lleva un jugador o NPC vivo
					if (ent:IsWeapon() and IsValid(ent:GetOwner())) then continue end
					if (class == "prop_ragdoll" or ent:IsWeapon()) then
						if (ent:GetPos():DistToSqr(spawnPos) < cleanRadiusSq) then
							table.insert(toClean, ent)
						end
					end
				end

				if (#toClean > 0) then
					local timerName = "npcpresets_cleanup_" .. point.id
					timer.Create(timerName, 300, 1, function()
						for _, ent in ipairs(toClean) do
							if (IsValid(ent)) then ent:Remove() end
						end
					end)
				end
			end
		end

		-- Comprobar cooldown desde la muerte del último NPC
		local lastDeath = state and state.lastDeath or 0
		if (CurTime() - lastDeath < (preset.cooldown or 0)) then continue end

		-- ── Radio interno (radius): no spawnear si el jugador está demasiado cerca
		local proxRadius   = preset.radius or PROXIMITY_RADIUS
		local proxRadiusSq = proxRadius * proxRadius

		local tooClose = false
		for _, client in ipairs(player.GetAll()) do
			if (IsValid(client) and client:GetPos():DistToSqr(spawnPos) < proxRadiusSq) then
				tooClose = true
				break
			end
		end
		if (tooClose) then continue end

		-- Spawnear NPCs del preset
		spawnNPCsAtPoint(point, preset)

		-- Si es patrulla, iniciar controlador de IA tras un breve delay para que los NPCs terminen de spawnear
		if (preset.isPatrol) then
			local capturedPoint = point
			local capturedPreset = preset
			local totalNPCs = 0
			for _, npcInfo in ipairs(preset.npcs or {}) do
				totalNPCs = totalNPCs + math.max(1, npcInfo.count or 1)
			end
			local spawnDelay = math.max(1, totalNPCs * SPAWN_INTERVAL + 0.5)
			timer.Simple(spawnDelay, function()
				startPatrolController(capturedPoint, capturedPreset)
			end)
		end
	end
end)

-- ── Limpieza al desconectar ───────────────────────────────────

function PLUGIN:PlayerDisconnected(client)
	PLUGIN.pendingSpawn[client]       = nil
	PLUGIN.pendingAlarm[client]       = nil
	PLUGIN.pendingHordeTarget[client] = nil
	PLUGIN.pendingPatrolPoint[client] = nil
	PLUGIN.showingPlayers[client]     = nil
end

-- ── Receptores de red ─────────────────────────────────────────

net.Receive("npcpresets_AdminRequest", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	sendAdminData(client)
end)

net.Receive("npcpresets_AdminSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local preset = ix.npcpresets.ReadCompressed()
	if (!istable(preset)) then return end

	if (!preset.id or preset.id == "") then
		preset.id = generateId("p_")
	end

	preset.name        = tostring(preset.name or "Preset sin nombre")
	preset.cooldown    = math.max(0, math.floor(tonumber(preset.cooldown) or 0))
	preset.radius      = math.Clamp(math.floor(tonumber(preset.radius) or 800), 0, 5000)
	preset.spawnRadius = math.Clamp(math.floor(tonumber(preset.spawnRadius) or 2500), 0, 10000)
	preset.isHorde     = preset.isHorde == true
	preset.isPatrol    = preset.isPatrol == true
	if (preset.isHorde and preset.isPatrol) then preset.isPatrol = false end
	preset.npcs        = istable(preset.npcs) and preset.npcs or {}

	-- Sanear cada entrada de NPC
	for i, entry in ipairs(preset.npcs) do
		preset.npcs[i] = {
			class  = tostring(entry.class or ""),
			count  = math.Clamp(math.floor(tonumber(entry.count) or 1), 1, 50),
			weapon = tostring(entry.weapon or ""),  -- vacío = arma por defecto del NPC
		}
	end

	ix.npcpresets.presets[preset.id] = preset
	savePlugin()
	sendAdminData(client)
end)

net.Receive("npcpresets_AdminDelete", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local id = net.ReadString()
	if (!ix.npcpresets.presets[id]) then return end

	ix.npcpresets.presets[id] = nil

	-- Eliminar también todos los puntos que usaban este preset
	local remaining = {}
	for _, point in ipairs(ix.npcpresets.points) do
		if (point.presetId != id) then
			table.insert(remaining, point)
		else
			PLUGIN.spawnState[point.id] = nil
			timer.Remove("npcpresets_patrolai_" .. point.id)
			ix.npcpresets.patrolWaypoints[point.id] = nil
		end
	end
	ix.npcpresets.points = remaining

	savePlugin()
	sendAdminData(client)
	pushPointsUpdate()
end)

net.Receive("npcpresets_SpawnConfirm", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local presetId = net.ReadString()
	if (!ix.npcpresets.presets[presetId]) then
		client:Notify("[NPC Presets] Preset no encontrado.")
		return
	end

	local pos = PLUGIN.pendingSpawn[client]
	PLUGIN.pendingSpawn[client] = nil

	if (!pos) then
		client:Notify("[NPC Presets] La posición de spawn no está disponible. Usa /npcSpawn de nuevo.")
		return
	end

	local point = {
		id       = generateId("sp_"),
		presetId = presetId,
		pos      = PosToTable(pos),
	}

	table.insert(ix.npcpresets.points, point)
	savePlugin()
	pushPointsUpdate()

	local preset = ix.npcpresets.presets[presetId]
	client:Notify("[NPC Presets] Punto de spawn añadido para '" .. preset.name .. "'.")
end)

net.Receive("npcpresets_HordeActivate", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local presetId = net.ReadString()
	local preset   = ix.npcpresets.presets[presetId]
	if (!preset or !preset.isHorde) then return end

	-- Spawnear en todos los puntos que usen este preset
	local spawned = 0
	for _, point in ipairs(ix.npcpresets.points) do
		if (point.presetId == presetId) then
			spawnNPCsAtPoint(point, preset)
			spawned = spawned + 1
		end
	end

	-- Buscar objetivo de horda para este preset (uno por horda)
	local targetPos = nil
	for _, ht in ipairs(ix.npcpresets.hordeTargets) do
		if (ht.presetId == presetId) then
			targetPos = TableToPos(ht.pos)
			break
		end
	end

	-- Controlador de IA: redirigir NPCs sin enemigo hacia el objetivo cada 2s
	if (targetPos) then
		for _, point in ipairs(ix.npcpresets.points) do
			if (point.presetId != presetId) then continue end
			local controllerName = "npcpresets_hordeai_" .. point.id
			local capturedTarget = targetPos
			local capturedPointId = point.id
			timer.Create(controllerName, 2, 0, function()
				local state = PLUGIN.spawnState[capturedPointId]
				if (!state) then timer.Remove(controllerName); return end
				local anyAlive = false
				for _, ent in ipairs(state.entities or {}) do
					if (IsValid(ent)) then
						anyAlive = true
						if (ent:IsNPC() and !IsValid(ent:GetEnemy()) and ent:GetPos():DistToSqr(capturedTarget) > (300 * 300)) then
							ent:SetLastPosition(capturedTarget)
							ent:SetSchedule(SCHED_FORCED_GO_RUN)
						end
					end
				end
				if (!anyAlive) then timer.Remove(controllerName) end
			end)
		end
	end

	-- Enviar alarma por cada punto de alarma del preset; cada jugador recibe solo una vez
	local alarmRadiusSq = 1800 * 1800
	local sentTo = {}
	for _, ap in ipairs(ix.npcpresets.alarmPoints) do
		if (ap.presetId != presetId) then continue end
		local apPos = TableToPos(ap.pos)
		if (!apPos) then continue end

		local recipients = {}
		for _, ply in ipairs(player.GetAll()) do
			if (IsValid(ply) and !sentTo[ply] and ply:GetPos():DistToSqr(apPos) < alarmRadiusSq) then
				table.insert(recipients, ply)
				sentTo[ply] = true
			end
		end

		if (#recipients > 0) then
			net.Start("npcpresets_PlayAlarm")
				net.WriteBool(true)
				net.WriteVector(apPos)
			net.Send(recipients)
		end
	end

	client:Notify("[NPC Presets] Horda '" .. preset.name .. "' activada en " .. spawned .. " punto(s).")
end)

net.Receive("npcpresets_HordeTargetConfirm", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local presetId = net.ReadString()
	if (!ix.npcpresets.presets[presetId]) then return end

	local pos = PLUGIN.pendingHordeTarget[client]
	PLUGIN.pendingHordeTarget[client] = nil
	if (!pos) then
		client:Notify("[NPC Presets] Posición de objetivo no disponible. Usa /npcHordaObj de nuevo.")
		return
	end

	-- Un objetivo por horda: sobreescribir si ya existe
	for i, ht in ipairs(ix.npcpresets.hordeTargets) do
		if (ht.presetId == presetId) then
			table.remove(ix.npcpresets.hordeTargets, i)
			break
		end
	end

	table.insert(ix.npcpresets.hordeTargets, {
		presetId = presetId,
		pos      = PosToTable(pos),
	})
	savePlugin()

	local preset = ix.npcpresets.presets[presetId]
	client:Notify("[NPC Presets] Objetivo de horda asignado a '" .. preset.name .. "'.")
	pushPointsUpdate()
end)

net.Receive("npcpresets_AlarmConfirm", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local presetId = net.ReadString()
	if (!ix.npcpresets.presets[presetId]) then return end

	local pos = PLUGIN.pendingAlarm[client]
	PLUGIN.pendingAlarm[client] = nil
	if (!pos) then
		client:Notify("[NPC Presets] Posición de alarma no disponible. Usa /npcAlarma de nuevo.")
		return
	end

	table.insert(ix.npcpresets.alarmPoints, {
		presetId = presetId,
		pos      = PosToTable(pos),
	})
	savePlugin()

	local preset = ix.npcpresets.presets[presetId]
	client:Notify("[NPC Presets] Punto de alarma asignado a '" .. preset.name .. "'.")
	pushPointsUpdate()
end)

-- Comandos definidos en sh_commands.lua (compartido) para que
-- aparezcan en el autocompletado del chat del cliente.
