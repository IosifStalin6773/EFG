-- ============================================================================
--  Lectura de las tablas de sh_loot_tables.lua: piscinas, filtros, pesos y
--  sorteo. Es la única parte con lógica; las tablas son solo datos.
--
--  ix.efg.loot.Roll(tableID, opts) -> {{uniqueID = "...", data = {...}}, ...}
--    opts.map        mapa (clave de LOOT.MapTables); por defecto game.GetMap()
--    opts.weighting  sustituye el de la tabla ("rarity", "price", "flat")
--    opts.filters    filtros extra (nombres de LOOT.Filters)
--    opts.rolls      número fijo de objetos (ignora table.rolls)
-- ============================================================================

local LOOT = ix.efg.loot

-- ─── Filtros ────────────────────────────────────────────────────────────────
-- Cada filtro recibe el ITEM (plantilla de ix.item.list) y devuelve true si
-- el objeto puede salir. Las tablas los nombran en "filters".
LOOT.Filters = {
	lootable = function(item)
		return !item.isBase and !item.noLoot and !item.efgNoGenLoot and !item.isDogtag
			and !item.isSecureContainer and item.category != "Misión"
	end,
	noGenericAmmo = function(item)
		-- munición genérica de HL2 (ammo_pistol, ammo_smg1...): solo la de EFT
		return !(item.isAmmo and item.ammo)
	end,
	size1x1 = function(item)
		return (item.width or 1) == 1 and (item.height or 1) == 1
	end,
	noAmmo = function(item)
		return !item.isAmmo
	end,
	noMagazines = function(item)
		return !item.isMagazine
	end,
	noBags = function(item)
		return !item.isBag
	end
}

local function passes(item, filters)
	for _, name in ipairs(filters) do
		local filter = LOOT.Filters[name]

		if (filter and !filter(item)) then
			return false
		end
	end

	return true
end

-- ─── Piscinas por categoría ─────────────────────────────────────────────────
-- Se calculan una vez (las armas, la munición y las llaves se registran en
-- InitializedPlugins) y se rehacen con ResetCache.
local cache = {}

function LOOT.ResetCache()
	cache = {}
end

-- El dinero se llamaba "bala" antes de pasar a "rublos": se acepta el nombre
-- antiguo en tablas o comandos y se traduce al que exista.
LOOT.ItemAliases = {
	bala = "rublos"
}

function LOOT.ResolveID(uniqueID)
	if (ix.item.list[uniqueID]) then return uniqueID end

	local alias = LOOT.ItemAliases[uniqueID]

	return (alias and ix.item.list[alias]) and alias or uniqueID
end

function LOOT.MoneyID()
	return LOOT.ResolveID("rublos")
end

local function normalizeEntry(entry)
	if (isstring(entry)) then
		return {id = LOOT.ResolveID(entry)}
	end

	if (istable(entry) and entry.id) then
		local resolved = LOOT.ResolveID(entry.id)

		if (resolved != entry.id) then
			entry = table.Copy(entry)
			entry.id = resolved
		end
	end

	return entry
end

