-- HUD de EFG. El estado físico, la postura, el arma, los avisos y el cursor
-- vienen del port del addon EFT HUD (cl_tarkov.lua); aquí quedan las
-- necesidades, la barra de acción, la placa de nombre y las etiquetas.
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

-- Necesidades en una columna a la izquierda, por encima de la postura.
local function drawNeeds(client, character)
	local c = UI().color
	local left, bottom = S(20), ScrH() - S(262)

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
	local x, y = ScrW() / 2 - w / 2, S(16)

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
		hud.DrawCondition(client)
		hud.DrawStance(client)
		drawNeeds(client, character)
		hud.DrawWeapon(client)
		hud.DrawCursor(client)
		drawTargetTag(client)
	end

	hud.DrawNotice()

	drawNameBadge(character)
	drawAction()
end
