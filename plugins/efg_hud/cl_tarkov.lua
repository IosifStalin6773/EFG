-- Port del addon "EFT HUD" (tarkovhud.lua) como parte de efg_hud: silueta de
-- estado por zonas, postura con reglas de altura y velocidad, barra de
-- resistencia, comprobación de cargador y modo de disparo, avisos abajo a la
-- derecha, cursor de interacción, pantalla de casi muerte y cierre al morir.
-- Lee los datos de EFG (efgHP, efgPain, efgPainkiller, stm) en vez de VIVO/OJS
-- y no necesita el addon instalado: texturas en content/materials/efg/hud.
local hud = ix.efg.hud

-- efg_hud carga antes que efg_ui (orden alfabético): escala propia por si
-- ix.efgui aún no existe al crear las fuentes
local function S(v)
	if (ix.efgui and ix.efgui.Scale) then return ix.efgui.Scale(v) end
	return math.max(1, math.Round(v * math.max(ScrH() / 1080, 0.75)))
end

local MAT = {}
local function mat(path)
	MAT[path] = MAT[path] or Material("efg/hud/" .. path .. ".png", "smooth")
	return MAT[path]
end

local function createFonts()
	surface.CreateFont("efgTarkov.Big", {font = "MBender", extended = true, size = S(39), weight = 500})
	surface.CreateFont("efgTarkov.Icon", {font = "MBender", extended = true, size = S(14), weight = 500, outline = true})
	surface.CreateFont("efgTarkov.Notice", {font = "MBender", extended = true, size = S(18), weight = 500})
	surface.CreateFont("efgTarkov.Interact", {font = "MBender", extended = true, size = S(12), weight = 500})
end

createFonts()
hook.Add("InitPostEntity", "efgTarkov.Fonts", createFonts)
hook.Add("OnScreenSizeChanged", "efgTarkov.Fonts", createFonts)

local function texture(path, x, y, w, h, r, g, b, a)
	surface.SetDrawColor(r, g, b, a)
	surface.SetMaterial(mat(path))
	surface.DrawTexturedRect(x, y, w, h)
end

-- ─── Avisos (abajo a la derecha) ─────────────────────────────────────────────
local notice = {text = "", red = false, at = -10, alpha = 0, slide = 30}

function hud.Notify(text, red)
	notice.text, notice.red, notice.at = text, red, CurTime()
	notice.alpha, notice.slide = 0, 30
	surface.PlaySound("efg/notification_exp.wav")
end

function hud.DrawNotice()
	local active = notice.at + 3 > CurTime()
	notice.slide = math.Approach(notice.slide, active and 0 or 30, 30 * FrameTime() / 0.25)
	notice.alpha = math.Approach(notice.alpha, active and 205 or 0, 205 * FrameTime() / (active and 0.4 or 0.15))
	if (notice.alpha <= 0 and !active) then return end

	local x, y = ScrW() - S(500), ScrH() - S(30) + S(notice.slide)
	draw.RoundedBox(2, x, y, S(500), S(26), Color(0, 0, 0, 235 * notice.alpha / 205))
	texture(notice.red and "icons/notification_icon_alert_red" or "icons/notification_icon_alert",
		x + S(3), y - S(1), S(30), S(29), 255, 255, 255, notice.alpha)
	draw.SimpleText(notice.text, "efgTarkov.Notice", x + S(35), y + S(3), Color(220, 220, 220, notice.alpha * 255 / 205))
end

-- ─── Estado por zonas (arriba a la izquierda) ────────────────────────────────
-- Posiciones y tamaños del addon original sobre battle_char_back (148x264).
local layout = {
	head    = {"health_condition/battle_head",       54, 15, 41, 45},
	thorax  = {"health_condition/battle_chest",      43, 43, 60, 64},
	stomach = {"health_condition/battle_belly",      42, 87, 56, 50},
	larm    = {"health_condition/battle_hand_left",  82, 50, 45, 98},
	rarm    = {"health_condition/battle_hand_right", 19, 53, 45, 97},
	lleg    = {"health_condition/battle_leg_left",   63, 79, 50, 170},
	rleg    = {"health_condition/battle_leg_right",  30, 114, 48, 129},
}

local cond = {alpha = 255, shownAt = 0, signature = "", blur = 0, nearDeath = 0}

