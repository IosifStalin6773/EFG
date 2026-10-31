local PLUGIN = PLUGIN

if (!SERVER) then return end

local FX = ix.efg.effects

local function sync(client)
	local list = {}

	for _, e in ipairs(client.efgEffects or {}) do
		list[#list + 1] = {e[1], e[2], e[3], e[4]}
	end

	client:SetNetVar("efgEffects", #list > 0 and list or nil)
end

-- Añade un efecto: dura `seconds` desde dentro de `delay` segundos
function FX.Add(client, id, seconds, strength, delay)
	client.efgEffects = client.efgEffects or {}

	local start = CurTime() + (delay or 0)
	table.insert(client.efgEffects, {id, start + seconds, strength or 1, start})

	if (id == "painkiller" and ix.efg.health) then
		timer.Simple(delay or 0, function()
			if (IsValid(client) and client:Alive()) then
				ix.efg.health.AddPainkiller(client, seconds)
			end
		end)
	end

	sync(client)
end

function FX.Remove(client, id)
	local list = client.efgEffects or {}

	for i = #list, 1, -1 do
		if (list[i][1] == id) then
			table.remove(list, i)
		end
	end

	sync(client)
end

function FX.Clear(client)
	client.efgEffects = nil
	client.efgSprintTime = nil
	sync(client)
end

function FX.ApplyStim(client, id)
	local stim = FX.stims[id]
	if (!stim) then return false end

	local list = stim[3]

	if (list == "random") then
		-- Obdolbos: cada efecto sale o no al azar (y a veces mata, como en EFT: no aquí)
		list = {}
		local pool = {"regen", "painkiller", "speed", "stamina", "tremor", "tunnel", "toxin", "water", "energy"}

		for _, id2 in ipairs(pool) do
			if (math.random() < 0.4) then
				local strength = ({regen = 1, speed = 0.1, stamina = 0.5, water = -20, energy = -20})[id2] or 1
				list[#list + 1] = {id2, strength, 0, math.random(60, 300)}
			end
		end
	end

	for _, e in ipairs(list) do
		FX.Add(client, e[1], e[4], e[2], e[3])
	end

	if (FX.Has(client, "antidote") or list[1] and list[1][1] == "antidote") then
		FX.Remove(client, "toxin")
		FX.Remove(client, "radiation")

		-- la intoxicación de needs (comida o agua en mal estado) también se cura
		if (client:GetNetVar("intoxicadoEnd", 0) > CurTime()) then
			client:SetNetVar("intoxicadoEnd", 0)
		end
	end

	return true
end

-- ─── Bucle por segundo ──────────────────────────────────────────────────────
local function damageBody(client, amount)
	local health = ix.efg.health
	local killed = false

	for _, part in ipairs(health.parts) do
		killed = health.DamagePart(client, part.id, amount * part.max / health.total) or killed
	end

	return killed
end

local function changeNeed(character, getter, setter, delta)
	if (!character[getter] or delta == 0) then return end
	character[setter](character, math.Clamp((character[getter](character) or 100) + delta, 0, 100))
end

local nextTick = 0

function PLUGIN:Think()
	if (nextTick > CurTime()) then return end
	nextTick = CurTime() + 1

	local now = CurTime()
	local health = ix.efg.health

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and client:Alive() and health and client.efgHP) then
			local list = client.efgEffects or {}
			local changed, killed = false, false

			for i = #list, 1, -1 do
				if (list[i][2] <= now) then
					table.remove(list, i)
					changed = true
				end
			end

			-- fatiga: correr sin parar agota (Status_effects#Fatigue)
			if (client:IsSprinting() and client:GetVelocity():Length2D() > 50) then
				client.efgSprintTime = (client.efgSprintTime or 0) + 1

				if (client.efgSprintTime >= 25 and !FX.Has(client, "fatigue")) then
					FX.Add(client, "fatigue", 45)
					FX.Add(client, "tunnel", 20)
					client.efgSprintTime = 0
					client:Notify("Estás fatigado.")
				end
			else
				client.efgSprintTime = math.max(0, (client.efgSprintTime or 0) - 2)
			end

			local regen = 0
			local hydration, energy = 0, 0

			for _, e in ipairs(list) do
				if (e[4] <= now) then
					local id, strength = e[1], e[3]

					if (id == "regen") then regen = regen + strength
					elseif (id == "toxin") then regen = regen - 0.5
					elseif (id == "radiation") then regen = regen - 0.15
					elseif (id == "water") then hydration = hydration + strength / 60
					elseif (id == "energy") then energy = energy + strength / 60
					elseif (id == "hemostatic") then
						if (next(health.GetStatus(client).bleed)) then
							health.StopBleeding(client, "all")
						end
					end
				end
			end

			if (regen > 0) then
				health.Heal(client, regen)
				changed = true
			elseif (regen < 0) then
				killed = damageBody(client, -regen)
				changed = true
			end

			-- hidratación y energía: se acumulan los decimales
			client.efgFXAcc = client.efgFXAcc or {0, 0}
			client.efgFXAcc[1] = client.efgFXAcc[1] + hydration
			client.efgFXAcc[2] = client.efgFXAcc[2] + energy

			for i, pair in ipairs({{"GetSaturation", "SetSaturation"}, {"GetSatiety", "SetSatiety"}}) do
				local whole = client.efgFXAcc[i] >= 0 and math.floor(client.efgFXAcc[i]) or math.ceil(client.efgFXAcc[i])

				if (whole != 0) then
					changeNeed(character, pair[1], pair[2], whole)
					client.efgFXAcc[i] = client.efgFXAcc[i] - whole
				end
			end

			if (changed) then
				sync(client)
			end

			if (killed) then
				health.Kill(client)
			elseif (regen != 0) then
				health.Sync(client)
			end
		end
	end
end

-- ─── Herida fresca: más sangrado en la zona curada (efg_health) ────────────
function PLUGIN:EFGBleedChanceMult(client, partID)
	if (FX.Has(client, "hemostatic")) then return 0 end

	for _, e in ipairs(client.efgEffects or {}) do
		if (e[1] == "freshwound" and e[3] == partID and e[2] > CurTime()) then
			return 2
		end
	end
end

function PLUGIN:EFGBleedStopped(client, partID)
	FX.Add(client, "freshwound", 120, partID)
end

-- ─── Alcohol: al consumir bebidas alcohólicas ──────────────────────────────
local ignoredActions = {take = true, drop = true, combine = true, Equip = true, EquipUn = true, efgSplit = true}

function PLUGIN:PlayerInteractItem(client, action, item)
	if (!IsValid(client) or !istable(item) or ignoredActions[action]) then return end

	for key, seconds in pairs(FX.alcohol) do
		if (item.uniqueID:find(key, 1, true)) then
			FX.Add(client, "alcohol", seconds)
			FX.Add(client, "painkiller", seconds / 2)
			FX.Add(client, "tremor", seconds)
			return
		end
	end
end

-- Toxinas (cuchillos de cultista, agua sucia…) y radiación: los aplican otros
-- plugins con ix.efg.effects.Add(client, "toxin", segundos)

function PLUGIN:PlayerDeath(client)
	FX.Clear(client)
end

function PLUGIN:EFGRaidEnded(client)
	-- los efectos de la raid se acaban al volver (el escondite cura)
	FX.Remove(client, "toxin")
	FX.Remove(client, "radiation")
	FX.Remove(client, "freshwound")
end

