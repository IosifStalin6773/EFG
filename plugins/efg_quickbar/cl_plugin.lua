local PLUGIN = PLUGIN

-- Selector como el de EFT: diez casillas abajo en el centro, de la 1 a la 0.
-- 1-3 son las armas equipadas (pistolera, bandolera, espalda), 4-8 el acceso
-- rápido de ix_invkey (character data "hotbar") y 9-0 la physgun y la toolgun
-- del staff. Aparece al pulsar una tecla, al cambiar de arma o de acceso rápido
-- y se oculta sola a los 3 segundos; el cambio de arma lo sigue haciendo ix_invkey.

-- ix_invkey carga después (orden alfabético): el número de ranuras se lee al dibujar
local function slotCount() return ix.hotbar and ix.hotbar.SLOTS or 5 end
local matBlock = Material("efg/quickbar/background.png", "smooth")
local matSelected = Material("efg/quickbar/selection.png", "smooth")
local matNull = Material("efg/quickbar/null.png", "smooth")

local alwaysShow = CreateClientConVar("efg_accesorapido_siempre", "0", true, false, "Muestra siempre la barra de acceso rápido", 0, 1)

local FADE_IN, VISIBLE, FADE_OUT = 0.25, 3, 0.25
local shownAt = -100
local lastWeapon, lastSig

local function show()
	local now = RealTime()
	local age = now - shownAt

	-- si ya está visible solo se alarga, sin repetir el fundido de entrada
	if (age > FADE_IN and age < FADE_IN + VISIBLE + FADE_OUT) then
		shownAt = now - FADE_IN
	elseif (age >= FADE_IN + VISIBLE + FADE_OUT) then
		shownAt = now
	end
end

local function alpha()
	if (alwaysShow:GetBool()) then return 255 end

	local age = RealTime() - shownAt
	if (age < FADE_IN) then return 255 * age / FADE_IN end
	if (age < FADE_IN + VISIBLE) then return 255 end
	return math.max(0, 255 * (1 - (age - FADE_IN - VISIBLE) / FADE_OUT))
end

local fontScale

local function createFonts(s)
	fontScale = ScrH()
	surface.CreateFont("efgQuickbar.Name", {font = "MBender", extended = true, size = math.max(11, math.Round(12 * s)), weight = 600, antialias = true})
	surface.CreateFont("efgQuickbar.Key", {font = "MBender", extended = true, size = math.max(12, math.Round(15 * s)), weight = 700, antialias = true})
end

local WEAPON_KEYS = {"secondary", "primary", "primary2"}
local STAFF_TOOLS = {{class = "weapon_physgun", name = "PHYSGUN", key = "9"}, {class = "gmod_tool", name = "TOOLGUN", key = "0"}}

