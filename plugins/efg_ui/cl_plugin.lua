-- Kit visual de EFG: paleta y utilidades de dibujo compartidas por el
-- inventario, el escondite, el mercadillo y el resto de menús.

ix.efgui = ix.efgui or {}

local UI = ix.efgui

UI.color = {
	bg0     = Color(11, 12, 12),          -- fondo de pantalla
	bg1     = Color(20, 22, 22, 245),     -- paneles
	bg2     = Color(30, 32, 31, 245),     -- cabeceras y celdas
	cell    = Color(17, 18, 18, 230),     -- celda vacía de inventario
	line    = Color(58, 61, 58),          -- bordes
	lineHi  = Color(110, 108, 96),        -- borde resaltado
	text    = Color(199, 197, 179),       -- texto principal (caqui claro)
	textDim = Color(130, 128, 116),       -- texto secundario
	accent  = Color(154, 136, 102),       -- acento (tan)
	select  = Color(199, 197, 179, 30),   -- relleno al pasar el ratón
	red     = Color(196, 60, 51),
	green   = Color(106, 138, 58),
	yellow  = Color(196, 168, 72),
	-- fondos de objeto por categoría, como los colores de fondo de EFT
	item = {
		default = Color(34, 36, 35, 220),
		weapon  = Color(30, 30, 30, 220),
		ammo    = Color(46, 44, 30, 220),
		medical = Color(28, 44, 30, 220),
		food    = Color(32, 46, 38, 220),
		gear    = Color(28, 36, 48, 220),
		key     = Color(26, 42, 58, 220),
		money   = Color(48, 46, 26, 220),
		quest   = Color(56, 46, 24, 220),
		barter  = Color(40, 36, 36, 220),
	}
}

UI.mat = {
	panel  = Material("efgui/panel.png", "noclamp smooth"),
	cell   = Material("efgui/cell.png", "noclamp smooth"),
	card   = Material("efgui/mainmenu_card.png", "noclamp smooth"),
	corner = Material("efgui/icons/corner.png", "noclamp smooth"),
	bg     = Material("efgui/spawnmenu/Menu/3.jpg", "noclamp smooth"),
	logo   = Material("efgui/logo32028.png", "noclamp smooth"),
}

local function createFonts()
	local s = math.max(ScrH() / 1080, 0.75)

	surface.CreateFont("efgui.Huge",   {font = "Bender", size = math.Round(42 * s), weight = 700, extended = true, antialias = true})
	surface.CreateFont("efgui.Title",  {font = "Bender", size = math.Round(26 * s), weight = 700, extended = true, antialias = true})
	surface.CreateFont("efgui.Header", {font = "Bender", size = math.Round(19 * s), weight = 600, extended = true, antialias = true})
	surface.CreateFont("efgui.Normal", {font = "Bender", size = math.Round(16 * s), weight = 500, extended = true, antialias = true})
	surface.CreateFont("efgui.Small",  {font = "Bender", size = math.Round(13 * s), weight = 500, extended = true, antialias = true})
	surface.CreateFont("efgui.Tiny",   {font = "Bender", size = math.Round(11 * s), weight = 500, extended = true, antialias = true})
end

createFonts()
hook.Add("OnScreenSizeChanged", "efguiFonts", createFonts)

function UI.Scale(v)
	return math.Round(v * math.max(ScrH() / 1080, 0.75))
end

-- Panel EFT: fondo oscuro con rejilla y borde fino.
function UI.DrawPanel(x, y, w, h, alpha)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(UI.mat.panel)
	surface.DrawTexturedRectUV(x, y, w, h, 0, 0, w / 256, h / 256)

	surface.SetDrawColor(UI.color.line)
	surface.DrawOutlinedRect(x, y, w, h)
end

