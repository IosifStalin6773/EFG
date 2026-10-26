local PLUGIN = PLUGIN
local health = ix.efg.health

surface.CreateFont("ixEFGHealthSmall", {font = "EFGX Label", extended = true, size = math.max(11, ScreenScale(5)), weight = 400})
surface.CreateFont("ixEFGHealthNum", {font = "EFGX Mono", extended = true, size = math.max(15, ScreenScale(7)), weight = 500})

-- Barra corporal de 7 segmentos (Pizarra): un medidor vertical por parte,
-- en el orden del cuerpo de arriba abajo. Sangrado = marca roja abajo,
-- fractura = barra amarilla arriba, parte destruida = celda tachada.
local labels = {head = "CAB", thorax = "TÓR", stomach = "EST", larm = "B.I", rarm = "B.D", lleg = "P.I", rleg = "P.D"}
local order = {"head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg"}

local function tokens()
	local c = ix.efgui and ix.efgui.color or {}

	return c.bg1 or Color(22, 28, 34), c.line or Color(46, 58, 70), c.text or Color(230, 226, 216),
		c.textDim or Color(104, 115, 125), c.ok or Color(127, 176, 105), c.warn or Color(232, 197, 71),
		c.crit or Color(224, 90, 71), c.info or Color(108, 195, 213)
end

local function partColor(fraction, ok, warn, crit)
	if (fraction > 0.6) then return ok end
	if (fraction > 0.3) then return warn end
	return crit
end

