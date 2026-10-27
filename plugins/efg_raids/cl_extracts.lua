local PLUGIN = PLUGIN

-- Lista de extracciones y barra de extracción de EFT, adaptadas del addon de
-- puntos de extracción de Tarkov. O una vez: el tiempo de raid aparece y se
-- desvanece. O dos veces seguidas: la lista completa con su animación (el
-- tiempo, la barra verde "Busca la extracción" y las filas que bajan).

local matFind = Material("efg/raids/icon_find_point.png", "noclamp smooth")
local matRunner = Material("efg/raids/exit_status_runner.png", "noclamp smooth")
local matYes = Material("efg/raids/icon_exit_pmc_yes.png", "noclamp smooth")
local matNo = Material("efg/raids/icon_exit_pmc_no.png", "noclamp smooth")

local EXTRACT = {mode = 0, fadeState = "hidden", fadeAlpha = 0, fadeStart = 0, phase = "none", phaseStart = 0, flash = {}, pendingFlash = {}}
PLUGIN.extractHUD = EXTRACT

local FADE_IN, FADE_VISIBLE, FADE_OUT = 0.4, 3, 0.6
local T_TIMEFADE, T_GREEN, T_ROWS, T_VISIBLE = 0.3, 0.6, 0.5, 6
local T_ROWCLOSE, T_GREENCLOSE, T_TIMECLOSE = 0.5, 0.6, 0.5

local function easeOut(t) t = t - 1 return t * t * t + 1 end
local function easeIn(t) return t * t * t end

local fontScale

local function S(v)
	return math.max(1, math.Round(v * math.max(ScrH() / 1080, 0.75)))
end

local function createFonts()
	fontScale = ScrH()
	surface.CreateFont("efgExtract.HeaderTime", {font = "MBender", extended = true, size = S(26), weight = 500, antialias = true})
	surface.CreateFont("efgExtract.HeaderBold", {font = "MBender", extended = true, size = S(22), weight = 800, antialias = true})
	surface.CreateFont("efgExtract.RowBold", {font = "MBender", extended = true, size = S(20), weight = 800, antialias = true})
	surface.CreateFont("efgExtract.RowName", {font = "MBender", extended = true, size = S(20), weight = 500, antialias = true})
	surface.CreateFont("efgExtract.Condition", {font = "MBender", extended = true, size = S(16), weight = 500, italic = true, antialias = true})
	surface.CreateFont("efgExtract.Countdown", {font = "MBender", extended = true, size = S(24), weight = 800, antialias = true})
end

local function formatTime(seconds)
	seconds = math.max(0, seconds)
	return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
end

