-- HUD de EFG. Todo se dibuja con el kit Pizarra (efg_ui); no usa texturas de
-- ningún addon. Por diseño muestra poco: el estado físico siempre, el resto
-- solo cuando importa (necesidades bajas, resistencia gastándose, cargador
-- comprobado a mano, acciones en curso).
local PLUGIN = PLUGIN
local hud = ix.efg.hud

local function UI() return ix.efgui end
local function S(v) return ix.efgui.Scale(v) end

hook.Add("HUDShouldNotDraw", "efgHUD.Hide", function(name)
	if (PLUGIN.hide[name]) then return true end
end)

function PLUGIN:HUDShouldDraw(name)
	if (PLUGIN.hide[name]) then return false end
end

-- el destello rojo de daño del motor no se puede quitar con hooks: se purga cada frame
hook.Add("RenderScreenspaceEffects", "efgHUD.NoDamageFlash", function()
	local client = LocalPlayer()
	if (IsValid(client)) then client:ScreenFade(SCREENFADE.PURGE, color_white, 0, 0) end
end)

local function menuOpen()
	return (IsValid(ix.gui.menu) and !ix.gui.menu.bClosing) or IsValid(ix.gui.metroInventory)
		or IsValid(ix.gui.efgLobby)
end

-- ─── Medidores de necesidades ────────────────────────────────────────────────
-- Fila compacta: etiqueta, medidor segmentado y valor. Energía e hidratación
-- solo aparecen por debajo del 60 %, el peso solo si pasas del 80 % del máximo.
local function needRows(client, character)
	local rows = {}
	local c = UI().color

	local energy = (character.GetSatiety and character:GetSatiety()) or client:GetLocalVar("satiety", 100) or 100
	local water = (character.GetSaturation and character:GetSaturation()) or client:GetLocalVar("saturation", 100) or 100

	if (energy < 60) then rows[#rows + 1] = {"ENERGÍA", energy / 100, math.floor(energy) .. "%", energy < 25 and c.crit or c.warn} end
	if (water < 60) then rows[#rows + 1] = {"HIDRATACIÓN", water / 100, math.floor(water) .. "%", water < 25 and c.crit or c.info} end

	local carry = character:GetData("carry", 0)
	local maxWeight = character.GetMaxWeight and character:GetMaxWeight() or 30

	if (carry > maxWeight * 0.8) then
		rows[#rows + 1] = {"PESO", carry / math.max(1, maxWeight), ("%.1f / %d kg"):format(carry, maxWeight), carry > maxWeight and c.crit or c.warn}
	end

	for _, buff in ipairs({{"nutridoEnd", "NUTRIDO", c.ok}, {"intoxicadoEnd", "INTOXICADO", c.crit}}) do
		local ends = client:GetNetVar(buff[1], 0)

		if (ends > CurTime()) then
			local left = ends - CurTime()
			rows[#rows + 1] = {buff[2], nil, ("%d:%02d"):format(math.floor(left / 60), left % 60), buff[3]}
		end
	end

	return rows
end

-- Silueta corporal arriba a la izquierda: siempre visible, más tenue si estás
-- sano. Debajo, la vida total y los estados (sangrado, fractura, dolor).
local function drawBody(client)
	local c = UI().color
	local data = client:GetNetVar("efgHP")
	local parts = UI().BodyFromNet(data)
	local total, injured = 0, false
	local bleeding, fractured = false, false

	for _, p in pairs(parts) do
		total = total + math.max(0, p.hp)
		if (p.frac < 1 or p.bleed > 0 or p.fracture) then injured = true end
		if (p.bleed > 0) then bleeding = true end
		if (p.fracture) then fractured = true end
	end

	local alpha = injured and 1 or 0.55
	local w, h = S(64), S(140)
	local x, y = S(20), S(20)

	UI().DrawBody(x, y, w, h, parts, alpha)

	local maxHP = ix.efg.health and ix.efg.health.total or 440
	local ty = y + h + S(8)
	surface.SetAlphaMultiplier(alpha)
		draw.SimpleText(("%d"):format(math.Round(total)), "efgx.NumBig", x, ty, total < maxHP * 0.3 and c.crit or c.text)
		draw.SimpleText("/" .. maxHP, "efgx.Num", x + S(64), ty + S(14), c.text2)
	surface.SetAlphaMultiplier(1)

	local sy = ty + S(36)
	local states = {}
	if (bleeding) then states[#states + 1] = {"SANGRADO", c.crit} end
	if (fractured) then states[#states + 1] = {"FRACTURA", c.warn} end
	if (client:GetNetVar("efgPain")) then states[#states + 1] = {"DOLOR", c.warn} end

	local pk = client:GetNetVar("efgPainkiller")
	if (pk and pk > CurTime()) then states[#states + 1] = {("ANALGÉSICO %ds"):format(math.ceil(pk - CurTime())), c.info} end

	for i, st in ipairs(states) do
		local yy = sy + (i - 1) * S(16)
		surface.SetDrawColor(st[2])
		surface.DrawRect(x, yy + S(3), S(3), S(10))
		draw.SimpleText(st[1], "efgx.Label", x + S(8), yy, st[2])
	end
end

-- Postura abajo a la izquierda: de pie, agachado o tumbado en el suelo, con
-- una figura sencilla dibujada a mano y el modo de movimiento.
local function drawStance(client)
	local c = UI().color
	local crouch = client:Crouching()
	local walking = client:KeyDown(IN_WALK)
	local x, bottom = S(20), ScrH() - S(20)
	local fh = crouch and S(34) or S(52)
	local fw = S(14)

	surface.SetDrawColor(c.text2.r, c.text2.g, c.text2.b, 200)
	-- cabeza, tronco y piernas
	surface.DrawRect(x + fw / 2 - S(4), bottom - fh, S(8), S(8))
	surface.DrawRect(x + fw / 2 - S(5), bottom - fh + S(10), S(10), fh * 0.38)
	surface.DrawRect(x + fw / 2 - S(5), bottom - fh * 0.5 + S(4), S(4), fh * 0.5 - S(4))
	surface.DrawRect(x + fw / 2 + S(1), bottom - fh * 0.5 + S(4), S(4), fh * 0.5 - S(4))

	-- marcas de altura (como una regla) a la izquierda
	for i = 0, 4 do
		local yy = bottom - i * S(13)
		surface.SetDrawColor(c.line)
		surface.DrawRect(x - S(8), yy - 1, i % 2 == 0 and S(5) or S(3), 1)
	end

	draw.SimpleText(crouch and "AGACHADO" or "DE PIE", "efgx.Label", x + fw + S(10), bottom - S(24), c.text2)
	draw.SimpleText(walking and "SIGILO" or (client:KeyDown(IN_SPEED) and "CARRERA" or "NORMAL"), "efgx.Label", x + fw + S(10), bottom - S(10), c.textDim)
end

local function drawStatus(client, character)
	local c = UI().color
	local left, bottom = S(20), ScrH() - S(84)

	drawBody(client)
	drawStance(client)

	local rows = needRows(client, character)
	if (#rows == 0) then return end

	local w = S(240)
	local rowH = S(20)
	local h = S(8) + #rows * rowH
	local y = bottom - h

	UI().DrawPanel(left, y, w, h, 220)

	for i, row in ipairs(rows) do
		local ry = y + S(4) + (i - 1) * rowH

		surface.SetDrawColor(row[4])
		surface.DrawRect(left, ry + S(3), S(2), rowH - S(6))
		draw.SimpleText(row[1], "efgx.Label", left + S(8), ry + rowH / 2, c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(row[3], "efgx.Num", left + w - S(8), ry + rowH / 2, c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		if (row[2]) then
			UI().DrawMeter(left + S(92), ry + rowH / 2 - S(3), w - S(92) - S(78), S(6), math.Clamp(row[2], 0, 1), 10, row[4])
		end
	end
end

-- ─── Resistencia (centro inferior) ───────────────────────────────────────────
-- Solo se ve mientras se gasta o se recupera; se desvanece al llenarse.
local staminaAlpha = 0

local function drawStamina(client)
	local stamina = math.Clamp(client:GetLocalVar("stm", 100) or 100, 0, 100)
	local target = stamina < 99 and 1 or 0
	staminaAlpha = math.Approach(staminaAlpha, target, FrameTime() * (target > 0 and 4 or 1.5))
	if (staminaAlpha <= 0.01) then return end

	local c = UI().color
	local w, h = S(260), S(5)
	local x, y = ScrW() / 2 - w / 2, ScrH() - S(28)
	local col = stamina < 20 and c.crit or c.text2

	surface.SetAlphaMultiplier(staminaAlpha)
		surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, 200)
		surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
		surface.SetDrawColor(col)
		surface.DrawRect(x, y, w * stamina / 100, h)
		draw.SimpleText("RESISTENCIA", "efgx.Label", x, y - S(4), c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	surface.SetAlphaMultiplier(1)
end

-- ─── Arma y comprobación de cargador (abajo a la derecha) ────────────────────
-- No hay contador permanente de balas: el panel sale unos segundos al cambiar
-- de arma, al recargar o al comprobar el cargador (Alt + T o efg_cargador),
-- y el cargador se describe de forma aproximada.
hud.weaponShowUntil = 0
hud.magCheckUntil = 0

local function magEstimate(clip, maxClip)
	if (maxClip <= 0) then return "—" end
	local frac = clip / maxClip

	if (clip <= 0) then return "VACÍO" end
	if (frac >= 1) then return "LLENO" end
	if (frac > 0.75) then return "CASI LLENO" end
	if (frac > 0.4) then return "MÁS DE LA MITAD" end
	if (frac > 0.15) then return "MENOS DE LA MITAD" end
	return "CASI VACÍO"
end

function hud.CheckMagazine()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive()) then return end

	hud.magCheckUntil = CurTime() + 3.5
	hud.weaponShowUntil = math.max(hud.weaponShowUntil, CurTime() + 3.5)
	surface.PlaySound("weapons/ar2/ar2_reload_rotate.wav")
end

concommand.Add("efg_cargador", function() hud.CheckMagazine() end)

hook.Add("PlayerButtonDown", "efgHUD.MagCheck", function(client, button)
	if (button == KEY_T and client == LocalPlayer() and IsFirstTimePredicted()
		and (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) and !vgui.GetKeyboardFocus()) then
		hud.CheckMagazine()
	end
end)

local lastWeapon

hook.Add("Think", "efgHUD.WeaponWatch", function()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local weapon = client:GetActiveWeapon()

	if (weapon != lastWeapon) then
		lastWeapon = weapon
		hud.weaponShowUntil = CurTime() + 2.5
	end
end)

hook.Add("KeyPress", "efgHUD.Reload", function(client, key)
	if (key == IN_RELOAD and client == LocalPlayer()) then
		hud.weaponShowUntil = CurTime() + 4
	end
end)

local function drawWeapon(client)
	if (hud.weaponShowUntil <= CurTime()) then return end

	local weapon = client:GetActiveWeapon()
	if (!IsValid(weapon)) then return end

	local c = UI().color
	local alpha = math.Clamp((hud.weaponShowUntil - CurTime()) * 2, 0, 1)
	local name = string.upper(weapon:GetPrintName() or weapon:GetClass())
	local clip, maxClip = weapon:Clip1(), weapon:GetMaxClip1()
	local hasMag = clip >= 0 and maxClip > 0
	local w, h = S(280), hasMag and S(62) or S(34)
	local x, y = ScrW() - w - S(16), ScrH() - h - S(16)

	surface.SetAlphaMultiplier(alpha)
		UI().DrawPanel(x, y, w, h, 220)
		draw.SimpleText(name, "efgx.Header", x + S(12), y + S(8), c.text)

		if (hasMag) then
			local checking = hud.magCheckUntil > CurTime()
			local ammoID = weapon:GetPrimaryAmmoType()
			local reserve = ammoID >= 0 and client:GetAmmoCount(ammoID) or 0
			local ammoName = ammoID >= 0 and string.upper(game.GetAmmoName(ammoID) or "") or ""

			draw.SimpleText(checking and magEstimate(clip, maxClip) or "ALT + T  COMPROBAR CARGADOR", "efgx.Label",
				x + S(12), y + S(36), checking and c.accent or c.textDim)
			draw.SimpleText(ammoName, "efgx.Label", x + w - S(12), y + S(10), c.textDim, TEXT_ALIGN_RIGHT)
			draw.SimpleText(("RESERVA %d"):format(reserve), "efgx.Num", x + w - S(12), y + S(32), reserve > 0 and c.text2 or c.crit, TEXT_ALIGN_RIGHT)
		end
	surface.SetAlphaMultiplier(1)
end

-- ─── Barra de acción (SetAction de Helix) ────────────────────────────────────
ix.bar.DrawAction = function() end

local function drawAction()
	if (!ix.bar.actionEnd or ix.bar.actionEnd <= CurTime()) then return end

	local c = UI().color
	local frac = math.Clamp(math.TimeFraction(ix.bar.actionStart, ix.bar.actionEnd, CurTime()), 0, 1)
	local w, h = math.floor(ScrW() * 0.26), S(46)
	local x, y = ScrW() / 2 - w / 2, math.floor(ScrH() * 0.78)

	UI().DrawPanel(x, y, w, h, 230)
	draw.SimpleText(ix.bar.actionText or "", "efgx.Body", x + S(12), y + S(8), c.text)
	draw.SimpleText(("%.1f s"):format(math.max(0, ix.bar.actionEnd - CurTime())), "efgx.Num", x + w - S(12), y + S(8), c.text2, TEXT_ALIGN_RIGHT)
	UI().DrawMeter(x + S(12), y + h - S(14), w - S(24), S(6), frac, 20, c.accent)
end

-- ─── Placa de identidad al cargar el personaje ───────────────────────────────
local nameUntil = 0
hook.Add("CharacterLoaded", "efgHUD.Name", function() nameUntil = CurTime() + 6 end)

local function drawNameBadge(character)
	if (nameUntil <= CurTime()) then return end

	local c = UI().color
	local faction = ix.faction.indices[character:GetFaction()]
	local w, h = S(280), S(54)
	local x, y = S(16), S(16)

	surface.SetAlphaMultiplier(math.Clamp(nameUntil - CurTime(), 0, 1))
		UI().DrawPanel(x, y, w, h, 230)
		surface.SetDrawColor(faction and faction.color or c.accent)
		surface.DrawRect(x, y, S(3), h)
		draw.SimpleText(character:GetName(), "efgx.Title", x + S(14), y + S(6), c.text)
		draw.SimpleText(string.upper(faction and faction.name or ""), "efgx.Label", x + S(14), y + S(34), c.text2)
	surface.SetAlphaMultiplier(1)
end

-- ─── Etiqueta al mirar a otro jugador ────────────────────────────────────────
function PLUGIN:ShouldPopulateEntityInfo(entity)
	if (IsValid(entity) and (entity:IsPlayer() or IsValid(entity:GetNetVar("player")))) then
		return false
	end
end

local tagAlpha, tagTarget = 0, nil

local function drawTargetTag(client)
	local ent = client:GetEyeTrace().Entity
	local valid = IsValid(ent) and ent:IsPlayer() and ent != client and ent:GetCharacter()
		and client:GetPos():Distance(ent:GetPos()) <= 150

	if (valid) then tagTarget = ent end
	tagAlpha = math.Approach(tagAlpha, valid and 1 or 0, FrameTime() * (valid and 5 or 7))
	if (tagAlpha <= 0 or !IsValid(tagTarget) or !tagTarget:GetCharacter()) then return end

	local c = UI().color
	local name = hook.Run("GetCharacterName", tagTarget) or tagTarget:GetCharacter():GetName()
	local bone = tagTarget:LookupBone("ValveBiped.Bip01_Head1")
	local pos = (bone and tagTarget:GetBonePosition(bone)) or (tagTarget:GetPos() + Vector(0, 0, 72))
	local screen = (pos + Vector(0, 0, 10)):ToScreen()
	if (!screen.visible) then return end

	surface.SetFont("efgx.Body")
	local tw, th = surface.GetTextSize(name)
	local w, h = tw + S(20), th + S(8)
	local x, y = math.floor(screen.x - w / 2), math.floor(screen.y - h)

	surface.SetAlphaMultiplier(tagAlpha)
		surface.SetDrawColor(c.bg1.r, c.bg1.g, c.bg1.b, 200)
		surface.DrawRect(x, y, w, h)
		surface.SetDrawColor(c.accent)
		surface.DrawRect(x, y + h - S(2), w, S(2))
		draw.SimpleText(name, "efgx.Body", x + w / 2, y + h / 2 - 1, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
end

-- ─── Tooltip de objetos ──────────────────────────────────────────────────────
ix.hud.PopulateItemTooltip = function(tooltip, item)
	local c = ix.efgui.color

	local name = tooltip:AddRow("name")
	name:SetImportant()
	name:SetFont("efgx.Header")
	name:SetTextColor(c.text)
	name:SetText(item.GetName and item:GetName() or L(item.name))
	name:SetMaxWidth(math.max(name:GetMaxWidth(), ScrW() * 0.5))
	name:SizeToContents()

	local description = tooltip:AddRow("description")
	description:SetFont("efgx.Small")
	description:SetTextColor(c.text2)
	description:SetText(item:GetDescription() or "")
	description:SizeToContents()

	if (item.PopulateTooltip) then
		item:PopulateTooltip(tooltip)
	end

	hook.Run("PopulateItemTooltip", tooltip, item)
end

-- ─── Dibujo ──────────────────────────────────────────────────────────────────
function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive() or !ix.efgui) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	if (!menuOpen()) then
		drawStatus(client, character)
		drawStamina(client)
		drawWeapon(client)
		drawTargetTag(client)
	end

	drawNameBadge(character)
	drawAction()
end
