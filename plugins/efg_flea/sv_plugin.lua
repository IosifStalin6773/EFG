local PLUGIN = PLUGIN

util.AddNetworkString("ixEFGFleaState")
util.AddNetworkString("ixEFGFleaSell")
util.AddNetworkString("ixEFGFleaBuy")
util.AddNetworkString("ixEFGFleaCancel")
util.AddNetworkString("ixEFGFleaRequest")

-- Datos guardados por mapa: ofertas, pagos pendientes y objetos devueltos
-- a vendedores desconectados (se entregan al cargar el personaje).
function PLUGIN:LoadData()
	local data = self:GetData() or {}

	self.listings = data.listings or {}
	self.payouts = data.payouts or {}
	self.returns = data.returns or {}
	self.nextID = data.nextID or 1
end

function PLUGIN:SaveData()
	self:SetData({
		listings = self.listings or {},
		payouts = self.payouts or {},
		returns = self.returns or {},
		nextID = self.nextID or 1
	})
end

local function findListing(id)
	for index, listing in ipairs(PLUGIN.listings or {}) do
		if (listing.id == id) then
			return listing, index
		end
	end
end

local function countOffers(charID)
	local total = 0

	for _, listing in ipairs(PLUGIN.listings or {}) do
		if (listing.seller == charID) then
			total = total + 1
		end
	end

	return total
end

local function canUse(client)
	local character = client:GetCharacter()

	return character and !client:InRaid() and character:GetEFGLevel() >= ix.config.Get("efgFleaLevel", 15)
end

-- Dinero al vendedor: al momento si está conectado, si no al volver a entrar
local function paySeller(charID, amount, itemName)
	local character = ix.char.loaded[charID]
	local client = character and character:GetPlayer()

	if (IsValid(client) and client:GetCharacter() == character) then
		character:GiveMoney(amount)
		client:Notify(("Has vendido %s en el mercadillo por %s RUB."):format(itemName, string.Comma(amount)))
		hook.Run("EFGFleaSold", character, itemName, amount)
	else
		PLUGIN.payouts[charID] = (PLUGIN.payouts[charID] or 0) + amount
	end
end

-- Devuelve el objeto de una oferta a su vendedor (o lo deja pendiente)
local function returnListing(listing)
	local character = ix.char.loaded[listing.seller]
	local client = character and character:GetPlayer()

	if (IsValid(client) and client:GetCharacter() == character and character:GetInventory():Add(listing.itemID, 1, listing.data)) then
		client:Notify("Te han devuelto una oferta del mercadillo que no se ha vendido.")
		return
	end

	PLUGIN.returns[listing.seller] = PLUGIN.returns[listing.seller] or {}
	table.insert(PLUGIN.returns[listing.seller], {itemID = listing.itemID, data = listing.data})
end

function PLUGIN:SendListings(client)
	local character = client:GetCharacter()
	local now = os.time()
	local listings = {}

	for _, listing in ipairs(self.listings or {}) do
		local itemTable = ix.item.list[listing.itemID]

		if (itemTable) then
			listings[#listings + 1] = {
				id = listing.id,
				itemID = listing.itemID,
				name = itemTable.name,
				category = itemTable.category or "Otros",
				price = listing.price,
				sellerName = listing.sellerName,
				mine = listing.seller == character:GetID(),
				remaining = math.max(0, listing.expires - now)
			}
		end
	end

	net.Start("ixEFGFleaState")
		net.WriteTable(listings)
	net.Send(client)
end

-- la pestaña MERCADILLO del TAB pide las ofertas al abrirse
net.Receive("ixEFGFleaRequest", function(_, client)
	if ((client.ixEFGFleaNextList or 0) > CurTime()) then return end
	client.ixEFGFleaNextList = CurTime() + 0.5

	if (canUse(client)) then
		PLUGIN:SendListings(client)
	end
end)

