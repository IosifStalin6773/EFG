-- Inercia de movimiento y temblor de brazos, de EFT Realism (Tarkov Movement):
-- arrancar y frenar no es instantáneo, el lateral al esprintar es torpe y con
-- un brazo roto o destruido (o sin aguante) la mira se mueve.

local inertia = CreateClientConVar("efg_inercia", "1", true, false, "Inercia al moverse (0 = desactivada, 2 = el doble de rápida)", 0, 3)

local smF, smS, swayP, swayY = 0, 0, 0, 0
local lastT = SysTime()

local function approach(cur, target, step)
	if (cur < target) then return math.min(cur + step, target) end
	return math.max(cur - step, target)
end

-- brazos rotos o destruidos (0, 1 o 2) según la netvar efgHP
local function badArms(client)
	local data = client:GetNetVar("efgHP")
	if (!data) then return 0 end

	local count = 0

	for i, part in ipairs(ix.efg.health.parts) do
		local entry = data[i]
		if (part.arm and entry and (entry[1] <= 0 or bit.band(entry[2], 4) != 0)) then count = count + 1 end
	end

	return count
end

hook.Add("CreateMove", "efgInertia", function(cmd)
	local client = LocalPlayer()
	local now = SysTime()
	local dt = math.min(now - lastT, 0.1)
	lastT = now

	if (inertia:GetFloat() <= 0 or !IsValid(client) or !client:Alive() or client:GetMoveType() != MOVETYPE_WALK or !client:GetCharacter()) then
		smF, smS = cmd:GetForwardMove(), cmd:GetSideMove()
		return
	end

	local f, s = cmd:GetForwardMove(), cmd:GetSideMove()
	if (cmd:KeyDown(IN_SPEED)) then s = s * 0.5 end

	local rate = 10000 * inertia:GetFloat() * dt
	smF = approach(smF, f, math.abs(f) < math.abs(smF) and rate * 1.6 or rate)
	smS = approach(smS, s, math.abs(s) < math.abs(smS) and rate * 1.6 or rate)
	cmd:SetForwardMove(smF)
	cmd:SetSideMove(smS)

	-- temblor de la mira: brazos dañados y poco aguante (stm de Helix)
	local stamina = client:GetLocalVar("stm", 100) or 100
	local amp = badArms(client) * 0.5 + (1 - math.Clamp(stamina, 0, 100) / 100) * 0.35
	local t = CurTime()
	local p, y = math.sin(t * 1.3) * amp, math.sin(t * 0.9 + 1) * amp * 1.4
	local ang = cmd:GetViewAngles()
	ang.p = ang.p + (p - swayP)
	ang.y = ang.y + (y - swayY)
	swayP, swayY = p, y
	cmd:SetViewAngles(ang)
end)
