local PLUGIN = PLUGIN
local health = ix.efg.health

surface.CreateFont("ixEFGHealthSmall", {font = "Bender", extended = true, size = ScreenScale(6), weight = 600})

-- Silueta: posición y tamaño relativos de cada parte dentro de un cuadro de 1x2
local layout = {
	head    = {0.38, 0.00, 0.24, 0.16},
	thorax  = {0.30, 0.18, 0.40, 0.26},
	stomach = {0.30, 0.46, 0.40, 0.16},
	larm    = {0.06, 0.18, 0.22, 0.40},
	rarm    = {0.72, 0.18, 0.22, 0.40},
	lleg    = {0.30, 0.64, 0.19, 0.36},
	rleg    = {0.51, 0.64, 0.19, 0.36}
}

local colorBorder = Color(0, 0, 0, 220)
local colorDead   = Color(25, 25, 25, 230)
local colorBleed  = Color(200, 30, 30)
local colorText   = Color(220, 215, 200)

local function partColor(fraction)
	-- verde → amarillo → rojo, como el panel de salud de EFT
	if (fraction > 0.5) then
		return Color(Lerp((1 - fraction) * 2, 70, 200), 170, 60, 200)
	end

	return Color(200, Lerp(fraction * 2, 40, 170), 40, 200)
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local data = client:GetNetVar("efgHP")

	if (!data or !client:Alive() or !client:GetCharacter()) then return end

	local boxH = ScreenScale(70)
	local boxW = boxH / 2
	local x0, y0 = ScreenScale(8), ScrH() - boxH - ScreenScale(36)
	local total = 0

	for i, part in ipairs(health.parts) do
		local entry = data[i]
		local rect = layout[part.id]

		if (entry and rect) then
			local hp, flags = entry[1], entry[2]
			local x, y = x0 + rect[1] * boxW, y0 + rect[2] * boxH
			local w, h = rect[3] * boxW, rect[4] * boxH

			total = total + hp

			surface.SetDrawColor(hp <= 0 and colorDead or partColor(hp / part.max))
			surface.DrawRect(x, y, w, h)
			surface.SetDrawColor(colorBorder)
			surface.DrawOutlinedRect(x, y, w, h)

			-- sangrado (gota roja) y fractura (F)
			if (bit.band(flags, 3) != 0) then
				local size = bit.band(flags, 2) != 0 and 6 or 4
				draw.RoundedBox(size, x + w / 2 - size, y + h / 2 - size, size * 2, size * 2, colorBleed)
			end

			if (bit.band(flags, 4) != 0) then
				draw.SimpleTextOutlined("F", "ixEFGHealthSmall", x + w - 2, y + 1, colorText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, color_black)
			end
		end
	end

	draw.SimpleTextOutlined(("%d / %d"):format(math.Round(total), health.total), "ixEFGHealthSmall",
		x0 + boxW / 2, y0 + boxH + ScreenScale(3), colorText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)

	local painkiller = client:GetNetVar("efgPainkiller")

	if (painkiller and painkiller > CurTime()) then
		draw.SimpleTextOutlined(("Analgésico %ds"):format(math.ceil(painkiller - CurTime())), "ixEFGHealthSmall",
			x0 + boxW / 2, y0 + boxH + ScreenScale(10), Color(120, 180, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
	end
end

-- Dolor: la imagen pierde color y tiembla un poco
function PLUGIN:RenderScreenspaceEffects()
	local client = LocalPlayer()

	if (client:GetNetVar("efgPain") and client:Alive()) then
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.03,
			["$pp_colour_contrast"] = 1.05,
			["$pp_colour_colour"] = 0.55,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
		DrawMotionBlur(0.2, 0.4, 0.01)
	end
end