net.Receive("ixEFGFleaSell", function(_, client)
	local itemID = net.ReadUInt(32)
	local price = math.floor(net.ReadUInt(32))

	if (!canUse(client) or (client.ixEFGFleaNext or 0) > CurTime()) then return end
	client.ixEFGFleaNext = CurTime() + 0.5

	local character = client:GetCharacter()
	local inventory = character:GetInventory()
	local item = ix.item.instances[itemID]

	if (!item or item.invID != inventory:GetID() or item:GetData("equip") or !ix.efg.flea.CanList(item)) then
		return client:Notify("No puedes vender ese objeto.")
	end

	if (price < 1 or price > 99999999) then
		return client:Notify("Precio no válido.")
	end

	if (countOffers(character:GetID()) >= ix.config.Get("efgFleaMaxOffers", 5)) then
		return client:Notify("Ya tienes el máximo de ofertas publicadas.")
	end

	local fee = ix.efg.flea.Fee(item, price)

	if (!character:HasMoney(fee)) then
		return client:Notify(("Necesitas %s RUB para pagar la comisión."):format(string.Comma(fee)))
	end

	-- los contenedores (mochilas) se venden solo vacíos
	if (item.isBag) then
		local bag = item.GetInventory and item:GetInventory()

		if (bag and table.Count(bag:GetItems()) > 0) then
			return client:Notify("Vacía la mochila antes de venderla.")
		end
	end

	local data = table.Copy(item.data or {})
	data.equip = nil
	data.id = nil -- el inventario de una mochila se crea de nuevo al comprarla

	character:TakeMoney(fee)
	item:Remove()

	table.insert(PLUGIN.listings, {
		id = PLUGIN.nextID,
		seller = character:GetID(),
		sellerName = character:GetName(),
		itemID = item.uniqueID,
		data = data,
		price = price,
		expires = os.time() + ix.config.Get("efgFleaHours", 24) * 3600
	})

	PLUGIN.nextID = PLUGIN.nextID + 1
	PLUGIN:SaveData()

	client:Notify(("Oferta publicada. Comisión: %s RUB."):format(string.Comma(fee)))
	PLUGIN:SendListings(client)
end)

net.Receive("ixEFGFleaBuy", function(_, client)
	local id = net.ReadUInt(32)

	if (!canUse(client) or (client.ixEFGFleaNext or 0) > CurTime()) then return end
	client.ixEFGFleaNext = CurTime() + 0.5

	local character = client:GetCharacter()
	local listing, index = findListing(id)

	if (!listing) then
		client:Notify("Esa oferta ya no existe.")
		return PLUGIN:SendListings(client)
	end

	if (listing.seller == character:GetID()) then
		return client:Notify("No puedes comprar tu propia oferta.")
	end

	if (!character:HasMoney(listing.price)) then
		return client:Notify("No tienes suficientes rublos.")
	end

	if (!character:GetInventory():Add(listing.itemID, 1, listing.data)) then
		return client:Notify("No tienes sitio en el inventario.")
	end

	character:TakeMoney(listing.price)
	table.remove(PLUGIN.listings, index)

	local itemTable = ix.item.list[listing.itemID]
	paySeller(listing.seller, listing.price, itemTable and itemTable.name or listing.itemID)
	PLUGIN:SaveData()

	client:Notify(("Has comprado %s por %s RUB."):format(itemTable and itemTable.name or listing.itemID, string.Comma(listing.price)))
	PLUGIN:SendListings(client)
end)

net.Receive("ixEFGFleaCancel", function(_, client)
	local id = net.ReadUInt(32)
	local character = client:GetCharacter()
	if (!character or client:InRaid()) then return end

	local listing, index = findListing(id)

	if (!listing or listing.seller != character:GetID()) then return end

	if (!character:GetInventory():Add(listing.itemID, 1, listing.data)) then
		return client:Notify("No tienes sitio en el inventario.")
	end

	table.remove(PLUGIN.listings, index)
	PLUGIN:SaveData()

	client:Notify("Oferta retirada.")
	PLUGIN:SendListings(client)
end)

-- ofertas caducadas vuelven al vendedor
local nextCheck = 0

function PLUGIN:Think()
	if (nextCheck > CurTime() or !self.listings) then return end
	nextCheck = CurTime() + 60

	local now = os.time()
	local changed = false

	for index = #self.listings, 1, -1 do
		local listing = self.listings[index]

		if (listing.expires <= now) then
			table.remove(self.listings, index)
			returnListing(listing)
			changed = true
		end
	end

	if (changed) then
		self:SaveData()
	end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	timer.Simple(2, function()
		if (!IsValid(client) or client:GetCharacter() != character or !self.payouts) then return end

		local charID = character:GetID()
		local changed = false

		if (self.payouts[charID]) then
			character:GiveMoney(self.payouts[charID])
			client:Notify(("Mientras no estabas has ganado %s RUB en el mercadillo."):format(string.Comma(self.payouts[charID])))
			self.payouts[charID] = nil
			changed = true
		end

		local pending = self.returns[charID]

		if (pending) then
			for index = #pending, 1, -1 do
				if (character:GetInventory():Add(pending[index].itemID, 1, pending[index].data)) then
					table.remove(pending, index)
					changed = true
				end
			end

			if (#pending == 0) then
				self.returns[charID] = nil
			else
				client:Notify("Tienes ofertas devueltas del mercadillo que no caben: haz sitio y vuelve a entrar.")
			end
		end

		if (changed) then
			self:SaveData()
		end
	end)
end
