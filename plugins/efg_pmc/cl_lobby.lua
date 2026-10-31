-- Secciones del menú principal de EFG: Personaje, Comerciantes, Escondite,
-- Escape (raid), Mercadillo y Ajustes. Ya no hay tecla F4: el inventario TAB
-- (ix_invkey) usa estos Build_* como pestañas. Cada acción se pide al
-- servidor por net (ixEFGLobbyAction) y allí pasa por la misma validación que
-- los comandos (/Raid, /RaidScav, /Escondite, /Mercadillo).

local PMC = ix.efg.pmc
local LOGO = Material("efgui/logo32028.png", "smooth")
local BACKGROUND = Material("efgui/backgrounds/mainmenu.jpg", "smooth")
local LOYALTY = {"loyalty_one", "loyalty_two", "loyalty_three", "loyalty_king_new"}

local function lobbyAction(action, argument)
	net.Start("ixEFGLobbyAction")
		net.WriteString(action)
		net.WriteString(argument or "")
	net.SendToServer()
end

PMC.LobbyAction = lobbyAction

local function inRaid()
	local client = LocalPlayer()
	return client.InRaid and client:InRaid()
end

local PANEL = {}

function PANEL:Init()
	local UI = ix.efgui
	local s = UI.Scale
	local sw, sh = ScrW(), ScrH()

	if (IsValid(ix.gui.efgLobby)) then ix.gui.efgLobby:Remove() end
	ix.gui.efgLobby = self

	self:SetSize(sw, sh)
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.2)

	self.topH = s(64)
	self.bottomH = s(78)

	-- zona de contenido
	self.content = self:Add("DPanel")
	self.content:SetPos(s(40), self.topH + s(20))
	self.content:SetSize(sw - s(80), sh - self.topH - self.bottomH - s(40))
	self.content.Paint = nil

	-- barra inferior de pestañas (como la de EFT)
	local tabs = {
		{id = "character", label = "Personaje"},
		{id = "traders", label = "Comerciantes"},
		{id = "hideout", label = "Escondite"},
		{id = "raid", label = "Escape from Gmod", wide = true},
		{id = "flea", label = "Mercadillo"},
		{id = "settings", label = "Ajustes"},
	}

	local unit = s(170)
	local totalW = 0
	for _, tab in ipairs(tabs) do totalW = totalW + (tab.wide and unit * 1.6 or unit) + s(6) end

	local x = sw / 2 - totalW / 2
	self.tabButtons = {}

	for _, tab in ipairs(tabs) do
		local w = tab.wide and unit * 1.6 or unit
		local b = self:Add("DButton")
		b:SetPos(x, sh - self.bottomH + s(14))
		b:SetSize(w, self.bottomH - s(28))
		b:SetText(tab.label)
		UI.StyleButton(b, tab.wide and "efgui.Title" or "efgui.Header")
		b.Think = function(this) this.efgActive = (self.tab == tab.id) end
		b.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")
			self:SetTab(tab.id)
		end
		self.tabButtons[tab.id] = b
		x = x + w + s(6)
	end

	local close = self:Add("DButton")
	close:SetSize(s(110), s(30))
	close:SetPos(sw - s(130), self.topH / 2 - s(15))
	close:SetText("Cerrar")
	UI.StyleButton(close, "efgui.Small")
	close.DoClick = function() self:Remove() end

	self:SetTab("character")
end

function PANEL:SetTab(id)
	self.tab = id
	self.content:Clear()

	local builder = self["Build_" .. id]
	if (builder) then builder(self, self.content) end
end

-- tarjeta con cabecera, usada por todas las pestañas
local function card(parent, x, y, w, h, title)
	local UI = ix.efgui
	local p = parent:Add("DPanel")
	p:SetPos(x, y)
	p:SetSize(w, h)
	p.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
		UI.DrawHeader(0, 0, pw, UI.Scale(30), title)
	end
	return p
end

