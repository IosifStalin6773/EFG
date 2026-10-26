-- Kit visual Pizarra de EFG: tokens, fuentes, caché de materiales y funciones
-- de dibujo compartidas por el inventario, el escondite, el mercadillo, los
-- traders y el HUD. ix.efgx es el nombre nuevo; ix.efgui se mantiene como alias
-- para los plugins que ya lo usan.

ix.efgui = ix.efgui or {}
ix.efgx = ix.efgui

local UI = ix.efgui

UI.color = {
	bg0     = Color(14, 18, 22),           -- fondo de pantalla
	bg1     = Color(22, 28, 34, 245),      -- paneles
	bg2     = Color(31, 39, 48, 245),      -- cabeceras y celdas
	bg3     = Color(38, 48, 58, 245),      -- celda con objeto
	cell    = Color(31, 39, 48, 245),      -- celda vacía de inventario
	line    = Color(46, 58, 70),           -- bordes
	lineHi  = Color(74, 90, 106),          -- borde resaltado
	text    = Color(230, 226, 216),        -- tiza
	text2   = Color(154, 165, 175),        -- secundario
	textDim = Color(104, 115, 125),        -- etiquetas
	accent  = Color(232, 131, 58),         -- bengala: lo interactivo y lo seleccionado
	accentHi = Color(245, 150, 80),
	info    = Color(108, 195, 213),        -- datos de instrumento (HUD)
	select  = Color(230, 226, 216, 15),    -- relleno al pasar el ratón
	red     = Color(224, 90, 71),
	green   = Color(127, 176, 105),
	yellow  = Color(232, 197, 71),
}

UI.color.ok, UI.color.warn, UI.color.crit = UI.color.green, UI.color.yellow, UI.color.red
UI.c = UI.color

-- En Pizarra la categoría no tiñe el fondo: todos los objetos usan el mismo
-- fondo y la rareza se marca con la pestaña de la esquina (DrawRarity).
UI.color.item = setmetatable({}, {__index = function() return UI.color.bg3 end})

UI.rarity = {
	common    = {name = "Común",      color = Color(138, 147, 155), weight = 100},
	uncommon  = {name = "Poco común", color = Color(111, 175, 107), weight = 40},
	rare      = {name = "Raro",       color = Color(79, 159, 217),  weight = 15},
	epic      = {name = "Épico",      color = Color(167, 123, 214), weight = 5},
	legendary = {name = "Legendario", color = Color(220, 192, 96),  weight = 1},
}

-- ─── Materiales ──────────────────────────────────────────────────────────────
-- Material() es caro: cada ruta se crea una sola vez.
local matCache = {}

function UI.Mat(path, params)
	local key = path .. "|" .. (params or "")
	local mat = matCache[key]

	if (mat == nil) then
		mat = Material(path, params or "smooth mips")

		if (mat:IsError()) then
			MsgC(UI.color.yellow, "[efgui] Material no encontrado: " .. path .. "\n")
			mat = false
		end

		matCache[key] = mat
	end

	return mat or nil
end

UI.mat = {
	bg   = Material("efgui/spawnmenu/Menu/3.jpg", "noclamp smooth"),
	logo = Material("efgui/logo32028.png", "noclamp smooth"),
}

-- ─── Fuentes ─────────────────────────────────────────────────────────────────
-- Familias EFGX (content/resource/fonts): Saira Semi Condensed e IBM Plex,
-- licencia OFL, renombradas como exige la licencia al modificarlas.
local function createFonts()
	local s = math.max(ScrH() / 1080, 0.75)
	local function f(name, family, size, weight)
		surface.CreateFont(name, {font = family, size = math.Round(size * s), weight = weight, extended = true, antialias = true})
	end

	f("efgx.Display", "EFGX Display", 30, 700)
	f("efgx.Title",   "EFGX Display", 22, 700)
	f("efgx.Header",  "EFGX Header",  16, 600)
	f("efgx.Body",    "EFGX Body",    15, 500)
	f("efgx.Small",   "EFGX Small",   13, 400)
	f("efgx.Num",     "EFGX Mono",    14, 500)
	f("efgx.NumBig",  "EFGX Mono",    30, 500)
	f("efgx.Label",   "EFGX Label",   11, 400)

	-- nombres antiguos, usados por otros plugins
	f("efgui.Huge",   "EFGX Display", 42, 700)
	f("efgui.Title",  "EFGX Display", 26, 700)
	f("efgui.Header", "EFGX Header",  19, 600)
	f("efgui.Normal", "EFGX Body",    16, 500)
	f("efgui.Small",  "EFGX Small",   13, 400)
	f("efgui.Tiny",   "EFGX Label",   11, 400)
