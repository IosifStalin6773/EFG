-- ════════════════════════════════════════════════════════════════════════════
-- AJUSTES > JUEGO al estilo de EFT (efgxGameSettings).
-- Lee las mismas opciones de Helix (ix.option) y las guarda con ix.option.Set,
-- pero las pinta como la pestaña CONTROLES: grupos en mayúsculas, filas finas,
-- valor a la derecha. Booleanos se alternan con clic; numéricos con una barra
-- (clic o arrastre); clic derecho restablece el valor por defecto.
-- ════════════════════════════════════════════════════════════════════════════

local UI = ix.efgui

local function Col(name, fallback)
	return (UI.color and UI.color[name]) or fallback
end

local function Sc(v)
	return UI.Scale and UI.Scale(v) or v
end

local ROW_H = Sc(40)
local BAR_W = Sc(260)

local function Label(v)
	return L(v or "")
end

-- ─── Fila de una opción ─────────────────────────────────────────────────────
local ROW = {}

function ROW:Init()
	self:SetCursor("hand")
	self.label = self:Add("DLabel")
	self.label:SetFont("efgui.Normal")
	self.label:SetTextColor(Col("text", color_white))
	self.label:SetText("")
end

function ROW:Setup(data)
	self.data = data
	self.key = data.key
	self.label:SetText(Label(data.phrase))
	self.label:SizeToContents()
end

function ROW:GetValue()
	return ix.util.SanitizeType(self.data.type, ix.option.Get(self.key))
end

function ROW:SetValueAndSave(v)
	ix.option.Set(self.key, v)
end

function ROW:IsDefault()
	return self:GetValue() == self.data.default
end

function ROW:PerformLayout(w, h)
	self.label:SetPos(Sc(12), (h - self.label:GetTall()) / 2)
end

function ROW:OnMousePressed(code)
	local data = self.data
	if (code == MOUSE_RIGHT) then
		self:SetValueAndSave(data.default)
		surface.PlaySound("efg/ui/click.wav")
		return
	end

	if (code ~= MOUSE_LEFT) then return end

	if (data.type == ix.type.bool) then
		self:SetValueAndSave(!self:GetValue())
		surface.PlaySound("efg/ui/click.wav")
	elseif (data.type == ix.type.number) then
		self.dragging = true
		self:DragTo(self:CursorPos())
	end
end

function ROW:OnMouseReleased(code)
	if (code == MOUSE_LEFT) then self.dragging = false end
end

function ROW:Think()
	if (self.dragging and input.IsMouseDown(MOUSE_LEFT)) then
		self:DragTo(self:CursorPos())
	else
		self.dragging = false
	end
end

-- x dentro de la barra → valor entre min y max
function ROW:DragTo(mx)
	local data = self.data
	local w = self:GetWide()
	local x0 = w - Sc(12) - BAR_W - Sc(60)
	local frac = math.Clamp((mx - x0) / BAR_W, 0, 1)
	local min, max = data.min or 0, data.max or 10
	local v = min + (max - min) * frac

	if ((data.decimals or 0) == 0) then
		v = math.Round(v)
	else
		v = math.Round(v, data.decimals)
	end

	if (v ~= self:GetValue()) then
		self:SetValueAndSave(v)
	end
end

function ROW:Paint(w, h)
	local data = self.data
	local line = Col("line", Color(60, 60, 55))
	local changed = not self:IsDefault()

	surface.SetDrawColor(self:IsHovered() and 30 or 20, 22, 20, 235)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(line)
	surface.DrawRect(0, h - 1, w, 1)

	if (changed) then
		surface.SetDrawColor(Col("accent", Color(227, 114, 45)))
		surface.DrawRect(0, 0, Sc(3), h)
	end

	local vx = w - Sc(12)
	local v = self:GetValue()

	if (data.type == ix.type.bool) then
		local on = v and true or false
		draw.SimpleText(on and "SÍ" or "NO", "efgui.Normal", vx, h / 2, on and Col("accent", color_white) or Col("textDim", Color(150, 150, 140)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	elseif (data.type == ix.type.number) then
		local min, max = data.min or 0, data.max or 10
		local frac = math.Clamp((v - min) / math.max(max - min, 0.0001), 0, 1)
		local bx = vx - BAR_W - Sc(60)
		local by = h / 2 - Sc(5)

		surface.SetDrawColor(10, 11, 10, 255)
		surface.DrawRect(bx, by, BAR_W, Sc(10))
		surface.SetDrawColor(Col("accent", Color(227, 114, 45)))
		surface.DrawRect(bx, by, BAR_W * frac, Sc(10))

		local txt = (data.decimals or 0) == 0 and tostring(math.Round(v)) or string.format("%." .. (data.decimals or 2) .. "f", v)
		draw.SimpleText(txt, "efgui.Normal", vx, h / 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(tostring(v), "efgui.Normal", vx, h / 2, Col("textDim", Color(150, 150, 140)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("efgxGameSettingsRow", ROW, "DPanel")

-- ─── Panel completo ─────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	self:SetPaintBackground(false)

	self.search = self:Add("DTextEntry")
	self.search:SetFont("efgui.Normal")
	self.search:SetPlaceholderText("Buscar ajuste")
	self.search.OnChange = function() self:Rebuild() end
	self.search:Dock(TOP)
	self.search:DockMargin(0, 0, 0, Sc(8))
	self.search:SetTall(Sc(34))

	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:GetVBar():SetWide(Sc(6))

	self.info = self:Add("DLabel")
	self.info:SetFont("efgui.Normal")
	self.info:SetTextColor(Col("textDim", Color(150, 150, 140)))
	self.info:Dock(BOTTOM)
	self.info:DockMargin(0, Sc(6), 0, 0)
	self.info:SetTall(Sc(24))
	self.info:SetText("Clic izquierdo: cambiar   ·   Clic derecho: restablecer")

	self:Rebuild()
end

function PANEL:AddGroup(name)
	local header = self.scroll:Add("DPanel")
	header:Dock(TOP)
	header:DockMargin(0, Sc(10), 0, 0)
	header:SetTall(Sc(30))
	header.Paint = function(_, w, h)
		surface.SetDrawColor(Col("panel", Color(19, 19, 16, 240)))
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText(string.upper(name), "efgui.Normal", Sc(12), h / 2, Col("text", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:AddRowFor(data)
	local row = self.scroll:Add("efgxGameSettingsRow")
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, 0)
	row:SetTall(ROW_H)
	row:Setup(data)
	return row
end

function PANEL:Rebuild()
	self.scroll:Clear()

	local filter = string.lower(self.search:GetValue() or "")
	local groups = ix.option.GetAllByCategories(true)
	local names = {}

	for category in pairs(groups) do names[#names + 1] = category end
	table.sort(names, function(a, b) return Label(a) < Label(b) end)

	for _, category in ipairs(names) do
		local options = {}

		for _, data in ipairs(groups[category]) do
			local label = string.lower(Label(data.phrase))
			if (filter == "" or string.find(label, filter, 1, true)) then
				options[#options + 1] = data
			end
		end

		if (#options > 0) then
			table.sort(options, function(a, b) return Label(a.phrase) < Label(b.phrase) end)
			self:AddGroup(Label(category))

			for _, data in ipairs(options) do
				self:AddRowFor(data)
			end
		end
	end
end

function PANEL:Paint() end

vgui.Register("efgxGameSettings", PANEL, "EditablePanel")
