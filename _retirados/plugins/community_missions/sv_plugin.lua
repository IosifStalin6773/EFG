-- ============================================================
--  community_missions  |  sv_plugin.lua  (SERVER)
--  Persistencia, ciclo de vida, tracking de progreso,
--  recompensas y comandos de misiones comunitarias.
-- ============================================================

-- Net strings
util.AddNetworkString("cmission_State")        -- sv->cl: estado global de la misión
util.AddNetworkString("cmission_PlayerState")   -- sv->cl: estado personal del jugador
util.AddNetworkString("cmission_Join")          -- cl->sv: unirse a la misión
util.AddNetworkString("cmission_Deliver")       -- cl->sv: entregar objetos
util.AddNetworkString("cmission_Claim")         -- cl->sv: reclamar recompensa
util.AddNetworkString("cmission_AdminSave")     -- cl->sv: guardar definición
util.AddNetworkString("cmission_AdminDelete")   -- cl->sv: eliminar definición
util.AddNetworkString("cmission_AdminStart")    -- cl->sv: iniciar misión
util.AddNetworkString("cmission_AdminStop")     -- cl->sv: detener misión activa
util.AddNetworkString("cmission_AdminData")     -- sv->cl: datos para el panel admin
util.AddNetworkString("cmission_AdminRequest")  -- cl->sv: solicitar datos admin
util.AddNetworkString("cmission_OpenAdmin")     -- sv->cl: abrir panel admin

-- Estado en memoria
ix.communityMissions.definitions = ix.communityMissions.definitions or {}
ix.communityMissions.nextId      = ix.communityMissions.nextId or 1
ix.communityMissions.active      = ix.communityMissions.active or nil
ix.communityMissions._dirty      = false

-- ============================================================
--  Persistencia
-- ============================================================

function PLUGIN:LoadData()
	local data = self:GetData() or {}
	ix.communityMissions.definitions = data.definitions or {}
	ix.communityMissions.nextId      = data.nextId or 1
	ix.communityMissions.active      = data.active or nil
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	ix.data.SetSafe(self.uniqueID, {
		definitions = ix.communityMissions.definitions,
		nextId      = ix.communityMissions.nextId,
		active      = ix.communityMissions.active,
	})
end

local function saveData()
	local plugin = ix.plugin.Get("community_missions")
	if (plugin) then plugin:SaveData() end
end

-- ============================================================
--  Broadcast / Sync
-- ============================================================

function ix.communityMissions.SendState(client)
	local active = ix.communityMissions.active

	net.Start("cmission_State")
		if (active) then
			net.WriteBool(true)
			net.WriteString(active.id or "")
			net.WriteString(active.name or "")
			net.WriteString(active.description or "")
			net.WriteString(active.type or "")
			net.WriteString(active.type == "kill" and (active.npcClass or "") or "")
			net.WriteString(active.targetName or "")
			net.WriteUInt(active.goalCount or 0, 32)
			net.WriteUInt(math.min(active.progress or 0, active.goalCount or 0), 32)
			net.WriteUInt(table.Count(active.joined or {}), 16)
			net.WriteBool(active.completed == true)
			net.WriteString(util.TableToJSON(active.rewardOptions or {}))
			net.WriteString(util.TableToJSON(active.deliverItems or {}))
			net.WriteString(util.TableToJSON(active.deliverProgress or {}))
		else
			net.WriteBool(false)
		end

	if (client) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

function ix.communityMissions.SendPlayerState(client)
	if (!IsValid(client)) then return end
	local character = client:GetCharacter()
	if (!character) then return end

	local active = ix.communityMissions.active
	local charID = tostring(character:GetID())

	net.Start("cmission_PlayerState")
		if (active) then
			net.WriteBool(active.joined and active.joined[charID] == true or false)
			net.WriteUInt(active.contributors and active.contributors[charID] or 0, 32)
			net.WriteBool(active.claimed and active.claimed[charID] == true or false)
		else
			net.WriteBool(false)
			net.WriteUInt(0, 32)
			net.WriteBool(false)
		end
	net.Send(client)
end

function ix.communityMissions.SyncFull(client)
	ix.communityMissions.SendState(client)
	ix.communityMissions.SendPlayerState(client)
end

