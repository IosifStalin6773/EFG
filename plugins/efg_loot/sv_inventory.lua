-- ============================================================================
--  Inventarios de loot (servidor): crear, rellenar con una tirada, borrar y
--  registrar en el log.
--
--  Un inventario de loot es un ix.inventory con noSave (no se guarda como
--  inventario de personaje). Sus objetos sí tienen fila en ix_items, porque
--  Helix la necesita para poder transferirlos al jugador; su inventory_id es
--  el ID del inventario de loot (>= 3 000 000 000), así que lo que nadie coge
--  se borra al quitar el contenedor o el cadáver y, si el servidor se cae,
--  al volver a arrancar (PurgeOrphans).
-- ============================================================================

local LOOT = ix.efg.loot

LOOT.INV_BASE = 3500000000
local invCounter = 0

-- IDs por encima de los de la BD y de los de persistent_corpses (3 000 000 000)
function LOOT.NextInventoryID()
	invCounter = invCounter + 1
	return LOOT.INV_BASE + invCounter
end

function LOOT.NewInventory(w, h)
	local inventory = ix.inventory.Create(w, h, LOOT.NextInventoryID())
	inventory.noSave = true
	inventory.vars = inventory.vars or {}
	inventory.vars.efgLoot = true

	return inventory
end

-- Crea un objeto en una casilla libre del inventario y llama a callback(item)
-- cuando existe (la inserción en la BD es asíncrona).
function LOOT.AddItem(inventory, uniqueID, data, callback)
	local stock = ix.item.list[uniqueID]
	if (!stock or !inventory) then return false end

	local x, y = inventory:FindEmptySlot(stock.width or 1, stock.height or 1, true)
	if (!x or !y) then return false end

	for dx = 0, (stock.width or 1) - 1 do
		for dy = 0, (stock.height or 1) - 1 do
			inventory.slots[x + dx] = inventory.slots[x + dx] or {}
			inventory.slots[x + dx][y + dy] = true
		end
	end

	ix.item.Instance(inventory:GetID(), uniqueID, data or {}, x, y, function(item)
		-- el inventario se pudo borrar mientras tanto
		if (ix.item.inventories[inventory:GetID()] != inventory) then
			local query = mysql:Delete("ix_items")
				query:Where("item_id", item.id)
			query:Execute()

			ix.item.instances[item.id] = nil
			return
		end

		item.gridX, item.gridY = x, y

		for dx = 0, item.width - 1 do
			for dy = 0, item.height - 1 do
				inventory.slots[x + dx] = inventory.slots[x + dx] or {}
				inventory.slots[x + dx][y + dy] = item
			end
		end

		inventory:SendSlot(x, y, item)
		hook.Run("InventoryItemAdded", nil, inventory, item)

		if (callback) then
			callback(item)
		end
	end)

	return true
end

-- Rellena un inventario con una tirada de ix.efg.loot.Roll. Devuelve cuántos
-- objetos han cabido.
function LOOT.Fill(inventory, rolled)
	local added = 0

	for _, entry in ipairs(rolled or {}) do
		if (LOOT.AddItem(inventory, entry.uniqueID, entry.data)) then
			added = added + 1
		end
	end

	return added
end

-- Llama a callback(inventario) cuando el inventario propio de una mochila o
-- un chaleco táctico recién creado está listo (lo crean en OnInstanced).
function LOOT.WhenContainerReady(item, callback, tries)
	tries = tries or 0

	local id = item:GetData("id")
	local inventory = id and ix.item.inventories[id]

	if (inventory) then
		callback(inventory)
	elseif (tries < 40 and ix.item.instances[item.id]) then
		timer.Simple(0.25, function()
			LOOT.WhenContainerReady(item, callback, tries + 1)
		end)
	end
end

-- Borra un inventario de loot con todo lo que tenga dentro (también el
-- contenido de mochilas y chalecos tácticos).
function LOOT.DestroyInventory(inventory)
	if (!inventory) then return end

	if (inventory.storageInfo) then
		ix.storage.Close(inventory)
	end

	local seen = {}

	for _, column in pairs(inventory.slots or {}) do
		for _, item in pairs(column) do
			if (istable(item) and item.id and !seen[item.id]) then
				seen[item.id] = true

				local bagID = item:GetData("id")

				if (bagID and ix.item.inventories[bagID]) then
					LOOT.DestroyInventory(ix.item.inventories[bagID])

					local query = mysql:Delete("ix_inventories")
						query:Where("inventory_id", bagID)
					query:Execute()
				end

				local query = mysql:Delete("ix_items")
					query:Where("item_id", item.id)
				query:Execute()

				ix.item.instances[item.id] = nil
			end
		end
	end

	ix.item.inventories[inventory:GetID()] = nil
end

-- Objetos de una lista de inventarios (sin repetir), para valorar o volcar
function LOOT.ItemsOf(inventories)
	local list, seen = {}, {}

	for _, inventory in ipairs(inventories) do
		for _, column in pairs(inventory.slots or {}) do
			for _, item in pairs(column) do
				if (istable(item) and item.id and !seen[item.id]) then
					seen[item.id] = true
					list[#list + 1] = item
				end
			end
		end
	end

	return list
end

-- Filas de objetos de loot que quedaron de una sesión anterior (cadáveres y
-- contenedores no saqueados antes de un cierre del servidor).
function LOOT.PurgeOrphans()
	-- solo antes de crear el primer inventario de loot de esta sesión
	if (invCounter > 0) then return end

	local query = mysql:Delete("ix_items")
		query:WhereGTE("inventory_id", 3000000000)
	query:Execute()
end

-- ─── Log ────────────────────────────────────────────────────────────────────
-- data/efg/loot/<prefijo>_<fecha>.txt
function LOOT.Log(prefix, line)
	file.CreateDir("efg")
	file.CreateDir("efg/loot")
	file.Append(("efg/loot/%s_%s.txt"):format(prefix, os.date("%Y-%m-%d")), os.date("[%H:%M:%S] ") .. line .. "\n")
end

-- "rublos x5000, salewa, ammo_545x39_ps x60"
function LOOT.Describe(rolled)
	local parts = {}

	for _, entry in ipairs(rolled or {}) do
		local data = entry.data or {}
		local amount = data.count or data.rounds

		parts[#parts + 1] = amount and (entry.uniqueID .. " x" .. amount) or entry.uniqueID
	end

	return #parts > 0 and table.concat(parts, ", ") or "(vacío)"
end
