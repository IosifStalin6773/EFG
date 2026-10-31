-- ============================================================================
--  Ventana de saqueo de EFT (Documento B), en VGUI
--    izquierda  TU EQUIPO: bolsillos y las bolsas que llevas
--    derecha    el cuerpo o contenedor según BuildLootLayout
--  Las secciones sin buscar muestran BUSCAR; al buscar aparecen siluetas una
--  a una y, al acabar, los objetos. Lo que tu personaje no conoce sale como
--  "Objeto desconocido" hasta examinarlo (clic central o menú).
-- ============================================================================

local WIN = ix.efg.lootwin

WIN.sections = WIN.sections or {}

local function Sc(v) return math.Round(v * ScrH() / 1080) end
local function G() return ix.efg.invgrid end

local function Col(key, fallback)
	return (ix.efgui and ix.efgui.color and ix.efgui.color[key]) or fallback
end

local function CreateFonts()
	surface.CreateFont("efgLootWin.Title", {font = "MBender", extended = true, size = Sc(18), weight = 600})
	surface.CreateFont("efgLootWin.Label", {font = "MBender", extended = true, size = Sc(13), weight = 600})
	surface.CreateFont("efgLootWin.Small", {font = "MBender", extended = true, size = Sc(12), weight = 500})
	surface.CreateFont("efgLootWin.Big", {font = "MBender", extended = true, size = Sc(26), weight = 700})
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "efgLootWin.Fonts", CreateFonts)

-- ¿lo conoce el personaje? (misma lista que efg_invrules)
function WIN.IsUnknown(item)
	if (!ix.config.Get("efgExamineEnabled", true)) then return false end
	if (!item.functions or !item.functions.Examinar) then return false end

	local character = LocalPlayer():GetCharacter()
	if (!character) then return false end

	return !character:GetData("efgExamined", {})[item.uniqueID]
end

function WIN.ItemName(item)
	if (WIN.IsUnknown(item)) then return L("efgLootWinUnknown") end

	return (item.GetName and item:GetName()) or item.name or "?"
end

-- Ranura de la réplica a la que va un objeto del equipo
function WIN.SlotOf(item)
	if (item.isWeapon or item.isARC9) then
		local category = string.lower(item.weaponCategory or item.efgSlot or "")

		if (category:find("pistol", 1, true) or category:find("holster", 1, true) or category == "sidearm") then
			return "holster"
		end

		return "primary"
	end

	local kind = ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)

	if (kind == "helmet" or kind == "armor" or kind == "rig" or kind == "backpack") then
		return kind
	end

	if (item.isBag) then return "backpack" end

	return "other"
end

