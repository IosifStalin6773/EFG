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
-- al cargar el archivo ScrH() todavía puede ser la del menú de carga: se
-- vuelven a crear cuando el jugador ya está dentro
hook.Add("InitPostEntity", "efguiFonts", createFonts)

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

-- Imagen a pantalla completa sin deformarla: se recorta lo que sobra (como
-- background-size: cover). Para los fondos de EFT de content/materials/efg/menu.
function UI.DrawCover(mat, x, y, w, h, alpha)
	if (!mat or mat:IsError()) then return false end

	local tw, th = mat:Width(), mat:Height()
	local u0, v0, u1, v1 = 0, 0, 1, 1
	local imgRatio, boxRatio = tw / math.max(th, 1), w / math.max(h, 1)

	if (imgRatio > boxRatio) then
		local keep = boxRatio / imgRatio
		u0, u1 = (1 - keep) / 2, (1 + keep) / 2
	else
		local keep = imgRatio / boxRatio
		v0, v1 = (1 - keep) / 2, (1 + keep) / 2
	end

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.DrawTexturedRectUV(x, y, w, h, u0, v0, u1, v1)
	return true
end

-- Teclas dibujadas con las texturas de EFT (efg/ui/key_*.png). str es una
-- combinación como "ALT + T", "LMB" o "CTRL + 1-5"; LMB, RMB, MMB, RUEDA y
-- RATÓN usan los iconos del ratón. Devuelve el ancho dibujado.
local mouseKeys = {LMB = "key_mouse_left", RMB = "key_mouse_right", MMB = "key_mouse_both", ["RATÓN"] = "key_mouse_both", RUEDA = "key_mouse_scroll"}

