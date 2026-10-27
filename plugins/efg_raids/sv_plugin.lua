local PLUGIN = PLUGIN

util.AddNetworkString("ixEFGShowExtracts")
util.AddNetworkString("ixEFGRaidResult")
util.AddNetworkString("ixEFGExtractDenied")

PLUGIN.raiders  = PLUGIN.raiders  or {} -- [client] = {side, endTime, startTime, extracts, extractIndex, extractEnd}
PLUGIN.groups   = PLUGIN.groups   or {} -- [leader] = {leader = client, members = {client, ...}}
PLUGIN.invites  = PLUGIN.invites  or {} -- [target] = {from = client, expire = CurTime()}
PLUGIN.deploys  = PLUGIN.deploys  or {} -- [client] = true mientras dura la cuenta atrás

-- ─── Datos del mapa (escondite, spawns, extracciones) ────────────────────────
function PLUGIN:GetMapData()
	self.mapData = self.mapData or {spawns = {}, extracts = {}}
	return self.mapData
end

function PLUGIN:SaveMapData()
	self:SetData(self:GetMapData())
	self:SyncPoints()
end

function PLUGIN:LoadData()
	local data = self:GetData({})

	self.mapData = {
		hideout  = data.hideout,
		spawns   = data.spawns or {},
		extracts = data.extracts or {},
		switches = data.switches or {}
	}

	self:SyncPoints()
end

-- Los clientes necesitan las extracciones (nombre, posición y radio) para el HUD,
-- y los admins los spawns para verlos en noclip.
function PLUGIN:SyncPoints()
	local data = self:GetMapData()
	local extracts, spawns = {}, {}

	for i, v in ipairs(data.extracts) do
		extracts[i] = {name = v.name, pos = v.pos, radius = v.radius, type = v.type, side = v.side, cost = v.cost}
	end

	for i, v in ipairs(data.spawns) do
		spawns[i] = v.pos
	end

	SetNetVar("efgExtracts", extracts)
	SetNetVar("efgSpawns", spawns)
	SetNetVar("efgHideout", data.hideout and data.hideout.pos or nil)
end

function PLUGIN:SetHideout(pos, ang)
	self:GetMapData().hideout = {pos = pos, ang = Angle(0, ang.y, 0)}
	self:SaveMapData()
end

