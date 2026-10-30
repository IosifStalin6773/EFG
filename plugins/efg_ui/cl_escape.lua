-- ESC cierra el panel EFG/Helix que esté abierto (VGUI o DHTML) en vez de
-- abrir el menú de pausa de GMod. Si no hay ninguno, ESC abre el menú normal.
-- Un DHTML con el foco se traga la tecla, así que hay dos vías:
--   1. hook OnPauseMenuShow (GMod lo llama antes de mostrar el menú de pausa)
--   2. respaldo en Think: si el menú de GMod se abrió igualmente con un panel
--      nuestro encima, se oculta y se cierra el panel.

ix.efgui = ix.efgui or {}

-- clases que ESC puede cerrar. Un panel también se apunta con panel.efgEsc = true
-- (o con ix.efgui.RegisterEsc(panel)).
local CLOSABLE = {
	"^efgx",            -- todos los paneles EFG (menús, raid, inspección, flea...)
	"^ixMetroInventory", -- TAB
	"^ixStorageView",
	"^ixInventory$",
	"^ixMenu$",
	"^ixTrade",
	"^ixTraderMenu",
}

-- paneles que no se cierran nunca con ESC (chat, HUD, menú de personaje)
local KEEP = {
	ixChatbox = true,
	ixCharMenu = true,
}

function ix.efgui.RegisterEsc(panel)
	if (IsValid(panel)) then panel.efgEsc = true end
	return panel
end

local function closable(panel)
	if (!IsValid(panel) or !panel:IsVisible()) then return false end

	local class = panel.ClassName or panel:GetClassName() or ""
	if (KEEP[class] or panel.efgNoEsc) then return false end
	if (panel.efgEsc) then return true end

	for _, pattern in ipairs(CLOSABLE) do
		if (class:find(pattern)) then return true end
	end

	return false
end

-- el último hijo del WorldPanel es el que está delante
local function topPanel()
	local children = vgui.GetWorldPanel():GetChildren()

	for i = #children, 1, -1 do
		if (closable(children[i])) then return children[i] end
	end
end

local function anyPopupLeft()
	for _, child in ipairs(vgui.GetWorldPanel():GetChildren()) do
		if (IsValid(child) and child:IsVisible() and child:IsMouseInputEnabled() and (child:IsPopup() or closable(child))) then
			return true
		end
	end

	return false
end

-- panel de delante en el frame anterior: si ya no existe, se cerró él solo con
-- su propio OnKeyCodePressed(KEY_ESCAPE) y no hay que cerrar otro más
local lastTop

function ix.efgui.CloseTop()
	if (lastTop and !IsValid(lastTop)) then
		lastTop = nil
		return true
	end

	local panel = topPanel()
	if (!panel) then return false end

	if (panel.OnEscape and panel:OnEscape() == false) then return true end

	if (panel.Close) then panel:Close() else panel:Remove() end

	-- devuelve el ratón al juego si ya no queda ningún popup
	timer.Simple(0, function()
		if (!anyPopupLeft()) then
			gui.EnableScreenClicker(false)
			RememberCursorPosition()
		end
	end)

	surface.PlaySound("efg/ui/click.wav")
	return true
end

-- ESC sin nada abierto: el menú principal de EFG (efg_menus) en vez del de
-- GMod. El menú de GMod solo sale desde ahí ("AJUSTES DEL JUEGO") o sin
-- personaje cargado (pantalla de personajes).
function ix.efgui.OpenPauseMenu()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter() or IsValid(ix.gui.characterMenu)) then return false end
	if (!vgui.GetControlTable("efgxMainMenu")) then return false end

	if (IsValid(ix.gui.efgMain)) then
		ix.gui.efgMain:Remove()
	else
		vgui.Create("efgxMainMenu")
		surface.PlaySound("efg/ui/click.wav")
	end

	return true
end

function ix.efgui.ShowGameMenu()
	ix.efgui.allowGameUI = true
	gui.ActivateGameUI()
end

-- 1. vía normal: GMod pregunta antes de abrir el menú de pausa
hook.Add("OnPauseMenuShow", "efgEscClose", function()
	if (ix.efgui.allowGameUI) then
		ix.efgui.allowGameUI = nil
		return
	end

	if (ix.efgui.CloseTop()) then return false end
	if (ix.efgui.OpenPauseMenu()) then return false end
end)

-- 2. respaldo: el DHTML con el foco hizo que el menú se abriera igualmente
local escDown = false

hook.Add("Think", "efgEscFallback", function()
	local down = input.IsKeyDown(KEY_ESCAPE)

	if (down and !escDown and gui.IsGameUIVisible() and topPanel()) then
		gui.HideGameUI()
		ix.efgui.CloseTop()
	end

	escDown = down
	lastTop = topPanel() or false
end)

-- por si un panel se borra sin limpiar el cursor
concommand.Add("efg_unlock", function()
	for _, child in ipairs(vgui.GetWorldPanel():GetChildren()) do
		if (closable(child)) then child:Remove() end
	end

	gui.EnableScreenClicker(false)
	if (gui.IsGameUIVisible()) then gui.HideGameUI() end
end)