-- una entrada por casilla: {item, class, name, key, group}
local function selectorSlots(client, character)
	local out = {}
	local weapons = {}
	local inv = character:GetInventory()

	if (inv) then
		for _, item in pairs(inv:GetItems(true)) do
			if (item.isWeapon and item:GetData("equip")) then
				local kind = item:GetData("efgSlot") or item.weaponCategory or "primary"
				weapons[kind] = weapons[kind] or item
			end
		end
	end

	local binds = ix.efg.binds

	for i, kind in ipairs(ix.hotbar and ix.hotbar.WEAPON_KEYS or WEAPON_KEYS) do
		local item = weapons[kind]
		out[#out + 1] = {item = item, class = item and item.class, key = binds and binds.Name("weapon" .. i) or tostring(i), group = 1}
	end

	local data = ix.hotbar and ix.hotbar.Get(character) or character:GetData("hotbar", {})

	for i = 1, slotCount() do
		local id = data[i]
		local item = id and ix.item.instances[id] or nil
		out[#out + 1] = {item = item, class = item and item.class, key = ix.hotbar and ix.hotbar.KeyLabel(i) or tostring(i + 3), group = 2}
	end

	local staff = client:IsAdmin()

	for _, tool in ipairs(STAFF_TOOLS) do
		out[#out + 1] = {class = staff and tool.class or nil, name = staff and tool.name or nil, key = tool.key, group = 3, locked = !staff}
	end

	return out
end

-- nombre recortado con "..." para que quepa en la celda
local function fit(text, width)
	surface.SetFont("efgQuickbar.Name")
	if (surface.GetTextSize(text) <= width) then return text end

	while (#text > 1 and surface.GetTextSize(text .. "...") > width) do
		text = text:sub(1, -2)
	end

	return text .. "..."
end

function PLUGIN:PlayerBindPress(client, bind, pressed)
	if (pressed and bind:match("^slot%d$")) then show() end
end

-- teclas cambiadas en AJUSTES > CONTROLES (efg_ui)
function PLUGIN:PlayerButtonDown(client, button)
	local binds = ix.efg.binds
	if (!binds or client != LocalPlayer() or !IsFirstTimePredicted()) then return end

	for _, id in ipairs({"weapon1", "weapon2", "weapon3", "quick1", "quick2", "quick3", "quick4", "quick5"}) do
		if (binds.Matches(id, button)) then
			show()
			return
		end
	end
end

function PLUGIN:Think()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local weapon = client:GetActiveWeapon()
	if (weapon != lastWeapon) then
		lastWeapon = weapon
		show()
	end

	local character = client:GetCharacter()
	local sig = ""

	if (character) then
		local data = ix.hotbar and ix.hotbar.Get(character) or character:GetData("hotbar", {})
		for i = 1, slotCount() do sig = sig .. tostring(data[i]) .. "," end
	end

	if (sig != lastSig) then
		if (lastSig) then show() end
		lastSig = sig
	end
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local character = client:GetCharacter()
	if (!character or !client:Alive() or IsValid(ix.gui.efgInventory) or IsValid(ix.gui.EFGSpawnMenu)) then return end

	local a = alpha()
	if (a <= 0) then return end

	local s = math.max(ScrH() / 1080, 0.75)
	if (fontScale != ScrH()) then createFonts(s) end

	local slots = selectorSlots(client, character)
	local bw, bh = math.Round(74 * s), math.Round(89 * s)
	local gap = math.Round(10 * s)
	local groups = slots[#slots].group
	local x = math.Round(ScrW() / 2 - (bw * #slots + gap * (groups - 1)) / 2)
	local y = ScrH() - bh - math.Round(26 * s)
	local active = client:GetActiveWeapon()
	local activeClass = IsValid(active) and active:GetClass()
	local lastGroup = slots[1].group

	for _, slot in ipairs(slots) do
		if (slot.group != lastGroup) then
			x = x + gap
			lastGroup = slot.group
		end

		local item = slot.item
		local selected = slot.class and slot.class == activeClass
		local cellA = slot.locked and a * 0.45 or a

		surface.SetDrawColor(255, 255, 255, cellA)
		surface.SetMaterial(matBlock)
		surface.DrawTexturedRect(x, y, bw, bh)

		if (selected) then
			surface.SetMaterial(matSelected)
			surface.DrawTexturedRect(x, y, bw, bh)
		end

		local ix0, iy0, isz = x + 12 * s, y + 12 * s, 50 * s
		local name = slot.name

		if (item) then
			if (!(ix.efg.icons and ix.efg.icons.Get(item))) then
				surface.SetDrawColor(255, 255, 255, a)
				surface.SetMaterial(matNull)
				surface.DrawTexturedRect(ix0, iy0, isz, isz)
			else
				-- efg_icons dibuja siempre opaco: el fundido se aplica con el multiplicador
				surface.SetAlphaMultiplier(a / 255)
				ix.efg.icons.Draw(item, ix0, iy0, isz, isz)
				surface.SetAlphaMultiplier(1)
			end

			name = item.GetName and item:GetName() or item.name
		elseif (name) then
			draw.SimpleText(name, "efgQuickbar.Key", x + bw / 2, iy0 + isz / 2, selected and Color(0, 0, 0, a) or Color(200, 198, 180, a),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if (item) then
			draw.SimpleText(fit(name, bw - 6 * s), "efgQuickbar.Name", x + bw / 2, y + bh - 9 * s, selected and Color(0, 0, 0, a) or Color(220, 220, 220, a),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(slot.key, "efgQuickbar.Key", x + 7 * s, y + 4 * s, Color(200, 198, 180, cellA), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		x = x + bw
	end
end
