local PLUGIN = PLUGIN

util.AddNetworkString(PLUGIN.netOpen)
util.AddNetworkString(PLUGIN.netCreate)
util.AddNetworkString(PLUGIN.netCancel)
util.AddNetworkString(PLUGIN.netFulfill)
util.AddNetworkString(PLUGIN.netPickup)
util.AddNetworkString(PLUGIN.netClose)

ix.encargos.orders = ix.encargos.orders or {}
ix.encargos.pickups = ix.encargos.pickups or {}
ix.encargos.tablones = ix.encargos.tablones or {}

local nextID = 1

-- ════════════════════════════════════════════════════════════════════
--  PERSISTENCIA
-- ════════════════════════════════════════════════════════════════════

function PLUGIN:LoadData()
	local saved = self:GetData() or {}
	ix.encargos.orders = saved.orders or {}
	ix.encargos.pickups = saved.pickups or {}
	ix.encargos.tablones = saved.tablones or {}

	for _, order in pairs(ix.encargos.orders) do
		if (order.id >= nextID) then
			nextID = order.id + 1
		end
	end

	-- Restaurar tablones
	timer.Simple(1, function()
		for _, info in ipairs(ix.encargos.tablones) do
			local pos = Vector(info.px, info.py, info.pz)

			local exists = false
			for _, e in pairs(ents.FindByClass("metro_tablon_encargos")) do
				if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
					exists = true
					break
				end
			end

			if (not exists) then
				local ent = ents.Create("metro_tablon_encargos")
				if (IsValid(ent)) then
					if (info.model and info.model != "") then
						ent.tablonModel = info.model
					end

					ent:SetPos(pos)
					ent:SetAngles(Angle(0, info.ay or 0, 0))
					ent:Spawn()
					ent:Activate()
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData({
		orders = ix.encargos.orders,
		pickups = ix.encargos.pickups,
		tablones = ix.encargos.tablones,
	})
end

function ix.encargos.SaveTablones()
	ix.encargos.tablones = {}

	for _, ent in pairs(ents.FindByClass("metro_tablon_encargos")) do
		if (IsValid(ent)) then
			local pos = ent:GetPos()
			local ang = ent:GetAngles()
			table.insert(ix.encargos.tablones, {
				px = pos.x, py = pos.y, pz = pos.z,
				ay = ang.yaw,
				model = ent:GetModel(),
			})
		end
	end

	local plugin = ix.plugin.Get("tablon_encargos")
	if (plugin) then
		plugin:SaveData()
	end
end

function ix.encargos.RemoveTablon(ent)
	if (not IsValid(ent)) then return end

	local pos = ent:GetPos()
	for i = #ix.encargos.tablones, 1, -1 do
		local info = ix.encargos.tablones[i]
		if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
			table.remove(ix.encargos.tablones, i)
		end
	end

	local plugin = ix.plugin.Get("tablon_encargos")
	if (plugin) then
		plugin:SaveData()
	end
end

-- ════════════════════════════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════════════════════════════

local function CountPlayerOrders(steamID)
	local count = 0
	for _, order in ipairs(ix.encargos.orders) do
		if (order.posterSteamID == steamID) then
			count = count + 1
		end
	end
	return count
end

local function SendOrdersToClient(client)
	local steamID = client:SteamID64()
	local orders = ix.encargos.orders
	local pickups = ix.encargos.pickups[steamID] or {}

	net.Start(PLUGIN.netOpen)
		net.WriteUInt(#orders, 16)
		for _, order in ipairs(orders) do
			net.WriteUInt(order.id, 32)
			net.WriteString(order.itemID)
			net.WriteString(order.itemName)
			net.WriteUInt(order.quantity, 16)
			net.WriteUInt(order.reward, 32)
			net.WriteString(order.posterName)
			net.WriteString(order.posterSteamID)
		end

		net.WriteUInt(#pickups, 8)
		for _, pickup in ipairs(pickups) do
			net.WriteString(pickup.type)
			if (pickup.type == "item") then
				net.WriteString(pickup.itemID)
				net.WriteString(pickup.itemName)
				net.WriteUInt(pickup.quantity, 16)
			elseif (pickup.type == "payment") then
				net.WriteUInt(pickup.amount, 32)
				net.WriteString(pickup.reason)
			end
		end
	net.Send(client)
end

-- ════════════════════════════════════════════════════════════════════
--  CREAR ENCARGO (jugador pide ítems, paga RUB como escrow)
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netCreate, function(_, client)
	local itemID = net.ReadString()
	local quantity = net.ReadUInt(16)
	local reward = net.ReadUInt(32)

	if (not itemID or itemID == "") then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = ix.encargos.config

	quantity = math.max(math.floor(quantity), 1)
	reward = math.Clamp(math.floor(reward), cfg.minReward, cfg.maxReward)

	-- Validar que el ítem existe
	local itemTable = ix.item.list[itemID]
	if (not itemTable) then
		client:Notify("Ítem no válido.")
		return
	end

	-- Validar límite de encargos activos
	local steamID = client:SteamID64()
	if (CountPlayerOrders(steamID) >= cfg.maxOrdersPerPlayer) then
		client:Notify(("Solo puedes tener %i encargos activos."):format(cfg.maxOrdersPerPlayer))
		return
	end

	-- La tasa del tablón la paga quien publica el encargo (10% de la recompensa),
	-- por encima de la recompensa que recibirá íntegra quien lo cumpla.
	local tax = math.floor(reward * cfg.taxRate)
	local totalCost = reward + tax

	-- Cobrar RUB como escrow (recompensa + tasa)
	local money = char:GetMoney()
	if (money < totalCost) then
		client:Notify(("No tienes suficientes RUB. Necesitas %i (%i de recompensa + %i de tasa), tienes %i."):format(totalCost, reward, tax, money))
		return
	end

	char:TakeMoney(totalCost)

	-- La tasa del tablón va a las arcas de Hanza en vez de destruirse
	if (ix.arcas and ix.arcas.Deposit) then
		ix.arcas.Deposit(tax)
	end

	local order = {
		id = nextID,
		posterSteamID = steamID,
		posterName = char:GetName(),
		itemID = itemID,
		itemName = itemTable.name or itemID,
		quantity = quantity,
		reward = reward,
		tax = tax,
		totalCost = totalCost,
		createdAt = os.time(),
	}

	nextID = nextID + 1
	table.insert(ix.encargos.orders, order)

	local plugin = ix.plugin.Get("tablon_encargos")
	if (plugin) then plugin:SaveData() end

	client:Notify(("Encargo publicado: %ix %s. Pagaste %i RUB (%i de recompensa + %i de tasa)."):format(quantity, order.itemName, totalCost, reward, tax))
	ix.encargos.BroadcastToNearbyPlayers()
end)

-- ════════════════════════════════════════════════════════════════════
--  CANCELAR ENCARGO (devuelve RUB al que encargó)
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netCancel, function(_, client)
	local orderID = net.ReadUInt(32)

	local char = client:GetCharacter()
	if (not char) then return end

	local steamID = client:SteamID64()

	for i, order in ipairs(ix.encargos.orders) do
		if (order.id == orderID and order.posterSteamID == steamID) then
			-- order.totalCost incluye la tasa; los encargos antiguos (previos a la
			-- tasa a cargo del publicador) solo tenían "reward" como escrow.
			local refund = order.totalCost or order.reward
			char:GiveMoney(refund)

			-- La tasa ya se había depositado en las arcas de Hanza al crear el
			-- encargo (ver netCreate): hay que retirarla de ahí o el refund
			-- duplicaría esas RUB (creadas de la nada).
			if (order.tax and order.tax > 0 and ix.arcas) then
				ix.arcas.hanza = math.max(0, (ix.arcas.hanza or 0) - order.tax)
				local arcasPlugin = ix.plugin.Get("arcas_hanza")
				if (arcasPlugin) then arcasPlugin:SaveData() end
			end

			table.remove(ix.encargos.orders, i)

			local plugin = ix.plugin.Get("tablon_encargos")
			if (plugin) then plugin:SaveData() end

			client:Notify(("Encargo cancelado. Se te devolvieron %i RUB."):format(refund))
			ix.encargos.BroadcastToNearbyPlayers()
			return
		end
	end

	client:Notify("No se encontró ese encargo.")
end)

-- ════════════════════════════════════════════════════════════════════
--  CUMPLIR ENCARGO (artesano entrega ítems, cobra RUB)
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netFulfill, function(_, client)
	local orderID = net.ReadUInt(32)

	local char = client:GetCharacter()
	if (not char) then return end

	local steamID = client:SteamID64()
	local inventory = char:GetInventory()
	if (not inventory) then return end

	for i, order in ipairs(ix.encargos.orders) do
		if (order.id == orderID) then
			if (order.posterSteamID == steamID) then
				client:Notify("No puedes cumplir tu propio encargo.")
				return
			end

			-- Verificar que tiene los ítems
			local count = 0
			for _, item in pairs(inventory:GetItems()) do
				if (item.uniqueID == order.itemID) then
					count = count + item:GetData("Amount", 1)
				end
			end

			if (count < order.quantity) then
				client:Notify(("Necesitas %i unidades de %s. Tienes %i."):format(order.quantity, order.itemName, count))
				return
			end

			-- Retirar ítems del artesano
			local remaining = order.quantity
			for _, item in pairs(inventory:GetItems()) do
				if (item.uniqueID == order.itemID and remaining > 0) then
					local stackAmt = item:GetData("Amount", 1)
					if (stackAmt <= remaining) then
						remaining = remaining - stackAmt
						item:Remove()
					else
						item:SetData("Amount", stackAmt - remaining)
						remaining = 0
					end
				end
				if (remaining <= 0) then break end
			end

			-- Pagar al artesano la recompensa íntegra: la tasa ya la pagó quien
			-- publicó el encargo al crearlo (ver netCreate).
			local payment = order.reward
			char:GiveMoney(payment)

			-- Entregar ítems al que encargó
			local poster = player.GetBySteamID64(order.posterSteamID)
			if (IsValid(poster) and poster:GetCharacter()) then
				local posterInv = poster:GetCharacter():GetInventory()
				for _ = 1, order.quantity do
					if (not posterInv or not posterInv:Add(order.itemID)) then
						ix.item.Spawn(order.itemID, poster)
					end
				end
				poster:Notify(("Tu encargo de %ix %s ha sido completado."):format(order.quantity, order.itemName))
			else
				-- Offline: guardar para recogida
				ix.encargos.pickups[order.posterSteamID] = ix.encargos.pickups[order.posterSteamID] or {}
				table.insert(ix.encargos.pickups[order.posterSteamID], {
					type = "item",
					itemID = order.itemID,
					itemName = order.itemName,
					quantity = order.quantity,
				})
			end

			table.remove(ix.encargos.orders, i)

			local plugin = ix.plugin.Get("tablon_encargos")
			if (plugin) then plugin:SaveData() end

			client:Notify(("Encargo completado. Recibiste %i RUB."):format(payment))

			ix.encargos.BroadcastToNearbyPlayers()
			return
		end
	end

	client:Notify("Ese encargo ya no está disponible.")
end)