-- Cabecera de sección: barra rayada tintada con el texto en mayúsculas.
function UI.DrawHeader(x, y, w, h, text, color)
	surface.SetDrawColor(UI.color.bg2)
	surface.DrawRect(x, y, w, h)

	local c = color or UI.color.accent
	surface.SetDrawColor(c.r, c.g, c.b, 70)
	surface.SetMaterial(UI.mat.card)
	surface.DrawTexturedRect(x, y, w, h)

	surface.SetDrawColor(c)
	surface.DrawRect(x, y + h - 1, w, 1)

	if (text) then
		draw.SimpleText(string.upper(text), "efgui.Header", x + UI.Scale(8), y + h / 2, UI.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

-- Celda de rejilla vacía.
function UI.DrawCell(x, y, w, h, hovered)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(UI.mat.cell)
	surface.DrawTexturedRect(x, y, w, h)

	if (hovered) then
		surface.SetDrawColor(UI.color.select)
		surface.DrawRect(x, y, w, h)
	end
end

-- Esquinas de selección (los corchetes que EFT dibuja al pasar el ratón).
function UI.DrawCorners(x, y, w, h, color)
	surface.SetDrawColor(color or UI.color.text)
	surface.SetMaterial(UI.mat.corner)
	surface.DrawTexturedRect(x, y, w, h)
end

-- Botón plano estilo EFT para paneles DButton.
function UI.PaintButton(panel, w, h, active)
	local hovered = panel:IsHovered() and panel:IsEnabled()

	surface.SetDrawColor(active and UI.color.accent or (hovered and Color(48, 50, 48, 250) or UI.color.bg2))
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(hovered and UI.color.lineHi or UI.color.line)
	surface.DrawOutlinedRect(0, 0, w, h)

	local text = panel.efgText or panel:GetText()
	local color = not panel:IsEnabled() and UI.color.textDim or (active and UI.color.bg0 or UI.color.text)

	draw.SimpleText(string.upper(text or ""), panel.efgFont or "efgui.Normal", w / 2, h / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	return true
end

-- Aplica el estilo EFT a un DButton existente.
function UI.StyleButton(button, font)
	button.efgText = button:GetText()
	button.efgFont = font
	button:SetText("")
	button.Paint = function(this, w, h)
		return UI.PaintButton(this, w, h, this.efgActive)
	end

	local oldSetText = button.SetText
	button.SetText = function(this, text)
		if (text ~= "") then
			this.efgText = text
		end

		oldSetText(this, "")
	end
end

-- Fondo de categoría de un objeto (como los colores de fondo de EFT).
function UI.GetItemColor(item)
	local cat = string.lower(item.category or "")
	local c = UI.color.item

	if (item.isWeapon or item.class) then return c.weapon end
	if (item.ammo or cat:find("munici", 1, true)) then return c.ammo end
	if (item.isEFGArmor or item.isBag or cat:find("chaleco", 1, true) or cat:find("casco", 1, true) or cat:find("mochila", 1, true)) then return c.gear end
	if (cat:find("medic", 1, true) or cat:find("médic", 1, true)) then return c.medical end
	if (cat:find("comida", 1, true) or cat:find("bebida", 1, true) or cat:find("provisi", 1, true)) then return c.food end
	if (cat:find("llave", 1, true) or cat:find("key", 1, true)) then return c.key end
	if (item.uniqueID == "bala" or cat:find("dinero", 1, true)) then return c.money end
	if (cat:find("misi", 1, true) or cat:find("quest", 1, true)) then return c.quest end
	if (cat:find("trueque", 1, true) or cat:find("material", 1, true) or cat:find("chatarra", 1, true)) then return c.barter end

	return c.default
end

-- Estilo EFT para los DFrame que usan los plugins de EFG (escondite, mercadillo).
function UI.StyleFrame(frame, title)
	frame:SetTitle("")
	frame.efgTitle = title or ""
	frame.Paint = function(this, w, h)
		Derma_DrawBackgroundBlur(this, this.m_fCreateTime or SysTime())
		UI.DrawPanel(0, 0, w, h)
		UI.DrawHeader(0, 0, w, UI.Scale(30), this.efgTitle)
	end

	if (IsValid(frame.btnClose)) then
		frame.btnClose.Paint = function(this, w, h)
			draw.SimpleText("X", "efgui.Normal", w / 2, h / 2, this:IsHovered() and UI.color.red or UI.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return true
		end
	end

	if (IsValid(frame.btnMaxim)) then frame.btnMaxim:SetVisible(false) end
	if (IsValid(frame.btnMinim)) then frame.btnMinim:SetVisible(false) end
end
