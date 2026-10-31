-- AJUSTES > CONTROLES: lista de teclas al estilo de EFT (grupos, una fila por
-- acción, casilla de tecla). Pinchar la casilla espera una tecla: Esc cancela,
-- Retroceso deja la acción sin tecla; ALT, CTRL o MAYÚS pulsados a la vez se
-- guardan como modificador. Las teclas repetidas salen en rojo.
local UI = ix.efgui
local BINDS = ix.efg.binds

local MOD_KEYS = {}

for mod, keys in pairs(BINDS.MODS) do
	for _, key in ipairs(keys) do MOD_KEYS[key] = mod end
end

-- ─── Casilla de tecla ────────────────────────────────────────────────────────
local KEYBOX = {}

function KEYBOX:Init()
	self:SetText("")
	self:SetCursor("hand")
	self:SetKeyboardInputEnabled(true)
end

function KEYBOX:Setup(id)
	self.bindID = id
end

function KEYBOX:DoClick()
	if (IsValid(BINDS.capturing) and BINDS.capturing != self) then BINDS.capturing:CancelCapture() end

	BINDS.capturing = self
	self.waitFrom = RealTime()
	self.held = nil
	surface.PlaySound("efg/ui/click.wav")
end

function KEYBOX:CancelCapture()
	if (BINDS.capturing == self) then BINDS.capturing = nil end
	self.waitFrom = nil
end

-- el TAB no tiene el teclado en esta pestaña: se mira el estado de cada tecla
function KEYBOX:Think()
	if (BINDS.capturing != self) then return end

	local held = self.held or {}
	self.held = held

	for code = KEY_FIRST + 1, KEY_LAST do
		local down = input.IsKeyDown(code)

		if (down and !held[code] and RealTime() - (self.waitFrom or 0) > 0.1) then
			held[code] = true
			self:OnKeyCodePressed(code)
			if (BINDS.capturing != self) then return end
		end

		held[code] = down
	end
end

function KEYBOX:OnKeyCodePressed(code)
	if (BINDS.capturing != self) then return end

	if (code == KEY_ESCAPE) then
		self:CancelCapture()
		return
	end

	if (code == KEY_BACKSPACE) then
		self:Assign(0)
		return
	end

	-- un modificador solo no es una tecla: se espera a la de verdad
	if (MOD_KEYS[code]) then return end

	self:Assign(code)
end

function KEYBOX:Assign(code)
	local mod

	for name in pairs(BINDS.MODS) do
		if (code > 0 and BINDS.ModDown(name)) then mod = name break end
	end

	BINDS.Set(self.bindID, code, mod)
	self:CancelCapture()
	surface.PlaySound("efg/ui/hover.wav")
end

function KEYBOX:OnRemove()
	if (BINDS.capturing == self) then BINDS.capturing = nil end
end

function KEYBOX:Paint(w, h)
	local c = UI.color
	local waiting = BINDS.capturing == self
	local conflict = !waiting and #BINDS.Conflicts(self.bindID) > 0

	UI.DrawCell(0, 0, w, h, waiting or self:IsHovered())

	surface.SetDrawColor(waiting and c.accent or (conflict and c.red or c.line))
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	local label = waiting and "PULSA UNA TECLA..." or BINDS.Name(self.bindID)
	draw.SimpleText(label, "efgui.Header", w / 2, h / 2, waiting and c.accent or (conflict and c.red or c.text),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	return true
end

vgui.Register("efgxKeyBox", KEYBOX, "DButton")

-- ─── Pantalla de controles ───────────────────────────────────────────────────
local CONTROLS = {}

local function rowH() return UI.Scale(40) end

function CONTROLS:Init()
	local s = UI.Scale
	local c = UI.color

	local top = self:Add("DPanel")
	top:Dock(TOP)
	top:SetTall(s(52))
	top.Paint = function(_, w, h)
		draw.SimpleText("Pincha una tecla y pulsa la nueva. Esc cancela, Retroceso la deja sin asignar.", "efgui.Normal",
			s(4), h / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local reset = top:Add("DButton")
	reset:Dock(RIGHT)
	reset:DockMargin(0, s(6), 0, s(6))
	reset:SetWide(s(220))
	reset:SetText("RESTABLECER")
	UI.StyleButton(reset, "efgui.Header")
	reset.DoClick = function()
		Derma_Query("¿Volver a las teclas por defecto?", "Controles", "Restablecer", function()
			BINDS.ResetAll()
			surface.PlaySound("efg/ui/click.wav")
		end, "Cancelar")
	end

	local scroll = self:Add("DScrollPanel")
	scroll:Dock(FILL)

	-- dos columnas; los grupos se reparten alternando
	local half = {scroll:Add("DPanel"), scroll:Add("DPanel")}

	for i, group in ipairs(BINDS.groups) do
		local column = half[(i - 1) % 2 + 1]
		column:SetPaintBackground(false)
		column.groups = column.groups or {}
		column.groups[#column.groups + 1] = group
	end

	self.columns = half
	self.scroll = scroll

	for _, column in ipairs(half) do
		local y = 0

		for _, group in ipairs(column.groups) do
			local header = column:Add("DPanel")
			header:SetPos(0, y)
			header:SetTall(s(30))
			header.Paint = function(_, w, h) UI.DrawHeader(0, 0, w, h, group) end
			header.efgFull = true
			y = y + s(34)

			for _, entry in ipairs(BINDS.list) do
				if (entry[3] == group) then
					local row = column:Add("DPanel")
					row:SetPos(0, y)
					row:SetTall(rowH())
					row.efgFull = true
					row.Paint = function(this, w, h)
						surface.SetDrawColor(this:IsChildHovered() and c.select or Color(0, 0, 0, 0))
						surface.DrawRect(0, 0, w, h)
						surface.SetDrawColor(c.line)
						surface.DrawRect(0, h - 1, w, 1)
						draw.SimpleText(entry[2], "efgui.Normal", s(10), h / 2, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end

					local box = row:Add("efgxKeyBox")
					box:Setup(entry[1])
					box:Dock(RIGHT)
					box:DockMargin(0, s(4), s(4), s(4))
					box:SetWide(s(200))

					y = y + rowH() + s(2)
				end
			end

			y = y + s(16)
		end

		column:SetTall(y)
	end
end

function CONTROLS:PerformLayout(w)
	local s = UI.Scale
	local colW = math.floor((w - s(24)) / 2)

	for i, column in ipairs(self.columns or {}) do
		column:SetPos((i - 1) * (colW + s(24)), s(8))
		column:SetWide(colW)

		for _, child in ipairs(column:GetChildren()) do
			if (child.efgFull) then child:SetWide(colW) end
		end
	end
end

vgui.Register("efgxControls", CONTROLS, "EditablePanel")
