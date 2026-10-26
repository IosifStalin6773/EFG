local PLUGIN = PLUGIN

concommand.Add("hud_tag_debug", function()
	ix.hudDebugTag = !ix.hudDebugTag
	print("[DBG tag] debug " .. (ix.hudDebugTag and "ON" or "OFF"))
end)

-- ============================================================
--  METRO RP 2033 · HUD
--  Estética: instrumentación analógica desgastada del Metro.
--  Filosofía: mostrar solo lo necesario. Lo que está "bien"
--  (stamina/comida/bebida llenas) no se dibuja; solo aparecen
--  como avisos cuando caen por debajo del 25%.
-- ============================================================

-- ============================================================
--  MATERIALES
-- ============================================================

-- Iconos vitales (contentUI · astranetworks)
local matHp      = Material("efgui/hud/hp.png",      "noclamp smooth")
local matArmor   = Material("efgui/hud/armor.png",   "noclamp smooth")
local matStamina = Material("efgui/hud/stamina.png", "noclamp smooth")
local matFood    = Material("efgui/hud/food.png",    "noclamp smooth")
local matThirst  = Material("efgui/hud/thirst.png",  "noclamp smooth")

-- Filtro de gasmask (contentUI · metroui)
local matFilter   = Material("efgui/hud/filter.png",    "noclamp smooth")
local matNoFilter = Material("efgui/hud/no_filter.png", "noclamp smooth")

-- Munición: rozok (cargador, izquierda) + cartucho según calibre (derecha)
local matMag = Material("efgui/icons/rozok.png", "noclamp smooth")

-- Cartuchos por tipo de arma (lado de la reserva)
local matAmmoAK       = Material("efgui/icons/ak_ammo.png",            "noclamp smooth")
local matAmmoRevolver = Material("efgui/icons/revolver_ammo.png",      "noclamp smooth")
local matAmmoShotgun  = Material("efgui/icons/shotgun_ammo.png",       "noclamp smooth")
local matAmmoFlame    = Material("efgui/icons/shotgun_flame_ammo.png", "noclamp smooth")
local matAmmoSniper   = Material("efgui/icons/sniper_ammo.png",        "noclamp smooth")
local matAmmoGatling  = Material("efgui/icons/gatling_ammo.png",       "noclamp smooth")
local matAmmoTikhar   = Material("efgui/icons/tikhar_ammo.png",        "noclamp smooth")
local matAmmoDefault  = Material("efgui/icons/money_ammo.png",         "noclamp smooth")  -- balas sueltas (fallback)

-- Iconos de facción (rellenados tras 1 s, cuando FACTION_X ya existe)
local FACTION_ICON_MATS = {}

timer.Simple(1, function()
	-- Iconos provisionales hasta tener los de USEC/BEAR/Scav
	if (FACTION_USEC)  then FACTION_ICON_MATS[FACTION_USEC]  = Material("efgui/factions/usec.png",     "noclamp smooth") end
	if (FACTION_BEAR)  then FACTION_ICON_MATS[FACTION_BEAR]  = Material("efgui/factions/bear.png",    "noclamp smooth") end
	if (FACTION_SCAV)  then FACTION_ICON_MATS[FACTION_SCAV]  = Material("efgui/factions/scav.png",     "noclamp smooth") end
	if (FACTION_STAFF) then FACTION_ICON_MATS[FACTION_STAFF] = Material("efgui/factions/staff.png", "noclamp smooth") end

	for k, v in pairs(FACTION_ICON_MATS) do
		PLUGIN.FACTION_ICONS[k] = v
	end
end)

-- ============================================================
--  FUENTES
-- ============================================================

surface.CreateFont("MetroHUD_Name",       { font = "Bender", size = 18, weight = 600, antialias = true })
surface.CreateFont("MetroHUD_Faction",    { font = "Bender", size = 13, weight = 400, antialias = true })
surface.CreateFont("MetroHUD_Label",      { font = "Bender", size = 12, weight = 500, antialias = true })
surface.CreateFont("MetroHUD_Small",      { font = "Bender", size = 11, weight = 400, antialias = true })
surface.CreateFont("MetroHUD_Value",      { font = "Bender", size = 20, weight = 600, antialias = true })
surface.CreateFont("MetroHUD_AmmoClip",   { font = "Bender", size = 44, weight = 800, antialias = true })
surface.CreateFont("MetroHUD_AmmoRes",    { font = "Bender", size = 30, weight = 500, antialias = true })
surface.CreateFont("MetroHUD_Filter",     { font = "Bender", size = 17, weight = 500, antialias = true })
surface.CreateFont("MetroHUD_GeigerValue",{ font = "Bender", size = 24, weight = 700, antialias = true })
surface.CreateFont("MetroHUD_GeigerLabel",{ font = "Bender", size = 14, weight = 500, antialias = true })
surface.CreateFont("MetroHUD_GeigerScale",{ font = "Bender", size = 13, weight = 400, antialias = true })
surface.CreateFont("MetroHUD_TagName",    { font = "Bender", size = 16, weight = 500, antialias = true })
surface.CreateFont("MetroHUD_TagDesc",    { font = "Bender", size = 15, weight = 400, antialias = true })

-- ============================================================
--  PALETA
-- ============================================================