-- ════════════════════════════════════════════════════════════════════
--  RECOGER ENTREGAS PENDIENTES
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netPickup, function(_, client)
	local char = client:GetCharacter()
	if (not char) then return end

	local steamID = client:SteamID64()
	local pickups = ix.encargos.pickups[steamID]
	if (not pickups or #pickups == 0) then
		client:Notify("No tienes nada que recoger.")
		return
	end

	local inventory = char:GetInventory()

	for _, pickup in ipairs(pickups) do
		if (pickup.type == "payment") then
			char:GiveMoney(pickup.amount)
			client:Notify(("Recogiste %i RUB: %s"):format(pickup.amount, pickup.reason))
		elseif (pickup.type == "item") then
			for _ = 1, pickup.quantity do
				if (not inventory or not inventory:Add(pickup.itemID)) then
					ix.item.Spawn(pickup.itemID, client)
				end
			end
			client:Notify(("Recogiste %ix %s."):format(pickup.quantity, pickup.itemName))
		end
	end

	ix.encargos.pickups[steamID] = nil

	local plugin = ix.plugin.Get("tablon_encargos")
	if (plugin) then plugin:SaveData() end

	SendOrdersToClient(client)
end)

-- ════════════════════════════════════════════════════════════════════
--  BROADCAST / HOOKS
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netClose, function(_, client)
	client.ixEncargosOpen = false
end)

function ix.encargos.BroadcastToNearbyPlayers()
	for _, ent in pairs(ents.FindByClass("metro_tablon_encargos")) do
		if (not IsValid(ent)) then continue end

		for _, ply in ipairs(player.GetAll()) do
			if (IsValid(ply) and ply:GetPos():DistToSqr(ent:GetPos()) < 500 * 500) then
				if (ply.ixEncargosOpen) then
					SendOrdersToClient(ply)
				end
			end
		end
	end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	local steamID = client:SteamID64()
	local pickups = ix.encargos.pickups[steamID]

	if (pickups and #pickups > 0) then
		timer.Simple(5, function()
			if (IsValid(client)) then
				client:Notify(("Tienes %i entregas pendientes en el Tablón de Encargos."):format(#pickups))
			end
		end)
	end
end

function PLUGIN:PlayerDisconnected(client)
	client.ixEncargosOpen = nil
end