function PLUGIN:AddSpawn(pos, ang)
	local spawns = self:GetMapData().spawns
	spawns[#spawns + 1] = {pos = pos, ang = Angle(0, ang.y, 0)}
	self:SaveMapData()

	return #spawns
end

function PLUGIN:AddExtract(extract)
	local extracts = self:GetMapData().extracts
	extracts[#extracts + 1] = extract
	self:SaveMapData()
end

function PLUGIN:RemoveNearest(pos)
	local data = self:GetMapData()
	local bestList, bestIndex, bestDist

	for _, list in ipairs({data.spawns, data.extracts, data.switches or {}}) do
		for i, v in ipairs(list) do
			local dist = v.pos:Distance(pos)

			if (dist < 300 and (!bestDist or dist < bestDist)) then
				bestList, bestIndex, bestDist = list, i, dist
			end
		end
	end

	if (!bestList) then
		return "No hay ningún spawn ni extracción a menos de 300 unidades."
	end

	local removed = table.remove(bestList, bestIndex)
	self:SaveMapData()

	return removed.name and ("Extracción \"" .. removed.name .. "\" borrada.") or "Spawn de raid borrado."
end

-- ─── Interruptores de extracción ─────────────────────────────────────────────
PLUGIN.switchActive = PLUGIN.switchActive or {} -- [nombre] = CurTime() al accionarlo

function PLUGIN:KeyPress(client, key)
	if (key != IN_USE or !client:InRaid()) then return end

	local eye = client:EyePos()

	for _, switch in ipairs(self:GetMapData().switches or {}) do
		if (eye:Distance(switch.pos) <= 90) then
			if ((self.switchActive[switch.name] or 0) + 2 > CurTime()) then return end

			self.switchActive[switch.name] = CurTime()
			client:EmitSound("buttons/lever7.wav", 75)
			client:Notify(("Has accionado el interruptor: la extracción \"%s\" está abierta %d min."):format(switch.name, ix.config.Get("efgSwitchMinutes", 10)))

			return
		end
	end
end

function PLUGIN:InHideout(pos)
	local hideout = self:GetMapData().hideout
	if (!hideout) then return false end

	return pos:Distance(hideout.pos) <= ix.config.Get("efgHideoutRadius", 1500)
end

function PLUGIN:SendToHideout(client)
	local hideout = self:GetMapData().hideout
	if (!hideout) then return end

	local offset = VectorRand() * 48
	offset.z = 0

	client:SetPos(hideout.pos + offset)
	client:SetEyeAngles(hideout.ang)
	client:SetVelocity(-client:GetVelocity())
end

-- ─── Grupos ──────────────────────────────────────────────────────────────────
function PLUGIN:GetGroup(client)
	for _, group in pairs(self.groups) do
		if (table.HasValue(group.members, client)) then
			return group
		end
	end
end

function PLUGIN:GroupInvite(client, target)
	if (target == client) then
		return "No puedes invitarte a ti mismo."
	end

	local group = self:GetGroup(client)

	if (group and group.leader != client) then
		return "Solo el líder del grupo puede invitar."
	end

	if (self:GetGroup(target)) then
		return target:Name() .. " ya está en un grupo."
	end

	if (group and #group.members >= ix.config.Get("efgGroupMax", 5)) then
		return "Tu grupo está lleno."
	end

	self.invites[target] = {from = client, expire = CurTime() + 60}
	target:Notify(client:Name() .. " te invita a su grupo de raid. Escribe /GrupoAceptar (60 s).")

	return "Invitación enviada a " .. target:Name() .. "."
end

function PLUGIN:GroupAccept(client)
	local invite = self.invites[client]
	self.invites[client] = nil

	if (!invite or invite.expire < CurTime() or !IsValid(invite.from)) then
		return "No tienes invitaciones pendientes."
	end

	if (client:InRaid() or invite.from:InRaid()) then
		return "No puedes unirte a un grupo durante una raid."
	end

	self:GroupLeave(client, true)

	local leader = invite.from
	local group = self:GetGroup(leader)

	if (!group) then
		group = {leader = leader, members = {leader}}
		self.groups[leader] = group
	end

	if (#group.members >= ix.config.Get("efgGroupMax", 5)) then
		return "Ese grupo está lleno."
	end

	group.members[#group.members + 1] = client

	for _, member in ipairs(group.members) do
		if (IsValid(member) and member != client) then
			member:Notify(client:Name() .. " se ha unido al grupo.")
		end
	end

	self:SyncGroup(group)

	return "Te has unido al grupo de " .. leader:Name() .. "."
end

function PLUGIN:GroupLeave(client, bSilent)
	local group = self:GetGroup(client)

	if (!group) then
		return !bSilent and "No estás en ningún grupo." or nil
	end

	table.RemoveByValue(group.members, client)
	client:SetNetVar("efgGroup", nil)

	if (group.leader == client or #group.members < 2) then
		self.groups[group.leader] = nil

		for _, member in ipairs(group.members) do
			if (IsValid(member)) then
				member:SetNetVar("efgGroup", nil)
				member:Notify("El grupo se ha disuelto.")
			end
		end
	else
		for _, member in ipairs(group.members) do
			if (IsValid(member)) then
				member:Notify(client:Name() .. " ha salido del grupo.")
			end
		end

		self:SyncGroup(group)
	end

	return !bSilent and "Has salido del grupo." or nil
end

-- Los miembros del grupo se ven entre sí en el HUD (EFT no marca a los aliados,
-- pero sin tarjetas de identificación en GMod es fácil dispararse entre amigos).
function PLUGIN:SyncGroup(group)
	local ids = {}

	for _, member in ipairs(group.members) do
		if (IsValid(member)) then
			ids[#ids + 1] = member:EntIndex()
		end
	end

	for _, member in ipairs(group.members) do
		if (IsValid(member)) then
			member:SetNetVar("efgGroup", ids)
		end
	end
end

-- ─── Despliegue ──────────────────────────────────────────────────────────────
function PLUGIN:CanDeploy(client, side)
	local character = client:GetCharacter()

	if (!character or !client:Alive()) then
		return false, "Tienes que estar vivo."
	end

	if (client:InRaid() or self.deploys[client]) then
		return false, "Ya estás en una raid."
	end

	local hideout = self:GetMapData().hideout

	if (hideout and !self:InHideout(client:GetPos())) then
		return false, "Tienes que estar en el escondite."
	end

	if (side == "pmc" and character:GetFaction() == FACTION_SCAV) then
		return false, "Los Scav no pueden desplegar como PMC."
	end

	if (side == "scav") then
		local nextScav = client:GetData("efgNextScav", 0)

		if (nextScav > os.time()) then
			return false, ("Tu Scav estará listo en %s."):format(string.NiceTime(nextScav - os.time()))
		end
	end

	return true
end

function PLUGIN:RequestDeploy(client, side)
	if (#self:GetMapData().spawns == 0) then
		return "Este mapa no tiene spawns de raid. Un admin debe usar /RaidAddSpawn."
	end

	local group = self:GetGroup(client)
	local members = {client}

	if (group) then
		if (group.leader != client) then
			return "Solo el líder del grupo puede desplegar."
		end

		members = {}

		for _, member in ipairs(group.members) do
			if (IsValid(member)) then
				members[#members + 1] = member
			end
		end
	end

	for _, member in ipairs(members) do
		local ok, reason = self:CanDeploy(member, side)

		if (!ok) then
			return (member == client) and reason or (member:Name() .. ": " .. reason)
		end
	end

	local delay = ix.config.Get("efgDeploySeconds", 10)

	for _, member in ipairs(members) do
		self.deploys[member] = true
		member:SetNetVar("efgDeployAt", CurTime() + delay)
		member:Notify(("Desplegando en la raid como %s en %d segundos..."):format(side == "scav" and "Scav" or "PMC", delay))
	end

	timer.Simple(delay, function()
		local ready = {}

		for _, member in ipairs(members) do
			if (IsValid(member)) then
				member:SetNetVar("efgDeployAt", nil)

				if (self.deploys[member]) then
					self.deploys[member] = nil

					-- se vuelve a comprobar: pudo morir o salir del escondite durante la cuenta atrás
					local ok, reason = self:CanDeploy(member, side)

					if (ok) then
						ready[#ready + 1] = member
					else
						member:Notify("Despliegue cancelado: " .. reason)
					end
				end
			end
		end

		if (#ready > 0) then
			self:Deploy(ready, side)
		end
	end)
end

-- Decide qué extracciones están abiertas en esta raid (iguales para todo el grupo)
function PLUGIN:RollExtracts(side)
	local result = {}
	local chance = ix.config.Get("efgRandomExtractChance", 50)

	for i, v in ipairs(self:GetMapData().extracts) do
		if (v.side == "todos" or v.side == side) then
			if (v.type != "aleatoria" or math.random(100) <= chance) then
				result[#result + 1] = i
			end
		end
	end

	-- EFT asigna siempre al menos una salida: si el azar las cerró todas, se abre una
	if (#result == 0) then
		local candidates = {}

		for i, v in ipairs(self:GetMapData().extracts) do
			if (v.side == "todos" or v.side == side) then
				candidates[#candidates + 1] = i
			end
		end

		if (#candidates > 0) then
			result[1] = candidates[math.random(#candidates)]
		end
	end

	return result
end

function PLUGIN:Deploy(members, side)
	local spawns = self:GetMapData().spawns
	local spawn = spawns[math.random(#spawns)]
	local extracts = self:RollExtracts(side)

	for i, member in ipairs(members) do
		-- el grupo aparece junto, en círculo alrededor del punto
		local offset = Vector(0, 0, 0)

		if (i > 1) then
			local angle = (i - 1) / (#members - 1) * math.pi * 2
			offset = Vector(math.cos(angle) * 56, math.sin(angle) * 56, 0)
		end

		self:StartRaid(member, side, spawn.pos + offset, spawn.ang, extracts)
	end
end

function PLUGIN:StartRaid(client, side, pos, ang, extracts)
	local character = client:GetCharacter()
	if (!character) then return end

	if (side == "scav" and !self:BeginScav(client, character)) then
		client:Notify("No se pudo preparar tu Scav. Inténtalo de nuevo.")
		return
	end

	local minutes = ix.config.Get("efgRaidMinutes", 35)
	local endTime = CurTime() + minutes * 60

	self.raiders[client] = {
		side      = side,
		endTime   = endTime,
		startTime = CurTime(),
		extracts  = extracts,
		kills     = 0,
		events    = {{0, "Despliegue (" .. string.upper(side) .. ")"}} -- cronología para la pantalla de fin de raid
	}

	-- si el jugador se desconecta o el servidor se cae con esta marca puesta,
	-- al volver a cargar el personaje pierde el equipo (como en EFT)
	character:SetData("efgInRaid", side)

	local stats = character:GetData("efgStats", {})
	stats.raids = (stats.raids or 0) + 1
	character:SetData("efgStats", stats)

	client:SetPos(pos)
	client:SetEyeAngles(ang)
	client:SetVelocity(-client:GetVelocity())

	client:SetNetVar("efgRaidEnd", endTime)
	client:SetNetVar("efgRaidSide", side)
	client:SetNetVar("efgRaidExtracts", extracts)

	net.Start("ixEFGShowExtracts")
	net.Send(client)

	hook.Run("EFGRaidStarted", client, side)
end

-- reason: "extract", "death", "mia", "admin"
function PLUGIN:EndRaid(client, reason, extract)
	local raid = self.raiders[client]
	if (!raid) then return end

	self.raiders[client] = nil

	client:SetNetVar("efgRaidEnd", nil)
	client:SetNetVar("efgRaidSide", nil)
	client:SetNetVar("efgRaidExtracts", nil)
	client:SetNetVar("efgExtracting", nil)

	local character = client:GetCharacter()
	if (!character) then return end

	character:SetData("efgInRaid", nil)

	local stats = character:GetData("efgStats", {})
	local xp = 0
	local survived = (reason == "extract" or reason == "admin")

	if (reason == "extract") then
		stats.survived = (stats.survived or 0) + 1

		-- Raid#Run_Through: poco tiempo (o poca XP, si efgRunThroughXP > 0)
		local minXP = ix.config.Get("efgRunThroughXP", 0)

		if (CurTime() - raid.startTime < ix.efg.runThroughMinutes * 60 or (minXP > 0 and (raid.xp or 0) < minXP)) then
			xp = ix.efg.xp.runThrough
			raid.runThrough = true
		else
			xp = ix.efg.xp.survived
		end
	elseif (reason == "mia") then
		stats.mia = (stats.mia or 0) + 1
	elseif (reason == "death") then
		stats.killed = (stats.killed or 0) + 1
	end

	character:SetData("efgStats", stats)

	-- el Scav no da experiencia al PMC al morir, pero sí al extraer
	if (xp > 0) then
		self:GiveXP(character, xp)
	end

	if (raid.side == "scav") then
		self:EndScav(client, character, survived)
		client:SetData("efgNextScav", os.time() + ix.config.Get("efgScavCooldown", 20) * 60 * (hook.Run("EFGGetScavCooldownMultiplier", client) or 1))
	end

	if (survived) then
		self:SendToHideout(client)
	end

	local text = ({
		extract = "Sobreviviste" .. (extract and (": extraído por " .. extract.name) or ""),
		death   = "Muerto en combate",
		mia     = "Desaparecido en combate (MIA): se acabó el tiempo",
		admin   = "Has salido de la raid"
	})[reason] or reason

	local events = raid.events or {}
	events[#events + 1] = {CurTime() - raid.startTime, text}

	net.Start("ixEFGRaidResult")
		net.WriteBool(survived)
		net.WriteString(text)
		net.WriteUInt(xp, 16)
		-- datos extra para la pantalla de fin de raid (efgxRaidResult)
		net.WriteUInt(math.min(65535, math.floor(CurTime() - raid.startTime)), 16)
		net.WriteUInt(math.min(255, raid.kills or 0), 8)
		net.WriteString(raid.killedBy or "")
		net.WriteUInt(math.min(#events, 32), 6)

		for i = math.max(1, #events - 31), #events do
			net.WriteUInt(math.min(65535, math.floor(events[i][1])), 16)
			net.WriteString(events[i][2])
		end
	net.Send(client)

	hook.Run("EFGRaidEnded", client, raid.side, reason, raid.runThrough == true)
end

function PLUGIN:GiveXP(character, amount)
	local owner = character:GetPlayer()
	local raid = IsValid(owner) and self.raiders[owner]
	if (raid) then raid.xp = (raid.xp or 0) + amount end

	local before = character:GetEFGLevel()
	character:SetData("efgXP", character:GetEFGXP() + amount)
	local after = character:GetEFGLevel()

	local client = character:GetPlayer()

	if (IsValid(client) and after > before) then
		client:Notify(("¡Has subido al nivel %d!"):format(after))
	end
end

-- ─── Bucle de la raid: tiempo y extracciones ─────────────────────────────────
local nextThink = 0

function PLUGIN:Think()
	if (nextThink > CurTime()) then return end
	nextThink = CurTime() + 0.25

	local data = self:GetMapData()

	for client, raid in pairs(self.raiders) do
		if (!IsValid(client)) then
			self.raiders[client] = nil
		elseif (client:Alive()) then
			if (CurTime() >= raid.endTime) then
				self:EndRaid(client, "mia")
				client:Kill()
			else
				self:CheckExtraction(client, raid, data)
			end
		end
	end

	if (ix.config.Get("efgConfineHideout", true) and data.hideout) then
		self:ConfineHideout()
	end
end

function PLUGIN:CheckExtraction(client, raid, data)
	local pos = client:GetPos()
	local inside

	for _, index in ipairs(raid.extracts) do
		local extract = data.extracts[index]

		if (extract and pos:Distance(extract.pos) <= extract.radius) then
			inside = index
			break
		end
	end

	if (!inside) then
		if (raid.extractIndex) then
			raid.extractIndex = nil
			client:SetNetVar("efgExtracting", nil)
		end

		return
	end

	local extract = data.extracts[inside]

	if (raid.extractIndex != inside) then
		local ok, reason = self:CanUseExtract(client, extract)

		if (!ok) then
			if (raid.blockedNotice != inside) then
				raid.blockedNotice = inside
				client:Notify(reason)

				-- la lista de extracciones se abre con esa fila parpadeando en rojo
				net.Start("ixEFGExtractDenied")
					net.WriteUInt(inside, 8)
				net.Send(client)
			end

			return
		end

		raid.blockedNotice = nil
		raid.extractIndex = inside
		raid.extractEnd = CurTime() + ix.config.Get("efgExtractSeconds", 8)
		client:SetNetVar("efgExtracting", {raid.extractEnd, extract.name, inside})
	elseif (CurTime() >= raid.extractEnd) then
		local ok, reason = self:CanUseExtract(client, extract)

		if (!ok) then
			raid.extractIndex = nil
			client:SetNetVar("efgExtracting", nil)
			client:Notify(reason)
			return
		end

		if (extract.type == "pago" and extract.cost) then
			client:GetCharacter():TakeMoney(extract.cost)
		end

		self:EndRaid(client, "extract", extract)
	end
end

function PLUGIN:CanUseExtract(client, extract)
	local character = client:GetCharacter()

	if (extract.type == "sin_mochila" and character:GetPrimaryBag()) then
		return false, "Esta extracción no permite llevar mochila."
	end

	if (extract.type == "interruptor" and (self.switchActive[extract.name] or 0) + ix.config.Get("efgSwitchMinutes", 10) * 60 < CurTime()) then
		return false, "Esta extracción está cerrada: hay que accionar su interruptor."
	end

	if (extract.type == "pago" and extract.cost and !character:HasMoney(extract.cost)) then
		return false, ("Esta extracción cuesta %s rublos."):format(string.Comma(extract.cost))
	end

	return true
end

-- quien no está en raid no puede salir andando del escondite
function PLUGIN:ConfineHideout()
	for _, client in ipairs(player.GetAll()) do
		if (client:GetCharacter() and client:Alive() and !client:InRaid()
			and client:GetMoveType() != MOVETYPE_NOCLIP and !client:InVehicle()
			and !self:InHideout(client:GetPos())) then
			self:SendToHideout(client)
			client:Notify("Para salir del escondite usa /Raid o /RaidScav.")
		end
	end
end

-- ─── Hooks ───────────────────────────────────────────────────────────────────
-- Zona segura: en el escondite nadie recibe daño
function PLUGIN:EntityTakeDamage(target, dmginfo)
	if (target:IsPlayer() and !target:InRaid() and self:InHideout(target:GetPos())) then
		return true
	end
end

function PLUGIN:PlayerDeath(client, inflictor, attacker)
	local raid = self.raiders[client]

	if (IsValid(attacker) and attacker:IsPlayer() and attacker != client and self.raiders[attacker]) then
		local character = attacker:GetCharacter()

		if (character) then
			local stats = character:GetData("efgStats", {})
			stats.kills = (stats.kills or 0) + 1
			character:SetData("efgStats", stats)

			local attackerRaid = self.raiders[attacker]
			attackerRaid.kills = (attackerRaid.kills or 0) + 1
			attackerRaid.events = attackerRaid.events or {}
			attackerRaid.events[#attackerRaid.events + 1] = {CurTime() - attackerRaid.startTime, "Baja: " .. client:Name()}

			-- el Scav jugador no sube el nivel del PMC por bajas
			if (self.raiders[attacker].side == "pmc") then
				local victimSide = raid and raid.side or "pmc"
				self:GiveXP(character, victimSide == "scav" and ix.efg.xp.killScav or ix.efg.xp.killPMC)
			end
		end
	end

	if (raid) then
		raid.killedBy = IsValid(attacker) and attacker != client and (attacker:IsPlayer() and attacker:Name()
			or (attacker:IsNPC() and (attacker.PrintName or attacker:GetClass()))) or nil
		self:EndRaid(client, "death")
	end
end

function PLUGIN:OnNPCKilled(npc, attacker)
	if (!IsValid(attacker) or !attacker:IsPlayer()) then return end

	local raid = self.raiders[attacker]
	local character = attacker:GetCharacter()

	if (raid and raid.side == "pmc" and character) then
		self:GiveXP(character, npc.efgIsScav and ix.efg.xp.killScav or ix.efg.xp.killNPC)
	end
end

-- al reaparecer fuera de raid, al escondite
function PLUGIN:PostPlayerLoadout(client)
	if (!client:InRaid() and self:GetMapData().hideout) then
		timer.Simple(0, function()
			if (IsValid(client) and !client:InRaid()) then
				self:SendToHideout(client)
			end
		end)
	end
end

-- cambiar de personaje en plena raid cuenta como abandonarla
function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
	if (self.raiders[client]) then
		self.raiders[client] = nil
		client:SetNetVar("efgRaidEnd", nil)
		client:SetNetVar("efgRaidSide", nil)
		client:SetNetVar("efgRaidExtracts", nil)
		client:SetNetVar("efgExtracting", nil)
	end

	self.deploys[client] = nil
	client:SetNetVar("efgDeployAt", nil)

	-- personaje que se quedó en una raid (desconexión, cambio de personaje o caída
	-- del servidor): pierde lo que llevaba encima, salvo el contenedor seguro
	local side = character:GetData("efgInRaid")

	if (side) then
		timer.Simple(1, function()
			if (!IsValid(client) or client:GetCharacter() != character) then return end

			character:SetData("efgInRaid", nil)
			self:WipeCarriedItems(client, character)

			if (side == "scav") then
				self:EndScav(client, character, false)
			else
				local stats = character:GetData("efgStats", {})
				stats.mia = (stats.mia or 0) + 1
				character:SetData("efgStats", stats)
			end

			client:Notify("Abandonaste la raid: has perdido el equipo que llevabas encima.")
		end)
	end
end

function PLUGIN:PlayerDisconnected(client)
	-- la marca efgInRaid del personaje se queda puesta: al volver pierde el equipo
	self.raiders[client] = nil
	self.deploys[client] = nil
	self.invites[client] = nil
	self:GroupLeave(client, true)
end

-- ─── Utilidades de inventario ────────────────────────────────────────────────
-- Recorre los ítems que el personaje lleva encima (inventario y equipo)
function PLUGIN:GetCarriedItems(character, bIncludeNoLoot)
	local items = {}
	local inventories = {character:GetInventory(), ix.GetEquipInventory and ix.GetEquipInventory(character)}

	for _, inventory in pairs(inventories) do
		if (inventory and inventory.slots) then
			for _, slot in pairs(inventory.slots) do
				for _, item in pairs(slot) do
					if ((bIncludeNoLoot or !item.noLoot) and !table.HasValue(items, item)) then
						items[#items + 1] = item
					end
				end
			end
		end
	end

	return items
end

function PLUGIN:UnequipItem(client, item)
	if (item:GetData("equip")) then
		if (item.Unequip) then
			item:Unequip(client)
		elseif (item.RemoveOutfit) then
			item:RemoveOutfit(client)
		end
	end
end

-- Borra todo lo que el personaje lleva encima menos lo marcado con noLoot
-- (el contenedor seguro y su contenido)
function PLUGIN:WipeCarriedItems(client, character)
	for _, item in ipairs(self:GetCarriedItems(character)) do
		self:UnequipItem(client, item)
		item:Remove()
	end
end