function UI.DrawKeys(str, x, y, h, font)
	font = font or "efgx.Num"
	local cx = x
	local parts = string.Explode("+", str)

	for i, raw in ipairs(parts) do
		local key = string.Trim(raw)

		if (i > 1) then
			local plus = UI.Mat("efg/ui/key_plus.png", "smooth")
			local pw = h * 0.3

			if (plus) then
				surface.SetMaterial(plus)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(cx + h * 0.08, y + h * 0.15, pw, h * 0.7)
			end

			cx = cx + pw + h * 0.16
		end

		local mouse = mouseKeys[key]

		if (mouse) then
			local mat = UI.Mat("efg/ui/" .. mouse .. ".png", "smooth")
			local mw = h * 28 / 38

			if (mat) then
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(cx, y, mw, h)
			end

			cx = cx + mw
		else
			surface.SetFont(font)
			local tw = surface.GetTextSize(key)
			local small = utf8.len(key) == 1
			local kw = small and h or math.max(h * 65 / 45, tw + h * 0.6)
			local mat = UI.Mat(small and "efg/ui/key_small.png" or "efg/ui/key_big.png", "smooth")

			if (mat) then
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(cx, y, kw, h)
			else
				surface.SetDrawColor(UI.color.bg3)
				surface.DrawRect(cx, y, kw, h)
				surface.SetDrawColor(UI.color.lineHi)
				surface.DrawOutlinedRect(cx, y, kw, h, 1)
			end

			draw.SimpleText(key, font, cx + kw / 2, y + h * 0.45, Color(20, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cx = cx + kw
		end
	end

	return cx - x
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

-- ─── Silueta corporal ────────────────────────────────────────────────────────
-- Figura propia de 7 zonas (cabeza, tórax, estómago, brazos y piernas) dentro
-- de un cuadro w×h (proporción ~1:2.2). parts[id] = {frac = 0..1, dead, bleed
-- (0, 1 leve, 2 grave), fracture, selected}. Cada zona es un cuadrilátero
-- convexo en sentido horario, como exige surface.DrawPoly.
UI.bodyShape = {
	head    = {{0.40, 0.00}, {0.60, 0.00}, {0.62, 0.10}, {0.38, 0.10}},
	thorax  = {{0.29, 0.12}, {0.71, 0.12}, {0.67, 0.35}, {0.33, 0.35}},
	stomach = {{0.33, 0.36}, {0.67, 0.36}, {0.66, 0.50}, {0.34, 0.50}},
	larm    = {{0.17, 0.13}, {0.28, 0.13}, {0.25, 0.49}, {0.08, 0.47}},
	rarm    = {{0.72, 0.13}, {0.83, 0.13}, {0.92, 0.47}, {0.75, 0.49}},
	lleg    = {{0.34, 0.52}, {0.49, 0.52}, {0.48, 1.00}, {0.33, 1.00}},
	rleg    = {{0.51, 0.52}, {0.66, 0.52}, {0.67, 1.00}, {0.52, 1.00}},
}

-- centro de cada zona (para marcas de herida y textos)
function UI.BodyPartCenter(id, x, y, w, h)
	local cx, cy = 0, 0
	for _, p in ipairs(UI.bodyShape[id]) do cx, cy = cx + p[1], cy + p[2] end
	return x + cx / 4 * w, y + cy / 4 * h
end

function UI.BodyPartHit(id, x, y, w, h, mx, my)
	local minX, minY, maxX, maxY = 1, 1, 0, 0
	for _, p in ipairs(UI.bodyShape[id]) do
		minX, minY = math.min(minX, p[1]), math.min(minY, p[2])
		maxX, maxY = math.max(maxX, p[1]), math.max(maxY, p[2])
	end
	return mx >= x + minX * w and mx <= x + maxX * w and my >= y + minY * h and my <= y + maxY * h
end

function UI.DrawBody(x, y, w, h, parts, alpha)
	local c = UI.color
	alpha = alpha or 1
	draw.NoTexture()

	for id, shape in pairs(UI.bodyShape) do
		local p = parts[id] or {frac = 1}
		local col = p.dead and c.crit or (p.frac > 0.6 and c.ok or (p.frac > 0.3 and c.warn or c.crit))
		local poly = {}

		for i, pt in ipairs(shape) do
			poly[i] = {x = x + pt[1] * w, y = y + pt[2] * h}
		end

		surface.SetDrawColor(c.bg3.r, c.bg3.g, c.bg3.b, 220 * alpha)
		surface.DrawPoly(poly)

		-- relleno de abajo arriba según la vida de la zona
		if (!p.dead and p.frac > 0) then
			local top = shape[1][2] + (shape[4][2] - shape[1][2]) * (1 - p.frac)
			local t = (top - shape[1][2]) / math.max(0.001, shape[4][2] - shape[1][2])
			local fill = {
				{x = x + Lerp(t, shape[1][1], shape[4][1]) * w, y = y + top * h},
				{x = x + Lerp(t, shape[2][1], shape[3][1]) * w, y = y + top * h},
				poly[3], poly[4]
			}
			surface.SetDrawColor(col.r, col.g, col.b, 170 * alpha)
			surface.DrawPoly(fill)
		end

		local line = p.selected and c.accent or (p.dead and c.crit or c.lineHi)
		surface.SetDrawColor(line.r, line.g, line.b, 255 * alpha)
		for i = 1, 4 do
			local a, b = poly[i], poly[i % 4 + 1]
			surface.DrawLine(a.x, a.y, b.x, b.y)
		end

		if (p.dead) then
			surface.SetDrawColor(c.crit.r, c.crit.g, c.crit.b, 255 * alpha)
			surface.DrawLine(poly[1].x, poly[1].y, poly[3].x, poly[3].y)
			surface.DrawLine(poly[2].x, poly[2].y, poly[4].x, poly[4].y)
		end

		local cx, cy = UI.BodyPartCenter(id, x, y, w, h)
		local mark = math.max(3, math.floor(w * 0.05))

		if ((p.bleed or 0) > 0) then
			surface.SetDrawColor(c.crit.r, c.crit.g, c.crit.b, 255 * alpha)
			surface.DrawRect(cx - mark, cy - mark, mark * 2, mark * (p.bleed == 2 and 3 or 2))
		end

		if (p.fracture) then
			surface.SetDrawColor(c.warn.r, c.warn.g, c.warn.b, 255 * alpha)
			surface.DrawRect(cx - mark * 2, cy - mark * 2 - 2, mark * 4, 2)
		end
	end
end

-- convierte la netvar efgHP en la tabla que espera UI.DrawBody
function UI.BodyFromNet(data)
	local parts = {}
	local health = ix.efg and ix.efg.health
	if (!health) then return parts end

	for i, part in ipairs(health.parts) do
		local entry = data and data[i]
		local hp, flags = entry and entry[1] or part.max, entry and entry[2] or 0

		parts[part.id] = {
			hp = hp, max = part.max, name = part.name,
			frac = math.Clamp(hp / part.max, 0, 1), dead = hp <= 0,
			bleed = bit.band(flags, 2) != 0 and 2 or (bit.band(flags, 1) != 0 and 1 or 0),
			fracture = bit.band(flags, 4) != 0
		}
	end

	return parts
end
