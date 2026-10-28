util.AddNetworkString("ixHarvestOpen")
util.AddNetworkString("ixHarvestSubmit")

-- Ventana (en segundos) durante la cual el servidor acepta el resultado del minijuego.
local SUBMIT_WINDOW = 30

-- Spawna un recolectable con los datos dados (pos, ang, model, type).
function ix.harvest.SpawnEntity(pos, ang, model, harvestType)
	local entity = ents.Create("ix_harvestable")

	if (!IsValid(entity)) then
		return nil
	end

	entity:SetPos(pos)
	entity:SetAngles(ang)
	entity.HarvestType = harvestType
	entity:Spawn()
	entity:SetNetVar("type", harvestType)
	entity:SetModel(model)
	entity:SetSolid(SOLID_VPHYSICS)
	entity:PhysicsInit(SOLID_VPHYSICS)

	local physObj = entity:GetPhysicsObject()

	if (IsValid(physObj)) then
		physObj:Wake()
		physObj:EnableMotion(false)
	end

	return entity
end

-- Borra el prop y lo vuelve a spawnear tras `seconds` segundos.
-- Usa la posicion como clave del timer para que sea estable aunque cambie el EntIndex.
-- Los recolectables "persistent" no se borran: simplemente marcan cuando vuelven a estar listos.
function ix.harvest.SetCooldown(entity, seconds)
	if (!IsValid(entity)) then
		return
	end

	local data = ix.harvest.types[entity.HarvestType or ""]

	if (data and data.persistent) then
		entity:SetNetVar("nextHarvest", os.time() + seconds)
		return
	end

	local pos = entity:GetPos()
	local ang = entity:GetAngles()
	local model = entity:GetModel()
	local harvestType = entity.HarvestType
	local timerKey = "ixHarvest_" .. math.floor(pos.x) .. "_" .. math.floor(pos.y) .. "_" .. math.floor(pos.z)

	ix.harvest.pending[timerKey] = {pos, ang, model, harvestType}
	entity:Remove()

	timer.Create(timerKey, seconds, 1, function()
		ix.harvest.pending[timerKey] = nil
		ix.harvest.SpawnEntity(pos, ang, model, harvestType)
	end)
end

-- Inicia el minijuego para un jugador sobre un recolectable concreto.
function ix.harvest.Start(client, entity)
	if (!IsValid(client) or !IsValid(entity)) then
		return
	end

	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local data = ix.harvest.types[entity.HarvestType or ""]

	if (!data) then
		return
	end

	if (data.persistent and entity:GetNetVar("nextHarvest", 0) > os.time()) then
		client:NotifyLocalized("harvestNotReady")
		return
	end

	if (data.requiredItem and !character:GetInventory():HasItem(data.requiredItem)) then
		local toolItem = ix.item.list[data.requiredItem]

		client:NotifyLocalized("harvestMissingTool", toolItem and string.lower(toolItem.name) or data.requiredItem)
		return
	end

	-- Otro jugador esta usando este recolectable en este momento.
	if (entity.harvestBusy and entity.harvestBusy > CurTime()
	and IsValid(entity.harvestUser) and entity.harvestUser != client) then
		client:NotifyLocalized("harvestBusy")
		return
	end

	entity.harvestUser = client
	entity.harvestBusy = CurTime() + SUBMIT_WINDOW

	net.Start("ixHarvestOpen")
		net.WriteEntity(entity)
		net.WriteString(entity.HarvestType)
	net.Send(client)
end

net.Receive("ixHarvestSubmit", function(length, client)
	local entity = net.ReadEntity()
	local successes = net.ReadUInt(4)

	if (!IsValid(client) or !IsValid(entity)) then
		return
	end

	local data = ix.harvest.types[entity.HarvestType or ""]

	if (!data) then
		return
	end

	local character = client:GetCharacter()

	if (!character) then
		return
	end

	-- El resultado solo lo acepta el jugador que abrio el minijuego, una unica vez.
	if (entity.harvestUser != client or !entity.harvestBusy or entity.harvestBusy < CurTime()) then
		return
	end

	entity.harvestUser = nil
	entity.harvestBusy = nil

	-- El jugador debe seguir cerca.
	if (client:GetPos():Distance(entity:GetPos()) > ix.harvest.range) then
		return
	end

	successes = math.Clamp(successes, 0, data.rounds)

	if (successes <= 0) then
		ix.harvest.SetCooldown(entity, data.failCooldown)
		client:NotifyLocalized("harvestFailed")
		return
	end

	local inventory = character:GetInventory()
	local given = 0
	local amount = data.amountPerSuccess or 1

	for i = 1, successes do
		if (inventory:Add(data.item, amount)) then
			given = given + amount
		else
			break
		end
	end

	ix.harvest.SetCooldown(entity, math.random(data.cooldownMin, data.cooldownMax))

	if (given > 0) then
		local itemTable = ix.item.list[data.item]

		client:EmitSound(data.giveSound)
		client:NotifyLocalized("harvestSuccess", given, string.lower(itemTable and itemTable.name or data.label))
	else
		client:NotifyLocalized("harvestInventoryFull")
	end
end)

-- Coloca un recolectable a partir del trace del administrador.
function ix.harvest.SpawnFromTrace(client, harvestType, model)
	local data = ix.harvest.types[harvestType]

	if (!data) then
		return
	end

	if (model and model != "" and !util.IsValidModel(model)) then
		client:ChatPrint("'"..model.."' no es un modelo valido.")
		return
	end

	local trace = {}
		trace.start = client:GetShootPos()
		trace.endpos = trace.start + client:GetAimVector() * 96
		trace.filter = client
	trace = util.TraceLine(trace)

	local pos = trace.HitPos + trace.HitNormal * 5
	local ang = Angle(0, client:EyeAngles().y + 180, 0)
	local mdl = (model and model != "") and model or data.defaultModel

	local entity = ix.harvest.SpawnEntity(pos, ang, mdl, harvestType)

	if (IsValid(entity)) then
		client:ChatPrint("Recolectable '"..data.label.."' colocado.")
	end
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	local data = {}

	for _, entity in ipairs(ents.FindByClass("ix_harvestable")) do
		if (!ix.harvest.types[entity.HarvestType or ""]) then
			continue
		end

		data[#data + 1] = {
			entity:GetPos(),
			entity:GetAngles(),
			entity:GetModel(),
			entity.HarvestType
		}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData({})

	if (!data) then
		return
	end

	for _, v in ipairs(data) do
		if (!ix.harvest.types[v[4] or ""]) then
			continue
		end

		ix.harvest.SpawnEntity(v[1], v[2], v[3], v[4])
	end
end
