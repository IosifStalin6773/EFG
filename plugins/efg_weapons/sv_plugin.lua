local PLUGIN = PLUGIN

if (!SERVER) then return end

local WEP = ix.efg.weapons

-- ─── Disparos: se detectan por la bajada del cargador ────────────────────────
-- Funciona igual con balas físicas de ARC9 o con FireBullets.
local function weaponItem(client, weapon)
	return ix.arc9 and ix.arc9.GetWeaponItem and ix.arc9.GetWeaponItem(client, weapon) or weapon.ixItem
end

local function rollType()
	local total = 0
	for _, m in pairs(WEP.malfunctions) do total = total + m.weight end

	local pick = math.random() * total

	for id, m in pairs(WEP.malfunctions) do
		pick = pick - m.weight
		if (pick <= 0) then return id end
	end

	return "jam"
end

local function jam(client, weapon)
	local kind = rollType()

	weapon.efgMalf = kind
	weapon:SetNextPrimaryFire(CurTime() + 3600)
	client:SetNetVar("efgMalf", kind)
	client:EmitSound("weapons/pistol/pistol_empty.wav", 70)
	client:Notify("¡" .. WEP.malfunctions[kind].name .. "! Pulsa recargar para arreglarlo.")
end

-- Arreglar el fallo (recargar con el arma averiada, cl_plugin)
concommand.Add("efg_arreglar", function(client)
	if (!IsValid(client) or !client:Alive()) then return end

	local weapon = client:GetActiveWeapon()
	local kind = IsValid(weapon) and weapon.efgMalf
	if (!kind or (client.efgFixing or 0) > CurTime()) then return end

	local seconds = WEP.malfunctions[kind].seconds * ix.config.Get("efgJamSeconds", 2.5) / 2.5
	client.efgFixing = CurTime() + seconds
	client:SetNetVar("efgMalfFix", CurTime() + seconds)
	client:EmitSound("weapons/smg1/switch_single.wav", 65)

	timer.Simple(seconds, function()
		if (!IsValid(client)) then return end

		client:SetNetVar("efgMalfFix", nil)

		if (IsValid(weapon) and weapon.efgMalf == kind and client:GetActiveWeapon() == weapon) then
			weapon.efgMalf = nil
			weapon:SetNextPrimaryFire(CurTime() + 0.2)
			client:SetNetVar("efgMalf", nil)

			-- el fallo de disparo y la doble alimentación pierden la bala de la recámara
			if ((kind == "misfire" or kind == "doublefeed") and weapon:Clip1() > 0) then
				weapon:SetClip1(weapon:Clip1() - 1)
			end

			client:EmitSound("weapons/ar2/ar2_reload_push.wav", 65)
		end
	end)
end)

local function onShot(client, weapon, shots)
	local item = weaponItem(client, weapon)
	if (!WEP.IsFirearm(item)) then return end

	-- sobrecalentamiento (Weapon_overheating): más desgaste y más fallos
	weapon.efgHeat = math.min(100, (weapon.efgHeat or 0) + ix.config.Get("efgHeatPerShot", 1.2) * shots)
	weapon:SetNW2Float("efgHeat", weapon.efgHeat)

	local heatMult = weapon.efgHeat > 70 and (1 + (weapon.efgHeat - 70) / 30 * 2) or 1

	local loss = ix.config.Get("efgWeaponWearPerShot", 0.03) * shots * heatMult
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

	if (durability < threshold or heatMult > 1) then
		local chance = math.max(0, threshold - durability) / math.max(threshold, 1) * ix.config.Get("efgJamMaxChance", 4) / 100
		chance = math.max(chance, 0.002) * heatMult

		if (math.random() < chance * shots) then
			jam(client, weapon)
		end
	end
end

local nextCool = 0

function PLUGIN:Think()
	if (nextCool <= CurTime()) then
		nextCool = CurTime() + 0.5

		local cool = ix.config.Get("efgHeatCooling", 4) * 0.5

		for _, weapon in ipairs(ents.FindByClass("arc9_*")) do
			if ((weapon.efgHeat or 0) > 0) then
				weapon.efgHeat = math.max(0, weapon.efgHeat - cool)
				weapon:SetNW2Float("efgHeat", weapon.efgHeat)
			end
		end
	end

	for _, client in ipairs(player.GetAll()) do
		local weapon = client:GetActiveWeapon()

		-- al cambiar de arma se ve el fallo de la nueva (o ninguno)
		local malf = IsValid(weapon) and weapon.efgMalf or nil
		if (client:GetNetVar("efgMalf") != malf) then
			client:SetNetVar("efgMalf", malf)
		end

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
