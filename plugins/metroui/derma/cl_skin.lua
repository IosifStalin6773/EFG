
local gradient = surface.GetTextureID("vgui/gradient-d")
local gradientUp = surface.GetTextureID("vgui/gradient-u")
local gradientLeft = surface.GetTextureID("vgui/gradient-l")
local gradientRadial = Material("helix/gui/radial-gradient.png")
local defaultBackgroundColor = Color(30, 30, 30, 200)

-- Ritmo del latido de la pantalla de inconsciencia (ixDeathScreen): tanto el
-- pulso rojo (PaintDeathScreenBackground) como el sonido (más abajo) usan el
-- mismo periodo para que vayan sincronizados.
local HEARTBEAT_PERIOD = 1.1

local function registerChatFonts()
	local scale = ix and ix.option and ix.option.Get("chatFontScale", 1) or 1
	local chatSize = math.max(ScreenScale(7), 17) * scale

	surface.CreateFont("ixChatFont", {
		font = "Bender",
		size = chatSize,
		extended = true,
		weight = 500,
		antialias = true
	})

	surface.CreateFont("ixChatFontItalics", {
		font = "Bender",
		size = chatSize,
		extended = true,
		weight = 500,
		antialias = true,
		italic = true
	})

	-- Misma familia/peso que el HUD del inventario (ixInv.*), pero a tamaño
	-- "huge" para textos de pantalla completa (p.ej. ixDeathScreen). Helix por
	-- defecto usa "Roboto Th" en peso 100 ahí, que no tiene nada que ver.
	surface.CreateFont("ixHugeFontMetro", {
		font = "Bender",
		size = math.max(ScreenScale(24), 48),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Redefinimos estas dos fuentes DE HELIX por su mismo nombre (mismo truco
	-- que arriba): cualquier panel que las use (el texto de los botones del
	-- menú de objetos como "BEBER", y los títulos "importantes" de tooltip
	-- como "Armario") pasa a heredar Capture Smallz automáticamente, sin tener
	-- que parchear cada panel uno a uno.
	surface.CreateFont("ixMenuButtonFont", {
		font = "Bender",
		size = ScreenScale(14),
		weight = 600,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixSmallTitleFont", {
		font = "Bender",
		size = math.max(ScreenScale(12), 24),
		weight = 600,
		extended = true,
		antialias = true
	})
end

hook.Add("InitializedConfig", "metroChatFontOverride", function()
	timer.Simple(0, registerChatFonts)
end)
hook.Add("OnScreenSizeChanged", "metroChatFonts", registerChatFonts)

local SKIN = {}
derma.DefineSkin("helix", "The base skin for the Helix framework.", SKIN)

SKIN.fontCategory = "ixMediumLightFont"
SKIN.fontCategoryBlur = "ixMediumLightBlurFont"
SKIN.fontSegmentedProgress = "ixMediumLightFont"

SKIN.Colours = table.Copy(derma.SkinList.Default.Colours)

SKIN.Colours.Info = Color(100, 185, 255)
SKIN.Colours.Success = Color(64, 185, 85)
SKIN.Colours.Error = Color(255, 100, 100)
SKIN.Colours.Warning = Color(230, 180, 0)
SKIN.Colours.MenuLabel = color_white
SKIN.Colours.DarkerBackground = Color(0, 0, 0, 77)

SKIN.Colours.SegmentedProgress = {}
SKIN.Colours.SegmentedProgress.Bar = Color(64, 185, 85)
SKIN.Colours.SegmentedProgress.Text = color_white

SKIN.Colours.Area = {}

SKIN.Colours.Window.TitleActive = Color(0, 0, 0)
SKIN.Colours.Window.TitleInactive = color_white

SKIN.Colours.Button.Normal = color_white
SKIN.Colours.Button.Hover = color_white
SKIN.Colours.Button.Down = Color(180, 180, 180)
SKIN.Colours.Button.Disabled = Color(0, 0, 0, 100)

SKIN.Colours.Label.Default = color_white

function SKIN.tex.Menu_Strip(x, y, width, height, color)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(ColorAlpha(color or ix.config.Get("color"), 175))
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(x, y, width, height)

	surface.SetTextColor(color_white)
end

hook.Add("ColorSchemeChanged", "ixSkin", function(color)
	SKIN.Colours.Area.Background = color
end)

function SKIN:DrawHelixCurved(x, y, radius, segments, barHeight, fraction, color, altColor)
	radius = radius or math.min(ScreenScale(72), 128) * 2
	segments = segments or 76
	barHeight = barHeight or 64
	color = color or ix.config.Get("color")
	altColor = altColor or Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, color.a)
	fraction = fraction or 1

	surface.SetTexture(-1)

	for i = 1, math.ceil(segments) do
		local angle = math.rad((i / segments) * -360)
		local barX = x + math.sin(angle + (fraction * math.pi * 2)) * radius
		local barY = y + math.cos(angle + (fraction * math.pi * 2)) * radius
		local barOffset = math.sin(SysTime() + i * 0.5)

		if (barOffset > 0) then
			surface.SetDrawColor(color)
		else
			surface.SetDrawColor(altColor)
		end

		surface.DrawTexturedRectRotated(barX, barY, 4, barOffset * (barHeight * fraction), math.deg(angle))
	end
end

function SKIN:DrawHelix(x, y, width, height, segments, color, fraction, speed)
	segments = segments or width * 0.05
	color = color or ix.config.Get("color")
	fraction = fraction or 0.25
	speed = speed or 1

	for i = 1, math.ceil(segments) do
		local offset = math.sin((SysTime() + speed) + i * fraction)
		local barHeight = height * offset

		surface.SetTexture(-1)

		if (offset > 0) then
			surface.SetDrawColor(color)
		else
			surface.SetDrawColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, color.a)
		end

		surface.DrawTexturedRectRotated(x + (i / segments) * width, y + height * 0.5, 4, barHeight, 0)
	end
