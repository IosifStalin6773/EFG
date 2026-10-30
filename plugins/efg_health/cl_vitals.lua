-- Monitor de constantes de la pestaña SALUD (efgxVitals): SpO2, FC, TA,
-- sangre, grupo sanguíneo, ECG animado, avisos, energía e hidratación.
-- Lee las netvars efgVitals y efgHP en Think (sin crear tablas) y solo dibuja
-- en Paint; el ECG usa un búfer circular reservado una vez.
local PANEL = {}

local SAMPLES = 180
local SWEEP = 3 -- segundos en recorrer el monitor

local GREEN, YELLOW, RED = Color(90, 220, 110), Color(225, 190, 50), Color(225, 70, 58)
local DIM, TEXT = Color(130, 130, 118), Color(206, 204, 186)

local function S(v) return ix.efgui and ix.efgui.Scale(v) or v end

-- complejo PQRST normalizado (fase 0-1 de un latido), -1..1
local function ecg(phase)
	if (phase < 0.10) then return 0.12 * math.sin(phase / 0.10 * math.pi) end
	if (phase < 0.16) then return 0 end
	if (phase < 0.18) then return -0.15 * (phase - 0.16) / 0.02 end
	if (phase < 0.21) then return -0.15 + 1.15 * (phase - 0.18) / 0.03 end
	if (phase < 0.24) then return 1 - 1.3 * (phase - 0.21) / 0.03 end
	if (phase < 0.26) then return -0.3 + 0.3 * (phase - 0.24) / 0.02 end
	if (phase < 0.36) then return 0 end
	if (phase < 0.52) then return 0.25 * math.sin((phase - 0.36) / 0.16 * math.pi) end
	return 0
end

local function grade(value, warn, crit)
	return value <= crit and RED or (value <= warn and YELLOW or GREEN)
end

function PANEL:Init()
	self.buffer = {}
	for i = 1, SAMPLES do self.buffer[i] = 0 end

	self.head = 1
	self.carry = 0
	self.phase = 0
	self.last = RealTime()

	self.spo2, self.hr, self.sys, self.dia, self.blood, self.brain, self.flags = 98, 72, 120, 80, 6000, 0, 0
	self.bleed = 0
	self.ecgColor = GREEN
	self.bloodType = "?"
	self.warnings = {}
	self.nextSlow = 0
end

function PANEL:Think()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local v = client:GetNetVar("efgVitals")

	if (v) then
		self.spo2, self.hr, self.sys, self.dia, self.blood, self.brain, self.flags = v[1], v[2], v[3], v[4], v[5], v[6], v[7] or 0
	end

	-- sangrados activos (bits 1 leve, 2 grave de efgHP)
	local bleed = 0
	local parts = client:GetNetVar("efgHP")

	if (parts) then
		for _, part in pairs(parts) do
			local f = istable(part) and part[2] or 0
			if (bit.band(f, 2) != 0) then bleed = 2 break end
			if (bit.band(f, 1) != 0) then bleed = 1 end
		end
	end

	self.bleed = bleed

	local PH = ix.efg.physio
	local FLAG = PH and PH.FLAG
	local arrest = FLAG and bit.band(self.flags, FLAG.ARREST) != 0 or self.hr <= 0

	if (arrest or bleed == 2 or (FLAG and bit.band(self.flags, FLAG.SHOCK3 + FLAG.SHOCK4) != 0)) then
		self.ecgColor = RED
	elseif (bleed == 1 or (FLAG and bit.band(self.flags, FLAG.SHOCK2) != 0) or self.spo2 < 92) then
		self.ecgColor = YELLOW
	else
		self.ecgColor = GREEN
	end

	-- avanzar el ECG
	local now = RealTime()
	local dt = math.min(now - self.last, 0.1)
	self.last = now

	local bpm = arrest and 0 or self.hr
	local rate = SAMPLES / SWEEP
	self.carry = self.carry + dt * rate

	while (self.carry >= 1) do
		self.carry = self.carry - 1
		self.phase = (self.phase + (bpm / 60) / rate) % 1

		local value = bpm > 0 and ecg(self.phase) or 0
		-- en fibrilación (parada con RCP) temblor irregular
		if (arrest and FLAG and bit.band(self.flags, FLAG.CPR) != 0) then value = math.Rand(-0.25, 0.25) end

		self.buffer[self.head] = value
		self.head = self.head % SAMPLES + 1
	end

	-- lo que cambia poco, dos veces por segundo
	if (now >= self.nextSlow) then
		self.nextSlow = now + 0.5

		local character = client:GetCharacter()
		local bloodType = character and character.GetEfgBloodType and character:GetEfgBloodType()
		self.bloodType = (bloodType and bloodType != "") and bloodType or "?"

		self.energy = character and ((character.GetSatiety and character:GetSatiety()) or client:GetLocalVar("satiety", 100)) or 100
		self.water = character and ((character.GetSaturation and character:GetSaturation()) or client:GetLocalVar("saturation", 100)) or 100

		self.warnings = (v and PH and PH.Warnings) and PH.Warnings(v) or {}
	end
