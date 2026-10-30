-- Menú principal al entrar al servidor (ixCharMenu), con la composición del
-- menú principal de Escape from Tarkov: escena desenfocada de fondo, logotipo
-- arriba, aviso naranja de versión beta, opciones centradas en columna y barra
-- inferior con accesos rápidos.
local PLUGIN = PLUGIN
local PANEL = {}

local VERSION = "0.1.0 Beta"

local textures = {
	bg = ix.util.GetMaterial("efgui/backgrounds/mainmenu.jpg", "noclamp smooth"),
	-- arte y logo de EFT (content/materials/efg/menu)
	art = ix.util.GetMaterial("efg/menu/main_art.jpg", "smooth"),
	logo = ix.util.GetMaterial("efg/menu/logo.png", "smooth mips"),
	gameIcon = ix.util.GetMaterial("efg/menu/sb_game_eft.png", "smooth"),
	gradient = ix.util.GetMaterial("vgui/gradient-u", "noclamp smooth"),
	gradientDown = ix.util.GetMaterial("vgui/gradient-d", "noclamp smooth"),
	gradientSide = ix.util.GetMaterial("vgui/gradient-l", "noclamp smooth"),
}

local colors = {
	text = Color(222, 224, 211),
	textDim = Color(150, 150, 140),
	hoverBg = Color(225, 225, 220, 235),
	hoverText = Color(20, 20, 20),
	banner = Color(226, 128, 40, 235),
	bannerText = Color(15, 15, 15),
	bar = Color(8, 9, 9, 235),
	barActive = Color(200, 200, 195, 235),
	green = Color(150, 200, 60),
}

local function S(v) return math.max(1, math.Round(v * ScrH() / 1080)) end

local function createFonts()
	-- MBender viene del port del HUD (content/resource/fonts/mbender.ttf)
	surface.CreateFont("efgMain.LogoSmall", {font = "MBender", extended = true, size = S(34), weight = 800})
	surface.CreateFont("efgMain.Logo", {font = "MBender", extended = true, size = S(170), weight = 900})
	surface.CreateFont("efgMain.BannerTitle", {font = "MBender", extended = true, size = S(22), weight = 700})
	surface.CreateFont("efgMain.BannerText", {font = "MBender", extended = true, size = S(16), weight = 500})
	surface.CreateFont("efgMain.Primary", {font = "MBender", extended = true, size = S(40), weight = 400})
	surface.CreateFont("efgMain.Button", {font = "MBender", extended = true, size = S(34), weight = 400})
	surface.CreateFont("efgMain.Bar", {font = "MBender", extended = true, size = S(15), weight = 500})
	surface.CreateFont("efgMain.Version", {font = "MBender", extended = true, size = S(13), weight = 500})
end

createFonts()
hook.Add("OnScreenSizeChanged", "efgMainMenu.Fonts", createFonts)
hook.Add("InitPostEntity", "efgMainMenu.Fonts", createFonts)

local function playClick() surface.PlaySound("efg/ui/click.wav") end

local function hasCharacter()
	return isfunction(LocalPlayer().GetCharacter) and LocalPlayer():GetCharacter() != nil
end

-- abre el TAB en una pestaña (ix_invkey)
local function openTab(id)
	if (IsValid(ix.gui.metroInventory)) then
		ix.gui.metroInventory:SwitchTab(id)
		return
	end

	ix.gui.invKeyStartTab = id
	if (vgui.GetControlTable("ixMetroInventory")) then
		ix.gui.metroInventory = vgui.Create("ixMetroInventory")
	end
end

function PANEL:Init()
	if (IsValid(ix.gui.loading)) then ix.gui.loading:Remove() end
	if (IsValid(ix.gui.MetroSpawnMenu)) then ix.gui.MetroSpawnMenu:Remove() end
	ix.gui.MetroSpawnMenu = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.4)

	self:StartMusic()
	self:BuildButtons()
	self:BuildBar()