end

function SKIN:PaintFrame(panel)
	if (!panel.bNoBackgroundBlur) then
		ix.util.DrawBlur(panel, 10)
	end

	-- EFG: panel EFT (carbón con rejilla) y cabecera rayada
	if (ix.efgui) then
		ix.efgui.DrawPanel(0, 0, panel:GetWide(), panel:GetTall(), 240)

		if (panel:GetTitle() != "" or panel.btnClose:IsVisible()) then
			ix.efgui.DrawHeader(0, 0, panel:GetWide(), 24)
		end

		return
	end

	surface.SetDrawColor(30, 30, 30, 150)
	surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())

	if (panel:GetTitle() != "" or panel.btnClose:IsVisible()) then
		surface.SetDrawColor(ix.config.Get("color"))
		surface.DrawRect(0, 0, panel:GetWide(), 24)
	end

	surface.SetDrawColor(ix.config.Get("color"))
	surface.DrawOutlinedRect(0, 0, panel:GetWide(), panel:GetTall())
end

function SKIN:PaintBaseFrame(panel, width, height)
	if (!panel.bNoBackgroundBlur) then
		ix.util.DrawBlur(panel, 10)
	end

	if (ix.efgui) then
		ix.efgui.DrawPanel(0, 0, width, height, 240)
		return
	end

	surface.SetDrawColor(30, 30, 30, 150)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(ix.config.Get("color"))
	surface.DrawOutlinedRect(0, 0, width, height)
end

function SKIN:DrawImportantBackground(x, y, width, height, color)
	color = color or defaultBackgroundColor

	surface.SetTexture(gradientLeft)
	surface.SetDrawColor(color)
	surface.DrawTexturedRect(x, y, width, height)
end

function SKIN:DrawCharacterStatusBackground(panel, fraction)
	surface.SetDrawColor(0, 0, 0, fraction * 100)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	ix.util.DrawBlurAt(0, 0, ScrW(), ScrH(), 5, nil, fraction * 255)
end

function SKIN:PaintPanel(panel)
	if (panel.m_bBackground) then
		local width, height = panel:GetSize()
		if (panel.m_bgColor) then
			surface.SetDrawColor(panel.m_bgColor)
		else
			surface.SetDrawColor(20, 22, 22, 200)
		end
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(52, 55, 52, 255)
		surface.DrawOutlinedRect(0, 0, width, height)
	end
end

function SKIN:PaintMenuBackground(panel, width, height, alphaFraction)
	alphaFraction = alphaFraction or 1

	surface.SetDrawColor(ColorAlpha(color_black, alphaFraction * 255))
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, width, height)

	ix.util.DrawBlur(panel, alphaFraction * 15, nil, 200)
end

function SKIN:PaintPlaceholderPanel(panel, width, height, barWidth, padding)
	local size = math.max(width, height)
	barWidth = barWidth or size * 0.05

	local segments = size / barWidth

	for i = 1, segments do
		surface.SetTexture(-1)
		surface.SetDrawColor(0, 0, 0, 88)
		surface.DrawTexturedRectRotated(i * barWidth, i * barWidth, barWidth, size * 2, -45)
	end
