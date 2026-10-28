local PLUGIN = PLUGIN

util.AddNetworkString("ixDescuartizarStart")
util.AddNetworkString("ixDescuartizarOpen")
util.AddNetworkString("ixDescuartizarSubmit")

local SUBMIT_WINDOW = 30

function PLUGIN:GenerateLoot(rounds)
	local rewards = {}
	local emptySlot = math.random(1, rounds)

	for i = 1, rounds do
		if (i == emptySlot) then
			rewards[i] = false
		else
			local items = self.lootItems
			rewards[i] = items[math.random(1, #items)]
		end
	end

	for i = rounds, 2, -1 do
		local j = math.random(1, i)
		rewards[i], rewards[j] = rewards[j], rewards[i]
	end

	return rewards
end

function PLUGIN:MarkCarneable(entity)
	if (!IsValid(entity)) then return end

	entity.ixCarneable = true
	entity:SetNetVar("carneable", true)
	entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

function PLUGIN:ApplyDecayTimer(entity)
	timer.Simple(300, function()
		if (IsValid(entity) and !entity:GetNetVar("descuartizando")) then
			entity:Remove()
		end
	end)
end

function PLUGIN:EntityTakeDamage(npc, dmgInfo)
	if (!IsValid(npc) or !npc:IsNPC() or npc.ixDoDeathBlocked) then return end
	if (!self:IsCarneableClass(npc:GetClass()) or !isfunction(npc.DoDeath)) then return end

	if (npc:Health() - dmgInfo:GetDamage() <= 0) then
		npc.ixDoDeathBlocked = true
		npc.DoDeath = function() end
	end
end

function PLUGIN:SaveNPCData(npc)
	local data = {
		model = npc:GetModel(),
		pos = npc:GetPos(),
		angles = npc:GetAngles(),
		skin = npc:GetSkin(),
		bodygroups = {},
		bones = {}
	}

	for i = 0, npc:GetNumBodyGroups() - 1 do
		data.bodygroups[i] = npc:GetBodygroup(i)
	end

	self:CaptureBones(npc, data)

	return data
end

function PLUGIN:CaptureBones(npc, data)
	local origin = npc:GetPos()

	for i = 0, npc:GetBoneCount() - 1 do
		local pos, ang = npc:GetBonePosition(i)

		if (pos and pos:DistToSqr(origin) > 1) then
			data.bones[i] = { pos = pos, ang = ang }
		end
	end
end

function PLUGIN:SpawnCorpseFromData(data)
	local ragdoll = ents.Create("prop_ragdoll")

	if (!IsValid(ragdoll)) then return end

	ragdoll:SetModel(data.model)
	ragdoll:SetPos(data.pos)
	ragdoll:SetAngles(data.angles)
	ragdoll:Spawn()
	ragdoll:SetSkin(data.skin)

	for i, bg in pairs(data.bodygroups) do
		ragdoll:SetBodygroup(i, bg)
	end

	-- Copiar la pose final del NPC al ragdoll para evitar que aparezca en T-pose.
	local hasBones = next(data.bones) != nil

	if (hasBones) then
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = ragdoll:GetPhysicsObjectNum(i)
			local bone = ragdoll:TranslatePhysBoneToBone(i)

			if (IsValid(phys) and data.bones[bone]) then
				phys:SetPos(data.bones[bone].pos)
				phys:SetAngles(data.bones[bone].ang)
				phys:SetVelocity(Vector(0, 0, 0))
				phys:Wake()
			end
		end
	else
		local phys = ragdoll:GetPhysicsObject()

		if (IsValid(phys)) then
			phys:Wake()
		end
	end

	self:MarkCarneable(ragdoll)
	self:ApplyDecayTimer(ragdoll)
end

function PLUGIN:WaitAndSpawnCorpse(npc)
	local data = self:SaveNPCData(npc)
	local timerName = "ixDescuartizar_WaitDeath_" .. npc:EntIndex()
	local startTime = CurTime()

	timer.Create(timerName, 0.1, 0, function()
		if (IsValid(npc)) then
			data.pos = npc:GetPos()
			data.angles = npc:GetAngles()
			self:CaptureBones(npc, data)

			if (CurTime() - startTime > 10) then
				timer.Remove(timerName)
				self:SpawnCorpseFromData(data)
			end
		else
			timer.Remove(timerName)
			self:SpawnCorpseFromData(data)
		end
	end)
end

function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
	if (!IsValid(npc) or !self:IsCarneableClass(npc:GetClass())) then return end

	if (npc.ixDoDeathBlocked) then
		self:WaitAndSpawnCorpse(npc)
		return
	end

	local model = string.lower(npc:GetModel() or "")

	if (model == "") then return end

	self.pendingCarneable[model] = true

	timer.Simple(2, function()
		self.pendingCarneable[model] = nil
	end)
end

function PLUGIN:OnEntityCreated(entity)
	timer.Simple(0, function()
		if (!IsValid(entity) or entity.ixCarneable or entity:GetClass() != "prop_ragdoll") then return end

		local model = string.lower(entity:GetModel() or "")

		if (self.carneableModels[model] or self.pendingCarneable[model]) then
			self:MarkCarneable(entity)
			self:ApplyDecayTimer(entity)
		end
	end)
end

function PLUGIN:GiveLoot(client, character, entity)
	local rewards = entity.ixLootTable

	if (!rewards) then return end

	local successes = entity.ixLootSuccesses or 0
	local dropPos = entity:GetPos() + Vector(0, 0, 16)
	local inventory = character:GetInventory()
	local given = {}

	for i = 1, math.min(successes, #rewards) do
		local reward = rewards[i]

		if (reward) then
			local itemTable = ix.item.list[reward]
			local itemName = itemTable and itemTable.name or reward

			if (inventory:Add(reward, 1)) then
				given[#given + 1] = itemName
			else
				ix.item.Spawn(reward, dropPos)
				client:Notify("Inventario lleno. Has soltado: " .. itemName .. ".")
			end
		end
	end

	if (#given > 0) then
		client:Notify("Has obtenido: " .. table.concat(given, ", ") .. ".")
	elseif (successes > 0) then
		client:Notify("No has conseguido nada aprovechable de este cadáver.")
	end
end

net.Receive("ixDescuartizarStart", function(length, client)
	local entity = net.ReadEntity()

	if (!IsValid(client) or !IsValid(entity)) then return end
	if (!entity.ixCarneable) then return end

	local character = client:GetCharacter()

	if (!character) then return end

	if (client:GetPos():Distance(entity:GetPos()) > PLUGIN.promptRange) then return end

	if (entity:GetNetVar("descuartizando")) then return end

	-- Guard inmediato no-networkeado: SetNetVar es asincrono, asi que varios
	-- ixDescuartizarStart casi simultaneos pasarian el filtro de arriba antes de
	-- que se propague. Esto evita Notifys duplicados (ej. el del cuchillo).
	if (entity.ixDescuartizarStartBusy and entity.ixDescuartizarStartBusy > CurTime()) then return end
	entity.ixDescuartizarStartBusy = CurTime() + 0.5

	local requiredItem = ix.config.Get("descuartizarItem", "cuchillo")

	if (!character:GetInventory():HasItem(requiredItem)) then
		client:Notify("Necesitas un cuchillo para descuartizar este cadáver.")
		return
	end

	local rounds = ix.config.Get("descuartizarRondas", 3)

	entity:SetNetVar("descuartizando", true)
	entity.ixDescuartizarUser = client
	entity.ixDescuartizarBusy = CurTime() + SUBMIT_WINDOW
	entity.ixLootTable = PLUGIN:GenerateLoot(rounds)

	net.Start("ixDescuartizarOpen")
		net.WriteEntity(entity)
		net.WriteUInt(rounds, 4)
	net.Send(client)
end)

net.Receive("ixDescuartizarSubmit", function(length, client)
	local entity = net.ReadEntity()
	local successes = net.ReadUInt(4)

	if (!IsValid(client) or !IsValid(entity)) then return end
	if (entity.ixDescuartizarUser != client) then return end
	if (!entity.ixDescuartizarBusy or entity.ixDescuartizarBusy < CurTime()) then return end

	local character = client:GetCharacter()

	if (!character) then return end

	entity.ixDescuartizarUser = nil
	entity.ixDescuartizarBusy = nil

	if (client:GetPos():Distance(entity:GetPos()) > PLUGIN.promptRange) then return end

	local rounds = ix.config.Get("descuartizarRondas", 3)
	successes = math.Clamp(successes, 0, rounds)

	if (successes <= 0) then
		entity:SetNetVar("descuartizando", nil)
		client:Notify("No has conseguido extraer nada.")
		return
	end

	entity.ixLootSuccesses = successes

	PLUGIN:GiveLoot(client, character, entity)

	entity:EmitSound("physics/flesh/flesh_bloody_break.wav", 70)
	entity:Remove()
end)
