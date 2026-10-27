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


-- ─── Aspecto de la pantalla de salud de EFT ──────────────────────────────────
-- Siluetas e iconos de EFT en content/materials/efg/health (512x1024, cada
-- parte en su sitio dentro del mismo marco), teñidos según la vida.

local mats = {}

local function M(name)
	local mat = mats[name]

	if (!mat) then
		mat = Material("efg/health/" .. name .. ".png", "smooth mips")
		mats[name] = mat
	end

	return mat
end

-- de verde a rojo, como el modo policromo de EFT
local stops = {
	{0.0, Color(165, 28, 24)}, {0.3, Color(205, 50, 30)}, {0.6, Color(225, 190, 50)}, {1.0, Color(70, 230, 90)}
}

local function hpColor(frac)
	frac = math.Clamp(frac, 0, 1)

	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]

		if (frac <= b[1]) then
			local k = (frac - a[1]) / (b[1] - a[1])
			return Lerp(k, a[2].r, b[2].r), Lerp(k, a[2].g, b[2].g), Lerp(k, a[2].b, b[2].b)
		end
	end

	local c = stops[#stops][2]
	return c.r, c.g, c.b
end

-- dónde está cada parte dentro del marco de la silueta (0..1 del ancho y alto)
local layout = {
	head    = {cx = 0.514, cy = 0.109, x0 = 0.419, x1 = 0.609, y0 = 0.053, y1 = 0.165},
	thorax  = {cx = 0.504, cy = 0.264, x0 = 0.330, x1 = 0.678, y0 = 0.169, y1 = 0.359},
	stomach = {cx = 0.477, cy = 0.412, x0 = 0.319, x1 = 0.634, y0 = 0.345, y1 = 0.478},
	rarm    = {cx = 0.243, cy = 0.365, x0 = 0.132, x1 = 0.355, y0 = 0.202, y1 = 0.529},
	larm    = {cx = 0.748, cy = 0.357, x0 = 0.628, x1 = 0.868, y0 = 0.191, y1 = 0.522},
	rleg    = {cx = 0.340, cy = 0.686, x0 = 0.212, x1 = 0.468, y0 = 0.456, y1 = 0.915},
	lleg    = {cx = 0.617, cy = 0.705, x0 = 0.485, x1 = 0.750, y0 = 0.463, y1 = 0.947}
}

local alphaWorks -- nil hasta probar si IMaterial:GetColor lee el alfa de los PNG
local partOrder = {"head", "thorax", "stomach", "rarm", "larm", "rleg", "lleg"}

-- alto / ancho de cada icono de estado (los de EFT miden 24x22; buff y debuff 19x18)
local iconAspect = {icon_buff = 18 / 19, icon_debuff = 18 / 19, icon_poison = 1}

local function drawIcon(name, x, y, size)
	local ih = size * (iconAspect[name] or 22 / 24)
	surface.SetMaterial(M(name))
	surface.DrawTexturedRect(x, y + (size - ih) / 2, size, ih)
end

local fontScale

local function createFonts()
	local s = ix.efgui.Scale
	fontScale = ScrH()

	surface.CreateFont("efgHealth.Label", {font = "Tektur Medium", extended = true, size = s(19), weight = 500, antialias = true})
	surface.CreateFont("efgHealth.Value", {font = "Tektur Medium", extended = true, size = s(15), weight = 500, antialias = true})
	surface.CreateFont("efgHealth.Hint", {font = "Tektur Medium", extended = true, size = s(15), weight = 500, antialias = true})
	surface.CreateFont("efgHealth.Big", {font = "Big Shoulders", extended = true, size = s(60), weight = 700, antialias = true})
	surface.CreateFont("efgHealth.BigMax", {font = "Big Shoulders", extended = true, size = s(31), weight = 700, antialias = true})
	surface.CreateFont("efgHealth.Cell", {font = "Tektur Medium", extended = true, size = s(12), weight = 500, antialias = true})
end

local white, shadow, redText = Color(232, 232, 228), Color(0, 0, 0, 220), Color(225, 70, 60)
local tabColor, barBack, barEdge = Color(44, 46, 48), Color(10, 10, 10), Color(72, 74, 76)
local hintColor = Color(150, 150, 145)

-- a qué partes puede ir cada medicina (lo mismo que comprueba el servidor)
local function canTreat(item, e)
	if (!item) then return false end
	local kind = item.useSound

	if (kind == "pills") then return true end
	if (kind == "esmarch") then return bit.band(e.flags, 2) != 0 end
	if (kind == "splint") then return bit.band(e.flags, 4) != 0 end
	if (kind == "surgery") then return !e.part.vital and e.hp <= 0 end
	if (e.hp <= 0) then return false end

	local bleed = bit.band(e.flags, 3) != 0 and (item.stopsBleed == "heavy" or (item.stopsBleed == "light" and bit.band(e.flags, 1) != 0))
	return e.hp < e.part.max or bleed
end

-- ─── Pantalla de salud del TAB (pestaña SALUD de ix_invkey) ──────────────────
-- Como la de EFT: la silueta en el centro con la ficha de cada parte a su
-- alrededor, la vida total abajo y las medicinas a la derecha. Se arrastra una
-- medicina sobre una parte del cuerpo para usarla en ella (o se hace clic en
-- la medicina y luego en la parte; doble clic la usa donde haga más falta).


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
	if (fontScale != ScrH()) then createFonts() end

	self.shown = {} -- vida mostrada (se anima hacia la real)

	surface.PlaySound("efg/health/ui_open.wav")
	self:Rebuild()
end

function HEALTH:OnRemove()
	surface.PlaySound("efg/health/ui_close.wav")
end

function HEALTH:PerformLayout(w, h)
	if (self._w != w or self._h != h) then
		self._w, self._h = w, h
		self:Rebuild()
	end
end

function HEALTH:Signature()
	local sig = ""
	for _, item in ipairs(medItems()) do sig = sig .. item.id .. "=" .. tostring((item:GetData("uses"))) .. tostring((item:GetData("using"))) .. ";" end
	return sig
end

-- marco de la silueta: alto = 2 x ancho, centrada en la zona libre de la izquierda
function HEALTH:FigureRect()
	local S = ix.efgui.Scale
	local w, h = self:GetSize()
	local areaW = w - self.medsW - S(24)
	local fh = math.min(h - S(120), areaW * 1.1)
	local fw = fh / 2

	return areaW / 2 - fw / 2, S(10), fw, fh
end

-- parte del cuerpo bajo el punto (x, y) del panel: primero por el alfa de las
-- texturas de EFT y, si no se puede leer, por el rectángulo de cada parte
function HEALTH:PartAt(x, y)
	local fx, fy, fw, fh = self:FigureRect()
	local u, v = (x - fx) / fw, (y - fy) / fh
	if (u < 0 or u > 1 or v < 0 or v > 1) then return end

	if (alphaWorks == nil) then
		-- la esquina de la textura de la cabeza es transparente: si GetColor no
		-- lo dice así, no sirve para esta prueba y se usan los rectángulos
		local ok, col = pcall(function() return M("head"):GetColor(0, 0) end)
		alphaWorks = ok and istable(col) and isnumber(col.a) and col.a < 10
	end

	if (alphaWorks) then
		for _, id in ipairs(partOrder) do
			local mat = M(id)
			local col = mat:GetColor(math.floor(u * (mat:Width() - 1)), math.floor(v * (mat:Height() - 1)))

			if (col.a > 60) then return id end
		end
	end

	local best, bestDist

	for _, id in ipairs(partOrder) do
		local l = layout[id]

		if (u >= l.x0 and u <= l.x1 and v >= l.y0 and v <= l.y1) then
			local d = (u - l.cx) ^ 2 + (v - l.cy) ^ 2
			if (!bestDist or d < bestDist) then best, bestDist = id, d end
		end
	end

	return best
end

function HEALTH:Apply(item, partID)
	local key = useAction(item)
	if (!key or item:GetData("using")) then return end

	net.Start("ixInventoryAction")
		net.WriteString(key)
		net.WriteUInt(item.id, 32)
		net.WriteUInt(item.invID or 0, 32)
		net.WriteTable(partID and {part = partID} or {})
	net.SendToServer()

	self.armed = nil
end

function HEALTH:StartDrag(item, cell)
	self.drag = {item = item, cell = cell, x = gui.MouseX(), y = gui.MouseY(), moved = false}
end

function HEALTH:Think()
	local client = LocalPlayer()
	local data = healthData()
	local dt = FrameTime()

	for id, e in pairs(data) do
		local target = math.max(0, e.hp)
		local cur = self.shown[id] or target
		self.shown[id] = math.Approach(cur, target, math.max(math.abs(target - cur) * dt * 6, dt * 10))
	end

	self.data = data

	-- arrastrar una medicina
	local drag = self.drag

	if (drag) then
		if (!drag.moved and (math.abs(gui.MouseX() - drag.x) > 4 or math.abs(gui.MouseY() - drag.y) > 4)) then
			drag.moved = true
			self.armed = nil

			local ghost = self:Add("SpawnIcon")
			ghost:SetModel(drag.item:GetModel() or "models/props_junk/popcan01a.mdl")
			ghost:SetSize(ix.efgui.Scale(56), ix.efgui.Scale(56))
			ghost:SetMouseInputEnabled(false)
			ghost:SetAlpha(220)
			drag.ghost = ghost
		end

		if (IsValid(drag.ghost)) then
			local x, y = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
			drag.ghost:SetPos(x - drag.ghost:GetWide() / 2, y - drag.ghost:GetTall() / 2)
			drag.ghost:MoveToFront()
		end

		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self.drag = nil
			if (IsValid(drag.ghost)) then drag.ghost:Remove() end

			if (drag.moved) then
				local partID = self:PartAt(self:ScreenToLocal(gui.MouseX(), gui.MouseY()))
				if (partID) then self:Apply(drag.item, partID) end
			else
				-- clic sin arrastrar: la medicina queda elegida hasta hacer clic en una parte
				self.armed = (self.armed != drag.item) and drag.item or nil
			end
		end
	end

	if (self.armed and (input.IsMouseDown(MOUSE_RIGHT) or !ix.item.instances[self.armed.id])) then
		self.armed = nil
	end

	if ((self._next or 0) > CurTime()) then return end
	self._next = CurTime() + 0.3

	if (self:Signature() != self._sig) then self:Rebuild() end
end

function HEALTH:OnMousePressed(code)
	if (code != MOUSE_LEFT or !self.armed) then return end

	local partID = self:PartAt(self:CursorPos())

	if (partID) then
		self:Apply(self.armed, partID)
	else
		self.armed = nil
	end
end

-- ficha de una parte: pestaña con el nombre, barra de vida y estados debajo
function HEALTH:DrawPartPlate(id, x, y, pw)
	local S = ix.efgui.Scale
	local e = self.data[id]
	local th, bh, cut = S(28), S(19), S(20)

	draw.NoTexture()
	surface.SetDrawColor(tabColor.r, tabColor.g, tabColor.b, 235)
	surface.DrawPoly({{x = x, y = y}, {x = x + pw - cut, y = y}, {x = x + pw, y = y + th}, {x = x, y = y + th}})
	surface.SetDrawColor(95, 97, 99, 255)
	surface.DrawRect(x, y + th - 1, pw, 1)
	draw.SimpleText(string.upper(e.part.name), "efgHealth.Label", x + S(8), y + th / 2, white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local by = y + th + S(3)
	local shown = self.shown[id] or e.hp
	local frac = math.Clamp(shown / e.part.max, 0, 1)

	surface.SetDrawColor(barBack.r, barBack.g, barBack.b, 240)
	surface.DrawRect(x, by, pw, bh)

	if (shown > 0.05) then
		local r, g, b = hpColor(frac)
		surface.SetDrawColor(r, g, b, 255)
		surface.DrawRect(x + 2, by + 2, math.max(0, (pw - 4) * frac), bh - 4)
	end

	surface.SetDrawColor(barEdge)
	surface.DrawOutlinedRect(x, by, pw, bh)

	local hp = math.max(0, math.ceil(e.hp - 0.05))
	local text = hp .. "/" .. e.part.max
	local textCol, shadowCol = e.hp > 0.05 and white or redText, shadow

	if (e.hp > 0.05 and frac > 0.5) then
		local r, g, b = hpColor(frac)
		if (0.299 * r + 0.587 * g + 0.114 * b > 175) then textCol, shadowCol = Color(22, 22, 22), Color(255, 255, 255, 90) end
	end

	draw.SimpleText(text, "efgHealth.Value", x + pw / 2 + 1, by + bh / 2 + 1, shadowCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "efgHealth.Value", x + pw / 2, by + bh / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- estados: los de la parte y, bajo la cabeza, los de todo el cuerpo (como en EFT)
	local list = {}
	if (e.hp <= 0) then list[#list + 1] = {"icon_debuff", "Destruida"} end
	if (bit.band(e.flags, 2) != 0) then list[#list + 1] = {"icon_heavybleed", "Sangrado grave"} end
	if (bit.band(e.flags, 1) != 0) then list[#list + 1] = {"icon_bleed", "Sangrado leve"} end
	if (bit.band(e.flags, 4) != 0) then list[#list + 1] = {"icon_fracture", "Fractura"} end

	if (id == "head") then
		for _, st in ipairs(self.bodyStatus or {}) do list[#list + 1] = st end
	end

	local size = S(22)
	local iy = by + bh + S(5)

	for _, st in ipairs(list) do
		surface.SetDrawColor(255, 255, 255, 255)
		drawIcon(st[1], x, iy, size)
		draw.SimpleText(st[2] .. (st[3] and ("  " .. st[3]) or ""), "efgHealth.Value", x + size + S(6), iy + size / 2, st[4] or white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		iy = iy + size + S(3)
	end
end

-- estados de todo el cuerpo: dolor, analgésico, comida y bebida
function HEALTH:BodyStatus()
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local out = {}
	local now = CurTime()

	local painkiller = client:GetNetVar("efgPainkiller")
	if (painkiller and painkiller > now) then out[#out + 1] = {"icon_painkiller", "Analgésico", math.ceil(painkiller - now) .. "s"} end
	if (client:GetNetVar("efgPain")) then out[#out + 1] = {"icon_pain", "Dolor"} end

	local nutrido = client:GetNetVar("nutridoEnd", 0)
	if (nutrido > now) then out[#out + 1] = {"icon_buff", "Bien alimentado", math.ceil(nutrido - now) .. "s", Color(150, 215, 90)} end

	local intox = client:GetNetVar("intoxicadoEnd", 0)
	if (intox > now) then out[#out + 1] = {"icon_poison", "Intoxicación", math.ceil(intox - now) .. "s", Color(225, 95, 80)} end

	if (character) then
		local energy = (character.GetSatiety and character:GetSatiety()) or client:GetLocalVar("satiety", 100) or 100
		local water = (character.GetSaturation and character:GetSaturation()) or client:GetLocalVar("saturation", 100) or 100

		if (energy <= 0) then out[#out + 1] = {"icon_debuff", "Agotamiento", nil, Color(225, 95, 80)} end
		if (water <= 0) then out[#out + 1] = {"icon_debuff", "Deshidratación", nil, Color(225, 95, 80)} end
	end

	return out
end

function HEALTH:Paint(w, h)
	if (!self.data) then return end

	local S = ix.efgui.Scale
	local fx, fy, fw, fh = self:FigureRect()
	local mx, my = self:CursorPos()
	local holding = (self.drag and self.drag.moved and self.drag.item) or self.armed
	local hovered = self:IsHovered() or (self.drag and self.drag.moved)
	local hoverPart = hovered and holding and self:PartAt(mx, my)

	self.bodyStatus = self:BodyStatus()

	surface.SetDrawColor(8, 9, 10, 215)
	surface.DrawRect(0, 0, w, h)

	-- silueta: cada parte de EFT teñida por su vida; destruida = casi negra
	for _, id in ipairs(partOrder) do
		local e = self.data[id]
		local shown = self.shown[id] or e.hp

		if (shown <= 0.05) then
			surface.SetDrawColor(30, 30, 30, 255)
		else
			local r, g, b = hpColor(shown / e.part.max)
			surface.SetDrawColor(r, g, b, 255)
		end

		surface.SetMaterial(M(id))
		surface.DrawTexturedRect(fx, fy, fw, fh)
	end

	-- con una medicina en la mano: brillan las partes que puede tratar
	if (holding) then
		local pulse = 40 + math.abs(math.sin(CurTime() * 4)) * 60

		for _, id in ipairs(partOrder) do
			if (canTreat(holding, self.data[id])) then
				surface.SetDrawColor(255, 255, 255, id == hoverPart and 150 or pulse)
				surface.SetMaterial(M(id))
				surface.DrawTexturedRect(fx, fy, fw, fh)
			end
		end
	end

	-- fichas alrededor de la silueta
	local pw = S(190)
	local function X(nx) return fx + nx * fw end
	local function Y(ny) return fy + ny * fh end
	local L = layout
	local pos = {
		head    = {X(L.head.x1) + S(24),      Y(L.head.y0)},
		thorax  = {X(L.thorax.cx) - pw / 2,   Y(L.thorax.cy) - S(40)},
		stomach = {X(L.stomach.cx) - pw / 2,  Y(L.stomach.cy) - S(26)},
		rarm    = {X(L.rarm.x0) - pw - S(20), Y(L.rarm.y0 + (L.rarm.y1 - L.rarm.y0) * 0.3)},
		larm    = {X(L.larm.x1) + S(20),      Y(L.larm.y0 + (L.larm.y1 - L.larm.y0) * 0.3)},
		rleg    = {X(L.rleg.x0) - pw - S(10), Y(L.rleg.y0 + (L.rleg.y1 - L.rleg.y0) * 0.35)},
		lleg    = {X(L.lleg.x1) + S(10),      Y(L.lleg.y0 + (L.lleg.y1 - L.lleg.y0) * 0.35)}
	}

	for _, id in ipairs(partOrder) do self:DrawPartPlate(id, pos[id][1], pos[id][2], pw) end

	-- vida total abajo, con la cruz de EFT
	local total = 0
	for _, e in pairs(self.data) do total = total + math.max(0, e.hp) end

	local r, g, b = hpColor(total / health.total)
	local num, rest = tostring(math.ceil(total - 0.05)), "/" .. health.total
	surface.SetFont("efgHealth.Big")
	local nw, nh = surface.GetTextSize(num)
	surface.SetFont("efgHealth.BigMax")
	local rw = surface.GetTextSize(rest)
	local cs = S(38)
	local areaW = w - self.medsW - S(24)
	local tx, ty = areaW / 2 - (cs + S(12) + nw + rw) / 2, h - nh - S(14)

	surface.SetDrawColor(r, g, b, 255)
	surface.SetMaterial(M("icon_cross"))
	surface.DrawTexturedRect(tx, ty + nh / 2 - cs / 2, cs, cs)
	draw.SimpleText(num, "efgHealth.Big", tx + cs + S(12), ty, Color(r, g, b))
	draw.SimpleText(rest, "efgHealth.BigMax", tx + cs + S(12) + nw + S(2), ty + nh * 0.42, hintColor)

	-- energía e hidratación a los lados, como en EFT
	local character = LocalPlayer():GetCharacter()

	if (character) then
		local energy = (character.GetSatiety and character:GetSatiety()) or LocalPlayer():GetLocalVar("satiety", 100) or 100
		local water = (character.GetSaturation and character:GetSaturation()) or LocalPlayer():GetLocalVar("saturation", 100) or 100

		draw.SimpleText("ENERGÍA", "efgHealth.Hint", S(24), h - S(56), hintColor)
		draw.SimpleText(math.floor(energy) .. "/100", "efgHealth.BigMax", S(24), h - S(38), energy < 25 and redText or Color(225, 190, 50))
		draw.SimpleText("HIDRATACIÓN", "efgHealth.Hint", S(170), h - S(56), hintColor)
		draw.SimpleText(math.floor(water) .. "/100", "efgHealth.BigMax", S(170), h - S(38), water < 25 and redText or Color(108, 170, 215))
	end

	local hint = holding and "Suelta o haz clic sobre una parte del cuerpo. Clic derecho para cancelar."
		or "Arrastra una medicina sobre una parte del cuerpo para usarla. Doble clic: donde más falta haga."
	draw.SimpleText(hint, "efgHealth.Hint", areaW - S(12), h - S(14), hintColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

function HEALTH:Rebuild()
	self._sig = self:Signature()
	self:Clear()
	self.drag = nil

	local UI = ix.efgui
	local c = UI.color
	local S = UI.Scale
	local w, h = self:GetSize()
	self.medsW = S(64) * 4 + S(4) * 3 + S(28)
	if (w < 50 or h < 50) then return end

	-- ── medicinas que llevas (bolsillos, chaleco, mochila) ──
	local meds = self:Add("DPanel")
	meds:SetPos(w - self.medsW, 0)
	meds:SetSize(self.medsW, h)
	meds.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
		UI.DrawHeader(0, 0, pw, S(28), "MEDICINAS")
	end

	local scroll = meds:Add("DScrollPanel")
	scroll:SetPos(S(10), S(38))
	scroll:SetSize(self.medsW - S(14), h - S(46))

	local items = medItems()

	if (#items == 0) then
		local empty = scroll:Add("DLabel")
		empty:Dock(TOP)
		empty:SetFont("efgx.Body")
		empty:SetTextColor(c.text2)
		empty:SetText("No llevas medicinas. Las que guardes en bolsillos, chaleco o mochila aparecerán aquí.")
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
		return
	end

	local grid = scroll:Add("DIconLayout")
	grid:Dock(TOP)
	grid:SetSpaceX(S(4))
	grid:SetSpaceY(S(4))

	local cell = S(64)

	for _, item in ipairs(items) do
		local iw, ih = math.min(item.width or 1, 4), math.min(item.height or 1, 3)
		local btn = grid:Add("DButton")
		btn:SetText("")
		btn:SetSize(cell * iw + S(4) * (iw - 1), cell * ih + S(4) * (ih - 1))
		btn:SetTooltip(item:GetName() .. "\n" .. (item.description or ""))

		local icon = btn:Add("SpawnIcon")
		icon:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")
		icon:Dock(FILL)
		icon:DockMargin(S(4), S(12), S(4), S(4))
		icon:SetMouseInputEnabled(false)

		btn.Paint = function(this, pw, ph)
			local active = self.armed == item or (self.drag and self.drag.item == item)
			UI.DrawCell(0, 0, pw, ph, active and "selected" or (this:IsHovered() and "hover" or "normal"), true)
			UI.DrawRarity(0, 0, pw, ph, item.rarity)
		end
		btn.PaintOver = function(this, pw, ph)
			draw.SimpleText(item:GetName(), "efgHealth.Cell", pw - S(4), S(2), c.text, TEXT_ALIGN_RIGHT)

			local uses = item.GetUses and item:GetUses()
			if (uses and item.maxUses and item.maxUses > 1) then
				draw.SimpleText(uses .. "/" .. item.maxUses, "efgHealth.Cell", pw - S(4), ph - S(2), Color(150, 215, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			end

			if (item:GetData("using")) then
				surface.SetDrawColor(0, 0, 0, 160)
				surface.DrawRect(0, 0, pw, ph)
				draw.SimpleText("EN USO", "efgHealth.Cell", pw / 2, ph / 2, c.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
		btn.OnMousePressed = function(this, code)
			if (code == MOUSE_LEFT) then
				-- doble clic: usarla donde más falta haga
				if (this.lastClick and RealTime() - this.lastClick < 0.3) then
					this.lastClick = nil
					self.drag = nil
					self.armed = nil
					self:Apply(item)
					return
				end

				this.lastClick = RealTime()
				self:StartDrag(item, this)
			elseif (code == MOUSE_RIGHT) then
				local menu = DermaMenu()
				menu:AddOption("Usar donde más falta haga", function() self:Apply(item) end):SetIcon("icon16/heart.png")

				local sub = menu:AddSubMenu("Usar en...")
				for _, part in ipairs(health.parts) do
					sub:AddOption(part.name, function() self:Apply(item, part.id) end)
				end

				menu:Open()
			end
		end
	end
end

vgui.Register("efgxHealth", HEALTH, "Panel")
