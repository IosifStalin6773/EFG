-- ============================================================
--  economia_monitor  |  sv_plugin.lua  (SERVER)
--  Suma los Rublos ("rublos") de todo el servidor: personajes online (en
--  memoria), personajes offline (BD) y todas las taquillas (BD, salvo
--  las que ya estén cargadas en memoria). Mismo patrón que el panel
--  de vigilancia (ix_characters + ix_inventories + ix_items).
--  De paso construye un ranking por personaje (inventario + sus
--  taquillas) para el listado de "más ricos".
-- ============================================================

local RUBLOS_ID = "rublos"

-- Suma "rublos" de un inventario ya cargado en memoria (ix.item.inventories)
local function SumLoadedInventory(inv)
	local total = 0
	for _, item in pairs(inv:GetItems()) do
		if (item.uniqueID == RUBLOS_ID) then
			total = total + item:GetData("count", 1)
		end
	end
	return total
end

-- Suma "rublos" consultando directamente la BD para un inventoryID concreto.
-- cb(amount) se llama siempre, tanto si hay filas como si no.
local function SumInventoryFromDB(invID, cb)
	local q = mysql:Select("ix_items")
		q:Select("data")
		q:Where("inventory_id", invID)
		q:Where("unique_id", RUBLOS_ID)
		q:Callback(function(result)
			local total = 0
			if (istable(result)) then
				for _, row in ipairs(result) do
					local d = util.JSONToTable(row.data or "") or {}
					total = total + (tonumber(d.count) or 1)
				end
			end
			cb(total)
		end)
	q:Execute()
end

-- Calcula la masa monetaria total del servidor y llama a callback(totals) con:
-- {online, offline, lockers, arcas, onlineCount, offlineCount,
--  richest = {{charID, name, amount}, ...} ordenado de mayor a menor}
function ix.economia.ComputeTotal(callback)
	local totals = {
		online = 0,
		offline = 0,
		lockers = 0,
		arcas = (ix.arcas and ix.arcas.hanza) or 0,
		onlineCount = 0,
		offlineCount = 0,
		richest = {},
	}

	-- 1. Personajes ONLINE: lectura en vivo desde memoria (exacta al segundo).
	-- ix.char.loaded puede contener personajes cuyo jugador ya se desconectó
	-- (limpieza pendiente); solo cuentan como "online" los que siguen con un
	-- jugador válido detrás (mismo criterio que usa vigilancia).
	local loadedIDs = {}
	local onlineInv = {} -- charID -> Rublos de su inventario (en vivo)
	for id, character in pairs(ix.char.loaded) do
		if (IsValid(character:GetPlayer())) then
			loadedIDs[id] = true
			totals.onlineCount = totals.onlineCount + 1

			local inv = character:GetInventory()
			local amount = inv and SumLoadedInventory(inv) or 0
			totals.online = totals.online + amount
			onlineInv[id] = amount
		end
	end

	-- 2. Recorrer TODOS los personajes de la BD para localizar: offline +
	--    las taquillas de absolutamente todos (online y offline), y montar
	--    el ranking por personaje.
	local query = mysql:Select("ix_characters")
		query:Select("id")
		query:Select("name")
		query:Select("data")
		query:Callback(function(result)
			if (not istable(result)) then
				callback(totals)
				return
			end

			local perChar = {}      -- charID -> {name = .., amount = ..}
			local offlineIDs = {}
			local lockerJobs = {}   -- {invID = .., charID = ..}

			for _, row in ipairs(result) do
				local id = tonumber(row.id)
				if (not id) then continue end

				local name = row.name or ("Personaje #" .. id)
				local isOnline = loadedIDs[id] == true

				if (isOnline) then
					perChar[id] = {name = name, amount = onlineInv[id] or 0}
				else
					perChar[id] = {name = name, amount = 0}
					offlineIDs[#offlineIDs + 1] = id
					totals.offlineCount = totals.offlineCount + 1
				end

				local dataTbl = util.JSONToTable(row.data or "") or {}
				for key, val in pairs(dataTbl) do
					if (string.match(key, "^strongbox_%d+$") and istable(val) and val.id) then
						lockerJobs[#lockerJobs + 1] = {invID = tonumber(val.id), charID = id}
					end
				end
			end

			-- Centinela: arranca en 1 para que ninguna consulta síncrona pueda
			-- disparar el callback antes de que terminemos de lanzar todas.
			local remaining = 1
			local function finishOne()
				remaining = remaining - 1
				if (remaining <= 0) then
					local list = {}
					for id, info in pairs(perChar) do
						list[#list + 1] = {charID = id, name = info.name, amount = info.amount}
					end
					table.sort(list, function(a, b) return a.amount > b.amount end)
					totals.richest = list
					callback(totals)
				end
			end

			-- 2a. Taquillas de TODOS (online + offline): memoria si ya está
			-- cargada (p. ej. alguien la tiene abierta ahora mismo), si no BD.
			-- Se suma tanto al total global como al saldo de su dueño.
			for _, job in ipairs(lockerJobs) do
				local loadedInv = ix.item.inventories[job.invID]
				if (loadedInv) then
					local amount = SumLoadedInventory(loadedInv)
					totals.lockers = totals.lockers + amount
					if (perChar[job.charID]) then
						perChar[job.charID].amount = perChar[job.charID].amount + amount
					end
				else
					remaining = remaining + 1
					SumInventoryFromDB(job.invID, function(amount)
						totals.lockers = totals.lockers + amount
						if (perChar[job.charID]) then
							perChar[job.charID].amount = perChar[job.charID].amount + amount
						end
						finishOne()
					end)
				end
			end

			-- 2b. Inventario personal de OFFLINE: vía ix_inventories -> ix_items,
			-- excluyendo los inventoryID que ya sabemos son taquillas (2a).
			local lockerSet = {}
			for _, job in ipairs(lockerJobs) do lockerSet[job.invID] = true end

			for _, charID in ipairs(offlineIDs) do
				remaining = remaining + 1

				local invQ = mysql:Select("ix_inventories")
					invQ:Select("inventory_id")
					invQ:Where("character_id", charID)
					invQ:Callback(function(invResult)
						if (not istable(invResult) or #invResult == 0) then
							finishOne()
							return
						end

						local invIDs = {}
						for _, r in ipairs(invResult) do
							local iid = tonumber(r.inventory_id)
							if (iid and not lockerSet[iid]) then
								invIDs[#invIDs + 1] = iid
							end
						end

						if (#invIDs == 0) then
							finishOne()
							return
						end

						local subRemaining = #invIDs
						for _, iid in ipairs(invIDs) do
							SumInventoryFromDB(iid, function(amount)
								totals.offline = totals.offline + amount
								if (perChar[charID]) then
									perChar[charID].amount = perChar[charID].amount + amount
								end
								subRemaining = subRemaining - 1
								if (subRemaining <= 0) then finishOne() end
							end)
						end
					end)
				invQ:Execute()
			end

			-- Consume el centinela inicial: si toda la cadena fue síncrona, aquí
			-- ya llega a 0 y dispara el callback; si es async, solo lo baja y las
			-- consultas reales lo siguen bajando hasta 0.
			finishOne()
		end)
	query:Execute()
end