end

function SKIN:PaintCategoryPanel(panel, text, color)
	text = text or ""
	color = color or ix.config.Get("color")

	surface.SetFont(self.fontCategoryBlur)

	local textHeight = select(2, surface.GetTextSize(text)) + 6
	local width, height = panel:GetSize()

	surface.SetDrawColor(0, 0, 0, 100)
	surface.DrawRect(0, textHeight, width, height - textHeight)

	self:DrawImportantBackground(0, 0, width, textHeight, color)

	surface.SetTextColor(color_black)
	surface.SetTextPos(4, 4)
	surface.DrawText(text)

	surface.SetFont(self.fontCategory)
	surface.SetTextColor(color_white)
	surface.SetTextPos(4, 4)
	surface.DrawText(text)

	surface.SetDrawColor(color)
	surface.DrawOutlinedRect(0, 0, width, height)

	return 1, textHeight, 1, 1
end

function SKIN:PaintButton(panel)
	if (panel.m_bBackground) then
		local w, h = panel:GetWide(), panel:GetTall()
		local alpha = 50

		if (panel:GetDisabled()) then
			alpha = 10
		elseif (panel.Depressed) then
			alpha = 180
		elseif (panel.Hovered) then
			alpha = 75
		end

		if (panel:GetParent() and panel:GetParent():GetName() == "DListView_Column") then
			surface.SetDrawColor(color_white)
			surface.DrawRect(0, 0, w, h)
		end

		-- botón plano EFT: gris oscuro, borde fino y relleno tan al pulsar
		if (panel.Depressed) then
			surface.SetDrawColor(154, 136, 102, 200)
		else
			surface.SetDrawColor(30 + alpha * 0.2, 32 + alpha * 0.2, 31 + alpha * 0.2, 235)
		end
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(panel.Hovered and Color(110, 108, 96) or Color(58, 61, 58))
		surface.DrawOutlinedRect(0, 0, w, h)

		surface.SetDrawColor(0, 0, 0, 180)
		surface.DrawOutlinedRect(0, 0, w, h)

		surface.SetDrawColor(180, 180, 180, 2)
		surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
	end
end

-- Misma estética que el panel de inventario (ix_invkey): panel translúcido
-- con blur, esquinas redondeadas, borde cálido sutil y una franja de acento
-- arriba, en vez de bordes duros + corchetes de esquina.
function SKIN:PaintMetroTooltip(panel, width, height, alphaMul)
	alphaMul = alphaMul or 1
	local theme = ixInvTheme
	local C = theme and theme.C
	local RAD = (theme and theme.RAD) or 4

	if (!C) then
		-- Fallback si ixInvTheme aún no ha cargado (no debería pasar en juego).
		draw.RoundedBox(3, 0, 0, width, height, Color(10, 9, 8, 205 * alphaMul))
		return
	end

	if (IsValid(panel)) then
		ix.util.DrawBlur(panel, 4)
	end

	draw.RoundedBox(RAD, 0, 0, width, height, ColorAlpha(C.panel, C.panel.a * alphaMul))
	surface.SetDrawColor(ColorAlpha(C.panelLine, C.panelLine.a * alphaMul))
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	draw.RoundedBoxEx(RAD, 0, 0, width, 3, ColorAlpha(C.accent, 230 * alphaMul), true, true, false, false)
end

function SKIN:PaintEntityInfoBackground(panel, width, height)
	self:PaintMetroTooltip(panel, width, height)
end

function SKIN:PaintTooltipBackground(panel, width, height)
	self:PaintMetroTooltip(panel, width, height)
end

function SKIN:PaintTooltipMinimalBackground(panel, width, height)
	self:PaintMetroTooltip(panel, width, height, panel.fraction or 1)
end

function SKIN:PaintSegmentedProgressBackground(panel, width, height)
end

function SKIN:PaintSegmentedProgress(panel, width, height)
	local font = panel:GetFont() or self.fontSegmentedProgress
	local textColor = panel:GetTextColor() or self.Colours.SegmentedProgress.Text
	local barColor = panel:GetBarColor() or self.Colours.SegmentedProgress.Bar
	local segments = panel:GetSegments()
	local segmentHalfWidth = width / #segments * 0.5

	surface.SetDrawColor(barColor)
	surface.DrawRect(0, 0, panel:GetFraction() * width, height)

	for i = 1, #segments do
		local text = segments[i]
		local x = (i - 1) / #segments * width + segmentHalfWidth
		local y = height * 0.5

		draw.SimpleText(text, font, x, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function SKIN:PaintCharacterCreateBackground(panel, width, height)
	surface.SetDrawColor(40, 40, 40, 255)
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, width, height)
end

