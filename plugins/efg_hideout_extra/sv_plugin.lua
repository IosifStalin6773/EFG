local PLUGIN = PLUGIN

if (!SERVER) then return end

local hideout = ix.efg.hideout

local function stashAdd(character, uniqueID, data)
	local stash = ix.strongbox and ix.strongbox.GetStash(character)
	return stash and ix.item.list[uniqueID] and stash:Add(uniqueID, 1, data)
end

-- ─── Generador ──────────────────────────────────────────────────────────────
function PLUGIN:GeneratorCommand(client, action)
	local character = client:GetCharacter()
	if (hideout.GetLevel(character, "generator") <= 0) then return "No tienes generador." end

	if (action == "repostar") then
		local can = character:GetInventory():HasItem("gasolina")
		if (!can) then return "Necesitas gasolina." end

		can:Remove()
		character:SetData("efgFuel", math.min(100, character:GetData("efgFuel", 0) + 10))
	end

	return ("Combustible: %.1f/100 · %s"):format(character:GetData("efgFuel", 0),
		hideout.HasPower(character) and "con corriente" or "SIN CORRIENTE (la producción se detiene)")
end

-- ─── Granja de bitcoin ──────────────────────────────────────────────────────
function PLUGIN:BitcoinCommand(client, action)
	local character = client:GetCharacter()
	local level = hideout.GetLevel(character, "bitcoin")
	if (level <= 0) then return "No tienes granja de bitcoin." end

	local slots = hideout.byID.bitcoin.gpuSlots[level]
	local gpus = character:GetData("efgGPUs", 0)

	if (action == "gpu") then
		if (gpus >= slots) then return "La granja está llena (" .. slots .. " tarjetas)." end

		local gpu = character:GetInventory():HasItem("tarjeta_grafica")
		if (!gpu) then return "Necesitas una tarjeta gráfica." end

		gpu:Remove()
		character:SetData("efgGPUs", gpus + 1)
		gpus = gpus + 1
	elseif (action == "recoger") then
		local coins = math.floor(character:GetData("efgBTC", 0))
		if (coins <= 0) then return "Aún no hay bitcoins." end

		local given = 0

		for _ = 1, coins do
			if (stashAdd(character, "bitcoin", {fir = true})) then given = given + 1 end
		end

		character:SetData("efgBTC", character:GetData("efgBTC", 0) - given)

		return given .. " bitcoin(s) enviados al alijo."
	end

	return ("Tarjetas: %d/%d · producido: %.2f BTC (máx. 3)"):format(gpus, slots, character:GetData("efgBTC", 0))
end

-- ─── Scav Case ──────────────────────────────────────────────────────────────
-- Botín por coste: {probabilidad de cada objeto, número de objetos}
local scavCaseTiers = {
	[2500] = {count = {1, 3}, pool = {"water", "canned", "venda_aseptica", "ai2", "ammo_545x39_ps", "ammo_9x18_pst", "tornillos", "cobre"}},
	[15000] = {count = {2, 4}, pool = {"ifak", "calok", "ammo_545x39_bt", "ammo_556x45_m855", "stim_morphine", "circuitos", "bateria", "key_dorms_214"}},
	[95000] = {count = {2, 5}, pool = {"grizzly", "stim_propital", "stim_etgc", "ammo_545x39_bs", "ammo_762x39_bp", "tarjeta_grafica", "key_dorms_314", "key_labs_access", "bitcoin"}}
}

function PLUGIN:ScavCaseCommand(client, amount)
	local character = client:GetCharacter()
	if (hideout.GetLevel(character, "scav_case") <= 0) then return "No tienes Scav Case." end

	local running = character:GetData("efgScavCase")

	if (!amount) then
		if (!running) then return "El Scav Case está libre." end
		return ("El Scav vuelve en %d min."):format(math.max(0, math.ceil((running.ready - os.time()) / 60)))
	end

	if (running) then return "El Scav ya está fuera." end

	local tier = scavCaseTiers[amount]
	if (!tier) then return "Opciones: 2500, 15000 o 95000 rublos." end
	if (!character:HasMoney(amount)) then return "No tienes suficientes rublos." end

	character:TakeMoney(amount)
	character:SetData("efgScavCase", {ready = os.time() + ix.config.Get("efgScavCaseMinutes", 40) * 60, tier = amount})

	return "El Scav ha salido a buscar botín."
end

-- ─── Bucle por minuto: combustible, bitcoin, producción automática ──────────
local nextTick = 0

function PLUGIN:Think()
	if (nextTick > CurTime()) then return end
	nextTick = CurTime() + 60

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and hideout.GetLevel(character, "generator") > 0) then
			local fuel = character:GetData("efgFuel", 0)
			local mult = hideout.GetLevel(character, "solar") > 0 and 0.5 or 1

			if (fuel > 0) then
				character:SetData("efgFuel", math.max(0, fuel - ix.config.Get("efgFuelPerHour", 1) / 60 * mult))
			end

			if (hideout.HasPower(character)) then
				-- bitcoin (Bitcoin_Farm): más tarjetas, más rápido (con rendimiento decreciente)
				local gpus = character:GetData("efgGPUs", 0)

				if (gpus > 0 and hideout.GetLevel(character, "bitcoin") > 0) then
					local perMinute = (1 + (gpus - 1) * 0.041225) / (ix.config.Get("efgBitcoinHours", 4) * 60)
					character:SetData("efgBTC", math.min(3, character:GetData("efgBTC", 0) + perMinute))
				end

				-- recolector de agua y destilería
				for _, moduleID in ipairs({"water_collector", "booze"}) do
					local module = hideout.byID[moduleID]
					local level = hideout.GetLevel(character, moduleID)

					if (module and level > 0) then
						local key = "efgProd_" .. moduleID
						local progress = character:GetData(key, 0) + level

						if (progress >= module.produce.minutes) then
							progress = 0
							stashAdd(character, module.produce.item)
						end

						character:SetData(key, progress)
					end
				end
			end
		end

		-- vuelta del Scav Case
		local running = character and character:GetData("efgScavCase")

		if (running and running.ready <= os.time() and !client:InRaid()) then
			local tier = scavCaseTiers[running.tier] or scavCaseTiers[2500]
			local count = math.random(tier.count[1], tier.count[2])

			for _ = 1, count do
				stashAdd(character, tier.pool[math.random(#tier.pool)], {fir = true})
			end

			character:SetData("efgScavCase", nil)
			client:Notify("El Scav Case ha vuelto: " .. count .. " objetos en tu alijo.")
		end
	end
end
