-- Página de inventario de EFT en VGUI (efgxInventoryEFT): equipo a la
-- izquierda, chaleco/bolsillos/mochila/contenedor seguro en el centro, alijo
-- con scroll a la derecha y acceso rápido abajo. Arrastre propio con encaje a
-- la rejilla, R para girar mientras se arrastra y clic derecho para el menú.
local G = ix.efg.invgrid
local S = G.S

local GEAR_LABELS = {
	headset = "AURICULARES", helmet = "CASCO", facecover = "CUBRECARAS", armband = "BRAZALETE",
	armor = "CHALECO ANTIBALAS", eyewear = "GAFAS", rig = "CHALECO TÁCTICO", backpack = "MOCHILA",
	secure = "CONTENEDOR SEGURO",
}

local WEAPON_LABELS = {primary = "EN BANDOLERA", primary2 = "A LA ESPALDA", secondary = "PISTOLERA", melee = "VAINA"}

local HP_COLOR, WATER_COLOR, ENERGY_COLOR = Color(143, 179, 74), Color(108, 170, 215), Color(225, 190, 50)

local function H() return ix.efg.invhtml end

local function innerInv(item)
	local id = item and item:GetData("id")
	local inv = id and ix.item.inventories[id]

	return (inv and inv.slots) and inv or nil
end

local function weaponSlotOf(item)
	local cat = item.weaponCategory or "primary"
	return (cat == "secondary" or cat == "melee") and cat or "primary"
end

local PAGE = {}

function PAGE:Init()
	G.Fonts()
	ix.gui.efgInvHTML = self -- recibe el alijo (ixEFGStashTabReady) igual que la página HTML

	self.drops = {}

	local client = LocalPlayer()

	if (!(client.InRaid and client:InRaid())) then
		net.Start("ixEFGStashTab")
			net.WriteBool(true)
		net.SendToServer()
		self.stashRequested = true
	end
end

function PAGE:SetEmbedded(embedded)
	self.embedded = embedded
end

function PAGE:SetStash(invID)
	self.stashID = invID
	self.sig = nil
end

