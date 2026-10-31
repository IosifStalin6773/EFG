-- Piezas del inventario de EFT en VGUI: utilidades de rejilla, objeto
-- (efgxInvItem), rejilla (efgxInvGrid), ranura de equipo (efgxInvSlot) y menú
-- contextual. La página que las junta y el arrastre están en cl_page.lua.
local G = ix.efg.invgrid

G.color = {
	bg = Color(20, 20, 20), panel = Color(30, 30, 30, 235), border = Color(50, 50, 50),
	cell = Color(22, 22, 21, 240), cellLine = Color(44, 45, 42), item = Color(40, 42, 39),
	header = Color(0, 0, 0, 230), text = Color(200, 198, 180), dim = Color(118, 118, 106),
	hover = Color(255, 255, 255, 70), ok = Color(110, 190, 80, 80), bad = Color(200, 60, 50, 80),
	okLine = Color(130, 210, 95), badLine = Color(215, 70, 58), menu = Color(20, 20, 20, 250),
}

function G.S(v)
	return ix.efgui and ix.efgui.Scale(v) or v
end

local S = G.S

function G.Fonts()
	local key = ScrW() .. "x" .. ScrH()
	if (G.fontKey == key) then return end
	G.fontKey = key

	surface.CreateFont("efgInv.Name", {font = "MBender", extended = true, size = S(12), weight = 500})
	surface.CreateFont("efgInv.Count", {font = "MBender", extended = true, size = S(13), weight = 600})
	surface.CreateFont("efgInv.Header", {font = "MBender", extended = true, size = S(14), weight = 600})
	surface.CreateFont("efgInv.Menu", {font = "MBender", extended = true, size = S(15), weight = 500})
	surface.CreateFont("efgInv.Big", {font = "MBender", extended = true, size = S(22), weight = 600})
end

-- ─── Posiciones ──────────────────────────────────────────────────────────────
-- En el cliente Helix guarda el objeto en la casilla superior izquierda; si por
-- algún camino ocupa más casillas, la esquina es la mínima.
function G.Pos(item, inv)
	inv = inv or ix.item.inventories[item.invID or 0]
	if (!inv) then return end

	local bx, by

	for x, column in pairs(inv.slots) do
		for y, other in pairs(column) do
			if (istable(other) and other.id == item.id and (!bx or x < bx or (x == bx and y < by))) then
				bx, by = x, y
			end
		end
	end

	return bx, by
end

