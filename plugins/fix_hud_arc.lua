PLUGIN.name = "Fix arco del HUD"
PLUGIN.author = "EFG"
PLUGIN.description = "Corrige ix.util.PrecacheArc (generaba polígonos con menos de 3 vértices) y protege ix.hud.DrawAll para que cam.Start2D/End2D quede siempre equilibrado."

if (CLIENT) then
	local cos, sin, rad, abs, ceil = math.cos, math.sin, math.rad, math.abs, math.ceil

	-- roughness = grados por segmento (Helix pasa 2)
	function ix.util.PrecacheArc(cx, cy, radius, thickness, startang, endang, roughness)
		local quadarc = {}

		startang = startang or 0
		endang = endang or 0

		local diff = abs(endang - startang)

		-- arco vacío o inválido: nada que dibujar (antes daba log(0) y step NaN)
		if (diff < 0.01 or !radius or radius <= 0) then
			return quadarc
		end

		local degPerSegment = (isnumber(roughness) and roughness > 0) and roughness or 2
		local segments = math.Clamp(ceil(diff / degPerSegment), 1, 360)
		local step = (endang >= startang and 1 or -1) * diff / segments
		local innerRadius = math.max(radius - (thickness or 0), 0)

		local function point(deg, r)
			local a = rad(deg)
			local x, y = cx + cos(a) * r, cy - sin(a) * r

			return {x = x, y = y, u = (x - cx) / radius + 0.5, v = (y - cy) / radius + 0.5}
		end

		for i = 0, segments - 1 do
			local a1 = startang + step * i
			local a2 = startang + step * (i + 1)

			-- mismo orden de vértices que el original (exterior a1, exterior a2, interior a2, interior a1)
			quadarc[#quadarc + 1] = {point(a1, radius), point(a2, radius), point(a2, innerRadius), point(a1, innerRadius)}
		end

		return quadarc
	end

	function ix.util.DrawPrecachedArc(arc)
		if (!istable(arc)) then return end

		for _, poly in ipairs(arc) do
			if (istable(poly) and poly[1] and poly[2] and poly[3]) then
				surface.DrawPoly(poly)
			end
		end
	end

	-- GM:PostDrawHUD llama a DrawAll entre cam.Start2D y cam.End2D: si DrawAll lanza un
	-- error, End2D no se ejecuta y GMod avisa "missing cam.End2D call" cada frame.
	local rawDrawAll = ix.hud.rawDrawAll or ix.hud.DrawAll
	ix.hud.rawDrawAll = rawDrawAll

	local nextReport = 0

	function ix.hud.DrawAll()
		local ok, err = pcall(rawDrawAll)

		if (!ok and RealTime() >= nextReport) then
			nextReport = RealTime() + 5
			ErrorNoHalt("[ix.hud.DrawAll] " .. tostring(err) .. "\n")
		end
	end
end
