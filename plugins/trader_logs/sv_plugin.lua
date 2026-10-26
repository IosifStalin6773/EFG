-- ============================================================
--  trader_logs  |  sv_plugin.lua  (SERVER)
--  Persistencia en sv.db (SQLite/MySQL de Helix), seguimiento
--  de traspasos, detección de duplicados y borrado físico.
-- ============================================================

util.AddNetworkString("traderlogs_Open")
util.AddNetworkString("traderlogs_Delete")
util.AddNetworkString("dupescanner_Open")
util.AddNetworkString("dupescanner_Delete")

ix.traderlogs.entries   = ix.traderlogs.entries   or {}   -- [serial] = entry (cache en RAM)
ix.traderlogs.charCache = ix.traderlogs.charCache or {}   -- [charID] = {name, steamID}
ix.traderlogs.dupeHistory = ix.traderlogs.dupeHistory or {} -- registros históricos de dupes

-- ============================================================
--  Creación de tablas en la BD
-- ============================================================

function PLUGIN:DatabaseConnected()
	local query

	query = mysql:Create("ix_trader_logs")
		query:Create("id",          "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("serial",      "VARCHAR(32) NOT NULL")
		query:Create("unique_id",   "VARCHAR(60) NOT NULL")
		query:Create("item_name",   "VARCHAR(120) NOT NULL")
		query:Create("trader_id",   "VARCHAR(64) DEFAULT NULL")
		query:Create("trader_name", "VARCHAR(120) DEFAULT NULL")
		query:Create("price",       "INT(11) UNSIGNED DEFAULT 0")
		query:Create("bought_at",   "INT(11) UNSIGNED DEFAULT 0")
		query:Create("buyer_char",  "INT(11) UNSIGNED DEFAULT NULL")
		query:Create("buyer_steam", "VARCHAR(20) DEFAULT NULL")
		query:Create("buyer_name",  "VARCHAR(120) DEFAULT NULL")
		query:Create("history",     "TEXT DEFAULT NULL")
		query:Create("deleted",     "TINYINT(1) DEFAULT 0")
		query:Create("deleted_by",  "VARCHAR(120) DEFAULT NULL")
		query:Create("deleted_at",  "INT(11) UNSIGNED DEFAULT NULL")
		query:PrimaryKey("id")
	query:Execute()

	query = mysql:Create("ix_dupe_logs")
		query:Create("id",           "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("item_id",      "INT(11) UNSIGNED NOT NULL")
		query:Create("unique_id",    "VARCHAR(60) NOT NULL")
		query:Create("item_name",    "VARCHAR(120) NOT NULL")
		query:Create("category",     "VARCHAR(60) DEFAULT NULL")
		query:Create("reason",       "VARCHAR(20) NOT NULL")
		query:Create("serial",       "VARCHAR(32) DEFAULT NULL")
		query:Create("holders",      "TEXT DEFAULT NULL")
		query:Create("count",        "SMALLINT(4) UNSIGNED DEFAULT 1")
		query:Create("detected_at",  "INT(11) UNSIGNED DEFAULT 0")
		query:Create("resolved",     "TINYINT(1) DEFAULT 0")
		query:Create("resolved_by",  "VARCHAR(120) DEFAULT NULL")
		query:Create("resolved_at",  "INT(11) UNSIGNED DEFAULT NULL")
		query:PrimaryKey("id")
	query:Execute()
end

-- ============================================================
--  Carga desde la BD al arrancar
-- ============================================================

function PLUGIN:PostLoadData()
	ix.traderlogs.entries = {}

	local query = mysql:Select("ix_trader_logs")
		query:Select("serial")
		query:Select("unique_id")
		query:Select("item_name")
		query:Select("trader_id")
		query:Select("trader_name")
		query:Select("price")
		query:Select("bought_at")
		query:Select("buyer_char")
		query:Select("buyer_steam")
		query:Select("buyer_name")
		query:Select("history")
		query:Select("deleted")
		query:Select("deleted_by")
		query:Select("deleted_at")
		query:Callback(function(result)
			if (not istable(result)) then return end

			for _, row in ipairs(result) do
				local serial = row.serial
				ix.traderlogs.entries[serial] = {
					serial     = serial,
					uniqueID   = row.unique_id,
					itemName   = row.item_name,
					traderID   = row.trader_id,
					traderName = row.trader_name,
					price      = tonumber(row.price) or 0,
					boughtAt   = tonumber(row.bought_at) or 0,
					buyer      = {
						charID  = tonumber(row.buyer_char),
						steamID = row.buyer_steam,
						name    = row.buyer_name,
					},
					history    = util.JSONToTable(row.history or "[]") or {},
					deleted    = (tonumber(row.deleted) or 0) != 0,
					deletedBy  = row.deleted_by,
					deletedAt  = tonumber(row.deleted_at),
				}
			end
		end)
	query:Execute()

	-- Cargar historial de dupes
	ix.traderlogs.dupeHistory = {}
	local dupeQuery = mysql:Select("ix_dupe_logs")
		dupeQuery:Callback(function(result)
			if (not istable(result)) then return end
			for _, row in ipairs(result) do
				ix.traderlogs.dupeHistory[#ix.traderlogs.dupeHistory + 1] = {
					dbID       = tonumber(row.id),
					itemID     = tonumber(row.item_id) or 0,
					uniqueID   = row.unique_id,
					itemName   = row.item_name,
					category   = row.category,
					reason     = row.reason,
					serial     = row.serial,
					holders    = util.JSONToTable(row.holders or "[]") or {},
					count      = tonumber(row.count) or 1,
					detectedAt = tonumber(row.detected_at) or 0,
					resolved   = (tonumber(row.resolved) or 0) != 0,
					resolvedBy = row.resolved_by,
					resolvedAt = tonumber(row.resolved_at),
				}
			end
		end)
	dupeQuery:Execute()

	-- Migrar datos antiguos del JSON (PLUGIN:GetData) a la BD si existen
	timer.Simple(2, function()
		local old = self:GetData()
		if (not old or not old.entries or table.Count(old.entries) == 0) then return end

		for serial, entry in pairs(old.entries) do
			if (not ix.traderlogs.entries[serial]) then
				ix.traderlogs.entries[serial] = entry
				ix.traderlogs.DBInsert(entry)
			end
		end

		-- Limpiar el JSON antiguo
		self:SetData(nil)
	end)
end

-- ============================================================
--  Operaciones de BD
-- ============================================================

-- Contador local para serials (más rápido que una query MAX)
local nextSerialID = 0

function PLUGIN:Initialize()
	local query = mysql:Select("ix_trader_logs")
		query:Select("serial")
		query:OrderBy("id", "DESC")
		query:Limit(1)
		query:Callback(function(result)
			if (istable(result) and result[1]) then
				local num = tonumber(string.match(result[1].serial, "^TL(%d+)$"))
				if (num) then nextSerialID = num end
			end
		end)
	query:Execute()
end

function ix.traderlogs.GenSerial()
	nextSerialID = nextSerialID + 1
	return "TL" .. nextSerialID
end

function ix.traderlogs.DBInsert(entry)
	local query = mysql:Insert("ix_trader_logs")
		query:Insert("serial",      entry.serial)
		query:Insert("unique_id",   entry.uniqueID or "")
		query:Insert("item_name",   entry.itemName or "")
		query:Insert("trader_id",   entry.traderID or "")
		query:Insert("trader_name", entry.traderName or "")
		query:Insert("price",       entry.price or 0)
		query:Insert("bought_at",   entry.boughtAt or 0)
		query:Insert("buyer_char",  entry.buyer and entry.buyer.charID or 0)
		query:Insert("buyer_steam", entry.buyer and entry.buyer.steamID or "")
		query:Insert("buyer_name",  entry.buyer and entry.buyer.name or "")
		query:Insert("history",     util.TableToJSON(entry.history or {}))
		query:Insert("deleted",     entry.deleted and 1 or 0)
		query:Insert("deleted_by",  entry.deletedBy or "")
		query:Insert("deleted_at",  entry.deletedAt or 0)
	query:Execute()
end

function ix.traderlogs.DBUpdateHistory(serial, history)
	local query = mysql:Update("ix_trader_logs")
		query:Update("history", util.TableToJSON(history or {}))
		query:Where("serial", serial)
	query:Execute()
end

function ix.traderlogs.DBMarkDeleted(serial, deletedBy, deletedAt)
	local query = mysql:Update("ix_trader_logs")
		query:Update("deleted",    1)
		query:Update("deleted_by", deletedBy or "")
		query:Update("deleted_at", deletedAt or 0)
		query:Where("serial", serial)
	query:Execute()
end

-- ============================================================
--  Utilidades
-- ============================================================

function ix.traderlogs.CacheChar(character)
	if (not character) then return end
	local id  = character:GetID()
	local ply = character:GetPlayer()
	ix.traderlogs.charCache[id] = {
		name    = character:GetName(),
		steamID = IsValid(ply) and ply:SteamID() or (ix.traderlogs.charCache[id] and ix.traderlogs.charCache[id].steamID),
	}
end

function ix.traderlogs.ResolveHolder(inv)
	if (not inv) then return {kind = "desconocido", name = "Desconocido"} end

	local charID = inv.owner
	if (not charID or charID == 0) then
		return {kind = "mundo", name = "Inventario sin dueño"}
	end

	local character = ix.char.loaded[charID]
	if (character) then
		ix.traderlogs.CacheChar(character)
	end

	local cached = ix.traderlogs.charCache[charID] or {}
	return {
		kind    = "personaje",
		charID  = charID,
		name    = cached.name or ("Personaje #" .. charID),
		steamID = cached.steamID or "?",
		online  = character != nil,
	}
end

function ix.traderlogs.GetLoadedBySerial()
	local bySerial = {}
	for _, item in pairs(ix.item.instances) do
		if (not item or not item.GetData) then continue end
		local serial = item:GetData("traderSerial")
		if (serial) then
			bySerial[serial] = bySerial[serial] or {}
			table.insert(bySerial[serial], item)
		end
	end
	return bySerial
end

-- ============================================================
--  Registro de compra (hook del plugin "traders")
-- ============================================================

function PLUGIN:TraderItemPurchased(client, traderEnt, uniqueID, qty, totalPrice)
	if (not IsValid(client) or not IsValid(traderEnt)) then return end
	local character = client:GetCharacter()
	if (not character) then return end

	ix.traderlogs.CacheChar(character)

	local traderID   = traderEnt:GetPersistKey()
	local traderName = traderEnt:GetNetVar("traderName", "Comerciante")
	local unitPrice  = math.floor((totalPrice or 0) / math.max(1, qty))
	local charID     = character:GetID()
	local steamID    = client:SteamID()
	local charName   = character:GetName()
	local itemDef    = ix.item.list[uniqueID]
	local itemName   = itemDef and itemDef.name or uniqueID

	timer.Simple(0.5, function()
		if (not IsValid(client)) then return end
		local char = client:GetCharacter()
		if (not char) then return end
		local inv = char:GetInventory()
		if (not inv) then return end

		local tagged = 0
		for _, item in pairs(inv:GetItems()) do
			if (item.uniqueID == uniqueID and not item:GetData("traderSerial")) then
				local serial = ix.traderlogs.GenSerial()
				item:SetData("traderSerial", serial)
				item:SetData("traderOrigin", traderID)

				local entry = {
					serial     = serial,
					uniqueID   = uniqueID,
					itemName   = itemName,
					traderID   = traderID,
					traderName = traderName,
					price      = unitPrice,
					boughtAt   = os.time(),
					buyer      = {
						charID  = charID,
						steamID = steamID,
						name    = charName,
					},
					history    = {},
				}

				ix.traderlogs.entries[serial] = entry
				ix.traderlogs.DBInsert(entry)

				tagged = tagged + 1
				if (tagged >= qty) then break end
			end
		end
	end)
end

-- ============================================================
--  Seguimiento de traspasos entre inventarios
-- ============================================================

function PLUGIN:OnItemTransferred(item, curInv, newInv)
	if (not item or not item.GetData) then return end
	local serial = item:GetData("traderSerial")
	if (not serial) then return end

	local entry = ix.traderlogs.entries[serial]
	if (not entry) then return end

	local holder = ix.traderlogs.ResolveHolder(newInv)

	local last = entry.history[#entry.history]
	local lastCharID = last and last.charID or (entry.buyer and entry.buyer.charID)
	if (holder.kind == "personaje" and holder.charID == lastCharID) then return end

	entry.history[#entry.history + 1] = {
		charID  = holder.charID,
		steamID = holder.steamID,
		name    = holder.name,
		kind    = holder.kind,
		at      = os.time(),
	}

	while (#entry.history > ix.traderlogs.maxHistory) do
		table.remove(entry.history, 1)
	end

	ix.traderlogs.DBUpdateHistory(serial, entry.history)
end

function PLUGIN:CharacterLoaded(character)
	ix.traderlogs.CacheChar(character)
end

-- ============================================================
--  Construcción del payload para el panel
-- ============================================================

function ix.traderlogs.BuildPayload()
	local bySerial = ix.traderlogs.GetLoadedBySerial()
	local list = {}

	for serial, entry in pairs(ix.traderlogs.entries) do
		local loaded  = bySerial[serial] or {}
		local holders = {}

		for _, item in ipairs(loaded) do
			local inv    = ix.item.inventories[item.invID]
			local holder = inv and ix.traderlogs.ResolveHolder(inv) or nil

			if (not holder) then
				if (IsValid(item.entity)) then
					holder = {kind = "suelo", name = "En el suelo"}
				else
					holder = {kind = "desconocido", name = "Desconocido"}
				end
			end

			holders[#holders + 1] = {
				name    = holder.name,
				steamID = holder.steamID or "?",
				charID  = holder.charID,
				kind    = holder.kind,
				online  = holder.online or false,
				itemDBID = item:GetID(),
			}
		end

		list[#list + 1] = {
			serial     = serial,
			itemName   = entry.itemName or entry.uniqueID,
			uniqueID   = entry.uniqueID,
			traderName = entry.traderName,
			price      = entry.price or 0,
			boughtAt   = entry.boughtAt or 0,
			buyer      = entry.buyer or {name = "?"},
			history    = entry.history or {},
			holders    = holders,
			dupe       = (#loaded > 1),
			deleted    = entry.deleted or false,
			deletedBy  = entry.deletedBy,
			deletedAt  = entry.deletedAt,
		}
	end

	table.sort(list, function(a, b) return (a.boughtAt or 0) > (b.boughtAt or 0) end)
	return list
end

local function sendPanel(client)
	local payload = ix.traderlogs.BuildPayload()
	local json    = util.TableToJSON(payload) or "[]"
	local data    = util.Compress(json)

	net.Start("traderlogs_Open")
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
	net.Send(client)
end

-- ============================================================
--  Comando de apertura
-- ============================================================

ix.command.Add("TraderLogs", {
	adminOnly   = true,
	description = "Abre el panel de trazabilidad de ítems vendidos por traders.",
	OnRun = function(self, client)
		sendPanel(client)
	end
})

-- ============================================================
--  Borrado físico del objeto desde el panel
-- ============================================================

net.Receive("traderlogs_Delete", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local serial = net.ReadString()
	local entry  = ix.traderlogs.entries[serial]
	if (not entry) then return end

	local removed = 0
	local bySerial = ix.traderlogs.GetLoadedBySerial()
	for _, item in ipairs(bySerial[serial] or {}) do
		if (IsValid(item.entity)) then item.entity:Remove() end
		item:Remove()
		removed = removed + 1
	end

	local deletedBy = client:SteamName() .. " (" .. client:SteamID() .. ")"
	local deletedAt = os.time()

	entry.deleted   = true
	entry.deletedBy = deletedBy
	entry.deletedAt = deletedAt

	ix.traderlogs.DBMarkDeleted(serial, deletedBy, deletedAt)

	client:ChatPrint(string.format("[Trader Logs] %s instancia(s) de '%s' (%s) eliminada(s).",
		removed, entry.itemName or "?", serial))

	sendPanel(client)
end)

-- ============================================================
--  DUPE SCANNER — escaneo general de TODOS los ítems cargados
--  Persistencia en ix_dupe_logs (sv.db)
-- ============================================================

-- Inserta un registro de dupe en la BD y en el cache RAM
function ix.traderlogs.DupeInsert(entry)
	entry.detectedAt = entry.detectedAt or os.time()

	local query = mysql:Insert("ix_dupe_logs")
		query:Insert("item_id",     entry.itemID or 0)
		query:Insert("unique_id",   entry.uniqueID or "")
		query:Insert("item_name",   entry.itemName or "")
		query:Insert("category",    entry.category or "")
		query:Insert("reason",      entry.reason or "")
		query:Insert("serial",      entry.serial or "")
		query:Insert("holders",     util.TableToJSON(entry.holders or {}))
		query:Insert("count",       entry.count or 1)
		query:Insert("detected_at", entry.detectedAt)
		query:Insert("resolved",    0)
		query:Insert("resolved_by", "")
		query:Insert("resolved_at", 0)
		query:Callback(function(_, _, lastID)
			entry.dbID = lastID
			ix.traderlogs.dupeHistory[#ix.traderlogs.dupeHistory + 1] = entry
		end)
	query:Execute()
end

function ix.traderlogs.DupeMarkResolved(dbID, resolvedBy)
	local resolvedAt = os.time()

	local query = mysql:Update("ix_dupe_logs")
		query:Update("resolved",    1)
		query:Update("resolved_by", resolvedBy or "")
		query:Update("resolved_at", resolvedAt)
		query:Where("id", dbID)
	query:Execute()

	for _, d in ipairs(ix.traderlogs.dupeHistory) do
		if (d.dbID == dbID) then
			d.resolved   = true
			d.resolvedBy = resolvedBy
			d.resolvedAt = resolvedAt
			break
		end
	end
end

-- Escaneo en vivo de la memoria
function ix.traderlogs.ScanDupes()
	local dupes = {}

	-- Check 1: item.id en slots de múltiples inventarios
	local idToInvs = {}
	for invID, inv in pairs(ix.item.inventories) do
		if (not inv or not inv.slots or invID == 0) then continue end
		for x, col in pairs(inv.slots) do
			if (not istable(col)) then continue end
			for y, slotItem in pairs(col) do
				if (istable(slotItem) and slotItem.id and slotItem.gridX == x and slotItem.gridY == y) then
					idToInvs[slotItem.id] = idToInvs[slotItem.id] or {}
					idToInvs[slotItem.id][invID] = true
				end
			end
		end
	end

	for itemID, invMap in pairs(idToInvs) do
		local invIDs = table.GetKeys(invMap)
		if (#invIDs <= 1) then continue end

		local item = ix.item.instances[itemID]
		if (not item) then continue end

		local holders = {}
		for _, invID in ipairs(invIDs) do
			local inv    = ix.item.inventories[invID]
			local holder = inv and ix.traderlogs.ResolveHolder(inv) or {kind = "desconocido", name = "Inv #" .. invID}
			holders[#holders + 1] = {
				name    = holder.name,
				steamID = holder.steamID or "?",
				charID  = holder.charID,
				kind    = holder.kind,
				online  = holder.online or false,
				invID   = invID,
			}
		end

		local itemDef = ix.item.list[item.uniqueID]
		dupes[#dupes + 1] = {
			reason   = "multi_inv",
			itemID   = itemID,
			uniqueID = item.uniqueID,
			itemName = itemDef and itemDef.name or item.uniqueID,
			category = itemDef and itemDef.category or "?",
			serial   = item.GetData and item:GetData("traderSerial") or nil,
			holders  = holders,
			count    = #invIDs,
			live     = true,
		}
	end

	-- Check 2: traderSerial compartido por múltiples instancias
	local bySerial = ix.traderlogs.GetLoadedBySerial()
	for serial, items in pairs(bySerial) do
		if (#items <= 1) then continue end

		local alreadyCaught = false
		for _, d in ipairs(dupes) do
			if (d.serial == serial) then alreadyCaught = true; break end
		end
		if (alreadyCaught) then continue end

		local holders = {}
		for _, item in ipairs(items) do
			local inv    = ix.item.inventories[item.invID]
			local holder = inv and ix.traderlogs.ResolveHolder(inv) or nil
			if (not holder) then
				if (IsValid(item.entity)) then
					holder = {kind = "suelo", name = "En el suelo"}
				else
					holder = {kind = "desconocido", name = "Desconocido"}
				end
			end
			holders[#holders + 1] = {
				name    = holder.name,
				steamID = holder.steamID or "?",
				charID  = holder.charID,
				kind    = holder.kind,
				online  = holder.online or false,
				itemDBID = item:GetID(),
			}
		end

		local first   = items[1]
		local itemDef = ix.item.list[first.uniqueID]
		dupes[#dupes + 1] = {
			reason   = "serial_dupe",
			itemID   = first:GetID(),
			uniqueID = first.uniqueID,
			itemName = itemDef and itemDef.name or first.uniqueID,
			category = itemDef and itemDef.category or "?",
			serial   = serial,
			holders  = holders,
			count    = #items,
			live     = true,
		}
	end

	-- Check 3: invID no coincide con inventario real
	for id, item in pairs(ix.item.instances) do
		if (not item or not item.invID or item.invID == 0) then continue end
		local inv = ix.item.inventories[item.invID]
		if (not inv or not inv.slots) then continue end

		local found = false
		if (inv.slots[item.gridX]) then
			local slotItem = inv.slots[item.gridX][item.gridY]
			if (istable(slotItem) and slotItem.id == item.id) then
				found = true
			end
		end

		if (not found) then
			local itemDef = ix.item.list[item.uniqueID]
			local holder  = ix.traderlogs.ResolveHolder(inv)
			dupes[#dupes + 1] = {
				reason   = "ghost",
				itemID   = item.id,
				uniqueID = item.uniqueID,
				itemName = itemDef and itemDef.name or item.uniqueID,
				category = itemDef and itemDef.category or "?",
				serial   = item.GetData and item:GetData("traderSerial") or nil,
				holders  = {{
					name    = holder.name or "?",
					steamID = holder.steamID or "?",
					charID  = holder.charID,
					kind    = holder.kind,
					online  = holder.online or false,
					invID   = item.invID,
				}},
				count    = 1,
				claimedInv = item.invID,
				claimedPos = item.gridX .. "," .. item.gridY,
				live     = true,
			}
		end
	end

	-- Registrar nuevos dupes en la BD (evitar duplicar por itemID+reason)
	local existingKeys = {}
	for _, d in ipairs(ix.traderlogs.dupeHistory) do
		existingKeys[d.reason .. "_" .. d.itemID] = true
	end

	for _, d in ipairs(dupes) do
		local key = d.reason .. "_" .. (d.itemID or 0)
		if (not existingKeys[key]) then
			existingKeys[key] = true
			ix.traderlogs.DupeInsert(table.Copy(d))
		end
	end

	return dupes
end

-- Construye el payload combinando dupes en vivo + historial de la BD
function ix.traderlogs.BuildDupePayload()
	local liveDupes = ix.traderlogs.ScanDupes()

	-- Construir set de claves de dupes vivos para marcar cuáles siguen activos
	local liveKeys = {}
	for _, d in ipairs(liveDupes) do
		liveKeys[d.reason .. "_" .. (d.itemID or 0)] = d
	end

	-- Combinar: históricos que ya no están vivos + los vivos
	local payload = {}
	local seen = {}

	-- Primero los vivos (más relevantes)
	for _, d in ipairs(liveDupes) do
		d.live = true
		payload[#payload + 1] = d
		seen[d.reason .. "_" .. (d.itemID or 0)] = true
	end

	-- Luego los históricos que ya no están activos (resueltos o ya no detectables)
	for _, d in ipairs(ix.traderlogs.dupeHistory) do
		local key = d.reason .. "_" .. (d.itemID or 0)
		if (not seen[key]) then
			d.live = false
			payload[#payload + 1] = d
			seen[key] = true
		end
	end

	-- Ordenar: vivos primero, luego por fecha
	table.sort(payload, function(a, b)
		if (a.live and not b.live) then return true end
		if (not a.live and b.live) then return false end
		return (a.detectedAt or 0) > (b.detectedAt or 0)
	end)

	return payload
end

local function sendDupePanel(client)
	local payload = ix.traderlogs.BuildDupePayload()
	local json    = util.TableToJSON(payload) or "[]"
	local data    = util.Compress(json)

	net.Start("dupescanner_Open")
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
	net.Send(client)
end

ix.command.Add("DupeScanner", {
	adminOnly   = true,
	description = "Escanea todos los ítems cargados del servidor buscando duplicados.",
	OnRun = function(self, client)
		sendDupePanel(client)
	end
})

net.Receive("dupescanner_Delete", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local itemID = net.ReadUInt(32)
	local item   = ix.item.instances[itemID]
	if (not item) then
		client:ChatPrint("[Dupe Scanner] Ítem #" .. itemID .. " no encontrado en memoria.")
		return
	end

	local itemName = item.GetName and item:GetName() or item.uniqueID
	if (IsValid(item.entity)) then item.entity:Remove() end
	item:Remove()

	-- Marcar como resuelto en la BD cualquier registro que coincida con este ítem
	local resolvedBy = client:SteamName() .. " (" .. client:SteamID() .. ")"
	for _, d in ipairs(ix.traderlogs.dupeHistory) do
		if (d.itemID == itemID and not d.resolved) then
			ix.traderlogs.DupeMarkResolved(d.dbID, resolvedBy)
		end
	end

	client:ChatPrint(string.format("[Dupe Scanner] Ítem '%s' (#%d) eliminado.", itemName, itemID))
	sendDupePanel(client)
end)
