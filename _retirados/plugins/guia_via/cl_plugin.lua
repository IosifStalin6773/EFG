local segments = {}
local overlayActive = false

net.Receive("GuiaVia_SendList", function()
	segments = {}
	local count = net.ReadUInt(16)
	for i = 1, count do
		local id = net.ReadUInt(16)
		local startPos = net.ReadVector()
		local endPos = net.ReadVector()
		local width = net.ReadUInt(16)

		table.insert(segments, {id = id, startPos = startPos, endPos = endPos, width = width})
	end

	overlayActive = !overlayActive
	LocalPlayer():Notify(overlayActive and "Visualización de guías de vía activada." or "Visualización de guías de vía desactivada.")
end)

hook.Add("PostDrawTranslucentRenderables", "GuiaVia_Overlay3D", function(_, bSkybox)
	if (bSkybox or !overlayActive or #segments == 0) then return end

	for _, seg in ipairs(segments) do
		local dir = seg.endPos - seg.startPos
		local len = dir:Length()
		if (len > 0) then
			dir:Normalize()
			local perp = dir:Cross(vector_up)
			perp:Normalize()

			local leftStart = seg.startPos + perp * (seg.width / 2)
			local leftEnd = seg.endPos + perp * (seg.width / 2)
			local rightStart = seg.startPos - perp * (seg.width / 2)
			local rightEnd = seg.endPos - perp * (seg.width / 2)

			render.DrawLine(leftStart, leftEnd, Color(255, 210, 0), true)
			render.DrawLine(rightStart, rightEnd, Color(255, 210, 0), true)
			render.DrawLine(seg.startPos, seg.endPos, Color(0, 200, 255), true)

			render.DrawWireframeBox(seg.startPos, angle_zero, Vector(-8, -8, 0), Vector(8, 8, 60), Color(0, 255, 0))
			render.DrawWireframeBox(seg.endPos, angle_zero, Vector(-8, -8, 0), Vector(8, 8, 60), Color(255, 0, 0))
		end
	end

	cam.Start2D()
		for _, seg in ipairs(segments) do
			local mid = (seg.startPos + seg.endPos) / 2 + Vector(0, 0, 40)
			local screen = mid:ToScreen()
			if (!screen.visible) then continue end

			local label = "GUÍA #" .. seg.id .. " (" .. seg.width .. "u)"
			draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "BudgetLabel", screen.x, screen.y, Color(255, 210, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End2D()
end)