end

function PANEL:StartMusic()
	timer.Simple(1, function()
		if (!IsValid(self) or !IsValid(LocalPlayer())) then return end
		if (IsValid(PLUGIN.ambientMusic) and PLUGIN.ambientMusic:GetState() == GMOD_CHANNEL_PLAYING) then return end
		if (hasCharacter()) then return end

		sound.PlayFile("sound/" .. PLUGIN.menuMusic, "noblock", function(station)
			if (!IsValid(station)) then return end
			-- sound.PlayFile es asíncrono: el personaje pudo cargar mientras tanto
			if (hasCharacter()) then station:Stop() return end

			PLUGIN.ambientMusic = station
			station:EnableLooping(true)
			station:SetVolume(0)
			station:Play()

			local steps = 20
			timer.Create("MetroUI_MusicFadeIn", 0.05, steps, function()
				if (IsValid(station)) then station:SetVolume(math.min(station:GetVolume() + 3 / steps, 3)) end
			end)
		end)
	end)
end

function PANEL:CloseMenu(callback)
	PLUGIN:FadeOutMusic(1)
	self:AlphaTo(0, 0.3, 0, function()
		self:Remove()
		if (callback) then callback() end
	end)
end

-- sustituye este menú por otro panel del menú de personajes
function PANEL:SwapTo(class)
	local panel = vgui.Create(class)
	self:AlphaTo(0, 0.3, 0, function() self:Remove() end)
	return panel
end

