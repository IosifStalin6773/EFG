-- Creador de PMC al estilo EFT, en cinco pasos sobre un modelo 3D en vivo:
-- BANDO → APARIENCIA → ATRIBUTOS → ROL → IDENTIDAD.
-- El cliente solo previsualiza: el servidor vuelve a validarlo todo
-- (sv_plugin.lua CanPlayerCreateCharacter + sv_creation.lua PMC.ValidateCreation).

local PMC = ix.efg.pmc
local BACKGROUND = Material("efgui/backgrounds/creation.jpg", "smooth")
local SIDE_ORDER = {"usec", "bear"}

local STEPS = {
	{id = "side", name = "Bando"},
	{id = "look", name = "Apariencia"},
	{id = "attrib", name = "Atributos"},
	{id = "role", name = "Rol"},
	{id = "identity", name = "Identidad"},
}

local SIDE_INFO = {
	usec = {
		motto = "United Security",
		lines = {"Contratistas occidentales de TerraGroup.", "Armas de la OTAN en el equipo inicial.", "Comerciantes afines: Peacekeeper y Mechanic."},
	},
	bear = {
		motto = "Battle Encounter Assault Regiment",
		lines = {"Unidad rusa creada para vigilar a TerraGroup.", "Armas soviéticas en el equipo inicial.", "Comerciantes afines: Prapor y Skier."},
	},
}

local function factionIndex(sideKey)
	return (sideKey == "usec" and FACTION_USEC) or (sideKey == "bear" and FACTION_BEAR) or nil
end

local function itemName(id)
	local item = ix.item.list[id]
	return item and (item.GetName and item:GetName() or item.name) or id
end

local function play(sound)
	surface.PlaySound(sound or "ui/buttonclick.wav")
end

local PANEL = {}

