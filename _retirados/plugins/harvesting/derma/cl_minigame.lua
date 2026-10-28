-- ============================================================
--  PALETA HUD (mismos valores que plugins/hud/cl_plugin.lua)
-- ============================================================
local C_WHITE     = Color(240, 220, 188, 255)
local C_BONE      = Color(214, 178, 128, 255)
local C_GRAY      = Color(150, 124,  92, 255)
local C_PANEL     = Color( 10,   9,   8, 205)
local C_PANEL_TOP = Color( 30,  24,  16,  95)
local C_BORDER    = Color( 70,  48,  24, 205)
local C_BRACKET   = Color(206, 116,  36, 230)
local C_ACCENT    = Color(214, 122,  34, 255)
local C_BAR_BG    = Color( 24,  20,  16, 230)
local C_GREEN     = Color( 92, 150,  56, 255)
local C_RED       = Color(198,  64,  28, 255)
local C_YELLOW    = Color(220, 158,  52, 255)

-- ============================================================
--  HELPERS (réplicas ligeras del HUD)
-- ============================================================
local function DrawPanel(x, y, w, h)
	draw.RoundedBox(3, x, y, w, h, C_PANEL)
	surface.SetDrawColor(C_PANEL_TOP)
	surface.DrawRect(x + 1, y + 1, w - 2, 2)
	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function DrawBrackets(x, y, w, h, size, col)
	col  = col or C_BRACKET
	size = size or 8
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, size, 2);                 surface.DrawRect(x, y, 2, size)
	surface.DrawRect(x + w - size, y, size, 2);      surface.DrawRect(x + w - 2, y, 2, size)
	surface.DrawRect(x, y + h - 2, size, 2);         surface.DrawRect(x, y + h - size, 2, size)
	surface.DrawRect(x + w - size, y + h - 2, size, 2); surface.DrawRect(x + w - 2, y + h - size, 2, size)
end

local function DrawBar(x, y, w, h, frac, colFill)
	draw.RoundedBox(2, x, y, w, h, C_BAR_BG)
	if (frac > 0) then
		draw.RoundedBox(2, x, y, math.floor(w * frac), h, colFill)
	end
end

local function Shadow(text, font, x, y, col, xa, ya)
	draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 190), xa, ya)
	draw.SimpleText(text, font, x,     y,     col,                  xa, ya)
end

-- ============================================================
--  FUENTES
-- ============================================================
local function CreateHarvestFonts()
	local h = ScrH()

	surface.CreateFont("ixHarvestTitle", {
		font = "Capture Smallz",
		size = math.floor(h * 0.028),
		weight = 600,
		antialias = true
	})

	surface.CreateFont("ixHarvestText", {
		font = "Capture Smallz",
		size = math.floor(h * 0.015),
		weight = 500,
		antialias = true
	})

	surface.CreateFont("ixHarvestKey", {
		font = "Capture Smallz",
		size = math.floor(h * 0.026),
		weight = 700,
		antialias = true
	})
end

CreateHarvestFonts()
hook.Add("OnScreenSizeChanged", "ixHarvestFonts", CreateHarvestFonts)

-- Teclas posibles para el minijuego de secuencia.
local SEQ_KEYS = {
	{ key = KEY_W, label = "W" },
	{ key = KEY_A, label = "A" },
	{ key = KEY_S, label = "S" },
	{ key = KEY_D, label = "D" }
}

-- Numero total de modos disponibles (ver NewRound).
local MODE_COUNT = 5

local function IsSeqKey(key)
	return key == KEY_W or key == KEY_A or key == KEY_S or key == KEY_D
end

local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW() * 0.34, ScrH() * 0.22)
	self:Center()
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)

	self.markerT = 0
	self.dir = 1
	self.returning = false
	self.round = 1
	self.successes = 0
	self.locked = false
	self.submitted = false

	ix.gui.harvestMinigame = self
end

function PANEL:Setup(entity, harvestType)
	self.entity = entity
	self.data = ix.harvest.types[harvestType]

	if (!IsValid(entity) or !self.data) then
		self:Remove()
		return
	end

	self.rounds = self.data.rounds

	-- Se escoge un unico minijuego al azar para toda la sesion.
	-- 1 = zona, 2 = secuencia WASD, 3 = aporrear, 4 = reflejos, 5 = equilibrio.
	self.mode = math.random(MODE_COUNT)

	self:NewRound()
end

function PANEL:NewRound()
	self.locked = false

	if (self.mode == 1) then
		self:SetupZone()
	elseif (self.mode == 2) then
		self:SetupSequence()
	elseif (self.mode == 3) then
		self:SetupMash()
	elseif (self.mode == 4) then
		self:SetupReflex()
	else
		self:SetupBalance()
	end
end