-- {item, x, y, w, h} de cada objeto guardado directamente en inv
function G.Layout(inv)
	local out = {}

	for _, item in pairs(inv:GetItems(true)) do
		if (item.invID == inv:GetID()) then
			local x, y = G.Pos(item, inv)

			if (x) then
				out[#out + 1] = {item = item, x = x, y = y, w = item.width or 1, h = item.height or 1}
			end
		end
	end

	return out
end

-- ¿cabe un rectángulo w x h en (x, y)? Comprueba bordes y solapes (AABB)
function G.Fits(inv, layout, ignore, x, y, w, h)
	local iw, ih = inv:GetSize()
	if (x < 1 or y < 1 or x + w - 1 > iw or y + h - 1 > ih) then return false end
	if (ix.efg.rig and !ix.efg.rig.Fits(inv, x, y, w, h)) then return false end

	local ignoreID = ignore and ignore.id

	for i = 1, #layout do
		local e = layout[i]

		if (e.item.id != ignoreID and x < e.x + e.w and x + w > e.x and y < e.y + e.h and y + h > e.y) then
			return false
		end
	end

	return true
end

function G.StockSize(item)
	local stock = ix.item.list[item.uniqueID] or item
	return stock.width or 1, stock.height or 1
end

function G.IsRotated(item)
	return ix.efg.inv and ix.efg.inv.IsRotated and ix.efg.inv.IsRotated(item) or false
end

-- primer hueco libre (prueba sin girar y girado): x, y, rot
function G.FindFree(inv, item)
	local layout = G.Layout(inv)
	local bw, bh = G.StockSize(item)
	local iw, ih = inv:GetSize()
	local tries = {{bw, bh, false}}

	if (bw != bh) then tries[2] = {bh, bw, true} end

	for _, try in ipairs(tries) do
		for y = 1, ih do
			for x = 1, iw do
				if (G.Fits(inv, layout, item, x, y, try[1], try[2])) then return x, y, try[3] end
			end
		end
	end
end

-- mover (y girar si hace falta) con los nets de Helix y de efg_invrules
function G.MoveTo(item, inv, x, y, rot)
	if (rot != nil and rot != G.IsRotated(item)) then
		net.Start("ixEFGRotateMove")
			net.WriteUInt(item:GetID(), 32)
			net.WriteUInt(inv:GetID(), 32)
			net.WriteUInt(x, 6)
			net.WriteUInt(y, 6)
			net.WriteBool(rot)
		net.SendToServer()

		return true
	end

	local H = ix.efg.invhtml
	return H and H.Move and H.Move(item, inv:GetID(), x, y) or false
end

-- ─── Datos del objeto ────────────────────────────────────────────────────────
function G.Name(item)
	return (item.GetName and item:GetName()) or item.name or "?"
end

function G.Count(item)
	if (item.isMagazine and item.GetRounds) then return item:GetRounds() .. "/" .. (item.capacity or 0) end
	if (item.isAmmo) then return tostring(item:GetData("rounds", item.ammoAmount or 0)) end

	local uses = item:GetData("uses")
	if (uses and item.maxUses and item.maxUses > 0) then return uses .. "/" .. item.maxUses end

	local qty = item:GetData("quantity")
	return (qty and qty > 1) and tostring(qty) or nil
end

-- nombre corto que cabe en w píxeles (se calcula una vez por panel)
function G.ShortName(item, w)
	local name = item.shortName or G.Name(item):gsub("%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")

	surface.SetFont("efgInv.Name")
	if (surface.GetTextSize(name) <= w) then return name end

	local len = utf8.len(name) or #name

	for n = len - 1, 1, -1 do
		local short = name:sub(1, (utf8.offset(name, n + 1) or (#name + 1)) - 1) .. "."
		if (surface.GetTextSize(short) <= w) then return short end
	end

	return ""
end

-- Icono escalado para cubrir la caja sin deformarse; girado 90° si rotated
function G.DrawIcon(item, x, y, w, h, rotated)
	local path = ix.efg.icons and ix.efg.icons.Resolve(item)
	local mat = path and ix.efgui and ix.efgui.Mat(path)

	if (!mat or mat:IsError()) then
		draw.SimpleText(G.Name(item):sub(1, 3):upper(), "efgInv.Big", x + w / 2, y + h / 2, G.color.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end

	local tw, th = mat:Width(), mat:Height()
	if (tw <= 0 or th <= 0) then tw, th = 1, 1 end

	-- en espacio del icono la caja girada intercambia ancho y alto
	local bw, bh = rotated and h or w, rotated and w or h
	local scale = math.min(bw / tw, bh / th)

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRectRotated(x + w / 2, y + h / 2, tw * scale, th * scale, rotated and 90 or 0)
end

-- ¿está el cursor dentro del panel y de todos sus padres? (respeta el recorte
-- de los paneles con scroll)
function G.CursorIn(panel)
	local mx, my = gui.MousePos()
	local p = panel
	local world = vgui.GetWorldPanel()

	while (IsValid(p) and p != world) do
		if (!p:IsVisible()) then return false end

		local x, y = p:LocalToScreen(0, 0)
		local w, h = p:GetSize()

		if (mx < x or my < y or mx >= x + w or my >= y + h) then return false end

		p = p:GetParent()
	end

	return true
end

-- ─── Objeto ──────────────────────────────────────────────────────────────────
local ITEM = {}

function ITEM:Init()
	self:SetText("")
	self:SetCursor("hand")
end

-- source: {kind = "grid", inv = inv} | {kind = "gear", slot = ...} |
-- {kind = "weapon", slot = ...} | {kind = "hotbar", slot = n}
function ITEM:Setup(item, page, source, rotated)
	self.itemTable = item
	self.page = page
	self.source = source
	self.rotated = rotated or false
end

function ITEM:PerformLayout(w)
	if (self.itemTable) then self.short = G.ShortName(self.itemTable, w - S(6)) end
end

function ITEM:OnMousePressed(code)
	local page = self.page
	if (!IsValid(page)) then return end

	if (page:IsDragging()) then
		if (code == MOUSE_RIGHT) then page:CancelDrag() end
		return
	end

	if (code == MOUSE_LEFT) then
		local now = RealTime()

		if (self.lastClick and now - self.lastClick < 0.3) then
			self.lastClick = nil
			page:ItemDoubleClick(self.itemTable, self.source)
			return
		end

		self.lastClick = now
		self.pressX, self.pressY = self:LocalCursorPos()
		self.pressing = true
		self:MouseCapture(true)
	elseif (code == MOUSE_RIGHT) then
		page:OpenContext(self.itemTable, self.source)
	end
end

function ITEM:Think()
	if (!self.pressing or !IsValid(self.page) or self.page:IsDragging()) then return end

	local x, y = self:LocalCursorPos()

	if (math.abs(x - self.pressX) + math.abs(y - self.pressY) > 4) then
		self.page:StartDrag(self, self.pressX, self.pressY)
	end
end

function ITEM:OnMouseReleased(code)
	if (code != MOUSE_LEFT) then return end

	self:MouseCapture(false)
	self.pressing = false

	if (IsValid(self.page) and self.page:IsDragging()) then self.page:FinishDrag() end
end

function ITEM:OnRemove()
	if (self.pressing) then self:MouseCapture(false) end
end

function ITEM:Paint(w, h)
	local item = self.itemTable
	if (!item) then return end

	local c = G.color

	surface.SetDrawColor(c.item)
	surface.DrawRect(0, 0, w, h)
	G.DrawIcon(item, S(2), S(2), w - S(4), h - S(4), self.rotated)

	surface.SetDrawColor(c.border)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	if (self.short and self.short != "") then
		draw.SimpleText(self.short, "efgInv.Name", w - S(3), S(1), c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	local count = G.Count(item)
	if (count) then draw.SimpleText(count, "efgInv.Count", w - S(3), h - S(1), c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end

	if (self.source and self.source.kind == "grid" and item.isWeapon and item:GetData("equip")) then
		draw.SimpleText("EQ", "efgInv.Name", S(3), h - S(1), c.okLine, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	local drag = IsValid(self.page) and self.page.drag

	if (drag and drag.panel == self) then
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, w, h)
	elseif (!drag and self:IsHovered()) then
		surface.SetDrawColor(c.hover)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
end

vgui.Register("efgxInvItem", ITEM, "DButton")

-- ─── Rejilla ─────────────────────────────────────────────────────────────────
local GRID = {}

function GRID:Init()
	self:SetPaintBackground(false)
end

function GRID:Setup(inv, cell, page)
	self.inv = inv
	self.cell = cell
	self.page = page
	self.gw, self.gh = inv:GetSize()
	self:SetSize(self.gw * cell + 1, self.gh * cell + 1)
	self.layout = G.Layout(inv)

	for _, e in ipairs(self.layout) do
		local panel = self:Add("efgxInvItem")
		panel:SetPos((e.x - 1) * cell + 1, (e.y - 1) * cell + 1)
		panel:SetSize(e.w * cell - 1, e.h * cell - 1)
		panel:Setup(e.item, page, {kind = "grid", inv = inv}, G.IsRotated(e.item))
	end

	page:RegisterDrop(self)
end

-- top-left de la rejilla bajo el cursor con encaje: el borde del objeto
-- arrastrado (cursor - desplazamiento del agarre) se redondea a la casilla
-- más cercana y se limita al interior de la rejilla
function GRID:SnapCell(offX, offY, w, h)
	local lx, ly = self:ScreenToLocal(gui.MousePos())
	local cell = self.cell
	local gx = math.Round((lx - offX) / cell) + 1
	local gy = math.Round((ly - offY) / cell) + 1

	if (w <= self.gw) then gx = math.Clamp(gx, 1, self.gw - w + 1) end
	if (h <= self.gh) then gy = math.Clamp(gy, 1, self.gh - h + 1) end

	return gx, gy
end

function GRID:Paint(w, h)
	local c = G.color
	local cell = self.cell

	local rig = ix.efg.rig and ix.efg.rig.ForInventory(self.inv)
	local layout = rig and ix.efg.rig.Layout(rig)

	if (layout) then
		-- chaleco: solo los bolsillos, cada uno con su borde
		for _, p in ipairs(layout.pockets) do
			local px, py, pw, ph = (p.x - 1) * cell, (p.y - 1) * cell, p.w * cell + 1, p.h * cell + 1

			surface.SetDrawColor(c.cell)
			surface.DrawRect(px, py, pw, ph)
			surface.SetDrawColor(c.cellLine)

			for i = 1, p.w - 1 do surface.DrawRect(px + i * cell, py, 1, ph) end
			for j = 1, p.h - 1 do surface.DrawRect(px, py + j * cell, pw, 1) end

			surface.SetDrawColor(c.dim)
			surface.DrawOutlinedRect(px, py, pw, ph, 1)
		end

		return
	end

	surface.SetDrawColor(c.cell)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(c.cellLine)

	for i = 0, self.gw do surface.DrawRect(i * cell, 0, 1, h) end
	for j = 0, self.gh do surface.DrawRect(0, j * cell, w, 1) end
end

function GRID:PaintOver()
	local t = IsValid(self.page) and self.page.dropTarget
	if (!t or t.panel != self) then return end

	local cell = self.cell
	local x, y, w, h = (t.x - 1) * cell + 1, (t.y - 1) * cell + 1, t.w * cell - 1, t.h * cell - 1

	surface.SetDrawColor(t.ok and G.color.ok or G.color.bad)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(t.ok and G.color.okLine or G.color.badLine)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end

vgui.Register("efgxInvGrid", GRID, "DPanel")

-- ─── Ranura (equipo, armas, acceso rápido) ───────────────────────────────────
-- kind: gear | weapon | hotbar; key: headset, primary, 1...; label arriba
local SLOT = {}

function SLOT:Init()
	self:SetPaintBackground(false)
end

function SLOT:Setup(page, kind, key, label, item)
	self.page = page
	self.kind = kind
	self.key = key
	self.label = label
	self.itemTable = item
	self.headH = label and S(16) or 0

	if (item) then
		self.child = self:Add("efgxInvItem")
		self.child:Setup(item, page, {kind = kind, slot = key}, false)
	end

	page:RegisterDrop(self)
end

function SLOT:PerformLayout(w, h)
	if (IsValid(self.child)) then
		self.child:SetPos(1, self.headH + 1)
		self.child:SetSize(w - 2, h - self.headH - 2)
	end
end

function SLOT:Paint(w, h)
	local c = G.color

	if (self.label) then
		surface.SetDrawColor(c.header)
		surface.DrawRect(0, 0, w, self.headH)
		draw.SimpleText(self.label, "efgInv.Name", S(4), self.headH / 2, c.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(c.cell)
	surface.DrawRect(0, self.headH, w, h - self.headH)

	if (self.kind == "hotbar") then
		draw.SimpleText(tostring(self.key), "efgInv.Name", S(3), self.headH + S(1), c.dim)
	end
end

function SLOT:PaintOver(w, h)
	local page = self.page
	local drag = IsValid(page) and page.drag
	local c = G.color
	local y = self.headH

	if (drag and page:SlotAccepts(self, drag.item)) then
		local t = page.dropTarget
		local hot = t and t.panel == self

		surface.SetDrawColor(c.ok.r, c.ok.g, c.ok.b, hot and 90 or 30)
		surface.DrawRect(0, y, w, h - y)
		surface.SetDrawColor(c.okLine)
		surface.DrawOutlinedRect(0, y, w, h - y, 1)
		return
	end

	surface.SetDrawColor((!drag and self:IsHovered()) and c.hover or c.border)
	surface.DrawOutlinedRect(0, y, w, h - y, 1)
end

vgui.Register("efgxInvSlot", SLOT, "DPanel")

-- ─── Menú contextual estilo EFT (DMenu restilizado: cierra solo al hacer clic
-- fuera y admite submenús) ────────────────────────────────────────────────────
local MENU_DARK = Color(20, 20, 20)

local function styleOption(option)
	option:SetFont("efgInv.Menu")
	option:SetTextInset(S(12), 0)
	option:SetTall(S(26))
	option.Paint = function(this, w, h)
		local hovered = this:IsHovered() or (this.SubMenu and IsValid(this.SubMenu) and this.SubMenu:IsVisible())

		if (hovered) then
			surface.SetDrawColor(200, 198, 180)
			surface.DrawRect(0, 0, w, h)
		end

		this:SetTextColor(hovered and MENU_DARK or G.color.text)

		if (this.SubMenu) then
			draw.SimpleText(">", "efgInv.Menu", w - S(10), h / 2, hovered and MENU_DARK or G.color.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		return false
	end
end

local function styleMenu(menu)
	menu:SetMinimumWidth(S(190))
	menu.Paint = function(_, w, h)
		surface.SetDrawColor(G.color.menu)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(G.color.border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
end

function G.Menu()
	local menu = DermaMenu()
	styleMenu(menu)

	local wrap
	wrap = function(m)
		local add, sub = m.AddOption, m.AddSubMenu

		m.AddOption = function(this, text, fn)
			local option = add(this, string.upper(text), fn)
			styleOption(option)
			return option
		end

		m.AddSubMenu = function(this, text, fn)
			local child, parent = sub(this, string.upper(text), fn)
			styleMenu(child)
			styleOption(parent)
			wrap(child)
			return child, parent
		end
	end

	wrap(menu)
	return menu
end
