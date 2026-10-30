-- Datos y acciones de la pestaña TAREAS. Las misiones siguen siendo las del
-- plugin missions (las crean los admins con /MisionAdmin); aquí solo se
-- listan todas a la vez y se aceptan o entregan sin ir hasta el comerciante,
-- como en el menú de EFT.

local PLUGIN = PLUGIN

util.AddNetworkString("ixEFGTasksRequest")
util.AddNetworkString("ixEFGTasksData")
util.AddNetworkString("ixEFGTasksAction")

local function findTrader(persistKey, factions)
	local byFaction

	for _, entity in ipairs(ents.FindByClass("ix_trader")) do
		if (persistKey and persistKey != "" and entity:GetPersistKey() == persistKey) then
			return entity
		end

		if (!byFaction and factions and table.HasValue(factions, entity.factionKey or "prapor")) then
			byFaction = entity
		end
	end

	return byFaction
end
PLUGIN.FindTrader = findTrader

local function traderOf(mission)
	if (mission.traderKey and mission.traderKey != "") then
		local entity = findTrader(mission.traderKey)
		return entity and (entity.factionKey or "prapor") or (mission.factions and mission.factions[1]) or "prapor"
	end

	return mission.factions and mission.factions[1] or "prapor"
end

local function rewardOptions(mission)
	if (istable(mission.rewardOptions) and #mission.rewardOptions > 0) then return mission.rewardOptions end
	if (istable(mission.rewards)) then return {mission.rewards} end
	return {}
end

function PLUGIN:BuildTaskList(client)
	local character = client:GetCharacter()
	local active = character:GetMissionActive()
	local record = character:GetMissionRecord() or {}
	local tasks = {}

	for id, mission in pairs(ix.missions.list or {}) do
		if (!mission.steps or #mission.steps == 0) then continue end

		local isActive = active and active.missionId == id

		-- las diarias solo cuentan si son la elegida hoy por su comerciante
		if (mission.isDaily and !isActive and mission.traderKey and mission.traderKey != ""
			and ix.missions.GetDailyMission(mission.traderKey) != id) then
			continue
		end

		local status, reason

		if (isActive) then
			status = active.readyToComplete and "ready" or "active"
		elseif (mission.repeatMode == "once" and record[id]) then
			status = "done"
		elseif (ix.missions.IsOnCooldown(character, mission)) then
			status = "cooldown"
			reason = ("Disponible de nuevo en %d min."):format(math.ceil(((mission.cooldown or 0) - (os.time() - record[id])) / 60))
		else
			local ok, why = ix.missions.CanAccept(character, mission)
			status = ok and "available" or "locked"
			reason = why

			-- tener otra tarea en curso no la bloquea: solo hay que acabar la otra
			if (!ok and active and active.missionId and why and why:find("misión activa", 1, true)) then
				status = "available"
			end
		end

		local steps = {}
		for i, step in ipairs(mission.steps) do
			local progress = (isActive and i == active.stepIndex) and active.progress or {}
			steps[i] = {
				text = step.description and step.description != "" and step.description or ix.missions.GetStepObjective(step, progress),
				objective = ix.missions.GetStepObjective(step, progress),
				percent = ix.missions.GetStepPercent(step, progress),
				done = isActive and (i < active.stepIndex or active.readyToComplete) or status == "done",
				current = isActive and i == active.stepIndex and !active.readyToComplete,
				deliver = step.type == "deliver"
			}
		end

		tasks[#tasks + 1] = {
			id = id,
			name = mission.name or id,
			description = mission.description or "",
			trader = isActive and active.traderFaction or traderOf(mission),
			status = status,
			reason = reason,
			daily = mission.isDaily == true,
			repeatMode = mission.repeatMode or "once",
			steps = steps,
			rewards = rewardOptions(mission),
			completedAt = record[id]
		}
	end

	table.sort(tasks, function(a, b)
		if (a.trader != b.trader) then return a.trader < b.trader end
		return tostring(a.name) < tostring(b.name)
	end)

	return tasks
end

function PLUGIN:SendTasks(client)
	local character = client:GetCharacter()
	if (!character or !ix.missions) then return end

	local traders = {}
	for _, key in ipairs(ix.traders and ix.traders.factions or {}) do
		local rep = ix.traders.GetEffectiveRep(character, key)
		local ll = 1

		for i, entry in ipairs(ix.traders.repLevels) do
			if (rep >= entry.min) then ll = i end
		end

		traders[#traders + 1] = {key = key, rep = rep, ll = ll}
	end

	local tasks = self:BuildTaskList(client)

	net.Start("ixEFGTasksData")
		net.WriteTable(traders)
		net.WriteTable(tasks)
	net.Send(client)
end

net.Receive("ixEFGTasksRequest", function(_, client)
	if ((client.efgNextTasks or 0) > CurTime()) then return end
	client.efgNextTasks = CurTime() + 0.3

	PLUGIN:SendTasks(client)
end)

-- Aceptar, entregar objetos, cobrar o abandonar desde el TAB. Igual que el
-- comercio desde el menú (efg_pmc): el comerciante cuenta como alcanzable
-- durante un rato y fuera de raid. Las comprobaciones son las de missions.
net.Receive("ixEFGTasksAction", function(_, client)
	if ((client.efgNextTaskAction or 0) > CurTime()) then return end
	client.efgNextTaskAction = CurTime() + 0.5

	local character = client:GetCharacter()
	if (!character or !ix.missions or !ix.missions.HandleAccept) then return end

	local action = net.ReadString()
	local missionId = net.ReadString()

	if (client.InRaid and client:InRaid()) then
		client:Notify("No puedes gestionar tareas durante una raid.")
		return
	end

	if (action == "abandon") then
		ix.command.Run(client, "abandonarMision", {})
	else
		local entity

		if (action == "accept") then
			local mission = ix.missions.list[missionId]
			if (!mission) then return end

			entity = findTrader(mission.traderKey, mission.factions)
		else
			local active = character:GetMissionActive()
			if (!active or !active.missionId) then return end

			entity = findTrader(active.traderKey, {active.traderFaction})
		end

		if (!IsValid(entity)) then
			client:Notify("Ese comerciante no está en este mapa.")
			return
		end

		client.efgLobbyTrader = entity
		client.efgLobbyTraderUntil = CurTime() + 900

		if (action == "accept") then
			ix.missions.HandleAccept(client, entity, missionId)
		elseif (action == "deliver") then
			ix.missions.HandleDeliver(client, entity)
		elseif (action == "turnin") then
			ix.missions.HandleTurnIn(client, entity)
		end
	end

	timer.Simple(0.3, function()
		if (IsValid(client)) then PLUGIN:SendTasks(client) end
	end)
end)
