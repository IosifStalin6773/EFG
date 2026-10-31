-- Mercado simulado del mercadillo. Cada objeto del catálogo tiene un índice de
-- mercado (persistente, PLUGIN.simIndex) y unas pocas ofertas de vendedores
-- simulados (en memoria). Cada efgFleaSimInterval segundos el índice se mueve
-- y vuelve poco a poco a 1, se reponen las ofertas y los compradores simulados
-- se llevan ofertas de jugadores según lo baratas que estén.
local PLUGIN = PLUGIN

local SIM = {}
PLUGIN.sim = SIM

-- las filas simuladas usan ids altos para no chocar con las ofertas reales
local SIM_BASE = 2000000000
local INDEX_MIN, INDEX_MAX = 0.7, 1.6

SIM.catalog = {}  -- [n] = uniqueID
SIM.byID = {}     -- [uniqueID] = n
SIM.offers = {}   -- [uniqueID] = {{price, seller, expires}, ...} ordenadas por precio

local NAMES = {"Dimon", "Sanya", "Vovan", "Kostya", "Lyokha", "Tolik", "Zhenya", "Grisha", "Pasha", "Misha", "Borya", "Stas",
	"Yura", "Fedya", "Arkasha", "Senya", "Petro", "Kolyan", "Gena", "Vitek"}
local TAGS = {"_ak", "_vdv", "_rus", "_pro", "_77", "_99", "_tula", "_omsk", "_spb", "_nn", "_krd", "_ural"}