function SKIN:PaintCharacterLoadBackground(panel, width, height)
	surface.SetDrawColor(40, 40, 40, panel:GetBackgroundFraction() * 255)
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, width, height)
end

function SKIN:PaintCharacterTransitionOverlay(panel, x, y, width, height, color)
	color = color or ix.config.Get("color")

	surface.SetDrawColor(color)
	surface.DrawRect(x, y, width, height)
end

function SKIN:PaintAreaEntry(panel, width, height)
	local color = ColorAlpha(panel:GetBackgroundColor() or self.Colours.Area.Background, panel:GetBackgroundAlpha())

	self:DrawImportantBackground(0, 0, width, height, color)
end

function SKIN:PaintListRow(panel, width, height)
	surface.SetDrawColor(0, 0, 0, 150)
	surface.DrawRect(0, 0, width, height)
end

function SKIN:PaintSettingsRowBackground(panel, width, height)
	local index = panel:GetBackgroundIndex()
	local bReset = panel:GetShowReset()

	if (index == 0) then
		surface.SetDrawColor(30, 30, 30, 45)
		surface.DrawRect(0, 0, width, height)
	end

	if (bReset) then
		surface.SetDrawColor(self.Colours.Warning)
		surface.DrawRect(0, 0, 2, height)
	end
end

function SKIN:PaintVScrollBar(panel, width, height)
end

function SKIN:PaintScrollBarGrip(panel, width, height)
	local parent = panel:GetParent()
	local upButtonHeight = parent.btnUp:GetTall()
	local downButtonHeight = parent.btnDown:GetTall()

	DisableClipping(true)
		surface.SetDrawColor(110, 108, 96, 200)
		surface.DrawRect(4, -upButtonHeight, width - 8, height + upButtonHeight + downButtonHeight)
	DisableClipping(false)
end

function SKIN:PaintButtonUp(panel, width, height)
end

function SKIN:PaintButtonDown(panel, width, height)
end

function SKIN:PaintComboBox(panel, width, height)
end

function SKIN:PaintComboDownArrow(panel, width, height)
	surface.SetFont("ixIconsSmall")

	local textWidth, textHeight = surface.GetTextSize("r")
	local alpha = (panel.ComboBox:IsMenuOpen() or panel.ComboBox.Hovered) and 200 or 100

	surface.SetTextColor(ColorAlpha(ix.config.Get("color"), alpha))
	surface.SetTextPos(width * 0.5 - textWidth * 0.5, height * 0.5 - textHeight * 0.5)
	surface.DrawText("r")
end

function SKIN:PaintMenu(panel, width, height)
	ix.util.DrawBlur(panel)

	surface.SetDrawColor(16, 17, 17, 245)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(58, 61, 58)
	surface.DrawOutlinedRect(0, 0, width, height)
end

function SKIN:PaintMenuOption(panel, width, height)
	if (panel.m_bBackground and (panel.Hovered or panel.Highlight)) then
		surface.SetDrawColor(199, 197, 179, 30)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(154, 136, 102)
		surface.DrawRect(0, 0, 2, height)
	end
end

function SKIN:PaintHelixSlider(panel, width, height)
	surface.SetDrawColor(self.Colours.DarkerBackground)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(self.Colours.Success)
	surface.DrawRect(0, 0, panel:GetVisualFraction() * width, height)
end

function SKIN:PaintChatboxTabButton(panel, width, height)
	if (panel:GetActive()) then
		surface.SetDrawColor(18, 14, 8, 220)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(170, 155, 115, 220)
		surface.DrawRect(0, height - 2, width, 2)
	else
		surface.SetDrawColor(10, 8, 5, 180)
		surface.DrawRect(0, 0, width, height)

		if (panel:GetUnread()) then
			local pulse = math.sin(CurTime() * 3) * 0.5 + 0.5
			surface.SetDrawColor(154, 136, 102, pulse * 120)
			surface.DrawRect(0, height - 2, width, 2)
		end
	end

	surface.SetDrawColor(80, 55, 20, 140)
	surface.DrawRect(width - 1, 2, 1, height - 4)