-- colores: "monocromo" del addon (blanco → rojo, negro destruida) o
-- verde → rojo con efg_hud_color 1
local colored = CreateClientConVar("efg_hud_color", "0", true)
local autohide = CreateClientConVar("efg_hud_autohide", "1", true)

local function partColor(p)
	if (p.dead) then return 0, 0, 0 end

	if (colored:GetBool()) then
		return math.Clamp(310 - p.frac * 310, 0, 155), math.Clamp(p.frac * 310, 0, 155), 0
	end

	return 155, p.frac * 155, p.frac * 155
end

local function conditionData(client)
	local parts = ix.efgui.BodyFromNet(client:GetNetVar("efgHP"))
	local data = {parts = parts, total = 0, max = 0, bleed = 0, fracture = 0}

	for _, p in pairs(parts) do
		data.total = data.total + math.max(0, p.hp)
		data.max = data.max + p.max
		if (p.bleed > 0) then data.bleed = data.bleed + 1 end
		if (p.fracture) then data.fracture = data.fracture + 1 end
	end

	local pk = client:GetNetVar("efgPainkiller")
	data.painkiller = pk and pk > CurTime()
	data.pain = client:GetNetVar("efgPain") and !data.painkiller

	return data
end

function hud.DrawCondition(client)
	local data = conditionData(client)

	-- se muestra 3 s tras cualquier cambio (como el addon) o siempre si sangras
	local signature = ("%d|%d|%d|%s|%s"):format(data.total, data.bleed, data.fracture, tostring(data.pain), tostring(data.painkiller))
	if (signature != cond.signature) then
		if (cond.oldTotal and data.total > cond.oldTotal + 0.5) then
			hud.Notify(("Experiencia de tratamiento - Curación (%d)"):format(data.total - cond.oldTotal))
		elseif (cond.oldTotal and data.total < cond.oldTotal) then
			cond.blur = 8
		end

		cond.signature, cond.shownAt, cond.oldTotal = signature, CurTime(), data.total
	end

	local visible = !autohide:GetBool() or cond.shownAt + 3 > CurTime() or data.bleed > 0
	cond.alpha = math.Approach(cond.alpha, visible and 255 or 0, 255 * FrameTime() / 0.25)
	cond.nearDeath = math.Approach(cond.nearDeath, data.total <= data.max / 3.5 and 255 or 0, 255 * FrameTime() / 6)

	if (cond.nearDeath > 0) then
		texture("deathscreen/neardeath", 0, 0, ScrW(), ScrH(), 255, 255, 255, cond.nearDeath)
	end

	local a = cond.alpha
	if (a <= 0) then return end

	local x, y = S(1), S(1)
	texture("health_condition/battle_char_back", x, y, S(148), S(264), 255, 255, 255, a)

	for id, l in pairs(layout) do
		local p = data.parts[id]
		if (p) then
			local r, g, b = partColor(p)
			texture(l[1], x + S(l[2]), y + S(l[3]), S(l[4]), S(l[5]), r, g, b, a)
		end
	end

	-- iconos de efectos a la derecha de la silueta, apilados
	local effects = {}
	if (data.pain) then effects[#effects + 1] = {"health_condition/effect_pain"} end
	if (data.painkiller) then effects[#effects + 1] = {"health_condition/effect_painkiller"} end
	if (data.bleed > 0) then effects[#effects + 1] = {"health_condition/effect_light_bleeding", data.bleed} end
	if (data.fracture > 0) then effects[#effects + 1] = {"health_condition/effect_fracture", data.fracture} end

	for i, e in ipairs(effects) do
		local ey = y + S(7) + (i - 1) * S(22)
		texture(e[1], x + S(145), ey, S(24), S(22), 255, 255, 255, a)

		if (e[2] and e[2] > 1) then
			draw.SimpleText(e[2], "efgTarkov.Icon", x + S(168), ey + S(8), Color(255, 255, 255, a), TEXT_ALIGN_RIGHT)
		end
	end
end

-- desenfoque breve al recibir daño y borroso con casi muerte
hook.Add("RenderScreenspaceEffects", "efgTarkov.DamageBlur", function()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	cond.blur = math.Approach(cond.blur, 0, 6 * FrameTime() / 0.5)
	if (cond.blur > 0) then DrawToyTown(cond.blur, ScrH() - S(242)) end
	if (cond.nearDeath > 0) then DrawMotionBlur(1 - 0.5 * cond.nearDeath / 255, 1, 0) end
end)

-- ─── Postura, ruido y resistencia (abajo a la izquierda) ─────────────────────
local stanceFrames = {
	{"stamina_and_stance/stand0", -3, 126, 166}, {"stamina_and_stance/stand1", 2, 126, 160},
	{"stamina_and_stance/stand2", 6, 127, 154}, {"stamina_and_stance/stand3", 13, 127, 148},
	{"stamina_and_stance/stand4", 18, 127, 143}, {"stamina_and_stance/stand5", 23, 127, 138},
	{"stamina_and_stance/crouch", 46, 127, 114},
}

local stance = {value = 0, walk = 0, alpha = 255, shownAt = 0, arrow = 0, speed = 0}

local function isAiming(weapon)
	if (!IsValid(weapon)) then return false end
	if (weapon.ARC9 and weapon.GetInSights) then return weapon:GetInSights() end
	if (weapon.Base == "arccw_base" and weapon.GetState and ArcCW) then return weapon:GetState() == ArcCW.STATE_SIGHTS end
	if (weapon.GetIronSights) then return weapon:GetIronSights() end
	return false
end

function hud.DrawStance(client)
	local sw, sh = S(55), ScrH() - S(242)
	local crouch = client:Crouching()
	local aiming = isAiming(client:GetActiveWeapon())
	local now = CurTime()

	local target = crouch and 6 or 0
	if (stance.value != target) then stance.shownAt = now end
	stance.value = math.Approach(stance.value, target, 6 * FrameTime() / 0.15)

	-- velocidad de movimiento: lento (Alt), normal o al apuntar
	local speed = client:KeyDown(IN_WALK) and 55 or (aiming and 55 or 140)
	if (speed != stance.speed) then stance.shownAt = now end
	stance.speed = speed

	local moving = client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT)
	if (moving or client:KeyDown(IN_JUMP)) then stance.shownAt = now end

	local stamina = math.Clamp(client:GetLocalVar("stm", 100) or 100, 0, 100)
	if (stamina < 99) then stance.shownAt = now end

	local visible = !autohide:GetBool() or stance.shownAt + 3 > now
	stance.alpha = math.Approach(stance.alpha, visible and 255 or 0, 255 * FrameTime() / 0.25)

	local a = stance.alpha
	if (a <= 0) then return end

	-- figura
	local frame = stanceFrames[math.min(7, math.floor(stance.value) + 1)]
	texture(frame[1], sw - S(1), sh + S(frame[2]), S(frame[3]), S(frame[4]), 255, 255, 255, a)

	-- ruido
	local noise = (crouch or client:KeyDown(IN_WALK)) and (crouch and client:KeyDown(IN_WALK) and "03" or "02") or "01"
	texture("stamina_and_stance/noise_" .. noise, sw - S(30), sh + S(172), S(16), S(16), 255, 255, 255, a)

	-- regla vertical (altura)
	local vx, vy = sw - S(26), sh + S(13)
	surface.SetDrawColor(255, 255, 255, a)
	surface.SetMaterial(mat("stamina_and_stance/arrow_down_tiny"))
	surface.DrawTexturedRectRotated(vx - S(10), vy + S(1) + (crouch and S(18 * 6) or 0), S(6), S(5), 90)
	draw.RoundedBox(0, vx, vy, S(3), S(18 * 8 + 2), Color(51, 51, 51, a / 2))

	for i = 0, 8 do
		if (i != 7) then draw.RoundedBox(0, vx, vy + S(18 * i), S(3), math.max(1, S(2)), Color(255, 255, 255, a)) end
	end

	-- regla horizontal (velocidad)
	local hx, hy = vx + S(22), vy + S(167)
	texture("stamina_and_stance/arrow_down_tiny", hx - S(1) + S(stance.speed), hy - S(11), S(6), S(5), 255, 255, 255, a)
	draw.RoundedBox(0, hx, hy, S(7 * 20 + 7), S(3), Color(51, 51, 51, a / 2))

	for i = 0, 20 do
		local ta = (aiming and i > 8) and a / 17 or a
		draw.RoundedBox(0, hx + S(7 * i + math.floor(i / 4.5)), hy, math.max(1, S(2)), S(3), Color(255, 255, 255, ta))
	end

	-- resistencia
	local bx, by = sw - S(9), sh + S(185 + 9)
	texture("stamina_and_stance/sprint_panel", bx, by, S(156), S(13), 255, 255, 255, a)
	texture(stamina < 10 and "stamina_and_stance/sprint_slider_exh" or "stamina_and_stance/sprint_slider",
		bx + S(5), by + S(4), S(146) * stamina / 100, S(3), 255, 255, 255, a)

	-- armadura (barra azul, solo si llevas)
	local armor, maxArmor = client:Armor(), math.max(1, client:GetMaxArmor())
	if (armor > 0) then
		texture("stamina_and_stance/sprint_panel", bx, by - S(9), S(156), S(13), 255, 255, 255, a)
		texture("stamina_and_stance/sprint_slider_blue", bx + S(5), by - S(5), S(146) * math.min(1, armor / maxArmor), S(3), 255, 255, 255, a)
	end
end

-- ─── Cargador y modo de disparo (abajo a la derecha) ─────────────────────────
-- Alt + T comprueba el cargador, Alt + B el modo de disparo; también salen al
-- recargar y al cambiar de modo.
local weaponHUD = {ammoAt = -10, modeAt = -10, alpha = 0, mode = nil}

local function magEstimate(clip, maxClip)
	if (clip <= 0) then return "Vacío" end
	if (clip <= maxClip / 5) then return "Casi vacío" end
	if (clip <= maxClip / 2) then return "Menos de la mitad" end
	if (clip <= maxClip / 1.25) then return "Más o menos la mitad" end
	if (clip <= maxClip - 1) then return "Casi lleno" end
	return "Lleno"
end

local function fireMode(weapon)
	if (weapon.ARC9 and weapon.GetFiremodeName) then
		local ok, name = pcall(weapon.GetFiremodeName, weapon)
		if (ok and name) then return name end
	end

	if (weapon.Base == "arccw_base" and weapon.GetFiremodeName) then return weapon:GetFiremodeName() end
	if (weapon.GetFireModeName) then return weapon:GetFireModeName() end
	return weapon.Primary and (weapon.Primary.Automatic and "Automático" or "Semiautomático") or nil
end

function hud.CheckMagazine()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive()) then return end

	weaponHUD.ammoAt, weaponHUD.modeAt = CurTime(), -10
	surface.PlaySound("weapons/ar2/ar2_reload_rotate.wav")
end

function hud.CheckFireMode()
	weaponHUD.modeAt = CurTime()
end

concommand.Add("efg_cargador", function() hud.CheckMagazine() end)
concommand.Add("efg_mododisparo", function() hud.CheckFireMode() end)

hook.Add("PlayerButtonDown", "efgHUD.MagCheck", function(client, button)
	if (client != LocalPlayer() or !IsFirstTimePredicted() or vgui.GetKeyboardFocus()) then return end
	if (!(input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT))) then return end

	if (button == KEY_T) then hud.CheckMagazine()
	elseif (button == KEY_B) then hud.CheckFireMode() end
end)

hook.Add("KeyPress", "efgHUD.Reload", function(client, key)
	if (key == IN_RELOAD and client == LocalPlayer() and IsFirstTimePredicted()) then
		weaponHUD.ammoAt = CurTime()
	end
end)

function hud.DrawWeapon(client)
	local weapon = client:GetActiveWeapon()
	if (!IsValid(weapon) or weapon:GetPrimaryAmmoType() < 0) then return end

	local mode = fireMode(weapon)
	if (mode != weaponHUD.mode) then
		if (weaponHUD.mode != nil) then weaponHUD.modeAt = CurTime() end
		weaponHUD.mode = mode
	end

	local now = CurTime()
	local showMode = weaponHUD.modeAt + 3 > now and mode
	local visible = weaponHUD.ammoAt + 3 > now or showMode
	weaponHUD.alpha = math.Approach(weaponHUD.alpha, visible and 255 or 0, 255 * FrameTime() / 0.25)

	local a = weaponHUD.alpha
	if (a <= 0) then return end

	local clip, maxClip = weapon:Clip1(), weapon:GetMaxClip1()
	local text

	if (showMode) then
		text = mode
	elseif (clip < 0 or maxClip <= 0) then
		text = tostring(math.min(999, client:GetAmmoCount(weapon:GetPrimaryAmmoType())))
	else
		text = magEstimate(clip, maxClip)
	end

	local x, y = ScrW() - S(95), ScrH() - S(119)
	surface.SetFont("efgTarkov.Big")
	local tw = surface.GetTextSize(text)

	draw.RoundedBox(2, x - tw - S(7), y + S(2), tw + S(10), S(38), Color(0, 0, 0, a / 3))
	draw.SimpleText(text, "efgTarkov.Big", x, y, Color(255, 255, 255, a), TEXT_ALIGN_RIGHT)

	if (!showMode) then
		local ammoName = game.GetAmmoName(weapon:GetPrimaryAmmoType()) or ""
		ammoName = language.GetPhrase(ammoName .. "_ammo") != ammoName .. "_ammo" and language.GetPhrase(ammoName .. "_ammo") or ammoName
		local nx, ny = ScrW() - S(100), ScrH() - S(80)
		local nw = surface.GetTextSize(ammoName)

		texture("icons/icon_info_magsize", nx - nw - S(25), ny + S(10), S(19), S(20), 255, 255, 255, a)
		draw.SimpleText(ammoName, "efgTarkov.Big", nx, ny, Color(220, 220, 220, a), TEXT_ALIGN_RIGHT)
	end
end

-- ─── Cursor de interacción (centro) ──────────────────────────────────────────
local cursor = {alpha = 255, hand = false}

-- Otros plugins (efg_doors) pueden dar su propia acción y una lista de
-- opciones que se elige con la rueda; false oculta el cursor.
local function interaction(ent)
	local action, name, options, selected = hook.Run("EFGInteraction", LocalPlayer(), ent)
	if (action == false) then return end
	if (action) then return action, name, options, selected end

	local class = ent:GetClass()

	if (class == "ix_item") then
		local item = ent.GetItemTable and ent:GetItemTable()
		return "COGER", item and string.upper(item.GetName and item:GetName() or L(item.name)) or nil
	elseif (class == "prop_door_rotating" or class == "func_door_rotating" or class == "func_door") then
		return "ABRIR"
	elseif (class == "ix_container" or ent.bIsContainer) then
		return "REGISTRAR", string.upper(ent.GetDisplayName and ent:GetDisplayName() or "")
	elseif (ent:IsWeapon()) then
		return "COGER", string.upper(ent:GetPrintName() or "")
	elseif (class:find("^ix_") or class:find("^efg_")) then
		return "USAR"
	end
end

function hud.DrawCursor(client)
	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:EyeAngles():Forward() * 100,
		filter = client
	})

	local ent = trace.Entity
	local action, name, options, selected

	if (IsValid(ent) and !ent:IsPlayer() and !ent:IsNPC()) then
		action, name, options, selected = interaction(ent)
	end

	cursor.alpha = math.Approach(cursor.alpha, action and 255 or 0, 255 * FrameTime() / (action and 0.25 or 0.5))
	if (cursor.alpha <= 0) then return end

	if (action) then cursor.action, cursor.name, cursor.options, cursor.selected = action, name, options, selected end

	local a = cursor.alpha
	local x, y = ScrW() / 2, ScrH() / 2
	if (isAiming(client:GetActiveWeapon())) then y = y + S(200) end

	texture("icons/cursor_hand", x - S(20), y - S(18), S(38), S(38), 255, 255, 255, a)

	surface.SetFont("efgTarkov.Interact")

	if (cursor.options) then
		-- lista de acciones a la derecha de la mano, la elegida resaltada
		local bw = 0

		for _, text in ipairs(cursor.options) do
			bw = math.max(bw, surface.GetTextSize(text) + S(16))
		end

		local ox, oy = x + S(24), y - S(18)
		local rowH = S(19)

		for i, text in ipairs(cursor.options) do
			local ry = oy + (i - 1) * rowH
			local chosen = i == cursor.selected

			draw.RoundedBox(1, ox, ry, bw, rowH - S(2), Color(0, 0, 0, a * (chosen and 1 or 0.7)))

			if (chosen) then
				draw.RoundedBox(1, ox + S(3), ry + S(3), bw - S(6), rowH - S(8), Color(131, 131, 131, a))
			end

			draw.SimpleText(text, "efgTarkov.Interact", ox + S(8), ry + S(3), chosen and Color(0, 0, 0, a) or Color(220, 220, 220, a))
		end
	else
		local bw = surface.GetTextSize(cursor.action or "") + S(16)
		draw.RoundedBox(1, x - bw / 2 - 1, y - S(40), bw, S(19), Color(0, 0, 0, a))
		draw.RoundedBox(1, x - bw / 2 + S(3) - 1, y - S(37), bw - S(6), S(13), Color(131, 131, 131, a))
		draw.SimpleText(cursor.action or "", "efgTarkov.Interact", x - 1, y - S(37), Color(0, 0, 0, a), TEXT_ALIGN_CENTER)
	end

	if (cursor.name and cursor.name != "") then
		local nw = surface.GetTextSize(cursor.name) + S(10)
		draw.RoundedBox(1, x - nw / 2 - 1, y + S(31), nw, S(13), Color(0, 0, 0, a))
		draw.SimpleText(cursor.name, "efgTarkov.Interact", x - 1, y + S(31), Color(220, 220, 220, a), TEXT_ALIGN_CENTER)
	end
