local PLUGIN = PLUGIN

if (!SERVER) then return end

local WEP = ix.efg.weapons

-- ─── Disparos: se detectan por la bajada del cargador ────────────────────────
-- Funciona igual con balas físicas de ARC9 o con FireBullets.
local function weaponItem(client, weapon)
	return ix.arc9 and ix.arc9.GetWeaponItem and ix.arc9.GetWeaponItem(client, weapon) or weapon.ixItem
end

local function jam(client, weapon)
	local seconds = ix.config.Get("efgJamSeconds", 2.5)

	weapon:SetNextPrimaryFire(CurTime() + seconds)
	client:EmitSound("weapons/pistol/pistol_empty.wav", 70)
	client:Notify("¡El arma se ha encasquillado!")
end

local function onShot(client, weapon, shots)
	local item = weaponItem(client, weapon)
	if (!WEP.IsFirearm(item)) then return end

	local loss = ix.config.Get("efgWeaponWearPerShot", 0.03) * shots
	loss = loss * (hook.Run("AdjustArmorDurabilityLoss", client, client:GetCharacter()) or 1) -- Mantenimiento

	-- los decimales se guardan en la instancia; se escribe en BD al bajar un punto entero
	local before = WEP.GetDurability(item) - (item.efgWearAcc or 0)
	local durability = math.max(0, before - loss)

	if (math.floor(durability) < math.floor(before)) then
		item:SetData("durability", math.floor(durability))
		item.efgWearAcc = math.floor(durability) - durability
	else
		item.efgWearAcc = (item.efgWearAcc or 0) + loss
	end

	local threshold = ix.config.Get("efgJamThreshold", 70)

	if (durability < threshold) then
		local chance = (threshold - durability) / math.max(threshold, 1) * ix.config.Get("efgJamMaxChance", 4) / 100

		if (math.random() < chance * shots) then
			jam(client, weapon)
		end
	end
end

function PLUGIN:Think()
	for _, client in ipairs(player.GetAll()) do
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and client:Alive()) then
			local clip = weapon:Clip1()

			if (client.efgLastWeapon == weapon and client.efgLastClip and clip < client.efgLastClip and clip >= 0) then
				onShot(client, weapon, client.efgLastClip - clip)
			end

			client.efgLastWeapon = weapon
			client.efgLastClip = clip
		end
	end
end

-- ─── Brazos heridos: netvar para el StartCommand compartido ────────────────
local nextArms = 0

function PLUGIN:Tick()
	if (nextArms > CurTime()) then return end
	nextArms = CurTime() + 0.5

	local health = ix.efg.health
	if (!health) then return end

	for _, client in ipairs(player.GetAll()) do
		if (client.efgHP and client:Alive()) then
			local hp = health.GetHP(client)
			local out = (hp.larm or 1) <= 0 and (hp.rarm or 1) <= 0 and !health.HasPainkiller(client)

			if (client:GetNetVar("efgArmsOut") != (out or nil)) then
				client:SetNetVar("efgArmsOut", out or nil)
			end
		end
	end
end
