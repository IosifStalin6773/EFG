-- ============================================================
--  missions  |  sv_plugin.lua  (SERVER)
--  Persistencia de definiciones, ciclo de vida de misiones,
--  spawn por proximidad, tracking de progreso y comandos.
-- ============================================================

-- ── Net strings ─────────────────────────────────────────────────────────────────
util.AddNetworkString("missions_AdminData")     -- sv→cl: lista completa para el panel
util.AddNetworkString("missions_AdminRequest")  -- cl→sv: abrir panel admin
util.AddNetworkString("missions_AdminSave")     -- cl→sv: crear/actualizar una misión
util.AddNetworkString("missions_AdminDelete")   -- cl→sv: eliminar misión
util.AddNetworkString("missions_SetActiveStep") -- cl→sv: marcar paso activo para captura
util.AddNetworkString("missions_OfferList")     -- sv→cl: misiones ofertables por el trader
util.AddNetworkString("missions_RequestList")   -- cl→sv: pedir misiones a un trader
util.AddNetworkString("missions_Accept")        -- cl→sv: aceptar una misión
util.AddNetworkString("missions_Deliver")       -- cl→sv: entregar objetos de misión (paso deliver)
util.AddNetworkString("missions_TurnIn")        -- cl→sv: entregar misión completada al trader
util.AddNetworkString("missions_OpenAdmin")     -- sv→cl: forzar apertura del panel admin
util.AddNetworkString("missions_ShowRewards")   -- sv→cl: mostrar opciones de recompensa al completar
util.AddNetworkString("missions_RewardChoice")  -- cl→sv: jugador elige opción de recompensa
util.AddNetworkString("missions_TraderList")    -- sv→cl: lista de traders para el selector del panel admin

-- Estado en memoria
ix.missions.list    = ix.missions.list or {}   -- [id] = definición
ix.missions.nextId  = ix.missions.nextId or 1
ix.missions.editing = ix.missions.editing or {} -- [client] = {missionId, stepIndex}
ix.missions.spawned = ix.missions.spawned or {} -- [charID] = { entities = {...} }

-- ── Helpers de posición (almacenadas como {x,y,z} para JSON/persistencia) ─────────
local function PosToTable(vec)
	return {x = vec.x, y = vec.y, z = vec.z}
end

local function TableToPos(t)
	if (!t) then return nil end
	return Vector(t.x or 0, t.y or 0, t.z or 0)
end

-- ============================================================
--  Persistencia
-- ============================================================

function PLUGIN:LoadData()
	local data = self:GetData() or {}
	ix.missions.list       = data.missions   or {}
	ix.missions.nextId     = data.nextId     or 1
	ix.missions.dailyState = data.dailyState or {}
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	ix.data.SetSafe(self.uniqueID, {
		missions   = ix.missions.list,
		nextId     = ix.missions.nextId,
		dailyState = ix.missions.dailyState or {},
	})
end