end

createFonts()
hook.Add("OnScreenSizeChanged", "efguiFonts", createFonts)

function UI.Scale(v)
	return math.max(1, math.Round(v * math.max(ScrH() / 1080, 0.75)))
end

UI.S = UI.Scale

-- ─── Dibujo ──────────────────────────────────────────────────────────────────
-- Panel con la esquina superior derecha biselada (polígono convexo en sentido
-- horario, como exige surface.DrawPoly).
function UI.DrawPanel(x, y, w, h, alpha, cut)
	cut = math.min(cut or UI.Scale(10), w, h)

	local fill = UI.color.bg1
	draw.NoTexture()
	surface.SetDrawColor(fill.r, fill.g, fill.b, alpha or fill.a)
	surface.DrawPoly({
		{x = x, y = y}, {x = x + w - cut, y = y}, {x = x + w, y = y + cut},
		{x = x + w, y = y + h}, {x = x, y = y + h},
	})

	surface.SetDrawColor(UI.color.line)
	surface.DrawLine(x, y, x + w - cut, y)
	surface.DrawLine(x + w - cut, y, x + w - 1, y + cut)
	surface.DrawLine(x + w - 1, y + cut, x + w - 1, y + h - 1)
	surface.DrawLine(x + w - 1, y + h - 1, x, y + h - 1)
	surface.DrawLine(x, y + h - 1, x, y)
end

