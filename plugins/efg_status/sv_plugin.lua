local PLUGIN = PLUGIN

if (!SERVER) then return end

local STATUS = ix.efg.status

-- Daño repartido por todo el cuerpo según los PV de cada parte (como el daño
-- de área de efg_health). Devuelve true si mata.
local function damageBody(client, amount)
	local health = ix.efg.health
	local killed = false

	for _, part in ipairs(health.parts) do
		killed = health.DamagePart(client, part.id, amount * part.max / health.total) or killed
	end

	return killed
end

-- Los decimales se acumulan y se aplican en pasos enteros (needs redondea).
local function step(client, key, perSecond)
	client.efgNeedAcc = client.efgNeedAcc or {}

	local acc = (client.efgNeedAcc[key] or 0) + perSecond
	local whole = acc >= 0 and math.floor(acc) or math.ceil(acc)

	client.efgNeedAcc[key] = acc - whole

	return whole
end

local function setNeed(character, getter, setter, delta)
	if (delta == 0 or !character[getter]) then return end

	character[setter](character, math.Clamp((character[getter](character) or 100) + delta, 0, 100))
end

function STATUS.Contuse(client, seconds)
	seconds = seconds or ix.config.Get("efgContusionTime", 15)
	if (seconds <= 0) then return end

	local untilTime = math.max(client:GetNetVar("efgContusion", 0), CurTime() + seconds)

	client:SetNetVar("efgContusion", untilTime)
	client:SetDSP(ix.config.Get("efgContusionDSP", 35), false)
	client.efgContusionUntil = untilTime
end

-- Conmoción: explosión cercana o bala en la cabeza parada por el casco
function PLUGIN:PostEntityTakeDamage(client, dmginfo, took)
	if (!took or !IsValid(client) or !client:IsPlayer() or !client:Alive()) then return end

	if (dmginfo:IsExplosionDamage() and dmginfo:GetDamage() >= 10) then
		STATUS.Contuse(client)
	elseif (dmginfo:IsBulletDamage() and client:LastHitGroup() == HITGROUP_HEAD and client.efgArmorStopped == CurTime()) then
		STATUS.Contuse(client, ix.config.Get("efgContusionTime", 15) * 0.5)
	end
end

local nextTick = 0

function PLUGIN:Think()
	if (nextTick > CurTime()) then return end
	nextTick = CurTime() + 1

	local health = ix.efg.health
	if (!health) then return end

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (!character or !client:Alive() or !client.efgHP) then continue end

		-- needs ya no desgasta: el ritmo de EFT lo lleva este plugin
		local timerID = "ixPrimaryNeeds." .. client:AccountID()
		if (timer.Exists(timerID)) then timer.Remove(timerID) end

		local hp = health.GetHP(client)
		local status = health.GetStatus(client)
		local inRaid = client.InRaid and client:InRaid()

		if (inRaid) then
			local mult = (hp.stomach or 1) <= 0 and ix.config.Get("efgStomachDrainMult", 2) or 1
			mult = mult * (hook.Run("AdjustNeedsConsume", client, character) or 1)

			setNeed(character, "GetSaturation", "SetSaturation", -step(client, "water", ix.config.Get("efgHydrationDrain", 1) * mult / 60))
			setNeed(character, "GetSatiety", "SetSatiety", -step(client, "energy", ix.config.Get("efgEnergyDrain", 0.8) * mult / 60))

			local killed = false

			if ((character:GetSaturation() or 100) <= 0) then
				killed = damageBody(client, ix.config.Get("efgDehydrationDamage", 30) / 60) or killed
			end

			if ((character:GetSatiety() or 100) <= 0) then
				killed = damageBody(client, ix.config.Get("efgExhaustionDamage", 20) / 60) or killed
			end

			if (killed) then
				client:Kill()
				continue
			end
		else
			local regen = ix.config.Get("efgNeedsRegen", 1) * (hook.Run("EFGGetRegenMultiplier", client) or 1) / 60

			setNeed(character, "GetSaturation", "SetSaturation", step(client, "water", regen))
			setNeed(character, "GetSatiety", "SetSatiety", step(client, "energy", regen))
		end

		-- pierna rota o destruida: más lento (SetupMove en sh_plugin)
		local legHurt = status.fracture.lleg or status.fracture.rleg or (hp.lleg or 1) <= 0 or (hp.rleg or 1) <= 0
		if (client:GetNetVar("efgLegHurt") != (legHurt or nil)) then
			client:SetNetVar("efgLegHurt", legHurt or nil)
		end

		if (client.efgContusionUntil and client.efgContusionUntil <= CurTime()) then
			client.efgContusionUntil = nil
			client:SetDSP(0, false)
		end
	end
end

local function clear(client)
	client.efgNeedAcc = nil
	client.efgContusionUntil = nil
	client:SetNetVar("efgContusion", nil)
	client:SetNetVar("efgLegHurt", nil)
	client:SetDSP(0, false)
end

function PLUGIN:PlayerDeath(client)
	clear(client)
end

function PLUGIN:EFGRaidEnded(client)
	clear(client)
end