local function sellerName()
	return NAMES[math.random(#NAMES)] .. TAGS[math.random(#TAGS)] .. (math.random() < 0.5 and tostring(math.random(10, 99)) or "")
end

function SIM.Reference(uniqueID)
	local price = ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(uniqueID)

	if (!price or price <= 0) then
		local item = ix.item.list[uniqueID]
		price = item and tonumber(item.price) or 0
	end

	return price
end

function SIM.Index(uniqueID)
	PLUGIN.simIndex = PLUGIN.simIndex or {}
	return PLUGIN.simIndex[uniqueID] or 1
end

function SIM.Nudge(uniqueID, delta)
	if (!SIM.byID[uniqueID]) then return end

	PLUGIN.simIndex = PLUGIN.simIndex or {}
	PLUGIN.simIndex[uniqueID] = math.Clamp(SIM.Index(uniqueID) + delta, INDEX_MIN, INDEX_MAX)
end

function SIM.MarketPrice(uniqueID)
	return math.max(1, math.Round(SIM.Reference(uniqueID) * SIM.Index(uniqueID)))
end

function SIM.IsSimID(id)
	return id > SIM_BASE
end

function SIM.BuildCatalog()
	SIM.catalog, SIM.byID = {}, {}

	for uniqueID, item in SortedPairs(ix.item.list) do
		if (ix.efg.flea.CanSimulate(item) and SIM.Reference(uniqueID) > 0) then
			SIM.catalog[#SIM.catalog + 1] = uniqueID
			SIM.byID[uniqueID] = #SIM.catalog
		end
	end
end

local function sortOffers(list)
	table.sort(list, function(a, b) return a.price < b.price end)
end

-- quita las caducadas y repone hasta un número al azar entre el mínimo y el máximo
local function refill(uniqueID, now)
	local list = SIM.offers[uniqueID] or {}

	for i = #list, 1, -1 do
		if (list[i].expires <= now) then table.remove(list, i) end
	end

	local low = ix.config.Get("efgFleaSimOffersMin", 3)
	local high = math.max(low, ix.config.Get("efgFleaSimOffersMax", 8))
	local target = math.random(low, high)
	local market = SIM.MarketPrice(uniqueID)

	while (#list < target) do
		list[#list + 1] = {
			price = math.max(1, math.Round(market * math.Rand(0.9, 1.2))),
			seller = sellerName(),
			expires = now + math.random(3600, 12 * 3600)
		}
	end

	sortOffers(list)
	SIM.offers[uniqueID] = list
end

-- compradores simulados: más probable cuanto más barata frente al mercado
local function simBuyers()
	local chance = ix.config.Get("efgFleaSimSellChance", 25) / 100
	local changed = false

	for index = #(PLUGIN.listings or {}), 1, -1 do
		local listing = PLUGIN.listings[index]
		local market = SIM.byID[listing.itemID] and SIM.MarketPrice(listing.itemID)

		if (market) then
			local ratio = listing.price / market
			local p = chance * math.Clamp(2 - ratio, 0, 2)

			if (math.random() < p) then
				table.remove(PLUGIN.listings, index)

				local itemTable = ix.item.list[listing.itemID]
				PLUGIN.PaySeller(listing.seller, listing.price, itemTable and itemTable.name or listing.itemID)
				SIM.Nudge(listing.itemID, 0.02)
				changed = true
			end
		end
	end

	return changed
end

function SIM.Tick()
	local now = os.time()

	for _, uniqueID in ipairs(SIM.catalog) do
		local index = SIM.Index(uniqueID)

		-- paseo aleatorio que vuelve poco a poco a 1
		index = index + (1 - index) * 0.1 + math.Rand(-0.04, 0.04)
		PLUGIN.simIndex[uniqueID] = math.Clamp(index, INDEX_MIN, INDEX_MAX)

		refill(uniqueID, now)
	end

	simBuyers()
	PLUGIN:SaveData()

	-- refrescar a quien ha mirado el mercadillo hace poco
	for _, client in player.Iterator() do
		if ((client.ixEFGFleaWatched or -1000) + 600 > CurTime() and PLUGIN.CanUse(client)) then
			PLUGIN:SendListings(client, "ixEFGFleaUpdate")
		end
	end
end

-- una fila por objeto: la oferta más barata y cuántas hay
function SIM.AppendRows(listings)
	if (!ix.config.Get("efgFleaSim", true)) then return end

	local now = os.time()

	for n, uniqueID in ipairs(SIM.catalog) do
		local list = SIM.offers[uniqueID]
		local best = list and list[1]
		local itemTable = ix.item.list[uniqueID]

		if (best and itemTable) then
			listings[#listings + 1] = {
				id = SIM_BASE + n,
				itemID = uniqueID,
				name = itemTable.name,
				category = itemTable.category or "Otros",
				price = best.price,
				sellerName = #list > 1 and ("%s · %d ofertas"):format(best.seller, #list) or best.seller,
				mine = false,
				remaining = math.max(0, best.expires - now)
			}
		end
	end
end

function SIM.Buy(client, id)
	local character = client:GetCharacter()
	local uniqueID = SIM.catalog[id - SIM_BASE]
	local list = uniqueID and SIM.offers[uniqueID]
	local offer = list and list[1]

	if (!ix.config.Get("efgFleaSim", true) or !offer or offer.expires <= os.time()) then
		client:Notify("Esa oferta ya no existe.")
		return PLUGIN:SendListings(client)
	end

	if (!character:HasMoney(offer.price)) then
		return client:Notify("No tienes suficientes rublos.")
	end

	if (!character:GetInventory():Add(uniqueID, 1)) then
		return client:Notify("No tienes sitio en el inventario.")
	end

	character:TakeMoney(offer.price)
	table.remove(list, 1)
	SIM.Nudge(uniqueID, 0.02)

	local itemTable = ix.item.list[uniqueID]
	client:Notify(("Has comprado %s por %s RUB."):format(itemTable and itemTable.name or uniqueID, string.Comma(offer.price)))
	PLUGIN:SendListings(client)
end

function PLUGIN:InitializedPlugins()
	SIM.BuildCatalog()

	local now = os.time()
	PLUGIN.simIndex = PLUGIN.simIndex or {}

	for _, uniqueID in ipairs(SIM.catalog) do
		refill(uniqueID, now)
	end
end

timer.Create("efgFleaSim", 30, 0, function()
	if (!ix.config.Get("efgFleaSim", true) or #SIM.catalog == 0) then return end
	if ((SIM.nextTick or 0) > CurTime()) then return end

	SIM.nextTick = CurTime() + ix.config.Get("efgFleaSimInterval", 120)
	SIM.Tick()
end)
