local PLUGIN = PLUGIN

-- Barra de acceso rápido como la de EFT: aparece abajo en el centro al pulsar
-- 1-5, al cambiar de arma o al cambiar lo que hay en el acceso rápido, y se
-- oculta sola a los 3 segundos. Lee las ranuras del acceso rápido de ix_invkey
-- (character data "hotbar"); el cambio de arma lo sigue haciendo ix_invkey.

local SLOTS = 5
local matBlock = Material("efg/quickbar/background.png", "smooth")
local matSelected = Material("efg/quickbar/selection.png", "smooth")
local matBinds = Material("efg/quickbar/binds.png", "smooth")
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
end

local function hotbarItems(character)
	local out = {}
	local data = character:GetData("hotbar", {})

	for i = 1, SLOTS do
		local id = data[i]
		out[i] = id and ix.item.instances[id] or nil
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
	if (pressed and bind:match("^slot[1-5]$")) then show() end
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
		local data = character:GetData("hotbar", {})
		for i = 1, SLOTS do sig = sig .. tostring(data[i]) .. "," end
	end

	if (sig != lastSig) then
		if (lastSig) then show() end
		lastSig = sig
	end
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local character = client:GetCharacter()
	if (!character or !client:Alive() or IsValid(ix.gui.metroInventory) or IsValid(ix.gui.MetroSpawnMenu) or IsValid(ix.gui.efgMain)) then return end

	local a = alpha()
	if (a <= 0) then return end

	local s = math.max(ScrH() / 1080, 0.75)
	if (fontScale != ScrH()) then createFonts(s) end

	local bw, bh = math.Round(74 * s), math.Round(89 * s)
	local x0 = math.Round(ScrW() / 2 - bw * SLOTS / 2)
	local y = ScrH() - bh - math.Round(26 * s)
	local items = hotbarItems(character)
	local active = client:GetActiveWeapon()
	local activeClass = IsValid(active) and active:GetClass()

	for i = 1, SLOTS do
		local x = x0 + (i - 1) * bw
		local item = items[i]
		local selected = item and item.class and item.class == activeClass

		surface.SetDrawColor(255, 255, 255, a)
		surface.SetMaterial(matBlock)
		surface.DrawTexturedRect(x, y, bw, bh)

		if (selected) then
			surface.SetMaterial(matSelected)
			surface.DrawTexturedRect(x, y, bw, bh)
		end

		local ix0, iy0, isz = x + 12 * s, y + 12 * s, 50 * s

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

			local name = fit(item.GetName and item:GetName() or item.name, bw - 6 * s)
			draw.SimpleText(name, "efgQuickbar.Name", x + bw / 2, y + bh - 9 * s, selected and Color(0, 0, 0, a) or Color(220, 220, 220, a),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- números de las teclas: la textura trae 6, se usan las 5 primeras
	surface.SetDrawColor(255, 255, 255, a)
	surface.SetMaterial(matBinds)
	surface.DrawTexturedRectUV(x0, y, bw * SLOTS, bh, 0, 0, SLOTS / 6, 1)
end
