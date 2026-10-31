-- Pantallas de flujo de EFG. Siguen las convenciones del género de extracción
-- (menú de entrada con opciones apiladas, selección de ubicación con ficha,
-- pantalla de despliegue con controles, inspección de objetos) pero con el
-- kit Pizarra y texturas propias de content/materials/efgui.
local PLUGIN = PLUGIN

local BACKGROUND = Material("efgui/backgrounds/mainmenu.jpg", "smooth")

-- fondos y logo de EFT (content/materials/efg/menu); si faltan, los de efgui
local ART = {
	main = Material("efg/menu/main_art.jpg", "smooth"),
	raid = Material("efg/menu/bg3.jpg", "smooth"),
	deploy = Material("efg/menu/bg2.jpg", "smooth"),
	logo = Material("efg/menu/logo.png", "smooth mips"),
}

local function UI() return ix.efgui end
local function S(v) return ix.efgui.Scale(v) end

local function lobbyAction(action, argument)
	if (ix.efg.pmc and ix.efg.pmc.LobbyAction) then
		ix.efg.pmc.LobbyAction(action, argument)
		return
	end

	net.Start("ixEFGLobbyAction")
		net.WriteString(action)
		net.WriteString(argument or "")
	net.SendToServer()
end

local function inRaid()
	local client = LocalPlayer()
	return client.InRaid and client:InRaid()
end

local function paintBackdrop(w, h, veil, art)
	if (!UI().DrawCover(ART[art or "main"], 0, 0, w, h)) then
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(BACKGROUND)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	local c = UI().color
	surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, veil or 150)
	surface.DrawRect(0, 0, w, h)
end

-- ════════════════════════════════════════════════════════════════════════════
-- SELECCIÓN DE RAID
-- Lista de ubicaciones sobre un plano, ficha de la elegida y bando. Solo el
-- mapa cargado se puede jugar; el resto sale como "próximamente".
-- ════════════════════════════════════════════════════════════════════════════
-- ubicaciones de Tarkov en el plano de la región (x, y de 0 a 1). Se puede
-- jugar la que coincide con el mapa cargado (por palabras clave del nombre);
-- si ninguna coincide, el mapa cargado sale como nodo propio.
local REGION = {
	{id = "lighthouse",  name = "Lighthouse",   x = 0.11, y = 0.30, keys = {"lighthouse", "faro"},           links = {"woods", "shoreline"},
		desc = "Faro y complejo de agua en la costa norte. Rogues armados en la planta de tratamiento."},
	{id = "woods",       name = "Woods",        x = 0.29, y = 0.36, keys = {"woods", "forest", "bosque"},     links = {"customs", "shoreline", "reserve"},
		desc = "Bosque cerrado alrededor del aserradero y la base de la ONU. Largas distancias, poca cobertura."},
	{id = "shoreline",   name = "Shoreline",    x = 0.21, y = 0.66, keys = {"shoreline", "coast", "costa"},  links = {"customs"},
		desc = "Costa con el balneario de Azure Coast. Botín médico y llaves valiosas en el resort."},
	{id = "customs",     name = "Customs",      x = 0.47, y = 0.47, keys = {"customs", "aduana", "bigred"},  links = {"factory", "interchange", "reserve"},
		desc = "Zona industrial de aduanas con la residencia y la gasolinera. Mucho tráfico de Scavs."},
	{id = "factory",     name = "Factory",      x = 0.52, y = 0.30, keys = {"factory", "fabrica"},            links = {},
		desc = "Fábrica química cerrada. Raid corta, combate a muy corta distancia."},
	{id = "reserve",     name = "Reserve",      x = 0.38, y = 0.17, keys = {"reserve", "reserva", "base"},     links = {},
		desc = "Base militar con búnkeres subterráneos. Raiders y equipo militar de alto valor."},
	{id = "interchange", name = "Interchange",  x = 0.64, y = 0.58, keys = {"interchange", "mall", "ultra"},   links = {"streets"},
		desc = "Centro comercial ULTRA. Tiendas con electrónica y equipo táctico."},
	{id = "streets",     name = "Streets",      x = 0.79, y = 0.42, keys = {"streets", "city", "ciudad"},     links = {"labs", "groundzero"},
		desc = "Calles de Tarkov. Edificios altos, lucha urbana y el banco de Lexos."},
	{id = "labs",        name = "The Lab",      x = 0.74, y = 0.70, keys = {"lab"},                           links = {},
		desc = "Laboratorio subterráneo de TerraGroup. Raiders con equipo pesado. Requiere tarjeta."},
	{id = "groundzero",  name = "Ground Zero",  x = 0.88, y = 0.24, keys = {"groundzero", "ground_zero"},      links = {},
		desc = "Distrito de oficinas donde empezó todo. Para PMC de nivel bajo."},
}

