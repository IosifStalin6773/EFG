-- ════════════════════════════════════════════════════════════════════════════
-- SAQUEO (efgxLootView) — cadáver o alijo a la izquierda, tu equipo a la derecha.
-- API igual que ixStorageView: SetStorageTitle, SetStorageInventory,
-- SetLocalInventory, SetStorageMoney, SetLocalMoney, SetStorageID, Close.
-- Usa la rejilla y los iconos de efg_invgrid (ix.efg.invgrid). Mover = red de Helix
-- (ixInventoryMove) vía G.MoveTo, igual que el resto de inventarios.
-- ════════════════════════════════════════════════════════════════════════════

local function G() return ix.efg.invgrid end

local function Col(name, fallback)
	local c = ix.efgui and ix.efgui.color and ix.efgui.color[name]
	return c or fallback
end

local function Sc(v)
	return (ix.efgui and ix.efgui.S and ix.efgui.S(v)) or (ScrH() / 1080) * v
end

local function Fonts()
	surface.CreateFont("efgLoot.Title", {font = "MBender", extended = true, size = Sc(16), weight = 600})
	surface.CreateFont("efgLoot.Small", {font = "MBender", extended = true, size = Sc(12), weight = 500})
end

local function Signature(inv)
	if (not inv or not inv.GetItems) then return "" end

	local parts = {}
	for id, item in pairs(inv:GetItems()) do
		local x, y = G().Pos(item, inv)
		parts[#parts + 1] = id .. ":" .. tostring(x) .. "," .. tostring(y) .. ":" .. tostring(G().IsRotated(item))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

-- ─── Rejilla de un inventario ───────────────────────────────────────────────
local GRID = {}

function GRID:Setup(view, inv, side, cell)
	self.view = view
	self.inv = inv
	self.side = side
	self.cell = cell
	self.gw, self.gh = inv:GetSize()
	self.layout = G().Layout(inv)
	self.panels = {}
	self:SetSize(self.gw * cell + 1, self.gh * cell + 1)
end

-- Helix llama a AddIcon al añadir un objeto a un inventario con panel; esta rejilla
-- se repinta sola desde Think, así que no hace falta crear iconos.
function GRID:AddIcon()
end

function GRID:ItemAt(mx, my)
	local cx = math.floor(mx / self.cell) + 1
	local cy = math.floor(my / self.cell) + 1

	for _, e in ipairs(self.layout or {}) do
		if (cx >= e.x and cx < e.x + e.w and cy >= e.y and cy < e.y + e.h) then
			return e.item
		end
	end
end

function GRID:Paint(w, h)
	local cell = self.cell
	local line = Col("line", Color(90, 90, 80, 60))

	surface.SetDrawColor(line)
	for x = 0, self.gw do surface.DrawRect(x * cell, 0, 1, h) end
	for y = 0, self.gh do surface.DrawRect(0, y * cell, w, 1) end

	local hover = self.view and self.view.hoverItem
	for _, e in ipairs(self.layout or {}) do
		local x, y = (e.x - 1) * cell + 1, (e.y - 1) * cell + 1
		local bw, bh = e.w * cell - 1, e.h * cell - 1
		local rot = G().IsRotated(e.item)

		surface.SetDrawColor(12, 12, 10, 235)
		surface.DrawRect(x, y, bw, bh)

		G().DrawIcon(e.item, x, y, bw, bh, rot)

		local count = G().Count(e.item)
		if (count) then
			draw.SimpleText(tostring(count), "efgLoot.Small", x + bw - Sc(3), y + bh - Sc(2), color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end

		if (hover == e.item) then
			surface.SetDrawColor(Col("accent", Color(200, 170, 90)))
			surface.DrawOutlinedRect(x, y, bw, bh, 2)
		end
	end
end

function GRID:OnMousePressed(code)
	local mx, my = self:CursorPos()
	local item = self:ItemAt(mx, my)
	if (not item) then return end

	if (code == MOUSE_LEFT) then
		self.view:MoveItem(item, self.side)
	elseif (code == MOUSE_RIGHT) then
		self.view:ShowMenu(item, self.side)
	end
end

function GRID:Think()
	local mx, my = self:CursorPos()
	if (mx < 0 or my < 0 or mx > self:GetWide() or my > self:GetTall()) then return end

	local item = self:ItemAt(mx, my)
	if (item ~= self.view.hoverItem) then
		self.view.hoverItem = item
	end
end

vgui.Register("efgxLootGrid", GRID, "DPanel")

-- ─── Panel principal ────────────────────────────────────────────────────────
local PANEL = {}
DEFINE_BASECLASS("Panel")

function PANEL:Init()
	Fonts()

	if (not G()) then self:Remove() return end

	if (IsValid(ix.gui.openedStorage)) then ix.gui.openedStorage:Remove() end
	ix.gui.openedStorage = self

	local sw, sh = ScrW(), ScrH()
	self:SetSize(sw, sh)
	self:SetPos(0, 0)
	self:SetAlpha(0)
	self:AlphaTo(255, 0.15)
	self:MakePopup()

	self.title = "ALIJO"
	self.hoverItem = nil
	self.sigStorage = nil
	self.sigLocal = nil

	self.topH = Sc(34)
	self.bottomH = Sc(44)
	self.gap = Sc(24)
	self.colW = math.floor((sw - Sc(60) - self.gap) / 2)
	self.areaY = self.topH + Sc(20)
	self.areaH = sh - self.areaY - self.bottomH - Sc(20)

	self.closeBtn = self:Add("DButton")
	self.closeBtn:SetText("")
	self.closeBtn:SetSize(Sc(120), self.topH - Sc(6))
	self.closeBtn:SetPos(sw - Sc(130), Sc(3))
	self.closeBtn.Paint = function(btn, w, h)
		surface.SetDrawColor(Col("panel", Color(20, 20, 18, 240)))
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("CERRAR  (ESC)", "efgLoot.Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	self.closeBtn.DoClick = function() self:Close() end

	self.storageHolder = self:Add("DPanel")
	self.storageHolder:SetPaintBackground(false)
	self.storageHolder:SetPos(Sc(30), self.areaY)
	self.storageHolder:SetSize(self.colW, self.areaH)

	self.localHolder = self:Add("DPanel")
	self.localHolder:SetPaintBackground(false)
	self.localHolder:SetPos(Sc(30) + self.colW + self.gap, self.areaY)
	self.localHolder:SetSize(self.colW, self.areaH)

	self.escWasDown = false
end

-- celda que cabe en el área de la columna
function PANEL:CellFor(inv)
	local iw, ih = inv:GetSize()
	iw = math.max(iw or 1, 1); ih = math.max(ih or 1, 1)

	local cell = math.min(math.floor((self.colW - Sc(20)) / iw), math.floor(self.areaH / ih), Sc(46))
	return math.Clamp(cell, Sc(18), Sc(46))
end

function PANEL:BuildGrid(holder, inv, side, sigKey)
	if (IsValid(holder.grid)) then holder.grid:Remove() end
	if (not inv or not inv.slots) then return end

	local cell = self:CellFor(inv)
	local grid = holder:Add("efgxLootGrid")
	grid:Setup(self, inv, side, cell)
	grid:SetPos(math.floor((holder:GetWide() - grid:GetWide()) / 2), 0)

	holder.grid = grid
	self[sigKey] = Signature(inv)

	return grid
end

function PANEL:SetStorageTitle(title)
	self.title = title or "ALIJO"
end

function PANEL:SetStorageInventory(inventory)
	self.storageInventory = inventory
	self:BuildGrid(self.storageHolder, inventory, "storage", "sigStorage")
	ix.gui["inv" .. (inventory and inventory:GetID() or 0)] = self.storageHolder.grid
end

function PANEL:SetLocalInventory(inventory)
	self.localInventory = inventory
	self:BuildGrid(self.localHolder, inventory, "local", "sigLocal")
	ix.gui.inv1 = self.localHolder.grid
end

function PANEL:SetStorageMoney(money) end
function PANEL:SetLocalMoney(money) end

function PANEL:SetStorageID(id)
	self.storageID = id
end

-- Las rejillas se reconstruyen cuando cambia su contenido (Helix mueve ítems por red).
function PANEL:Think()
	if (self.storageInventory and Signature(self.storageInventory) ~= self.sigStorage) then
		self:BuildGrid(self.storageHolder, self.storageInventory, "storage", "sigStorage")
	end
	if (self.localInventory and Signature(self.localInventory) ~= self.sigLocal) then
		self:BuildGrid(self.localHolder, self.localInventory, "local", "sigLocal")
	end

	local escDown = input.IsKeyDown(KEY_ESCAPE)
	if (escDown and not self.escWasDown) then self:Close() end
	self.escWasDown = escDown
end

-- Pasa el objeto al otro lado (primer hueco libre). Sin hueco: aviso.
function PANEL:MoveItem(item, fromSide)
	local target = fromSide == "storage" and self.localInventory or self.storageInventory
	if (not target or not item) then return end

	local x, y, rot = G().FindFree(target, item)
	if (not x) then
		notification.AddLegacy("No cabe en el otro lado.", NOTIFY_ERROR, 3)
		surface.PlaySound("buttons/button10.wav")
		return
	end

	G().MoveTo(item, target, x, y, rot)
end

function PANEL:ShowMenu(item, side)
	local menu = DermaMenu()
	menu:AddOption(side == "storage" and "Pasar a mi equipo" or "Pasar al alijo", function()
		self:MoveItem(item, side)
	end)

	if (ix.efg.inspect and ix.efg.inspect.Open) then
		menu:AddOption("Inspeccionar", function() ix.efg.inspect.Open(item) end)
	end

	menu:Open()
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(Col("panel", Color(19, 19, 16, 240)))
	surface.DrawRect(0, 0, w, self.topH)
	draw.SimpleText(self.title or "ALIJO", "efgLoot.Title", Sc(12), self.topH / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local colX = Sc(30)
	draw.SimpleText("BOTÍN", "efgLoot.Small", colX, self.areaY - Sc(10), Col("muted", Color(170, 170, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	draw.SimpleText("TU EQUIPO", "efgLoot.Small", colX + self.colW + self.gap, self.areaY - Sc(10), Col("muted", Color(170, 170, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

	local by = h - self.bottomH
	surface.SetDrawColor(19, 19, 16, 240)
	surface.DrawRect(0, by, w, self.bottomH)

	local item = self.hoverItem
	if (item) then
		draw.SimpleText(G().Name(item), "efgLoot.Title", Sc(12), by + Sc(8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	draw.SimpleText("Clic izquierdo: pasar al otro lado   ·   Clic derecho: menú", "efgLoot.Small", Sc(12), by + self.bottomH - Sc(8), Col("muted", Color(170, 170, 150)), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end

function PANEL:Close()
	if (self._closed) then return end
	self._closed = true

	net.Start("ixStorageClose")
	net.SendToServer()

	self:Remove()
end

function PANEL:OnRemove()
	if (ix.gui.openedStorage == self) then ix.gui.openedStorage = nil end
	if (ix.gui.inv1 == (self.localHolder and self.localHolder.grid)) then ix.gui.inv1 = nil end
	CloseDermaMenus()
end

vgui.Register("efgxLootView", PANEL, "EditablePanel")