-- Paleta ámbar/naranja del HUD de Metro (Last Light / Exodus).
local C_WHITE      = Color(240, 220, 188, 255)   -- ámbar claro (texto principal)
local C_BONE       = Color(214, 178, 128, 255)   -- ámbar medio
local C_GRAY       = Color(150, 124,  92, 255)   -- ámbar apagado
local C_DARKGRAY   = Color( 96,  78,  56, 255)
local C_PANEL      = Color( 10,   9,   8, 205)    -- fondo de panel (casi negro cálido)
local C_PANEL_TOP  = Color( 30,  24,  16,  95)    -- highlight superior (metal cálido)
local C_BORDER     = Color( 70,  48,  24, 205)    -- borde ámbar oscuro
local C_BRACKET    = Color(154, 136,  102, 230)    -- corchetes de esquina (naranja Metro)
local C_ACCENT     = Color(154, 136,  102, 255)    -- naranja de acento
local C_BAR_BG     = Color( 24,  20,  16, 230)
local C_RED        = Color(198,  64,  28, 255)    -- salud: rojo-naranja cálido
local C_BLUE       = Color(110, 120, 110, 255)    -- armadura: gris-verdoso apagado
local C_YELLOW     = Color(220, 158,  52, 255)    -- ámbar (stamina)
local C_GREEN      = Color( 92, 150,  56, 255)
local C_ORANGE     = Color(224, 132,  40, 255)
local C_HERIDA     = Color( 90,  46,  20, 255)    -- heridas: marrón quemado
local C_HERIDA_TXT = Color(196, 120,  60, 255)
local C_SEP        = Color( 70,  48,  24, 120)
local C_PREMIUM    = Color(235, 140,  35, 255)    -- naranja: munición premium (pagada con Balas)
local C_AMMO_ICON  = Color(140, 110,  72, 255)    -- ámbar oscuro: icono de cartucho (munición normal)

-- Umbral de aviso para necesidades / stamina
local WARN_THRESHOLD = 25


-- ============================================================
--  HOOK · HUDShouldNotDraw
-- ============================================================

hook.Add("HUDShouldNotDraw", "MetroHUD_HideElements", function(name)
	for _, v in ipairs(PLUGIN.HUD_HIDE) do
		if (v == name) then return true end
	end
end)

-- ============================================================
--  HELPERS DE DIBUJO
-- ============================================================

local function DrawMat(mat, x, y, w, h, col)
	surface.SetDrawColor(col or C_WHITE)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(x, y, w, h)
end

--- Fondo de panel desgastado: cuerpo oscuro + highlight metálico + borde.
local function DrawPanel(x, y, w, h)
	draw.RoundedBox(3, x, y, w, h, C_PANEL)
	surface.SetDrawColor(C_PANEL_TOP)
	surface.DrawRect(x + 1, y + 1, w - 2, 2)           -- brillo superior
	surface.SetDrawColor(C_BORDER)
	surface.DrawOutlinedRect(x, y, w, h, 1)            -- borde
end

--- Corchetes de esquina estilo interfaz militar Metro.
local function DrawBrackets(x, y, w, h, size, col)
	col  = col or C_BRACKET
	size = size or 8
	surface.SetDrawColor(col)
	-- Sup-izq
	surface.DrawRect(x, y, size, 2);       surface.DrawRect(x, y, 2, size)
	-- Sup-der
	surface.DrawRect(x + w - size, y, size, 2); surface.DrawRect(x + w - 2, y, 2, size)
	-- Inf-izq
	surface.DrawRect(x, y + h - 2, size, 2);    surface.DrawRect(x, y + h - size, 2, size)
	-- Inf-der
	surface.DrawRect(x + w - size, y + h - 2, size, 2); surface.DrawRect(x + w - 2, y + h - size, 2, size)
end

--- Barra horizontal con relleno y leve marca de tope.
local function DrawBar(x, y, w, h, val, maxVal, colFill, segments)
	local frac = math.Clamp(val / maxVal, 0, 1)
	draw.RoundedBox(2, x, y, w, h, C_BAR_BG)
	if (frac > 0) then
		draw.RoundedBox(2, x, y, math.floor(w * frac), h, colFill)
	end
	-- Marcas verticales tenues (lectura tipo escala)
	if (segments) then
		surface.SetDrawColor(0, 0, 0, 90)
		for i = 1, segments - 1 do
			local sx = x + math.floor(w * (i / segments))
			surface.DrawRect(sx, y, 1, h)
		end
	end
end

local function Shadow(text, font, x, y, col, xa, ya)
	draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 190), xa, ya)
	draw.SimpleText(text, font, x,     y,     col,                  xa, ya)
end

local function DrawSep(x, y, w)
	surface.SetDrawColor(C_SEP)
	surface.DrawRect(x, y, w, 1)
end

local function Pulse(base, range, speed)
	return math.Clamp(base + math.floor(math.sin(CurTime() * speed) * range), 0, 255)
end

-- ============================================================
--  GASMASK
-- ============================================================

local function GetEquippedGasMask(client)
	local char = client:GetCharacter()
	if (not char) then return nil end
	local inv = char:GetInventory()
	if (not inv) then return nil end
	for _, v in pairs(inv:GetItems()) do
		if (v.isGasMask and v:GetData("equip")) then return v end
	end
	return nil
end

-- ============================================================
--  PANEL VITAL (inferior-izquierdo)
--  Construye una lista de filas activas y dibuja solo esas.
--  Siempre: HP. Condicional: armadura, filtro, stamina/comida/
--  bebida (estas tres solo bajo el 25 %).
-- ============================================================

local ROW_H   = 40
local PANEL_W = 256