-- Cabecera de sección: banda plana, línea inferior y texto en mayúsculas.
-- color (opcional) tiñe la línea inferior; right (opcional) va alineado a la derecha.
function UI.DrawHeader(x, y, w, h, text, color, right)
	surface.SetDrawColor(UI.color.bg2)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(color or UI.color.line)
	surface.DrawRect(x, y + h - 1, w, 1)

	if (text) then
		draw.SimpleText(string.upper(text), "efgx.Header", x + UI.Scale(10), y + h / 2, UI.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (right) then
		draw.SimpleText(right, "efgx.Num", x + w - UI.Scale(14), y + h / 2, UI.color.text2, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- Celda de rejilla. state: "normal", "hover", "selected", "valid", "invalid",
-- "disabled" o "locked". Por compatibilidad, un booleano equivale a hover.
function UI.DrawCell(x, y, w, h, state, hasItem)
	if (state == true) then state = "hover" elseif (!state) then state = "normal" end

	local c = UI.color
	surface.SetDrawColor(hasItem and c.bg3 or c.bg2)
	surface.DrawRect(x, y, w, h)

	if (state == "locked") then
		surface.SetDrawColor(c.bg1)
		local step = UI.Scale(6)

		for px = x + 2, x + w - 3, step do
			for py = y + 2, y + h - 3, step do
				surface.DrawRect(px, py, 2, 2)
			end
		end
	elseif (state == "valid" or state == "invalid") then
		local col = state == "valid" and c.ok or c.crit
		surface.SetDrawColor(col.r, col.g, col.b, 46)
		surface.DrawRect(x, y, w, h)
	elseif (state == "hover") then
		surface.SetDrawColor(c.select)
		surface.DrawRect(x, y, w, h)
	end

	local border = (state == "selected" and c.accent) or (state == "valid" and c.ok)
		or (state == "invalid" and c.crit) or (state == "hover" and c.lineHi) or c.line
	surface.SetDrawColor(border)
	surface.DrawOutlinedRect(x, y, w, h, state == "selected" and 2 or 1)

	if (state == "disabled") then
		surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, 150)
		surface.DrawRect(x, y, w, h)
	end
end

-- Marco de selección (sustituye a los corchetes antiguos).
function UI.DrawCorners(x, y, w, h, color)
	surface.SetDrawColor(color or UI.color.accent)
	surface.DrawOutlinedRect(x, y, w, h, 2)
end

-- Pestaña triangular abajo a la izquierda + línea base de 2 px.
function UI.DrawRarity(x, y, w, h, key)
	local r = UI.rarity[key or ""]
	if (!r) then return end

	local t = math.min(UI.Scale(9), w, h)
	surface.SetDrawColor(r.color)
	surface.DrawRect(x, y + h - 2, w, 2)
	draw.NoTexture()
	surface.DrawPoly({{x = x, y = y + h - t}, {x = x + t, y = y + h}, {x = x, y = y + h}})
end

-- Barra segmentada (durabilidad, peso, confianza). color opcional; si no, se
-- elige verde/amarillo/rojo según la fracción.
function UI.DrawMeter(x, y, w, h, frac, segments, color)
	segments = segments or 10
	frac = math.Clamp(frac or 0, 0, 1)

	local c = UI.color
	local col = color or (frac > 0.6 and c.ok or (frac > 0.25 and c.warn or c.crit))
	local segW = (w - (segments - 1)) / segments
	local lit = math.ceil(frac * segments - 0.001)

	surface.SetDrawColor(c.bg0)
	surface.DrawRect(x, y, w, h)

	for i = 0, segments - 1 do
		surface.SetDrawColor(i < lit and col or c.bg3)
		surface.DrawRect(math.floor(x + i * (segW + 1)), y, math.max(1, math.floor(segW)), h)
	end
end

-- Botón plano. variant: "primary", "ghost" o nil. active fuerza el aspecto primario.
function UI.PaintButton(panel, w, h, active, variant)
	local c = UI.color
	local enabled = panel:IsEnabled()
	local hovered = panel:IsHovered() and enabled
	local primary = active or variant == "primary"

	local fill = primary and (hovered and c.accentHi or c.accent)
		or (variant == "ghost" and (hovered and c.bg2 or color_transparent))
		or (hovered and c.bg3 or c.bg2)

	surface.SetDrawColor(fill)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(primary and c.accent or (hovered and c.lineHi or c.line))
	surface.DrawOutlinedRect(0, 0, w, h)

	local text = panel.efgText or panel:GetText()
	local color = !enabled and c.textDim or (primary and Color(26, 15, 5) or c.text)

	draw.SimpleText(string.upper(text or ""), panel.efgFont or "efgx.Header", w / 2, h / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	return true
end

-- Aplica el estilo a un DButton existente.
function UI.StyleButton(button, font, variant)
	button.efgText = button:GetText()
	button.efgFont = font
	button.efgVariant = variant
	button:SetText("")
	button.Paint = function(this, w, h)
		return UI.PaintButton(this, w, h, this.efgActive, this.efgVariant)
	end

	local oldSetText = button.SetText
	button.SetText = function(this, text)
		if (text ~= "") then
			this.efgText = text
		end

		oldSetText(this, "")
	end
end

-- Fondo de un objeto: igual para todas las categorías (ver UI.color.item).
function UI.GetItemColor(item)
	return UI.color.bg3
end

-- Marco para los DFrame de los plugins de EFG (escondite, mercadillo...).
function UI.StyleFrame(frame, title)
	frame:SetTitle("")
	frame.efgTitle = title or ""
	frame.Paint = function(this, w, h)
		Derma_DrawBackgroundBlur(this, this.m_fCreateTime or SysTime())
		UI.DrawPanel(0, 0, w, h)
		UI.DrawHeader(0, 0, w - UI.Scale(10), UI.Scale(30), this.efgTitle)
	end

	if (IsValid(frame.btnClose)) then
		frame.btnClose.Paint = function(this, w, h)
			draw.SimpleText("✕", "efgx.Header", w / 2, h / 2, this:IsHovered() and UI.color.accent or UI.color.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return true
		end
	end

	if (IsValid(frame.btnMaxim)) then frame.btnMaxim:SetVisible(false) end
	if (IsValid(frame.btnMinim)) then frame.btnMinim:SetVisible(false) end
end
