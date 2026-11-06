-- Progreso de las tareas diarias: eliminación, entrega FIR, supervivencia y
-- recompensas. Las tareas aceptadas viven en el estado del personaje
-- (tareasDiarias[traderKey].task) con status "active" y progress.

local PLUGIN = PLUGIN

local function mapMatches(mapID)
	local patterns = ix.tareasDiarias.mapPatterns[mapID]
	if (!patterns) then return false end

	for _, pattern in ipairs(patterns) do
		if (string.find(game.GetMap(), pattern, 1, true)) then return true end
	end

	return false
end

local function npcMatchesGroup(npc, group)
	if (group == "scav") then return npc.efgAIType == "scav" end
	if (group == "pmc") then return npc.efgAIType == "pmc" end
	if (group == "boss") then return npc.efgIsBoss == true end
	return false
end

-- Concede la recompensa de una tarea completada (misma forma que missions).
function ix.tareasDiarias.GiveReward(client, character, reward)
	reward = reward or {}

	if (reward.rublos and reward.rublos > 0) then
		character:GiveMoney(reward.rublos)
	end

	local raids = ix.plugin.Get("efg_raids")
	local xp = math.floor((reward.rublos or 0) / 20) + (reward.rep or 0) * 20

	if (raids and raids.GiveXP and xp > 0) then
		raids:GiveXP(character, xp, "task")
	end

	if (reward.rep and reward.rep > 0) then
		local traderRep = character:GetTraderRep() or {}

		-- la reputación va al comerciante de la tarea (reward.traderKey)
		if (reward.traderKey) then
			traderRep[reward.traderKey] = math.Clamp((traderRep[reward.traderKey] or 0) + reward.rep, 0, 1000)
			character:SetTraderRep(traderRep)
		end
	end
end

-- Aplica fn a cada tarea activa del personaje. fn devuelve true si cambió el progreso.
local function eachActive(client, fn)
	local character = client:GetCharacter()
	if (!character) then return end

	local state = character:GetTareasDiarias() or {}
	local changed = false

	for traderKey, entry in pairs(state) do
		local task = entry.task

		if (task and task.status == "active") then
			if (fn(task, traderKey)) then
				changed = true
				if (task.progress >= task.steps[1].count) then
					task.status = "done"
					task.reward = task.rewardOptions and task.rewardOptions[1] or {}
					task.reward.traderKey = traderKey
					ix.tareasDiarias.GiveReward(client, character, task.reward)
					client:Notify("Tarea diaria completada: " .. task.title)
				end
			end
		end
	end

	if (changed) then character:SetTareasDiarias(state) end
end

-- Eliminación: cuenta bajas de IA de la banda pedida en el mapa de la tarea.
function PLUGIN:OnNPCKilled(npc, attacker)
	if (!IsValid(attacker) or !attacker:IsPlayer() or !npc.efgZone) then return end

	eachActive(attacker, function(task)
		local step = task.steps[1]
		if (step.type != "kill") then return false end
		if (!npcMatchesGroup(npc, step.npcGroup) or !mapMatches(step.map)) then return false end

		task.progress = (task.progress or 0) + 1
		return true
	end)
end

-- Supervivencia: cada extracción sin Run Through ni muerte suma; morir o MIA la reinicia.
-- Exploración: extraer vivo tras haber estado en la zona (task.visited).
function PLUGIN:EFGRaidEnded(client, side, reason, runThrough)
	local character = client:GetCharacter()
	if (!character) then return end

	eachActive(client, function(task)
		local step = task.steps[1]
		local died = reason == "death" or reason == "mia"

		if (step.type == "survive") then
			if (reason == "extract" and !runThrough and mapMatches(step.map)) then
				task.progress = (task.progress or 0) + 1
				return true
			end

			if (died and (task.progress or 0) > 0) then
				task.progress = 0
				return true
			end

			return false
		end

		if (step.type == "explore") then
			if (died and task.visited) then
				task.visited = false
				return true
			end

			if (reason == "extract" and !runThrough and task.visited and mapMatches(step.map)) then
				task.progress = step.count
				return true
			end
		end

		return false
	end)
end

-- Marca como visitada la zona de exploración cuando el jugador está dentro del radio del punto.
timer.Create("tareasDiarias_Zonas", 2, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		local character = IsValid(ply) and ply:GetCharacter()

		if (character and ply.InRaid and ply:InRaid()) then
			local state = character:GetTareasDiarias() or {}
			local changed = false

			for _, entry in pairs(state) do
				local task = entry.task
				local step = task and task.status == "active" and task.steps[1]

				if (step and step.type == "explore" and !task.visited and mapMatches(step.map)) then
					local point = ix.tareasDiarias.zonePoints[step.map] and ix.tareasDiarias.zonePoints[step.map][step.zone]

					if (point and ply:GetPos():Distance(Vector(point.pos.x, point.pos.y, point.pos.z)) <= point.radius) then
						task.visited = true
						changed = true
					end
				end
			end

			if (changed) then character:SetTareasDiarias(state) end
		end
	end
end)

-- Entrega FIR: quita del inventario los objetos encontrados en raid pedidos.
function ix.tareasDiarias.Deliver(client, traderKey)
	local character = client:GetCharacter()
	if (!character) then return false, "Sin personaje." end

	local state = character:GetTareasDiarias() or {}
	local entry = state[traderKey]
	local task = entry and entry.task

	if (!task or task.status != "active") then return false, "No tienes una tarea de entrega activa." end

	local step = task.steps[1]
	if (step.type != "deliver") then return false, "Esta tarea no es de entrega." end

	local inventory = character:GetInventory()
	local owned, total = {}, 0

	for _, it in pairs(inventory:GetItems()) do
		if (it.uniqueID == step.itemID and it:GetData("fir")) then
			owned[#owned + 1] = it
			total = total + (it:GetData("Amount") or it:GetData("count") or 1)
		end
	end

	if (total < step.count) then
		return false, "Te faltan objetos (" .. total .. "/" .. step.count .. ")."
	end

	local remaining = step.count
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

	task.progress = step.count
	task.status = "done"
	task.reward = task.rewardOptions and task.rewardOptions[1] or {}
	task.reward.traderKey = traderKey
	ix.tareasDiarias.GiveReward(client, character, task.reward)
	state[traderKey] = entry
	character:SetTareasDiarias(state)

	return true, "Tarea diaria entregada: " .. task.title
end

-- Acepta la tarea vigente del comerciante. Solo una activa a la vez.
function ix.tareasDiarias.Accept(client, traderKey)
	local character = client:GetCharacter()
	if (!character) then return false, "Sin personaje." end

	local state = character:GetTareasDiarias() or {}

	for _, entry in pairs(state) do
		if (entry.task and entry.task.status == "active") then
			return false, "Ya tienes una tarea diaria en curso."
		end
	end

	local entry = state[traderKey]
	local task = entry and entry.task

	if (!task or task.status != "available") then return false, "No hay tarea disponible de este comerciante." end

	if (character:GetEFGLevel() < task.requires.minLevel) then
		return false, "Te falta nivel para esta tarea."
	end

	if (ix.traders.GetEffectiveRep(character, traderKey) < task.requires.minRep) then
		return false, "Te falta lealtad con este comerciante."
	end

	task.status = "active"
	task.progress = 0
	character:SetTareasDiarias(state)

	return true, "Tarea diaria aceptada: " .. task.title
end
