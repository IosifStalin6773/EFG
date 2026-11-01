-- ============================================================
--  traders  |  sv_plugin.lua  (SERVER)
--  Persistencia, receptores de net, comandos de admin y
--  timer de restock global.
-- ============================================================

-- Net strings
util.AddNetworkString("traders_OpenDialogue")
util.AddNetworkString("traders_DialogueAction")
util.AddNetworkString("traders_OpenTrade")
util.AddNetworkString("traders_OpenLore")
util.AddNetworkString("traders_Purchase")
util.AddNetworkString("traders_PurchaseResult")
util.AddNetworkString("traders_Sell")
util.AddNetworkString("traders_SellResult")
util.AddNetworkString("traders_AdminOpen")
util.AddNetworkString("traders_AdminSave")
util.AddNetworkString("traders_PricesOpen")
util.AddNetworkString("traders_PricesSave")
util.AddNetworkString("traders_WipePlayerStock")
util.AddNetworkString("traders_WipePlayerStockResult")

-- ============================================================
--  Persistencia
-- ============================================================

-- Genera un ID único y estable para un trader. No depende de su posición,
-- por lo que mover el trader (physgun) o recrearlo (cambio de apariencia)
-- nunca invalida las misiones que lo referencian.
function ix.traders.GenerateID()
	ix.traders.data = ix.traders.data or {}
	local id
	repeat
		id = "trader_" .. os.time() .. "_" .. math.random(1000, 9999)
	until (not ix.traders.data[id])
	return id
end

-- ============================================================
--  Preservación de datos de instancia (munición, usos, durabilidad…)
--  Conserva los datos de los ítems que un jugador vende para que
--  recomprarlos no los resetee a sus valores por defecto.
-- ============================================================

-- Claves de datos que NO deben trasladarse del vendedor al comprador
local NON_TRANSFERABLE_DATA = {
	equip = true,  -- referencia al arma equipada del vendedor
	id    = true,
}

-- Solo se preservan tipos serializables a JSON; un Entity/Vector/función en
-- data corrompería la persistencia (util.TableToJSON) del trader.
local function isSerializableData(v)
	local t = type(v)
	return t == "number" or t == "string" or t == "boolean" or t == "table"
end

-- Devuelve una copia de los datos de instancia preservables del ítem,
-- o nil si no tiene datos relevantes que conservar.
function ix.traders.SnapshotItemData(item)
	local data = item.data
	if (not data) then return nil end

	local copy = {}
	local has  = false
	for k, v in pairs(data) do
		if (not NON_TRANSFERABLE_DATA[k] and isSerializableData(v)) then
			copy[k] = istable(v) and table.Copy(v) or v
			has = true
		end
	end

	return has and copy or nil
end

