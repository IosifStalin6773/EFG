local PLUGIN = PLUGIN

local function isDizzy()
	local client = LocalPlayer()
	return IsValid(client) and client:GetNetVar("drogaMareo", 0) > CurTime()
end

local function isDrunk()
	local client = LocalPlayer()
	return IsValid(client) and client:GetNetVar("drogaAlcohol", 0) > CurTime()
end

-- Vista nublada del narcótico casero: desenfoque leve y colores apagados, sin
-- el balanceo de cámara del mareo (el narcótico atonta, no marea).
hook.Add("RenderScreenspaceEffects", "ixDrogas_narcoticoEffect", function()
	local client = LocalPlayer()
	if (!IsValid(client) or client:GetNetVar("drogaNarcotico", 0) <= CurTime()) then return end

	local pulse = 0.5 + 0.5 * math.sin(CurTime() * 0.9)

	DrawSharpen(-1 - 0.4 * pulse, 2.5)

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.01,
		["$pp_colour_contrast"] = 0.95,
		["$pp_colour_colour"] = 0.75,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})
end)

-- Desaturación pulsante y desenfoque de movimiento para simular el mareo.
hook.Add("RenderScreenspaceEffects", "ixDrogas_mareoEffect", function()
	if (!isDizzy()) then return end

	local t = CurTime()
	local pulse = 0.5 + 0.5 * math.sin(t * 1.5)

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast"] = 1 - 0.15 * pulse,
		["$pp_colour_colour"] = 0.4 + 0.2 * pulse,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})

	DrawMotionBlur(0.45 + 0.2 * math.sin(t * 2), 0.85, 0.012)
end)

-- Balanceo de cámara (roll y FOV) para reforzar la sensación de vértigo.
hook.Add("CalcView", "ixDrogas_mareoView", function(client, pos, ang, fov)
	if (!isDizzy()) then return end

	local t = CurTime()

	return {
		origin = pos,
		angles = Angle(ang.p + math.sin(t * 1.1) * 1.5, ang.y, ang.r + math.sin(t * 1.5) * 4),
		fov    = fov + math.sin(t * 0.8) * 3,
	}
end)

-- Efecto de ebriedad: tonos cálidos y desenfoque suave.
hook.Add("RenderScreenspaceEffects", "ixDrogas_alcoholEffect", function()
	if (!isDrunk()) then return end

	local t = CurTime()
	local pulse = 0.5 + 0.5 * math.sin(t * 0.8)

	DrawColorModify({
		["$pp_colour_addr"] = 0.01 * pulse,
		["$pp_colour_addg"] = 0.005 * pulse,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = 0.02 * pulse,
		["$pp_colour_contrast"] = 1 - 0.05 * pulse,
		["$pp_colour_colour"] = 0.85 + 0.15 * pulse,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})

	DrawMotionBlur(0.3 + 0.15 * math.sin(t * 1.2), 0.8, 0.01)
end)

-- Tambaleo de cámara lento y pesado, propio de la borrachera.
hook.Add("CalcView", "ixDrogas_alcoholView", function(client, pos, ang, fov)
	if (!isDrunk()) then return end

	local t = CurTime()

	return {
		origin = pos,
		angles = Angle(
			ang.p + math.sin(t * 0.7) * 0.8,
			ang.y + math.cos(t * 0.5) * 0.6,
			ang.r + math.sin(t * 0.9) * 2.5
		),
		fov = fov + math.sin(t * 0.6) * 1.5,
	}
end)
