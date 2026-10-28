if (not CLIENT) then return end

local _showTimbres = false
local _timbreData = {}

local _SPHERE_MAT = CreateMaterial("timbres_sphere_mat", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$model"]       = 1,
	["$translucent"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$nocull"]      = 1,
})

local VIEW_RANGE_SQ = 4000 * 4000
local TIMBRE_COLOR = Color(255, 180, 40, 200)
local LABEL_COLOR = Color(255, 200, 60, 255)
local SHADOW_COLOR = Color(0, 0, 0, 200)

hook.Add("PostDrawTranslucentRenderables", "timbres.DrawMarkers", function(bDepth, bSkybox)
	if (bSkybox) then return end
	if (!_showTimbres) then return end

	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local clientPos = client:GetPos()

	render.SetMaterial(_SPHERE_MAT)

	for _, data in ipairs(_timbreData) do
		local pos = Vector(data.pos[1], data.pos[2], data.pos[3])
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end

		render.DrawSphere(pos + Vector(0, 0, 8), 14, 12, 12, TIMBRE_COLOR)
	end

	cam.Start2D()
		for _, data in ipairs(_timbreData) do
			local pos = Vector(data.pos[1], data.pos[2], data.pos[3])
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end

			local screen = (pos + Vector(0, 0, 40)):ToScreen()
			if (!screen.visible) then continue end

			local label = "TIMBRE #" .. data.idx
			draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, SHADOW_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "BudgetLabel", screen.x, screen.y, LABEL_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End2D()
end)

net.Receive("timbres_PointsData", function()
	local json = net.ReadString()
	local data = util.JSONToTable(json) or {}

	if (_showTimbres) then
		_showTimbres = false
		_timbreData = {}
		LocalPlayer():Notify("[Timbres] Puntos ocultos.")
	else
		if (#data == 0) then
			LocalPlayer():Notify("[Timbres] No hay timbres configurados.")
			return
		end

		_showTimbres = true
		_timbreData = data
		LocalPlayer():Notify("[Timbres] Mostrando " .. #data .. " timbre(s).")
	end
end)