end

function SKIN:PaintChatboxTabs(panel, width, height, alpha)
	surface.SetDrawColor(8, 6, 4, 225)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(40, 28, 12, 60)
	surface.SetTexture(gradient)
	surface.DrawTexturedRect(0, 0, width, height)

	surface.SetDrawColor(70, 64, 50, 140)
	surface.DrawRect(0, height - 1, width, 1)
end

function SKIN:PaintChatboxBackground(panel, width, height)
	ix.util.DrawBlur(panel, 10)

	local flicker = 0.97 + math.sin(CurTime() * 8.7) * 0.015 + math.sin(CurTime() * 13.3) * 0.01
	local baseAlpha = math.floor(225 * flicker)

	surface.SetDrawColor(8, 6, 4, baseAlpha)
	surface.DrawRect(0, 0, width, height)

	if (panel:GetActive()) then
		surface.SetDrawColor(50, 35, 12, 25)
		surface.SetTexture(gradientUp)
		surface.DrawTexturedRect(0, 0, width, height * 0.12)
	end

	surface.SetDrawColor(70, 64, 50, 200)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	surface.SetDrawColor(55, 38, 15, 80)
	surface.DrawOutlinedRect(2, 2, width - 4, height - 4, 1)

	surface.SetDrawColor(170, 155, 115, 160)
	surface.DrawRect(1, 0, width - 2, 1)

	local bk = 12
	surface.SetDrawColor(170, 155, 115, 140)
	surface.DrawRect(0, 0, bk, 1);            surface.DrawRect(0, 0, 1, bk)
	surface.DrawRect(width - bk, 0, bk, 1);   surface.DrawRect(width - 1, 0, 1, bk)
	surface.DrawRect(0, height - 1, bk, 1);   surface.DrawRect(0, height - bk, 1, bk)
	surface.DrawRect(width - bk, height - 1, bk, 1); surface.DrawRect(width - 1, height - bk, 1, bk)
end

function SKIN:PaintChatboxEntry(panel, width, height)
	surface.SetDrawColor(5, 4, 3, 200)
	surface.DrawRect(0, 0, width, height)

	panel:DrawTextEntryText(Color(199, 197, 179), Color(170, 155, 115), Color(199, 197, 179))

	surface.SetDrawColor(70, 64, 50, 140)
	surface.DrawRect(0, 0, width, 1)

	surface.SetDrawColor(170, 155, 115, 80)
	surface.DrawRect(0, 1, 1, height - 1)
end

function SKIN:DrawChatboxPreviewBox(x, y, text, color)
	local textWidth, textHeight = surface.GetTextSize(text)
	local width, height = textWidth + 10, textHeight + 6

	surface.SetDrawColor(8, 6, 4, 220)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(170, 155, 115, 160)
	surface.DrawRect(x, y, 2, height)

	surface.SetTextColor(199, 197, 179)
	surface.SetTextPos(x + 6, y + height * 0.5 - textHeight * 0.5)
	surface.DrawText(text)

	surface.SetDrawColor(80, 55, 20, 140)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	return width
end

function SKIN:DrawChatboxPrefixBox(panel, width, height)
	local color = panel:GetBackgroundColor()

	surface.SetDrawColor(8, 6, 4, 200)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(color)
	surface.DrawRect(0, 0, 2, height)

	surface.SetDrawColor(80, 55, 20, 100)
	surface.DrawOutlinedRect(0, 0, width, height, 1)
end

function SKIN:PaintChatboxAutocompleteEntry(panel, width, height)
	if (panel.highlightAlpha > 0) then
		surface.SetDrawColor(170, 155, 115, panel.highlightAlpha * 50)
		surface.SetTexture(gradientLeft)
		surface.DrawTexturedRect(0, 0, width * 0.6, height)

		surface.SetDrawColor(170, 155, 115, panel.highlightAlpha * 160)
		surface.DrawRect(0, 0, 2, height)
	end

	surface.SetDrawColor(80, 55, 20, 50)
	surface.DrawRect(8, height - 5, width - 16, 1)
end

