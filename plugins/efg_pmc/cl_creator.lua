-- Creador de PMC al estilo EFT: bando (USEC/BEAR), nombre, cara y voz.
-- La validación de verdad la hace el servidor (sv_plugin.lua,
-- CanPlayerCreateCharacter); aquí solo se avisa antes de enviar.

local PMC = ix.efg.pmc
local BACKGROUND = Material("efgui/backgrounds/creation.jpg", "smooth")
local SIDE_ORDER = {"usec", "bear"}

local function factionIndex(sideKey)
	return (sideKey == "usec" and FACTION_USEC) or (sideKey == "bear" and FACTION_BEAR) or nil
end

local PANEL = {}

function PANEL:Init()
	local UI = ix.efgui
	local C = UI.color
	local sw, sh = ScrW(), ScrH()
	local s = UI.Scale

	if (IsValid(ix.gui.efgPMCCreator)) then ix.gui.efgPMCCreator:Remove() end
	ix.gui.efgPMCCreator = self

	self:SetSize(sw, sh)
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.25)

	self.side = SIDE_ORDER[math.random(#SIDE_ORDER)]
	self.face = 1
	self.voice = 1

	local colW = math.floor(sw * 0.22)
	local margin = math.floor(sw * 0.06)
	local top = s(110)
	local bottom = sh - s(90)

	-- ── izquierda: bando ──────────────────────────────────────────────
	local left = self:Add("DPanel")
	left:SetPos(margin, top)
	left:SetSize(colW, bottom - top)
	left.Paint = function(_, w, h)
		UI.DrawPanel(0, 0, w, h, 235)
		UI.DrawHeader(0, 0, w, s(30), "Bando")
	end

	self.sideCards = {}
	local cardH = math.floor((bottom - top - s(30) - s(30)) / 2)

	for i, key in ipairs(SIDE_ORDER) do
		local side = PMC.sides[key]
		local card = left:Add("DButton")
		card:SetText("")
		card:SetPos(s(10), s(40) + (i - 1) * (cardH + s(10)))
		card:SetSize(colW - s(20), cardH)
		card.emblem = Material("efgui/factions/" .. key .. ".png", "smooth")
		card.Paint = function(this, w, h)
			local active = self.side == key
			surface.SetDrawColor(active and Color(40, 42, 40, 250) or C.bg2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(active and C.accent or (this:IsHovered() and C.lineHi or C.line))
			surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)

			local size = math.min(w * 0.5, h * 0.55)
			surface.SetDrawColor(255, 255, 255, active and 255 or 120)
			surface.SetMaterial(this.emblem)
			surface.DrawTexturedRect(w / 2 - size / 2, s(12), size, size)

			draw.SimpleText(side.name, "efgui.Title", w / 2, s(16) + size, active and C.text or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		card.DoClick = function()
			if (self.side == key) then return end
			surface.PlaySound("ui/buttonclick.wav")
			self.side = key
			self.face = 1
			self:UpdateModel()
		end

		local desc = card:Add("DLabel")
		desc:SetFont("efgui.Small")
		desc:SetTextColor(C.textDim)
		desc:SetWrap(true)
		desc:SetContentAlignment(8)
		desc:SetText(side.description)
		desc:SetMouseInputEnabled(false)
		card.PerformLayout = function(this, w, h)
			desc:SetPos(s(10), h - s(62))
			desc:SetSize(w - s(20), s(56))
		end

		self.sideCards[key] = card
	end

	-- ── centro: modelo del PMC ────────────────────────────────────────
	local centerX = margin + colW + s(20)
	local centerW = sw - margin * 2 - colW * 2 - s(40)

	local model = self:Add("DModelPanel")
	model:SetPos(centerX, top)
	model:SetSize(centerW, bottom - top)
	model:SetFOV(30)
	model:SetCamPos(Vector(120, 0, 46))
	model:SetLookAt(Vector(0, 0, 38))
	model:SetAmbientLight(Color(60, 62, 60))
	model:SetDirectionalLight(BOX_FRONT, Color(210, 205, 190))
	model:SetDirectionalLight(BOX_TOP, Color(90, 90, 100))
	model.yaw = 20
	model.LayoutEntity = function(this, entity)
		if (this.dragX) then
			local x = gui.MousePos()
			this.yaw = this.yaw + (x - this.dragX) * 0.5
			this.dragX = x
		end

		entity:SetAngles(Angle(0, this.yaw, 0))
		this:RunAnimation()
	end
	model.OnMousePressed = function(this) this.dragX = gui.MousePos() end
	model.OnMouseReleased = function(this) this.dragX = nil end
	model.PaintOver = function(_, w, h)
		draw.SimpleText("Arrastra para girar", "efgui.Small", w / 2, h - s(6), C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end
	self.model = model

	-- ── derecha: nombre, cara y voz ───────────────────────────────────
	local right = self:Add("DPanel")
	right:SetPos(sw - margin - colW, top)
	right:SetSize(colW, bottom - top)
	right.Paint = function(_, w, h)
		UI.DrawPanel(0, 0, w, h, 235)
		UI.DrawHeader(0, 0, w, s(30), "Personaje")
	end

	local y = s(42)
	local function label(text, color, font)
		local l = right:Add("DLabel")
		l:SetPos(s(12), y)
		l:SetSize(colW - s(24), s(18))
		l:SetFont(font or "efgui.Small")
		l:SetTextColor(color or C.textDim)
		l:SetText(text)
		y = y + s(20)
		return l
	end

	label("NOMBRE (3-15 caracteres, sin espacios)")
	local name = right:Add("DTextEntry")
	name:SetPos(s(12), y)
	name:SetSize(colW - s(24), s(32))
	name:SetFont("efgui.Normal")
	name:SetTextColor(C.text)
	name:SetCursorColor(C.text)
	name:SetPaintBackground(false)
	name.PaintOver = function(this, w, h)
		surface.SetDrawColor(this:HasFocus() and C.accent or C.line)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	name.Paint = function(this, w, h)
		surface.SetDrawColor(C.cell)
		surface.DrawRect(0, 0, w, h)
		this:DrawTextEntryText(C.text, C.accent, C.text)
	end
	self.nameEntry = name
	y = y + s(46)

	-- selector < valor > reutilizable
	local function selector(title, getText, onPrev, onNext)
		label(title)
		local row = right:Add("DPanel")
		row:SetPos(s(12), y)
		row:SetSize(colW - s(24), s(34))
		row.Paint = function(_, w, h)
			surface.SetDrawColor(C.cell)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(C.line)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.SimpleText(getText(), "efgui.Header", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		for i, info in ipairs({{"<", onPrev, LEFT}, {">", onNext, RIGHT}}) do
			local b = row:Add("DButton")
			b:Dock(info[3])
			b:SetWide(s(34))
			b:SetText(info[1])
			UI.StyleButton(b, "efgui.Header")
			b.DoClick = function()
				surface.PlaySound("ui/buttonclick.wav")
				info[2]()
			end
		end

		y = y + s(44)
		return row
	end

	selector("CARA", function()
		return ("CARA %d / %d"):format(self.face, PMC.sides[self.side].faces)
	end, function()
		self.face = self.face <= 1 and PMC.sides[self.side].faces or self.face - 1
		self:UpdateModel()
	end, function()
		self.face = self.face >= PMC.sides[self.side].faces and 1 or self.face + 1
		self:UpdateModel()
	end)

	local warn = label("La cara NO se puede cambiar después de crear el PMC.", C.yellow)
	warn:SetWrap(true)
	warn:SetTall(s(34))
	y = y + s(18)

	selector("VOZ", function()
		return string.upper(PMC.voices[self.voice].name)
	end, function()
		self.voice = self.voice <= 1 and #PMC.voices or self.voice - 1
		self:PreviewVoice()
	end, function()
		self.voice = self.voice >= #PMC.voices and 1 or self.voice + 1
		self:PreviewVoice()
	end)

	local listen = right:Add("DButton")
	listen:SetPos(s(12), y)
	listen:SetSize(colW - s(24), s(28))
	listen:SetText("Escuchar voz")
	UI.StyleButton(listen)
	listen.DoClick = function() self:PreviewVoice() end
	y = y + s(38)

	local note = label("La voz se puede cambiar más tarde en el menú principal (Ajustes).", C.textDim)
	note:SetWrap(true)
	note:SetTall(s(34))

	-- ── abajo: atrás, aleatorio y crear ───────────────────────────────
	local btnW, btnH = s(200), s(44)
	local function bottomButton(text, x, onClick, primary)
		local b = self:Add("DButton")
		b:SetPos(x, sh - s(70))
		b:SetSize(btnW, btnH)
		b:SetText(text)
		UI.StyleButton(b, "efgui.Header")
		b.efgActive = primary
		b.DoClick = function()
			surface.PlaySound("ui/buttonclickrelease.wav")
			onClick()
		end
		return b
	end

	bottomButton("< Atrás", margin, function() self:Back() end)
	bottomButton("Aleatorio", sw / 2 - btnW - s(10), function() self:Randomize() end)
	bottomButton("Crear", sw / 2 + s(10), function() self:Create() end, true)

	self:UpdateModel()
end

function PANEL:UpdateModel()
	local side = PMC.sides[self.side]
	local model = self.model

	if (model:GetModel() != side.model) then
		model:SetModel(side.model)
	end

	local entity = model.Entity

	if (IsValid(entity)) then
		local seq = entity:LookupSequence("idle_all_01")
		if (seq and seq > 0) then entity:ResetSequence(seq) end

		local headID = entity:FindBodygroupByName("Head")
		if (headID and headID >= 0) then
			entity:SetBodygroup(headID, self.face - 1)
		end
	end
end

function PANEL:PreviewVoice()
	local path = PMC.RandomVoicePath(self.side, "ready") or PMC.RandomVoicePath(self.side, "yes")

	if (path) then
		if (self.voiceSound) then self.voiceSound:Stop() end
		self.voiceSound = CreateSound(LocalPlayer(), path)
		self.voiceSound:PlayEx(1, PMC.voices[self.voice].pitch)
	end
end

local RANDOM_NAMES = {
	usec = {"Ghost", "Reaper", "Hawk", "Viper", "Ranger", "Wolf", "Nomad", "Talon", "Saber", "Raven"},
	bear = {"Medved", "Volk", "Sokol", "Grom", "Kostya", "Zubr", "Orel", "Taiga", "Lyutyi", "Shtorm"},
}

function PANEL:Randomize()
	self.side = SIDE_ORDER[math.random(#SIDE_ORDER)]
	self.face = math.random(PMC.sides[self.side].faces)
	self.voice = math.random(#PMC.voices)

	local names = RANDOM_NAMES[self.side]
	self.nameEntry:SetValue(names[math.random(#names)] .. "_" .. math.random(10, 99))

	self:UpdateModel()
end

function PANEL:Create()
	local name = string.Trim(self.nameEntry:GetValue() or "")
	local ok, fault = PMC.ValidateNickname(name)

	if (!ok) then
		LocalPlayer():Notify(L(fault))
		return
	end

	local faction = factionIndex(self.side)

	if (!faction) then
		LocalPlayer():Notify(L("efgInvalidSide"))
		return
	end

	local payload = {
		name = name,
		description = PMC.sides[self.side].description,
		faction = faction,
		model = 1,
		efgFace = self.face,
		efgVoice = self.voice,
		chosenSkin = 0,
		chosenBodygroups = {},
	}

	vgui.Create("metroModal"):Setup("CREAR PMC",
		("¿Crear a %s (%s, cara %d)? La cara no se podrá cambiar."):format(name, PMC.sides[self.side].name, self.face), nil, function()
		vgui.Create("metroCharCreationDim")

		net.Start("ixCharacterCreate")
			net.WriteUInt(table.Count(payload), 8)

			for k, v in pairs(payload) do
				net.WriteString(k)
				net.WriteType(v)
			end
		net.SendToServer()

		self:Remove()
	end)
end

function PANEL:Back()
	vgui.Create("ixCharMenu")
	self:Remove()
end

function PANEL:OnRemove()
	if (self.voiceSound) then self.voiceSound:Stop() end
end

function PANEL:Paint(w, h)
	local UI = ix.efgui
	local s = UI.Scale

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(BACKGROUND)
	surface.DrawTexturedRect(0, 0, w, h)
	surface.SetDrawColor(6, 7, 7, 170)
	surface.DrawRect(0, 0, w, h)

	draw.SimpleText("CREACIÓN DE PMC", "efgui.Huge", w / 2, s(40), UI.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("Elige tu bando, tu cara y tu voz", "efgui.Normal", w / 2, s(76), UI.color.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("efgPMCCreator", PANEL, "EditablePanel")