local function locations()
	local map = string.lower(game.GetMap())
	local list, matched = {}, false

	for _, r in ipairs(REGION) do
		local available = false

		for _, key in ipairs(r.keys) do
			if (map:find(key, 1, true)) then available = true break end
		end

		matched = matched or available
		list[#list + 1] = {id = r.id, name = string.upper(r.name), desc = r.desc, available = available, pos = {r.x, r.y}, links = r.links}
	end

	if (!matched) then
		table.insert(list, 1, {
			id = "current", name = string.upper(game.GetMap()),
			desc = "El mapa cargado en el servidor. Extracciones, zonas de botín y enemigos según la configuración de la raid.",
			available = true, pos = {0.56, 0.80}, links = {"customs"}
		})
	end

	for _, loc in ipairs(list) do
		if (loc.available) then return list, loc end
	end

	return list, list[1]
end

local RAID = {}

function RAID:Init()
	self.locations, self.selected = locations()
	self.side = "pmc"
	self.embedded = false
	self:Build()
end

-- embebido dentro del TAB (sin fondo ni pantalla completa)
function RAID:SetEmbedded(embedded)
	self.embedded = embedded
end

function RAID:Build()
	self:Clear()

	local back = self:Add("DButton")
	back:SetText("ATRÁS")
	UI().StyleButton(back, "efgx.Header", "ghost")
	back.DoClick = function()
		if (self.embedded) then return end
		self:Remove()
		ix.efgui.OpenPauseMenu()
	end
	self.backButton = back

	local nextButton = self:Add("DButton")
	nextButton:SetText("SIGUIENTE")
	UI().StyleButton(nextButton, "efgx.Title", "primary")
	nextButton.DoClick = function() self:Deploy() end
	nextButton.Think = function(this)
		local ok, why = self:CanDeploy()
		this:SetEnabled(ok)
		this:SetText(ok and "SIGUIENTE" or why)
	end
	self.nextButton = nextButton

	for _, side in ipairs({{"pmc", "PMC"}, {"scav", "SCAV"}}) do
		local b = self:Add("DButton")
		b:SetText(side[2])
		UI().StyleButton(b, "efgx.Header")
		b.Think = function(this) this.efgActive = self.side == side[1] end
		b.DoClick = function()
			surface.PlaySound("ui/buttonclickrelease.wav")
			self.side = side[1]
		end
		self["side_" .. side[1]] = b
	end

	-- plano topográfico en DHTML (cl_raidmap.lua): nodos con hover y selección
	local map = self:Add("DHTML")
	map:SetAllowLua(false)
	map:AddFunction("efg", "click", function() surface.PlaySound("ui/buttonclickrelease.wav") end)
	map:AddFunction("efg", "hover", function() surface.PlaySound("efg/ui/click.wav") end)
	map:AddFunction("efg", "select", function(id)
		for _, loc in ipairs(self.locations) do
			if (loc.id == id) then self.selected = loc end
		end
	end)
	map.OnDocumentReady = function() self:PushMap() end
	map:SetHTML(ix.efgui.InjectCSS(PLUGIN.raidMapHTML))
	self.map = map
end

function RAID:PushMap()
	if (!IsValid(self.map)) then return end

	local nodes = {}
	for _, loc in ipairs(self.locations) do
		nodes[#nodes + 1] = {id = loc.id, name = loc.name, x = loc.pos[1], y = loc.pos[2], available = loc.available,
			links = loc.links or {}, players = loc.available and (ix.config.Get("efgRaidMinutes", 35) .. " min") or nil}
	end

	self.map:RunJavascript("render(" .. util.TableToJSON({locations = nodes, selected = self.selected.id}) .. ")")
end

function RAID:CanDeploy()
	if (inRaid()) then return false, "YA ESTÁS EN UNA RAID" end
	if (!self.selected.available) then return false, "NO DISPONIBLE" end

	if (self.side == "scav") then
		local left = (LocalPlayer():GetData("efgNextScav", 0) or 0) - os.time()
		if (left > 0) then return false, ("SCAV EN %d:%02d"):format(math.floor(left / 60), left % 60) end
	end

	return true
end

function RAID:Deploy()
	if (!self:CanDeploy()) then return end

	surface.PlaySound("ui/buttonclickrelease.wav")
	lobbyAction(self.side == "scav" and "scav" or "raid")

	if (IsValid(ix.gui.metroInventory)) then ix.gui.metroInventory:Remove() end
	if (!self.embedded) then self:Remove() end
end

function RAID:PerformLayout(w, h)
	local m = S(24)
	local top = self.embedded and S(10) or S(90)
	local bottomH = S(64)
	local cardW = math.min(S(420), w * 0.3)
	local mapX, mapY = m, top
	local mapW, mapH = w - cardW - m * 3, h - top - bottomH - m * 2

	self.mapRect = {mapX, mapY, mapW, mapH}
	self.cardRect = {w - cardW - m, top, cardW, mapH}

	if (IsValid(self.map)) then
		self.map:SetPos(mapX, mapY)
		self.map:SetSize(mapW, mapH)
	end

	local by = h - bottomH - m / 2
	self.backButton:SetSize(S(160), S(44))
	self.backButton:SetPos(m, by + S(10))
	self.backButton:SetVisible(!self.embedded)
	self.nextButton:SetSize(S(280), S(52))
	self.nextButton:SetPos(w / 2 - S(140), by + S(6))
	self.side_pmc:SetSize(S(110), S(40))
	self.side_scav:SetSize(S(110), S(40))
	self.side_pmc:SetPos(w - m - S(226), by + S(12))
	self.side_scav:SetPos(w - m - S(110), by + S(12))
end

function RAID:Paint(w, h)
	local c = UI().color

	if (!self.embedded) then
		paintBackdrop(w, h, 170, "raid")
		draw.SimpleText("PREPARA LA SALIDA", "efgx.Display", w / 2, S(24), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("ELIGE UBICACIÓN", "efgx.Label", w / 2, S(64), c.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	-- ficha de la ubicación
	local cx, cy, cw, ch = unpack(self.cardRect or {0, 0, 0, 0})
	local loc = self.selected
	UI().DrawPanel(cx, cy, cw, ch, 235)
	UI().DrawHeader(cx, cy, cw, S(30), loc.name)

	local imgH = cw * 0.56
	if (loc.img) then
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(loc.img)
		surface.DrawTexturedRect(cx + S(12), cy + S(42), cw - S(24), imgH)
	else
		surface.SetDrawColor(c.bg2)
		surface.DrawRect(cx + S(12), cy + S(42), cw - S(24), imgH)
		draw.SimpleText(loc.name, "efgx.Title", cx + cw / 2, cy + S(42) + imgH / 2, c.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local ty = cy + S(54) + imgH
	surface.SetFont("efgx.Body")
	local words, line, out = string.Explode(" ", loc.desc or ""), "", {}
	for _, word in ipairs(words) do
		local test = line == "" and word or (line .. " " .. word)
		if (surface.GetTextSize(test) > cw - S(28) and line != "") then out[#out + 1] = line; line = word else line = test end
	end
	if (line != "") then out[#out + 1] = line end

	for i, l in ipairs(out) do
		draw.SimpleText(l, "efgx.Body", cx + S(14), ty + (i - 1) * S(20), c.text2)
	end

	local sy = ty + #out * S(20) + S(16)
	local stats = {
		{"DURACIÓN", ix.config.Get("efgRaidMinutes", 35) .. " MIN"},
		{"ESTADO", loc.available and "DISPONIBLE" or "PRÓXIMAMENTE"},
		{"HORA", os.date("%H:%M")},
	}

	for i, st in ipairs(stats) do
		local yy = sy + (i - 1) * S(24)
		draw.SimpleText(st[1], "efgx.Label", cx + S(14), yy, c.textDim)
		draw.SimpleText(st[2], "efgx.Num", cx + cw - S(14), yy, st[2] == "PRÓXIMAMENTE" and c.warn or c.text, TEXT_ALIGN_RIGHT)
	end

	-- texto del bando elegido
	local by = h - S(64) - S(12)
	draw.SimpleText(self.side == "scav" and "Equipo aleatorio. Tu PMC no arriesga nada." or "Entras con tu equipo. Si mueres lo pierdes, salvo el contenedor seguro.",
		"efgx.Small", w - S(24), by - S(4), c.text2, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

function RAID:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE and !self.embedded) then self:Remove() end
end

vgui.Register("efgxRaidSelect", RAID, "EditablePanel")

-- versión a pantalla completa
local RAIDFULL = {}

function RAIDFULL:Init()
	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.2)
end

vgui.Register("efgxRaidSelectFull", RAIDFULL, "efgxRaidSelect")

-- ════════════════════════════════════════════════════════════════════════════
-- DESPLIEGUE
-- Mientras corre la cuenta atrás (netvar efgDeployAt): modelo del PMC,
-- controles útiles y temporizador. No captura el ratón.
-- ════════════════════════════════════════════════════════════════════════════
local controls = {
	{"TAB", "Inventario y menús"},
	{"Z", "Menú radial (mantener)"},
	{"ALT + T", "Comprobar cargador"},
	{"ALT + B", "Comprobar modo de disparo"},
	{"O", "Tiempo y extracciones"},
	{"1 / 2 / 3", "Pistola / arma en bandolera / arma a la espalda"},
	{"4-8", "Acceso rápido"},
	{"CTRL", "Agacharse"},
	{"ALT", "Andar en sigilo"},
	{"SHIFT", "Correr"},
	{"RMB", "Apuntar"},
	{"LMB", "Disparar"},
}

local DEPLOY = {}

function DEPLOY:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	local model = self:Add("DModelPanel")
	model:SetSize(ScrW() * 0.35, ScrH() * 0.8)
	model:SetPos(ScrW() * 0.06, ScrH() * 0.12)
	model:SetModel(LocalPlayer():GetModel())
	model:SetFOV(30)
	model:SetCamPos(Vector(120, 0, 44))
	model:SetLookAt(Vector(0, 0, 38))
	model.LayoutEntity = function(this, entity)
		entity:SetAngles(Angle(0, 20, 0))
		this:RunAnimation()
	end
	model:SetMouseInputEnabled(false)

	if (IsValid(model.Entity)) then
		model.Entity:SetSkin(LocalPlayer():GetSkin())
		for _, bg in ipairs(LocalPlayer():GetBodyGroups()) do model.Entity:SetBodygroup(bg.id, LocalPlayer():GetBodygroup(bg.id)) end
	end
end

function DEPLOY:Paint(w, h)
	local c = UI().color
	paintBackdrop(w, h, 150, "deploy")

	local deployAt = LocalPlayer():GetNetVar("efgDeployAt", 0)
	local left = math.max(0, deployAt - CurTime())

	draw.SimpleText("HA LLEGADO LA HORA", "efgx.Display", w / 2, S(40), c.text, TEXT_ALIGN_CENTER)
	draw.SimpleText("DESPLEGANDO EN " .. string.upper(game.GetMap()), "efgx.Label", w / 2, S(82), c.text2, TEXT_ALIGN_CENTER)

	local px, py, pw = w * 0.5, h * 0.24, math.min(w * 0.42, S(620))
	local ph = S(40) + #controls * S(34)
	UI().DrawPanel(px, py, pw, ph, 230)
	UI().DrawHeader(px, py, pw, S(30), "CONTROLES")

	for i, ctl in ipairs(controls) do
		local yy = py + S(40) + (i - 1) * S(34)
		local kw = UI().DrawKeys(ctl[1], px + S(14), yy - S(1), S(28))
		draw.SimpleText(ctl[2], "efgx.Body", px + S(30) + kw, yy + S(13), c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText("Despliegue en", "efgx.Label", w / 2, h - S(110), c.textDim, TEXT_ALIGN_CENTER)
	draw.SimpleText(("%02d"):format(math.ceil(left)), "efgx.NumBig", w / 2, h - S(90), c.accent, TEXT_ALIGN_CENTER)
end

vgui.Register("efgxDeploy", DEPLOY, "Panel")

hook.Add("Think", "efgMenus.Deploy", function()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local deploying = (client:GetNetVar("efgDeployAt", 0) or 0) > CurTime()

	if (deploying and !IsValid(PLUGIN.deployPanel)) then
		PLUGIN.deployPanel = vgui.Create("efgxDeploy")
	elseif (!deploying and IsValid(PLUGIN.deployPanel)) then
		PLUGIN.deployPanel:AlphaTo(0, 0.4, 0, function(_, panel) if (IsValid(panel)) then panel:Remove() end end)
		PLUGIN.deployPanel = nil
	end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- INSPECCIÓN DE OBJETOS
-- Modelo grande que se gira arrastrando, ficha con datos y descripción.
-- ════════════════════════════════════════════════════════════════════════════
local INSPECT = {}

function INSPECT:Init()
	local w, h = math.min(ScrW() * 0.7, S(1100)), math.min(ScrH() * 0.75, S(680))
	self:SetSize(w, h)
	self:Center()
	self:MakePopup()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(true)

	local close = self:Add("DButton")
	close:SetText("✕")
	close:SetSize(S(30), S(30))
	close:SetPos(w - S(34), S(2))
	UI().StyleButton(close, "efgx.Header", "ghost")
	close.DoClick = function() self:Remove() end

	self.model = self:Add("DModelPanel")
	self.model:SetPos(S(12), S(44))
	self.model:SetSize(w * 0.58, h - S(56))
	self.yaw, self.pitch = 30, 10
	self.model.LayoutEntity = function(this, entity)
		if (this.dragging) then
			local mx, my = input.GetCursorPos()
			self.yaw = self.yaw + (mx - this.lastX) * 0.5
			self.pitch = math.Clamp(self.pitch + (my - this.lastY) * 0.3, -60, 60)
			this.lastX, this.lastY = mx, my
		end
		entity:SetAngles(Angle(self.pitch, self.yaw, 0))
	end
	self.model.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then
			this.dragging = true
			this.lastX, this.lastY = input.GetCursorPos()
			this:MouseCapture(true)
		end
	end
	self.model.OnMouseReleased = function(this)
		this.dragging = false
		this:MouseCapture(false)
	end
	self.model.OnMouseWheeled = function(this, delta)
		this:SetFOV(math.Clamp(this:GetFOV() - delta * 3, 10, 70))
	end
end

function INSPECT:SetItem(item)
	self.item = item
	self.model:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")

	local entity = self.model.Entity
	if (IsValid(entity)) then
		if (item.GetSkin and item:GetSkin()) then entity:SetSkin(item:GetSkin()) end
		local mins, maxs = entity:GetRenderBounds()
		local size = math.max((maxs - mins):Length(), 1)
		local center = (mins + maxs) / 2
		self.model:SetFOV(40)
		self.model:SetCamPos(center + Vector(size * 1.3, 0, size * 0.25))
		self.model:SetLookAt(center)
	end

	-- datos según el tipo de objeto
	local rows = {}
	rows[#rows + 1] = {"CATEGORÍA", string.upper(item.category or "—")}
	rows[#rows + 1] = {"TAMAÑO", ("%d×%d"):format(item.width or 1, item.height or 1)}
	if (item.GetWeight and item:GetWeight()) then rows[#rows + 1] = {"PESO", ("%.2f kg"):format(item:GetWeight())} end
	if (item.price) then rows[#rows + 1] = {"VALOR", string.Comma(item.price) .. " ₽"} end

	local rarity = ix.efgui.rarity[item.rarity or ""]
	if (rarity) then rows[#rows + 1] = {"RAREZA", string.upper(rarity.name), rarity.color} end

	if (item.isEFGArmor) then
		rows[#rows + 1] = {"CLASE", tostring(ix.efg.armor.GetClass(item))}
		rows[#rows + 1] = {"DURABILIDAD", ("%d / %d"):format(math.ceil(item:GetEFGDurability()), math.ceil(item:GetEFGMaxDurability()))}
	end

	if (item.isEFGPlate) then
		rows[#rows + 1] = {"CLASE", tostring(item.plateClass)}
		rows[#rows + 1] = {"DURABILIDAD", ("%d / %d"):format(item:GetData("durability", item.plateDurability), item.plateDurability)}
	end

	if (item.isARC9) then
		rows[#rows + 1] = {"ERGONOMÍA", tostring(item.GetErgonomics and item:GetErgonomics() or item.ergonomics or 55)}
		rows[#rows + 1] = {"CALIBRE", string.upper(item.ammoType or "—")}
	end

	if (item.isEFGMod) then
		rows[#rows + 1] = {"RANURA", string.upper(ix.efg.mods.slotNames[item.modSlot] or item.modSlot)}
		rows[#rows + 1] = {"ERGONOMÍA", ("%+d"):format(item.ergoDelta or 0)}
	end

	if (item.GetUses and item.maxUses and item.maxUses > 1) then
		rows[#rows + 1] = {"USOS", ("%d / %d"):format(item:GetUses(), item.maxUses)}
	end

	self.rows = rows

	local info = self:Add("DScrollPanel")
	local w, h = self:GetSize()
	info:SetPos(w * 0.58 + S(24), S(60) + #rows * S(26) + S(16))
	info:SetSize(w - (w * 0.58 + S(36)), h - (S(60) + #rows * S(26) + S(28)))

	local desc = info:Add("DLabel")
	desc:Dock(TOP)
	desc:SetFont("efgx.Body")
	desc:SetTextColor(ix.efgui.color.text2)
	desc:SetWrap(true)
	desc:SetAutoStretchVertical(true)
	desc:SetText(item:GetDescription() or "")
end

function INSPECT:Paint(w, h)
	local c = UI().color
	UI().DrawPanel(0, 0, w, h, 245)
	UI().DrawHeader(0, 0, w, S(34), self.item and (self.item.GetName and self.item:GetName() or self.item.name) or "")

	surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, 200)
	surface.DrawRect(S(12), S(44), w * 0.58, h - S(56))
	draw.SimpleText("Arrastra para girar · rueda para acercar", "efgx.Label", S(20), h - S(26), c.textDim)

	local x = w * 0.58 + S(24)
	for i, row in ipairs(self.rows or {}) do
		local y = S(56) + (i - 1) * S(26)
		draw.SimpleText(row[1], "efgx.Label", x, y + S(4), c.textDim)
		draw.SimpleText(row[2], "efgx.Num", w - S(16), y, row[3] or c.text, TEXT_ALIGN_RIGHT)
		surface.SetDrawColor(c.line)
		surface.DrawRect(x, y + S(22), w - S(16) - x, 1)
	end
end

function INSPECT:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("efgxInspect", INSPECT, "DFrame")