function PANEL:GetEntries()
	local creator = vgui.GetControlTable("efgPMCCreator") and "efgPMCCreator" or "metroCharacterCreation"

	if (!hasCharacter()) then
		return {
			{"ESCAPE FROM GMOD", function()
				-- sin personajes, directamente al creador
				self:SwapTo(#(ix.characters or {}) > 0 and "metroCharLoad" or creator)
			end, true},
			{"NUEVO PMC", function() self:SwapTo(creator) end},
			{"DISCORD", function() gui.OpenURL(ix.config.Get("discordURL", "https://example.com")) end},
			{"SALIR", function()
				vgui.Create("metroModal"):Setup("¿ESTÁS SEGURO?", "Vas a desconectarte del servidor.", nil, function()
					RunConsoleCommand("disconnect")
				end)
			end},
		}
	end

	return {
		{"ESCAPE FROM GMOD", function()
			self:CloseMenu(function()
				if (vgui.GetControlTable("efgxRaidSelectFull")) then vgui.Create("efgxRaidSelectFull") else openTab("raid") end
			end)
		end, true},
		{"PERSONAJE", function() self:CloseMenu(function() openTab("inv") end) end},
		{"COMERCIANTES", function() self:CloseMenu(function() openTab("traders") end) end},
		{"TAREAS", function() self:CloseMenu(function() openTab("tasks") end) end},
		{"ESCONDITE", function() self:CloseMenu(function() openTab("hideout") end) end},
		{"CAMBIAR PERSONAJE", function() self:SwapTo("metroCharLoad") end},
		{"SALIR", function()
			vgui.Create("metroModal"):Setup("¿ESTÁS SEGURO?", "Vas a desconectarte del servidor.", nil, function()
				RunConsoleCommand("disconnect")
			end)
		end},
	}
end

local function styleTextButton(button, font, primary)
	button:SetText("")
	button.font = font
	button.Paint = function(this, w, h)
		local hovered = this:IsHovered()

		if (hovered and !this.wasHovered) then surface.PlaySound("efg/ui/hover.wav") end
		this.wasHovered = hovered

		surface.SetFont(font)
		local tw, th = surface.GetTextSize(this.label)
		local padX = S(primary and 18 or 12)

		if (hovered) then
			surface.SetDrawColor(colors.hoverBg)
			surface.DrawRect(w / 2 - tw / 2 - padX, h / 2 - th / 2 - S(2), tw + padX * 2, th + S(4))
		end

		draw.SimpleText(this.label, font, w / 2, h / 2, hovered and colors.hoverText or colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function PANEL:BuildButtons()
	local entries = self:GetEntries()
	local y = S(470)
	local w = S(560)

	for i, entry in ipairs(entries) do
		local primary = entry[3]
		local h = primary and S(64) or S(52)
		local button = self:Add("DButton")
		button.label = entry[1]
		button:SetSize(w, h)
		button:SetPos(ScrW() / 2 - w / 2, y)
		styleTextButton(button, primary and "efgMain.Primary" or "efgMain.Button", primary)
		button.DoClick = function()
			playClick()
			entry[2]()
		end

		y = y + h + (primary and S(14) or S(2))
	end
end

-- barra inferior: menú principal y escondite a la izquierda, accesos a la
-- derecha (solo con personaje cargado)
function PANEL:BuildBar()
	local barH = S(26)
	local bar = self:Add("Panel")
	bar:SetSize(ScrW(), barH)
	bar:SetPos(0, ScrH() - barH)
	bar.Paint = function(_, w, h)
		surface.SetDrawColor(colors.bar)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 12)
		surface.DrawRect(0, 0, w, 1)

		-- dinero del personaje, a la derecha
		local character = hasCharacter() and LocalPlayer():GetCharacter()
		if (!character) then return end

		local money = string.Comma(character:GetMoney() or 0) .. " ₽"
		surface.SetFont("efgMain.Bar")
		local mw = surface.GetTextSize(money) + S(12)
		local mx, my = w - S(14) - mw, S(5)
		surface.SetDrawColor(colors.green)
		surface.DrawRect(mx, my, mw, h - S(10))
		draw.SimpleText(money, "efgMain.Bar", mx + mw / 2, h / 2, colors.hoverText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local active = hasCharacter()
	local function addItem(label, x, align, onClick, selected)
		surface.SetFont("efgMain.Bar")
		local tw = surface.GetTextSize(label)
		local item = bar:Add("DButton")
		item:SetText("")
		item:SetSize(tw + S(34), barH)
		item:SetPos(align == "right" and x - item:GetWide() or x, 0)
		item:SetEnabled(selected or (active and onClick != nil))
		item.Paint = function(this, w, h)
			local hovered = this:IsHovered() and this:IsEnabled()

			if (selected) then
				surface.SetDrawColor(colors.barActive)
				surface.DrawRect(0, S(3), w, h - S(6))
			elseif (hovered) then
				surface.SetDrawColor(255, 255, 255, 25)
				surface.DrawRect(0, S(3), w, h - S(6))
			end

			-- icono simple: tres rayas para el menú, cuadrado para el resto
			local ic = selected and colors.hoverText or (this:IsEnabled() and colors.text or colors.textDim)
			surface.SetDrawColor(ic)
			if (selected and !textures.gameIcon:IsError()) then
				surface.SetDrawColor(255, 255, 255)
				surface.SetMaterial(textures.gameIcon)
				surface.DrawTexturedRect(S(7), h / 2 - S(8), S(16), S(16))
			elseif (selected) then
				for i = 0, 2 do surface.DrawRect(S(9), h / 2 - S(5) + i * S(4), S(12), S(2)) end
			else
				surface.DrawOutlinedRect(S(10), h / 2 - S(5), S(10), S(10), 1)
			end

			draw.SimpleText(label, "efgMain.Bar", S(27), h / 2, ic, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		item.DoClick = function()
			if (!onClick) then return end
			playClick()
			onClick()
		end
		return item
	end

	local x = S(8)
	x = x + addItem("MENÚ PRINCIPAL", x, "left", nil, true):GetWide() + S(4)
	addItem("ESCONDITE", x, "left", function() self:CloseMenu(function() openTab("hideout") end) end)

	local rightItems = {
		{"AJUSTES", "settings"}, {"MERCADILLO", "flea"}, {"TAREAS", "tasks"}, {"COMERCIANTES", "traders"}, {"PERSONAJE", "inv"},
	}

	local rx = ScrW() - S(140)
	for _, it in ipairs(rightItems) do
		local tab = it[2]
		local item = addItem(it[1], rx, "right", function() self:CloseMenu(function() openTab(tab) end) end)
		rx = rx - item:GetWide() - S(4)
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE and hasCharacter()) then
		playClick()
		self:CloseMenu()
	end
end

local function drawLogo(w)
	local cx = w / 2
	local top = S(70)

	if (!textures.logo:IsError()) then
		local lw = S(640)
		local lh = math.min(lw * textures.logo:Height() / math.max(textures.logo:Width(), 1), S(300))
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(textures.logo)
		surface.DrawTexturedRect(cx - lw / 2, top - S(20), lw, lh)
		return
	end

	draw.SimpleText("BETA TESTING", "efgMain.LogoSmall", cx - S(330), top, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("ESCAPE FROM", "efgMain.LogoSmall", cx, top + S(40), colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	-- "GMOD" grande con sombra, como el bloque de letras del logotipo original
	draw.SimpleText("GMOD", "efgMain.Logo", cx + S(4), top + S(66), Color(0, 0, 0, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText("GMOD", "efgMain.Logo", cx, top + S(62), colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local function drawBanner(w)
	local bw, bh = S(855), S(64)
	local x, y = w / 2 - bw / 2, S(372)

	surface.SetDrawColor(colors.banner)
	surface.DrawRect(x, y, bw, bh)

	-- icono de alerta: círculo negro con "!"
	local ix_, iy = x + S(26), y + bh / 2
	local r = S(15)
	draw.RoundedBox(r, ix_ - r, iy - r, r * 2, r * 2, colors.bannerText)
	draw.SimpleText("!", "efgMain.BannerTitle", ix_, iy, colors.banner, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText("¡Atención! Esta es una versión Beta de \"Escape from Gmod\".", "efgMain.BannerTitle",
		x + S(54), y + S(10), colors.bannerText)
	draw.SimpleText("Esta versión Beta no representa la calidad final del producto. Gracias por tu comprensión y apoyo. ¡Buena suerte!",
		"efgMain.BannerText", x + S(54), y + S(38), colors.bannerText)
end

function PANEL:Paint(w, h)
	-- escena del mapa desenfocada detrás (como el fondo borroso del original);
	-- si no hay mundo todavía, la imagen del menú
	if (hasCharacter() or IsValid(LocalPlayer())) then
		ix.util.DrawBlur(self, 10)
	end

	-- arte de EFT sin deformar; tenue si detrás ya está el mapa
	local alpha = hasCharacter() and 90 or 255
	local drawn = ix.efgui and ix.efgui.DrawCover and ix.efgui.DrawCover(textures.art, 0, 0, w, h, alpha)

	if (!drawn and !hasCharacter()) then
		surface.SetDrawColor(255, 255, 255, 70)
		surface.SetMaterial(textures.bg)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	-- tinte frío y viñetas arriba y abajo
	surface.SetDrawColor(10, 16, 12, 150)
	surface.DrawRect(0, 0, w, h)
	surface.SetMaterial(textures.gradientDown)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawTexturedRect(0, 0, w, h * 0.35)
	surface.SetMaterial(textures.gradient)
	surface.DrawTexturedRect(0, h * 0.6, w, h * 0.4)

	-- viñeta lateral, como el menú de EFT
	surface.SetMaterial(textures.gradientSide)
	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawTexturedRect(0, 0, w * 0.22, h)
	surface.DrawTexturedRectUV(w * 0.78, 0, w * 0.22, h, 1, 0, 0, 1)

	drawLogo(w)
	drawBanner(w)

	draw.SimpleText(VERSION, "efgMain.Version", S(10), h - S(26) - S(4), colors.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end

vgui.Register("ixCharMenu", PANEL, "EditablePanel")