hook.Add("InitPostEntity", "metroui.ChatboxOverrides", function()
	local acMeta = vgui.GetControlTable("ixChatboxAutocomplete")
	if (acMeta) then
		acMeta.Paint = function(self, width, height)
			ix.util.DrawBlur(self)

			surface.SetDrawColor(8, 6, 4, 220)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(70, 64, 50, 180)
			surface.DrawOutlinedRect(0, 0, width, height, 1)

			surface.SetDrawColor(170, 155, 115, 100)
			surface.DrawRect(0, 0, 2, height)
		end
	end

	local entryMeta = vgui.GetControlTable("ixChatboxAutocompleteEntry")
	if (entryMeta) then
		local origSize = entryMeta.SizeToContents
		entryMeta.SizeToContents = function(self)
			origSize(self)
			self:SetTall(self:GetTall() + 8)
		end
	end

	-- Botones del menú de objetos (p.ej. "BEBER" al mirar una botella en el
	-- suelo): mismo panel traslúcido con blur que usa el inventario (ixInvTheme),
	-- en vez de texto blanco plano o el borde+corchetes que se probó antes.
	local entMenuBtnMeta = vgui.GetControlTable("ixEntityMenuButton")
	if (entMenuBtnMeta) then
		local origInit = entMenuBtnMeta.Init
		entMenuBtnMeta.Init = function(self)
			origInit(self)
			local C = ixInvTheme and ixInvTheme.C
			self:SetTextColor(C and C.white or Color(238, 233, 225, 255))
			self.backgroundColor = C and C.accent or Color(154, 136, 102)
			self.backgroundAlpha = 60
		end

		entMenuBtnMeta.PaintBackground = function(self, width, height)
			local theme = ixInvTheme
			local C = theme and theme.C

			if (!C) then
				surface.SetDrawColor(10, 9, 8, 210)
				surface.DrawRect(0, 0, width, height)
				return
			end

			ix.util.DrawBlur(self, 4)
			draw.RoundedBox(theme.RAD, 0, 0, width, height, C.panel)
			surface.SetDrawColor(C.panelLine)
			surface.DrawOutlinedRect(0, 0, width, height, 1)

			if (self.currentBackgroundAlpha > 1) then
				surface.SetDrawColor(ColorAlpha(C.accentGlow, self.currentBackgroundAlpha))
				surface.DrawRect(0, 0, width, height)
			end

			surface.SetDrawColor(C.accent)
			surface.DrawRect(0, height - 2, width, 2)
		end
	end

	-- Pantalla de "inconsciente" (ixDeathScreen): usaba "Roboto Th" en peso 100
	-- (fuente por defecto de Helix), nada que ver con "Capture Smallz" que usa
	-- el resto del HUD. Le ponemos la misma fuente/color que las cabeceras del
	-- inventario y recalculamos tamaño/posición porque cambia de fuente.
	local deathMeta = vgui.GetControlTable("ixDeathScreen")
	if (deathMeta) then
		local HEARTBEAT_SOUND = "player/heartbeat1.wav"

		local function stopHeartbeat()
			timer.Remove("ixDeathScreenHeartbeat")
			local ply = LocalPlayer()
			if (IsValid(ply)) then
				ply:StopSound(HEARTBEAT_SOUND)
			end
		end

		local origInit = deathMeta.Init
		deathMeta.Init = function(self)
			origInit(self)

			-- El texto empieza a aparecer quando progress > 0.3 (ver PANEL:Think
			-- original en cl_deathscreen.lua: alpha = ((progress-0.3)/0.3)*255).
			-- El latido debe arrancar en ese mismo instante, no al abrirse el panel.
			local spawnTime = ix.config.Get("spawnTime", 5)
			local textDelay = spawnTime * 0.3

			local function beat()
				local ply = LocalPlayer()
				if (IsValid(ply)) then
					-- Cortar la instancia anterior antes de emitir la nueva: si no,
					-- las repeticiones se van solapando (satura el audio) y una sola
					-- StopSound al final no basta para matarlas todas.
					ply:StopSound(HEARTBEAT_SOUND)
					ply:EmitSound(HEARTBEAT_SOUND, 60, 100, 0.85, CHAN_STATIC)
				end
			end

			stopHeartbeat() -- por si quedaba algo de una pantalla anterior

			timer.Simple(textDelay, function()
				if (!IsValid(self) or self:IsClosing()) then return end
				beat()
				timer.Create("ixDeathScreenHeartbeat", HEARTBEAT_PERIOD, 0, beat)
			end)

			if (!IsValid(self.label)) then return end

			local C = ixInvTheme and ixInvTheme.C

			self.label:SetFont("ixHugeFontMetro")
			self.label:SetTextColor(C and C.accent or Color(154, 136, 102, 255))
			self.label:SetExpensiveShadow(2, Color(15, 10, 4, 255))
			self.label:SizeToContents()

			local scrW, scrH = ScrW(), ScrH()
			self.label:SetPos(scrW * 0.5 - self.label:GetWide() * 0.5, scrH * 0.5 - self.label:GetTall() * 0.5)
		end

		local origClose = deathMeta.Close
		deathMeta.Close = function(self)
			stopHeartbeat()
			origClose(self)
		end

		-- Red de seguridad: si el panel se destruye sin pasar por Close() (p.ej.
		-- desconexión a mitad), el latido no debe quedarse sonando.
		local origOnRemove = deathMeta.OnRemove
		deathMeta.OnRemove = function(self)
			stopHeartbeat()
			if (origOnRemove) then origOnRemove(self) end
		end
	end
end)

