
local PLUGIN = PLUGIN

local nauseaFlashEnd = 0
local NAUSEA_FLASH_DURATION = 1.5

net.Receive("ixNeedsNausea", function()
	nauseaFlashEnd = CurTime() + NAUSEA_FLASH_DURATION
end)

local function isIntoxicated()
	local client = LocalPlayer()
	return IsValid(client) and client:GetNetVar("intoxicadoEnd", 0) > CurTime()
end

-- Náusea breve al comer algo crudo: un golpe corto de desaturación y ligero
-- desenfoque, tanto si acaba en intoxicación real como si no.
hook.Add("RenderScreenspaceEffects", "ixNeeds_nauseaFlash", function()
	local remaining = nauseaFlashEnd - CurTime()
	if (remaining <= 0) then return end

	local t = math.Clamp(remaining / NAUSEA_FLASH_DURATION, 0, 1)

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0.01 * t,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.02 * t,
		["$pp_colour_contrast"] = 1 - 0.2 * t,
		["$pp_colour_colour"] = 1 - 0.5 * t,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})

	DrawMotionBlur(0.3 * t, 0.8, 0.01)
end)

-- Malestar prolongado por intoxicación: tinte verdoso y balanceo de cámara
-- mientras el efecto sigue activo.
hook.Add("RenderScreenspaceEffects", "ixNeeds_intoxEffect", function()
	if (!isIntoxicated()) then return end

	local t = CurTime()
	local pulse = 0.5 + 0.5 * math.sin(t * 1.3)

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0.015 * pulse,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.01,
		["$pp_colour_contrast"] = 1 - 0.1 * pulse,
		["$pp_colour_colour"] = 0.45 + 0.15 * pulse,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})

	DrawMotionBlur(0.35 + 0.15 * math.sin(t * 1.8), 0.85, 0.012)
end)

hook.Add("CalcView", "ixNeeds_intoxView", function(client, pos, ang, fov)
	if (!isIntoxicated()) then return end

	local t = CurTime()

	return {
		origin = pos,
		angles = Angle(ang.p + math.sin(t * 1.0) * 1.2, ang.y, ang.r + math.sin(t * 1.4) * 3),
		fov    = fov + math.sin(t * 0.7) * 2,
	}
end)