local function buildPool(categoryID, extra)
	local category = LOOT.Categories[categoryID]
	if (!category) then return {} end

	local pool, seen = {}, {}
	local spec = category.pool or {}

	local function add(entry)
		entry = normalizeEntry(entry)

		if (entry and entry.id and !seen[entry.id] and ix.item.list[entry.id]) then
			seen[entry.id] = true
			pool[#pool + 1] = entry
		end
	end

	for _, entry in ipairs(spec.items or {}) do
		add(entry)
	end

	for _, entry in ipairs(extra or {}) do
		add(entry)
	end

	if (spec.flags or spec.categories) then
		local categories = {}

		for _, name in ipairs(spec.categories or {}) do
			categories[name] = true
		end

		for uniqueID, item in pairs(ix.item.list) do
			local match = categories[item.category or ""] == true

			for _, flag in ipairs(spec.flags or {}) do
				if (item[flag] == true) then
					match = true
					break
				end
			end

			if (match) then
				add({id = uniqueID})
			end
		end
	end

	-- orden estable para que dos servidores con la misma semilla den lo mismo
	table.sort(pool, function(a, b) return a.id < b.id end)

	return pool
end

function LOOT.GetPool(categoryID, map)
	local mapAdd = map and LOOT.MapTables[map] and LOOT.MapTables[map].add
	local key = categoryID .. "@" .. ((mapAdd and mapAdd[categoryID]) and map or "")

	if (!cache[key]) then
		cache[key] = buildPool(categoryID, mapAdd and mapAdd[categoryID])
	end

	return cache[key]
end

-- ─── Tabla con los cambios del mapa ─────────────────────────────────────────
function LOOT.GetTable(tableID, map)
	local base = LOOT.Tables[tableID]
	if (!base) then return end

	local override = map and LOOT.MapTables[map] and LOOT.MapTables[map][tableID]
	if (!override) then return base end

	local merged = table.Copy(base)

	if (override.categories) then
		merged.categories = table.Copy(override.categories)
		merged.base = nil
	end

	if (override.rolls) then
		merged.rolls = override.rolls
	end

	return merged
end

-- ─── Precio y pesos ─────────────────────────────────────────────────────────
-- Precio de referencia de un objeto en RUB (ITEM.price; con cantidad, por
-- unidad de la cantidad para el dinero y por caja para la munición).
function LOOT.GetPrice(uniqueID, data)
	local item = ix.item.list[uniqueID]
	if (!item) then return 0 end

	local price = tonumber(item.price) or 0

	if (uniqueID == LOOT.MoneyID() and data and data.count) then
		return data.count
	end

	if (item.efgCurrency and data and data.count) then
		return price * data.count
	end

	-- cartera: su precio más los rublos que lleva dentro
	if (item.efgWallet and data and data.count) then
		return price + data.count
	end

	return price
end

local function rarityWeight(item)
	local weights = ix.efg.rarityWeight
	local rarity = item.rarity or (ix.efg.GetRarity and ix.efg.GetRarity(item)) or "common"

	return weights and (weights[rarity] or 100) / 100 or 1
end

--- Ponderación inversa al precio (PMC de IA, Documento A).
-- peso = 1 / (1 + precio / LOOT.priceReference) ^ k
-- con k = efgLootPMCPriceWeight. Con k = 1 y referencia 10 000 RUB:
--   1 000 RUB -> 0,91 · 10 000 -> 0,5 · 100 000 -> 0,09 · 1 000 000 -> 0,01
-- Así lo barato sale a menudo y lo caro casi nunca. Con k = 0 todos pesan 1.
-- Si el objeto no tiene precio, se usa su rareza (efg_icons).
-- @param item ITEM (plantilla) o uniqueID
-- @param price precio en RUB (opcional; por defecto ITEM.price)
-- @return número > 0
function LOOT.WeightByPrice(item, price)
	if (isstring(item)) then
		item = ix.item.list[item]
	end

	if (!item) then return 0 end

	price = tonumber(price) or tonumber(item.price)

	if (!price or price <= 0) then
		return rarityWeight(item)
	end

	local k = ix.config.Get("efgLootPMCPriceWeight", 1)

	return 1 / math.pow(1 + price / LOOT.priceReference, k)
end

local function entryWeight(entry, item, weighting)
	local weight = tonumber(entry.weight)

	if (weighting == "price") then
		return (weight or 1) * LOOT.WeightByPrice(item)
	elseif (weighting == "flat") then
		return weight or 1
	end

	return weight or rarityWeight(item)
end

-- ─── Sorteo ─────────────────────────────────────────────────────────────────
local function pickWeighted(list, weightOf)
	local total = 0

	for _, value in ipairs(list) do
		total = total + weightOf(value)
	end

	if (total <= 0) then return end

	local roll = math.random() * total

	for _, value in ipairs(list) do
		local weight = weightOf(value)
		roll = roll - weight

		if (weight > 0 and roll <= 0) then
			return value
		end
	end

	return list[#list]
end

local function makeData(entry, item, category)
	local data = {}

	if (entry.count) then
		data[entry.dataKey or "count"] = math.random(entry.count[1], entry.count[2] or entry.count[1])
	end

	local stack = category and category.stack
	local max = stack and tonumber(item[stack.field])

	if (max and max > 0) then
		local low = math.max(1, math.floor(max * (stack.min or 1)))
		local high = math.max(low, math.floor(max * (stack.max or 1)))

		data[stack.key] = math.random(low, high)
	end

	return data
end

-- Objetos válidos de una categoría para una tabla (filtros aplicados)
local function candidates(categoryID, map, filters)
	local list = {}

	for _, entry in ipairs(LOOT.GetPool(categoryID, map)) do
		local item = ix.item.list[entry.id]

		if (item and passes(item, filters)) then
			list[#list + 1] = entry
		end
	end

	return list
end

function LOOT.Roll(tableID, opts)
	opts = opts or {}

	local map = opts.map or game.GetMap()
	local lootTable = LOOT.GetTable(tableID, map)
	local result = {}

	if (!lootTable) then
		ErrorNoHalt("[EFG Loot] No existe la tabla de loot " .. tostring(tableID) .. "\n")
		return result
	end

	local weighting = opts.weighting or lootTable.weighting or "rarity"
	local filters = {}

	for _, list in ipairs({LOOT.DefaultFilters, lootTable.filters or {}, opts.filters or {}}) do
		for _, name in ipairs(list) do
			filters[#filters + 1] = name
		end
	end

	-- categorías con al menos un objeto posible
	local weights = {}

	if (lootTable.base or !lootTable.categories) then
		for categoryID, category in pairs(LOOT.Categories) do
			weights[categoryID] = category.weight or 0
		end
	else
		weights = lootTable.categories
	end

	local pools, categoryList = {}, {}

	for categoryID, weight in SortedPairs(weights) do
		if (weight > 0) then
			local list = candidates(categoryID, map, filters)

			if (#list > 0) then
				pools[categoryID] = list
				categoryList[#categoryList + 1] = categoryID
			end
		end
	end

	if (#categoryList == 0) then return result end

	local rolls = lootTable.rolls or {1, 1}
	local count = opts.rolls or math.random(rolls[1], rolls[2] or rolls[1])

	for _ = 1, count do
		local categoryID = pickWeighted(categoryList, function(id) return weights[id] end)
		local list = categoryID and pools[categoryID]

		local entry = list and pickWeighted(list, function(e)
			return entryWeight(e, ix.item.list[e.id], weighting)
		end)

		if (entry) then
			local item = ix.item.list[entry.id]

			result[#result + 1] = {
				uniqueID = entry.id,
				category = categoryID,
				data = makeData(entry, item, LOOT.Categories[categoryID])
			}
		end
	end

	return result
end

-- Suma de precios de una tirada (para el valor de botín de los PMC de IA)
function LOOT.ValueOf(rolled)
	local total = 0

	for _, entry in ipairs(rolled or {}) do
		total = total + LOOT.GetPrice(entry.uniqueID, entry.data)
	end

	return total
end