end

-- ─── Cierre al morir ─────────────────────────────────────────────────────────
-- Dos persianas que se cierran mientras la pantalla se oscurece.
local death = {at = nil, shutter = 1000, bright = 0}

hook.Add("HUDPaint", "efgTarkov.Death", function()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter()) then return end

	if (client:Alive()) then
		death.at, death.shutter, death.bright, cond.nearDeath = nil, 1000, 0, 0
		return
	end

	death.at = death.at or CurTime()

	if (death.at + 2 < CurTime()) then
		death.shutter = math.Approach(death.shutter, -50, 1000 * FrameTime() / 0.4)
		death.bright = math.Approach(death.bright, -1, FrameTime() / 0.4)
	else
		death.bright = math.Approach(death.bright, -0.1, 0.1 * FrameTime() / 2)
	end

	local w, h = ScrW(), ScrH()
	local offset = S(death.shutter)
	texture("deathscreen/deathscreen_u", -S(96), offset, w * 1.1, h * 1.1, 255, 255, 255, 255)
	texture("deathscreen/deathscreen_d", -S(96), -offset - S(80), w * 1.1, h * 1.1, 255, 255, 255, 255)
end)

hook.Add("RenderScreenspaceEffects", "efgTarkov.DeathFade", function()
	if (!death.at) then return end

	DrawColorModify({
		["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = death.bright, ["$pp_colour_colour"] = 1, ["$pp_colour_contrast"] = 1,
		["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
	})
end)

-- ─── HUD de Tarkov del Workshop (tarkovhud.lua) ─────────────────────────────
-- Viene en la colección y pinta su propia postura, avisos y daño encima de
-- este HUD (todo sale doble). Se quitan sus hooks y se apaga su convar.
local workshopHooks = {
	HUDPaint = "EscapeFromTarkov_HUD",
	HUDShouldDraw = "EscapeFromTarkov_HideHUD",
	HUDDrawPickupHistory = "EscapeFromTarkov_HidePickedHistoryHUD",
	RenderScreenspaceEffects = "EscapeFromTarkov_HUDDamageEffect",
	HUDWeaponPickedUp = "EscapeFromTarkov_HUDWeaponPickedUp",
	HUDItemPickedUp = "EscapeFromTarkov_HUDItemPickedUp",
	HUDAmmoPickedUp = "EscapeFromTarkov_HUDAmmoPickedUp"
}

local function disableWorkshopHUD()
	for event, name in pairs(workshopHooks) do
		hook.Remove(event, name)
	end

	if (ConVarExists("tarkovhud_enabled")) then
		RunConsoleCommand("tarkovhud_enabled", "0")
	end
end

hook.Add("InitPostEntity", "efgTarkov.NoWorkshopHUD", disableWorkshopHUD)

-- el addon vuelve a añadir algunos hooks al reaparecer o al recibir daño
timer.Create("efgTarkov.NoWorkshopHUD", 5, 0, function()
	local hooks = hook.GetTable()

	for event, name in pairs(workshopHooks) do
		if (hooks[event] and hooks[event][name]) then
			disableWorkshopHUD()
			return
		end
	end
end)