end

local function cell(x, y, w, label, value, color)
	draw.SimpleText(label, "efgx.Label", x, y, DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(value, "efgx.Title", x, y + S(12), color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function bar(x, y, w, h, frac, color)
	surface.SetDrawColor(26, 27, 24)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(color)
	surface.DrawRect(x, y, math.floor(w * math.Clamp(frac, 0, 1)), h)
end

function PANEL:Paint(w, h)
	local pad = S(10)

	surface.SetDrawColor(8, 9, 8, 170)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(255, 255, 255, 14)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(1, 1, w - 2, S(26))
	draw.SimpleText("CONSTANTES", "efgx.Header", pad, S(14), TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local y = S(36)

	-- ── ECG ──
	local ex, ew, eh = pad, w - pad * 2, S(78)
	surface.SetDrawColor(4, 10, 6, 230)
	surface.DrawRect(ex, y, ew, eh)
	surface.SetDrawColor(40, 70, 46, 60)

	for gx = ex, ex + ew, S(13) do surface.DrawLine(gx, y, gx, y + eh) end
	for gy = y, y + eh, S(13) do surface.DrawLine(ex, gy, ex + ew, gy) end

	local col = self.ecgColor
	local mid, amp = y + eh * 0.6, eh * 0.45
	local step = ew / (SAMPLES - 1)
	local gap = 6 -- hueco del barrido delante del cursor

	surface.SetDrawColor(col)

	for i = 1, SAMPLES - 1 do
		local ahead = (i - self.head) % SAMPLES

		if (ahead >= gap) then
			local x1 = ex + (i - 1) * step
			surface.DrawLine(x1, mid - self.buffer[i] * amp, x1 + step, mid - self.buffer[i + 1] * amp)
		end
	end

	local hrText = self.hr > 0 and tostring(self.hr) or "--"
	draw.SimpleText("FC", "efgx.Label", ex + ew - S(4), y + S(4), DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	draw.SimpleText(hrText, "efgx.Title", ex + ew - S(4), y + S(14), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	y = y + eh + S(10)

	-- ── cifras ──
	local half = (w - pad * 2) / 2
	cell(pad, y, half, "SpO2", self.spo2 .. "%", grade(self.spo2, 92, 85))
	cell(pad + half, y, half, "TENSIÓN", self.sys > 0 and (self.sys .. "/" .. self.dia) or "--", grade(self.sys, 95, 70))
	y = y + S(42)

	local bloodMax = ix.efg.physio and ix.efg.physio.BLOOD_MAX or 6000
	local bloodFrac = self.blood / bloodMax
	cell(pad, y, half, "SANGRE", math.Round(self.blood) .. " ml", grade(bloodFrac, 0.85, 0.7))
	cell(pad + half, y, half, "GRUPO", self.bloodType, TEXT)
	y = y + S(40)
	bar(pad, y, w - pad * 2, S(6), bloodFrac, grade(bloodFrac, 0.85, 0.7))
	y = y + S(14)

	if (self.brain > 0) then
		draw.SimpleText("DAÑO CEREBRAL " .. self.brain .. "%", "efgx.Label", pad, y, DIM)
		bar(pad, y + S(14), w - pad * 2, S(6), self.brain / 100, RED)
		y = y + S(28)
	end

	-- ── avisos ──
	if (self.bleed > 0) then
		draw.SimpleText(self.bleed == 2 and "SANGRADO GRAVE" or "SANGRADO LEVE", "efgx.Small", pad, y, self.bleed == 2 and RED or YELLOW)
		y = y + S(16)
	end

	for i = 1, #self.warnings do
		local warning = self.warnings[i]
		if (y > h - S(80)) then break end

		draw.SimpleText(warning[1], "efgx.Small", pad, y, warning[2])
		y = y + S(16)
	end

	-- ── energía e hidratación, abajo como en EFT ──
	local energy, water = self.energy or 100, self.water or 100
	local by = h - S(62)

	draw.SimpleText("ENERGÍA", "efgx.Label", pad, by, DIM)
	draw.SimpleText(math.floor(energy) .. "/100", "efgx.Title", pad, by + S(12), energy < 25 and RED or YELLOW)
	bar(pad, by + S(38), half - S(8), S(4), energy / 100, energy < 25 and RED or YELLOW)

	draw.SimpleText("HIDRATACIÓN", "efgx.Label", pad + half, by, DIM)
	draw.SimpleText(math.floor(water) .. "/100", "efgx.Title", pad + half, by + S(12), water < 25 and RED or Color(108, 170, 215))
	bar(pad + half, by + S(38), half - S(8), S(4), water / 100, water < 25 and RED or Color(108, 170, 215))
end

vgui.Register("efgxVitals", PANEL, "DPanel")
