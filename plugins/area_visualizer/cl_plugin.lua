local PLUGIN = PLUGIN

-- ============================================================
--  ESTADO: VISUALIZACIÓN
-- ============================================================

local bVisible    = false
local badairZones = {}

-- ============================================================
--  ESTADO: COLOCACIÓN DE ÁREA
-- ============================================================

local bPlacing   = false
local placeType  = "badair"
local placeStart = nil

-- ============================================================
--  PALETA POR TIPO
-- ============================================================

local TYPE_COLORS = {
	area      = Color(100, 180, 255, 255),
	radzone   = Color(255, 120,   0, 255),
	toxiczone = Color( 80, 220,  80, 255),
	noairzone = Color(200,  60, 200, 255),
	safezone  = Color( 60, 220, 160, 255),
}
local COLOR_BADAIR  = Color(255, 200,  30, 255)
local COLOR_UNKNOWN = Color(200, 200, 200, 255)

local function GetTypeColor(t) return TYPE_COLORS[t] or COLOR_UNKNOWN end

-- ============================================================
--  HELPER: wireframe + label
-- ============================================================

local function DrawAreaBox(startPos, endPos, color, label, sublabel)
	local center = LerpVector(0.5, startPos, endPos)
	local min    = WorldToLocal(startPos, angle_zero, center, angle_zero)
	local max    = WorldToLocal(endPos,   angle_zero, center, angle_zero)

	render.DrawWireframeBox(center, angle_zero, min, max, color)

	cam.Start2D()
		local screen = center:ToScreen()
		if (screen.visible) then
			local x, y = screen.x, screen.y
			draw.SimpleText(label,    "BudgetLabel", x + 1, y + 1,  Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label,    "BudgetLabel", x,     y,      color,                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if (sublabel) then
				draw.SimpleText(sublabel, "BudgetLabel", x + 1, y + 15, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(sublabel, "BudgetLabel", x,     y + 14, ColorAlpha(color, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	cam.End2D()
end

-- ============================================================
--  RENDER 3D
-- ============================================================

function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)
	if (bSkybox) then return end

	-- ── Visualización de áreas (cuando está activa) ──────────
	if (bVisible) then
		if (ix.area and ix.area.stored) then
			for id, info in pairs(ix.area.stored) do
				local color    = GetTypeColor(info.type)
				local sublabel = (info.type ~= "area") and ("(" .. info.type .. ")") or nil
				DrawAreaBox(info.startPosition, info.endPosition, color, id, sublabel)
			end
		end

		for i, zone in ipairs(badairZones) do
			DrawAreaBox(zone[1], zone[2], COLOR_BADAIR, "Zona Tóxica #" .. i, "(badair)")
		end
	end

	-- ── Preview durante colocación ────────────────────────────
	if (bPlacing) then
		local trace  = LocalPlayer():GetEyeTraceNoCursor()
		local hitPos = trace.HitPos

		if (placeStart) then
			-- Esfera en la primera esquina
			render.DrawSphere(placeStart, 8, 12, 12, Color(255, 200, 0, 200))
			-- Wireframe de la caja que se va a crear
			local center = LerpVector(0.5, placeStart, hitPos)
			local min    = WorldToLocal(placeStart, angle_zero, center, angle_zero)
			local max    = WorldToLocal(hitPos,     angle_zero, center, angle_zero)
			render.DrawWireframeBox(center, angle_zero, min, max, Color(255, 255, 255, 200))
		else
			-- Punto de cursor en el mundo
			render.DrawSphere(hitPos, 6, 12, 12, Color(255, 230, 0, 220))
		end
	end
end

-- ============================================================
--  HUD: instrucciones de colocación
-- ============================================================

function PLUGIN:HUDPaint()
	if (not bPlacing) then return end

	local sw, sh = ScrW(), ScrH()
	local cx = sw * 0.5
	local step   = placeStart and "Haz clic izq en la segunda esquina" or "Haz clic izq en la primera esquina"
	local cancel = "Clic derecho para cancelar"

	draw.SimpleText("[AddArea: " .. placeType .. "]  " .. step,
		"BudgetLabel", cx + 1, 81, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("[AddArea: " .. placeType .. "]  " .. step,
		"BudgetLabel", cx,     80, Color(255, 230, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (placeStart) then
		local v = placeStart
		local s = string.format("Esquina 1:  %.0f  %.0f  %.0f", v.x, v.y, v.z)
		draw.SimpleText(s, "BudgetLabel", cx, 96, Color(200, 200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(cancel, "BudgetLabel", cx, 112, Color(200, 90, 90, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ============================================================
--  INPUT: intercepta clics durante la colocación
-- ============================================================

function PLUGIN:PlayerBindPress(client, bind, bPressed)
	if (not bPlacing or not bPressed) then return end

	-- Cancelar con clic derecho
	if (bind:find("attack2")) then
		bPlacing   = false
		placeStart = nil
		LocalPlayer():ChatPrint("[AreaVis] Colocación cancelada.")
		return true
	end

	-- Colocar esquina con clic izquierdo
	if (bind:find("attack") and not bind:find("attack2")) then
		local hitPos = LocalPlayer():GetEyeTraceNoCursor().HitPos

		if (not placeStart) then
			placeStart = hitPos
			local v = hitPos
			LocalPlayer():ChatPrint(string.format("[AreaVis] Esquina 1: %.0f %.0f %.0f", v.x, v.y, v.z))
			LocalPlayer():ChatPrint("[AreaVis] Ahora clic en la segunda esquina.")
		else
			net.Start("ixAreaVisAdd")
				net.WriteString(placeType)
				net.WriteVector(placeStart)
				net.WriteVector(hitPos)
			net.SendToServer()

			bPlacing   = false
			placeStart = nil
		end
		return true
	end
end

-- ============================================================
--  NET: recibe zonas badair del servidor
-- ============================================================

net.Receive("ixAreaVisBadairSync", function()
	badairZones = {}
	local count = net.ReadUInt(8)
	for _ = 1, count do
		local vMin = net.ReadVector()
		local vMax = net.ReadVector()
		table.insert(badairZones, {vMin, vMax})
	end
	LocalPlayer():ChatPrint("[AreaVis] " .. count .. " zona(s) badair recibidas.")
end)

-- ============================================================
--  COMANDOS
-- ============================================================

concommand.Add("showHelixAreas", function()
	local client = LocalPlayer()
	if (not client:IsAdmin()) then
		client:ChatPrint("[AreaVis] Solo administradores.")
		return
	end
	bVisible = true
	net.Start("ixAreaVisRequest")
	net.SendToServer()
	client:ChatPrint("[AreaVis] Visualización ACTIVADA. Solicitando zonas badair...")
end)

concommand.Add("disableHelixAreas", function()
	local client = LocalPlayer()
	if (not client:IsAdmin()) then
		client:ChatPrint("[AreaVis] Solo administradores.")
		return
	end
	bVisible    = false
	badairZones = {}
	client:ChatPrint("[AreaVis] Visualización DESACTIVADA.")
end)

-- addGenericArea [tipo]  (por defecto: badair)
-- Tipos soportados actualmente: badair
concommand.Add("addGenericArea", function(_, _, args)
	local client = LocalPlayer()
	if (not client:IsAdmin()) then
		client:ChatPrint("[AreaVis] Solo administradores.")
		return
	end

	-- Segundo llamado cancela
	if (bPlacing) then
		bPlacing   = false
		placeStart = nil
		client:ChatPrint("[AreaVis] Colocación cancelada.")
		return
	end

	placeType  = (args and args[1] ~= "" and args[1]) or "badair"
	bPlacing   = true
	placeStart = nil
	client:ChatPrint("[AreaVis] Modo colocación (" .. placeType .. "). Clic izq = esquina. Clic der = cancelar.")
end)