function PAGE:RegisterDrop(panel)
	self.drops[#self.drops + 1] = panel
end

function PAGE:IsDragging()
	return self.drag != nil
end

-- ─── Construcción ────────────────────────────────────────────────────────────
function PAGE:PerformLayout(w, h)
	if (self.builtW != w or self.builtH != h) then self.sig = nil end
end

function PAGE:Rebuild()
	local character = LocalPlayer():GetCharacter()
	if (!character or !H()) then return end

	local w, h = self:GetSize()
	if (w < 200 or h < 200) then return end

	-- conservar el scroll al reconstruir
	local stashScroll = IsValid(self.stashScroll) and self.stashScroll:GetVBar():GetScroll() or 0
	local midScroll = IsValid(self.midScroll) and self.midScroll:GetVBar():GetScroll() or 0

	self:Clear()
	self.drops = {}
	self.stashMsg = nil
	self.builtW, self.builtH = w, h
	self.sig = H().Signature(self)

	local margin, gap = S(16), S(12)
	local quickH = S(70)
	local leftW = math.floor(w * 0.30)
	local midW = math.floor(w * 0.29)
	local midX = margin + leftW + gap
	local stashX = midX + midW + gap
	local stashW = w - stashX - margin
	local bottom = h - quickH - S(8)

	local equip = H().GetEquipped(character)
	local weapons = H().GetWeapons(character)
	local stash = self.stashID and ix.item.inventories[self.stashID]

	-- tamaño de casilla: el alijo de 10 columnas manda; el centro no puede desbordar
	local stashCols = stash and select(1, stash:GetSize()) or 10
	local cell = math.min(S(56), math.floor((stashW - S(14)) / stashCols))
	local box = math.min(math.floor((leftW - gap * 2) / 3), S(124))
	local midBox = math.min(box, math.floor(midW * 0.3))
	local widest = 1

	for _, kind in ipairs({"rig", "backpack", "secure"}) do
		local inv = innerInv(equip[kind])
		if (inv) then widest = math.max(widest, (inv:GetSize())) end
	end

	widest = math.max(widest, (character:GetInventory():GetSize()))
	local midCell = math.min(cell, math.floor((midW - midBox - S(22)) / widest))
	self.cell = cell

	-- ── izquierda: equipo ──
	local function gearSlot(kind, x, y, sw, sh)
		local slot = self:Add("efgxInvSlot")
		slot:SetPos(x, y)
		slot:SetSize(sw, sh)
		slot:Setup(self, "gear", kind, GEAR_LABELS[kind], equip[kind])
		return slot
	end

	local function weaponSlot(key, x, y, sw, sh)
		local slot = self:Add("efgxInvSlot")
		slot:SetPos(x, y)
		slot:SetSize(sw, sh)
		slot:Setup(self, "weapon", key, WEAPON_LABELS[key], weapons[key])
		return slot
	end

	local x1, x2, x3 = margin, margin + box + gap, margin + (box + gap) * 2
	local y = margin
	local rowH = box + S(16)

	gearSlot("headset", x1, y, box, rowH)
	gearSlot("helmet", x2, y, box, rowH)
	gearSlot("facecover", x3, y, box, rowH)
	y = y + rowH + gap

	gearSlot("armband", x1, y, box, math.floor(box * 0.6) + S(16))
	gearSlot("armor", x2, y, box, math.floor(box * 1.25) + S(16))
	gearSlot("eyewear", x3, y, box, math.floor(box * 0.6) + S(16))
	y = y + math.floor(box * 1.25) + S(16) + gap

	local wideW = box * 2 + gap
	local weaponH = math.floor(box * 0.9) + S(16)
	weaponSlot("primary", x1, y, wideW, weaponH)
	weaponSlot("secondary", x3, y, box, weaponH)
	y = y + weaponH + gap
	weaponSlot("primary2", x1, y, wideW, weaponH)
	weaponSlot("melee", x3, y, box, weaponH)

	self.statsY = math.min(y + weaponH + gap, bottom - S(40))
	self.statsX = margin

	-- ── centro: táctico (scroll propio) ──
	local mid = self:Add("DScrollPanel")
	mid:SetPos(midX, margin)
	mid:SetSize(midW, bottom - margin)
	self:StyleScroll(mid)
	self.midScroll = mid

	local my = 0

	local function header(parent, text, yy, ww)
		local bar = parent:Add("DPanel")
		bar:SetPos(0, yy)
		bar:SetSize(ww, S(20))
		bar.Paint = function(_, bw, bh)
			surface.SetDrawColor(G.color.header)
			surface.DrawRect(0, 0, bw, bh)
			draw.SimpleText(text, "efgInv.Header", S(6), bh / 2, G.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		return yy + S(22)
	end

	local function container(kind, title)
		my = header(mid, title, my, midW - S(12))

		local slot = mid:Add("efgxInvSlot")
		slot:SetPos(0, my)
		slot:SetSize(midBox, midBox)
		slot:Setup(self, "gear", kind, nil, equip[kind])

		local inv = innerInv(equip[kind])
		local blockH = midBox

		if (inv) then
			local grid = mid:Add("efgxInvGrid")
			grid:SetPos(midBox + S(8), my)
			grid:Setup(inv, midCell, self)
			blockH = math.max(blockH, grid:GetTall())
		end

		my = my + blockH + S(14)
	end

	container("rig", "CHALECO TÁCTICO")

	my = header(mid, "BOLSILLOS", my, midW - S(12))
	local pockets = mid:Add("efgxInvGrid")
	pockets:SetPos(0, my)
	pockets:Setup(character:GetInventory(), midCell, self)
	my = my + pockets:GetTall() + S(14)

	container("backpack", "MOCHILA")
	container("secure", "CONTENEDOR SEGURO")

	-- ── derecha: alijo ──
	local stashTop = margin + S(30)
	self.stashRect = {stashX, margin, stashW}

	if (stash) then
		local scroll = self:Add("DScrollPanel")
		scroll:SetPos(stashX, stashTop)
		scroll:SetSize(stashW, bottom - stashTop)
		self:StyleScroll(scroll)
		self.stashScroll = scroll

		local grid = scroll:Add("efgxInvGrid")
		grid:SetPos(0, 0)
		grid:Setup(stash, cell, self)
	else
		local client = LocalPlayer()
		self.stashMsg = (client.InRaid and client:InRaid()) and "EL ALIJO NO ESTÁ DISPONIBLE DURANTE LA RAID" or "CARGANDO EL ALIJO..."
	end

	-- ── abajo: acceso rápido ──
	local hotbar = ix.hotbar and ix.hotbar.Get(character) or {}
	local slots = H().HOTBAR_SLOTS or 5
	local qs = S(52)
	local qx = math.floor(w / 2 - (slots * (qs + S(4))) / 2)

	self.quickY = h - quickH

	for i = 1, slots do
		local item = hotbar[i] and ix.item.instances[hotbar[i]]
		local slot = self:Add("efgxInvSlot")
		slot:SetPos(qx + (i - 1) * (qs + S(4)), h - qs - S(8))
		slot:SetSize(qs, qs)
		slot:Setup(self, "hotbar", i, nil, item)
	end

	-- restaurar scroll cuando el lienzo ya tiene tamaño
	timer.Simple(0, function()
		if (IsValid(mid)) then mid:GetVBar():SetScroll(midScroll) end
		if (IsValid(self.stashScroll)) then self.stashScroll:GetVBar():SetScroll(stashScroll) end
	end)
end

function PAGE:StyleScroll(scroll)
	local bar = scroll:GetVBar()
	bar:SetWide(S(6))
	bar:SetHideButtons(true)
	bar.Paint = function(_, w, h)
		surface.SetDrawColor(14, 14, 14, 200)
		surface.DrawRect(0, 0, w, h)
	end
	bar.btnGrip.Paint = function(this, w, h)
		surface.SetDrawColor(this:IsHovered() and G.color.dim or G.color.border)
		surface.DrawRect(0, 0, w, h)
	end
end

-- ─── Reglas de soltar ────────────────────────────────────────────────────────
function PAGE:SlotAccepts(slot, item)
	if (!item or slot.itemTable == item) then return false end

	if (slot.kind == "gear") then
		return ix.GetEquipSlotKind and ix.GetEquipSlotKind(item) == slot.key
	elseif (slot.kind == "weapon") then
		if (!item.isWeapon or item:GetData("equip")) then return false end

		local want = weaponSlotOf(item)
		return want == slot.key or (want == "primary" and slot.key == "primary2")
	elseif (slot.kind == "hotbar") then
		return H().CanHotbar(item) and true or false
	end

	return false
end

local function canEnter(item, inv)
	if (item:GetData("id") == inv:GetID()) then return false end

	local old = ix.item.inventories[item.invID or 0]

	if (old and old != inv) then
		if (hook.Run("CanTransferItem", item, old, inv) == false) then return false end
		if (item.CanTransfer and item:CanTransfer(old, inv) == false) then return false end
	end

	return true
end

-- ─── Arrastre ────────────────────────────────────────────────────────────────
function PAGE:StartDrag(panel, pressX, pressY)
	local item = panel.itemTable
	if (!item) then return end

	local bw, bh = G.StockSize(item)
	local rot = panel.source.kind == "grid" and G.IsRotated(item) or false
	local fw, fh = rot and bh or bw, rot and bw or bh
	local cell = self.cell or S(48)
	local offX, offY

	if (panel.source.kind == "grid") then
		-- el punto agarrado se mantiene bajo el cursor
		local sx, sy = panel:GetSize()
		offX = pressX / math.max(sx, 1) * fw * cell
		offY = pressY / math.max(sy, 1) * fh * cell
	else
		offX, offY = cell / 2, cell / 2
	end

	self.drag = {panel = panel, item = item, source = panel.source, bw = bw, bh = bh, rot = rot, offX = offX, offY = offY}
	self.rWasDown = input.IsKeyDown(KEY_R)

	if (ix.efg.inv) then ix.efg.inv.dragging = true end
	CloseDermaMenus()
	surface.PlaySound("efg/ui/click.wav")
end

function PAGE:DragSize()
	local d = self.drag
	return d.rot and d.bh or d.bw, d.rot and d.bw or d.bh
end

function PAGE:Rotate()
	local d = self.drag
	if (!d or d.bw == d.bh or d.source.kind != "grid") then return end

	d.rot = !d.rot
	d.offX, d.offY = d.offY, d.offX
	surface.PlaySound("efg/ui/click.wav")
end

function PAGE:UpdateDropTarget()
	local d = self.drag
	local fw, fh = self:DragSize()

	self.dropTarget = nil

	for _, panel in ipairs(self.drops) do
		if (IsValid(panel) and G.CursorIn(panel)) then
			if (panel.inv) then
				local inv = panel.inv
				local gx, gy = panel:SnapCell(d.offX, d.offY, fw, fh)
				local ok = d.source.kind != "hotbar" and G.Fits(inv, panel.layout, d.item, gx, gy, fw, fh) and canEnter(d.item, inv)

				-- un arma o equipo que llega de una ranura no se puede girar
				if (d.source.kind != "grid" and d.rot) then ok = false end

				self.dropTarget = {panel = panel, x = gx, y = gy, w = fw, h = fh, ok = ok}
			elseif (panel.kind) then
				self.dropTarget = {panel = panel, ok = self:SlotAccepts(panel, d.item)}
			end

			return
		end
	end
end

function PAGE:CancelDrag()
	self.drag = nil
	self.dropTarget = nil
	if (ix.efg.inv) then ix.efg.inv.dragging = false end
end

function PAGE:FinishDrag()
	local d = self.drag
	if (!d) then return end

	self:UpdateDropTarget()

	local t = self.dropTarget
	local item = d.item

	self:CancelDrag()

	-- desde el acceso rápido: soltar fuera de otra ranura quita la asignación
	if (d.source.kind == "hotbar") then
		if (t and t.panel.kind == "hotbar" and t.panel.key != d.source.slot) then
			self:SetHotbar(t.panel.key, item:GetID())
		end

		if (!t or t.panel.key != d.source.slot) then self:SetHotbar(d.source.slot, 0) end
		return
	end

	if (!t or !t.ok) then
		if (t) then surface.PlaySound("buttons/button10.wav") end
		return
	end

	local panel = t.panel

	if (panel.inv) then
		self:DropOnGrid(item, d.source, panel.inv, t.x, t.y, d.rot)
	elseif (panel.kind == "gear") then
		net.Start("ixEquipToSlot")
			net.WriteUInt(item:GetID(), 32)
		net.SendToServer()
	elseif (panel.kind == "weapon") then
		H().RunFunction(item, "Equip")
	elseif (panel.kind == "hotbar") then
		self:SetHotbar(panel.key, item:GetID())
	end

	surface.PlaySound("efg/ui/click.wav")
	self.sig = nil
end

function PAGE:DropOnGrid(item, source, inv, x, y, rot)
	if (source.kind == "grid") then
		if (!G.MoveTo(item, inv, x, y, rot)) then surface.PlaySound("buttons/button10.wav") end
	elseif (source.kind == "gear") then
		-- la ropa se quita con ixUnequipSlot; el resto va a la casilla
		if (item.outfitCategory or !H().Move(item, inv:GetID(), x, y)) then
			net.Start("ixUnequipSlot")
				net.WriteUInt(item:GetID(), 32)
			net.SendToServer()
		end
	elseif (source.kind == "weapon") then
		if (item:GetData("equip")) then H().RunFunction(item, "EquipUn") end

		if (item.invID != inv:GetID() or G.Pos(item) != x or select(2, G.Pos(item)) != y) then
			timer.Simple(0.15, function()
				if (ix.item.instances[item:GetID()]) then H().Move(item, inv:GetID(), x, y) end
			end)
		end
	end
end

function PAGE:SetHotbar(slot, id)
	net.Start("ixHotbarUpdate")
		net.WriteUInt(slot, 8)
		net.WriteUInt(id or 0, 32)
	net.SendToServer()
end

-- ─── Clics ───────────────────────────────────────────────────────────────────
function PAGE:ItemDoubleClick(item, source)
	if ((item.category == "Medicamentos" or item.category == "Estimulantes") and ix.efg.health and ix.efg.health.QuickUse
		and ix.efg.health.QuickUse(item)) then
		surface.PlaySound("efg/ui/click.wav")
		return
	end

	if (source.kind == "grid" and ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)) then
		net.Start("ixEquipToSlot")
			net.WriteUInt(item:GetID(), 32)
		net.SendToServer()
		return
	end

	if (source.kind == "grid" and item.isWeapon and !item:GetData("equip")) then
		H().RunFunction(item, "Equip")
		return
	end

	if (ix.efg.inspect and ix.efg.inspect.Open) then ix.efg.inspect.Open(item) end
end

-- inventarios a los que se puede mandar con «Mover a»
function PAGE:MoveTargets(item)
	local character = LocalPlayer():GetCharacter()
	local equip = H().GetEquipped(character)
	local out = {}

	local function add(name, inv)
		if (inv and inv:GetID() != item.invID and canEnter(item, inv)) then out[#out + 1] = {name, inv} end
	end

	add("Alijo", self.stashID and ix.item.inventories[self.stashID])
	add("Chaleco táctico", innerInv(equip.rig))
	add("Bolsillos", character:GetInventory())
	add("Mochila", innerInv(equip.backpack))
	add("Contenedor seguro", innerInv(equip.secure))

	return out
end

function PAGE:OpenContext(item, source)
	local menu = G.Menu()
	local html = H()

	if (ix.efg.inspect and ix.efg.inspect.Open) then
		menu:AddOption("Inspeccionar", function() ix.efg.inspect.Open(item) end)
	end

	for key, fn in SortedPairs(item.functions or {}) do
		if (key != "combine" and html.CanRun(item, fn)) then
			local name = fn.name or key
			name = isstring(name) and L(name) or tostring(name)

			if (fn.isMulti) then
				item.player = LocalPlayer()
				local ok, options = pcall(fn.multiOptions or function() return {} end, item, LocalPlayer())
				item.player = nil

				local sub = menu:AddSubMenu(name)

				for _, option in ipairs(ok and istable(options) and options or {}) do
					sub:AddOption(option.name or "?", function() html.RunFunction(item, key, option.data) end)
				end
			else
				menu:AddOption(name, function() html.RunFunction(item, key) end)
			end
		end
	end

	if (source.kind == "grid") then
		local targets = self:MoveTargets(item)

		if (#targets > 0) then
			local sub = menu:AddSubMenu("Mover a")

			for _, target in ipairs(targets) do
				sub:AddOption(target[1], function()
					local x, y, rot = G.FindFree(target[2], item)

					if (x) then
						G.MoveTo(item, target[2], x, y, rot)
					else
						LocalPlayer():Notify("No hay sitio en " .. string.lower(target[1]) .. ".")
					end
				end)
			end
		end
	elseif (source.kind == "gear") then
		menu:AddOption("Quitar", function()
			net.Start("ixUnequipSlot")
				net.WriteUInt(item:GetID(), 32)
			net.SendToServer()
		end)
	end

	if (source.kind == "hotbar") then
		menu:AddOption("Quitar del acceso rápido", function() self:SetHotbar(source.slot, 0) end)
	elseif (html.CanHotbar(item)) then
		local sub = menu:AddSubMenu("Acceso rápido")

		for i = 1, html.HOTBAR_SLOTS or 5 do
			sub:AddOption("Tecla " .. (ix.hotbar and ix.hotbar.KeyLabel(i) or i), function() self:SetHotbar(i, item:GetID()) end)
		end
	end

	menu:Open()
end

-- ─── Bucle ───────────────────────────────────────────────────────────────────
function PAGE:Think()
	local d = self.drag

	if (d) then
		if (!IsValid(d.panel) or !ix.item.instances[d.item:GetID()] or !input.IsMouseDown(MOUSE_LEFT)) then
			if (IsValid(d.panel) and !input.IsMouseDown(MOUSE_LEFT)) then
				d.panel:MouseCapture(false)
				d.panel.pressing = false
				self:FinishDrag()
			else
				self:CancelDrag()
			end

			return
		end

		local down = input.IsKeyDown(KEY_R)
		if (down and !self.rWasDown) then self:Rotate() end
		self.rWasDown = down

		self:UpdateDropTarget()
		return
	end

	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.2

	if (!self:IsVisible() or !LocalPlayer():GetCharacter() or !H()) then return end
	if (self.sig == nil or H().Signature(self) != self.sig) then self:Rebuild() end
end

-- ─── Dibujo ──────────────────────────────────────────────────────────────────
function PAGE:Paint(w, h)
	local c = G.color

	surface.SetDrawColor(c.bg.r, c.bg.g, c.bg.b, 200)
	surface.DrawRect(0, 0, w, h)

	local character = LocalPlayer():GetCharacter()
	if (!character) then return end

	-- cabecera del alijo
	local r = self.stashRect

	if (r) then
		surface.SetDrawColor(c.header)
		surface.DrawRect(r[1], r[2], r[3], S(26))
		draw.SimpleText("ALIJO", "efgInv.Big", r[1] + S(8), r[2] + S(13), c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.Comma(character:GetMoney()) .. " RUB", "efgInv.Header", r[1] + r[3] - S(8), r[2] + S(13), c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		if (self.stashMsg and !IsValid(self.stashScroll)) then
			draw.SimpleText(self.stashMsg, "efgInv.Header", r[1] + r[3] / 2, r[2] + S(80), c.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- estado abajo a la izquierda: peso, salud, hidratación y energía
	if (self.statsY) then
		local client = LocalPlayer()
		local hp, hpMax = client:Health(), client:GetMaxHealth()
		local parts = client:GetNetVar("efgHP")

		if (istable(parts) and ix.efg.health) then
			hp = 0
			for _, part in ipairs(parts) do hp = hp + (tonumber(part[1]) or 0) end
			hpMax = ix.efg.health.total or hpMax
		end

		local water = (character.GetSaturation and character:GetSaturation()) or client:GetLocalVar("saturation", 100) or 100
		local energy = (character.GetSatiety and character:GetSatiety()) or client:GetLocalVar("satiety", 100) or 100
		local weight, maxWeight = character:GetData("carry", 0), ix.config.Get("maxWeight", 30)

		local stats = {
			{"PESO", ("%.1f/%d"):format(weight, maxWeight), weight > maxWeight and c.badLine or c.text},
			{"SALUD", math.Round(hp) .. "/" .. hpMax, HP_COLOR},
			{"HIDRAT.", math.floor(water) .. "/100", WATER_COLOR},
			{"ENERGÍA", math.floor(energy) .. "/100", ENERGY_COLOR},
		}

		local sx = self.statsX

		for _, stat in ipairs(stats) do
			draw.SimpleText(stat[1], "efgInv.Name", sx, self.statsY, c.dim)
			draw.SimpleText(stat[2], "efgInv.Big", sx, self.statsY + S(12), stat[3])
			sx = sx + S(104)
		end
	end

	if (self.quickY) then
		draw.SimpleText("ACCESO RÁPIDO", "efgInv.Name", w / 2, self.quickY, c.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

function PAGE:PaintOver(w, h)
	local d = self.drag
	local mx, my = self:ScreenToLocal(gui.MousePos())

	-- objeto arrastrado pegado al cursor, con su tamaño (girado si toca)
	if (d) then
		local fw, fh = self:DragSize()
		local cell = self.cell or S(48)
		local gw, gh = fw * cell, fh * cell
		local x, y = mx - d.offX, my - d.offY

		surface.SetDrawColor(G.color.item.r, G.color.item.g, G.color.item.b, 200)
		surface.DrawRect(x, y, gw, gh)
		G.DrawIcon(d.item, x + S(2), y + S(2), gw - S(4), gh - S(4), d.rot)
		surface.SetDrawColor(G.color.hover)
		surface.DrawOutlinedRect(x, y, gw, gh, 1)
		return
	end

	-- nombre del objeto bajo el ratón
	local hovered = vgui.GetHoveredPanel()

	if (IsValid(hovered) and hovered.itemTable and hovered.page == self) then
		if (self.hoverPanel != hovered) then
			self.hoverPanel = hovered
			self.hoverTime = RealTime()
		end

		if (RealTime() - self.hoverTime > 0.35) then
			local item = hovered.itemTable
			local text = G.Name(item)
			local sub = ("%.2f kg"):format(tonumber(item.weight) or 0)

			if (item:GetData("fir")) then sub = sub .. "  ·  ENCONTRADO EN RAID" end

			surface.SetFont("efgInv.Menu")
			local tw = math.max(surface.GetTextSize(text), S(120)) + S(16)
			local th = S(42)
			local tx, ty = math.min(mx + S(14), w - tw - S(4)), math.min(my + S(18), h - th - S(4))

			surface.SetDrawColor(G.color.menu)
			surface.DrawRect(tx, ty, tw, th)
			surface.SetDrawColor(G.color.border)
			surface.DrawOutlinedRect(tx, ty, tw, th, 1)
			draw.SimpleText(text, "efgInv.Menu", tx + S(8), ty + S(4), G.color.text)
			draw.SimpleText(sub, "efgInv.Name", tx + S(8), ty + S(24), G.color.dim)
		end
	else
		self.hoverPanel = nil
	end
end

function PAGE:RequestClose()
	CloseDermaMenus()
	if (self.OnRequestClose) then self:OnRequestClose() end
end

function PAGE:OnRemove()
	self:CancelDrag()
	if (ix.gui.efgInvHTML == self) then ix.gui.efgInvHTML = nil end

	if (self.stashRequested and !IsValid(ix.gui.efgTrader)) then
		net.Start("ixEFGStashTab")
			net.WriteBool(false)
		net.SendToServer()
	end
end

vgui.Register("efgxInventoryEFT", PAGE, "EditablePanel")