local function text(parent, x, y, w, str, font, color)
	local l = parent:Add("DLabel")
	l:SetPos(x, y)
	l:SetWide(w)
	l:SetFont(font or "efgui.Normal")
	l:SetTextColor(color or ix.efgui.color.text)
	l:SetWrap(true)
	l:SetAutoStretchVertical(true)
	l:SetText(str)
	return l
end

local function button(parent, x, y, w, h, label, onClick, primary)
	local b = parent:Add("DButton")
	b:SetPos(x, y)
	b:SetSize(w, h)
	b:SetText(label)
	ix.efgui.StyleButton(b, "efgui.Header")
	b.efgActive = primary
	b.DoClick = function()
		surface.PlaySound("ui/buttonclickrelease.wav")
		onClick()
	end
	return b
end

-- ─── Personaje ───────────────────────────────────────────────────────────────
function PANEL:Build_character(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w, h = parent:GetSize()
	local character = LocalPlayer():GetCharacter()
	if (!character) then return end

	local model = parent:Add("DModelPanel")
	model:SetPos(0, 0)
	model:SetSize(w * 0.4, h)
	model:SetModel(LocalPlayer():GetModel())
	model:SetFOV(32)
	model:SetCamPos(Vector(110, 0, 46))
	model:SetLookAt(Vector(0, 0, 38))
	model:SetAmbientLight(Color(60, 62, 60))
	model:SetDirectionalLight(BOX_FRONT, Color(210, 205, 190))
	model.LayoutEntity = function(this, entity)
		entity:SetAngles(Angle(0, 25, 0))
		this:RunAnimation()
	end

	if (IsValid(model.Entity)) then
		local entity = model.Entity
		entity:SetSkin(LocalPlayer():GetSkin())

		for _, bodygroup in ipairs(LocalPlayer():GetBodyGroups()) do
			entity:SetBodygroup(bodygroup.id, LocalPlayer():GetBodygroup(bodygroup.id))
		end

		local seq = entity:LookupSequence("idle_all_01")
		if (seq and seq > 0) then entity:ResetSequence(seq) end
	end

	local info = card(parent, w * 0.42, 0, w * 0.58, h, "Perfil del PMC")
	local iw = w * 0.58 - s(40)
	local xp = character.GetEFGXP and character:GetEFGXP() or 0
	local level = ix.efg.GetLevel and ix.efg.GetLevel(xp) or 1
	local nextXP = ix.efg.levels and ix.efg.levels[level + 1]
	local stats = character:GetData("efgStats", {})
	local sideKey = PMC.GetSideKey(character:GetFaction())
	local faction = ix.faction.indices[character:GetFaction()]

	text(info, s(20), s(46), iw, character:GetName(), "efgui.Huge")
	-- insignia de nivel EFT (ix.efg.utils.LevelBadge)
	local badgeX = s(20)
	local badgePath = ix.efg.utils and ix.efg.utils.LevelBadge(level)

	if (badgePath and file.Exists("materials/" .. badgePath, "GAME")) then
		local badge = info:Add("DImage")
		badge:SetPos(s(20), s(92))
		badge:SetSize(s(36), s(36))
		badge:SetMaterial(Material(badgePath, "smooth mips"))
		badge:SetKeepAspect(true)
		badgeX = s(64)
	end

	text(info, badgeX, s(96), iw - (badgeX - s(20)), ("%s  ·  NIVEL %d"):format(faction and faction.name or "?", level), "efgui.Title", UI.color.accent)

	local bar = info:Add("DPanel")
	bar:SetPos(s(20), s(136))
	bar:SetSize(iw, s(30))
	bar.Paint = function(_, bw, bh)
		local prev = ix.efg.levels[level] or 0
		local frac = nextXP and math.Clamp((xp - prev) / math.max(nextXP - prev, 1), 0, 1) or 1
		surface.SetDrawColor(UI.color.cell)
		surface.DrawRect(0, bh - s(8), bw, s(8))
		surface.SetDrawColor(UI.color.accent)
		surface.DrawRect(0, bh - s(8), bw * frac, s(8))
		draw.SimpleText(nextXP and ("%s / %s XP"):format(string.Comma(xp), string.Comma(nextXP)) or (string.Comma(xp) .. " XP (nivel máximo)"),
			"efgui.Small", 0, 0, UI.color.textDim)
	end

	local lines = {
		("Raids: %d    Sobrevividas: %d    Muertes: %d    MIA: %d"):format(stats.raids or 0, stats.survived or 0, stats.killed or 0, stats.mia or 0),
		("Bajas: %d"):format(stats.kills or 0),
		("Rublos: %s RUB"):format(string.Comma(character:GetMoney() or 0)),
	}

	if (sideKey) then
		local voice = PMC.voices[character:GetEfgVoice() or 1]
		lines[#lines + 1] = ("Cara %d  ·  %s (la voz se cambia en Ajustes)"):format(character:GetEfgFace() or 1, voice and voice.name or "Voz 1")
	end

	for i, line in ipairs(lines) do
		text(info, s(20), s(180) + (i - 1) * s(28), iw, line, "efgui.Normal", UI.color.text)
	end

	button(info, s(20), h - s(64), s(260), s(44), "Abrir inventario (TAB)", function()
		self:Remove()
		if (IsValid(ix.gui.metroInventory)) then ix.gui.metroInventory:Remove() end
		ix.gui.metroInventory = vgui.Create("ixMetroInventory")
	end, true)

	button(info, s(290), h - s(64), s(260), s(44), "Abrir alijo", function()
		lobbyAction("stash")
		self:Remove()
	end)
end

-- ─── Comerciantes ────────────────────────────────────────────────────────────
function PANEL:Build_traders(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w, h = parent:GetSize()
	local character = LocalPlayer():GetCharacter()
	if (!character or !ix.traders) then return end

	local keys = ix.traders.factions or {}
	local cols = 4
	local gap = s(12)
	local cw = (w - gap * (cols - 1)) / cols
	local rows = math.ceil(#keys / cols)
	local ch = math.min((h - s(40) - gap * (rows - 1)) / rows, s(300))

	text(parent, 0, 0, w, inRaid() and "No puedes comerciar durante una raid." or "Elige un comerciante. El nivel de lealtad (LL) depende de tu nivel de PMC y de tu reputación con él.",
		"efgui.Normal", inRaid() and UI.color.red or UI.color.textDim)

	for i, key in ipairs(keys) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local rep = ix.traders.GetEffectiveRep(character, key)
		local ll = ix.traders.GetRepLevel(rep)
		local emblem = Material("efgui/traders/" .. key .. ".png", "smooth")

		local b = parent:Add("DButton")
		b:SetText("")
		b:SetPos(col * (cw + gap), s(40) + row * (ch + gap))
		b:SetSize(cw, ch)
		b.Paint = function(this, bw, bh)
			UI.DrawPanel(0, 0, bw, bh, 235)
			if (this:IsHovered()) then
				surface.SetDrawColor(UI.color.select)
				surface.DrawRect(0, 0, bw, bh)
				UI.DrawCorners(0, 0, bw, bh, UI.color.accent)
			end

			local size = math.min(bw * 0.55, bh * 0.55)
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(emblem)
			surface.DrawTexturedRect(bw / 2 - size / 2, s(14), size, size)

			draw.SimpleText(string.upper(ix.traders.names[key] or key), "efgui.Title", bw / 2, s(22) + size, UI.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			local level = table.KeyFromValue(ix.traders.repLevels, ll) or 1
			draw.SimpleText(("LL%d  ·  rep %d"):format(level, rep), "efgui.Normal",
				bw / 2, s(56) + size, ll.color or UI.color.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			-- icono de lealtad de EFT en la esquina del retrato (corona en LL4)
			local icon = UI.Mat(("efg/ui/%s.png"):format(LOYALTY[math.Clamp(level, 1, 4)]), "smooth")
			if (icon) then
				local ih = s(22)
				local iw = ih * icon:Width() / math.max(icon:Height(), 1)
				surface.SetMaterial(icon)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(bw / 2 + size / 2 - iw - s(4), s(14) + size - ih - s(4), iw, ih)
			end

			if (this:IsHovered()) then
				local stripes = UI.Mat("efg/ui/image_diagonal_trader.png", "smooth")
				if (stripes) then
					surface.SetMaterial(stripes)
					surface.SetDrawColor(255, 255, 255, 18)
					surface.DrawTexturedRectUV(0, 0, bw, bh, 0, 0, bw / 64, bh / 64)
				end
			end
		end
		b.DoClick = function()
			if (inRaid()) then return end
			surface.PlaySound("ui/buttonclickrelease.wav")
			lobbyAction("trader", key)
			self:Remove()
		end
	end
end

-- ─── Escondite ───────────────────────────────────────────────────────────────
function PANEL:Build_hideout(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w = parent:GetWide()
	local c = card(parent, 0, 0, w * 0.6, s(260), "Escondite")

	text(c, s(20), s(46), w * 0.6 - s(40),
		"Tu refugio. Mejora los módulos (generador, banco de trabajo, estación médica, lavabo, unidad de nutrición, zona de descanso y centro de inteligencia) con rublos y materiales del alijo. Cada módulo da bonificaciones y desbloquea recetas.",
		"efgui.Normal", UI.color.text)

	button(c, s(20), s(260) - s(64), s(260), s(44), "Abrir escondite", function()
		lobbyAction("hideout")
		self:Remove()
	end, true)

	button(c, s(290), s(260) - s(64), s(260), s(44), "Abrir alijo", function()
		lobbyAction("stash")
		self:Remove()
	end)
end

-- ─── Escape (raid) ───────────────────────────────────────────────────────────
function PANEL:Build_raid(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w, h = parent:GetSize()
	local cw = (w - s(20)) / 2
	local minutes = ix.config.Get("efgRaidMinutes", 35)

	text(parent, 0, 0, w, ("Mapa: %s  ·  Duración de la raid: %d min"):format(game.GetMap(), minutes), "efgui.Header", UI.color.text)

	local pmc = card(parent, 0, s(40), cw, h - s(40), "PMC")
	text(pmc, s(20), s(50), cw - s(40),
		"Entras con tu propio equipo. Si mueres o no extraes a tiempo pierdes todo lo que llevas encima salvo el contenedor seguro. Si extraes, ganas experiencia y te quedas el botín.\n\nSi eres líder de grupo, entra todo el grupo contigo (/GrupoInvitar).",
		"efgui.Normal", UI.color.text)

	local scav = card(parent, cw + s(20), s(40), cw, h - s(40), "Scav")
	text(scav, s(20), s(50), cw - s(40),
		("Entras como Scav con equipo aleatorio. Tu PMC no arriesga nada y lo que saques va a tu alijo, pero no ganas experiencia. Los Scavs de la IA no te atacan.\n\nEspera entre Scav runs: %d min."):format(ix.config.Get("efgScavCooldown", 20)),
		"efgui.Normal", UI.color.text)

	local busy = inRaid()

	local deploy = button(pmc, s(20), h - s(40) - s(64), cw - s(40), s(48), busy and "Ya estás en una raid" or "Desplegar como PMC", function()
		lobbyAction("raid")
		self:Remove()
	end, !busy)
	deploy:SetEnabled(!busy)

	local scavButton = button(scav, s(20), h - s(40) - s(64), cw - s(40), s(48), "Desplegar como Scav", function()
		lobbyAction("scav")
		self:Remove()
	end)
	scavButton.Think = function(this)
		local left = (LocalPlayer():GetData("efgNextScav", 0) or 0) - os.time()

		if (busy) then
			this:SetText("Ya estás en una raid")
			this:SetEnabled(false)
		elseif (left > 0) then
			this:SetText(("Scav disponible en %d:%02d"):format(math.floor(left / 60), left % 60))
			this:SetEnabled(false)
		else
			this:SetText("Desplegar como Scav")
			this:SetEnabled(true)
		end
	end
end

-- ─── Mercadillo ──────────────────────────────────────────────────────────────
function PANEL:Build_flea(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w = parent:GetWide()
	local character = LocalPlayer():GetCharacter()
	local required = ix.config.Get("efgFleaLevel", 15)
	local level = character and character.GetEFGLevel and character:GetEFGLevel() or 1
	local c = card(parent, 0, 0, w * 0.6, s(240), "Mercadillo")

	text(c, s(20), s(46), w * 0.6 - s(40),
		("Mercado entre jugadores: pon objetos a la venta a precio fijo o compra los de otros. Publicar cuesta una comisión.\n\nSe desbloquea al nivel %d (tú: nivel %d)."):format(required, level),
		"efgui.Normal", UI.color.text)

	local open = button(c, s(20), s(240) - s(64), s(260), s(44), level >= required and "Abrir mercadillo" or "Bloqueado", function()
		lobbyAction("flea")
		self:Remove()
	end, level >= required)
	open:SetEnabled(level >= required)
end

-- ─── Ajustes ─────────────────────────────────────────────────────────────────
-- se definen más abajo; el TAB llama a Build_settings con su propio panel como
-- self, así que no pueden ser métodos de efgLobby
local buildSettingsGame, buildSettingsVoice

function PANEL:Build_settings(parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w, h = parent:GetSize()

	-- subpestañas: JUEGO (opciones de Helix aquí mismo), CONTROLES y VOZ
	local tabs = {{"game", "JUEGO"}, {"controls", "CONTROLES"}, {"voice", "VOZ"}}
	local body = parent:Add("DPanel")
	body:SetPos(0, s(56))
	body:SetSize(w, math.max(h - s(56), s(300)))
	body:SetPaintBackground(false)

	local current = parent.efgSettingsTab or "game"

	local function show(id)
		parent.efgSettingsTab = id
		current = id
		body:Clear()

		if (id == "game") then
			buildSettingsGame(body)
		elseif (id == "controls" and vgui.GetControlTable("efgxControls")) then
			local controls = body:Add("efgxControls")
			controls:Dock(FILL)
		else
			buildSettingsVoice(self, body)
		end
	end

	for i, t in ipairs(tabs) do
		local b = button(parent, (i - 1) * s(210), 0, s(200), s(44), t[2], function() show(t[1]) end)
		b.Think = function(this) this.efgActive = current == t[1] end
	end

	show(current)
end

-- opciones de Helix (las mismas que su menú de Ajustes) dentro del TAB
function buildSettingsGame(parent)
	if (vgui.GetControlTable("efgxGameSettings")) then
		local panel = parent:Add("efgxGameSettings")
		panel:Dock(FILL)
		return
	end

	local menuTabs = {}
	hook.Run("CreateMenuButtons", menuTabs)

	local info = menuTabs["settings"]

	if (info and info.Create) then
		local container = parent:Add("DPanel")
		container:Dock(FILL)
		container.Paint = function(_, pw, ph) ix.efgui.DrawPanel(0, 0, pw, ph, 235) end

		info.Create(info, container)
		return
	end

	text(parent, 0, 0, parent:GetWide(), "Las opciones de Helix no están disponibles.", "efgui.Normal", ix.efgui.color.textDim)
end

function buildSettingsVoice(owner, parent)
	local UI = ix.efgui
	local s = UI.Scale
	local w = parent:GetWide()
	local character = LocalPlayer():GetCharacter()
	local sideKey = character and PMC.GetSideKey(character:GetFaction())
	local c = card(parent, 0, 0, w * 0.5, s(300), "Voz del PMC")

	if (!sideKey) then
		text(c, s(20), s(46), w * 0.5 - s(40), "Solo los PMC (USEC/BEAR) tienen voz configurable.", "efgui.Normal", UI.color.textDim)
	else
		text(c, s(20), s(46), w * 0.5 - s(40), "La voz se puede cambiar cuando quieras. La cara se eligió al crear el PMC y no se puede cambiar.", "efgui.Normal", UI.color.textDim)

		for i, voice in ipairs(PMC.voices) do
			local b = button(c, s(20) + (i - 1) * s(170), s(110), s(160), s(44), voice.name, function()
				net.Start("ixEFGSetVoice")
					net.WriteUInt(i, 4)
				net.SendToServer()
			end)
			b.Think = function(this) this.efgActive = (character:GetEfgVoice() or 1) == i end
		end

		button(c, s(20), s(170), s(330), s(40), "Escuchar mi voz", function()
			local voice = PMC.voices[character:GetEfgVoice() or 1] or PMC.voices[1]
			local path = PMC.RandomVoicePath(sideKey, "ready") or PMC.RandomVoicePath(sideKey, "yes")
			if (path) then LocalPlayer():EmitSound(path, 75, voice.pitch) end
		end)
	end

	local other = card(parent, w * 0.5 + s(20), 0, w * 0.5 - s(20), s(300), "Personajes")
	text(other, s(20), s(46), w * 0.5 - s(60), "Cambiar de personaje o crear uno nuevo.", "efgui.Normal", UI.color.textDim)

	button(other, s(20), s(110), s(300), s(44), "Personajes", function()
		owner:Remove()
		vgui.Create("ixCharMenu")
	end)
end

function PANEL:Paint(w, h)
	local UI = ix.efgui
	local s = UI.Scale
	local character = LocalPlayer():GetCharacter()

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(BACKGROUND)
	surface.DrawTexturedRect(0, 0, w, h)
	surface.SetDrawColor(6, 7, 7, 120)
	surface.DrawRect(0, 0, w, h)

	-- barra superior: logo y datos del PMC
	surface.SetDrawColor(10, 11, 11, 235)
	surface.DrawRect(0, 0, w, self.topH)
	surface.SetDrawColor(UI.color.line)
	surface.DrawRect(0, self.topH - 1, w, 1)

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(LOGO)
	surface.DrawTexturedRect(s(20), s(4), s(224), s(56))

	if (character) then
		local level = character.GetEFGLevel and character:GetEFGLevel() or 1
		local right = w - s(150)

		draw.SimpleText(character:GetName(), "efgui.Title", right, s(10), UI.color.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(("NIVEL %d  ·  %s RUB"):format(level, string.Comma(character:GetMoney() or 0)), "efgui.Small",
			right, s(40), UI.color.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	-- barra inferior
	surface.SetDrawColor(10, 11, 11, 235)
	surface.DrawRect(0, h - self.bottomH, w, self.bottomH)
	surface.SetDrawColor(UI.color.line)
	surface.DrawRect(0, h - self.bottomH, w, 1)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (ix.gui.efgLobby == self) then ix.gui.efgLobby = nil end
end

vgui.Register("efgLobby", PANEL, "EditablePanel")

-- ─── Apertura ────────────────────────────────────────────────────────────────
-- El servidor (al entrar o con /Lobby) pide el menú principal: se abre el TAB
-- en la pestaña RAID. La tecla F4 ya no hace nada.
net.Receive("ixEFGOpenLobby", function()
	if (!LocalPlayer():GetCharacter() or !vgui.GetControlTable("ixMetroInventory")) then return end
	if (IsValid(ix.gui.efgLobby)) then ix.gui.efgLobby:Remove() end

	-- menú de inicio del servidor (metroui, ixCharMenu)
	if (vgui.GetControlTable("ixCharMenu")) then
		if (IsValid(ix.gui.metroInventory)) then ix.gui.metroInventory:Remove() end
		if (!IsValid(ix.gui.MetroSpawnMenu)) then vgui.Create("ixCharMenu") end
		return
	end

	if (IsValid(ix.gui.metroInventory)) then
		ix.gui.metroInventory:SwitchTab("raid")
		return
	end

	ix.gui.invKeyStartTab = "raid"
	ix.gui.metroInventory = vgui.Create("ixMetroInventory")
end)
