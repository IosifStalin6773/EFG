-- Indicador de carga de cargadores (como en EFT): icono del cargador abajo a
-- la derecha, balas que entran (o salen) una a una y contador. Se cancela con
-- clic derecho mientras está activo.
local M = ix.efg.mags

local work

net.Receive("efgMagWorkUI", function()
	if (!net.ReadBool()) then
		work = nil
		return
	end

	local id = net.ReadUInt(32)
	local loading = net.ReadBool()
	local total = net.ReadUInt(8)
	local step = net.ReadFloat()
	local item = ix.item.instances[id]

	work = {
		id = id, loading = loading, total = total, step = step, start = CurTime(),
		finish = CurTime() + total * step + 1,
		material = item and item.iconMaterial and Material(item.iconMaterial, "smooth") or nil
	}
end)


hook.Add("HUDPaint", "efgMagWork", function()
	if (!work) then return end

	if (CurTime() > work.finish) then
		work = nil
		return
	end

	local item = ix.item.instances[work.id]
	local capacity = item and item.capacity or 30
	local rounds = item and item:GetRounds() or 0

	local scale = math.max(ScrH() / 1080, 0.75)
	local w, h = math.Round(220 * scale), math.Round(92 * scale)
	local x, y = ScrW() - w - math.Round(40 * scale), ScrH() - h - math.Round(170 * scale)

	surface.SetDrawColor(14, 15, 13, 225)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(80, 82, 74, 255)
	surface.DrawOutlinedRect(x, y, w, h, 1)

	-- icono del cargador
	local icon = h - math.Round(16 * scale)
	local ix0, iy0 = x + math.Round(8 * scale), y + math.Round(8 * scale)

	if (work.material and !work.material:IsError()) then
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(work.material)
		surface.DrawTexturedRect(ix0, iy0, icon, icon)
	else
		surface.SetDrawColor(60, 62, 56)
		surface.DrawRect(ix0 + icon * 0.3, iy0, icon * 0.4, icon)
	end

	-- bala que entra (o sale) del cargador en cada paso
	local frac = ((CurTime() - work.start) % work.step) / work.step
	local bx = ix0 + icon * 0.5
	local by = work.loading and Lerp(frac, iy0 - icon * 0.6, iy0 + icon * 0.1) or Lerp(frac, iy0 + icon * 0.1, iy0 - icon * 0.6)
	local alpha = 255 * (1 - math.abs(frac - 0.5) * 1.6)
	local bs = math.Round(14 * scale)

	-- casquillo y punta
	surface.SetDrawColor(200, 160, 70, alpha)
	surface.DrawRect(bx - bs / 4, by + bs * 0.4, bs / 2, bs * 1.1)
	surface.SetDrawColor(170, 110, 60, alpha)
	surface.DrawRect(bx - bs / 5, by, bs * 0.4, bs * 0.45)

	-- texto y barra
	local tx = ix0 + icon + math.Round(10 * scale)
	local title = work.loading and "CARGANDO" or "DESCARGANDO"

	draw.SimpleText(title, "efgui.Small", tx, y + math.Round(10 * scale), Color(196, 193, 178))
	draw.SimpleText(("%d/%d"):format(rounds, capacity), "efgui.Title", tx, y + math.Round(28 * scale), color_white)

	local barW = x + w - tx - math.Round(10 * scale)
	local barY = y + h - math.Round(16 * scale)
	local progress = math.Clamp((CurTime() - work.start) / (work.total * work.step), 0, 1)

	surface.SetDrawColor(40, 41, 37)
	surface.DrawRect(tx, barY, barW, math.Round(5 * scale))
	surface.SetDrawColor(154, 186, 92)
	surface.DrawRect(tx, barY, barW * progress, math.Round(5 * scale))

	draw.SimpleText("Clic derecho: parar", "efgui.Tiny", x + w - math.Round(8 * scale), y + math.Round(10 * scale),
		Color(140, 138, 126), TEXT_ALIGN_RIGHT)
end)

-- clic derecho con el indicador activo para parar (fuera de menús)
hook.Add("PlayerBindPress", "efgMagWork", function(client, bind, pressed)
	if (work and pressed and bind:find("+attack2", 1, true)) then
		work = nil

		net.Start("efgMagWorkUI")
		net.SendToServer()

		return true
	end
end)
