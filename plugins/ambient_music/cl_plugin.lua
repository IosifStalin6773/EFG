local PLUGIN = PLUGIN

local audioChannel = nil
local emissionPoints = {}
local soundPath = ""
local maxRadius = 1500
local maxRadiusSqr = 1500 * 1500
local maxVolume = 1.0
local lastUpdateTime = 0
local bShowPoints = false

local COLOR_POINT = Color(112, 128, 130, 255)
local COLOR_RADIUS = Color(112, 128, 130, 40)
local COLOR_LINE = Color(112, 128, 130, 120)
local RING_SEGMENTS = 64

local function StopChannel()
	if (IsValid(audioChannel)) then
		audioChannel:Stop()
	end

	audioChannel = nil
end

local function StartChannel()
	StopChannel()

	if (soundPath == "" or #emissionPoints == 0) then return end

	sound.PlayFile("sound/" .. soundPath, "noplay noblock", function(channel, errID, errName)
		if (IsValid(channel)) then
			audioChannel = channel
			channel:EnableLooping(true)
			channel:SetVolume(0)
			channel:Play()
		else
			MsgN("[AmbientMusic] Error al cargar '", soundPath, "': ", errName)
			chat.AddText(Color(255, 80, 80), "[AmbientMusic] No se pudo cargar: " .. soundPath .. " (" .. tostring(errName) .. ")")
			chat.AddText(Color(255, 200, 80), "[AmbientMusic] El archivo debe estar suelto en garrysmod/sound/, no dentro de un GMA.")
		end
	end)
end

net.Receive("AmbientMusic_Sync", function()
	local newPath = net.ReadString()
	local newRadius = net.ReadFloat()
	local newVolume = net.ReadFloat()
	local count = net.ReadUInt(8)

	emissionPoints = {}

	for _ = 1, count do
		table.insert(emissionPoints, net.ReadVector())
	end

	maxRadius = newRadius
	maxRadiusSqr = newRadius * newRadius
	maxVolume = newVolume

	local bSoundChanged = (newPath != soundPath)
	soundPath = newPath

	if (bSoundChanged or not IsValid(audioChannel)) then
		StartChannel()
	end

	if (#emissionPoints == 0 or soundPath == "") then
		StopChannel()
	end
end)

net.Receive("AmbientMusic_Stop", function()
	emissionPoints = {}
	soundPath = ""
	StopChannel()
end)

function PLUGIN:Think()
	if (not IsValid(audioChannel) or #emissionPoints == 0) then return end

	local now = RealTime()
	if (now - lastUpdateTime < 0.1) then return end
	lastUpdateTime = now

	local plyPos = LocalPlayer():GetPos()
	local nearestDistSqr = math.huge

	for _, pos in ipairs(emissionPoints) do
		local distSqr = plyPos:DistToSqr(pos)

		if (distSqr < nearestDistSqr) then
			nearestDistSqr = distSqr
		end
	end

	if (nearestDistSqr >= maxRadiusSqr) then
		audioChannel:SetVolume(0)
		return
	end

	local fraction = 1 - math.sqrt(nearestDistSqr) / maxRadius
	audioChannel:SetVolume(maxVolume * fraction)
end

-- ============================================================
--  VISUALIZACIÓN 3D
-- ============================================================

local function DrawRing(center, radius, color)
	local step = (2 * math.pi) / RING_SEGMENTS

	for i = 0, RING_SEGMENTS - 1 do
		local a1 = i * step
		local a2 = (i + 1) * step
		local p1 = center + Vector(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local p2 = center + Vector(math.cos(a2) * radius, math.sin(a2) * radius, 0)

		render.DrawLine(p1, p2, color)
	end
end

function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)
	if (bSkybox or not bShowPoints or #emissionPoints == 0) then return end

	for i, pos in ipairs(emissionPoints) do
		render.DrawSphere(pos, 12, 16, 16, COLOR_POINT)
		render.DrawLine(pos, pos + Vector(0, 0, 80), COLOR_LINE)
		DrawRing(pos, maxRadius, COLOR_RADIUS)
	end
end

function PLUGIN:HUDPaint()
	if (not bShowPoints or #emissionPoints == 0) then return end

	for i, pos in ipairs(emissionPoints) do
		local screen = pos:ToScreen()

		if (screen.visible) then
			local x, y = screen.x, screen.y

			draw.SimpleText("#" .. i, "BudgetLabel", x + 1, y - 15, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("#" .. i, "BudgetLabel", x, y - 16, COLOR_POINT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local dist = math.Round(LocalPlayer():GetPos():Distance(pos))
			local info = dist .. "u | R:" .. math.Round(maxRadius)

			draw.SimpleText(info, "BudgetLabel", x + 1, y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(info, "BudgetLabel", x, y, Color(220, 220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local sw = ScrW()
	draw.SimpleText("[AmbientMusic] Puntos: " .. #emissionPoints .. " | Sonido: " .. (soundPath != "" and soundPath or "ninguno"), "BudgetLabel", sw - 10, 20, COLOR_POINT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

concommand.Add("ambient_music_show", function()
	if (not LocalPlayer():IsAdmin()) then
		LocalPlayer():ChatPrint("[AmbientMusic] Solo administradores.")
		return
	end

	bShowPoints = not bShowPoints
	LocalPlayer():ChatPrint("[AmbientMusic] Visualización " .. (bShowPoints and "ACTIVADA" or "DESACTIVADA") .. ".")
end)

function PLUGIN:ShutDown()
	StopChannel()
end