-- Añade snapshots de datos a la cola FIFO del slot, sin exceder su stock
function ix.traders.PushInstances(slot, snapshots)
	if (not snapshots or #snapshots == 0) then return end
	slot.instances = slot.instances or {}
	for _, snap in ipairs(snapshots) do
		slot.instances[#slot.instances + 1] = snap
	end
	-- Nunca conservar más snapshots que unidades en stock. Si el stock se topó
	-- con un límite (slots de admin), las unidades descartadas son las últimas
	-- vendidas, así que se recorta por el final de la cola.
	while (#slot.instances > (slot.qty or 0)) do
		table.remove(slot.instances)
	end
end

-- Extrae (FIFO) el siguiente snapshot de datos del slot, o nil si no hay
function ix.traders.PopInstance(slot)
	local list = slot.instances
	if (not list or #list == 0) then return nil end
	return table.remove(list, 1)
end

-- Devuelve una descripción corta y legible del estado de una unidad concreta
-- (la próxima a comprar), p.ej. "Munición: 12" o "Usos: 3". Vacío si no aplica.
-- Un ítem puede definir ITEM:GetTraderCondition(data) para describirse a sí mismo.
function ix.traders.DescribeInstance(itemID, snapshot)
	if (not snapshot) then return "" end

	local itemTable = ix.item.list[itemID]
	if (itemTable and isfunction(itemTable.GetTraderCondition)) then
		local custom = itemTable:GetTraderCondition(snapshot)
		if (isstring(custom) and custom != "") then return custom end
	end

	local parts = {}
	if (snapshot.ammo != nil) then
		parts[#parts + 1] = "Munición: " .. tostring(snapshot.ammo)
	end
	if (snapshot.uses != nil) then
		parts[#parts + 1] = "Usos: " .. tostring(snapshot.uses)
	end

	-- Sin munición/usos reconocidos: describir la durabilidad genérica (máscara,
	-- etc.) como porcentaje si está por debajo del 100%; si no, no anunciar nada
	-- para no engañar al jugador (el ítem ya se marca como "Vendido por jugador").
	if (#parts == 0) then
		local factor = ix.traders.GetConditionFactor(itemID, snapshot)
		if (factor < 1) then
			return "Condición: " .. math.floor(factor * 100) .. "%"
		end
		return ""
	end
	return table.concat(parts, "  •  ")
end

function PLUGIN:LoadData()
	ix.traders.data = self:GetData() or {}
	ix.traders.globalPrices    = ix.data.Get("traders_prices", {})
	ix.traders.globalBuyPrices = ix.data.Get("traders_buyprices", {})
end

-- Corre después de que todos los plugins hayan cargado sus datos
-- (incluyendo "missions"), para poder migrar referencias con seguridad.
function PLUGIN:PostLoadData()
	local data = ix.traders.data or {}

	-- Migrar entradas antiguas (clave = posición redondeada, sin traderID) al
	-- formato con ID estable, y actualizar las misiones que las referencian.
	local dataDirty     = false
	local missionsDirty = false
	for oldKey, info in pairs(table.Copy(data)) do
		if (not info.traderID) then
			local x, y, z = string.match(oldKey, "(-?[%d%.]+)_(-?[%d%.]+)_(-?[%d%.]+)")
			if (x and y and z) then
				local newID = ix.traders.GenerateID()
				info.traderID = newID
				info.pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
				info.ang = info.ang or {p = 0, y = 0, r = 0}

				data[newID] = info
				data[oldKey] = nil
				dataDirty = true

				if (ix.missions and ix.missions.list) then
					for _, mission in pairs(ix.missions.list) do
						if (mission.traderKey == oldKey) then
							mission.traderKey = newID
							missionsDirty = true
						end
					end
				end
			end
		end
	end

	if (missionsDirty) then
		local mPlugin = ix.plugin and ix.plugin.Get("missions")
		if (mPlugin) then mPlugin:SaveData() end
	end

	if (dataDirty) then
		self:SaveData()
	end

	-- Spawnear traders guardados después de que los datos estén listos.
	-- Usamos timer para diferir un frame y asegurarnos de que el mapa esté completamente cargado.
	timer.Simple(1, function()
		for key, info in pairs(ix.traders.data or {}) do
			if (info.pos) then
				local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
				local ang = info.ang and Angle(info.ang.p, info.ang.y, info.ang.r) or angle_zero

				-- Evitar duplicados si ya existe un trader en esa posición
				local exists = false
				for _, e in pairs(ents.FindByClass("ix_trader")) do
					if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
						exists = true; break
					end
				end

				if (not exists) then
					local ent = ents.Create("ix_trader")
					if (IsValid(ent)) then
						ent.traderID = key
						ent:SetPos(pos)
						ent:SetAngles(ang)
						ent:Spawn()
						ent:SetupTrader(info.factionKey or "prapor")
						ent:Restock()
					end
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(ix.traders.data)
end

-- ============================================================
--  Timer global de restock
-- ============================================================

-- PLUGIN:Initialize nunca se ejecuta (el hook nativo "Initialize" se dispara antes
-- de que Helix registre los hooks de los plugins); InitializedPlugins sí corre una
-- vez todos los plugins están cargados.
--
-- Restock fijo (sin escalado progresivo): cada ciclo ("traders_restockInterval",
-- 6h por defecto) más un margen aleatorio de 0 a "traders_restockJitter" (30 min
-- por defecto), el stock de admin vuelve de golpe al máximo y se borra TODO el
-- stock vendido por jugadores (ver ENT:CycleRestock). El jitter evita que se
-- pueda calcular la hora exacta del restock y camperlo.
function PLUGIN:InitializedPlugins()
	ix.traders.restockCycleStart  = ix.traders.restockCycleStart or CurTime()
	ix.traders.restockCycleTarget = ix.traders.restockCycleTarget
		or (ix.config.Get("traders_restockInterval", 21600) + math.random(0, ix.config.Get("traders_restockJitter", 1800)))

	timer.Create("traders_GlobalRestock", ix.config.Get("traders_restockTickInterval", 60), 0, function()
		local elapsed = CurTime() - ix.traders.restockCycleStart

		if (elapsed >= ix.traders.restockCycleTarget) then
			for _, ent in pairs(ents.FindByClass("ix_trader")) do
				if (IsValid(ent)) then
					ent:CycleRestock()
				end
			end

			ix.traders.restockCycleStart  = CurTime()
			ix.traders.restockCycleTarget = ix.config.Get("traders_restockInterval", 21600)
				+ math.random(0, ix.config.Get("traders_restockJitter", 1800))
		end
	end)
end

-- Sincronizar precios globales al cliente cuando se conecta
function PLUGIN:PlayerInitialSpawn(client)
	timer.Simple(5, function()
		if (!IsValid(client)) then return end
		local sellJson = util.TableToJSON(ix.traders.globalPrices or {})
		local buyJson  = util.TableToJSON(ix.traders.globalBuyPrices or {})
		net.Start("traders_PricesOpen")
			net.WriteBool(false)
			net.WriteUInt(#sellJson, 32)
			net.WriteData(sellJson, #sellJson)
			net.WriteUInt(#buyJson, 32)
			net.WriteData(buyJson, #buyJson)
		net.Send(client)
	end)
end

-- InitializedPlugins ya no se usa para spawnear — el spawn ocurre en PostLoadData.

-- ============================================================
--  traders_DialogueAction — el cliente elige una opción del menú de diálogo
-- ============================================================

net.Receive("traders_DialogueAction", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	local action    = net.ReadString()

	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end

	-- Verificar que el jugador esté cerca del trader
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character  = client:GetCharacter()
	local factionKey = traderEnt.factionKey or "prapor"
	local traderRep  = character:GetTraderRep() or {}
	local rep        = ix.traders.GetEffectiveRep(character, factionKey)
	local repLevel   = ix.traders.GetRepLevel(rep)

	if (action == "trade") then
		local inv = traderEnt.inventory or {}
		net.Start("traders_OpenTrade")
			net.WriteEntity(traderEnt)
			net.WriteUInt(#inv, 8)
			for _, slot in ipairs(inv) do
				net.WriteString(slot.itemID)
				net.WriteUInt(math.Clamp(slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.maxQty or slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.price, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.buyPrice or 0, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.minRep or 0, 0, 1000), 10)
				net.WriteBool(slot.playerStock or false)
				-- Estado de las unidades con datos preservados (venta de jugador):
				-- nº de unidades usadas, descripción y % de condición de la próxima (FIFO)
				local instances = slot.instances or {}
				net.WriteUInt(math.Clamp(#instances, 0, 255), 8)
				net.WriteString(ix.traders.DescribeInstance(slot.itemID, instances[1]))
				local condFactor = instances[1] and ix.traders.GetConditionFactor(slot.itemID, instances[1]) or 1
				net.WriteUInt(math.Clamp(math.floor(condFactor * 100), 0, 100), 7)
			end
			net.WriteUInt(math.Clamp(character:GetMoney(), 0, 4294967295), 32)
			net.WriteUInt(rep, 10)
			net.WriteUInt(math.Clamp(traderEnt.maxSlots or 20, 0, 255), 8)
			local bwl = traderEnt.buyWhitelist or {}
			net.WriteUInt(#bwl, 8)
			for _, bwlID in ipairs(bwl) do
				net.WriteString(bwlID)
			end
		net.Send(client)

	elseif (action == "lore") then
		local loreText = traderEnt.traderCustomLore or ix.traders.lore[factionKey] or "Este comerciante no tiene nada que decir."
		net.Start("traders_OpenLore")
			net.WriteEntity(traderEnt)
			net.WriteString(loreText)
		net.Send(client)

	elseif (action == "admin") then
		if (!client:IsAdmin()) then return end
		-- Excluir playerStock: el admin no los gestiona y enviarlos causaría duplicados al guardar
		local inv = {}
		for _, slot in ipairs(traderEnt.inventory or {}) do
			if (not slot.playerStock) then table.insert(inv, slot) end
		end
		net.Start("traders_AdminOpen")
			net.WriteEntity(traderEnt)
			net.WriteUInt(#inv, 8)
			for _, slot in ipairs(inv) do
				net.WriteString(slot.itemID)
				net.WriteUInt(math.Clamp(slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.maxQty or slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.price, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.buyPrice or 0, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.minRep or 0, 0, 1000), 10)
			end
			net.WriteUInt(math.Clamp(traderEnt.maxSlots or 20, 0, 255), 8)
			net.WriteString(traderEnt.traderCustomName or "")
			net.WriteString(traderEnt.traderCustomLore or "")
			local af = traderEnt.traderAllowedFactions or {}
			net.WriteUInt(#af, 8)
			for _, fk in ipairs(af) do net.WriteString(fk) end
		local bwl2 = traderEnt.buyWhitelist or {}
		net.WriteUInt(#bwl2, 8)
		for _, bwlID in ipairs(bwl2) do net.WriteString(bwlID) end
		net.Send(client)

	end
	-- "mission" reservado para implementación futura
end)

-- ============================================================
--  traders_Purchase — el cliente compra un ítem del trader
-- ============================================================

net.Receive("traders_Purchase", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	local itemID    = net.ReadString()
	local qty       = net.ReadUInt(8)

	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character  = client:GetCharacter()
	local factionKey = traderEnt.factionKey or "prapor"
	local traderRep  = character:GetTraderRep() or {}
	local rep        = ix.traders.GetEffectiveRep(character, factionKey)
	local repLevel   = ix.traders.GetRepLevel(rep)

	-- Buscar el slot en el inventario del trader
	local targetSlot = nil
	for _, slot in ipairs(traderEnt.inventory) do
		if (slot.itemID == itemID) then
			targetSlot = slot
			break
		end
	end

	local function sendResult(success, msg)
		net.Start("traders_PurchaseResult")
			net.WriteBool(success)
			net.WriteString(msg)
		net.Send(client)
	end

	if (!targetSlot) then
		sendResult(false, "Este ítem ya no está disponible.")
		return
	end

	if (targetSlot.qty < qty) then
		sendResult(false, "No hay suficiente stock disponible.")
		return
	end

	-- Verificar rep mínima requerida
	if (rep < (targetSlot.minRep or 0)) then
		sendResult(false, "No tienes suficiente reputación para comprar este artículo.")
		return
	end

	-- Precio unitario: precio base * escasez (según qty/maxQty EN ESE MOMENTO)
	-- * descuento por reputación. La escasez se recalcula por cada unidad
	-- dentro del propio lote (ver bucle más abajo): cada compra deja menos
	-- stock, así que la siguiente unidad sale más cara. Antes se fijaba una
	-- sola vez para todo el lote, así que comprar 10 de golpe costaba lo
	-- mismo por unidad que comprar 1.
	local repDiscountMult = (1 - repLevel.discount / 100)
	local function GetUnitPriceForRemaining(remainingQty)
		local scarcityMult = ix.traders.GetStockPriceMultiplier(remainingQty, targetSlot.maxQty)
		return math.max(1, math.floor(targetSlot.price * scarcityMult * repDiscountMult))
	end

	-- Coste de la primera unidad (puede ser menor si está dañada) para validar fondos
	local firstData   = targetSlot.instances and targetSlot.instances[1]
	local firstFactor = firstData and ix.traders.GetConditionFactor(itemID, firstData) or 1
	local firstCost   = math.max(1, math.floor(GetUnitPriceForRemaining(targetSlot.qty) * firstFactor))

	if (character:GetMoney() < firstCost) then
		sendResult(false, "No tienes suficientes RUB.")
		return
	end

	-- Verificar que el ítem existe en el registro
	if (!ix.item.list[itemID]) then
		sendResult(false, "Ítem desconocido.")
		return
	end

	-- Realizar la transacción: añadir hasta qty ítems, cobrando cada unidad según
	-- su condición (las dañadas, vendidas por jugadores, salen más baratas).
	local inventory    = character:GetInventory()
	local addedCount   = 0
	local chargedPrice = 0
	local noSpace      = false
	local remainingQty = targetSlot.qty

	for i = 1, qty do
		-- Restaurar datos preservados (munición, usos, durabilidad…) de la unidad
		local unitPrice = GetUnitPriceForRemaining(remainingQty)
		local data   = ix.traders.PopInstance(targetSlot)
		local factor = data and ix.traders.GetConditionFactor(itemID, data) or 1
		local cost   = math.max(1, math.floor(unitPrice * factor))

		-- Detener si no puede pagar esta unidad (TakeMoney se aplica al final)
		if (character:GetMoney() < chargedPrice + cost) then
			if (data) then
				targetSlot.instances = targetSlot.instances or {}
				table.insert(targetSlot.instances, 1, data)
			end
			break
		end

		if (inventory:Add(itemID, 1, data)) then
			addedCount   = addedCount + 1
			chargedPrice = chargedPrice + cost
			remainingQty = remainingQty - 1
		else
			-- No cupo: devolver el snapshot al frente de la cola para no perderlo
			noSpace = true
			if (data) then
				targetSlot.instances = targetSlot.instances or {}
				table.insert(targetSlot.instances, 1, data)
			end
			break
		end
	end

	if (addedCount == 0) then
		sendResult(false, noSpace and "No hay espacio en tu inventario." or "No tienes suficientes RUB.")
		return
	end

	character:TakeMoney(chargedPrice)
	targetSlot.qty = targetSlot.qty - addedCount

	-- Si es stock de jugador y se agotó, eliminar el slot del inventario
	if (targetSlot.playerStock and targetSlot.qty <= 0) then
		for i, slot in ipairs(traderEnt.inventory) do
			if (slot == targetSlot) then
				table.remove(traderEnt.inventory, i)
				break
			end
		end
	end

	traderEnt:SaveToData()

	-- Trazabilidad: notificar al plugin trader_logs de los ítems vendidos
	hook.Run("TraderItemPurchased", client, traderEnt, itemID, addedCount, chargedPrice)

	local itemName = ix.item.list[itemID].name or itemID
	sendResult(true, "Has comprado " .. addedCount .. "x " .. itemName .. " por " .. chargedPrice .. " RUB.")
end)

-- ============================================================
--  traders_Sell — el cliente vende un ítem al trader
-- ============================================================

net.Receive("traders_Sell", function(len, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local traderEnt = net.ReadEntity()
	local itemID    = net.ReadString()
	local qty       = net.ReadUInt(8)

	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, traderEnt)) then return end

	local character = client:GetCharacter()
	local inventory = character:GetInventory()

	local function sendResult(success, msg, repGained)
		net.Start("traders_SellResult")
			net.WriteBool(success)
			net.WriteString(msg)
			net.WriteUInt(repGained or 0, 10)
		net.Send(client)
	end

	-- Verificar whitelist de compras del trader
	local bwl = traderEnt.buyWhitelist or {}
	if (#bwl == 0 or not table.HasValue(bwl, itemID)) then
		sendResult(false, "Este comerciante no compra ese artículo.", 0)
		return
	end

	-- Buscar TODAS las instancias del ítem en el inventario del jugador,
	-- sumando "Amount" para contemplar ítems apilados (recursos, rublos, etc.)
	-- Las instancias EQUIPADAS (arma, uniforme, mochila…) se excluyen: no se
	-- pueden vender puestas, hay que desequiparlas primero. Las instancias
	-- PODRIDAS (comida perecedera con ix.spoilage) también se excluyen: no
	-- son el mismo objeto que el trader compra.
	local ownedItems = {}
	local totalOwned = 0
	local hasEquipped = false
	local hasSpoiled = false
	for _, it in pairs(inventory:GetItems()) do
		if (it.uniqueID == itemID) then
			if (it:GetData("equip")) then
				hasEquipped = true
			elseif (it.isPerishable and it:GetData("spoiled", false)) then
				hasSpoiled = true
			else
				table.insert(ownedItems, it)
				totalOwned = totalOwned + it:GetData("Amount", 1)
			end
		end
	end

	if (#ownedItems == 0) then
		if (hasEquipped) then
			sendResult(false, "No puedes vender un ítem que tienes equipado. Desequípalo primero.", 0)
		elseif (hasSpoiled) then
			sendResult(false, "Ese ítem está podrido. Nadie te lo va a comprar.", 0)
		else
			sendResult(false, "No tienes ese ítem.", 0)
		end
		return
	end

	if (totalOwned < qty) then
		sendResult(false, "No tienes suficientes unidades de ese ítem.", 0)
		return
	end

	-- Buscar slot del trader (gestión de inventario Y precio de compra propio)
	local traderSlot = nil
	for _, slot in ipairs(traderEnt.inventory) do
		if (slot.itemID == itemID) then
			traderSlot = slot
			break
		end
	end

	-- Verificar que el trader tenga hueco si no tiene ese slot aún
	if (!traderSlot and #traderEnt.inventory >= traderEnt.maxSlots) then
		sendResult(false, "El trader no puede aceptar más artículos en este momento.", 0)
		return
	end

	-- Stock de admin al techo: el máximo configurado se respeta de verdad, así
	-- que si ya está lleno el trader deja de comprar ese ítem por completo (no
	-- solo "deja de contar" mientras sigue pagando por unidades que no entran).
	if (traderSlot and not traderSlot.playerStock and (traderSlot.qty or 0) >= (traderSlot.maxQty or 0)) then
		sendResult(false, "El trader ya tiene todo el stock que puede tener de ese ítem.", 0)
		return
	end

	-- Precio de compra: el propio de este trader si el admin le puso uno
	-- (economía dinámica por estación), si no, el precio de compra global.
	local baseBuyPrice = ix.traders.GetEffectiveBuyPrice(traderSlot and traderSlot.buyPrice, itemID)

	if (baseBuyPrice <= 0) then
		local minPrice = math.huge
		for _, trader in pairs(ents.FindByClass("ix_trader")) do
			if (IsValid(trader)) then
				for _, slot in ipairs(trader.inventory or {}) do
					if (slot.itemID == itemID and slot.price > 0) then
						minPrice = math.min(minPrice, slot.price)
					end
				end
			end
		end
		baseBuyPrice = (minPrice < math.huge) and math.max(1, math.floor(minPrice * 0.5)) or 1
	end
	-- Bonus de reputación: a mejor reputación, el trader paga algo más por unidad.
	local factionKey = traderEnt.factionKey or "prapor"
	local traderRep  = character:GetTraderRep() or {}
	local rep        = ix.traders.GetEffectiveRep(character, factionKey)
	local repLevel   = ix.traders.GetRepLevel(rep)
	local sellBonus  = repLevel.sellBonus or 0

	-- Sobreoferta: cuanto más stock de este ítem tenga ya el trader (respecto
	-- a su máximo histórico), menos paga por cada unidad nueva. Se calcula UNA
	-- vez con el stock ANTES de esta venta (igual que la escasez al comprar),
	-- no progresivamente unidad a unidad dentro del mismo lote.
	local oversupplyMult = traderSlot
		and ix.traders.GetSellToTraderMultiplier(traderSlot.qty, traderSlot.maxQty)
		or 1
	local unitSell = math.max(1, math.floor(baseBuyPrice * (1 + sellBonus / 100) * oversupplyMult))

	-- Remover qty unidades, reduciendo stacks parciales o eliminando instancias completas.
	-- Conservamos los datos de instancia (munición, usos, durabilidad…) de las unidades
	-- individuales para restaurarlos al recomprar; las pilas genéricas no los necesitan.
	-- El precio se calcula por unidad: las unidades con durabilidad < 100% valen menos.
	local soldInstances = {}
	local sellPrice = 0
	local remaining = qty
	for _, it in ipairs(ownedItems) do
		if (remaining <= 0) then break end
		local amount = it:GetData("Amount", 1)
		if (amount <= remaining) then
			remaining = remaining - amount
			if (amount == 1) then
				local snapshot = ix.traders.SnapshotItemData(it)
				if (snapshot) then soldInstances[#soldInstances + 1] = snapshot end
				local factor = ix.traders.GetConditionFactor(itemID, it.data)
				sellPrice = sellPrice + math.max(1, math.floor(unitSell * factor))
			else
				-- Pila genérica (recursos, rublos): sin durabilidad, precio íntegro
				sellPrice = sellPrice + unitSell * amount
			end

			-- ownedItems nunca contiene ítems equipados (se filtran arriba), así que
			-- no hace falta desequipar nada aquí.
			inventory:Remove(it:GetID())
		else
			it:SetData("Amount", amount - remaining)
			sellPrice = sellPrice + unitSell * remaining
			remaining = 0
		end
	end

	-- Añadir al inventario del trader o incrementar su stock
	if (traderSlot) then
		if (traderSlot.playerStock) then
			-- Stock de jugador: qty y maxQty crecen con cada venta (sin límite fijo)
			traderSlot.qty    = (traderSlot.qty or 0) + qty
			traderSlot.maxQty = (traderSlot.maxQty or 0) + qty
		else
			-- Stock de admin: el techo configurado se respeta siempre (si no,
			-- el trader nunca se quedaría sin ese ítem y el restock/escasez
			-- dejarían de tener sentido). Lo que exceda el máximo simplemente
			-- no entra en el stock (el jugador ya cobró por esas unidades).
			traderSlot.qty = math.min((traderSlot.qty or 0) + qty, traderSlot.maxQty or 255)
		end
	else
		local sellRef = ix.traders.GetGlobalPrice(itemID)
		if (sellRef <= 0) then sellRef = baseBuyPrice * 2 end
		traderSlot = {
			itemID      = itemID,
			qty         = qty,
			maxQty      = qty,
			price       = sellRef,
			minRep      = 0,
			playerStock = true,
		}
		table.insert(traderEnt.inventory, traderSlot)
	end

	-- Conservar los datos de instancia de las unidades vendidas para restaurarlos al recomprar
	ix.traders.PushInstances(traderSlot, soldInstances)

	-- Dar dinero y reputación al jugador (sellPrice ya incluye bonus de rep y condición)
	character:GiveMoney(sellPrice)

	local repGained  = math.min(math.floor(sellPrice * 0.1), 5)
	traderRep[factionKey] = math.Clamp((traderRep[factionKey] or 0) + repGained, 0, 1000)
	character:SetTraderRep(traderRep)

	traderEnt:SaveToData()

	local itemName = ix.item.list[itemID] and ix.item.list[itemID].name or itemID
	sendResult(true, "Has vendido " .. qty .. "x " .. itemName .. " por " .. sellPrice .. " RUB.", repGained)
end)

-- ============================================================
--  traders_SellItems — venta de objetos concretos (pantalla de EFT)
-- ============================================================
-- El cliente pone objetos en la mesa de venta y manda sus ids. Todo se valida
-- aquí: que el objeto lo lleve el personaje o esté en su alijo, que no esté
-- equipado, que el comerciante lo compre y que quepa en su stock. Si algo
-- falla no se vende nada.

util.AddNetworkString("traders_SellItems")

local MAX_SELL_ITEMS = 100

-- inventarios del personaje: bolsillos, equipo, alijo (solo en el escondite)
-- y lo que haya dentro
local function ownedInventories(character)
	local ids = {}
	local client = character:GetPlayer()
	local stashOK = ix.strongbox and IsValid(client) and ix.strongbox.CanAccess(client)
	local queue = {character:GetInventory(), ix.GetEquipInventory and ix.GetEquipInventory(character) or nil,
		stashOK and ix.strongbox.GetStash(character) or nil}

	while (#queue > 0) do
		local inv = table.remove(queue)

		if (inv and !ids[inv:GetID()]) then
			ids[inv:GetID()] = true

			for _, item in pairs(inv:GetItems(true)) do
				local bag = item:GetData("id") and ix.item.inventories[item:GetData("id")]
				if (bag) then queue[#queue + 1] = bag end
			end
		end
	end

	return ids
end

-- precio que paga el comerciante por una unidad (misma fórmula que traders_Sell)
local function unitSellPrice(character, traderEnt, itemID, traderSlot)
	local baseBuyPrice = ix.traders.GetEffectiveBuyPrice(traderSlot and traderSlot.buyPrice, itemID)

	if (baseBuyPrice <= 0) then
		local minPrice = math.huge

		for _, trader in pairs(ents.FindByClass("ix_trader")) do
			for _, slot in ipairs(IsValid(trader) and trader.inventory or {}) do
				if (slot.itemID == itemID and slot.price > 0) then minPrice = math.min(minPrice, slot.price) end
			end
		end

		baseBuyPrice = (minPrice < math.huge) and math.max(1, math.floor(minPrice * 0.5)) or 1
	end

	local rep = ix.traders.GetEffectiveRep(character, traderEnt.factionKey or "prapor")
	local sellBonus = ix.traders.GetRepLevel(rep).sellBonus or 0
	local oversupply = traderSlot and ix.traders.GetSellToTraderMultiplier(traderSlot.qty, traderSlot.maxQty) or 1

	return math.max(1, math.floor(baseBuyPrice * (1 + sellBonus / 100) * oversupply))
end

net.Receive("traders_SellItems", function(len, client)
	local traderEnt = net.ReadEntity()
	local count = math.min(net.ReadUInt(8), MAX_SELL_ITEMS)
	local ids, seen = {}, {}

	for _ = 1, count do
		local id = net.ReadUInt(32)
		if (!seen[id]) then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end

	local function sendResult(success, msg, repGained)
		net.Start("traders_SellResult")
			net.WriteBool(success)
			net.WriteString(msg)
			net.WriteUInt(repGained or 0, 10)
		net.Send(client)
	end

	if ((client.tradersSellNext or 0) > CurTime()) then return end
	client.tradersSellNext = CurTime() + 0.5

	local character = client:GetCharacter()
	if (!character or #ids == 0) then return end
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader" or !ix.traders.CanReach(client, traderEnt)) then return end

	local allowed = ownedInventories(character)
	local whitelist = traderEnt.buyWhitelist or {}
	local items, byID = {}, {}

	for _, id in ipairs(ids) do
		local item = ix.item.instances[id]

		if (!item or !allowed[item.invID or 0]) then
			sendResult(false, "Alguno de esos objetos ya no lo tienes.", 0)
			return
		end

		if (item:GetData("equip")) then
			sendResult(false, item.name .. " está equipado. Quítatelo primero.", 0)
			return
		end

		if (item.isPerishable and item:GetData("spoiled", false)) then
			sendResult(false, item.name .. " está podrido. Nadie te lo va a comprar.", 0)
			return
		end

		if (!table.HasValue(whitelist, item.uniqueID)) then
			sendResult(false, "Este comerciante no compra " .. item.name .. ".", 0)
			return
		end

		local bag = item:GetData("id") and ix.item.inventories[item:GetData("id")]
		if (bag and !table.IsEmpty(bag:GetItems())) then
			sendResult(false, "Vacía " .. item.name .. " antes de venderlo.", 0)
			return
		end

		items[#items + 1] = item
		byID[item.uniqueID] = byID[item.uniqueID] or {}
		table.insert(byID[item.uniqueID], item)
	end

	-- hueco en el stock del comerciante y precio de cada grupo
	local plan, newSlots = {}, 0

	for itemID, group in pairs(byID) do
		local traderSlot

		for _, slot in ipairs(traderEnt.inventory) do
			if (slot.itemID == itemID) then traderSlot = slot break end
		end

		if (!traderSlot) then newSlots = newSlots + 1 end

		if (traderSlot and !traderSlot.playerStock and (traderSlot.qty or 0) >= (traderSlot.maxQty or 0)) then
			sendResult(false, "El comerciante ya tiene todo el stock que puede de " .. group[1].name .. ".", 0)
			return
		end

		plan[#plan + 1] = {itemID = itemID, items = group, slot = traderSlot, unit = unitSellPrice(character, traderEnt, itemID, traderSlot)}
	end

	if (#traderEnt.inventory + newSlots > (traderEnt.maxSlots or 20)) then
		sendResult(false, "El comerciante no puede aceptar tantos objetos distintos ahora mismo.", 0)
		return
	end

	local total, units = 0, 0

	for _, entry in ipairs(plan) do
		local snapshots, qty = {}, 0

		for _, item in ipairs(entry.items) do
			local amount = item:GetData("Amount", 1)

			if (amount == 1) then
				local snapshot = ix.traders.SnapshotItemData(item)
				if (snapshot) then snapshots[#snapshots + 1] = snapshot end
				total = total + math.max(1, math.floor(entry.unit * ix.traders.GetConditionFactor(entry.itemID, item.data)))
			else
				total = total + entry.unit * amount
			end

			qty = qty + amount

			local inv = ix.item.inventories[item.invID]
			if (inv) then inv:Remove(item:GetID()) end
		end

		units = units + qty

		local slot = entry.slot

		if (slot) then
			if (slot.playerStock) then
				slot.qty = (slot.qty or 0) + qty
				slot.maxQty = (slot.maxQty or 0) + qty
			else
				slot.qty = math.min((slot.qty or 0) + qty, slot.maxQty or 255)
			end
		else
			local sellRef = ix.traders.GetGlobalPrice(entry.itemID)
			if (sellRef <= 0) then sellRef = entry.unit * 2 end

			slot = {itemID = entry.itemID, qty = qty, maxQty = qty, price = sellRef, minRep = 0, playerStock = true}
			table.insert(traderEnt.inventory, slot)
		end

		ix.traders.PushInstances(slot, snapshots)
	end

	character:GiveMoney(total)

	local factionKey = traderEnt.factionKey or "prapor"
	local traderRep = character:GetTraderRep() or {}
	local repGained = math.min(math.floor(total * 0.1), 5 * #plan)
	traderRep[factionKey] = math.Clamp((traderRep[factionKey] or 0) + repGained, 0, 1000)
	character:SetTraderRep(traderRep)

	traderEnt:SaveToData()

	sendResult(true, ("Has vendido %d objeto%s por %s RUB."):format(units, units == 1 and "" or "s", string.Comma(total)), repGained)
end)

-- ============================================================
--  traders_AdminSave — el admin guarda cambios desde el panel
-- ============================================================

net.Receive("traders_AdminSave", function(len, client)
	if (!IsValid(client)) then return end
	if (!client:IsAdmin()) then return end

	local traderEnt = net.ReadEntity()
	if (!IsValid(traderEnt) or traderEnt:GetClass() != "ix_trader") then return end

	local count    = net.ReadUInt(8)
	local newInv   = {}
	for i = 1, count do
		local id       = net.ReadString()
		local qty      = net.ReadUInt(8)
		local maxQty   = net.ReadUInt(8)
		local price    = net.ReadUInt(32)
		local buyPrice = net.ReadUInt(32)
		local minRep   = net.ReadUInt(10)
		if (ix.item.list[id]) then
			newInv[#newInv + 1] = {
				itemID = id, qty = qty, maxQty = maxQty, price = price, buyPrice = buyPrice, minRep = minRep,
			}
		end
	end
	local newMaxSlots   = net.ReadUInt(8)
	local newModel      = net.ReadString()
	local newAnim       = net.ReadString()
	local newCustomName = net.ReadString()
	local newCustomLore = net.ReadString()
	local facCount      = net.ReadUInt(8)
	local newAllowedFac = {}
	for i = 1, facCount do
		local fk = net.ReadString()
		if (fk != "") then table.insert(newAllowedFac, fk) end
	end
	local bgCount       = net.ReadUInt(8)
	local newBodygroups = {}
	for i = 1, bgCount do
		local bgID  = net.ReadUInt(8)
		local bgVal = net.ReadUInt(8)
		newBodygroups[bgID] = bgVal
	end

	local bwlCount        = net.ReadUInt(8)
	local newBuyWhitelist = {}
	for i = 1, bwlCount do
		local bwlID = net.ReadString()
		if (bwlID != "") then table.insert(newBuyWhitelist, bwlID) end
	end

	-- Preservar items de jugador (playerStock), excepto si el admin ya configuró ese itemID
	local adminItemIDs = {}
	for _, slot in ipairs(newInv) do adminItemIDs[slot.itemID] = true end

	for _, slot in ipairs(traderEnt.inventory) do
		if (slot.playerStock and not adminItemIDs[slot.itemID]) then
			table.insert(newInv, slot)
		end
	end

	traderEnt.inventory             = newInv
	traderEnt.maxSlots              = math.Clamp(newMaxSlots, 1, 100)
	traderEnt.traderCustomName      = (newCustomName != "") and newCustomName or nil
	traderEnt.traderCustomLore      = (newCustomLore != "") and newCustomLore or nil
	traderEnt.traderAllowedFactions = newAllowedFac
	traderEnt.buyWhitelist          = newBuyWhitelist

	-- Sincronizar el nombre de red con el nombre custom (o de facción como fallback)
	local updatedName = traderEnt.traderCustomName or ix.traders.names[traderEnt.factionKey] or "Comerciante"
	traderEnt:SetNetVar("traderName", updatedName)

	-- Propagar el nuevo nombre a las definiciones de misiones que referencian este trader
	local myKey = traderEnt:GetPersistKey()
	if (ix.missions and ix.missions.list) then
		local missionsDirty = false
		for _, mission in pairs(ix.missions.list) do
			if (mission.traderKey == myKey and mission.traderName != updatedName) then
				mission.traderName = updatedName
				missionsDirty = true
			end
		end
		if (missionsDirty) then
			local mPlugin = ix.plugin.Get("missions")
			if (mPlugin) then mPlugin:SaveData() end
		end
	end

	-- Aplicar apariencia si cambió. IMPORTANTE: capturar los valores viejos
	-- ANTES de escribir los nuevos en el entity, si no la comparación de abajo
	-- siempre da "sin cambios" (se compara el valor nuevo contra sí mismo).
	local oldModelField = traderEnt.traderModel or ""
	local oldAnimField  = traderEnt.traderAnim  or ""
	local newModelField = (newModel != "" and util.IsValidModel(newModel)) and newModel or oldModelField

	local appearanceChanged = (newModelField != oldModelField) or (newAnim != oldAnimField)

	-- Actualizar campos en el entity antes de guardar
	traderEnt.traderModel      = newModelField
	traderEnt.traderAnim       = newAnim
	traderEnt.traderBodygroups = newBodygroups

	-- Guardar posición, rotación, facción y traderID ANTES de eliminar
	-- (Remove dispara OnRemove que también guarda)
	local pos      = traderEnt:GetPos()
	local ang      = traderEnt:GetAngles()
	local fk       = traderEnt.factionKey
	local traderID = traderEnt:GetPersistKey()
	traderEnt:SaveToData()

	if (appearanceChanged) then
		-- Eliminar el entity viejo y crear uno nuevo para que todos los clientes
		-- vean el modelo actualizado (SetModel en SENT no siempre se propaga bien)
		traderEnt:Remove()

		timer.Simple(0.1, function()
			local newEnt = ents.Create("ix_trader")
			if (IsValid(newEnt)) then
				-- Conservar el traderID para que las misiones que lo referencian sigan siendo válidas
				newEnt.traderID = traderID
				newEnt:SetPos(pos)
				newEnt:SetAngles(ang)
				newEnt:Spawn()
				newEnt:SetupTrader(fk)
			end
		end)
	else
		traderEnt:ApplyAppearance()
	end

	client:ChatPrint("Panel de admin: cambios guardados en el trader.")
end)

-- ============================================================
--  traders_WipePlayerStock — borra el stock vendido por jugadores de
--  TODOS los traders del mapa (acción global e irreversible)
-- ============================================================

net.Receive("traders_WipePlayerStock", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local removed = 0
	for _, ent in pairs(ents.FindByClass("ix_trader")) do
		if (IsValid(ent)) then
			local before = #ent.inventory
			local i = 1
			while (i <= #ent.inventory) do
				if (ent.inventory[i].playerStock) then
					table.remove(ent.inventory, i)
				else
					i = i + 1
				end
			end
			removed = removed + (before - #ent.inventory)
			ent:SaveToData()
		end
	end

	-- Un vaciado manual equivale a cerrar el ciclo de restock: reiniciar el
	-- contador (con un nuevo margen aleatorio) para que el auto-restock no
	-- vuelva a borrar en breve.
	ix.traders.restockCycleStart  = CurTime()
	ix.traders.restockCycleTarget = ix.config.Get("traders_restockInterval", 21600)
		+ math.random(0, ix.config.Get("traders_restockJitter", 1800))

	net.Start("traders_WipePlayerStockResult")
		net.WriteUInt(math.Clamp(removed, 0, 65535), 16)
	net.Send(client)
end)

-- ============================================================
--  Comandos de administración
-- ============================================================

-- TraderSpawn <faccion> — spawnea un ix_trader delante del admin
ix.command.Add("TraderSpawn", {
	adminOnly   = true,
	arguments   = {ix.type.string},
	description = "Spawnea un trader de la facción especificada.",
	OnRun = function(self, client, factionKey)
		if (!table.HasValue(ix.traders.factions, factionKey)) then
			client:ChatPrint("Facciones válidas: " .. table.concat(ix.traders.factions, ", "))
			return
		end

		local trace = client:GetEyeTrace()
		local pos   = trace.HitPos + trace.HitNormal * 5

		local ent = ents.Create("ix_trader")
		ent:SetPos(pos)
		ent:Spawn()
		ent:SetupTrader(factionKey)

		client:ChatPrint("Trader '" .. factionKey .. "' spawneado.")
	end
})

-- TraderAdmin — abre el panel de administración del trader que el admin mira
ix.command.Add("TraderAdmin", {
	adminOnly   = true,
	description = "Abre el panel de administración del trader que estás mirando.",
	OnRun = function(self, client)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end

		local adminInv = {}
		for _, slot in ipairs(ent.inventory) do
			if (not slot.playerStock) then table.insert(adminInv, slot) end
		end
		net.Start("traders_AdminOpen")
			net.WriteEntity(ent)
			net.WriteUInt(#adminInv, 8)
			for _, slot in ipairs(adminInv) do
				net.WriteString(slot.itemID)
				net.WriteUInt(math.Clamp(slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.maxQty or slot.qty, 0, 255), 8)
				net.WriteUInt(math.Clamp(slot.price, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.buyPrice or 0, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.minRep or 0, 0, 1000), 10)
			end
			net.WriteUInt(math.Clamp(ent.maxSlots, 1, 255), 8)
			net.WriteString(ent.traderCustomName or "")
			net.WriteString(ent.traderCustomLore or "")
			local af2 = ent.traderAllowedFactions or {}
			net.WriteUInt(#af2, 8)
			for _, fk in ipairs(af2) do net.WriteString(fk) end
		local bwl3 = ent.buyWhitelist or {}
		net.WriteUInt(#bwl3, 8)
		for _, bwlID in ipairs(bwl3) do net.WriteString(bwlID) end
		net.Send(client)
	end
})

-- TraderSetPrice <itemID> <precio> — cambia el precio de un ítem en el trader mirado
ix.command.Add("TraderSetPrice", {
	adminOnly   = true,
	arguments   = {ix.type.string, ix.type.number},
	description = "Cambia el precio de un ítem en el trader que estás mirando.",
	OnRun = function(self, client, itemID, price)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end
		for _, slot in ipairs(ent.inventory) do
			if (slot.itemID == itemID) then
				slot.price = math.max(0, math.floor(price))
				ent:SaveToData()
				client:ChatPrint("Precio actualizado: " .. itemID .. " → " .. slot.price .. " RUB.")
				return
			end
		end
		client:ChatPrint("Ítem '" .. itemID .. "' no encontrado en el inventario del trader.")
	end
})

-- TraderSetSlots <n> — cambia los slots máximos del trader mirado
ix.command.Add("TraderSetSlots", {
	adminOnly   = true,
	arguments   = {ix.type.number},
	description = "Cambia los slots máximos del trader que estás mirando.",
	OnRun = function(self, client, slots)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end
		ent.maxSlots = math.Clamp(math.floor(slots), 1, 100)
		ent:SaveToData()
		client:ChatPrint("Slots máximos actualizados a " .. ent.maxSlots .. ".")
	end
})

-- TraderAddItem <itemID> <cantidad> <precio> — añade un ítem al trader mirado
ix.command.Add("TraderAddItem", {
	adminOnly   = true,
	arguments   = {ix.type.string, ix.type.number, ix.type.number},
	description = "Añade un ítem al inventario del trader que estás mirando.",
	OnRun = function(self, client, itemID, qty, price)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end
		if (!ix.item.list[itemID]) then
			client:ChatPrint("Ítem '" .. itemID .. "' no existe en el registro.")
			return
		end
		local amount = math.max(0, math.floor(qty))
		-- Actualizar slot existente si ya existe ese itemID (evitar duplicados)
		for _, slot in ipairs(ent.inventory) do
			if (slot.itemID == itemID) then
				slot.qty    = amount
				slot.maxQty = amount
				slot.price  = math.max(0, math.floor(price))
				ent:SaveToData()
				client:ChatPrint("Ítem '" .. itemID .. "' actualizado en el trader.")
				return
			end
		end
		if (#ent.inventory >= ent.maxSlots) then
			client:ChatPrint("El trader ya tiene el máximo de slots ocupados (" .. ent.maxSlots .. ").")
			return
		end
		table.insert(ent.inventory, {
			itemID = itemID,
			qty    = amount,
			maxQty = amount,
			price  = math.max(0, math.floor(price)),
			minRep = 0,
		})
		ent:SaveToData()
		client:ChatPrint("Ítem '" .. itemID .. "' añadido al trader.")
	end
})

-- TraderDelete — elimina el trader que el admin mira y borra su persistencia
ix.command.Add("TraderDelete", {
	adminOnly   = true,
	description = "Elimina el trader que estás mirando y borra todos sus datos persistidos.",
	OnRun = function(self, client)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end

		local key  = ent:GetPersistKey()
		local name = ent:GetNetVar("traderName", key)

		-- Marcar antes de Remove para que OnRemove no re-guarde los datos
		ent._deleting = true

		-- Eliminar datos persistidos
		ix.traders.data = ix.traders.data or {}
		ix.traders.data[key] = nil

		-- Eliminar la entidad (OnRemove no guardará porque _deleting=true)
		ent:Remove()

		-- Guardar tras el remove para persistir la ausencia del trader
		local plugin = ix.plugin.Get("traders")
		if (plugin) then plugin:SaveData() end

		client:ChatPrint("Trader '" .. name .. "' (" .. key .. ") eliminado permanentemente.")
	end
})

-- TraderRemoveItem <itemID> — elimina un ítem del inventario del trader mirado
ix.command.Add("TraderRemoveItem", {
	adminOnly   = true,
	arguments   = {ix.type.string},
	description = "Elimina un ítem del inventario del trader que estás mirando.",
	OnRun = function(self, client, itemID)
		local trace = client:GetEyeTrace()
		local ent   = trace.Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_trader") then
			client:ChatPrint("No estás mirando a ningún trader.")
			return
		end
		for i, slot in ipairs(ent.inventory) do
			if (slot.itemID == itemID) then
				table.remove(ent.inventory, i)
				ent:SaveToData()
				client:ChatPrint("Ítem '" .. itemID .. "' eliminado del trader.")
				return
			end
		end
		client:ChatPrint("Ítem '" .. itemID .. "' no encontrado en el inventario del trader.")
	end
})

-- ============================================================
--  TraderPrices — editor de precios globales
-- ============================================================

ix.command.Add("TraderPrices", {
	adminOnly   = true,
	description = "Abre el editor de precios globales de ítems.",
	OnRun = function(self, client)
		local sellJson = util.TableToJSON(ix.traders.globalPrices or {})
		local buyJson  = util.TableToJSON(ix.traders.globalBuyPrices or {})
		net.Start("traders_PricesOpen")
			net.WriteBool(true)
			net.WriteUInt(#sellJson, 32)
			net.WriteData(sellJson, #sellJson)
			net.WriteUInt(#buyJson, 32)
			net.WriteData(buyJson, #buyJson)
		net.Send(client)
	end
})

-- ============================================================
--  traders_PricesSave — el admin guarda los precios globales
-- ============================================================

net.Receive("traders_PricesSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local sellLen  = net.ReadUInt(32)
	local sellJson = net.ReadData(sellLen)
	local sellData = util.JSONToTable(sellJson)

	local buyLen  = net.ReadUInt(32)
	local buyJson = net.ReadData(buyLen)
	local buyData = util.JSONToTable(buyJson)

	if (!sellData or type(sellData) != "table") then
		client:ChatPrint("Error al procesar los precios de venta.")
		return
	end

	local cleanedSell = {}
	for itemID, price in pairs(sellData) do
		if (type(itemID) == "string" and ix.item.list[itemID]) then
			local n = tonumber(price)
			if (n and n > 0) then
				cleanedSell[itemID] = math.floor(n)
			end
		end
	end

	local cleanedBuy = {}
	if (buyData and type(buyData) == "table") then
		for itemID, price in pairs(buyData) do
			if (type(itemID) == "string" and ix.item.list[itemID]) then
				local n = tonumber(price)
				if (n and n > 0) then
					local sellPrice = cleanedSell[itemID] or ix.traders.GetGlobalPrice(itemID)
					local maxBuy = math.floor(sellPrice * ix.traders.MAX_BUY_RATIO)
					cleanedBuy[itemID] = math.min(math.floor(n), math.max(1, maxBuy))
				end
			end
		end
	end

	ix.traders.globalPrices    = cleanedSell
	ix.traders.globalBuyPrices = cleanedBuy
	ix.data.Set("traders_prices", cleanedSell)
	ix.data.Set("traders_buyprices", cleanedBuy)

	-- Resincronizar a todos los jugadores conectados
	local syncSellJson = util.TableToJSON(cleanedSell)
	local syncBuyJson  = util.TableToJSON(cleanedBuy)
	net.Start("traders_PricesOpen")
		net.WriteBool(false)
		net.WriteUInt(#syncSellJson, 32)
		net.WriteData(syncSellJson, #syncSellJson)
		net.WriteUInt(#syncBuyJson, 32)
		net.WriteData(syncBuyJson, #syncBuyJson)
	net.Broadcast()

	local totalItems = math.max(table.Count(cleanedSell), table.Count(cleanedBuy))
	client:ChatPrint("Precios globales guardados (" .. totalItems .. " items configurados).")
end)
