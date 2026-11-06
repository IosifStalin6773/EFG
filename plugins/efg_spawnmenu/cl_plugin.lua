-- Skin EFT para el menú Q (spawn menu de GMod). Solo cambia el aspecto:
-- el acceso lo decide plugins/contextmenu y las pestañas son las de siempre.

local UI = ix.efgui
local C = UI and UI.color or {}

local function Col(color, fallback)
	return color or fallback
end

local bg1    = Col(C.bg1, Color(28, 30, 27, 245))
local bg2    = Col(C.bg2, Color(37, 39, 35, 245))
local bg3    = Col(C.bg3, Color(48, 51, 46, 245))
local line   = Col(C.line, Color(58, 61, 54))
local lineHi = Col(C.lineHi, Color(86, 90, 80))
local text   = Col(C.text, Color(200, 198, 180))
local text2  = Col(C.text2, Color(154, 152, 136))
local accent = Col(C.accent, Color(227, 114, 45))

local SKIN_NAME = "efg_spawn"

local function CreateFonts()
	local scale = math.max(ScrH() / 1080, 0.6)

	surface.CreateFont("efgSpawn.Title", {font = "MBender", extended = true, size = math.Round(22 * scale), weight = 700, antialias = true})
	surface.CreateFont("efgSpawn.Body", {font = "MBender", extended = true, size = math.Round(18 * scale), weight = 500, antialias = true})
	surface.CreateFont("efgSpawn.Small", {font = "MBender", extended = true, size = math.Round(15 * scale), weight = 500, antialias = true})
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "efgSpawn_Fonts", CreateFonts)

local function SetColour(tbl, key, value)
	if (istable(tbl) and tbl[key] != nil) then
		tbl[key] = value
	end
end

local base = derma.GetNamedSkin("Default")

if (base) then
	local SKIN = table.Copy(base)

	SKIN.PrintName = "EFG Menú Q"
	SKIN.Author = "EFG Project"
	SKIN.fontFrame = "efgSpawn.Title"
	SKIN.fontButton = "efgSpawn.Body"
	SKIN.fontTab = "efgSpawn.Body"
	SKIN.fontCategoryHeader = "efgSpawn.Body"
	SKIN.fontMenuOption = "efgSpawn.Small"

	SKIN.Colours = table.Copy(base.Colours or {})
	local colours = SKIN.Colours

	if (colours.Window) then
		SetColour(colours.Window, "TitleActive", text)
		SetColour(colours.Window, "TitleInactive", text2)
	end

	if (colours.Button) then
		SetColour(colours.Button.Normal, "Text", text)
		SetColour(colours.Button.Hover, "Text", accent)
		SetColour(colours.Button.Down, "Text", accent)
	end

	if (colours.Tree) then
		SetColour(colours.Tree.Normal, "Text", text2)
		SetColour(colours.Tree.Hover, "Text", text)
		SetColour(colours.Tree.Selected, "Text", accent)
		SetColour(colours.Tree.Selected, "Background", bg3)
	end

	if (colours.Label) then
		SetColour(colours.Label.Default, "Text", text)
		SetColour(colours.Label.Bright, "Text", text)
	end

	SKIN.bg_color = bg1
	SKIN.bg_color_sleep = bg2
	SKIN.bg_color_bright = bg3
	SKIN.combobox_selected = bg3

	function SKIN:PaintFrame(panel, w, h)
		surface.SetDrawColor(bg1)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(accent)
		surface.DrawRect(0, 0, w, 3)
	end

	function SKIN:PaintPanel(panel, w, h)
		if (!panel.m_bBackground) then return end

		surface.SetDrawColor(bg2)
		surface.DrawRect(0, 0, w, h)
	end

	function SKIN:PaintButton(panel, w, h)
		if (!panel.m_bBackground) then return end

		local fill = bg2
		local border = line

		if (panel.Depressed or panel:IsSelected()) then
			fill = bg3
			border = accent
		elseif (panel.Hovered) then
			fill = bg3
			border = lineHi
		end

		surface.SetDrawColor(fill)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	derma.DefineSkin(SKIN_NAME, "Skin EFT para el menú Q", SKIN)
end

hook.Add("OnSpawnMenuOpen", "efgSpawn_ApplySkin", function()
	if (!derma.GetNamedSkin(SKIN_NAME)) then return end

	if (IsValid(g_SpawnMenu)) then
		g_SpawnMenu:SetSkin(SKIN_NAME)
		g_SpawnMenu:InvalidateChildren(true)
	end
end)