-- ─── Dibujo de un objeto ────────────────────────────────────────────────────
local function DrawItem(item, x, y, w, h, hover)
	surface.SetDrawColor(Col("bg3", Color(48, 51, 46, 245)))
	surface.DrawRect(x, y, w, h)

	local unknown = WIN.IsUnknown(item)

	if (G() and G().DrawIcon) then
		G().DrawIcon(item, x, y, w, h, G().IsRotated(item))
	end

	if (unknown) then
		surface.SetDrawColor(10, 10, 9, 215)
		surface.DrawRect(x, y, w, h)
		draw.SimpleText("?", "efgLootWin.Big", x + w / 2, y + h / 2, Col("text2", Color(154, 152, 136)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		local count = G() and G().Count and G().Count(item)

		if (count and count != "1") then
			draw.SimpleText(tostring(count), "efgLootWin.Small", x + w - Sc(3), y + h - Sc(2), color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	surface.SetDrawColor(hover and Col("accent", Color(227, 114, 45)) or Col("line", Color(58, 61, 54)))
	surface.DrawOutlinedRect(x, y, w, h, hover and 2 or 1)
end

-- ─── Acciones ───────────────────────────────────────────────────────────────
local function SendMove(item, toLoot, target)
	net.Start("efgLootWinMove")
		net.WriteUInt(item.id, 32)
		net.WriteBool(toLoot)
		net.WriteUInt(target or 0, 32)
	net.SendToServer()
end

local function SendExamine(item)
	net.Start("efgLootWinExamine")
		net.WriteUInt(item.id, 32)
	net.SendToServer()
end

local function ShowMenu(item, side)
	local menu = DermaMenu()

	if (WIN.IsUnknown(item)) then
		menu:AddOption(L("efgLootWinExamine"), function() SendExamine(item) end)
	end

	if (side == "loot") then
		menu:AddOption(L("efgLootWinTake"), function() SendMove(item, false) end)
	else
		menu:AddOption(L("efgLootWinPut"), function() SendMove(item, true) end)
	end

	menu:Open()
end

local function ItemClick(item, side, code)
	if (code == MOUSE_LEFT) then
		SendMove(item, side == "local")
	elseif (code == MOUSE_MIDDLE) then
		if (WIN.IsUnknown(item)) then SendExamine(item) end
	elseif (code == MOUSE_RIGHT) then
		ShowMenu(item, side)
	end
end

-- ─── Bloque de rejilla (una sección o un inventario propio) ─────────────────
local GRID = {}

function GRID:Init()
	self.cell = Sc(52)
	self.label = ""
	self:SetCursor("hand")
end

function GRID:Setup(view, side, invID, w, h, label, sectionIndex)
	self.view = view
	self.side = side
	self.invID = invID
	self.gw, self.gh = w, h
	self.label = label or ""
	self.sectionIndex = sectionIndex

	local header = Sc(22)
	self.header = header
	self:SetSize(w * self.cell + 1, header + h * self.cell + 1)
end

function GRID:Section()
	return self.sectionIndex and WIN.sections[self.sectionIndex]
end

function GRID:Layout()
	local inventory = ix.item.inventories[self.invID]
	if (!inventory or !G()) then return {} end

	return G().Layout(inventory)
end

function GRID:ItemAt(mx, my)
	local cx = math.floor(mx / self.cell) + 1
	local cy = math.floor((my - self.header) / self.cell) + 1

	for _, e in ipairs(self:Layout()) do
		if (cx >= e.x and cx < e.x + e.w and cy >= e.y and cy < e.y + e.h) then
			return e.item
		end
	end
end

function GRID:Paint(w, h)
	local cell, top = self.cell, self.header
	w = self.gw * cell + 1
	local section = self:Section()
	local state = section and section.state or "searched"

	draw.SimpleText(string.upper(self.label), "efgLootWin.Label", 0, top / 2, Col("textDim", Color(104, 106, 94)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(Col("cell", Color(18, 19, 17, 245)))
	surface.DrawRect(0, top, w, h - top)

	surface.SetDrawColor(Col("line", Color(58, 61, 54)))
	for x = 0, self.gw do surface.DrawRect(x * cell, top, 1, h - top) end
	for y = 0, self.gh do surface.DrawRect(0, top + y * cell, w, 1) end

	if (state == "searched") then
		local hover = self.view.hoverItem

		for _, e in ipairs(self:Layout()) do
			DrawItem(e.item, (e.x - 1) * cell + 1, top + (e.y - 1) * cell + 1, e.w * cell - 1, e.h * cell - 1, hover == e.item)
		end

		return
	end

	-- siluetas de lo encontrado hasta ahora
	for _, r in ipairs(section.revealed or {}) do
		local x, y = (r.x - 1) * cell + 1, top + (r.y - 1) * cell + 1
		surface.SetDrawColor(40, 42, 38, 240)
		surface.DrawRect(x, y, r.w * cell - 1, r.h * cell - 1)
		draw.SimpleText("?", "efgLootWin.Label", x + (r.w * cell) / 2, y + (r.h * cell) / 2, Col("textDim", Color(104, 106, 94)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (state == "searching") then
		local frac = math.Clamp((CurTime() - section.started) / math.max(section.duration, 0.01), 0, 1)
		local barH = Sc(6)

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, h - barH, w, barH)
		surface.SetDrawColor(Col("accent", Color(227, 114, 45)))
		surface.DrawRect(0, h - barH, w * frac, barH)
	else
		surface.SetDrawColor(0, 0, 0, 170)
		surface.DrawRect(1, top + 1, w - 2, h - top - 2)
		draw.SimpleText(L("efgLootWinSearch"), "efgLootWin.Title", w / 2, top + (h - top) / 2 - Sc(8), Col("accent", Color(227, 114, 45)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("efgLootWinSearchHint"), "efgLootWin.Small", w / 2, top + (h - top) / 2 + Sc(12), Col("text2", Color(154, 152, 136)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function GRID:OnMousePressed(code)
	local section = self:Section()

	if (section and section.state == "hidden") then
		if (code == MOUSE_LEFT) then
			net.Start("efgLootWinSearch")
				net.WriteUInt(self.sectionIndex, 8)
			net.SendToServer()
		end

		return
	end

	if (section and section.state != "searched") then return end

	local mx, my = self:CursorPos()
	local item = self:ItemAt(mx, my)

	if (item) then
		ItemClick(item, self.side, code)
	end
end

function GRID:Think()
	local section = self:Section()
	if (section and section.state != "searched") then return end
	if (!self:IsHovered()) then return end

	local mx, my = self:CursorPos()
	self.view.hoverItem = self:ItemAt(mx, my)
end

vgui.Register("efgxLootWinGrid", GRID, "DPanel")

-- ─── Bloque de ranuras de equipo (réplica de jugador o Scav) ────────────────
local SLOTS = {}

function SLOTS:Init()
	self.cell = Sc(52)
	self:SetCursor("hand")
end

function SLOTS:Setup(view, invID, slots, maxWidth)
	self.view = view
	self.invID = invID
	self.slots = slots
	self.boxes = {}

	-- reparto en filas que quepan en el ancho
	local gap, label = Sc(8), Sc(20)
	local x, y, rowH = 0, 0, 0

	for _, slot in ipairs(slots) do
		local bw, bh = slot.w * self.cell, slot.h * self.cell

		if (x > 0 and x + bw > maxWidth) then
			x, y = 0, y + rowH + gap
			rowH = 0
		end

		self.boxes[#self.boxes + 1] = {slot = slot, x = x, y = y + label, w = bw, h = bh}
		x = x + bw + gap
		rowH = math.max(rowH, bh + label)
	end

	self:SetSize(maxWidth, y + rowH)
end

-- objetos del inventario de equipo repartidos por ranura
function SLOTS:Assign()
	local inventory = ix.item.inventories[self.invID]
	local bySlot = {}

	if (inventory) then
		local items = {}

		for _, item in pairs(inventory:GetItems(true)) do
			if (item.invID == inventory:GetID()) then
				items[#items + 1] = item
			end
		end

		table.sort(items, function(a, b) return a.id < b.id end)

		for _, item in ipairs(items) do
			local slot = WIN.SlotOf(item)

			-- la segunda arma larga va a la secundaria si la hay
			if (slot == "primary" and bySlot.primary) then
				slot = "secondary"
			end

			bySlot[slot] = bySlot[slot] or {}
			table.insert(bySlot[slot], item)
		end
	end

	-- lo que no tiene ranura en este diseño va a OTROS
	local present = {}
	for _, slot in ipairs(self.slots) do present[slot.id] = true end

	for slot, items in pairs(bySlot) do
		if (!present[slot] and slot != "other") then
			bySlot.other = bySlot.other or {}

			for _, item in ipairs(items) do
				table.insert(bySlot.other, item)
			end

			bySlot[slot] = nil
		end
	end

	return bySlot
end

function SLOTS:ItemAt(mx, my)
	local bySlot = self:Assign()

	for _, box in ipairs(self.boxes) do
		if (mx >= box.x and mx < box.x + box.w and my >= box.y and my < box.y + box.h) then
			local items = bySlot[box.slot.id]
			if (!items or #items == 0) then return end

			-- OTROS enseña varios en fila
			local index = box.slot.many and (math.floor((mx - box.x) / (box.w / #items)) + 1) or 1
			return items[math.Clamp(index, 1, #items)]
		end
	end
end

function SLOTS:Paint(w, h)
	local bySlot = self:Assign()
	local hover = self.view.hoverItem

	for _, box in ipairs(self.boxes) do
		draw.SimpleText(L(box.slot.labelKey), "efgLootWin.Label", box.x, box.y - Sc(10), Col("textDim", Color(104, 106, 94)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(Col("cell", Color(18, 19, 17, 245)))
		surface.DrawRect(box.x, box.y, box.w, box.h)

		local items = bySlot[box.slot.id]

		if (items and #items > 0) then
			local each = box.w / #items

			for i, item in ipairs(items) do
				DrawItem(item, box.x + (i - 1) * each + 1, box.y + 1, each - 2, box.h - 2, hover == item)
			end
		else
			surface.SetDrawColor(Col("line", Color(58, 61, 54)))
			surface.DrawOutlinedRect(box.x, box.y, box.w, box.h, 1)
			draw.SimpleText(L("efgLootWinEmpty"), "efgLootWin.Small", box.x + box.w / 2, box.y + box.h / 2, Col("textDim", Color(104, 106, 94)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

function SLOTS:OnMousePressed(code)
	local mx, my = self:CursorPos()
	local item = self:ItemAt(mx, my)

	if (item) then
		ItemClick(item, "loot", code)
	end
end

function SLOTS:Think()
	if (!self:IsHovered()) then return end

	local mx, my = self:CursorPos()
	self.view.hoverItem = self:ItemAt(mx, my)
end

vgui.Register("efgxLootWinSlots", SLOTS, "DPanel")

-- ─── Ventana ────────────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgLootWin)) then ix.gui.efgLootWin:Remove() end
	ix.gui.efgLootWin = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)

	local top, pad = Sc(38), Sc(24)
	local half = ScrW() / 2

	self.localScroll = self:Add("DScrollPanel")
	self.localScroll:SetPos(pad, top + Sc(30))
	self.localScroll:SetSize(half - pad * 2, ScrH() - top - Sc(30) - Sc(40))

	self.lootScroll = self:Add("DScrollPanel")
	self.lootScroll:SetPos(half + pad, top + Sc(30))
	self.lootScroll:SetSize(half - pad * 2, ScrH() - top - Sc(30) - Sc(40))

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetSize(Sc(130), top)
	self.close:SetPos(ScrW() - Sc(140), 0)
	self.close.Paint = function(btn, w, h)
		draw.SimpleText(L("efgLootWinClose"), "efgLootWin.Label", w - Sc(8), h / 2, btn:IsHovered() and Col("accent", Color(227, 114, 45)) or Col("text", Color(200, 198, 180)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	self.close.DoClick = function() self:Remove() end

	self.localSig = ""
	self:BuildLocal()
end

function PANEL:SetLoot(entity, kind, title)
	self.entity = entity
	self.kind = kind
	self.title = title
end

-- firma de los inventarios propios: si cambian las bolsas, se rehace
local function OwnInventories()
	local list = {}
	local character = LocalPlayer():GetCharacter()
	if (!character) then return list end

	local main = character:GetInventory()

	if (main) then
		local w, h = main:GetSize()
		list[#list + 1] = {invID = main:GetID(), w = w, h = h, label = L("efgLootSectionPockets")}
	end

	local equip = ix.GetEquipInventory and ix.GetEquipInventory(character)

	for _, item in pairs(equip and equip:GetItems(true) or {}) do
		local bag = item:GetData("id") and ix.item.inventories[item:GetData("id")]

		if (bag) then
			local w, h = bag:GetSize()
			list[#list + 1] = {invID = bag:GetID(), w = w, h = h, label = item:GetName()}
		end
	end

	table.sort(list, function(a, b) return a.invID < b.invID end)

	return list
end

function PANEL:BuildLocal()
	local list = OwnInventories()
	local parts = {}

	for _, entry in ipairs(list) do parts[#parts + 1] = entry.invID end
	local sig = table.concat(parts, ",")

	if (sig == self.localSig) then return end
	self.localSig = sig

	self.localScroll:Clear()

	for _, entry in ipairs(list) do
		local grid = self.localScroll:Add("efgxLootWinGrid")
		grid:Setup(self, "local", entry.invID, entry.w, entry.h, entry.label)
		grid:Dock(TOP)
		grid:DockMargin(0, 0, 0, Sc(14))
	end
end

function PANEL:BuildLoot()
	self.lootScroll:Clear()

	local data = {title = self.title, sections = {}}

	for index, section in pairs(WIN.sections) do
		data.sections[#data.sections + 1] = section
		section.slot = index
	end

	table.sort(data.sections, function(a, b) return a.slot < b.slot end)

	local blocks = WIN.BuildLootLayout(self.kind, data)
	local maxWidth = self.lootScroll:GetWide() - Sc(16)

	for _, block in ipairs(blocks) do
		local section = data.sections[block.section]

		if (section) then
			local panel

			if (block.type == "slots") then
				panel = self.lootScroll:Add("efgxLootWinSlots")
				panel:Setup(self, section.invID, block.slots, maxWidth)
			else
				panel = self.lootScroll:Add("efgxLootWinGrid")
				panel:Setup(self, "loot", section.invID, section.w, section.h,
					block.labelKey and L(block.labelKey) or section.label, section.slot)
			end

			panel:Dock(TOP)
			panel:DockMargin(0, 0, 0, Sc(14))
		end
	end
end

function PANEL:Think()
	self.hoverItem = nil

	if (input.IsKeyDown(KEY_ESCAPE)) then
		if (gui.IsGameUIVisible()) then gui.HideGameUI() end
		self:Remove()
		return
	end

	if ((self.nextLocal or 0) < CurTime()) then
		self.nextLocal = CurTime() + 0.5
		self:BuildLocal()
	end
end

function PANEL:Paint(w, h)
	local top = Sc(38)

	surface.SetDrawColor(Col("bg0", Color(14, 15, 13)).r, Col("bg0", Color(14, 15, 13)).g, Col("bg0", Color(14, 15, 13)).b, 235)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(Col("bg2", Color(37, 39, 35, 245)))
	surface.DrawRect(0, 0, w, top)

	draw.SimpleText(self.title or "", "efgLootWin.Title", Sc(14), top / 2, Col("text", Color(200, 198, 180)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("efgLootWinYourGear"), "efgLootWin.Label", Sc(24), top + Sc(15), Col("text2", Color(154, 152, 136)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.upper(self.title or ""), "efgLootWin.Label", w / 2 + Sc(24), top + Sc(15), Col("text2", Color(154, 152, 136)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(Col("line", Color(58, 61, 54)))
	surface.DrawRect(w / 2, top, 1, h - top)

	-- pie: nombre del objeto bajo el ratón y ayuda
	surface.SetDrawColor(Col("bg2", Color(37, 39, 35, 245)))
	surface.DrawRect(0, h - Sc(32), w, Sc(32))

	local hover = self.hoverItem
	local text = hover and WIN.ItemName(hover) or L("efgLootWinHelp")

	draw.SimpleText(text, "efgLootWin.Small", Sc(14), h - Sc(16), hover and Col("text", Color(200, 198, 180)) or Col("textDim", Color(104, 106, 94)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:OnRemove()
	if (ix.gui.efgLootWin == self) then ix.gui.efgLootWin = nil end

	if (!self.serverClosed) then
		net.Start("efgLootWinClose")
		net.SendToServer()
	end

	WIN.sections = {}
end

vgui.Register("efgxLootWindow", PANEL, "EditablePanel")

-- ─── Red ────────────────────────────────────────────────────────────────────
local function ReadSections()
	local list = net.ReadTable()
	local old = WIN.sections or {}
	local sections = {}

	for _, meta in ipairs(list) do
		-- conserva la búsqueda en curso al refrescar
		local previous = old[meta.index]

		if (previous and previous.state == "searching" and meta.state == "hidden") then
			meta.state = "searching"
			meta.started, meta.duration, meta.revealed = previous.started, previous.duration, previous.revealed
		end

		sections[meta.index] = meta
	end

	WIN.sections = sections
end

net.Receive("efgLootWinOpen", function()
	local entity = net.ReadEntity()
	local kind = net.ReadString()
	local title = net.ReadString()

	WIN.sections = {}
	ReadSections()

	local window = vgui.Create("efgxLootWindow")
	window:SetLoot(entity, kind, title)
	window:BuildLoot()
end)

net.Receive("efgLootWinSections", function()
	net.ReadEntity()
	ReadSections()

	if (IsValid(ix.gui.efgLootWin)) then
		ix.gui.efgLootWin:BuildLoot()
	end
end)

net.Receive("efgLootWinSearchStart", function()
	local index = net.ReadUInt(8)
	local seconds = net.ReadFloat()
	local section = WIN.sections[index]

	if (section) then
		section.state = "searching"
		section.started = CurTime()
		section.duration = seconds
		section.revealed = {}
	end
end)

net.Receive("efgLootWinReveal", function()
	local index = net.ReadUInt(8)
	local x, y, w, h = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
	local section = WIN.sections[index]

	if (section and section.revealed) then
		section.revealed[#section.revealed + 1] = {x = x, y = y, w = w, h = h}
		surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav")
	end
end)

net.Receive("efgLootWinSearched", function()
	local index = net.ReadUInt(8)
	local section = WIN.sections[index]

	if (section) then
		section.state = "searched"
		section.revealed = nil
	end
end)

net.Receive("efgLootWinCancel", function()
	local index = net.ReadUInt(8)
	local section = WIN.sections[index]

	if (section) then
		section.state = "hidden"
		section.revealed = nil
	end
end)

net.Receive("efgLootWinClose", function()
	if (IsValid(ix.gui.efgLootWin)) then
		ix.gui.efgLootWin.serverClosed = true
		ix.gui.efgLootWin:Remove()
	end
end)