-- Dibuja la barra corporal con su esquina inferior izquierda en (left, bottom).
-- Devuelve el ancho y el alto para que efg_hud coloque lo demás encima.
function health.DrawBodyBar(left, bottom)
	local client = LocalPlayer()
	local data = client:GetNetVar("efgHP")

	if (!data or !client:Alive() or !client:GetCharacter()) then return 0, 0 end

	local bg1, line, text, textDim, ok, warn, crit, info = tokens()
	local byID = {}

	for i, part in ipairs(health.parts) do
		if (data[i]) then byID[part.id] = {part = part, hp = data[i][1], flags = data[i][2]} end
	end

	local segW, segH, gap = ScreenScale(9), ScreenScale(22), ScreenScale(1.5)
	local pad = ScreenScale(4)
	local w = pad * 2 + #order * segW + (#order - 1) * gap
	local h = pad * 2 + segH + ScreenScale(16)
	local x0, y0 = left, bottom - h
	local total = 0

	if (ix.efgui and ix.efgui.DrawPanel) then
		ix.efgui.DrawPanel(x0, y0, w, h, 225)
	else
		surface.SetDrawColor(bg1.r, bg1.g, bg1.b, 225); surface.DrawRect(x0, y0, w, h)
	end

	for n, id in ipairs(order) do
		local e = byID[id]

		if (e) then
			local x = x0 + pad + (n - 1) * (segW + gap)
			local y = y0 + pad + ScreenScale(9)
			local frac = math.Clamp(e.hp / e.part.max, 0, 1)
			total = total + e.hp

			surface.SetDrawColor(line); surface.DrawRect(x, y, segW, segH)

			if (e.hp <= 0) then
				surface.SetDrawColor(crit)
				surface.DrawLine(x, y, x + segW, y + segH)
				surface.DrawLine(x + segW, y, x, y + segH)
			else
				local fill = math.max(1, math.floor(segH * frac))
				surface.SetDrawColor(partColor(frac, ok, warn, crit))
				surface.DrawRect(x, y + segH - fill, segW, fill)
			end

			if (bit.band(e.flags, 3) != 0) then
				surface.SetDrawColor(crit)
				surface.DrawRect(x, y + segH + 1, segW, bit.band(e.flags, 2) != 0 and 3 or 2)
			end

			if (bit.band(e.flags, 4) != 0) then
				surface.SetDrawColor(warn)
				surface.DrawRect(x, y - 3, segW, 2)
			end

			draw.SimpleText(labels[id], "ixEFGHealthSmall", x + segW / 2, y0 + pad, textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end

	draw.SimpleText(("%d/%d"):format(math.Round(total), health.total), "ixEFGHealthNum",
		x0 + pad, y0 + h - pad, text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

	local painkiller = client:GetNetVar("efgPainkiller")

	if (painkiller and painkiller > CurTime()) then
		draw.SimpleText(("ANALG %ds"):format(math.ceil(painkiller - CurTime())), "ixEFGHealthSmall",
			x0 + w - pad, y0 + h - pad, info, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	return w, h
end

-- sin efg_hud la barra se dibuja sola en la esquina inferior izquierda
function PLUGIN:HUDPaint()
	if (ix.efg.hud) then return end
	health.DrawBodyBar(ScreenScale(8), ScrH() - ScreenScale(30))
end

-- Dolor: la imagen pierde color y tiembla un poco
function PLUGIN:RenderScreenspaceEffects()
	local client = LocalPlayer()

	if (client:GetNetVar("efgPain") and client:Alive()) then
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.03,
			["$pp_colour_contrast"] = 1.05,
			["$pp_colour_colour"] = 0.55,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
		DrawMotionBlur(0.2, 0.4, 0.01)
	end
end

-- ─── Pantalla de salud del TAB (pestaña SALUD de ix_invkey) ──────────────────
-- Silueta con las 7 partes, estados y lista de medicinas del inventario con
-- su botón de uso. Se rehace sola cuando cambian la salud o el inventario.

-- acciones que no son "usar" y no se muestran en la lista de medicinas
local skipActions = {drop = true, take = true, combine = true, Equip = true, EquipUn = true, EfgEquip = true, EfgUnequip = true}

local function healthData()
	local data = LocalPlayer():GetNetVar("efgHP")
	local out = {}

	for i, part in ipairs(health.parts) do
		local entry = data and data[i]
		out[part.id] = {part = part, hp = entry and entry[1] or part.max, flags = entry and entry[2] or 0}
	end

	return out
end

local function medItems()
	local character = LocalPlayer():GetCharacter()
	local list = {}
	if (!character) then return list end

	local inventories = {character:GetInventory()}
	local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(character)
	if (equipInv) then inventories[#inventories + 1] = equipInv end

	-- también lo que llevas en el chaleco táctico y la mochila
	-- copia superficial: table.Copy entra en los objetos middleclass y peta
	local roots = {}
	for i, inventory in ipairs(inventories) do roots[i] = inventory end

	for _, inventory in ipairs(roots) do
		for _, item in pairs(inventory:GetItems(true)) do
			local sub = item:GetData("id") and ix.item.inventories[item:GetData("id")]
			if (sub and sub != inventory) then inventories[#inventories + 1] = sub end
		end
	end

	local seen = {}

	for _, inventory in ipairs(inventories) do
		for _, item in pairs(inventory:GetItems(true)) do
			if (!seen[item.id] and item.category == "Medicamentos") then
				seen[item.id] = true
				list[#list + 1] = item
			end
		end
	end

	table.sort(list, function(a, b) return a:GetName() < b:GetName() end)
	return list
end

local function useAction(item)
	item.player = LocalPlayer()

	for key, fn in SortedPairs(item.functions or {}) do
		if (!skipActions[key] and !fn.isMulti and (!fn.OnCanRun or fn.OnCanRun(item) != false)) then
			item.player = nil
			return key, fn
		end
	end

	item.player = nil
end

local HEALTH = {}

function HEALTH:Init()
	self.selected = "thorax"
	self:Rebuild()
end

function HEALTH:PerformLayout(w, h)
	if (self._w != w or self._h != h) then
		self._w, self._h = w, h
		self:Rebuild()
	end
end

function HEALTH:Signature()
	local sig = tostring(LocalPlayer():GetNetVar("efgPain")) .. tostring(LocalPlayer():GetNetVar("efgPainkiller"))

	for _, e in pairs(healthData()) do sig = sig .. e.hp .. ":" .. e.flags .. ";" end
	for _, item in ipairs(medItems()) do sig = sig .. item.id .. "=" .. tostring(item:GetData("uses")) .. tostring(item:GetData("using")) .. ";" end

	return sig
end

function HEALTH:Think()
	if ((self._next or 0) > CurTime()) then return end
	self._next = CurTime() + 0.3

	local sig = self:Signature()
	if (sig != self._sig) then self:Rebuild() end
end

function HEALTH:Rebuild()
	self._sig = self:Signature()
	self:Clear()

	local UI = ix.efgui
	local c = UI.color
	local S = UI.Scale
	local w, h = self:GetSize()
	if (w < 50 or h < 50) then return end

	local data = healthData()
	local bodyW = math.min(w * 0.42, h * 0.5)
	local gap = S(16)

	-- ── silueta ──
	local body = self:Add("DPanel")
	body:SetPos(0, 0)
	body:SetSize(bodyW + S(40), h)
	body.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
		UI.DrawHeader(0, 0, pw, S(28), "ESTADO FÍSICO")

		local total = 0
		for _, e in pairs(data) do total = total + math.max(0, e.hp) end

		draw.SimpleText(("%d / %d"):format(math.Round(total), health.total), "efgx.NumBig", pw / 2, ph - S(16), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText("VIDA TOTAL", "efgx.Label", pw / 2, ph - S(52), c.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	local areaY, areaH = S(44), h - S(44) - S(80)
	local boxH = math.min(areaH, bodyW * 2.2)
	local boxW = boxH / 2.2
	local bx = (bodyW + S(40)) / 2 - boxW / 2

	local figure = body:Add("DButton")
	figure:SetText("")
	figure:SetPos(bx, areaY)
	figure:SetSize(boxW, boxH)
	figure.Paint = function(this, pw, ph)
		local parts = UI.BodyFromNet(LocalPlayer():GetNetVar("efgHP"))
		local mx, my = this:CursorPos()

		for id, p in pairs(parts) do
			p.selected = (self.selected == id) or (this:IsHovered() and UI.BodyPartHit(id, 0, 0, pw, ph, mx, my))
		end

		UI.DrawBody(0, 0, pw, ph, parts)

		for id, p in pairs(parts) do
			local cx, cy = UI.BodyPartCenter(id, 0, 0, pw, ph)
			draw.SimpleText(math.ceil(math.max(0, p.hp)), "efgx.Num", cx, cy, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	figure.DoClick = function(this)
		local mx, my = this:CursorPos()

		for id in pairs(UI.bodyShape) do
			if (UI.BodyPartHit(id, 0, 0, this:GetWide(), this:GetTall(), mx, my)) then
				self.selected = id
				surface.PlaySound("ui/buttonclickrelease.wav")
				self:Rebuild()
				return
			end
		end
	end

	-- ── detalle de la parte y estados ──
	local rx = bodyW + S(40) + gap
	local rw = w - rx
	local infoH = S(200)
	local info = self:Add("DPanel")
	info:SetPos(rx, 0)
	info:SetSize(rw, infoH)

	local sel = data[self.selected] or data.thorax
	local lines = {}

	for _, id in ipairs({"head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg"}) do
		local e = data[id]
		local states = {}
		if (e.hp <= 0) then states[#states + 1] = {"DESTRUIDA", c.crit} end
		if (bit.band(e.flags, 2) != 0) then states[#states + 1] = {"SANGRADO GRAVE", c.crit}
		elseif (bit.band(e.flags, 1) != 0) then states[#states + 1] = {"SANGRADO LEVE", c.crit} end
		if (bit.band(e.flags, 4) != 0) then states[#states + 1] = {"FRACTURA", c.warn} end

		for _, st in ipairs(states) do lines[#lines + 1] = {e.part.name, st[1], st[2]} end
	end

	local painkiller = LocalPlayer():GetNetVar("efgPainkiller")
	if (painkiller and painkiller > CurTime()) then
		lines[#lines + 1] = {"Analgésico", ("%ds restantes"):format(math.ceil(painkiller - CurTime())), c.info}
	elseif (LocalPlayer():GetNetVar("efgPain")) then
		lines[#lines + 1] = {"Dolor", "visión borrosa", c.warn}
	end

	info.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
		UI.DrawHeader(0, 0, pw, S(28), string.upper(sel.part.name), nil, ("%d / %d"):format(math.ceil(math.max(0, sel.hp)), sel.part.max))
		UI.DrawMeter(S(14), S(40), pw - S(28), S(8), math.Clamp(sel.hp / sel.part.max, 0, 1), 10)

		local y = S(60)
		if (#lines == 0) then
			draw.SimpleText("Sin heridas activas.", "efgx.Body", S(14), y, c.text2)
		end

		for i, line in ipairs(lines) do
			local ly = y + (i - 1) * S(20)
			if (ly > ph - S(20)) then break end
			draw.SimpleText(line[1], "efgx.Body", S(14), ly, c.text)
			draw.SimpleText(line[2], "efgx.Label", pw - S(14), ly + S(3), line[3], TEXT_ALIGN_RIGHT)
		end
	end

	-- ── medicinas ──
	local medsY = infoH + gap
	local meds = self:Add("DPanel")
	meds:SetPos(rx, medsY)
	meds:SetSize(rw, h - medsY)
	meds.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
		UI.DrawHeader(0, 0, pw, S(28), "MEDICINAS EN EL INVENTARIO")
	end

	local scroll = meds:Add("DScrollPanel")
	scroll:SetPos(S(8), S(36))
	scroll:SetSize(rw - S(16), h - medsY - S(44))

	local items = medItems()

	if (#items == 0) then
		local empty = scroll:Add("DLabel")
		empty:Dock(TOP)
		empty:SetFont("efgx.Body")
		empty:SetTextColor(c.text2)
		empty:SetText("No llevas medicinas. Las que guardes en bolsillos, chaleco o mochila aparecerán aquí.")
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
	end

	for _, item in ipairs(items) do
		local row = scroll:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, S(4))
		row:SetTall(S(44))
		row.Paint = function(this, pw, ph)
			UI.DrawCell(0, 0, ph, ph, "normal", true)
			UI.DrawRarity(0, 0, ph, ph, item.rarity)
			draw.SimpleText(item:GetName(), "efgx.Body", ph + S(10), S(6), c.text)

			local uses = item.GetUses and item:GetUses()
			local detail = (uses and item.maxUses and item.maxUses > 1) and ("%d / %d"):format(uses, item.maxUses) or (item.description or "")
			draw.SimpleText(detail, "efgx.Label", ph + S(10), S(26), c.textDim)
		end

		local icon = row:Add("SpawnIcon")
		icon:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")
		icon:SetPos(2, 2)
		icon:SetSize(S(40), S(40))
		icon:SetMouseInputEnabled(false)

		local key, fn = useAction(item)
		local btn = row:Add("DButton")
		btn:Dock(RIGHT)
		btn:SetWide(S(110))
		btn:SetText(key and (fn.name or key) or "—")
		UI.StyleButton(btn, "efgx.Header", key and "primary" or "ghost")
		btn:SetEnabled(key != nil and !item:GetData("using"))
		btn.DoClick = function()
			if (!key) then return end
			item.player = LocalPlayer()
			local send = true
			if (fn.OnClick) then send = fn.OnClick(item) end
			item.player = nil

			if (send != false) then
				net.Start("ixInventoryAction")
					net.WriteString(key)
					net.WriteUInt(item.id, 32)
					net.WriteUInt(item.invID or 0, 32)
					net.WriteTable({})
				net.SendToServer()
			end

			surface.PlaySound("items/medshot4.wav")
		end
	end
end

vgui.Register("efgxHealth", HEALTH, "Panel")
