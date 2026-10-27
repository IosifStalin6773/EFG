local PLUGIN = PLUGIN

-- ─── Iconos en la pantalla SALUD (hook de efg_health HEALTH:BodyStatus) ─────
function PLUGIN:EFGBodyStatus(out, client)
	local now = CurTime()
	local contusion = client:GetNetVar("efgContusion", 0)

	if (contusion > now) then
		out[#out + 1] = {"icon_concussion", "Conmoción", math.ceil(contusion - now) .. "s", Color(225, 95, 80)}
	end

	if (client:GetNetVar("efgPain") and !client:GetNetVar("efgPainkiller")) then
		out[#out + 1] = {"icon_debuff", "Temblores", nil, Color(225, 95, 80)}
	end
end

-- ─── Temblores: con dolor sin analgésico la vista tiembla ───────────────────
function PLUGIN:CalcView(client, origin, angles, fov)
	if (!client:Alive() or !client:GetNetVar("efgPain") or client:GetNetVar("efgPainkiller")) then return end

	local t = CurTime()
	angles.p = angles.p + math.sin(t * 9.3) * 0.25 + math.sin(t * 23.1) * 0.12
	angles.y = angles.y + math.cos(t * 7.7) * 0.25 + math.sin(t * 19.4) * 0.1
end

-- ─── Efectos de pantalla ─────────────────────────────────────────────────────
local vignette = Material("vgui/gradient-r")

local function tunnel(alpha)
	local w, h = ScrW(), ScrH()
	local edge = w * 0.22

	surface.SetMaterial(vignette)
	surface.SetDrawColor(0, 0, 0, alpha)
	surface.DrawTexturedRectRotated(edge / 2, h / 2, edge, h, 180)
	surface.DrawTexturedRectRotated(w - edge / 2, h / 2, edge, h, 0)
	surface.DrawTexturedRectRotated(w / 2, edge / 4, edge / 2, w, 90)
	surface.DrawTexturedRectRotated(w / 2, h - edge / 4, edge / 2, w, 270)
end

function PLUGIN:RenderScreenspaceEffects()
	local client = LocalPlayer()
	if (!client:Alive()) then return end

	local contusion = client:GetNetVar("efgContusion", 0) - CurTime()

	if (contusion > 0) then
		local f = math.Clamp(contusion / 5, 0, 1)
		DrawMotionBlur(0.15, 0.6 * f + 0.2, 0.01)
		DrawToyTown(2, ScrH() * 0.4 * f)
	end

	local character = client:GetCharacter()

	if (character) then
		local water = character.GetSaturation and character:GetSaturation() or 100
		local energy = character.GetSatiety and character:GetSatiety() or 100

		if (water <= 0 or energy <= 0) then
			DrawColorModify({
				["$pp_colour_addr"] = 0.02, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
				["$pp_colour_brightness"] = -0.04, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 0.7,
				["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
			})
		end
	end
end

-- Visión túnel: dolor sin analgésico o menos del 25% de vida total
function PLUGIN:HUDPaintBackground()
	local client = LocalPlayer()
	if (!client:Alive()) then return end

	local low = client:Health() < client:GetMaxHealth() * 0.25
	local pain = client:GetNetVar("efgPain") and !client:GetNetVar("efgPainkiller")

	if (low or pain) then
		tunnel(low and 230 or 150)
	end
end