--- Reúne las filas activas. Devuelve también valores derivados (heridas, base).
local function CollectVitalRows(client, char)
	local rows = {}

	-- HP (siempre)
	local hp      = client:Health()
	local heridas = (char.GetHeridas and char:GetHeridas() or 0)
	local base    = ix.config.Get("medico_vida_base", 100)
	rows[#rows + 1] = { kind = "hp", val = hp, max = base, heridas = heridas }

	-- Armadura (si lleva)
	local armor = client:Armor()
	if (armor > 0) then
		rows[#rows + 1] = { kind = "armor", val = armor, max = 100 }
	end

	-- Filtro de gasmask (mientras el aviso esté activo)
	local badair = ix.plugin.Get("badair")
	local fVis   = badair and CurTime() < (badair.filterHUDEnd or 0)
	local gmItem = fVis and GetEquippedGasMask(client) or nil
	if (gmItem) then
		-- getFilter() es un pool de "unidades" que se desgasta a razón de
		-- AdjustFilterDrain (≤1) por tick, no de 1 segundo por segundo real, así que
		-- el tiempo real restante (y la duración máxima real) hay que escalarlos por
		-- el mismo multiplicador que aplica el servidor en sv_effects.lua o el HUD
		-- siempre muestra 4:00 como si el perk "radiacion" no existiera.
		local rawVal    = math.max(0, gmItem:getFilter() or 0)
		local baseMax   = ix.config.Get("gasmask_filter", 240)
		local mult      = (ix.perks and ix.perks.GetFilterMultiplier(char)) or 1
		local fSecs     = rawVal / mult
		local fSecsMax  = baseMax / mult
		rows[#rows + 1] = { kind = "filter", val = fSecs, max = fSecsMax }
	end

	-- Avisos: solo bajo el umbral
	local stm = math.Clamp(client:GetLocalVar("stm", 100), 0, 100)
	if (stm < WARN_THRESHOLD) then
		rows[#rows + 1] = { kind = "stamina", val = stm, max = 100, warn = true }
	end

	local hunger = (char.GetSatiety and char:GetSatiety()) or client:GetLocalVar("satiety", 100)
	if (hunger < 50) then
		rows[#rows + 1] = { kind = "food", val = hunger, max = 100, warn = (hunger < WARN_THRESHOLD) }
	end

	local thirst = (char.GetSaturation and char:GetSaturation()) or client:GetLocalVar("saturation", 100)
	if (thirst < 50) then
		rows[#rows + 1] = { kind = "thirst", val = thirst, max = 100, warn = (thirst < WARN_THRESHOLD) }
	end

	return rows
end

local BADGE_H = 22

--- Reúne los buffs de comida activos ("Nutrido" / "Intoxicado") a mostrar sobre la barra de vida.
local function CollectBuffBadges(client)
	local badges = {}

	local nutridoEnd = client:GetNetVar("nutridoEnd", 0)
	if (nutridoEnd > CurTime()) then
		badges[#badges + 1] = { label = "NUTRIDO", remain = nutridoEnd - CurTime(), col = C_GREEN }
	end

	local intoxEnd = client:GetNetVar("intoxicadoEnd", 0)
	if (intoxEnd > CurTime()) then
		badges[#badges + 1] = { label = "INTOXICADO", remain = intoxEnd - CurTime(), col = C_RED }
	end

	return badges
end

--- Dibuja las insignias de buff justo encima del panel de vida, con el tiempo restante.
local function DrawBuffBadges(client, panX, panY, panW)
	local badges = CollectBuffBadges(client)
	if (#badges == 0) then return end

	local y = panY - 8

	for i = #badges, 1, -1 do
		local b = badges[i]
		y = y - BADGE_H

		DrawPanel(panX, y, panW, BADGE_H)
		surface.SetDrawColor(b.col)
		surface.DrawRect(panX, y, 3, BADGE_H)

		local mins = math.floor(b.remain / 60)
		local secs = math.floor(b.remain % 60)
		Shadow(b.label, "MetroHUD_Label", panX + 10, y + BADGE_H * 0.5, b.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		Shadow(string.format("%d:%02d", mins, secs), "MetroHUD_Small", panX + panW - 10, y + BADGE_H * 0.5, C_BONE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		y = y - 4
	end
end

local function DrawVitalPanel(scrW, scrH)
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end
	local char = client:GetCharacter()
	if (not char) then return end

	local rows = CollectVitalRows(client, char)
	local panH = 12 + #rows * ROW_H + 6
	local panX = 16
	local panY = scrH - panH - 16

	DrawPanel(panX, panY, PANEL_W, panH)
	DrawBrackets(panX, panY, PANEL_W, panH)
	DrawBuffBadges(client, panX, panY, PANEL_W)

	local iconX = panX + 11
	local barX  = panX + 46
	local barW  = 162
	local barH  = 7
	local valX  = barX + barW + 8
	local curY  = panY + 12

	for i, row in ipairs(rows) do
		if (i > 1) then DrawSep(panX + 8, curY - 4, PANEL_W - 16) end

		local icoY = curY + 4
		local barY = curY + 13

		if (row.kind == "hp") then
			DrawMat(matHp, iconX, icoY, 26, 26, C_RED)
			DrawBar(barX, barY, barW, barH, row.val, row.max, C_RED)
			if (row.heridas > 0) then
				local lostW = math.floor(barW * math.Clamp(row.heridas / 100, 0, 1))
				if (lostW > 0) then
					draw.RoundedBox(2, barX + barW - lostW, barY, lostW, barH, C_HERIDA)
				end
				Shadow("heridas recientes", "MetroHUD_Small", barX, curY + 24, C_HERIDA_TXT, TEXT_ALIGN_LEFT)
			end
			Shadow(tostring(row.val), "MetroHUD_Value", valX, barY - 6, C_WHITE, TEXT_ALIGN_LEFT)

		elseif (row.kind == "armor") then
			DrawMat(matArmor, iconX, icoY, 26, 26, C_BLUE)
			DrawBar(barX, barY, barW, barH, row.val, row.max, C_BLUE)
			Shadow(tostring(row.val), "MetroHUD_Value", valX, barY - 6, C_BONE, TEXT_ALIGN_LEFT)

		elseif (row.kind == "filter") then
			local frac   = row.val / row.max
			local fColor = (frac > 0.5) and C_GREEN or (frac > 0.2) and C_YELLOW or C_RED
			local fMat   = (row.val < 30) and matNoFilter or matFilter
			local mins   = math.floor(row.val / 60)
			local secs   = math.floor(row.val % 60)
			DrawMat(fMat, iconX, icoY, 26, 26, fColor)
			DrawBar(barX, barY, barW, barH, row.val, row.max, fColor)
			Shadow(string.format("%d:%02d", mins, secs), "MetroHUD_Filter", valX, barY - 5, fColor, TEXT_ALIGN_LEFT)

		else
			-- Filas de aviso (stamina / comida / bebida): parpadeo rojo al borde.
			local mat, baseCol
			if     (row.kind == "stamina") then mat = matStamina; baseCol = C_ORANGE
			elseif (row.kind == "food")    then mat = matFood;    baseCol = C_ORANGE
			else                                mat = matThirst;  baseCol = C_BLUE
			end

			local col
			if (row.warn) then
				local t  = math.Clamp(row.val / WARN_THRESHOLD, 0, 1)
				local pa = Pulse(200, 55, 6)
				col = Color(
					math.floor(Lerp(t, 210, baseCol.r)),
					math.floor(Lerp(t,  40, baseCol.g)),
					math.floor(Lerp(t,  40, baseCol.b)),
					pa
				)
			else
				col = Color(baseCol.r, baseCol.g, baseCol.b, 220)
			end

			DrawMat(mat, iconX, icoY, 26, 26, col)
			DrawBar(barX, barY, barW, barH, row.val, row.max, col)
			Shadow(tostring(math.floor(row.val)), "MetroHUD_Value", valX, barY - 6, col, TEXT_ALIGN_LEFT)
		end

		curY = curY + ROW_H
	end
end

-- ============================================================
--  PANEL DE MUNICIÓN (inferior-derecho) · estilo Metro original
--  Tira horizontal: [cargador]  31     74  [cartuchos]
-- ============================================================

--- Mapa por TIPO de munición real (registrado en ix_cwsupport · sh_configs.lua).
-- Todas las armas CW remapean su calibre a uno de estos tipos vía PLUGIN.changeAmmo.
local AMMO_TYPE_MATS = {
	["ar2"]                   = matAmmoAK,       -- Munición de Fusil
	["ar2altfire"]            = matAmmoGatling,  -- Munición Pesada
	["pistol"]                = matAmmoRevolver, -- Munición de Pistola
	["357"]                   = matAmmoTikhar, -- Balas de Rodamiento
	["smg1"]                  = matAmmoTikhar,   -- Dardos (armas neumáticas)
	["buckshot"]              = matAmmoShotgun,  -- Munición de Escopeta
	["sniperround"]           = matAmmoSniper,   -- Munición de Francotirador
	["sniperpenetratedround"] = matAmmoSniper,
}

--- Devuelve el material de cartucho del arma activa.
-- Prioriza el tipo de munición real; cae al nombre de clase para armas no-CW.
local function GetAmmoMat(wep)
	local ammoID = wep:GetPrimaryAmmoType()
	if (ammoID and ammoID >= 0) then
		local ammoName = game.GetAmmoName(ammoID)
		if (ammoName) then
			local mat = AMMO_TYPE_MATS[string.lower(ammoName)]
			if (mat) then return mat end
		end
	end

	-- Respaldo por nombre de clase (HL2 y armas sin tipo mapeado).
	local cls = string.lower(wep:GetClass())
	if (string.find(cls, "flame")) then return matAmmoFlame end
	if (string.find(cls, "tikhar") or string.find(cls, "tihar") or string.find(cls, "ventil") or string.find(cls, "preved")) then return matAmmoTikhar end
	if (string.find(cls, "duplet") or string.find(cls, "doublet") or string.find(cls, "uboynik")
		or string.find(cls, "ashot") or string.find(cls, "saiga") or string.find(cls, "helsing")
		or string.find(cls, "shotgun") or string.find(cls, "db")) then return matAmmoShotgun end
	if (string.find(cls, "revolver") or string.find(cls, "glushak") or string.find(cls, "padonak")
		or string.find(cls, "padnok") or string.find(cls, "pistol") or string.find(cls, "357")) then return matAmmoRevolver end
	if (string.find(cls, "gatling") or string.find(cls, "rpk")) then return matAmmoGatling end
	if (string.find(cls, "vsv") or string.find(cls, "vss") or string.find(cls, "sniper") or string.find(cls, "railgun")) then return matAmmoSniper end
	if (string.find(cls, "ak") or string.find(cls, "kalash") or string.find(cls, "bastard")
		or string.find(cls, "ubludok") or string.find(cls, "rifle") or string.find(cls, "smg")) then return matAmmoAK end

	return matAmmoDefault
end

local function DrawAmmoPanel(scrW, scrH)
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end
	if (not client:GetCharacter()) then return end

	local wep = client:GetActiveWeapon()
	if (not IsValid(wep)) then return end

	local clip = wep:Clip1()
	if (clip == -1) then return end   -- sin cargador (puños, etc.)

	local clipMax   = wep:GetMaxClip1()
	local isPremium = wep:GetNWBool("ixPremiumAmmo", false)

	-- En modo premium el cargador se paga con Balas, no con munición normal
	-- de reserva (que se queda a 0 porque la recarga nativa de CW2 nunca
	-- llega a tocarse). La "reserva" mostrada pasa a ser cuántas Balas de
	-- antes de la guerra le quedan al jugador para volver a cargar.
	local reserve
	if (isPremium) then
		local char = client:GetCharacter()
		reserve = char and char:GetMoney() or 0
	else
		reserve = client:GetAmmoCount(wep:GetPrimaryAmmoType())
	end

	-- Tira horizontal desgastada
	local panW = 300
	local panH = 64
	local panX = scrW - panW - 16
	local panY = scrH - panH - 16

	DrawPanel(panX, panY, panW, panH)
	DrawBrackets(panX, panY, panW, panH)

	local midY = panY + panH * 0.5

	-- Icono del cargador (izquierda)
	DrawMat(matMag, panX + 14, midY - 18, 36, 36, isPremium and C_PREMIUM or C_BONE)

	-- Número del cargador (grande, ámbar). Naranja intenso si queda <= 25 %,
	-- naranja fuerte si el cargador es munición premium (pagada con Balas).
	local clipCol = isPremium and C_PREMIUM
		or ((clipMax > 0 and clip <= math.ceil(clipMax * 0.25)) and C_ORANGE or C_WHITE)
	Shadow(tostring(clip), "MetroHUD_AmmoClip", panX + 60, midY - 24, clipCol, TEXT_ALIGN_LEFT)

	-- Cartucho: icono de Balas si el cargador es premium, si no el tipo de
	-- munición real del arma activa (derecha).
	DrawMat(isPremium and matAmmoDefault or GetAmmoMat(wep), panX + panW - 50, midY - 16, 34, 34, isPremium and C_PREMIUM or C_AMMO_ICON)

	-- Reserva (a la izquierda del icono de cartuchos)
	local resCol = (reserve <= 0) and C_DARKGRAY or C_BONE
	Shadow(tostring(reserve), "MetroHUD_AmmoRes", panX + panW - 58, midY - 16, resCol, TEXT_ALIGN_RIGHT)

	-- Tira segmentada del cargador, justo bajo el número (lectura tipo Metro).
	if (clipMax > 0) then
		local segTotal = math.min(clipMax, 32)
		local stripX   = panX + 60
		local stripW   = (panX + panW - 64) - stripX
		local segW     = math.max(2, math.floor(stripW / segTotal) - 1)
		local segY     = panY + panH - 14
		local litCol   = isPremium and C_PREMIUM or C_ACCENT
		for i = 0, segTotal - 1 do
			local lit = (i < math.floor(clip / clipMax * segTotal))
			draw.RoundedBox(0, stripX + i * (segW + 1), segY, segW, 4, lit and litCol or C_BAR_BG)
		end
	end
end

-- ============================================================
--  PANEL DOSÍMETRO GEIGER (centro-inferior)
-- ============================================================

local _geigerHas    = false
local _geigerCacheT = 0

hook.Add("Think", "MetroHUD_GeigerCache", function()
	if (CurTime() - _geigerCacheT < 2) then return end
	_geigerCacheT = CurTime()
	local client = LocalPlayer()
	if (not IsValid(client)) then _geigerHas = false; return end
	local char = client:GetCharacter()
	if (not char) then _geigerHas = false; return end
	local inv = char:GetInventory()
	if (not inv) then _geigerHas = false; return end
	for _, item in pairs(inv:GetItems()) do
		if (item.uniqueID == "contador_geiger") then _geigerHas = true; return end
	end
	_geigerHas = false
end)

-- Mismo lenguaje visual que el panel de vitales de la izquierda: chasis
-- ámbar (DrawPanel), corchetes de esquina naranja (DrawBrackets) y texto con
-- sombra en la misma paleta (C_WHITE/C_GRAY/C_ORANGE), para no romper la
-- estética del resto del HUD.
local _geigerNextBlip = 0
local _geigerBlipOn   = false

local function DrawGeigerPanel(scrW, scrH)
	if (not _geigerHas) then return end
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end
	local char = client:GetCharacter()
	if (not char) then return end
	if (not ix.badair) then return end

	local rad    = char:GetRadiation() or 0
	local inZone = client:GetNetVar("inRadZone", false)

	-- Antes solo se mostraba 5s tras mantener pulsada G (badair.geigerHUDEnd);
	-- con eso el jugador no tenía forma de saber su radiación el resto del
	-- tiempo. Con el contador encima, el panel queda persistente mientras
	-- importe (en zona o con radiación acumulada); el aviso de "mantén G" solo
	-- hace falta para consultar la radiación de OTRO jugador, que sigue usando
	-- geigerHUDEnd por separado (ver netstream "badair_geigerResult").
	if (rad <= 0 and not inZone) then return end

	local panW = 300
	local panH = 92
	local panX = math.floor((scrW - panW) / 2)
	local panY = scrH - panH - 16

	DrawPanel(panX, panY, panW, panH)
	DrawBrackets(panX, panY, panW, panH)

	-- Cabecera: título a la izquierda, número protagonista a la derecha.
	Shadow("DOSÍMETRO", "MetroHUD_GeigerLabel", panX + 16, panY + 14, C_GRAY, TEXT_ALIGN_LEFT)
	Shadow(math.floor(rad) .. " µR/h", "MetroHUD_GeigerValue", panX + panW - 16, panY + 13, C_WHITE, TEXT_ALIGN_RIGHT)

	-- LED de "tick" junto al título: parpadea más rápido cuanta más
	-- radiación, igual que el sonido del contador en plugins/badair/cl_plugin.lua.
	if (CurTime() >= _geigerNextBlip) then
		_geigerBlipOn = not _geigerBlipOn
		_geigerNextBlip = CurTime() + math.max(0.15, 1 - rad / ix.badair.RAD_DEATH)
	end

	local ledCol
	if     (rad < 240) then ledCol = C_GREEN
	elseif (rad < 400) then ledCol = C_YELLOW
	elseif (rad < 600) then ledCol = C_ORANGE
	else                     ledCol = C_RED end

	local ledSize = 6
	local ledX, ledY = panX + 16 + 78, panY + 15
	surface.SetDrawColor(ledCol.r, ledCol.g, ledCol.b, _geigerBlipOn and 255 or 40)
	draw.RoundedBox(3, ledX, ledY, ledSize, ledSize, surface.GetDrawColor())

	-- Barra segmentada 0-800: solo el tramo encendido lleva el color de
	-- gravedad (verde/amarillo/naranja/rojo); el resto usa el mismo fondo de
	-- barra que el resto del HUD (C_BAR_BG), sin bandas de color "apagadas".
	local segs = 20
	local bx, by = panX + 16, panY + 46
	local btw, bh = panW - 32, 10
	local gap = 3
	local sw = math.floor((btw - gap * (segs - 1)) / segs)
	local frac = math.Clamp(rad / ix.badair.RAD_DEATH, 0, 1)
	local act = math.floor(frac * segs)

	for i = 0, segs - 1 do
		local lit
		if     (i < 6)  then lit = C_GREEN
		elseif (i < 10) then lit = C_YELLOW
		elseif (i < 16) then lit = C_ORANGE
		else                 lit = C_RED end
		draw.RoundedBox(0, bx + i * (sw + gap), by, sw, bh, (i < act) and lit or C_BAR_BG)
	end

	-- Aguja marcando la posición EXACTA sobre la barra (no solo el bloque
	-- discreto que queda encendido), como pedía el usuario al recordar la
	-- versión anterior con "trayectoria" sobre los cuadrados.
	local markerCol
	if     (rad < 240) then markerCol = C_GREEN
	elseif (rad < 400) then markerCol = C_YELLOW
	elseif (rad < 600) then markerCol = C_ORANGE
	else                     markerCol = C_RED end

	local markerX = bx + math.floor(btw * frac)
	surface.SetDrawColor(markerCol)
	surface.DrawRect(markerX - 4, by - 8, 8, 2)
	surface.DrawRect(markerX - 3, by - 6, 6, 2)
	surface.DrawRect(markerX - 2, by - 4, 4, 2)
	surface.DrawRect(markerX - 1, by - 2, 2, 2)

	-- Escala numérica bajo la barra (umbrales reales de subida de estado).
	local scy = by + bh + 8
	Shadow("0",   "MetroHUD_GeigerScale", bx,             scy, C_GRAY, TEXT_ALIGN_LEFT)
	Shadow("400", "MetroHUD_GeigerScale", panX + panW / 2, scy, C_GRAY, TEXT_ALIGN_CENTER)
	Shadow("800", "MetroHUD_GeigerScale", bx + btw,        scy, C_GRAY, TEXT_ALIGN_RIGHT)

	-- Etiqueta inferior: aviso de zona activa si aplica, si no la fija.
	if (inZone) then
		local wa = Pulse(200, 55, 4)
		Shadow("ZONA RADIADA", "MetroHUD_GeigerLabel", panX + panW * 0.5, panY + panH - 16, Color(C_RED.r, C_RED.g, C_RED.b, wa), TEXT_ALIGN_CENTER)
	else
		Shadow("RADIACIÓN ACUMULADA", "MetroHUD_GeigerLabel", panX + panW * 0.5, panY + panH - 16, C_ORANGE, TEXT_ALIGN_CENTER)
	end
end

-- ============================================================
--  PLACA DE IDENTIDAD (superior-izquierda)
--  Aparece 6 s al cargar el personaje y se desvanece.
-- ============================================================

local _nameShowUntil = 0

hook.Add("CharacterLoaded", "MetroHUD_ShowName", function()
	_nameShowUntil = CurTime() + 6
end)

local function DrawNameBadge()
	if (CurTime() > _nameShowUntil) then return end
	local client = LocalPlayer()
	if (not IsValid(client)) then return end
	local char = client:GetCharacter()
	if (not char) then return end

	local alpha = math.Clamp((_nameShowUntil - CurTime()) * 90, 0, 235)
	local name  = char:GetName()
	local fid   = char:GetFaction()
	local fdata = ix.faction.indices[fid]
	local fname = fdata and fdata.name or ""

	local panW = 264
	local panH = 54
	local panX = 16
	local panY = 16

	draw.RoundedBox(3, panX, panY, panW, panH, Color(10, 9, 8, math.floor(alpha * 0.88)))
	surface.SetDrawColor(70, 48, 24, alpha)
	surface.DrawOutlinedRect(panX, panY, panW, panH, 1)
	DrawBrackets(panX, panY, panW, panH, 8, Color(154, 136, 102, alpha))

	local fIcon = FACTION_ICON_MATS[fid]
	if (fIcon) then
		DrawMat(fIcon, panX + 11, panY + 11, 32, 32, Color(214, 178, 128, alpha))
	end

	local tx = panX + (fIcon and 52 or 14)
	Shadow(name,  "MetroHUD_Name",    tx, panY + 9,  Color(240, 220, 188, alpha), TEXT_ALIGN_LEFT)
	Shadow(fname, "MetroHUD_Faction", tx, panY + 30, Color(150, 124, 92, alpha), TEXT_ALIGN_LEFT)
end

-- ============================================================
--  Suprimir el flash rojo de daño del motor Source
-- ============================================================

-- El motor Source inyecta un fade rojo a nivel C++ que no se puede
-- bloquear con hooks Lua. Lo contrarrestamos limpiando el ScreenFade
-- del jugador local cada frame cuando esté activo.
hook.Add("RenderScreenspaceEffects", "MetroHUD_BlockDamageFlash", function()
	local client = LocalPlayer()
	if (IsValid(client)) then
		client:ScreenFade(SCREENFADE.PURGE, color_white, 0, 0)
	end
end)

-- ============================================================
--  ACTION BAR — Rebuscando / Buscando / bloqueando...
--  Se activa con SetAction() de Helix; usa la misma paleta y
--  helpers del HUD (DrawPanel, DrawBrackets, DrawBar, Shadow).
-- ============================================================

local AB_SEGS     = 22    -- nº de marcas en la barra segmentada
local AB_PAD      = 7     -- padding interior horizontal y superior
local AB_BAR_H    = 9     -- alto de la barra de progreso interna

-- Color de relleno de la barra de progreso: el mismo naranja Metro de C_ACCENT
-- pero con una punta más brillante en el borde de avance.
local C_AB_FILL   = Color(154, 136,  102, 255)
local C_AB_TIP    = Color(255, 185,  70, 255)

local function DrawActionBar(scrW, scrH)
	if (ix.bar.actionEnd <= CurTime()) then return end

	local start     = ix.bar.actionStart
	local finish    = ix.bar.actionEnd
	local text      = ix.bar.actionText
	local fraction  = math.Clamp(math.TimeFraction(start, finish, CurTime()), 0, 1)
	local remaining = math.max(math.ceil(finish - CurTime()), 0)

	-- Dimensiones proporcionales a la pantalla
	local w = math.floor(scrW * 0.28)
	-- Altura = padding-top + label + gap + barra + padding-bot
	local labelH = 13
	local gap    = 4
	local h      = AB_PAD + labelH + gap + AB_BAR_H + AB_PAD

	local x = math.floor((scrW - w) * 0.5)
	local y = math.floor(scrH * 0.80) - math.floor(h * 0.5)

	-- Fondo con el mismo look que los paneles del HUD
	DrawPanel(x, y, w, h)
	DrawBrackets(x, y, w, h, 7)

	-- Texto de la acción (izquierda)
	local labelY = y + AB_PAD
	Shadow(text, "MetroHUD_Label", x + AB_PAD, labelY, C_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- Contador de segundos (derecha, color ámbar suave)
	local pulse   = Pulse(200, 40, 2.5)
	local timerCol = Color(C_BONE.r, C_BONE.g, C_BONE.b, pulse)
	Shadow(remaining .. "s", "MetroHUD_Small", x + w - AB_PAD, labelY, timerCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	-- Barra de progreso segmentada
	local barX = x + AB_PAD
	local barW = w - AB_PAD * 2
	local barY = labelY + labelH + gap
	DrawBar(barX, barY, barW, AB_BAR_H, fraction, 1, C_AB_FILL, AB_SEGS)

	-- Punta brillante en el borde del progreso (efecto de avance vivo)
	if (fraction > 0 and fraction < 1) then
		local tipW  = math.min(6, math.floor(barW * fraction))
		local tipX  = barX + math.floor(barW * fraction) - tipW
		surface.SetDrawColor(C_AB_TIP)
		surface.DrawRect(tipX, barY, tipW, AB_BAR_H)
	end
end

-- Suprime la barra de acción por defecto de Helix (dibujada en GM:PostDrawHUD).
-- La reemplaza DrawActionBar() con estética MetroUI.
ix.bar.DrawAction = function() end

-- ============================================================
--  TARGET NAME TAG — Nombre al mirar a un jugador
-- ============================================================

-- Suprime el ixTooltip de Helix SOLO para jugadores; el resto de entidades
-- (puertas, props, vendors) siguen usando su tooltip habitual.
function PLUGIN:ShouldPopulateEntityInfo(entity)
	if (IsValid(entity) and (entity:IsPlayer() or IsValid(entity:GetNetVar("player")))) then
		return false
	end
end

local _tagAlpha = 0

local function WrapText(text, font, maxW)
	surface.SetFont(font)
	local lines = {}
	local words = string.Explode(" ", text)
	local line  = ""
	for _, word in ipairs(words) do
		local test = (line == "") and word or (line .. " " .. word)
		if (surface.GetTextSize(test) > maxW and line != "") then
			lines[#lines + 1] = line
			line = word
		else
			line = test
		end
	end
	if (line != "") then lines[#lines + 1] = line end
	return lines
end

local function DrawTargetTag()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end

	local trace = client:GetEyeTrace()
	local ent   = trace.Entity
	local MAX_DIST = 150
	local show  = IsValid(ent) and ent:IsPlayer() and ent != client
	            and client:GetPos():Distance(ent:GetPos()) <= MAX_DIST

	if (show) then
		local char = ent:GetCharacter()
		if (not char) then show = false end

		if (show) then
			_tagAlpha = math.min(_tagAlpha + FrameTime() * 600, 220)

			local name = hook.Run("GetCharacterName", ent) or char:GetName()
			local desc = hook.Run("GetCharacterDescription", ent) or char:GetDescription() or ""
			local hasDesc = desc != ""

			if (ix.hudDebugTag and CurTime() - (ix.hudDebugTagLast or 0) > 1) then
				ix.hudDebugTagLast = CurTime()
				print(("[DBG tag] ent=%s name='%s' desc='%s' hasDesc=%s realDesc='%s'"):format(
					tostring(ent), tostring(name), tostring(desc), tostring(hasDesc), tostring(char:GetDescription())))
			end

			-- Ancla world-space: sobre la cabeza
			local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
			local headPos  = (headBone and select(1, ent:GetBonePosition(headBone))) or (ent:GetPos() + Vector(0, 0, 72))
			local screen   = (headPos + Vector(0, 0, 8)):ToScreen()
			if (not screen.visible) then show = false end

			if (show) then
				local a      = math.floor(_tagAlpha)
				local ACCENT = 2
				local PH     = 8
				local PV     = 4
				local GAP    = 4   -- espacio entre nombre y descripción
				local lineH  = 16
				local lineGap= 2
				local DESC_W = 200

				-- Medir nombre
				surface.SetFont("MetroHUD_TagName")
				local nw, nh = surface.GetTextSize(name)

				-- Wrap descripción
				local descLines  = hasDesc and WrapText(desc, "MetroHUD_TagDesc", DESC_W) or {}
				local descInnerW = 0
				if (hasDesc) then
					surface.SetFont("MetroHUD_TagDesc")
					for _, ln in ipairs(descLines) do
						local lw = surface.GetTextSize(ln)
						if (lw > descInnerW) then descInnerW = lw end
					end
				end

				local innerW = math.max(nw, descInnerW)
				local pw     = ACCENT + PH + innerW + PH
				local nameH  = PV + nh + PV
				local descH  = hasDesc and (GAP + #descLines * lineH + (#descLines - 1) * lineGap + PV) or 0
				local ph     = nameH + descH

				local px = math.floor(screen.x - pw * 0.5)
				local py = math.floor(screen.y - ph - 18)

				-- Fondo gris translúcido (estilo v1)
				surface.SetDrawColor(30, 28, 24, math.floor(a * 0.65))
				surface.DrawRect(px, py, pw, ph)

				-- Acento izquierdo 2px naranja
				surface.SetDrawColor(C_BRACKET.r, C_BRACKET.g, C_BRACKET.b, a)
				surface.DrawRect(px, py, ACCENT, ph)

				-- Nombre centrado
				local cx = px + ACCENT + PH + math.floor(innerW * 0.5)
				local ty = py + PV
				draw.SimpleText(name, "MetroHUD_TagName", cx + 1, ty + 1, Color(0, 0, 0, math.floor(a * 0.75)), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(name, "MetroHUD_TagName", cx,     ty,     Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

				-- Descripción
				if (hasDesc) then
					local lx = px + ACCENT + PH
					local ly = py + nameH + GAP
					for _, ln in ipairs(descLines) do
						draw.SimpleText(ln, "MetroHUD_TagDesc", lx + 1, ly + 1, Color(0, 0, 0, math.floor(a * 0.55)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
						draw.SimpleText(ln, "MetroHUD_TagDesc", lx,     ly,     Color(C_BONE.r, C_BONE.g, C_BONE.b, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
						ly = ly + lineH + lineGap
					end
				end
			end
		end
	end

	if (not show) then
		_tagAlpha = math.max(_tagAlpha - FrameTime() * 800, 0)
	end
end

-- ============================================================
--  HOOK PRINCIPAL
-- ============================================================

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end
	if (not client:GetCharacter()) then return end

	local scrW, scrH = ScrW(), ScrH()

	-- Oculta el panel vital (esquina inferior-izquierda) mientras el inventario (TAB, ix_invkey)
	-- o el menú estándar de Helix estén abiertos.
	local bMenuOpen = (IsValid(ix.gui.menu) and not ix.gui.menu.bClosing) or IsValid(ix.gui.metroInventory)
	if (not bMenuOpen) then
		DrawVitalPanel(scrW, scrH)
	end

	DrawGeigerPanel(scrW, scrH)
	DrawAmmoPanel(scrW, scrH)
	DrawNameBadge()
	DrawActionBar(scrW, scrH)
	DrawTargetTag()
end

-- ============================================================
--  TOOLTIP DE ÍTEMS — estilo Metro
-- ============================================================

ix.hud.PopulateItemTooltip = function(tooltip, item)
	local name = tooltip:AddRow("name")
	name:SetFont("MetroHUD_TagName")
	name:SetTextColor(C_WHITE)
	name:SetExpensiveShadow(1, color_black)
	name:SetText(item.GetName and item:GetName() or L(item.name))
	name:SetMaxWidth(math.max(name:GetMaxWidth(), ScrW() * 0.5))
	name:SetContentAlignment(5)
	name:SizeToContents()
	name.PaintBackground = function() end
	name._metroStyled = true

	local description = tooltip:AddRow("description")
	description:SetFont("MetroHUD_TagDesc")
	description:SetTextColor(C_BONE)
	description:SetExpensiveShadow(1, color_black)
	description:SetText(item:GetDescription() or "")
	description:SetContentAlignment(5)
	description:SizeToContents()
	description.Paint = function(_, w, h)
		surface.SetDrawColor(70, 48, 24, 120)
		surface.DrawRect(8, 0, w - 16, 1)
	end
	description._metroStyled = true

	if (item.PopulateTooltip) then
		item:PopulateTooltip(tooltip)
	end

	hook.Run("PopulateItemTooltip", tooltip, item)

	for _, v in ipairs(tooltip:GetChildren()) do
		if (IsValid(v) and not v._metroStyled) then
			v:SetFont("MetroHUD_TagDesc")
			v:SetTextColor(C_GRAY)
			v:SetContentAlignment(5)
			v:SetExpensiveShadow(1, color_black)
			v:SizeToContents()
			v.PaintBackground = function() end
			v._metroStyled = true
		end
	end
end

concommand.Add("ix_debug_needs", function()
	local client = LocalPlayer()
	local char = client:GetCharacter()

	print("=== NEEDS DEBUG ===")
	print("LocalVar satiety:", client:GetLocalVar("satiety", "NOT_SET"))
	print("LocalVar saturation:", client:GetLocalVar("saturation", "NOT_SET"))

	if (char) then
		print("Character: YES (ID " .. (char:GetID() or "?") .. ")")
		if (char.GetSatiety) then
			print("char:GetSatiety():", char:GetSatiety())
		else
			print("char:GetSatiety: NO EXISTE (plugin needs no cargado?)")
		end
		if (char.GetSaturation) then
			print("char:GetSaturation():", char:GetSaturation())
		else
			print("char:GetSaturation: NO EXISTE (plugin needs no cargado?)")
		end
	else
		print("Character: NO")
	end
	print("=== END ===")
end)
