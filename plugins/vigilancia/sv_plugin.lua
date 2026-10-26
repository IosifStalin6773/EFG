-- ============================================================
--  vigilancia  |  sv_plugin.lua  (SERVER)
--  Registro de movimientos de personajes vigilados y gestión
--  del flag de vigilancia. Persistencia en sv.db (Helix).
-- ============================================================

util.AddNetworkString("vigilancia_Open")     -- SV → CL : lista de personajes
util.AddNetworkString("vigilancia_Toggle")   -- CL → SV : activar/desactivar vigilancia
util.AddNetworkString("vigilancia_ReqInv")   -- CL → SV : pedir inventario  /  SV → CL : respuesta
util.AddNetworkString("vigilancia_ReqLogs")  -- CL → SV : pedir logs        /  SV → CL : respuesta
util.AddNetworkString("vigilancia_ReqLockers") -- CL → SV : pedir taquillas  /  SV → CL : respuesta

local CHAR = ix.meta.character

-- Cache de nombres/steamID por charID (para resolver poseedores offline)
ix.vigilancia.charCache = ix.vigilancia.charCache or {}

-- ============================================================
--  Creación de la tabla de logs
-- ============================================================

function PLUGIN:DatabaseConnected()
	local query = mysql:Create("ix_vigilancia_logs")
		query:Create("id",       "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("char_id",  "INT(11) UNSIGNED NOT NULL")
		query:Create("steam_id", "VARCHAR(20) DEFAULT NULL")
		query:Create("category", "VARCHAR(16) NOT NULL")
		query:Create("action",   "VARCHAR(24) NOT NULL")
		query:Create("message",  "TEXT NOT NULL")
		query:Create("amount",   "INT(11) DEFAULT 0")
		query:Create("logged_at","INT(11) UNSIGNED DEFAULT 0")
		query:PrimaryKey("id")
	query:Execute()
end

-- Limpieza de logs muy antiguos al arrancar (más de 30 días)
function PLUGIN:PostLoadData()
	local cutoff = os.time() - (60 * 60 * 24 * 30)
	local query  = mysql:Delete("ix_vigilancia_logs")
		query:WhereLT("logged_at", cutoff)
	query:Execute()
end

-- ============================================================
--  Cache de personajes
-- ============================================================

function ix.vigilancia.CacheChar(character)
	if (not character) then return end
	local id  = character:GetID()
	local ply = character:GetPlayer()
	ix.vigilancia.charCache[id] = {
		name    = character:GetName(),
		steamID = IsValid(ply) and ply:SteamID() or (ix.vigilancia.charCache[id] and ix.vigilancia.charCache[id].steamID),
	}
end

function PLUGIN:CharacterLoaded(character)
	ix.vigilancia.CacheChar(character)
end

-- Devuelve datos legibles del dueño de un inventario (o del mundo si es nil)
function ix.vigilancia.ResolveHolder(inv)
	if (not inv) then
		return {kind = "mundo", name = "el suelo", charID = nil}
	end

	local charID = inv.owner
	if (not charID or charID == 0) then
		return {kind = "almacen", name = "un almacén/mundo", charID = nil}
	end

	local character = ix.char.loaded[charID]
	if (character) then
		ix.vigilancia.CacheChar(character)
	end

	local cached = ix.vigilancia.charCache[charID] or {}
	return {
		kind    = "personaje",
		charID  = charID,
		name    = cached.name or ("Personaje #" .. charID),
		steamID = cached.steamID or "?",
	}
end

-- ============================================================
--  Escritura de logs
-- ============================================================

function ix.vigilancia.LogRaw(charID, steamID, category, action, message, amount)
	if (not charID) then return end

	local query = mysql:Insert("ix_vigilancia_logs")
		query:Insert("char_id",   charID)
		query:Insert("steam_id",  steamID or "")
		query:Insert("category",  category or "inv")
		query:Insert("action",    action or "")
		query:Insert("message",   message or "")
		query:Insert("amount",    amount or 0)
		query:Insert("logged_at", os.time())
	query:Execute()
end

function ix.vigilancia.LogChar(character, category, action, message, amount)
	if (not character) then return end
	local ply = character:GetPlayer()
	ix.vigilancia.LogRaw(
		character:GetID(),
		IsValid(ply) and ply:SteamID() or nil,
		category, action, message, amount
	)
end

-- ============================================================
--  Captura: traspasos de ítems (coger / soltar / entregar)
-- ============================================================

function PLUGIN:OnItemTransferred(item, curInv, newInv)
	if (not item) then return end

	local from = ix.vigilancia.ResolveHolder(curInv)
	local to   = ix.vigilancia.ResolveHolder(newInv)

	-- Reorganización dentro de los inventarios del mismo personaje → ignorar (ruido)
	if (from.charID and to.charID and from.charID == to.charID) then return end

	local isBala   = (item.uniqueID == "bala")
	local qty      = item.GetData and (isBala and item:GetData("count", 1) or item:GetData("Amount", 1)) or 1
	local itemName = (item.GetName and item:GetName()) or item.uniqueID or "objeto"
	local category = isBala and "eco" or "inv"
	local qtyStr   = qty > 1 and (" x" .. qty) or ""

	-- El personaje vigilado pierde el objeto
	if (from.kind == "personaje") then
		local character = ix.char.loaded[from.charID]
		if (character and character:GetVigilado()) then
			ix.vigilancia.LogRaw(from.charID, from.steamID, category, "salida",
				string.format("Entregó/soltó %s%s → %s", itemName, qtyStr, to.name), qty)
		end
	end

	-- El personaje vigilado recibe el objeto
	if (to.kind == "personaje") then
		local character = ix.char.loaded[to.charID]
		if (character and character:GetVigilado()) then
			ix.vigilancia.LogRaw(to.charID, to.steamID, category, "entrada",
				string.format("Recibió/recogió %s%s ← %s", itemName, qtyStr, from.name), qty)
		end
	end
end

-- ============================================================
--  Captura: compras a traders (hook del plugin "traders")
-- ============================================================

function PLUGIN:TraderItemPurchased(client, traderEnt, uniqueID, qty, totalPrice)
	if (not IsValid(client)) then return end
	local character = client:GetCharacter()
	if (not character or not character:GetVigilado()) then return end

	local itemDef    = ix.item.list[uniqueID]
	local itemName   = itemDef and itemDef.name or uniqueID
	local traderName = IsValid(traderEnt) and traderEnt:GetNetVar("traderName", "un comerciante") or "un comerciante"

	ix.vigilancia.LogChar(character, "compra", "compra",
		string.format("Compró %s x%d por %d balas a %s", itemName, qty or 1, totalPrice or 0, traderName),
		totalPrice or 0)
end

-- ============================================================
--  Captura: economía a nivel de cartera (envolviendo el meta)
--  Se ejecuta después de money_items, así que envuelve su versión.
-- ============================================================

local _GiveMoney = CHAR.GiveMoney
local _TakeMoney = CHAR.TakeMoney

function CHAR:GiveMoney(amount, bNoLog)
	local ret = _GiveMoney(self, amount, bNoLog)
	if (self:GetVigilado()) then
		local n = math.floor(math.abs(amount or 0))
		if (n > 0) then
			ix.vigilancia.LogChar(self, "eco", "gain",
				string.format("Ingresó %d balas en la cartera", n), n)
		end
	end
	return ret
end

function CHAR:TakeMoney(amount, bNoLog)
	local ret = _TakeMoney(self, amount, bNoLog)
	if (self:GetVigilado()) then
		local n = math.floor(math.abs(amount or 0))
		if (n > 0) then
			ix.vigilancia.LogChar(self, "eco", "spend",
				string.format("Gastó %d balas de la cartera", n), n)
		end
	end
	return ret
end

-- ============================================================
--  Construcción y envío de la lista de personajes al panel
-- ============================================================

-- Recopila los personajes online + los vigilados offline, y llama a cb(list)
local function buildCharList(cb)
	local list  = {}
	local byID  = {}

	-- Online (todos los cargados)
	for id, character in pairs(ix.char.loaded) do
		local ply = character:GetPlayer()
		if (not IsValid(ply)) then continue end
		local entry = {
			charID   = id,
			name     = character:GetName(),
			steamID  = ply:SteamID(),
			online   = true,
			vigilado = character:GetVigilado() and true or false,
		}
		list[#list + 1] = entry
		byID[id] = entry
	end

	-- Vigilados offline: consultar la tabla de personajes
	local query = mysql:Select("ix_characters")
		query:Select("id")
		query:Select("name")
		query:Select("steamid")
		query:Select("vigilado")
		query:Callback(function(result)
			if (istable(result)) then
				for _, row in ipairs(result) do
					if (not tobool(row.vigilado)) then continue end
					local id = tonumber(row.id)
					if (not id or byID[id]) then continue end
					list[#list + 1] = {
						charID   = id,
						name     = row.name or ("Personaje #" .. id),
						steamID  = row.steamid or "?",
						online   = false,
						vigilado = true,
					}
				end
			end

			table.sort(list, function(a, b)
				if (a.vigilado != b.vigilado) then return a.vigilado end
				if (a.online != b.online) then return a.online end
				return (a.name or "") < (b.name or "")
			end)

			cb(list)
		end)
	query:Execute()
end

local function sendCharList(client)
	buildCharList(function(list)
		if (not IsValid(client)) then return end
		local data = util.Compress(util.TableToJSON(list) or "[]")
		net.Start("vigilancia_Open")
			net.WriteUInt(#data, 32)
			net.WriteData(data, #data)
		net.Send(client)
	end)
end

-- ============================================================
--  Comando de apertura
-- ============================================================

ix.command.Add("Vigilancia", {
	adminOnly   = true,
	description = "Abre el panel de vigilancia de personajes.",
	OnRun = function(self, client)
		sendCharList(client)
	end
})

-- Marca/desmarca en silencio a un jugador online. El objetivo NUNCA recibe nada;
-- solo el administrador ve la confirmación por chat.
ix.command.Add("Vigilar", {
	adminOnly   = true,
	description = "Activa o desactiva en silencio la vigilancia del jugador indicado.",
	arguments   = ix.type.player,
	OnRun = function(self, client, target)
		if (not IsValid(target)) then
			return "@invalidTarget"
		end

		local character = target:GetCharacter()
		if (not character) then
			return "Ese jugador no tiene un personaje cargado."
		end

		local newState = not character:GetVigilado()
		character:SetVigilado(newState)
		character:Save()

		ix.vigilancia.LogRaw(character:GetID(), target:SteamID(), "sistema", "flag",
			(newState and "Vigilancia ACTIVADA por " or "Vigilancia DESACTIVADA por ")
			.. client:SteamName() .. " (" .. client:SteamID() .. ")")

		-- Confirmación solo para el administrador (el objetivo no se entera).
		client:Notify(string.format("%s ahora está %s.", character:GetName(),
			newState and "VIGILADO" or "SIN vigilancia"))
	end
})

-- ============================================================
--  Activar / desactivar la vigilancia de un personaje
-- ============================================================

net.Receive("vigilancia_Toggle", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local charID = net.ReadUInt(32)
	if (not charID or charID == 0) then return end

	local character = ix.char.loaded[charID]
	if (character) then
		local newState = not character:GetVigilado()
		character:SetVigilado(newState)
		character:Save()

		local ply = character:GetPlayer()
		ix.vigilancia.LogRaw(charID, IsValid(ply) and ply:SteamID() or nil, "sistema", "flag",
			(newState and "Vigilancia ACTIVADA por " or "Vigilancia DESACTIVADA por ")
			.. client:SteamName() .. " (" .. client:SteamID() .. ")")
	else
		-- Personaje offline: alternar directamente en la BD
		local read = mysql:Select("ix_characters")
			read:Select("vigilado")
			read:Where("id", charID)
			read:Limit(1)
			read:Callback(function(result)
				local cur = istable(result) and result[1] and tobool(result[1].vigilado) or false
				local upd = mysql:Update("ix_characters")
					upd:Update("vigilado", (not cur) and 1 or 0)
					upd:Where("id", charID)
				upd:Execute()

				ix.vigilancia.LogRaw(charID, nil, "sistema", "flag",
					((not cur) and "Vigilancia ACTIVADA por " or "Vigilancia DESACTIVADA por ")
					.. client:SteamName() .. " (offline)")
			end)
		read:Execute()
	end

	timer.Simple(0.2, function()
		if (IsValid(client)) then sendCharList(client) end
	end)
end)

-- ============================================================
--  Petición de inventario en vivo de un personaje
-- ============================================================

net.Receive("vigilancia_ReqInv", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local charID = net.ReadUInt(32)
	local character = ix.char.loaded[charID]

	local payload = {online = character != nil, items = {}}

	if (character) then
		local mainInv = character:GetInventory()
		local mainID  = mainInv and mainInv:GetID() or -1

		for invID, inv in pairs(ix.item.inventories) do
			if (not inv or inv.owner != charID) then continue end

			local label = (invID == mainID) and "Principal" or ("Extra #" .. invID)
			for _, item in pairs(inv:GetItems()) do
				if (not item) then continue end
				local isBala = (item.uniqueID == "bala")
				payload.items[#payload.items + 1] = {
					name     = (item.GetName and item:GetName()) or item.uniqueID,
					category = item.category or "—",
					qty      = isBala and item:GetData("count", 1) or item:GetData("Amount", 1),
					source   = label,
				}
			end
		end

		table.sort(payload.items, function(a, b)
			if (a.source != b.source) then return a.source < b.source end
			return (a.name or "") < (b.name or "")
		end)
	end

	local data = util.Compress(util.TableToJSON(payload) or "{}")
	net.Start("vigilancia_ReqInv")
		net.WriteUInt(charID, 32)
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
	net.Send(client)
end)

-- ============================================================
--  Petición de taquillas (funciona ONLINE y OFFLINE)
--  Las taquillas (plugin strongbox) son inventarios Helix
--  persistentes enlazados al personaje por character:SetData
--  ("strongbox_<lockerID>" = {id = invID, height = h}). Como
--  viven en ix_inventories/ix_items, se pueden leer aunque el
--  personaje esté desconectado consultando la BD directamente.
-- ============================================================

-- Carga la lista de taquillas de un personaje (con su contenido) y llama a cb(lockers)
local function collectLockers(charID, character, cb)
	local function withData(dataTbl)
		local lockers = {}

		for key, val in pairs(dataTbl or {}) do
			-- Solo tipos de caja conocidos: "strongbox_<lockerID>". Añadir aquí
			-- otros prefijos si se registran nuevos tipos de taquilla.
			local lockerID = string.match(key, "^strongbox_(%d+)$")
			if (lockerID and istable(val) and val.id) then
				lockers[#lockers + 1] = {
					lockerID = tonumber(lockerID),
					type     = "strongbox",
					invID    = val.id,
					items    = {},
				}
			end
		end

		if (#lockers == 0) then
			cb(lockers)
			return
		end

		-- Cargar el contenido de cada taquilla desde ix_items
		local pending = #lockers
		for _, locker in ipairs(lockers) do
			local q = mysql:Select("ix_items")
				q:Select("unique_id")
				q:Select("data")
				q:Where("inventory_id", locker.invID)
				q:Callback(function(result)
					if (istable(result)) then
						for _, row in ipairs(result) do
							local def    = ix.item.list[row.unique_id]
							local d      = util.JSONToTable(row.data or "") or {}
							local isBala = (row.unique_id == "bala")
							locker.items[#locker.items + 1] = {
								name     = def and def.name or row.unique_id,
								category = def and def.category or "—",
								qty      = isBala and (tonumber(d.count) or 1) or (tonumber(d.Amount) or 1),
							}
						end
						table.sort(locker.items, function(a, b) return (a.name or "") < (b.name or "") end)
					end

					pending = pending - 1
					if (pending == 0) then cb(lockers) end
				end)
			q:Execute()
		end
	end

	if (character) then
		withData(character:GetData())
	else
		local q = mysql:Select("ix_characters")
			q:Select("data")
			q:Where("id", charID)
			q:Limit(1)
			q:Callback(function(result)
				local dataTbl = {}
				if (istable(result) and result[1] and result[1].data) then
					dataTbl = util.JSONToTable(result[1].data) or {}
				end
				withData(dataTbl)
			end)
		q:Execute()
	end
end

net.Receive("vigilancia_ReqLockers", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local charID    = net.ReadUInt(32)
	local character  = ix.char.loaded[charID]

	collectLockers(charID, character, function(lockers)
		if (not IsValid(client)) then return end

		-- No enviar el invID interno al cliente (no lo necesita)
		for _, l in ipairs(lockers) do l.invID = nil end

		local payload = {online = character != nil, lockers = lockers}
		local data    = util.Compress(util.TableToJSON(payload) or "{}")
		net.Start("vigilancia_ReqLockers")
			net.WriteUInt(charID, 32)
			net.WriteUInt(#data, 32)
			net.WriteData(data, #data)
		net.Send(client)
	end)
end)

-- ============================================================
--  Petición de logs de un personaje
-- ============================================================

net.Receive("vigilancia_ReqLogs", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local charID = net.ReadUInt(32)

	local query = mysql:Select("ix_vigilancia_logs")
		query:Select("category")
		query:Select("action")
		query:Select("message")
		query:Select("amount")
		query:Select("logged_at")
		query:Where("char_id", charID)
		query:OrderByDesc("id")
		query:Limit(300)
		query:Callback(function(result)
			local logs = {}
			if (istable(result)) then
				for _, row in ipairs(result) do
					logs[#logs + 1] = {
						category = row.category,
						action   = row.action,
						message  = row.message,
						amount   = tonumber(row.amount) or 0,
						at       = tonumber(row.logged_at) or 0,
					}
				end
			end

			if (not IsValid(client)) then return end
			local data = util.Compress(util.TableToJSON(logs) or "[]")
			net.Start("vigilancia_ReqLogs")
				net.WriteUInt(charID, 32)
				net.WriteUInt(#data, 32)
				net.WriteData(data, #data)
			net.Send(client)
		end)
	query:Execute()
end)