function PANEL:SetupZone()
	self.zoneWidth = math.max(0.08, 0.20 - (self.round - 1) * 0.03)
	self.zoneStart = math.Rand(0, 1 - self.zoneWidth)
	self.speed = 0.80 + (self.round - 1) * 0.15
	self.markerT = 0
	self.dir = 1
	self.returning = false
end

function PANEL:SetupSequence()
	local count = math.Clamp(3 + self.round, 4, 6)
	self.sequence = {}

	for i = 1, count do
		self.sequence[i] = SEQ_KEYS[math.random(#SEQ_KEYS)]
	end

	self.seqIndex = 1
	self.seqPerKey = math.max(0.32, 0.62 - (self.round - 1) * 0.07)
	self.timeLimit = count * self.seqPerKey
	self.seqStart = SysTime()
end

function PANEL:SetupMash()
	self.mashCount = 0
	self.mashTarget = 12 + (self.round - 1) * 4
	self.mashLimit = 3.0
	self.mashStart = SysTime()
end

function PANEL:SetupReflex()
	self.reflexGo = false
	self.reflexAt = SysTime() + math.Rand(0.9, 2.4)
	self.reflexWindow = math.max(0.30, 0.60 - (self.round - 1) * 0.05)
end

function PANEL:SetupBalance()
	self.balPos = 0.5
	self.balVel = 0
	self.balDrift = math.Rand(-0.4, 0.4)
	self.balZone = math.max(0.045, 0.085 - (self.round - 1) * 0.01)
	self.balZoneAmp = 0.26
	self.balZoneSpeed = 1.5 + (self.round - 1) * 0.35
	self.balRequired = 1.8 + (self.round - 1) * 0.3
	self.balHold = 0
	self.balLimit = self.balRequired + 5
	self.balStart = SysTime()
end

-- Centro de la zona, que oscila de lado a lado.
function PANEL:GetBalanceCenter()
	return 0.5 + self.balZoneAmp * math.sin((SysTime() - self.balStart) * self.balZoneSpeed)
end

function PANEL:Lock(hit)
	if (self.locked) then
		return
	end

	self.locked = true
	self.lastHit = hit

	if (hit) then
		self.successes = self.successes + 1
		surface.PlaySound("buttons/button14.wav")
	else
		surface.PlaySound("buttons/button10.wav")
	end

	timer.Simple(0.45, function()
		if (!IsValid(self)) then
			return
		end

		self.round = self.round + 1

		if (self.round > self.rounds) then
			self:Finish()
		else
			self:NewRound()
		end
	end)
end

function PANEL:Attempt()
	if (self.locked) then
		return
	end

	local hit = self.markerT >= self.zoneStart and self.markerT <= (self.zoneStart + self.zoneWidth)
	self:Lock(hit)
end

function PANEL:SequenceInput(key)
	if (self.locked or !IsSeqKey(key)) then
		return
	end

	if (key == self.sequence[self.seqIndex].key) then
		self.seqIndex = self.seqIndex + 1

		if (self.seqIndex > #self.sequence) then
			self:Lock(true)
		else
			surface.PlaySound("buttons/button9.wav")
		end
	else
		self:Lock(false)
	end
end

function PANEL:MashInput()
	if (self.locked) then
		return
	end

	self.mashCount = self.mashCount + 1

	if (self.mashCount % 3 == 0) then
		surface.PlaySound("buttons/button9.wav")
	end

	if (self.mashCount >= self.mashTarget) then
		self:Lock(true)
	end
end

function PANEL:ReflexInput()
	if (self.locked) then
		return
	end

	-- Pulsar antes de la senal es un fallo.
	self:Lock(self.reflexGo == true)
end

function PANEL:Finish()
	if (self.submitted) then
		return
	end

	self.submitted = true

	if (IsValid(self.entity)) then
		net.Start("ixHarvestSubmit")
			net.WriteEntity(self.entity)
			net.WriteUInt(math.Clamp(self.successes, 0, 15), 4)
		net.SendToServer()
	end

	self:Remove()
end

function PANEL:OnRemove()
	-- Si se cierra antes de tiempo, se envia el progreso acumulado una sola vez.
	if (!self.submitted) then
		self.submitted = true

		if (IsValid(self.entity)) then
			net.Start("ixHarvestSubmit")
				net.WriteEntity(self.entity)
				net.WriteUInt(math.Clamp(self.successes, 0, 15), 4)
			net.SendToServer()
		end
	end

	if (ix.gui.harvestMinigame == self) then
		ix.gui.harvestMinigame = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Finish()
		return
	end

	if (self.mode == 1) then
		if (key == KEY_SPACE) then self:Attempt() end
	elseif (self.mode == 2) then
		self:SequenceInput(key)
	elseif (self.mode == 3) then
		if (key == KEY_SPACE) then self:MashInput() end
	elseif (self.mode == 4) then
		if (key == KEY_SPACE) then self:ReflexInput() end
	end
end

function PANEL:OnMousePressed(code)
	if (self.mode == 1 and code == MOUSE_LEFT) then
		self:Attempt()
	end
end

function PANEL:Think()
	if (!self.data or self.locked) then
		return
	end

	if (self.mode == 1) then
		self.markerT = self.markerT + self.dir * self.speed * FrameTime()

		if (self.markerT >= 1) then
			self.markerT = 1
			self.dir = -1
			self.returning = true
		elseif (self.markerT <= 0) then
			self.markerT = 0

			if (self.returning) then
				self:Lock(false)
			else
				self.dir = 1
			end
		end
	elseif (self.mode == 2) then
		if (SysTime() - self.seqStart > self.timeLimit) then
			self:Lock(false)
		end
	elseif (self.mode == 3) then
		if (SysTime() - self.mashStart > self.mashLimit) then
			self:Lock(false)
		end
	elseif (self.mode == 4) then
		if (!self.reflexGo) then
			if (SysTime() >= self.reflexAt) then
				self.reflexGo = true
				self.reflexGoAt = SysTime()
				surface.PlaySound("buttons/button17.wav")
			end
		elseif (SysTime() - self.reflexGoAt > self.reflexWindow) then
			self:Lock(false)
		end
	else
		local dt = FrameTime()

		-- La deriva deambula lentamente para que nunca sea estable.
		self.balDrift = math.Clamp(self.balDrift + math.Rand(-1, 1) * dt * 1.2, -1, 1)

		local move = 0
		if (input.IsKeyDown(KEY_A)) then move = move - 1 end
		if (input.IsKeyDown(KEY_D)) then move = move + 1 end

		self.balVel = self.balVel + (self.balDrift * 0.5 + move * 2.2) * dt
		self.balVel = self.balVel * math.Clamp(1 - dt * 2, 0, 1)
		self.balPos = self.balPos + self.balVel * dt

		if (self.balPos <= 0) then
			self.balPos = 0
			self.balVel = 0
		elseif (self.balPos >= 1) then
			self.balPos = 1
			self.balVel = 0
		end

		if (math.abs(self.balPos - self:GetBalanceCenter()) <= self.balZone) then
			self.balHold = self.balHold + dt

			if (self.balHold >= self.balRequired) then
				self:Lock(true)
			end
		end

		if (SysTime() - self.balStart > self.balLimit) then
			self:Lock(false)
		end
	end
end

function PANEL:PaintZone(width, height)
	local trackX = width * 0.08
	local trackW = width * 0.84
	local trackH = height * 0.16
	local trackY = height * 0.52 - trackH * 0.5

	DrawBar(trackX, trackY, trackW, trackH, 0, C_BAR_BG)

	surface.SetDrawColor(self.data.zoneColor)
	surface.DrawRect(trackX + self.zoneStart * trackW, trackY, self.zoneWidth * trackW, trackH)

	local markerW = math.max(2, width * 0.006)
	local markerX = trackX + self.markerT * trackW
	surface.SetDrawColor(self.locked and (self.lastHit and C_GREEN or C_RED) or C_WHITE)
	surface.DrawRect(markerX - markerW * 0.5, trackY - height * 0.04, markerW, trackH + height * 0.08)

	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(trackX, trackY, trackW, trackH, 1)

	Shadow("Pulsa [ESPACIO] o clic izquierdo cuando el marcador este en la zona.",
		"ixHarvestText", width * 0.5, height * 0.86, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintSequence(width, height)
	local count = #self.sequence
	local gapRatio = 0.35
	local avail = width * 0.84
	local boxSize = math.min(height * 0.24, avail / (count + (count - 1) * gapRatio))
	local gap = boxSize * gapRatio
	local totalW = count * boxSize + (count - 1) * gap
	local startX = width * 0.5 - totalW * 0.5
	local y = height * 0.44

	for i = 1, count do
		local x = startX + (i - 1) * (boxSize + gap)
		local done = i < self.seqIndex
		local current = (i == self.seqIndex) and !self.locked

		if (self.locked and !self.lastHit) then
			surface.SetDrawColor(C_RED.r, C_RED.g, C_RED.b, 230)
		elseif (done) then
			surface.SetDrawColor(self.data.zoneColor)
		elseif (current) then
			surface.SetDrawColor(C_PANEL)
		else
			surface.SetDrawColor(C_BAR_BG)
		end

		surface.DrawRect(x, y, boxSize, boxSize)

		surface.SetDrawColor(current and C_BRACKET or C_BORDER)
		surface.DrawOutlinedRect(x, y, boxSize, boxSize, current and 2 or 1)

		Shadow(self.sequence[i].label, "ixHarvestKey", x + boxSize * 0.5, y + boxSize * 0.5,
			C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local frac = math.Clamp(1 - (SysTime() - self.seqStart) / self.timeLimit, 0, 1)
	self:PaintTimerBar(width, height, frac, y + boxSize + height * 0.08)

	Shadow("Pulsa la secuencia con [W][A][S][D] antes de que se acabe el tiempo.",
		"ixHarvestText", width * 0.5, height * 0.92, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintMash(width, height)
	local frac = math.Clamp(self.mashCount / self.mashTarget, 0, 1)
	local barX = width * 0.08
	local barW = width * 0.84
	local barH = height * 0.16
	local barY = height * 0.50 - barH * 0.5

	local fillCol = self.locked and (self.lastHit and C_GREEN or C_RED) or self.data.zoneColor
	DrawBar(barX, barY, barW, barH, frac, fillCol)

	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(barX, barY, barW, barH, 1)

	local timeFrac = math.Clamp(1 - (SysTime() - self.mashStart) / self.mashLimit, 0, 1)
	self:PaintTimerBar(width, height, timeFrac, barY + barH + height * 0.08)

	Shadow("¡Aporrea [ESPACIO] para llenar la barra antes de que se acabe el tiempo!",
		"ixHarvestText", width * 0.5, height * 0.90, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintReflex(width, height)
	local boxW = width * 0.5
	local boxH = height * 0.34
	local boxX = width * 0.5 - boxW * 0.5
	local boxY = height * 0.42 - boxH * 0.5

	local label, col

	if (self.locked) then
		col = self.lastHit and C_GREEN or C_RED
		label = self.lastHit and "¡BIEN!" or "FALLO"
	elseif (self.reflexGo) then
		col = C_GREEN
		label = "¡YA!"
	else
		col = C_PANEL
		label = "Espera..."
	end

	surface.SetDrawColor(col)
	surface.DrawRect(boxX, boxY, boxW, boxH)
	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 1)
	DrawBrackets(boxX, boxY, boxW, boxH, 6)

	Shadow(label, "ixHarvestTitle", width * 0.5, boxY + boxH * 0.5,
		C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	Shadow("Pulsa [ESPACIO] en cuanto aparezca la señal (no te adelantes).",
		"ixHarvestText", width * 0.5, height * 0.90, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintBalance(width, height)
	local trackX = width * 0.08
	local trackW = width * 0.84
	local trackH = height * 0.16
	local trackY = height * 0.46 - trackH * 0.5

	DrawBar(trackX, trackY, trackW, trackH, 0, C_BAR_BG)

	local center = self:GetBalanceCenter()
	surface.SetDrawColor(self.data.zoneColor)
	surface.DrawRect(trackX + (center - self.balZone) * trackW, trackY, self.balZone * 2 * trackW, trackH)

	local markerW = math.max(2, width * 0.008)
	local markerX = trackX + self.balPos * trackW
	local inZone = math.abs(self.balPos - center) <= self.balZone
	surface.SetDrawColor(inZone and C_GREEN or C_WHITE)
	surface.DrawRect(markerX - markerW * 0.5, trackY - height * 0.04, markerW, trackH + height * 0.08)

	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(trackX, trackY, trackW, trackH, 1)

	local frac = math.Clamp(self.balHold / self.balRequired, 0, 1)
	self:PaintTimerBar(width, height, frac, trackY + trackH + height * 0.10)

	Shadow("Manten el marcador en la zona con [A] y [D].",
		"ixHarvestText", width * 0.5, height * 0.92, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Barra de progreso/tiempo reutilizable.
function PANEL:PaintTimerBar(width, height, frac, y)
	local barX = width * 0.08
	local barW = width * 0.84
	local barH = height * 0.05

	DrawBar(barX, y, barW, barH, frac, frac > 0.3 and C_YELLOW or C_RED)
end

function PANEL:Paint(width, height)
	if (!self.data) then
		return
	end

	DrawPanel(0, 0, width, height)
	DrawBrackets(0, 0, width, height)

	Shadow(self.data.label, "ixHarvestTitle", width * 0.5, height * 0.16,
		C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	Shadow("Ronda "..self.round.." / "..self.rounds.."   -   Aciertos: "..self.successes,
		"ixHarvestText", width * 0.5, height * 0.30, C_BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (self.mode == 1) then
		self:PaintZone(width, height)
	elseif (self.mode == 2) then
		self:PaintSequence(width, height)
	elseif (self.mode == 3) then
		self:PaintMash(width, height)
	elseif (self.mode == 4) then
		self:PaintReflex(width, height)
	else
		self:PaintBalance(width, height)
	end
end

vgui.Register("ixHarvestMinigame", PANEL, "EditablePanel")