-- Broadcast con throttle (1 seg)
timer.Create("cmission_Broadcast", 1, 0, function()
	if (!ix.communityMissions._dirty) then return end
	ix.communityMissions._dirty = false
	ix.communityMissions.SendState()
end)

-- ============================================================
--  Ciclo de vida: Start, Stop, MarkComplete, Claim
-- ============================================================

function ix.communityMissions.Start(defId)
	local def = ix.communityMissions.definitions[defId]
	if (!def) then return false, "Definición no encontrada." end
	if (ix.communityMissions.active) then return false, "Ya hay una misión comunitaria activa. Detenla primero." end

	-- Normalizar deliverItems para entregas (migrar formato antiguo si es necesario)
	local deliverItems = {}
	local deliverProgress = {}
	local goalCount = def.goalCount or 1

	if (def.type == "deliver") then
		if (istable(def.deliverItems) and #def.deliverItems > 0) then
			deliverItems = table.Copy(def.deliverItems)
		elseif (def.itemID and def.itemID != "") then
			deliverItems = {{id = def.itemID, count = def.goalCount or 1}}
		end

		goalCount = 0
		for _, di in ipairs(deliverItems) do
			deliverProgress[di.id] = 0
			goalCount = goalCount + (di.count or 1)
		end
	end

	ix.communityMissions.active = {
		id              = def.id,
		name            = def.name,
		description     = def.description or "",
		type            = def.type,
		npcClass        = def.npcClass,
		targetName      = def.targetName or "",
		goalCount       = goalCount,
		progress        = 0,
		deliverItems    = deliverItems,
		deliverProgress = deliverProgress,
		joined          = {},
		contributors    = {},
		claimed         = {},
		completed       = false,
		rewardOptions   = table.Copy(def.rewardOptions or {{balas = 0, rep = 0, items = {}}}),
		startedAt       = os.time(),
	}

	ix.communityMissions._dirty = true
	saveData()

	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client)) then
			client:Notify("¡Nueva misión comunitaria: " .. def.name .. "!")
			ix.communityMissions.SyncFull(client)
		end
	end

	return true
end

function ix.communityMissions.Stop()
	if (!ix.communityMissions.active) then return false, "No hay misión comunitaria activa." end

	local name = ix.communityMissions.active.name
	ix.communityMissions.active = nil
	ix.communityMissions._dirty = true
	saveData()

	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client)) then
			client:Notify("La misión comunitaria \"" .. name .. "\" ha sido cancelada.")
			ix.communityMissions.SyncFull(client)
		end
	end

	return true
end

-- Marca la misión como completada (no da recompensas aún — se reclaman individualmente)
function ix.communityMissions.MarkComplete()
	local active = ix.communityMissions.active
	if (!active or active.completed) then return end

	active.completed = true
	ix.communityMissions._dirty = true
	saveData()

	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client)) then
			client:Notify("¡Misión comunitaria completada: " .. active.name .. "! Reclama tu recompensa en el tablón de misiones.")
			ix.communityMissions.SyncFull(client)
		end
	end
end

