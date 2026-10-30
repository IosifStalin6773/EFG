local PLUGIN = PLUGIN

if (!SERVER) then return end

local TC = ix.efg.testcycle

TC.buffer = TC.buffer or {}

local MAX_BUFFER = 500

-- ─── Estado del personaje para el registro y las comprobaciones ─────────────
local function countItems(inv)
	if (!inv) then return 0 end

	local n = 0
	for _ in pairs(inv:GetItems(true)) do n = n + 1 end

	return n
end

local function secureInv(character)
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

	for _, item in pairs(eqInv and eqInv:GetItems(true) or {}) do
		if (item.isSecureContainer) then
			return ix.item.inventories[item:GetData("id") or 0], item
		end
	end
end

function TC.Snapshot(character)
	local raids = ix.plugin.Get("efg_raids")
	local stash = ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character)
	local secure = secureInv(character)

	return {
		carried = raids and #raids:GetCarriedItems(character) or 0,
		secure = countItems(secure),
		stash = countItems(stash),
		stats = table.Copy(character:GetData("efgStats", {})),
		xp = character.GetEFGXP and character:GetEFGXP() or 0,
		inRaid = character:GetData("efgInRaid"),
	}
end

-- ─── Registro ────────────────────────────────────────────────────────────────
-- Cada línea: fecha | CurTime | evento | jugador (#personaje, bando) | texto | estado
function TC.Log(kind, client, text)
	if (!ix.config.Get("efgCycleLog", true)) then return end

	local who, state = "-", ""
	local character = IsValid(client) and client:GetCharacter()

	if (character) then
		local snap = TC.Snapshot(character)
		who = ("%s (#%d, %s)"):format(client:Name(), character:GetID(), client:GetRaidSide() or "fuera")
		state = (" | encima=%d seguro=%d alijo=%d xp=%d"):format(snap.carried, snap.secure, snap.stash, snap.xp)
	end

	local line = ("%s [%9.2f] %-9s | %s | %s%s"):format(os.date("%Y-%m-%d %H:%M:%S"), CurTime(), kind, who, text or "", state)

	TC.buffer[#TC.buffer + 1] = {client = IsValid(client) and client:SteamID64() or nil, line = line}
	if (#TC.buffer > MAX_BUFFER) then table.remove(TC.buffer, 1) end

	if (ix.config.Get("efgCycleLogFile", true)) then
		file.CreateDir("efg/ciclo")
		file.Append("efg/ciclo/" .. os.date("%Y-%m-%d") .. ".txt", line .. "\n")
	end

	ServerLog("[EFG ciclo] " .. line .. "\n")
end

function TC.GetLines(target, amount)
	local id = IsValid(target) and target:SteamID64() or nil
	local out = {}

	for i = #TC.buffer, 1, -1 do
		local entry = TC.buffer[i]

		if (!id or entry.client == id) then
			table.insert(out, 1, entry.line)
			if (#out >= amount) then break end
		end
	end

	return out
end

function PLUGIN:EFGRaidStarted(client, side)
	TC.Log("RAID", client, "Despliegue como " .. string.upper(side or "?"))
end

function PLUGIN:EFGRaidEnded(client, side, reason, runThrough)
	TC.Log(string.upper(reason or "FIN"), client, ("Fin de raid (%s)%s"):format(side or "?", runThrough and ", Run Through" or ""))
end

function PLUGIN:EFGRaidAbandoned(client, character, side)
	TC.Log("ABANDONO", client, "Personaje que se quedó en raid (" .. tostring(side) .. "): pierde el equipo")
end

function PLUGIN:PlayerDeath(client, inflictor, attacker)
	if (!client:GetCharacter()) then return end

	local by = IsValid(attacker) and attacker != client and (attacker:IsPlayer() and attacker:Name() or attacker:GetClass()) or "sí mismo/mundo"
	TC.Log("MUERTE", client, (client:InRaid() and "En raid" or "Fuera de raid") .. ", por " .. by)
end

local function isStash(inv)
	return inv and inv.vars and inv.vars.isEFGStash
end

function PLUGIN:OnItemTransferred(item, curInv, newInv)
	local into, out = isStash(newInv), isStash(curInv)
	if (into == out) then return end

	local inv = into and newInv or curInv
	local character = inv.owner and ix.char.loaded[inv.owner]
	local client = character and character:GetPlayer()

	TC.Log("ALIJO", client, (into and "+ " or "- ") .. ((item.GetName and item:GetName()) or item.uniqueID) .. " #" .. item:GetID())
end

function PLUGIN:EFGInsuranceReturned(client, character, returned, lost)
	TC.Log("SEGURO", client, ("Devueltos %d, perdidos %d"):format(returned or 0, lost or 0))
end

function PLUGIN:EFGXPGained(character, amount, kind)
	TC.Log("XP", character:GetPlayer(), ("+%d (%s)"):format(amount or 0, tostring(kind)))
end

-- ─── /EFGTestCiclo ───────────────────────────────────────────────────────────
-- Helix da a los bots un personaje en memoria (GM:PlayerInitialSpawn). Aquí se
-- le añaden equipo y alijo también en memoria, se le hace pasar por raids con
-- las funciones reales de efg_raids y se comprueba el estado tras cada paso.
local function report(text)
	local test = TC.test
	TC.Log("TEST", test and test.bot, text)

	if (test and IsValid(test.admin)) then
		test.admin:PrintMessage(HUD_PRINTCONSOLE, "[EFGTestCiclo] " .. text)
	end
end

local function check(name, ok, detail)
	local test = TC.test
	if (!test) then return end

	test.results[#test.results + 1] = {name, ok}
	report((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. detail .. ")") or ""))
end

local function stat(snap, key)
	return snap.stats[key] or 0
end

function PLUGIN:InventoryItemAdded(oldInv, newInv, item)
	local test = TC.test

	if (test and !oldInv and newInv and test.charID and newInv.owner == test.charID) then
		test.created[#test.created + 1] = item:GetID()
	end
end

function TC.Finish()
	local test = TC.test
	if (!test) then return end

	-- borrar lo creado (primero el contenido, luego los contenedores)
	for i = #test.created, 1, -1 do
		local item = ix.item.instances[test.created[i]]
		if (item) then item:Remove() end
	end

	for _, id in ipairs(test.inventories or {}) do
		ix.item.inventories[id] = nil
	end

	local passed, failed = 0, 0
	for _, result in ipairs(test.results) do
		if (result[2]) then passed = passed + 1 else failed = failed + 1 end
	end

	report(("Resultado: %d PASS, %d FAIL en %.1f s"):format(passed, failed, CurTime() - test.start))

	if (IsValid(test.admin)) then
		test.admin:Notify(("EFGTestCiclo: %d PASS, %d FAIL. Detalle en la consola y en /EFGLogCiclo."):format(passed, failed))
	end

	if (IsValid(test.bot)) then test.bot:Kick("Fin de EFGTestCiclo") end

	TC.test = nil
end

local function abort(reason)
	check("Prueba completa", false, reason)
	TC.Finish()
end

local function runSteps(steps, index)
	local test = TC.test
	if (!test) then return end

	if (index > #steps) then
		TC.Finish()
		return
	end

	timer.Simple(ix.config.Get("efgCycleStepDelay", 2), function()
		if (!TC.test or TC.test != test) then return end
		if (!IsValid(test.bot) or !test.bot:GetCharacter()) then return abort("el bot desapareció") end

		local ok, err = pcall(steps[index][2], test)

		if (!ok) then
			check(steps[index][1], false, "error Lua: " .. tostring(err))
		end

		runSteps(steps, index + 1)
	end)
end

local function respawn(test)
	if (IsValid(test.bot) and !test.bot:Alive()) then test.bot:Spawn() end
end

local function addLoot(test)
	test.character:GetInventory():Add(ix.config.Get("efgCycleTestItem", "analgin"))
end

local function deploy(test)
	local raids = ix.plugin.Get("efg_raids")
	raids:StartRaid(test.bot, "pmc", test.bot:GetPos(), test.bot:EyeAngles(), {})
	check("Despliegue: marca efgInRaid", test.character:GetData("efgInRaid") == "pmc" and test.bot:InRaid())
end

-- comprobaciones comunes tras perder la raid (muerte, MIA, abandono)
local function checkLost(test, label, before, statKey)
	local after = TC.Snapshot(test.character)

	check(label .. ": fuera de raid", after.inRaid == nil and !test.bot:InRaid())
	check(label .. ": " .. statKey .. " +1", stat(after, statKey) == stat(before, statKey) + 1,
		stat(before, statKey) .. " → " .. stat(after, statKey))
	check(label .. ": pierde lo que llevaba encima", after.carried == 0, "quedan " .. after.carried)
	check(label .. ": conserva el contenedor seguro", after.secure == before.secure, before.secure .. " → " .. after.secure)
	check(label .. ": alijo intacto", after.stash == before.stash, before.stash .. " → " .. after.stash)
end

local function buildSteps(scenario)
	local steps = {}
	local function add(name, fn) steps[#steps + 1] = {name, fn} end
	local all = scenario == "todo"

	add("Preparar contenedor seguro", function(test)
		local secure = secureInv(test.character)
		check("Preparar: contenedor seguro creado", secure != nil)

		if (secure) then secure:Add(ix.config.Get("efgCycleTestItem", "analgin")) end
		addLoot(test)
	end)

	if (all or scenario == "extract") then
		add("Extracción: despliegue", function(test)
			test.before = TC.Snapshot(test.character)
			deploy(test)
		end)

		add("Extracción: extraer", function(test)
			ix.plugin.Get("efg_raids"):EndRaid(test.bot, "extract", {name = "PRUEBA"})

			local after = TC.Snapshot(test.character)
			check("Extracción: fuera de raid", after.inRaid == nil and !test.bot:InRaid())
			check("Extracción: survived +1", stat(after, "survived") == stat(test.before, "survived") + 1)
			check("Extracción: conserva lo que llevaba", after.carried == test.before.carried, test.before.carried .. " → " .. after.carried)
			check("Extracción: XP de supervivencia", after.xp > test.before.xp, test.before.xp .. " → " .. after.xp)
		end)

		add("Alijo: guardar el botín", function(test)
			local stash = ix.strongbox.GetStash(test.character)
			local before = TC.Snapshot(test.character)
			local item

			for _, candidate in pairs(test.character:GetInventory():GetItems(true)) do
				if (candidate.uniqueID == ix.config.Get("efgCycleTestItem", "analgin")) then item = candidate break end
			end

			if (!item) then return check("Alijo: hay botín que guardar", false) end

			local x, y = stash:FindEmptySlot(item.width, item.height)
			local moved = x and item:Transfer(stash:GetID(), x, y)
			local after = TC.Snapshot(test.character)

			check("Alijo: el objeto entra en el alijo", moved and item.invID == stash:GetID())
			check("Alijo: alijo +1", after.stash == before.stash + 1, before.stash .. " → " .. after.stash)
		end)
	end

	if (all or scenario == "death") then
		add("Muerte: botín y despliegue", function(test)
			addLoot(test)
			timer.Simple(0.5, function()
				if (TC.test != test) then return end
				test.before = TC.Snapshot(test.character)
				deploy(test)
			end)
		end)

		add("Muerte: matar al bot", function(test)
			test.bot:Kill()
		end)

		add("Muerte: comprobar", function(test)
			checkLost(test, "Muerte", test.before, "killed")
			respawn(test)
		end)
	end

	if (all or scenario == "mia") then
		add("MIA: botín y despliegue", function(test)
			respawn(test)
			addLoot(test)
			timer.Simple(0.5, function()
				if (TC.test != test) then return end
				test.before = TC.Snapshot(test.character)
				deploy(test)
			end)
		end)

		add("MIA: agotar el tiempo", function(test)
			local raid = ix.plugin.Get("efg_raids").raiders[test.bot]
			check("MIA: raid activa", raid != nil)
			if (raid) then raid.endTime = CurTime() - 1 end
		end)

		add("MIA: comprobar", function(test)
			checkLost(test, "MIA", test.before, "mia")
			respawn(test)
		end)
	end

	if (all or scenario == "abandon") then
		add("Abandono: botín y despliegue", function(test)
			respawn(test)
			addLoot(test)
			timer.Simple(0.5, function()
				if (TC.test != test) then return end
				test.before = TC.Snapshot(test.character)
				deploy(test)
			end)
		end)

		-- lo mismo que pasa al volver a cargar un personaje que se quedó en raid
		add("Abandono: recargar personaje", function(test)
			ix.plugin.Get("efg_raids"):PlayerLoadedCharacter(test.bot, test.character, test.character)
		end)

		add("Abandono: comprobar", function(test)
			checkLost(test, "Abandono", test.before, "mia")
		end)
	end

	return steps
end

-- equipo y alijo en memoria para el personaje del bot
local function prepareBot(test)
	local character = test.bot:GetCharacter()
	if (!character) then return abort("Helix no dio personaje al bot") end

	local id = character:GetID()
	test.character = character
	test.charID = id

	local function memInv(invID, w, h)
		local inv = ix.inventory.Create(w, h, invID)
		inv.noSave = true
		inv:SetOwner(id)
		test.inventories[#test.inventories + 1] = invID
		return inv
	end

	local eqInv = memInv(id + 1000, ix.EQUIP_INV_W or 20, ix.EQUIP_INV_H or 10)
	eqInv.vars.isEquipment = true
	character:SetData("equipInvID", eqInv:GetID())

	local stash = memInv(id + 2000, 10, 20)
	stash.vars.isContainer = true
	stash.vars.isEFGStash = true
	character:SetData("strongbox_stash", {id = stash:GetID(), height = 20})

	local ok, err = eqInv:Add("secure_alpha")
	if (!ok) then return abort("no se pudo dar el contenedor seguro: " .. tostring(err)) end

	report(("Bot %s listo (personaje #%d). Escenario: %s"):format(test.bot:Name(), id, test.scenario))
	runSteps(buildSteps(test.scenario), 1)
end

function TC.StartTest(admin, scenario)
	if (TC.test) then
		admin:Notify("Ya hay una prueba del ciclo en marcha.")
		return
	end

	if (game.SinglePlayer()) then
		admin:Notify("EFGTestCiclo necesita un servidor (no partida de un jugador) para crear el bot.")
		return
	end

	if (!ix.plugin.Get("efg_raids") or !ix.strongbox or !ix.GetEquipInventory) then
		admin:Notify("Faltan efg_raids, strongbox o ix_invkey.")
		return
	end

	if (player.GetCount() >= game.MaxPlayers()) then
		admin:Notify("No queda hueco en el servidor para el bot.")
		return
	end

	local bot = player.CreateNextBot("EFG_Test")

	if (!IsValid(bot)) then
		admin:Notify("No se pudo crear el bot.")
		return
	end

	TC.test = {admin = admin, bot = bot, scenario = scenario, results = {}, created = {}, inventories = {}, start = CurTime()}
	report("Inicio de la prueba (" .. scenario .. ")")

	timer.Simple(1, function()
		if (TC.test and TC.test.bot == bot) then prepareBot(TC.test) end
	end)
end

function PLUGIN:PlayerDisconnected(client)
	local test = TC.test

	if (test and (client == test.admin)) then
		test.admin = nil
	end
end