-- Re-elige la misión diaria de cada trader en cada arranque del servidor,
-- sin importar cuánto tiempo lleve activa la anterior.
function PLUGIN:PostLoadData()
	local pools = {}
	for id, mission in pairs(ix.missions.list) do
		if (mission.isDaily and mission.traderKey and mission.traderKey != "") then
			pools[mission.traderKey] = pools[mission.traderKey] or {}
			table.insert(pools[mission.traderKey], id)
		end
	end

	ix.missions.dailyState = ix.missions.dailyState or {}
	for traderKey, pool in pairs(pools) do
		ix.missions.dailyState[traderKey] = {missionId = pool[math.random(#pool)], at = os.time()}
	end

	-- Limpiar estados de traders que ya no tienen pool de misiones diarias
	for traderKey in pairs(table.Copy(ix.missions.dailyState)) do
		if (!pools[traderKey]) then ix.missions.dailyState[traderKey] = nil end
	end

	self:SaveData()
end

-- Persiste las definiciones desde contextos sin `self` (receptores/comandos)
local function saveMissions()
	local plugin = ix.plugin.Get("missions")
	if (plugin) then plugin:SaveData() end
end

-- ============================================================
--  Helpers de definición
-- ============================================================

function ix.missions.Get(id)
	return ix.missions.list[id]
end

-- Devuelve el id de la misión diaria activa de este trader, rotando a una
-- nueva si han pasado 24h desde la última selección (o si la anterior ya no
-- es válida). nil si el trader no tiene misiones marcadas como diarias.
function ix.missions.GetDailyMission(traderKey)
	if (!traderKey or traderKey == "") then return nil end

	local pool = {}
	for id, mission in pairs(ix.missions.list) do
		if (mission.isDaily and mission.traderKey == traderKey) then
			table.insert(pool, id)
		end
	end

	ix.missions.dailyState = ix.missions.dailyState or {}
	if (#pool == 0) then
		ix.missions.dailyState[traderKey] = nil
		return nil
	end

	local state = ix.missions.dailyState[traderKey]
	local needsRoll = (!state) or (!table.HasValue(pool, state.missionId)) or (os.time() - (state.at or 0) >= 86400)
	if (needsRoll) then
		ix.missions.dailyState[traderKey] = {missionId = pool[math.random(#pool)], at = os.time()}
		saveMissions()
	end

	return ix.missions.dailyState[traderKey].missionId
end

-- Devuelve la misión activa, su paso y su progreso (o nil)
function ix.missions.GetActive(character)
	if (!character) then return nil end
	local active = character:GetMissionActive()
	if (!active or !active.missionId) then return nil end

	local mission = ix.missions.list[active.missionId]
	if (!mission) then return nil end

	local step = mission.steps and mission.steps[active.stepIndex]
	return active, mission, step
end

-- ¿Puede el personaje aceptar esta misión? → bool, motivo
function ix.missions.CanAccept(character, mission)
	if (!character or !mission) then return false, "Misión no válida." end
	if (!mission.steps or #mission.steps == 0) then return false, "Esta misión no está terminada." end

	local active = character:GetMissionActive()
	if (active and active.missionId) then
		return false, "Ya tienes una misión activa. Termínala o abandónala primero."
	end

	local record = character:GetMissionRecord() or {}

	-- Verificar prerrequisitos
	if (mission.requires and #mission.requires > 0) then
		for _, reqId in ipairs(mission.requires) do
			if (!record[reqId]) then
				local reqMission = ix.missions.list[reqId]
				local reqName    = reqMission and reqMission.name or reqId
				return false, "Requiere completar primero: " .. tostring(reqName)
			end
		end
	end

	local last = record[mission.id]

	if (mission.repeatMode == "once" and last) then
		return false, "Ya has completado esta misión."
	elseif (mission.repeatMode == "cooldown" and last) then
		local remaining = (mission.cooldown or 0) - (os.time() - last)
		if (remaining > 0) then
			return false, "Debes esperar " .. math.ceil(remaining / 60) .. " min para repetirla."
		end
	end

	-- Restricción opcional de facción del jugador
	if (mission.allowedFactions and #mission.allowedFactions > 0) then
		local factionIndex = character:GetFaction()
		local factionData  = ix.faction.indices and ix.faction.indices[factionIndex]
		local playerFk     = factionData and factionData.uniqueID or ""
		if (!table.HasValue(mission.allowedFactions, playerFk)) then
			return false, "Tu facción no puede aceptar esta misión."
		end
	end

	return true
end

-- ¿Debe ocultarse esta misión del tablón del comerciante? Una misión "once"
-- ya completada se oculta para siempre; una "cooldown" se oculta hasta que
-- expire la espera, momento en el que vuelve a aparecer en la lista.
function ix.missions.IsOnCooldown(character, mission)
	if (!character or !mission) then return false end

	local record = character:GetMissionRecord() or {}
	local last = record[mission.id]
	if (!last) then return false end

	if (mission.repeatMode == "once") then
		return true
	elseif (mission.repeatMode == "cooldown") then
		return ((mission.cooldown or 0) - (os.time() - last)) > 0
	end

	return false
end

-- ============================================================
--  Spawn por proximidad y limpieza
-- ============================================================

-- Encuentra un punto en el suelo cerca de una posición base
local function findScatterPos(basePos, radius)
	local offset = Vector(math.Rand(-radius, radius), math.Rand(-radius, radius), 16)
	local target = basePos + offset
	local tr = util.TraceLine({
		start  = target + Vector(0, 0, 64),
		endpos = target - Vector(0, 0, 256),
		mask   = MASK_SOLID_BRUSHONLY,
	})
	return tr.Hit and (tr.HitPos + Vector(0, 0, 8)) or (basePos + Vector(0, 0, 8))
end

-- Registra una entidad como spawn de misión de un personaje
local function trackEntity(charID, ent)
	ix.missions.spawned[charID] = ix.missions.spawned[charID] or {entities = {}}
	table.insert(ix.missions.spawned[charID].entities, ent)
end

-- Elimina todos los spawns temporales de un personaje
function ix.missions.CleanupSpawns(charID)
	local data = ix.missions.spawned[charID]
	if (!data) then return end
	for _, ent in ipairs(data.entities) do
		if (IsValid(ent)) then ent:Remove() end
	end
	ix.missions.spawned[charID] = nil
end

-- Genera los NPCs/objetos pendientes del paso actual para un jugador
function ix.missions.SpawnStep(client, character, mission, step, stepIndex, progress)
	local charID  = character:GetID()
	local basePos = TableToPos(step.pos)
	if (!basePos) then return end

	if (step.type == "fetch") then
		local remaining = (step.count or 1) - (progress.collected or 0)
		for i = 1, remaining do
			local pos = findScatterPos(basePos, 80)
			ix.item.Spawn(step.itemID, pos, function(item, ent)
				if (item) then
					item:SetData("ixMission", {missionId = mission.id, stepIndex = stepIndex, owner = charID, state = "world"})
				end
				if (IsValid(ent)) then
					trackEntity(charID, ent)
					-- Solo el dueño de la misión puede ver e interactuar con el objeto
					for _, ply in ipairs(player.GetAll()) do
						if (IsValid(ply) and ply:GetCharacter() and ply:GetCharacter():GetID() != charID) then
							ent:SetPreventTransmit(ply, true)
						end
					end
				end
			end)
		end
	end
end

-- ============================================================
--  Ciclo de vida: aceptar, avanzar, completar
-- ============================================================

function ix.missions.Accept(client, character, mission, factionKey, traderKey, traderDisplayName)
	local stepSummaries = {}
	for i, step in ipairs(mission.steps or {}) do
		stepSummaries[i] = step.description or ix.missions.GetStepObjective(step, {})
	end

	character:SetMissionActive({
		missionId         = mission.id,
		missionName       = mission.name,
		traderFaction     = factionKey,
		traderKey         = traderKey,
		traderDisplayName = traderDisplayName,
		stepIndex         = 1,
		totalSteps        = #(mission.steps or {}),
		stepSummaries     = stepSummaries,
		progress          = {},
		readyToComplete   = false,
	})
	client:Notify("Misión aceptada: " .. mission.name)
end

-- Comprueba si el inventario tiene espacio para todos los ítems de una recompensa.
-- Simula la ocupación de slots secuencialmente para ser preciso con múltiples ítems.
local function canFitRewardItems(character, rewardOpt)
	local r = rewardOpt or {}
	if (!r.items or #r.items == 0) then return true end

	local inventory = character:GetInventory()
	if (!inventory) then return false end

	-- Copiar los slots ocupados para simular sin modificar el inventario real
	local occupied = {}
	local invW, invH = inventory:GetSize()
	for x = 1, invW do
		occupied[x] = {}
		for y = 1, invH do
			occupied[x][y] = (inventory.slots[x] and inventory.slots[x][y]) and true or false
		end
	end

	local function canFitAt(sx, sy, w, h)
		for x2 = 0, w - 1 do
			for y2 = 0, h - 1 do
				local cx, cy = sx + x2, sy + y2
				if (cx > invW or cy > invH) then return false end
				if (occupied[cx] and occupied[cx][cy]) then return false end
			end
		end
		return true
	end

	local function placeAt(sx, sy, w, h)
		for x2 = 0, w - 1 do
			for y2 = 0, h - 1 do
				occupied[sx + x2][sy + y2] = true
			end
		end
	end

	for _, entry in ipairs(r.items) do
		local itemData = ix.item.list[entry.id]
		if (!itemData) then continue end

		local iw, ih = itemData.width or 1, itemData.height or 1
		for q = 1, (entry.qty or 1) do
			local placed = false
			for y = 1, invH do
				for x = 1, invW do
					if (canFitAt(x, y, iw, ih)) then
						placeAt(x, y, iw, ih)
						placed = true
						break
					end
				end
				if (placed) then break end
			end
			if (!placed) then return false end
		end
	end

	return true
end

-- Entrega una opción de recompensa concreta
local function giveRewards(client, character, rewardOpt)
	local r = rewardOpt or {}

	if (r.balas and r.balas > 0) then
		-- Negociador: aumenta las balas obtenidas al completar misiones.
		local mult = hook.Run("AdjustMissionReward", client, character) or 1
		character:GiveMoney(math.Round(r.balas * mult))
	end

	-- experiencia de PMC (EFG): como en EFT, las misiones dan XP según la recompensa
	local raids = ix.plugin.Get("efg_raids")

	if (raids and raids.GiveXP) then
		local xp = math.floor((r.balas or 0) / 20) + (r.rep or 0) * 20

		if (xp > 0) then
			raids:GiveXP(character, xp)
			client:Notify(("+%d XP"):format(xp))
		end
	end

	if (r.rep and r.rep > 0) then
		local fk = (character:GetMissionActive() or {}).traderFaction
		if (fk and character.GetTraderRep) then
			local traderRep = character:GetTraderRep() or {}
			traderRep[fk] = math.Clamp((traderRep[fk] or 0) + r.rep, 0, 1000)
			character:SetTraderRep(traderRep)
		end
	end

	if (r.items) then
		local inventory = character:GetInventory()
		for _, entry in ipairs(r.items) do
			if (ix.item.list[entry.id]) then
				for i = 1, (entry.qty or 1) do
					inventory:Add(entry.id)
				end
			end
		end
	end
end

-- Devuelve las opciones de recompensa de una misión (soporta formato antiguo y nuevo)
local function getRewardOptions(mission)
	if (istable(mission.rewardOptions) and #mission.rewardOptions > 0) then
		return mission.rewardOptions
	end
	if (istable(mission.rewards)) then
		return {mission.rewards}
	end
	return {}
end

-- Completa la misión: recompensas, registro y limpieza
function ix.missions.Complete(client, character, mission, chosenReward)
	local options = getRewardOptions(mission)
	local reward  = chosenReward or options[1] or {}
	giveRewards(client, character, reward)

	local record = character:GetMissionRecord() or {}
	record[mission.id] = os.time()
	character:SetMissionRecord(record)

	ix.missions.CleanupSpawns(character:GetID())
	character:SetMissionActive(nil)

	-- Negociador / Veterano / Mula de carga: XP por completar la misión.
	hook.Run("OnMissionCompleted", client, character, mission)

	client:Notify("¡Misión completada: " .. mission.name .. "!")
end

-- Avanza al siguiente paso o completa la misión
function ix.missions.AdvanceStep(client, character)
	local active, mission, step = ix.missions.GetActive(character)
	if (!active) then return end

	ix.missions.CleanupSpawns(character:GetID())

	active.stepIndex = active.stepIndex + 1
	active.progress  = {}

	if (active.stepIndex > #mission.steps) then
		-- Todos los pasos completados — el jugador debe volver al trader para entregar
		active.readyToComplete = true
		character:SetMissionActive(active)
		local traderName = active.traderDisplayName or (ix.traders and ix.traders.names and ix.traders.names[active.traderFaction]) or active.traderFaction
		client:Notify("¡Objetivos completados! Vuelve con " .. traderName .. " para entregar la misión y cobrar tu recompensa.")
		return
	end

	character:SetMissionActive(active)
	client:Notify("Objetivo completado. Siguiente: " .. ix.missions.GetStepObjective(mission.steps[active.stepIndex], {}))
end

-- ============================================================
--  Timer global: spawn por proximidad + detección de exploración
-- ============================================================

timer.Create("missions_Proximity", 1, 0, function()
	local completeR = ix.config.Get("missions_completeRadius", 128)
	local spawnR    = ix.config.Get("missions_spawnRadius", 1500)

	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client) or !client:GetCharacter()) then continue end

		local character = client:GetCharacter()
		local active, mission, step = ix.missions.GetActive(character)
		if (!active or !step) then continue end

		local stepPos = TableToPos(step.pos)
		if (!stepPos) then continue end

		local dist = client:GetPos():Distance(stepPos)

		if (step.type == "explore") then
			local radius = step.radius or completeR
			if (dist <= radius) then
				ix.missions.AdvanceStep(client, character)
			end
		elseif (step.type == "fetch") then
			if (!active.progress.spawned and dist <= spawnR) then
				ix.missions.SpawnStep(client, character, mission, step, active.stepIndex, active.progress)
				active.progress.spawned = true
				character:SetMissionActive(active)
			end
		end
	end
end)

-- ============================================================
--  Hooks de detección de progreso
-- ============================================================

-- Eliminación: contar muertes de NPCs del tipo indicado por el jugador con misión activa
function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
	if (!IsValid(npc) or !IsValid(attacker) or !attacker:IsPlayer()) then return end
	if (!attacker:GetCharacter()) then return end

	local character = attacker:GetCharacter()
	local active, mission, step = ix.missions.GetActive(character)
	if (!active or !step or step.type != "kill") then return end
	if (!step.npcClass or npc:GetClass() != step.npcClass) then return end

	active.progress.killed = (active.progress.killed or 0) + 1
	character:SetMissionActive(active)

	if (active.progress.killed >= (step.count or 1)) then
		ix.missions.AdvanceStep(attacker, character)
	end
end

-- Búsqueda: contar objetos de misión recogidos
function PLUGIN:InventoryItemAdded(oldInv, targetInv, item)
	if (!item or !item.GetData) then return end
	local tag = item:GetData("ixMission")
	-- Solo contar recogidas del mundo; state="held" significa que ya está en inventario
	if (!tag or tag.state != "world") then return end

	local client = targetInv:GetOwner()
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local character = client:GetCharacter()
	if (character:GetID() != tag.owner) then return end

	local active, mission, step = ix.missions.GetActive(character)
	if (!active or !step or step.type != "fetch") then return end
	if (active.missionId != tag.missionId or active.stepIndex != tag.stepIndex) then return end

	-- Marcar como "held" para detectar pérdida por muerte (previene doble-cuenta al soltar/recoger)
	item:SetData("ixMission", {missionId = tag.missionId, stepIndex = tag.stepIndex, owner = tag.owner, state = "held"})

	active.progress.collected = (active.progress.collected or 0) + 1
	character:SetMissionActive(active)

	if (active.progress.collected >= (step.count or 1)) then
		-- Limpiar tags de los objetos ya recogidos antes de avanzar
		local inventory = character:GetInventory()
		for _, it in pairs(inventory:GetItems()) do
			local t = it:GetData("ixMission")
			if (t and t.state == "held" and t.owner == character:GetID()) then
				it:SetData("ixMission", nil)
			end
		end
		ix.missions.AdvanceStep(client, character)
	end
end

-- Ocultar objetos de misión de jugadores que cargan personaje durante una sesión activa
function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()
	if (!IsValid(client)) then return end
	local charID = character:GetID()

	for ownerCharID, data in pairs(ix.missions.spawned) do
		if (ownerCharID != charID and data.entities) then
			for _, ent in ipairs(data.entities) do
				if (IsValid(ent)) then
					ent:SetPreventTransmit(client, true)
				end
			end
		end
	end
end

-- Muerte durante un paso de búsqueda: perder objetos recogidos y la misión
function PLUGIN:PlayerDeath(client, inflictor, attacker)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local character = client:GetCharacter()
	local active, mission, step = ix.missions.GetActive(character)
	if (!active or !step or step.type != "fetch") then return end

	-- Eliminar objetos de misión que el jugador llevaba encima
	local inventory = character:GetInventory()
	local charID    = character:GetID()
	for itemID, it in pairs(inventory:GetItems()) do
		local t = it:GetData("ixMission")
		if (t and t.state == "held" and t.owner == charID) then
			inventory:Remove(itemID)
		end
	end

	ix.missions.CleanupSpawns(charID)
	character:SetMissionActive(nil)

	timer.Simple(1, function()
		if (IsValid(client)) then
			client:Notify("Has muerto. Los objetos de misión se han perdido y la misión ha sido abandonada.")
		end
	end)
end

-- Limpieza de spawns temporales al desconectar (conservando el progreso)
function PLUGIN:PlayerDisconnected(client)
	ix.missions.editing[client] = nil

	local character = client:GetCharacter()
	if (!character) then return end

	-- Si tenía un paso de spawn en curso, lo marcamos para regenerar al reconectar
	local active = character:GetMissionActive()
	if (active and active.progress and active.progress.spawned) then
		active.progress.spawned = false
		character:SetMissionActive(active)
	end

	ix.missions.CleanupSpawns(character:GetID())
end

-- ============================================================
--  Receptores de red — Panel de administración
-- ============================================================

local function sendAdminData(client)
	net.Start("missions_AdminData")
		net.WriteTable(ix.missions.list)
		net.WriteTable(ix.missions.dailyState or {})
	net.Send(client)

	-- Enviar lista de todos los traders para el selector del panel admin
	local traderList = {}
	if (ix.traders and ix.traders.data) then
		for key, data in pairs(ix.traders.data) do
			local name = data.traderCustomName
				or (ix.traders.names and ix.traders.names[data.factionKey or "prapor"])
				or "Comerciante"
			table.insert(traderList, {key = key, name = name, factionKey = data.factionKey or "prapor"})
		end
		table.sort(traderList, function(a, b) return a.name < b.name end)
	end
	net.Start("missions_TraderList")
		net.WriteTable(traderList)
	net.Send(client)
end

net.Receive("missions_AdminRequest", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	sendAdminData(client)
end)

net.Receive("missions_AdminSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local mission = net.ReadTable()
	if (!istable(mission)) then return end

	-- Asignar id si es nueva
	if (!mission.id or mission.id == "") then
		mission.id = "m" .. ix.missions.nextId
		ix.missions.nextId = ix.missions.nextId + 1
	end

	-- Saneado básico
	mission.name        = tostring(mission.name or "Misión sin nombre")
	mission.description = tostring(mission.description or "")
	mission.factions    = istable(mission.factions) and mission.factions or {}
	mission.traderKey      = tostring(mission.traderKey      or "")
	mission.traderName     = tostring(mission.traderName     or "")
	mission.adminName      = tostring(mission.adminName      or "")
	mission.allowedFactions = istable(mission.allowedFactions) and mission.allowedFactions or {}
	mission.repeatMode  = mission.repeatMode or "once"
	mission.cooldown    = math.max(0, tonumber(mission.cooldown) or 0)
	mission.isDaily     = (mission.isDaily == true) and mission.traderKey != ""

	-- Normalizar rewardOptions; migrar formato antiguo (mission.rewards) si necesario
	if (istable(mission.rewardOptions) and #mission.rewardOptions > 0) then
		for i, opt in ipairs(mission.rewardOptions) do
			mission.rewardOptions[i] = {
				balas = math.max(0, tonumber(opt.balas) or 0),
				rep   = math.max(0, tonumber(opt.rep)   or 0),
				items = istable(opt.items) and opt.items or {},
			}
		end
	elseif (istable(mission.rewards)) then
		mission.rewardOptions = {{
			balas = math.max(0, tonumber(mission.rewards.balas) or 0),
			rep   = math.max(0, tonumber(mission.rewards.rep)   or 0),
			items = istable(mission.rewards.items) and mission.rewards.items or {},
		}}
	else
		mission.rewardOptions = {{balas = 0, rep = 0, items = {}}}
	end
	mission.rewards = nil

	mission.steps    = istable(mission.steps)    and mission.steps    or {}
	mission.requires = istable(mission.requires) and mission.requires or {}

	ix.missions.list[mission.id] = mission
	saveMissions()
	sendAdminData(client)
end)

net.Receive("missions_AdminDelete", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	local id = net.ReadString()
	if (ix.missions.list[id]) then
		ix.missions.list[id] = nil
		saveMissions()
	end
	sendAdminData(client)
end)

net.Receive("missions_SetActiveStep", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	local missionId = net.ReadString()
	local stepIndex = net.ReadUInt(8)

	if (!ix.missions.list[missionId]) then
		client:ChatPrint("[Misiones] Guarda la misión antes de capturar datos del mundo.")
		return
	end

	ix.missions.editing[client] = {missionId = missionId, stepIndex = stepIndex}
	local step = ix.missions.list[missionId].steps[stepIndex]
	local typeName = step and (ix.missions.GetStepType(step.type) or {}).name or "?"
	client:ChatPrint("[Misiones] Paso activo: #" .. stepIndex .. " (" .. typeName .. "). Usa el comando correspondiente.")
end)

-- ============================================================
--  Receptores de red — Jugador
-- ============================================================

net.Receive("missions_RequestList", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character  = client:GetCharacter()
	local factionKey = traderEnt.factionKey or "prapor"
	local myKey      = traderEnt:GetPersistKey()
	local dailyId    = ix.missions.GetDailyMission(myKey)

	local offers = {}
	for id, mission in pairs(ix.missions.list) do
		-- Una misión con traderKey sólo la ofrece ese trader concreto.
		-- Sin traderKey se usa la lista de facciones como fallback (compatibilidad).
		-- Las misiones diarias sólo se ofrecen si son la elegida para este trader.
		local offered = false
		if (mission.traderKey and mission.traderKey != "") then
			if (mission.isDaily) then
				offered = (id == dailyId)
			else
				offered = (mission.traderKey == myKey)
			end
		else
			offered = (mission.factions and table.HasValue(mission.factions, factionKey))
		end

		if (offered and ix.missions.IsOnCooldown(character, mission)) then
			offered = false
		end

		if (offered) then
			local canAccept = ix.missions.CanAccept(character, mission)
			if (canAccept) then
				offers[#offers + 1] = {
					id            = id,
					name          = mission.name,
					description   = mission.description,
					rewardOptions = getRewardOptions(mission),
					repeatMode    = mission.repeatMode,
					isDaily       = (mission.isDaily == true),
					stepCount     = #(mission.steps or {}),
				}
			end
		end
	end

	-- Misiones comunitarias (si el plugin está cargado)
	local communityOffers = {}
	if (ix.communityMissions and ix.communityMissions.GetOfferForPlayer) then
		local cmOffer = ix.communityMissions.GetOfferForPlayer(character)
		if (cmOffer) then
			communityOffers[#communityOffers + 1] = cmOffer
		end
	end

	net.Start("missions_OfferList")
		net.WriteEntity(traderEnt)
		net.WriteTable(offers)
		net.WriteTable(communityOffers)
	net.Send(client)
end)

net.Receive("missions_Accept", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	local missionId = net.ReadString()
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character = client:GetCharacter()
	local mission   = ix.missions.list[missionId]
	if (!mission) then return end

	-- Verificar que el trader oferta esta misión (misma lógica que RequestList)
	local factionKey = traderEnt.factionKey or "prapor"
	local myKey      = traderEnt:GetPersistKey()
	local offered    = false
	if (mission.traderKey and mission.traderKey != "") then
		if (mission.isDaily) then
			offered = (missionId == ix.missions.GetDailyMission(myKey))
		else
			offered = (mission.traderKey == myKey)
		end
	else
		offered = (mission.factions and table.HasValue(mission.factions, factionKey))
	end
	if (!offered) then return end

	local canAccept, reason = ix.missions.CanAccept(character, mission)
	if (!canAccept) then
		client:Notify(reason)
		return
	end

	local traderKey          = traderEnt:GetPersistKey()
	local traderDisplayName  = traderEnt:GetNetVar("traderName", (ix.traders and ix.traders.names and ix.traders.names[factionKey]) or "Comerciante")
	ix.missions.Accept(client, character, mission, factionKey, traderKey, traderDisplayName)
end)

net.Receive("missions_Deliver", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character = client:GetCharacter()
	local active, mission, step = ix.missions.GetActive(character)
	if (!active or !step or step.type != "deliver") then
		client:Notify("No tienes nada que entregar aquí.")
		return
	end

	-- La entrega debe ser al trader específico que dio la misión
	local myKey = traderEnt:GetPersistKey()
	if (active.traderKey and active.traderKey != myKey) then
		local tName = active.traderDisplayName or (ix.traders and ix.traders.names and ix.traders.names[active.traderFaction]) or active.traderFaction
		client:Notify("Debes entregar esto a " .. tName .. ".")
		return
	elseif (not active.traderKey and active.traderFaction != (traderEnt.factionKey or "prapor")) then
		client:Notify("Debes entregar esta misión a su comerciante de origen.")
		return
	end

	local inventory = character:GetInventory()
	local owned = {}
	local total = 0
	for _, it in pairs(inventory:GetItems()) do
		if (it.uniqueID == step.itemID) then
			owned[#owned + 1] = it
			total = total + (it:GetData("Amount") or it:GetData("count") or 1)
		end
	end

	local need = step.count or 1
	if (total < need) then
		client:Notify("Te faltan objetos para completar la entrega (" .. total .. "/" .. need .. ").")
		return
	end

	local remaining = need
	for _, it in pairs(owned) do
		if (remaining <= 0) then break end

		local amount = it:GetData("Amount") or it:GetData("count") or 1
		if (amount <= remaining) then
			remaining = remaining - amount
			inventory:Remove(it:GetID())
		else
			local field = (it:GetData("Amount") and "Amount") or "count"
			it:SetData(field, amount - remaining)
			remaining = 0
		end
	end

	ix.missions.AdvanceStep(client, character)
end)

-- Entregar misión completada al trader (todos los pasos ya hechos)
net.Receive("missions_TurnIn", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character = client:GetCharacter()
	local active    = character:GetMissionActive()

	if (!active or !active.readyToComplete) then
		client:Notify("No tienes ninguna misión lista para entregar.")
		return
	end

	local myKey = traderEnt:GetPersistKey()
	if (active.traderKey and active.traderKey != myKey) then
		local tName = active.traderDisplayName or (ix.traders and ix.traders.names and ix.traders.names[active.traderFaction]) or active.traderFaction
		client:Notify("Esta misión debe entregarse a " .. tName .. ".")
		return
	elseif (not active.traderKey and active.traderFaction != (traderEnt.factionKey or "prapor")) then
		local factionName = (ix.traders and ix.traders.names and ix.traders.names[active.traderFaction]) or active.traderFaction
		client:Notify("Esta misión debe entregarse al comerciante de " .. factionName .. ".")
		return
	end

	local mission = ix.missions.list[active.missionId]
	if (!mission) then
		character:SetMissionActive(nil)
		client:Notify("La misión ya no existe.")
		return
	end

	local options = getRewardOptions(mission)
	if (#options <= 1) then
		local reward = options[1] or {}
		if (!canFitRewardItems(character, reward)) then
			client:Notify("No tienes espacio en el inventario para la recompensa. Haz hueco e inténtalo de nuevo.")
			return
		end
		ix.missions.Complete(client, character, mission, reward)
	else
		net.Start("missions_ShowRewards")
			net.WriteEntity(traderEnt)
			net.WriteTable(options)
		net.Send(client)
	end
end)

net.Receive("missions_RewardChoice", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt   = net.ReadEntity()
	local choiceIndex = net.ReadUInt(8)
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character = client:GetCharacter()
	local active    = character:GetMissionActive()
	if (!active or !active.readyToComplete) then return end

	local myKey = traderEnt:GetPersistKey()
	if (active.traderKey and active.traderKey != myKey) then return end
	if (not active.traderKey and active.traderFaction != (traderEnt.factionKey or "prapor")) then return end

	local mission = ix.missions.list[active.missionId]
	if (!mission) then
		character:SetMissionActive(nil)
		return
	end

	local options = getRewardOptions(mission)
	local chosen  = options[math.Clamp(choiceIndex, 1, math.max(#options, 1))]
	if (!chosen) then return end

	if (!canFitRewardItems(character, chosen)) then
		client:Notify("No tienes espacio en el inventario para la recompensa. Haz hueco e inténtalo de nuevo.")
		return
	end

	ix.missions.Complete(client, character, mission, chosen)
end)

-- ============================================================
--  Comando de diagnóstico (temporal)
-- ============================================================

ix.command.Add("debugMision", {
	adminOnly   = true,
	description = "[DEBUG] Muestra el estado raw de la misión activa del personaje.",
	OnRun = function(self, client)
		local character = client:GetCharacter()
		if (!character) then return "Sin personaje." end

		-- Leer el raw del var para ver qué hay exactamente en memoria
		local raw = character.vars and character.vars["missionActive"]
		client:ChatPrint("[DEBUG] Raw missionActive: " .. tostring(raw))

		local active = character:GetMissionActive()
		if (!active) then
			client:ChatPrint("[DEBUG] GetMissionActive() devuelve nil")
			return
		end

		client:ChatPrint("[DEBUG] missionId: "       .. tostring(active.missionId))
		client:ChatPrint("[DEBUG] missionName: "     .. tostring(active.missionName))
		client:ChatPrint("[DEBUG] traderFaction: "   .. tostring(active.traderFaction))
		client:ChatPrint("[DEBUG] stepIndex: "       .. tostring(active.stepIndex))
		client:ChatPrint("[DEBUG] readyToComplete: " .. tostring(active.readyToComplete))

		local mission = active.missionId and ix.missions.list[active.missionId]
		if (mission) then
			client:ChatPrint("[DEBUG] Misión encontrada en lista: " .. mission.name .. " (" .. #mission.steps .. " pasos)")
		else
			client:ChatPrint("[DEBUG] MISIÓN NO ENCONTRADA EN ix.missions.list — ¿guardaste la misión?")
		end
	end
})

-- ============================================================
--  Comandos de captura (admin) — escriben en el paso activo
-- ============================================================

-- Busca un ítem por nombre (búsqueda case-insensitive, partial match)
local function findItemByName(name)
	if (!name or name == "") then return nil end
	local search = name:lower()
	for id, data in pairs(ix.item.list) do
		if ((data.name or ""):lower():find(search, 1, true)) then
			return id, data
		end
	end
	return nil
end

-- Resuelve el paso activo en edición de un admin, validando tipo
local function getEditingStep(client, expectedType)
	local ed = ix.missions.editing[client]
	if (!ed) then
		client:ChatPrint("[Misiones] Selecciona primero un paso en el panel de misiones.")
		return nil
	end
	local mission = ix.missions.list[ed.missionId]
	if (!mission) then
		client:ChatPrint("[Misiones] La misión ya no existe.")
		return nil
	end
	local step = mission.steps[ed.stepIndex]
	if (!step) then
		client:ChatPrint("[Misiones] El paso seleccionado ya no existe.")
		return nil
	end
	if (step.type != expectedType) then
		local need = (ix.missions.GetStepType(expectedType) or {}).name or expectedType
		client:ChatPrint("[Misiones] El paso activo no es de tipo '" .. need .. "'.")
		return nil
	end
	return mission, step
end

ix.command.Add("setPuntoMision", {
	adminOnly   = true,
	arguments   = {bit.bor(ix.type.number, ix.type.optional)},
	description = "Fija el punto de un paso de exploración en tu posición actual.",
	OnRun = function(self, client, radius)
		local mission, step = getEditingStep(client, "explore")
		if (!step) then return end

		step.pos    = PosToTable(client:GetPos())
		step.radius = math.Clamp(math.floor(radius or ix.config.Get("missions_completeRadius", 128)), 16, 1024)
		saveMissions()
		sendAdminData(client)
		return "Punto de exploración fijado (radio " .. step.radius .. ")."
	end
})

ix.command.Add("setSpawnEnemy", {
	adminOnly   = true,
	arguments   = {ix.type.string, ix.type.number},
	description = "Define la clase de NPC y la cantidad a eliminar en un paso de eliminación.",
	OnRun = function(self, client, npcClass, count)
		local mission, step = getEditingStep(client, "kill")
		if (!step) then return end

		if (!list.Get("NPC")[npcClass] and !scripted_ents.GetStored(npcClass)) then
			return "Clase de NPC desconocida: " .. npcClass
		end

		step.npcClass = npcClass
		step.count    = math.Clamp(math.floor(count), 1, 50)
		saveMissions()
		sendAdminData(client)
		return "Paso de eliminación: " .. step.count .. "x " .. npcClass .. "."
	end
})

ix.command.Add("setSpawnObject", {
	adminOnly   = true,
	arguments   = {ix.type.string, bit.bor(ix.type.number, ix.type.optional)},
	description = "Define el objeto (por nombre) y cantidad a recoger de un paso de búsqueda (en tu mira).",
	OnRun = function(self, client, itemName, count)
		local mission, step = getEditingStep(client, "fetch")
		if (!step) then return end

		local itemID, itemData = findItemByName(itemName)
		if (!itemID) then return "Ítem no encontrado: " .. itemName end
		if (!itemData.noBusiness) then return "El objeto de misión debe ser noBusiness (no vendible)." end

		step.itemID = itemID
		step.count  = math.Clamp(math.floor(count or 1), 1, 50)
		step.pos    = PosToTable(client:GetEyeTraceNoCursor().HitPos)
		saveMissions()
		sendAdminData(client)
		return "Paso de búsqueda: " .. step.count .. "x " .. itemData.name .. " (" .. itemID .. ")."
	end
})

ix.command.Add("setQuestObject", {
	adminOnly   = true,
	arguments   = {ix.type.string, ix.type.number},
	description = "Define el objeto (por nombre) y cantidad a entregar al trader en un paso de entrega.",
	OnRun = function(self, client, itemName, count)
		local mission, step = getEditingStep(client, "deliver")
		if (!step) then return end

		local itemID, itemData = findItemByName(itemName)
		if (!itemID) then return "Ítem no encontrado: " .. itemName end
		if (itemData.noBusiness) then return "El objeto de entrega debe ser vendible, no valen objetos de misión." end

		step.itemID = itemID
		step.count  = math.Clamp(math.floor(count), 1, 50)
		saveMissions()
		sendAdminData(client)
		return "Paso de entrega: " .. step.count .. "x " .. itemData.name .. " (" .. itemID .. ")."
	end
})

ix.command.Add("MisionAdmin", {
	adminOnly   = true,
	description = "Abre el panel de administración de misiones.",
	OnRun = function(self, client)
		net.Start("missions_OpenAdmin")
		net.Send(client)
	end
})

-- ============================================================
--  Comando de estado (todos los jugadores)
-- ============================================================

ix.command.Add("estadoMision", {
	description = "Muestra el estado de tu misión activa.",
	OnRun = function(self, client)
		local character = client:GetCharacter()
		if (!character) then return end

		local active, mission, step = ix.missions.GetActive(character)
		if (!active) then
			return "No tienes ninguna misión activa."
		end

		client:ChatPrint("=== Misión: " .. mission.name .. " ===")

		if (active.readyToComplete) then
			local traderName = active.traderDisplayName or (ix.traders and ix.traders.names and ix.traders.names[active.traderFaction]) or active.traderFaction
			client:ChatPrint("¡LISTA PARA ENTREGAR! Habla con " .. traderName .. ".")
			client:ChatPrint("Progreso total: 100%")
			return
		end

		local total    = #mission.steps
		local stepNum  = active.stepIndex
		local objective = ix.missions.GetStepObjective(step, active.progress)
		local stepPct  = ix.missions.GetStepPercent(step, active.progress)
		local totalPct = math.floor(((stepNum - 1) / math.max(total, 1)) * 100)

		client:ChatPrint("Objetivo (" .. stepNum .. "/" .. total .. "): " .. objective)
		client:ChatPrint("Progreso del paso: " .. stepPct .. "%  |  Progreso total: " .. totalPct .. "%")
	end
})

ix.command.Add("abandonarMision", {
	description = "Abandona tu misión activa (se pierde el progreso).",
	OnRun = function(self, client)
		local character = client:GetCharacter()
		if (!character) then return end

		local active = character:GetMissionActive()
		if (!active or !active.missionId) then
			return "No tienes ninguna misión activa."
		end

		local missionName = active.missionName or active.missionId
		ix.missions.CleanupSpawns(character:GetID())
		character:SetMissionActive(nil)
		client:Notify("Has abandonado la misión: " .. missionName .. ".")
	end
})