function PANEL:Init()
	local UI = ix.efgui
	local s = UI.Scale
	local sw, sh = ScrW(), ScrH()

	if (IsValid(ix.gui.efgPMCCreator)) then ix.gui.efgPMCCreator:Remove() end
	ix.gui.efgPMCCreator = self

	self:SetSize(sw, sh)
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.25)

	self.step = 1
	self.voice = 1
	self.attributes = {}
	self.role = PMC.roles[1].id
	self:SetSide(SIDE_ORDER[math.random(#SIDE_ORDER)], true)

	self.margin = math.floor(sw * 0.04)
	self.top = s(118)
	self.bottom = sh - s(86)
	self.leftW = math.floor(sw * 0.3)
	self.rightW = math.floor(sw * 0.22)

	self:BuildModel()
	self:BuildSummary()
	self:BuildNav()

	self.content = self:Add("DPanel")
	self.content:SetPos(self.margin, self.top)
	self.content:SetSize(self.leftW, self.bottom - self.top)
	self.content.Paint = function(_, w, h)
		UI.DrawPanel(0, 0, w, h, 235)
		UI.DrawHeader(0, 0, w, s(32), STEPS[self.step].name, UI.color.accent, ("%d / %d"):format(self.step, #STEPS))
	end

	self:ShowStep(1)
end

-- ─── Estado ──────────────────────────────────────────────────────────────────
function PANEL:SetSide(key, bSilent)
	self.side = key
	self.face = 1
	self.skin = 0
	self.look = {top = 1, legs = 1}
	self.cosmetics = {}

	for _, info in ipairs(PMC.cosmetics) do self.cosmetics[info.id] = 1 end

	if (!bSilent) then
		self:UpdateModel()
		if (self.step == 2) then self:ShowStep(2) end
	end
end

-- opción real de bodygroup para la posición elegida en cada lista
function PMC.LookValue(list, index)
	local entry = list[index] or list[1]
	return entry and entry[1] or 0
end

function PANEL:GetLook()
	local cosmetics = {}

	for _, info in ipairs(PMC.cosmetics) do
		cosmetics[info.id] = PMC.LookValue(info.options, self.cosmetics[info.id])
	end

	return {
		top = PMC.LookValue(PMC.tops[self.side], self.look.top),
		legs = PMC.LookValue(PMC.legs[self.side], self.look.legs),
		skin = self.skin,
		cosmetics = cosmetics,
	}
end

function PANEL:PointsLeft()
	local used = 0
	for _, v in pairs(self.attributes) do used = used + v end
	return PMC.attribPoints - used
end

-- ─── Modelo 3D ───────────────────────────────────────────────────────────────
function PANEL:BuildModel()
	local UI = ix.efgui
	local s = UI.Scale
	local x = self.margin + self.leftW + s(10)
	local w = ScrW() - x - self.margin - self.rightW - s(10)

	local model = self:Add("DModelPanel")
	model:SetPos(x, self.top - s(30))
	model:SetSize(w, self.bottom - self.top + s(30))
	model:SetFOV(28)
	model:SetAmbientLight(Color(60, 62, 60))
	model:SetDirectionalLight(BOX_FRONT, Color(215, 208, 190))
	model:SetDirectionalLight(BOX_TOP, Color(90, 90, 100))
	model:SetDirectionalLight(BOX_LEFT, Color(60, 70, 90))
	model.yaw = 15
	model.zoom = 0
	model.zoomTarget = 0

	-- cuerpo entero ↔ cabeza (al editar cara y accesorios)
	model.LayoutEntity = function(this, entity)
		if (this.dragX) then
			local mx = gui.MousePos()
			this.yaw = this.yaw + (mx - this.dragX) * 0.5
			this.dragX = mx
		end

		this.zoom = Lerp(FrameTime() * 6, this.zoom, this.zoomTarget)
		this:SetCamPos(LerpVector(this.zoom, Vector(125, 0, 44), Vector(38, 0, 64)))
		this:SetLookAt(LerpVector(this.zoom, Vector(0, 0, 37), Vector(0, 0, 63)))

		entity:SetAngles(Angle(0, this.yaw, 0))
		this:RunAnimation()
	end
	model.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then this.dragX = gui.MousePos() end
	end
	model.OnMouseReleased = function(this) this.dragX = nil end
	model.OnMouseWheeled = function(this, delta)
		this.zoomTarget = math.Clamp(this.zoomTarget + delta * 0.15, 0, 1)
	end
	model.PaintOver = function(this, w, h)
		draw.SimpleText("Arrastra para girar · rueda para acercar", "efgui.Small", w / 2, h - s(8), UI.color.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end
	self.model = model

	local view = self:Add("DButton")
	view:SetSize(s(120), s(26))
	view:SetPos(x + w / 2 - s(60), self.bottom - s(30))
	view:SetText("Cabeza")
	UI.StyleButton(view, "efgx.Small", "ghost")
	view.DoClick = function()
		play()
		model.zoomTarget = model.zoomTarget > 0.5 and 0 or 1
	end
	view.Think = function(this) this:SetText(model.zoomTarget > 0.5 and "Cuerpo entero" or "Cabeza") end

	self:UpdateModel()
end

function PANEL:UpdateModel()
	local side = PMC.sides[self.side]
	local panel = self.model
	if (!IsValid(panel)) then return end

	if (panel:GetModel() != side.model) then
		panel:SetModel(side.model)
	end

	local entity = panel.Entity
	if (!IsValid(entity)) then return end

	local seq = entity:LookupSequence("idle_all_01")
	if (seq and seq > 0 and entity:GetSequence() != seq) then entity:ResetSequence(seq) end

	local look = self:GetLook()
	entity:SetSkin(look.skin)
	entity:SetBodygroup(PMC.BG_HEAD, self.face - 1)
	entity:SetBodygroup(PMC.BG_TOP, look.top)
	entity:SetBodygroup(PMC.BG_LEGS, look.legs)

	if (PMC.SetPanelCosmetics) then PMC.SetPanelCosmetics(panel, look.cosmetics) end
end

-- ─── Resumen (derecha) ───────────────────────────────────────────────────────
function PANEL:BuildSummary()
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale

	local summary = self:Add("DPanel")
	summary:SetPos(ScrW() - self.margin - self.rightW, self.top)
	summary:SetSize(self.rightW, self.bottom - self.top)
	summary.emblems = {}

	for _, key in ipairs(SIDE_ORDER) do summary.emblems[key] = Material("efgui/factions/" .. key .. ".png", "smooth") end

	summary.Paint = function(_, w, h)
		UI.DrawPanel(0, 0, w, h, 235)
		UI.DrawHeader(0, 0, w, s(32), "Resumen")

		local y = s(44)
		local size = s(56)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(summary.emblems[self.side])
		surface.DrawTexturedRect(s(12), y, size, size)

		local name = string.Trim(self.nickname or "")
		draw.SimpleText(name != "" and name or "SIN NOMBRE", "efgui.Header", s(78), y + s(6), name != "" and C.text or C.textDim)
		draw.SimpleText(PMC.sides[self.side].name .. " · " .. PMC.roleByID[self.role].name, "efgui.Small", s(78), y + s(30), C.accent)
		y = y + size + s(16)

		local function row(label, value, color)
			draw.SimpleText(label, "efgui.Small", s(12), y, C.textDim)
			draw.SimpleText(value, "efgui.Small", w - s(12), y, color or C.text, TEXT_ALIGN_RIGHT)
			y = y + s(19)
		end

		local look = self:GetLook()
		row("Cara", ("%d / %d"):format(self.face, PMC.sides[self.side].faces))
		row("Chaqueta", PMC.OptionName(PMC.tops[self.side], look.top) or "-")
		row("Pantalón", PMC.OptionName(PMC.legs[self.side], look.legs) or "-")

		for _, info in ipairs(PMC.cosmetics) do
			local value = look.cosmetics[info.id]
			if (value > 0) then row(info.name, PMC.OptionName(info.options, value)) end
		end

		row("Voz", PMC.voices[self.voice].name)
		y = y + s(6)

		surface.SetDrawColor(C.line)
		surface.DrawRect(s(12), y, w - s(24), 1)
		y = y + s(8)

		for _, key in ipairs(PMC.attribOrder) do
			local attribute = ix.attributes.list[key]
			if (attribute) then row(attribute.name, string.rep("■", self.attributes[key] or 0) .. string.rep("□", PMC.attribMax - (self.attributes[key] or 0)), C.accent) end
		end

		row("Puntos libres", tostring(self:PointsLeft()), self:PointsLeft() > 0 and C.yellow or C.green)
		y = y + s(6)

		surface.SetDrawColor(C.line)
		surface.DrawRect(s(12), y, w - s(24), 1)
		y = y + s(8)

		draw.SimpleText("EQUIPO INICIAL", "efgx.Label", s(12), y, C.textDim)
		y = y + s(16)

		for _, entry in ipairs(PMC.BuildKit(self.role, self.side, self.attributes)) do
			if (y > h - s(20)) then break end
			draw.SimpleText(itemName(entry[1]) .. (entry[2] > 1 and (" x" .. entry[2]) or ""), "efgui.Small", s(12), y, C.text2)
			y = y + s(17)
		end
	end

	self.summary = summary
end

-- ─── Navegación ──────────────────────────────────────────────────────────────
function PANEL:BuildNav()
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale
	local sw, sh = ScrW(), ScrH()

	-- migas de pan de los pasos
	self.stepButtons = {}
	local stepW = s(150)
	local startX = sw / 2 - (#STEPS * stepW) / 2

	for i, step in ipairs(STEPS) do
		local b = self:Add("DButton")
		b:SetText("")
		b:SetPos(startX + (i - 1) * stepW, s(70))
		b:SetSize(stepW - s(6), s(30))
		b.Paint = function(this, w, h)
			local active, done = self.step == i, i < self.step
			surface.SetDrawColor(active and C.accent or (done and C.bg3 or C.bg2))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(active and C.accent or C.line)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.SimpleText(i .. "  " .. string.upper(step.name), "efgx.Header", w / 2, h / 2,
				active and Color(26, 15, 5) or (this:IsHovered() and C.text or C.text2), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			if (i > self.step and !self:CanLeave(self.step)) then return end
			play()
			self:ShowStep(i)
		end
		self.stepButtons[i] = b
	end

	local btnW, btnH = s(200), s(44)
	local function bottom(text, x, onClick, variant)
		local b = self:Add("DButton")
		b:SetPos(x, sh - s(66))
		b:SetSize(btnW, btnH)
		b:SetText(text)
		UI.StyleButton(b, "efgui.Header", variant)
		b.DoClick = function()
			play("ui/buttonclickrelease.wav")
			onClick()
		end
		return b
	end

	bottom("< Atrás", self.margin, function()
		if (self.step > 1) then self:ShowStep(self.step - 1) else self:Back() end
	end)
	bottom("Aleatorio", sw / 2 - btnW / 2, function() self:Randomize() end, "ghost")
	self.nextButton = bottom("Siguiente >", sw - self.margin - btnW, function()
		if (!self:CanLeave(self.step)) then return end
		if (self.step < #STEPS) then self:ShowStep(self.step + 1) else self:Create() end
	end, "primary")
end

function PANEL:CanLeave(step)
	if (STEPS[step].id == "attrib" and self:PointsLeft() > 0) then
		LocalPlayer():Notify(("Te quedan %d puntos de atributo por repartir."):format(self:PointsLeft()))
		return false
	end

	return true
end

function PANEL:ShowStep(index)
	self.step = index
	self.content:Clear()

	local s = ix.efgui.Scale
	local body = self.content:Add("DScrollPanel")
	body:SetPos(s(12), s(42))
	body:SetSize(self.leftW - s(24), self.content:GetTall() - s(52))
	body:GetVBar():SetWide(s(4))
	self.body = body

	self["Build_" .. STEPS[index].id](self, body)
	self.nextButton:SetText(index == #STEPS and "Crear PMC" or "Siguiente >")
	self.model.zoomTarget = STEPS[index].id == "look" and self.model.zoomTarget or 0
end

-- fila "etiqueta  < valor >"
function PANEL:Selector(parent, title, getText, onPrev, onNext, onFocus)
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale

	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:DockMargin(0, 0, s(6), s(6))
	row:SetTall(s(52))
	row.Paint = function(_, w, h)
		draw.SimpleText(string.upper(title), "efgx.Label", 0, 0, C.textDim)
		surface.SetDrawColor(C.cell)
		surface.DrawRect(0, s(16), w, h - s(16))
		surface.SetDrawColor(row:IsChildHovered() and C.lineHi or C.line)
		surface.DrawOutlinedRect(0, s(16), w, h - s(16))
		draw.SimpleText(getText(), "efgui.Normal", w / 2, s(16) + (h - s(16)) / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	for _, info in ipairs({{"<", onPrev, LEFT}, {">", onNext, RIGHT}}) do
		local b = row:Add("DButton")
		b:Dock(info[3])
		b:DockMargin(0, s(16), 0, 0)
		b:SetWide(s(36))
		b:SetText(info[1])
		UI.StyleButton(b, "efgui.Header", "ghost")
		b.DoClick = function()
			play()
			info[2]()
			if (onFocus) then onFocus() end
			self:UpdateModel()
		end
	end

	return row
end

local function cycle(value, count, delta)
	return (value - 1 + delta) % count + 1
end

local function sectionTitle(parent, text)
	local UI = ix.efgui
	local label = parent:Add("DLabel")
	label:Dock(TOP)
	label:DockMargin(0, UI.Scale(8), 0, UI.Scale(6))
	label:SetTall(UI.Scale(20))
	label:SetFont("efgx.Header")
	label:SetTextColor(UI.color.accent)
	label:SetText(string.upper(text))
	return label
end

-- ─── Paso 1: bando ───────────────────────────────────────────────────────────
function PANEL:Build_side(body)
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale
	local cardH = math.floor((body:GetTall() - s(10)) / 2)

	for _, key in ipairs(SIDE_ORDER) do
		local side, info = PMC.sides[key], SIDE_INFO[key]
		local card = body:Add("DButton")
		card:Dock(TOP)
		card:DockMargin(0, 0, s(6), s(10))
		card:SetTall(cardH)
		card:SetText("")
		card.emblem = Material("efgui/factions/" .. key .. ".png", "smooth")
		card.Paint = function(this, w, h)
			local active = self.side == key
			surface.SetDrawColor(active and Color(42, 44, 40, 250) or C.bg2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(active and C.accent or (this:IsHovered() and C.lineHi or C.line))
			surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)

			local size = math.min(h - s(30), w * 0.38)
			surface.SetDrawColor(255, 255, 255, active and 255 or 110)
			surface.SetMaterial(this.emblem)
			surface.DrawTexturedRect(s(14), h / 2 - size / 2, size, size)

			local tx = s(28) + size
			draw.SimpleText(side.name, "efgui.Huge", tx, s(16), active and C.text or C.textDim)
			draw.SimpleText(info.motto, "efgui.Small", tx, s(62), C.accent)

			for i, line in ipairs(info.lines) do
				draw.SimpleText("· " .. line, "efgui.Small", tx, s(86) + (i - 1) * s(18), active and C.text2 or C.textDim)
			end
		end
		card.DoClick = function()
			if (self.side == key) then return end
			play()
			self:SetSide(key)
		end
	end
end

-- ─── Paso 2: apariencia ──────────────────────────────────────────────────────
function PANEL:Build_look(body)
	local function headFocus() self.model.zoomTarget = 1 end
	local function bodyFocus() self.model.zoomTarget = 0 end
	local side = PMC.sides[self.side]

	sectionTitle(body, "Conjuntos")

	local presets = body:Add("DIconLayout")
	presets:Dock(TOP)
	presets:SetSpaceX(ix.efgui.Scale(6))
	presets:SetSpaceY(ix.efgui.Scale(6))
	presets:DockMargin(0, 0, ix.efgui.Scale(6), ix.efgui.Scale(4))

	for _, preset in ipairs(PMC.presets[self.side] or {}) do
		local b = presets:Add("DButton")
		b:SetSize(ix.efgui.Scale(126), ix.efgui.Scale(30))
		b:SetText(preset.name)
		ix.efgui.StyleButton(b, "efgx.Small")
		b.DoClick = function()
			play()
			self.look.top, self.look.legs = preset.top, preset.legs

			for _, info in ipairs(PMC.cosmetics) do self.cosmetics[info.id] = preset[info.id] or 1 end

			bodyFocus()
			self:UpdateModel()
		end
	end

	sectionTitle(body, "Cara")

	self:Selector(body, "Cabeza (no se puede cambiar después)", function()
		return ("CARA %d / %d"):format(self.face, side.faces)
	end, function() self.face = cycle(self.face, side.faces, -1) end,
	function() self.face = cycle(self.face, side.faces, 1) end, headFocus)

	if ((side.skins or 1) > 1) then
		self:Selector(body, "Tono de piel", function()
			return ("TONO %d / %d"):format(self.skin + 1, side.skins)
		end, function() self.skin = (self.skin - 1) % side.skins end,
		function() self.skin = (self.skin + 1) % side.skins end, headFocus)
	end

	sectionTitle(body, "Ropa")

	for _, part in ipairs({{"top", "Chaqueta", PMC.tops}, {"legs", "Pantalón", PMC.legs}}) do
		local list = part[3][self.side]
		self:Selector(body, part[2], function()
			return list[self.look[part[1]]][2]
		end, function() self.look[part[1]] = cycle(self.look[part[1]], #list, -1) end,
		function() self.look[part[1]] = cycle(self.look[part[1]], #list, 1) end, bodyFocus)
	end

	sectionTitle(body, "Accesorios")

	for _, info in ipairs(PMC.cosmetics) do
		self:Selector(body, info.name, function()
			return info.options[self.cosmetics[info.id]][2]
		end, function() self.cosmetics[info.id] = cycle(self.cosmetics[info.id], #info.options, -1) end,
		function() self.cosmetics[info.id] = cycle(self.cosmetics[info.id], #info.options, 1) end, headFocus)
	end

	local note = body:Add("DLabel")
	note:Dock(TOP)
	note:DockMargin(0, ix.efgui.Scale(6), ix.efgui.Scale(6), 0)
	note:SetTall(ix.efgui.Scale(34))
	note:SetWrap(true)
	note:SetFont("efgui.Small")
	note:SetTextColor(ix.efgui.color.textDim)
	note:SetText("Los accesorios son estéticos: un casco, máscara, gafas o auriculares equipados los tapan. La ropa se puede cambiar luego en PERSONAJE.")
end

-- ─── Paso 3: atributos ───────────────────────────────────────────────────────
function PANEL:Build_attrib(body)
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale

	local header = body:Add("DPanel")
	header:Dock(TOP)
	header:DockMargin(0, 0, s(6), s(10))
	header:SetTall(s(46))
	header.Paint = function(_, w, h)
		surface.SetDrawColor(C.cell)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("PUNTOS DISPONIBLES", "efgx.Header", s(12), h / 2, C.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(self:PointsLeft() .. " / " .. PMC.attribPoints, "efgui.Title", w - s(12), h / 2,
			self:PointsLeft() > 0 and C.yellow or C.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	for _, key in ipairs(PMC.attribOrder) do
		local attribute = ix.attributes.list[key]

		if (attribute) then
			local row = body:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(0, 0, s(6), s(8))
			row:SetTall(s(96))
			row.icon = ix.efg.utils and Material(ix.efg.utils.UIPath(attribute.efgIcon or "strength"), "smooth") or nil
			row.Paint = function(this, w, h)
				local value = self.attributes[key] or 0
				surface.SetDrawColor(C.bg2)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(this:IsChildHovered() and C.lineHi or C.line)
				surface.DrawOutlinedRect(0, 0, w, h)

				if (this.icon) then
					surface.SetDrawColor(255, 255, 255)
					surface.SetMaterial(this.icon)
					surface.DrawTexturedRect(s(10), s(10), s(40), s(40))
				end

				draw.SimpleText(string.upper(attribute.name), "efgx.Header", s(60), s(10), C.text)
				draw.SimpleText(("NIVEL INICIAL %d"):format(1 + value * PMC.levelsPerPoint), "efgx.Label", w - s(12), s(12), C.accent, TEXT_ALIGN_RIGHT)

				local pipW = s(18)
				for i = 1, PMC.attribMax do
					surface.SetDrawColor(i <= value and C.accent or C.bg3)
					surface.DrawRect(s(60) + (i - 1) * (pipW + s(4)), s(34), pipW, s(10))
				end
			end

			local desc = row:Add("DLabel")
			desc:SetPos(s(10), s(54))
			desc:SetSize(self.leftW - s(150), s(38))
			desc:SetWrap(true)
			desc:SetFont("efgui.Small")
			desc:SetTextColor(C.textDim)
			desc:SetText(attribute.description or "")

			for i, info in ipairs({{"-", -1}, {"+", 1}}) do
				local b = row:Add("DButton")
				b:SetSize(s(34), s(34))
				b:SetText(info[1])
				UI.StyleButton(b, "efgui.Title", info[2] > 0 and "primary" or nil)
				b.Think = function(this)
					local value = self.attributes[key] or 0
					this:SetEnabled(info[2] > 0 and (value < PMC.attribMax and self:PointsLeft() > 0) or (info[2] < 0 and value > 0))
				end
				b.DoClick = function()
					play()
					local value = math.Clamp((self.attributes[key] or 0) + info[2], 0, PMC.attribMax)
					self.attributes[key] = value > 0 and value or nil
				end
				row.PerformLayout = function(this, w, h)
					for j, child in ipairs(this.buttons or {}) do child:SetPos(w - s(10) - (3 - j) * s(40), h - s(44)) end
				end
				row.buttons = row.buttons or {}
				row.buttons[i] = b
			end
		end
	end

	local note = body:Add("DLabel")
	note:Dock(TOP)
	note:DockMargin(0, s(4), s(6), 0)
	note:SetTall(s(40))
	note:SetWrap(true)
	note:SetFont("efgui.Small")
	note:SetTextColor(C.yellow)
	note:SetText(("Con menos de %d de Fuerza no puedes empezar con chalecos ni cascos de clase %d o superior: el rol te da uno más ligero."):format(PMC.heavyStrength, PMC.heavyClass))
end

-- ─── Paso 4: rol ─────────────────────────────────────────────────────────────
function PANEL:Build_role(body)
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale
	local cardH = math.floor((body:GetTall() - s(20)) / #PMC.roles)

	for _, role in ipairs(PMC.roles) do
		local card = body:Add("DButton")
		card:Dock(TOP)
		card:DockMargin(0, 0, s(6), s(8))
		card:SetTall(math.max(cardH, s(150)))
		card:SetText("")
		card.icon = ix.efg.utils and Material(ix.efg.utils.UIPath(role.icon), "smooth") or nil
		card.Paint = function(this, w, h)
			local active = self.role == role.id
			surface.SetDrawColor(active and Color(42, 44, 40, 250) or C.bg2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(active and C.accent or (this:IsHovered() and C.lineHi or C.line))
			surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)

			if (this.icon) then
				surface.SetDrawColor(255, 255, 255, active and 255 or 120)
				surface.SetMaterial(this.icon)
				surface.DrawTexturedRect(s(12), s(12), s(44), s(44))
			end

			draw.SimpleText(string.upper(role.name), "efgui.Title", s(66), s(12), active and C.text or C.text2)
			draw.SimpleText(role.description, "efgui.Small", s(66), s(42), C.textDim)

			local y = s(66)
			local kit = PMC.BuildKit(role.id, self.side, self.attributes)
			local col = 0

			for _, entry in ipairs(kit) do
				local text = "· " .. itemName(entry[1]) .. (entry[2] > 1 and (" x" .. entry[2]) or "")
				draw.SimpleText(text, "efgui.Small", s(14) + col * (w / 2), y, active and C.text2 or C.textDim)
				col = col + 1
				if (col > 1) then col = 0; y = y + s(17) end
				if (y > h - s(16)) then break end
			end
		end
		card.DoClick = function()
			play()
			self.role = role.id
		end
	end
end

-- ─── Paso 5: identidad ───────────────────────────────────────────────────────
function PANEL:Build_identity(body)
	local UI = ix.efgui
	local C = UI.color
	local s = UI.Scale

	sectionTitle(body, "Nombre")

	local name = body:Add("DTextEntry")
	name:Dock(TOP)
	name:DockMargin(0, 0, s(6), s(4))
	name:SetTall(s(38))
	name:SetFont("efgui.Header")
	name:SetValue(self.nickname or "")
	name:SetPaintBackground(false)
	name.Paint = function(this, w, h)
		surface.SetDrawColor(C.cell)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(this:HasFocus() and C.accent or C.line)
		surface.DrawOutlinedRect(0, 0, w, h)
		this:DrawTextEntryText(C.text, C.accent, C.text)
	end
	name.OnChange = function(this) self.nickname = this:GetValue() end
	self.nameEntry = name

	local hint = body:Add("DLabel")
	hint:Dock(TOP)
	hint:DockMargin(0, 0, 0, s(6))
	hint:SetTall(s(18))
	hint:SetFont("efgui.Small")
	hint.Think = function(this)
		local ok, fault = PMC.ValidateNickname(string.Trim(name:GetValue()))
		this:SetTextColor(ok and C.green or C.textDim)
		this:SetText(ok and "Nombre válido (el servidor comprueba que no esté en uso)." or L(fault))
	end

	sectionTitle(body, "Voz")

	self:Selector(body, "Voz del PMC", function()
		return string.upper(PMC.voices[self.voice].name)
	end, function() self.voice = cycle(self.voice, #PMC.voices, -1); self:PreviewVoice() end,
	function() self.voice = cycle(self.voice, #PMC.voices, 1); self:PreviewVoice() end)

	local listen = body:Add("DButton")
	listen:Dock(TOP)
	listen:DockMargin(0, 0, s(6), s(12))
	listen:SetTall(s(30))
	listen:SetText("Escuchar voz")
	UI.StyleButton(listen, "efgx.Header")
	listen.DoClick = function() self:PreviewVoice() end

	sectionTitle(body, "Antes de crear")

	local note = body:Add("DLabel")
	note:Dock(TOP)
	note:DockMargin(0, 0, s(6), 0)
	note:SetTall(s(90))
	note:SetWrap(true)
	note:SetFont("efgui.Small")
	note:SetTextColor(C.text2)
	note:SetText("Solo puedes tener un PMC por cuenta. El bando y la cara son definitivos; la ropa, los accesorios y la voz se cambian más tarde desde PERSONAJE y Ajustes. El equipo del rol aparece en tu inventario al entrar.")

	timer.Simple(0, function() if (IsValid(name)) then name:RequestFocus() end end)
end

-- ─── Acciones ────────────────────────────────────────────────────────────────
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

-- aleatorio dentro del paso actual (en el primero, todo)
function PANEL:Randomize()
	local id = STEPS[self.step].id

	if (id == "side") then
		self:SetSide(SIDE_ORDER[math.random(#SIDE_ORDER)])
	end

	if (id == "side" or id == "look") then
		local side = PMC.sides[self.side]
		self.face = math.random(side.faces)
		self.skin = math.random(0, (side.skins or 1) - 1)
		self.look.top = math.random(#PMC.tops[self.side])
		self.look.legs = math.random(#PMC.legs[self.side])

		for _, info in ipairs(PMC.cosmetics) do
			self.cosmetics[info.id] = math.random() < 0.5 and 1 or math.random(#info.options)
		end
	end

	if (id == "side" or id == "attrib") then
		self.attributes = {}

		for _ = 1, PMC.attribPoints do
			local key = PMC.attribOrder[math.random(#PMC.attribOrder)]
			if ((self.attributes[key] or 0) < PMC.attribMax) then self.attributes[key] = (self.attributes[key] or 0) + 1 end
		end
	end

	if (id == "side" or id == "role") then
		self.role = PMC.roles[math.random(#PMC.roles)].id
	end

	if (id == "side" or id == "identity") then
		local names = RANDOM_NAMES[self.side]
		self.nickname = names[math.random(#names)] .. "_" .. math.random(10, 99)
		if (IsValid(self.nameEntry)) then self.nameEntry:SetValue(self.nickname) end
		self.voice = math.random(#PMC.voices)
	end

	self:UpdateModel()
	self:ShowStep(self.step)
end

function PANEL:Create()
	local name = string.Trim(self.nickname or "")
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

	if (self:PointsLeft() > 0) then
		self:ShowStep(3)
		self:CanLeave(3)
		return
	end

	local look = self:GetLook()
	local payload = {
		name = name,
		description = PMC.sides[self.side].description,
		faction = faction,
		model = 1,
		efgFace = self.face,
		efgVoice = self.voice,
		efgRole = self.role,
		efgLook = look,
		attributes = table.Copy(self.attributes),
		chosenSkin = look.skin,
		chosenBodygroups = {},
	}

	vgui.Create("metroModal"):Setup("CREAR PMC",
		("¿Crear a %s (%s, %s)? El bando y la cara no se podrán cambiar."):format(name, PMC.sides[self.side].name, PMC.roleByID[self.role].name), nil, function()
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
	surface.SetDrawColor(6, 7, 7, 185)
	surface.DrawRect(0, 0, w, h)

	draw.SimpleText("CREACIÓN DE PMC", "efgui.Huge", self.margin or s(40), s(36), UI.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("Escape from Gmod", "efgui.Small", (self.margin or s(40)) + s(2), s(62), UI.color.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("efgPMCCreator", PANEL, "EditablePanel")