hook.Add("ChatboxCreated", "metroChatAutocompleteColors", function()
	timer.Simple(0, function()
		if (!IsValid(ix.gui.chat)) then return end

		local ac = ix.gui.chat.autocomplete
		if (!IsValid(ac)) then return end

		local nameColor = Color(170, 155, 115)
		local descColor = Color(190, 170, 130)

		local origUpdate = ac.Update
		ac.Update = function(self, text)
			origUpdate(self, text)

			for _, panel in ipairs(self.commandPanels) do
				if (IsValid(panel)) then
					if (IsValid(panel.name)) then
						panel.name:SetTextColor(nameColor)
					end
					if (IsValid(panel.description)) then
						panel.description:SetTextColor(descColor)
					end
				end
			end
		end
	end)
end)

do
	local crtGradDown = surface.GetTextureID("vgui/gradient-d")
	local crtGradUp = surface.GetTextureID("vgui/gradient-u")

	hook.Add("PostChatboxDraw", "metroChatCRT", function(width, height, alpha)
		if (alpha < 1) then return end

		surface.SetDrawColor(0, 0, 0, 18)
		for y = 0, height, 3 do
			surface.DrawRect(0, y, width, 1)
		end

		local scanY = math.floor((CurTime() * 55) % (height + 30) - 15)
		for i = -3, 3 do
			local ly = scanY + i
			if (ly >= 0 and ly < height) then
				local intensity = 1 - math.abs(i) / 4
				surface.SetDrawColor(200, 150, 50, math.floor(12 * intensity))
				surface.DrawRect(0, ly, width, 1)
			end
		end

		surface.SetDrawColor(0, 0, 0, 30)
		surface.SetTexture(crtGradDown)
		surface.DrawTexturedRect(0, 0, width, height * 0.06)

		surface.SetTexture(crtGradUp)
		surface.DrawTexturedRect(0, height * 0.94, width, height * 0.06)
	end)
end

function SKIN:PaintWindowMinimizeButton(panel, width, height)
end

function SKIN:PaintWindowMaximizeButton(panel, width, height)
end

function SKIN:PaintInfoBar(panel, width, height, color)
	-- bar
	surface.SetDrawColor(color.r, color.g, color.b, 250)
	surface.DrawRect(0, 0, width, height)

	-- gradient overlay
	surface.SetDrawColor(230, 230, 230, 8)
	surface.SetTexture(gradientUp)
	surface.DrawTexturedRect(0, 0, width, height)
end

function SKIN:PaintInfoBarBackground(panel, width, height)
	surface.SetDrawColor(230, 230, 230, 15)
	surface.DrawRect(0, 0, width, height)
	surface.DrawOutlinedRect(0, 0, width, height)

	panel.bar:PaintManual()

	DisableClipping(true)
		panel.label:PaintManual()
	DisableClipping(false)
end

-- Celda de rejilla EFT (textura efgui/cell)
function SKIN:PaintInventorySlot(panel, width, height)
	if (ix.efgui) then
		ix.efgui.DrawCell(0, 0, width, height)
		return
	end

	surface.SetDrawColor(18, 19, 19, 230)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(46, 49, 47, 255)
	surface.DrawOutlinedRect(0, 0, width, height, 1)
end

function SKIN:PaintDeathScreenBackground(panel, width, height, progress)
	surface.SetDrawColor(0, 0, 0, (progress / 0.3) * 255)
	surface.DrawRect(0, 0, width, height)

	-- Pulso rojo tipo latido: sube de golpe y decae despacio, al mismo ritmo
	-- que el sonido del corazón (HEARTBEAT_PERIOD, ver el bloque InitPostEntity).
	if (progress > 0.3) then
		local phase = (CurTime() % HEARTBEAT_PERIOD) / HEARTBEAT_PERIOD
		local pulse = math.max(0, 1 - phase * 3)
		local pulseAlpha = pulse * 65 * progress

		if (pulseAlpha > 0) then
			surface.SetDrawColor(140, 12, 12, pulseAlpha)
			surface.DrawRect(0, 0, width, height)
		end
	end