-- extracciones de esta raid: {index, extract}
local function raidExtracts(client)
	local out = {}
	local all = GetNetVar("efgExtracts", {})

	for _, index in ipairs(client:GetNetVar("efgRaidExtracts", {})) do
		if (all[index]) then out[#out + 1] = {index = index, data = all[index]} end
	end

	return out
end

local function condition(extract)
	if (extract.type == "pago" and extract.cost) then
		return ("Pagar %s rublos"):format(string.Comma(extract.cost))
	elseif (extract.type == "sin_mochila") then
		return "Sin mochila"
	end
end

function EXTRACT:OpenFull()
	if (self.mode == 2 and (self.phase == "visible" or self.phase == "rowslide")) then
		if (self.phase == "visible") then self.phaseStart = CurTime() end
		return
	end

	self.phase = (self.mode == 1 and self.fadeAlpha > 200) and "greenslide" or "timefade"
	self.mode = 2
	self.fadeState, self.fadeAlpha = "hidden", 0
	self.phaseStart = CurTime()
end

function EXTRACT:Peek()
	if (self.mode == 2) then return end

	if (self.mode == 1 and self.fadeState != "hidden") then
		self.fadeState, self.fadeStart, self.fadeAlpha = "visible", CurTime(), 255
	else
		self.mode, self.fadeState, self.fadeStart, self.fadeAlpha = 1, "fadein", CurTime(), 0
	end
end

net.Receive("ixEFGShowExtracts", function()
	EXTRACT:OpenFull()
end)

net.Receive("ixEFGExtractDenied", function()
	local index = net.ReadUInt(8)
	surface.PlaySound("efg/raids/error_message.wav")

	if (EXTRACT.mode == 2 and EXTRACT.phase == "visible") then
		EXTRACT.flash[index] = CurTime()
	else
		EXTRACT.pendingFlash[index] = true
	end

	EXTRACT:OpenFull()
end)

-- O: una pulsación enseña el tiempo; dos seguidas, la lista completa
local lastPress = 0

function PLUGIN:PlayerButtonDown(client, button)
	if (button != KEY_O or !IsFirstTimePredicted() or client != LocalPlayer() or !client:InRaid()) then return end
	if (vgui.CursorVisible()) then return end

	local now = RealTime()

	if (now - lastPress < 0.3) then
		timer.Remove("efgExtractPeek")
		EXTRACT:OpenFull()
	else
		timer.Create("efgExtractPeek", 0.3, 1, function() EXTRACT:Peek() end)
	end

	lastPress = now
end

local function flashAlpha(index, rowAlpha)
	local start = EXTRACT.flash[index]
	if (!start) then return 0 end

	local elapsed = CurTime() - start
	if (elapsed >= 1.5) then
		EXTRACT.flash[index] = nil
		return 0
	end

	return math.floor(math.max(0, math.sin(elapsed / 1.5 * math.pi * 6)) * 230 * rowAlpha / 255)
end

local function startPendingFlash()
	for index in pairs(EXTRACT.pendingFlash) do
		EXTRACT.flash[index] = CurTime()
		EXTRACT.pendingFlash[index] = nil
	end
end

local function drawList(client)
	if (EXTRACT.mode == 0) then return end

	local scrW, scrH = ScrW(), ScrH()
	local panelW = math.max(S(380), scrW * 0.28)
	local gap, timeW = S(3), S(110)
	local infoW = panelW - timeW - gap
	local headerH, rowH, condH = S(44), S(44), S(24)
	local startX, startY = scrW - panelW - S(16), S(16)

	local remaining = client:GetNetVar("efgRaidEnd", CurTime()) - CurTime()
	local timeText = formatTime(remaining)
	local timeColor = remaining < 10 * 60 and Color(210, 45, 45) or Color(255, 255, 255)

	-- ── O una vez: solo el tiempo, con fundido ──
	if (EXTRACT.mode == 1) then
		local t = CurTime() - EXTRACT.fadeStart

		if (EXTRACT.fadeState == "fadein") then
			EXTRACT.fadeAlpha = math.min(255, t / FADE_IN * 255)
			if (t >= FADE_IN) then EXTRACT.fadeState, EXTRACT.fadeStart = "visible", CurTime() end
		elseif (EXTRACT.fadeState == "visible") then
			EXTRACT.fadeAlpha = 255
			if (t >= FADE_VISIBLE) then EXTRACT.fadeState, EXTRACT.fadeStart = "fadeout", CurTime() end
		elseif (EXTRACT.fadeState == "fadeout") then
			EXTRACT.fadeAlpha = math.max(0, 255 - t / FADE_OUT * 255)
			if (t >= FADE_OUT) then
				EXTRACT.fadeState, EXTRACT.fadeAlpha, EXTRACT.mode = "hidden", 0, 0
				return
			end
		end

		local a = math.floor(EXTRACT.fadeAlpha)
		local x = scrW - timeW - S(16)
		surface.SetDrawColor(20, 20, 20, a * 200 / 255)
		surface.DrawRect(x, startY, timeW, headerH)
		draw.SimpleText(timeText, "efgExtract.HeaderTime", x + S(10), startY + headerH / 2, ColorAlpha(timeColor, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		return
	end

	-- ── O dos veces: lista completa con animación de apertura y cierre ──
	local t = CurTime() - EXTRACT.phaseStart
	local timeAlpha, green, rows = 255, 1, 1
	local phase = EXTRACT.phase

	local function nextPhase(name)
		EXTRACT.phase, EXTRACT.phaseStart = name, CurTime()
	end

	if (phase == "timefade") then
		timeAlpha, green, rows = math.min(255, t / T_TIMEFADE * 255), 0, 0
		if (t >= T_TIMEFADE) then nextPhase("greenslide") end
	elseif (phase == "greenslide") then
		green, rows = easeOut(math.min(1, t / T_GREEN)), 0
		if (t >= T_GREEN) then nextPhase("rowslide") end
	elseif (phase == "rowslide") then
		rows = easeOut(math.min(1, t / T_ROWS))
		if (t >= T_ROWS) then nextPhase("visible") startPendingFlash() end
	elseif (phase == "visible") then
		startPendingFlash()
		if (t >= T_VISIBLE) then nextPhase("rowclose") end
	elseif (phase == "rowclose") then
		rows = 1 - easeIn(math.min(1, t / T_ROWCLOSE))
		if (t >= T_ROWCLOSE) then nextPhase("greenclose") end
	elseif (phase == "greenclose") then
		green, rows = 1 - easeIn(math.min(1, t / T_GREENCLOSE)), 0
		if (t >= T_GREENCLOSE) then nextPhase("timeclose") end
	elseif (phase == "timeclose") then
		timeAlpha, green, rows = math.max(0, 255 - t / T_TIMECLOSE * 255), 0, 0
		if (t >= T_TIMECLOSE) then
			EXTRACT.phase, EXTRACT.mode = "none", 0
			return
		end
	end

	timeAlpha = math.floor(timeAlpha)

	-- tiempo de la raid (arriba a la derecha)
	local timeX = startX + infoW + gap
	surface.SetDrawColor(20, 20, 20, timeAlpha * 200 / 255)
	surface.DrawRect(timeX, startY, timeW, headerH)
	draw.SimpleText(timeText, "efgExtract.HeaderTime", timeX + S(10), startY + headerH / 2, ColorAlpha(timeColor, timeAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- barra verde "Busca la extracción", que se despliega hacia la izquierda
	if (green > 0) then
		local width = infoW * green
		local gx = timeX - gap - width
		local ga = math.floor(green * 255)

		surface.SetDrawColor(140, 200, 50, ga)
		surface.DrawRect(gx, startY, width, headerH)
		surface.SetDrawColor(120, 180, 40, math.floor(green * 80))
		surface.DrawRect(gx, startY + headerH - S(4), width, S(4))

		render.SetScissorRect(gx, startY, gx + width, startY + headerH, true)
			local icon = S(32)
			surface.SetDrawColor(255, 255, 255, ga)
			surface.SetMaterial(matFind)
			surface.DrawTexturedRect(gx + S(6), startY + (headerH - icon) / 2, icon, icon)
			draw.SimpleText("Busca la extracción", "efgExtract.HeaderBold", gx + icon + S(18), startY + headerH / 2, Color(0, 0, 0, ga), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		render.SetScissorRect(0, 0, 0, 0, false)
	end

	if (rows <= 0) then return end

	-- filas: bajan en bloque desde debajo de la cabecera
	local list = raidExtracts(client)
	local total = 0
	for i, e in ipairs(list) do total = total + rowH + (condition(e.data) and condH or 0) + (i > 1 and gap or 0) end

	local bottom = startY + headerH
	local listY = (bottom - total) + (bottom + gap - (bottom - total)) * rows
	local ra = math.floor(rows * 255)

	render.SetScissorRect(startX, bottom, startX + panelW, scrH, true)

	for i, e in ipairs(list) do
		local cond = condition(e.data)
		local fullH = rowH + (cond and condH or 0)
		local fa = flashAlpha(e.index, ra)

		for _, col in ipairs({{startX, infoW}, {startX + infoW + gap, timeW}}) do
			surface.SetDrawColor(20, 20, 20, math.floor(rows * 200))
			surface.DrawRect(col[1], listY, col[2], fullH)

			if (fa > 0) then
				surface.SetDrawColor(180, 35, 35, fa)
				surface.DrawRect(col[1], listY, col[2], fullH)
			end
		end

		local label = ("Extracción %02d"):format(i)
		draw.SimpleText(label, "efgExtract.RowBold", startX + S(12), listY + rowH / 2, Color(255, 255, 255, ra), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("efgExtract.RowBold")
		local lw = surface.GetTextSize(label)
		draw.SimpleText(e.data.name, "efgExtract.RowName", startX + S(12) + lw + S(8), listY + rowH / 2, Color(170, 170, 170, ra), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (cond) then
			draw.SimpleText(cond, "efgExtract.Condition", startX + S(14), listY + rowH - S(4) + condH / 2, Color(170, 170, 170, ra), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		listY = listY + fullH + gap
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

-- ─── Barra de extracción (dentro de la zona) ─────────────────────────────────
local barAlpha, barState = 0, {}

local function drawCountdown(client)
	local extracting = client:GetNetVar("efgExtracting")

	if (extracting) then
		barState = {remaining = extracting[1] - CurTime(), name = extracting[2], index = extracting[3]}
		barAlpha = math.min(1, barAlpha + FrameTime() * 6)
	else
		barAlpha = math.max(0, barAlpha - FrameTime() * 3)
	end

	if (barAlpha <= 0) then return end

	local a = barAlpha
	local barW, barH = S(250), S(54)
	local x, y = (ScrW() - barW) / 2, ScrH() * 0.75

	-- compañeros de grupo dentro de la misma zona
	local group = client:GetNetVar("efgGroup")
	local extract = barState.index and GetNetVar("efgExtracts", {})[barState.index]

	if (group and #group > 1 and extract) then
		local inside = 0

		for _, entIndex in ipairs(group) do
			local member = Entity(entIndex)
			if (IsValid(member) and member:Alive() and member:GetPos():Distance(extract.pos) <= extract.radius) then inside = inside + 1 end
		end

		local count = #group
		local ih = barH - S(20)
		local iw, gap = ih * 0.8, S(12)
		local tw = iw * count + gap * (count - 1)
		local sx, iy = x + (barW - tw) / 2, y - ih - S(24)

		surface.SetDrawColor(0, 0, 0, 255 * a)
		surface.DrawRect(sx - S(16), iy - S(10), tw + S(32), ih + S(20))

		for i = 1, count do
			surface.SetDrawColor(255, 255, 255, 255 * a)
			surface.SetMaterial(i <= inside and matYes or matNo)
			surface.DrawTexturedRect(sx + (i - 1) * (iw + gap), iy, iw, ih)
		end
	end

	surface.SetDrawColor(140, 200, 50, 230 * a)
	surface.DrawRect(x, y, barW, barH)

	local ih = barH - S(20)
	local iw = ih * 0.8
	surface.SetDrawColor(255, 255, 255, 255 * a)
	surface.SetMaterial(matRunner)
	surface.DrawTexturedRect(x + S(10), y + (barH - ih) / 2, iw, ih)

	draw.SimpleText(("Extracción %.1f"):format(math.max(0, barState.remaining or 0)), "efgExtract.Countdown",
		x + S(10) + iw + S(15), y + barH / 2, Color(0, 0, 0, 220 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "efgExtractHUD", function()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter()) then return end
	if (fontScale != ScrH()) then createFonts() end

	if (!client:InRaid()) then
		EXTRACT.mode, barAlpha = 0, 0
		return
	end

	drawList(client)
	drawCountdown(client)
end)
