local PLUGIN = PLUGIN
local health = ix.efg.health

surface.CreateFont("ixEFGHealthSmall", {font = "EFGX Label", extended = true, size = math.max(11, ScreenScale(5)), weight = 400})
surface.CreateFont("ixEFGHealthNum", {font = "EFGX Mono", extended = true, size = math.max(15, ScreenScale(7)), weight = 500})

-- Barra corporal de 7 segmentos (Pizarra): un medidor vertical por parte,
-- en el orden del cuerpo de arriba abajo. Sangrado = marca roja abajo,
-- fractura = barra amarilla arriba, parte destruida = celda tachada.
local labels = {head = "CAB", thorax = "TÓR", stomach = "EST", larm = "B.I", rarm = "B.D", lleg = "P.I", rleg = "P.D"}
local order = {"head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg"}

local function tokens()
	local c = ix.efgui and ix.efgui.color or {}

	return c.bg1 or Color(22, 28, 34), c.line or Color(46, 58, 70), c.text or Color(230, 226, 216),
		c.textDim or Color(104, 115, 125), c.ok or Color(127, 176, 105), c.warn or Color(232, 197, 71),
		c.crit or Color(224, 90, 71), c.info or Color(108, 195, 213)
end

local function partColor(fraction, ok, warn, crit)
	if (fraction > 0.6) then return ok end
	if (fraction > 0.3) then return warn end
	return crit
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local data = client:GetNetVar("efgHP")

	if (!data or !client:Alive() or !client:GetCharacter()) then return end

	local bg1, line, text, textDim, ok, warn, crit, info = tokens()
	local byID = {}

	for i, part in ipairs(health.parts) do
		if (data[i]) then byID[part.id] = {part = part, hp = data[i][1], flags = data[i][2]} end
	end

	local segW, segH, gap = ScreenScale(9), ScreenScale(22), ScreenScale(1.5)
	local pad = ScreenScale(4)
	local w = pad * 2 + #order * segW + (#order - 1) * gap
	local h = pad * 2 + segH + ScreenScale(16)
	local x0, y0 = ScreenScale(8), ScrH() - h - ScreenScale(30)
	local total = 0

	if (ix.efgui and ix.efgui.DrawPanel) then
		ix.efgui.DrawPanel(x0, y0, w, h, 225)
	else
		surface.SetDrawColor(bg1.r, bg1.g, bg1.b, 225); surface.DrawRect(x0, y0, w, h)
	end

	for n, id in ipairs(order) do
		local e = byID[id]

		if (e) then
			local x = x0 + pad + (n - 1) * (segW + gap)
			local y = y0 + pad + ScreenScale(9)
			local frac = math.Clamp(e.hp / e.part.max, 0, 1)
			total = total + e.hp

			surface.SetDrawColor(line); surface.DrawRect(x, y, segW, segH)

			if (e.hp <= 0) then
				surface.SetDrawColor(crit)
				surface.DrawLine(x, y, x + segW, y + segH)
				surface.DrawLine(x + segW, y, x, y + segH)
			else
				local fill = math.max(1, math.floor(segH * frac))
				surface.SetDrawColor(partColor(frac, ok, warn, crit))
				surface.DrawRect(x, y + segH - fill, segW, fill)
			end

			if (bit.band(e.flags, 3) != 0) then
				surface.SetDrawColor(crit)
				surface.DrawRect(x, y + segH + 1, segW, bit.band(e.flags, 2) != 0 and 3 or 2)
			end

			if (bit.band(e.flags, 4) != 0) then
				surface.SetDrawColor(warn)
				surface.DrawRect(x, y - 3, segW, 2)
			end

			draw.SimpleText(labels[id], "ixEFGHealthSmall", x + segW / 2, y0 + pad, textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end

	draw.SimpleText(("%d/%d"):format(math.Round(total), health.total), "ixEFGHealthNum",
		x0 + pad, y0 + h - pad, text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

	local painkiller = client:GetNetVar("efgPainkiller")

	if (painkiller and painkiller > CurTime()) then
		draw.SimpleText(("ANALG %ds"):format(math.ceil(painkiller - CurTime())), "ixEFGHealthSmall",
			x0 + w - pad, y0 + h - pad, info, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
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