-- Comprueba si el inventario tiene espacio para todos los ítems de una recompensa.
local function canFitRewardItems(character, rewardOpt)
	local r = rewardOpt or {}
	if (!r.items or #r.items == 0) then return true end

	local inventory = character:GetInventory()
	if (!inventory) then return false end

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

-- Un jugador reclama su recompensa individual
function ix.communityMissions.ClaimReward(client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local active = ix.communityMissions.active
	if (!active or !active.completed) then
		client:Notify("No hay misión comunitaria completada.")
		return
	end

	local character = client:GetCharacter()
	local charID    = tostring(character:GetID())

	if (!active.joined[charID]) then
		client:Notify("No participaste en esta misión.")
		return
	end

	if (active.claimed[charID]) then
		client:Notify("Ya has reclamado tu recompensa.")
		return
	end

	local reward = active.rewardOptions and active.rewardOptions[1] or {}

	if (!canFitRewardItems(character, reward)) then
		client:Notify("No tienes espacio en el inventario para la recompensa. Haz hueco e inténtalo de nuevo.")
		return
	end

	if (reward.balas and reward.balas > 0) then
		local mult = hook.Run("AdjustMissionReward", client, character) or 1
		character:GiveMoney(math.Round(reward.balas * mult))
	end

	if (reward.rep and reward.rep > 0 and character.GetTraderRep) then
		local factionIndex = character:GetFaction()
		local factionData  = ix.faction.indices and ix.faction.indices[factionIndex]
		local fk = factionData and factionData.uniqueID or "civil"
		local traderRep = character:GetTraderRep() or {}
		traderRep[fk] = math.Clamp((traderRep[fk] or 0) + reward.rep, 0, 1000)
		character:SetTraderRep(traderRep)
	end

	if (reward.items) then
		local inventory = character:GetInventory()
		for _, entry in ipairs(reward.items) do
			if (ix.item.list[entry.id]) then
				for i = 1, (entry.qty or 1) do
					inventory:Add(entry.id)
				end
			end
		end
	end

	active.claimed[charID] = true
	saveData()

	ix.communityMissions.SendPlayerState(client)
	ix.communityMissions.SendState()
	client:Notify("¡Recompensa reclamada!")
end

-- ============================================================
--  Acciones del jugador: Unirse, Entregar
-- ============================================================

function ix.communityMissions.JoinPlayer(client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local active = ix.communityMissions.active
	if (!active) then
		client:Notify("No hay ninguna misión comunitaria activa.")
		return
	end

	if (active.completed) then
		client:Notify("La misión ya está completada.")
		return
	end

	local charID = tostring(client:GetCharacter():GetID())
	if (active.joined[charID]) then
		client:Notify("Ya estás participando en esta misión.")
		return
	end

	active.joined[charID]       = true
	active.contributors[charID] = active.contributors[charID] or 0
	ix.communityMissions._dirty = true
	saveData()

	ix.communityMissions.SendPlayerState(client)
	client:Notify("Te has unido a la misión comunitaria: " .. active.name)
end

function ix.communityMissions.DeliverItems(client, traderEnt)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local active = ix.communityMissions.active
	if (!active or active.type != "deliver") then
		client:Notify("No hay misión comunitaria de entrega activa.")
		return
	end

	if (active.completed) then
		client:Notify("La misión ya está completada.")
		return
	end

	local charID = tostring(client:GetCharacter():GetID())
	if (!active.joined[charID]) then
		client:Notify("No estás participando. Usa /unirseComunitaria.")
		return
	end

	-- Comprobar proximidad a un trader
	if (IsValid(traderEnt) and traderEnt:GetClass() == "ix_trader") then
		if (client:GetPos():Distance(traderEnt:GetPos()) > 200) then
			client:Notify("Estás demasiado lejos del comerciante.")
			return
		end
	else
		local nearTrader = false
		for _, ent in ipairs(ents.FindByClass("ix_trader")) do
			if (IsValid(ent) and client:GetPos():Distance(ent:GetPos()) <= 200) then
				nearTrader = true
				break
			end
		end
		if (!nearTrader) then
			client:Notify("Debes estar cerca de un comerciante para entregar.")
			return
		end
	end

	local character = client:GetCharacter()
	local inventory = character:GetInventory()
	local items     = active.deliverItems or {}
	active.deliverProgress = active.deliverProgress or {}

	local totalDelivered = 0

	for _, dItem in ipairs(items) do
		local needed = (dItem.count or 1) - (active.deliverProgress[dItem.id] or 0)
		if (needed <= 0) then continue end

		local owned = {}
		local total = 0
		for _, it in pairs(inventory:GetItems()) do
			if (it.uniqueID == dItem.id) then
				owned[#owned + 1] = it
				total = total + (it:GetData("Amount") or it:GetData("count") or 1)
			end
		end

		local toDeliver = math.min(total, needed)
		if (toDeliver <= 0) then continue end

		local left = toDeliver
		for _, it in ipairs(owned) do
			if (left <= 0) then break end
			local amount = it:GetData("Amount") or it:GetData("count") or 1
			if (amount <= left) then
				left = left - amount
				inventory:Remove(it:GetID())
			else
				local field = it:GetData("Amount") and "Amount" or "count"
				it:SetData(field, amount - left)
				left = 0
			end
		end

		local delivered = toDeliver - left
		active.deliverProgress[dItem.id] = (active.deliverProgress[dItem.id] or 0) + delivered
		totalDelivered = totalDelivered + delivered
	end

	if (totalDelivered <= 0) then
		client:Notify("No tienes objetos necesarios para la misión.")
		return
	end

	-- Recalcular progreso global
	local totalProgress = 0
	for _, dItem in ipairs(items) do
		totalProgress = totalProgress + math.min(active.deliverProgress[dItem.id] or 0, dItem.count or 1)
	end
	active.progress = totalProgress
	active.contributors[charID] = (active.contributors[charID] or 0) + totalDelivered
	ix.communityMissions._dirty = true

	ix.communityMissions.SendPlayerState(client)
	client:Notify("Has entregado " .. totalDelivered .. " objetos. ¡Gracias por tu contribución!")

	-- Comprobar si todos los ítems están completos
	local allDone = true
	for _, dItem in ipairs(items) do
		if ((active.deliverProgress[dItem.id] or 0) < (dItem.count or 1)) then
			allDone = false
			break
		end
	end

	if (allDone) then
		ix.communityMissions.MarkComplete()
	else
		saveData()
	end
end

-- ============================================================
--  Hooks
-- ============================================================

function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
	local active = ix.communityMissions.active
	if (!active or active.type != "kill" or active.completed) then return end
	if (!IsValid(npc) or !IsValid(attacker) or !attacker:IsPlayer()) then return end
	if (!attacker:GetCharacter()) then return end

	local charID = tostring(attacker:GetCharacter():GetID())
	if (!active.joined or !active.joined[charID]) then return end
	if (active.npcClass and active.npcClass != "" and npc:GetClass() != active.npcClass) then return end

	active.progress = (active.progress or 0) + 1
	active.contributors[charID] = (active.contributors[charID] or 0) + 1
	ix.communityMissions._dirty = true

	ix.communityMissions.SendPlayerState(attacker)

	if (active.progress >= (active.goalCount or 1)) then
		ix.communityMissions.MarkComplete()
	else
		saveData()
	end
end

function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()
	if (!IsValid(client)) then return end

	timer.Simple(2, function()
		if (!IsValid(client)) then return end
		ix.communityMissions.SyncFull(client)
	end)
end

-- ============================================================
--  Datos para el tablón de misiones (usado por missions plugin)
-- ============================================================

-- Devuelve la info de la misión comunitaria activa para un jugador, para incluirla en el tablón.
function ix.communityMissions.GetOfferForPlayer(character)
	local active = ix.communityMissions.active
	if (!active) then return nil end

	local charID  = tostring(character:GetID())
	local joined  = active.joined and active.joined[charID] == true
	local claimed = active.claimed and active.claimed[charID] == true

	if (claimed) then return nil end

	return {
		id               = active.id,
		name             = active.name,
		description      = active.description,
		type             = active.type,
		targetName       = active.targetName or "",
		npcClass         = active.npcClass,
		goalCount        = active.goalCount or 1,
		progress         = math.min(active.progress or 0, active.goalCount or 1),
		joined           = joined,
		completed        = active.completed == true,
		participantCount = table.Count(active.joined or {}),
		myContribution   = active.contributors and active.contributors[charID] or 0,
		rewardOptions    = active.rewardOptions or {},
		deliverItems     = active.deliverItems or {},
		deliverProgress  = active.deliverProgress or {},
		isCommunity      = true,
	}
end

-- ============================================================
--  Receptores de red — Jugador
-- ============================================================

net.Receive("cmission_Join", function(len, client)
	ix.communityMissions.JoinPlayer(client)
end)

net.Receive("cmission_Deliver", function(len, client)
	local traderEnt = net.ReadEntity()
	ix.communityMissions.DeliverItems(client, traderEnt)
end)

net.Receive("cmission_Claim", function(len, client)
	ix.communityMissions.ClaimReward(client)
end)

-- ============================================================
--  Receptores de red — Admin
-- ============================================================

local function sendAdminData(client)
	net.Start("cmission_AdminData")
		net.WriteTable(ix.communityMissions.definitions or {})
		net.WriteTable(ix.communityMissions.active or {})
	net.Send(client)
end

net.Receive("cmission_AdminRequest", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	sendAdminData(client)
end)

net.Receive("cmission_AdminSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local def = net.ReadTable()
	if (!istable(def)) then return end

	if (!def.id or def.id == "") then
		def.id = "cm" .. ix.communityMissions.nextId
		ix.communityMissions.nextId = ix.communityMissions.nextId + 1
	end

	def.name        = tostring(def.name or "Misión sin nombre")
	def.description = tostring(def.description or "")
	def.type        = (def.type == "kill" or def.type == "deliver") and def.type or "kill"
	def.npcClass    = tostring(def.npcClass or "")
	def.targetName  = tostring(def.targetName or "")
	def.goalCount   = math.max(1, math.floor(tonumber(def.goalCount) or 1))

	-- Normalizar deliverItems para entregas
	if (def.type == "deliver") then
		def.deliverItems = istable(def.deliverItems) and def.deliverItems or {}
		for i, di in ipairs(def.deliverItems) do
			def.deliverItems[i] = {
				id    = tostring(di.id or ""),
				count = math.max(1, math.floor(tonumber(di.count) or 1)),
			}
		end
	end

	def.rewardOptions = istable(def.rewardOptions) and def.rewardOptions or {{balas = 0, rep = 0, items = {}}}
	for i, opt in ipairs(def.rewardOptions) do
		def.rewardOptions[i] = {
			balas = math.max(0, tonumber(opt.balas) or 0),
			rep   = math.max(0, tonumber(opt.rep)   or 0),
			items = istable(opt.items) and opt.items or {},
		}
	end

	ix.communityMissions.definitions[def.id] = def
	saveData()
	sendAdminData(client)
end)

net.Receive("cmission_AdminDelete", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local id = net.ReadString()
	if (ix.communityMissions.definitions[id]) then
		ix.communityMissions.definitions[id] = nil
		saveData()
	end
	sendAdminData(client)
end)

net.Receive("cmission_AdminStart", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local id = net.ReadString()
	local ok, reason = ix.communityMissions.Start(id)
	if (!ok) then
		client:Notify(reason or "No se pudo iniciar la misión.")
	end
	sendAdminData(client)
end)

net.Receive("cmission_AdminStop", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local ok, reason = ix.communityMissions.Stop()
	if (!ok) then
		client:Notify(reason or "No se pudo detener la misión.")
	end
	sendAdminData(client)
end)

-- ============================================================
--  Comandos
-- ============================================================

ix.command.Add("MisionComunitariaAdmin", {
	adminOnly   = true,
	description = "Abre el panel de administración de misiones comunitarias.",
	OnRun = function(self, client)
		net.Start("cmission_OpenAdmin")
		net.Send(client)
	end
})

ix.command.Add("unirseComunitaria", {
	description = "Únete a la misión comunitaria activa.",
	OnRun = function(self, client)
		ix.communityMissions.JoinPlayer(client)
	end
})

ix.command.Add("estadoComunitaria", {
	description = "Muestra el estado de la misión comunitaria activa.",
	OnRun = function(self, client)
		local active = ix.communityMissions.active
		if (!active) then
			return "No hay ninguna misión comunitaria activa."
		end

		client:ChatPrint("=== Misión Comunitaria: " .. active.name .. " ===")
		client:ChatPrint(ix.communityMissions.GetObjectiveText(active))

		local pct = math.floor(((active.progress or 0) / math.max(active.goalCount or 1, 1)) * 100)
		local status = active.completed and " [COMPLETADA]" or ""
		client:ChatPrint("Progreso: " .. pct .. "%" .. status .. "  (" .. (active.progress or 0) .. "/" .. (active.goalCount or 1) .. ")")
		client:ChatPrint("Participantes: " .. table.Count(active.joined or {}))

		if (!client:GetCharacter()) then return end
		local charID = tostring(client:GetCharacter():GetID())

		if (active.joined and active.joined[charID]) then
			client:ChatPrint("Tu aporte: " .. (active.contributors and active.contributors[charID] or 0))
			if (active.completed) then
				if (active.claimed and active.claimed[charID]) then
					client:ChatPrint("Recompensa ya reclamada.")
				else
					client:ChatPrint("¡Reclama tu recompensa en el tablón de misiones de un comerciante!")
				end
			end
		else
			client:ChatPrint("No estás participando. Usa /unirseComunitaria para unirte.")
		end
	end
})

ix.command.Add("entregarComunitaria", {
	description = "Entrega objetos para la misión comunitaria (cerca de un comerciante).",
	OnRun = function(self, client)
		ix.communityMissions.DeliverItems(client, nil)
	end
})