end

-- Forzar reaparición manteniendo F: aviso de "mantén F" + barra de progreso,
-- unos segundos después de que aparece el texto de "Estás inconsciente" (ver
-- Schema:PlayerButtonDown en schema/sv_hooks.lua, que valida el hold real).
-- Va aquí (dentro del Paint del propio panel) y NO en HUDPaint: HUDPaint se
-- pinta ANTES que los paneles VGUI, así que el fondo negro de esta pantalla
-- lo taparía por completo.
local ixForceRespawnHoldStart = nil

function SKIN:PaintDeathScreen(panel, width, height, progress)
	ix.bar.DrawAction()

	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local textDelay = ix.config.Get("spawnTime", 60) * 0.3
	local threshold = textDelay + ix.config.Get("forceRespawnDelay", 10)
	local elapsed = CurTime() - client:GetNetVar("deathStartTime", 0)

	if (elapsed < threshold) then
		ixForceRespawnHoldStart = nil
		return
	end

	local holdTime = ix.config.Get("forceRespawnHold", 10)
	local down = input.IsKeyDown(KEY_F)

	if (down) then
		ixForceRespawnHoldStart = ixForceRespawnHoldStart or CurTime()
	else
		ixForceRespawnHoldStart = nil
	end

	local heldFor = ixForceRespawnHoldStart and (CurTime() - ixForceRespawnHoldStart) or 0
	local frac = math.Clamp(heldFor / holdTime, 0, 1)

	local C = ixInvTheme and ixInvTheme.C
	local accent = (C and C.accent) or Color(154, 136, 102)
	local panelBg = (C and C.panel) or Color(20, 17, 14, 165)
	local panelLine = (C and C.panelLine) or Color(80, 66, 48, 90)

	local barW, barH = ScreenScale(160), 6
	local barX, barY = width * 0.5 - barW * 0.5, height * 0.72

	draw.SimpleText("MANTÉN [F] PARA FORZAR LA REAPARICIÓN", "ixInv.Header",
		width * 0.5, barY - 14, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

	surface.SetDrawColor(panelBg)
	surface.DrawRect(barX, barY, barW, barH)

	surface.SetDrawColor(accent)
	surface.DrawRect(barX, barY, barW * frac, barH)

	surface.SetDrawColor(panelLine)
	surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
end

do
	-- check if sounds exist, otherwise fall back to default UI sounds
	local bWhoosh = file.Exists("sound/helix/ui/whoosh1.wav", "GAME")
	local bRollover = file.Exists("sound/helix/ui/rollover.wav", "GAME")
	local bPress = file.Exists("sound/helix/ui/press.wav", "GAME")
	local bNotify = file.Exists("sound/helix/ui/REPLACEME.wav", "GAME") -- @todo

	sound.Add({
		name = "Helix.Whoosh",
		channel = CHAN_STATIC,
		volume = 0.4,
		level = 80,
		pitch = bWhoosh and {90, 105} or 100,
		sound = bWhoosh and {
			"helix/ui/whoosh1.wav",
			"helix/ui/whoosh2.wav",
			"helix/ui/whoosh3.wav",
			"helix/ui/whoosh4.wav",
			"helix/ui/whoosh5.wav",
			"helix/ui/whoosh6.wav"
		} or ""
	})

	sound.Add({
		name = "Helix.Rollover",
		channel = CHAN_STATIC,
		volume = 0.5,
		level = 80,
		pitch = {95, 105},
		sound = bRollover and "helix/ui/rollover.wav" or "ui/buttonrollover.wav"
	})

	sound.Add({
		name = "Helix.Press",
		channel = CHAN_STATIC,
		volume = 0.5,
		level = 80,
		pitch = bPress and {95, 110} or 100,
		sound = bPress and "helix/ui/press.wav" or "ui/buttonclickrelease.wav"
	})

	sound.Add({
		name = "Helix.Notify",
		channel = CHAN_STATIC,
		volume = 0.35,
		level = 80,
		pitch = 140,
		sound = bNotify and "helix/ui/REPLACEME.wav" or "weapons/grenade/tick1.wav"
	})
end

derma.RefreshSkins()
