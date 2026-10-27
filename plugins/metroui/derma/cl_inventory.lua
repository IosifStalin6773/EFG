
local RECEIVER_NAME = "ixInventoryItem"

-- Reenvía el scroll del ratón al panel padre (permite que un DScrollPanel
-- contenedor reciba la rueda aunque el cursor esté sobre un slot o ítem).
local function BubbleMouseWheel(panel, delta)
	local parent = panel:GetParent()

	if (IsValid(parent) and parent.OnMouseWheeled) then
		return parent:OnMouseWheeled(delta)
	end
end

-- The queue for the rendered icons.
ICON_RENDER_QUEUE = ICON_RENDER_QUEUE or {}

-- To make making inventory variant, This must be followed up.
local function RenderNewIcon(panel, itemTable)
	local model = itemTable:GetModel()

	-- re-render icons
	if ((itemTable.iconCam and !ICON_RENDER_QUEUE[string.lower(model)]) or itemTable.forceRender) then
		local ent = panel.Icon.Entity
		if (IsValid(ent)) then
			ent:SetPos(Vector(0, 0, 0))
			ent:SetAngles(Angle(0, 0, 0))
		end

		local iconCam = itemTable.iconCam
		iconCam = {
			cam_pos = iconCam.pos,
			cam_ang = iconCam.ang,
			cam_fov = iconCam.fov,
		}
		ICON_RENDER_QUEUE[string.lower(model)] = true

		panel.Icon:RebuildSpawnIconEx(
			iconCam
		)
	end
end

local function InventoryAction(action, itemID, invID, data)
	net.Start("ixInventoryAction")
		net.WriteString(action)
		net.WriteUInt(itemID, 32)
		net.WriteUInt(invID, 32)
		net.WriteTable(data or {})
	net.SendToServer()
end

-- Devuelve los paneles de inventario actualmente visibles (jugador, storage/cuerpo, bolsas)
-- para poder transferir ítems entre ellos con ctrl + click.
local function GetOpenInventoryPanels()
	local panels = {}

	if (IsValid(ix.gui.openedStorage)) then
		local storage = ix.gui.openedStorage.storageInventory

		if (IsValid(storage) and storage.invID) then
			panels[#panels + 1] = storage
		end
	end

	if (IsValid(ix.gui.inv1) and ix.gui.inv1.invID) then
		panels[#panels + 1] = ix.gui.inv1

		if (ix.gui.inv1.childPanels) then
			for _, v in ipairs(ix.gui.inv1.childPanels) do
				if (IsValid(v) and v.invID and v != ix.gui.inv1) then
					panels[#panels + 1] = v
				end
			end
		end
	end

	return panels
end

local PANEL = {}

AccessorFunc(PANEL, "itemTable", "ItemTable")
AccessorFunc(PANEL, "inventoryID", "InventoryID")

function PANEL:Init()
	self:Droppable(RECEIVER_NAME)
end

function PANEL:OnMousePressed(code)
	-- rejilla bloqueada por un filtro de categoría: solo lectura, no se mueven ítems
	-- (la selección de DETALLES sigue funcionando porque va por el Think del panel).
	local invPanel = self:GetParent()
	if (IsValid(invPanel) and invPanel.bFilterLocked) then return end

	if (code == MOUSE_LEFT and self:IsDraggable()) then
		if (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) then
			self:QuickTransfer()
			return
		end

		self:MouseCapture(true)
		self:DragMousePress(code)

		self.clickX, self.clickY = input.GetCursorPos()
	elseif (code == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick()
	end
end

function PANEL:OnMouseReleased(code)
	-- move the item into the world if we're dropping on something that doesn't handle inventory item drops
	if (!dragndrop.m_ReceiverSlot or dragndrop.m_ReceiverSlot.Name != RECEIVER_NAME) then
		self:OnDrop(dragndrop.IsDragging())
	end

	self:DragMouseRelease(code)
	self:SetZPos(99)
	self:MouseCapture(false)
end

-- Ctrl + click izquierdo: envía el ítem al primer espacio libre de otro
-- inventario abierto (storage, cuerpo, bolsa, etc.).
-- Para ítems stackeables, prioriza combinar con un stack existente.
function PANEL:QuickTransfer()
	local item = self.itemTable

	if (!item or !self.inventoryID) then return end

	-- Stackeable: por maxstack (recursos) o marcado como ilimitado (balas).
	local bStackable = item.functions.combine and
		(item.unlimitedStack or (item.maxstack and item.maxstack > 1))

	if (bStackable) then
		for _, target in ipairs(GetOpenInventoryPanels()) do
			if (target.invID == self.inventoryID) then continue end

			local targetInv = ix.item.inventories[target.invID]
			if (targetInv and targetInv.slots) then
				for _, row in pairs(targetInv.slots) do
					for _, slot in pairs(row) do
						if (slot.id) then
							local other = ix.item.instances[slot.id]
							if (other and other.uniqueID == item.uniqueID and other.id != item.id) then
								local otherAmt = other:GetData("Amount", 1)
								if (item.unlimitedStack or otherAmt < item.maxstack) then
									surface.PlaySound("ui/buttonclickrelease.wav")
									InventoryAction("combine", other.id, target.invID, {item.id})
									return
								end
							end
						end
					end
				end
			end
		end
	end

	for _, target in ipairs(GetOpenInventoryPanels()) do
		if (target.invID == self.inventoryID) then continue end

		local x, y = target:FindEmptySlot(item.width or 1, item.height or 1, self)

		if (x) then
			surface.PlaySound("ui/buttonclickrelease.wav")
			self:Move(x, y, target)
			return
		end
	end
end

function PANEL:DoRightClick()
	local itemTable = self.itemTable
	local inventory = self.inventoryID

	if (itemTable and inventory) then
		itemTable.player = LocalPlayer()

		local menu = DermaMenu()
		local override = hook.Run("CreateItemInteractionMenu", self, menu, itemTable)

		if (override == true) then
			if (menu.Remove) then
				menu:Remove()
			end

			return
		end

		for k, v in SortedPairs(itemTable.functions) do
			if (k == "drop" or k == "combine" or (v.OnCanRun and v.OnCanRun(itemTable) == false)) then
				continue
			end

			-- is Multi-Option Function
			if (v.isMulti) then
				local subMenu, subMenuOption = menu:AddSubMenu(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true

						if (v.OnClick) then
							send = v.OnClick(itemTable)
						end

						if (v.sound) then
							surface.PlaySound(v.sound)
						end

						if (send != false) then
							InventoryAction(k, itemTable.id, inventory)
						end
					itemTable.player = nil
				end)
				subMenuOption:SetImage(v.icon or "icon16/brick.png")

				if (v.multiOptions) then
					local options = isfunction(v.multiOptions) and v.multiOptions(itemTable, LocalPlayer()) or v.multiOptions

					for _, sub in pairs(options) do
						subMenu:AddOption(L(sub.name or "subOption"), function()
							itemTable.player = LocalPlayer()
								local send = true

								if (sub.OnClick) then
									send = sub.OnClick(itemTable)
								end

								if (sub.sound) then
									surface.PlaySound(sub.sound)
								end

								if (send != false) then
									InventoryAction(k, itemTable.id, inventory, sub.data)
								end
							itemTable.player = nil
						end)
					end
				end
			else
				menu:AddOption(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true

						if (v.OnClick) then
							send = v.OnClick(itemTable)
						end

						if (v.sound) then
							surface.PlaySound(v.sound)
						end

						if (send != false) then
							InventoryAction(k, itemTable.id, inventory)
						end
					itemTable.player = nil
				end):SetImage(v.icon or "icon16/brick.png")
			end
		end

		-- we want drop to show up as the last option
		local info = itemTable.functions.drop

		if (info and info.OnCanRun and info.OnCanRun(itemTable) != false) then
			menu:AddOption(L(info.name or "drop"), function()
				itemTable.player = LocalPlayer()
					local send = true

					if (info.OnClick) then
						send = info.OnClick(itemTable)
					end

					if (info.sound) then
						surface.PlaySound(info.sound)
					end

					if (send != false) then
						InventoryAction("drop", itemTable.id, inventory)
					end
				itemTable.player = nil
			end):SetImage(info.icon or "icon16/brick.png")
		end

		menu:Open()
		itemTable.player = nil
	end
end

function PANEL:OnDrop(bDragging, inventoryPanel, inventory, gridX, gridY)
	local item = self.itemTable

	if (!item or !bDragging) then
		return
	end

	if (!IsValid(inventoryPanel)) then
		local inventoryID = self.inventoryID

		if (inventoryID) then
			InventoryAction("drop", item.id, inventoryID, {})
		end
	elseif (inventoryPanel:IsAllEmpty(gridX, gridY, item.width, item.height, self)) then
		local oldX, oldY = self.gridX, self.gridY

		if (oldX != gridX or oldY != gridY or self.inventoryID != inventoryPanel.invID) then
			self:Move(gridX, gridY, inventoryPanel)
		end
	elseif (inventoryPanel.combineItem) then
		local combineItem = inventoryPanel.combineItem
		local inventoryID = combineItem.invID

		if (inventoryID) then
			combineItem.player = LocalPlayer()
				if (combineItem.functions.combine.sound) then
					surface.PlaySound(combineItem.functions.combine.sound)
				end

				InventoryAction("combine", combineItem.id, inventoryID, {item.id})
			combineItem.player = nil
		end
	end
end

function PANEL:Move(newX, newY, givenInventory, bNoSend)
	local iconSize = givenInventory.iconSize
	local oldX, oldY = self.gridX, self.gridY
	local oldParent = self:GetParent()

	if (givenInventory:OnTransfer(oldX, oldY, newX, newY, oldParent, bNoSend) == false) then
		return
	end

	local x = (newX - 1) * iconSize + 4
	local y = (newY - 1) * iconSize + givenInventory:GetPadding(2) - (givenInventory.scrollY or 0)

	-- al mover entre DOS rejillas distintas (cofre <-> inventario), esta misma
	-- ixItemIcon se reparenta a givenInventory pero seguía quedando referenciada en
	-- oldParent.panels[id] con gridX/gridY ya apuntando a la rejilla nueva: el próximo
	-- RebuildItems del panel viejo (ixStorageView reaplica el filtro cada 0.3s) indexaba
	-- oldParent.slots[gridX][gridY] fuera de rango -> "attempt to index a nil value".
	if (IsValid(oldParent) and oldParent != givenInventory and oldParent.panels and self.itemTable) then
		oldParent.panels[self.itemTable.id] = nil

		-- ...y REGISTRARLA en la rejilla nueva. Si no, cuando el servidor confirma la
		-- transferencia con ixInventorySet -> AddIcon, el deduplicado de AddIcon
		-- (self.panels[itemID]) no encuentra este icono optimista y crea uno SEGUNDO
		-- encima: el ítem aparece DUPLICADO tras arrastrar o hacer ctrl+click.
		if (givenInventory.panels) then
			givenInventory.panels[self.itemTable.id] = self
		end
	end

	self.gridX = newX
	self.gridY = newY

	self:SetParent(givenInventory)
	self:SetPos(x, y)

	if (self.slots) then
		for _, v in ipairs(self.slots) do
			if (IsValid(v) and v.item == self) then
				v.item = nil
			end
		end
	end

	self.slots = {}

	for currentX = 1, self.gridW do
		for currentY = 1, self.gridH do
			local slot = givenInventory.slots[self.gridX + currentX - 1][self.gridY + currentY - 1]

			slot.item = self
			self.slots[#self.slots + 1] = slot
		end
	end
end

-- Nombre corto del objeto (esquina superior derecha, como en EFT), recortado
-- hasta que quepa dentro de la celda
local function shortName(itemTable)
	if (itemTable.shortName) then return itemTable.shortName end
	local name = itemTable.GetName and itemTable:GetName() or itemTable.name or ""
	return tostring(name)
end

local fitCache = {}

local function fitName(name, maxW)
	local key = name .. "|" .. maxW
	if (fitCache[key]) then return fitCache[key] end

	surface.SetFont("efgInv.CellName")
	local text = name

	if (surface.GetTextSize(text) > maxW) then
		text = name:match("^(%S+)") or name

		while (#text > 1 and surface.GetTextSize(text .. ".") > maxW) do
			text = text:sub(1, -2)
		end

		if (text != name) then text = text .. "." end
	end

	fitCache[key] = text
	return text
end

function PANEL:PaintOver(width, height)
	local itemTable = self.itemTable

	if (itemTable) then
		draw.SimpleText(fitName(shortName(itemTable), width - 6), "efgInv.CellName", width - 3, 1,
			Color(205, 203, 190), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		if (itemTable.PaintOver) then
			itemTable.PaintOver(self, itemTable, width, height)
		end

		if (ix.efgui) then
			ix.efgui.DrawRarity(1, 1, width - 2, height - 2, itemTable.rarity)
		end
	end

	-- borde claro al pasar el ratón
	if (self:IsHovered()) then
		surface.SetDrawColor(199, 197, 179, 140)
		surface.DrawOutlinedRect(1, 1, width - 2, height - 2, 1)
	end
end

function PANEL:ExtraPaint(width, height)
end

-- Fondo del objeto (igual para todas las categorías) y borde fino
function PANEL:Paint(width, height)
	local itemTable = self.itemTable
	local UI = ix.efgui
	local color = (UI and itemTable) and UI.GetItemColor(itemTable) or Color(40, 42, 42)

	-- fondo semitransparente (el grunge se ve detrás) y borde tenue
	surface.SetDrawColor(color.r, color.g, color.b, 170)
	surface.DrawRect(1, 1, width - 2, height - 2)
	surface.SetDrawColor(self:IsHovered() and Color(255, 255, 255, 30) or Color(0, 0, 0, 0))
	surface.DrawRect(1, 1, width - 2, height - 2)
	-- bisel en relieve del objeto y borde tenue
	if (UI and UI.DrawBevel) then UI.DrawBevel(1, 1, width - 2, height - 2, false) end
	surface.SetDrawColor(0, 0, 0, 160)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	self:ExtraPaint(width, height)
end

PANEL.OnMouseWheeled = BubbleMouseWheel

vgui.Register("ixItemIcon", PANEL, "SpawnIcon")

PANEL = {}
DEFINE_BASECLASS("DFrame")

AccessorFunc(PANEL, "iconSize", "IconSize", FORCE_NUMBER)
AccessorFunc(PANEL, "bHighlighted", "Highlighted", FORCE_BOOL)

function PANEL:Init()
	self:SetIconSize(SScale(67/3))
	self:ShowCloseButton(false)
	self:SetDraggable(true)
	self:SetSizable(true)
	self:SetTitle(L"inv")
	self:Receiver(RECEIVER_NAME, self.ReceiveDrop)

	self.btnMinim:SetVisible(false)
	self.btnMinim:SetMouseInputEnabled(false)
	self.btnMaxim:SetVisible(false)
	self.btnMaxim:SetMouseInputEnabled(false)

	self.panels = {}
end

function PANEL:GetPadding(index)
	return select(index, self:GetDockPadding())
end

function PANEL:SetTitle(text)
	if (text == nil) then
		self.oldPadding = {self:GetDockPadding()}

		self.lblTitle:SetText("")
		self.lblTitle:SetVisible(false)

		self:DockPadding(5, 5, 5, 5)
	else
		if (self.oldPadding) then
			self:DockPadding(unpack(self.oldPadding))
			self.oldPadding = nil
		end

		BaseClass.SetTitle(self, text)
	end
end

function PANEL:FitParent(invWidth, invHeight)
	local parent = self:GetParent()

	if (!IsValid(parent)) then
		return
	end

	local width, height = parent:GetSize()
	local padding = 4
	local iconSize

	if (invWidth > invHeight) then
		iconSize = (width - padding * 2) / invWidth
	elseif (invHeight > invWidth) then
		iconSize = (height - padding * 2) / invHeight
	else
		-- we use height because the titlebar will make it more tall than it is wide
		iconSize = (height - padding * 2) / invHeight - 4
	end

	self:SetSize(iconSize * invWidth + padding * 2, iconSize * invHeight + padding * 2)
	self:SetIconSize(iconSize)
end

function PANEL:OnRemove()
	if (self.childPanels) then
		for _, v in ipairs(self.childPanels) do
			if (v != self) then
				v:Remove()
			end
		end
	end
end

function PANEL:ViewOnly()
	self.viewOnly = true

	for _, icon in pairs(self.panels) do
		icon.OnMousePressed = nil
		icon.OnMouseReleased = nil
		icon.doRightClick = nil
	end
end

function PANEL:SetInventory(inventory, bFitParent)
	if (inventory.slots) then
		local invWidth, invHeight = inventory:GetSize()
		self.invID = inventory:GetID()

		if (IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels and inventory != LocalPlayer():GetCharacter():GetInventory()) then
			self:SetIconSize(ix.gui.inv1:GetIconSize())
			self:SetPaintedManually(true)
			self.bNoBackgroundBlur = true

			ix.gui.inv1.childPanels[#ix.gui.inv1.childPanels + 1] = self
		elseif (bFitParent) then
			self:FitParent(invWidth, invHeight)
		else
			self:SetSize(self.iconSize, self.iconSize)
		end

		self:SetGridSize(invWidth, invHeight)

		for x, items in pairs(inventory.slots) do
			for y, data in pairs(items) do
				if (!data.id) then continue end

				local item = ix.item.instances[data.id]

				if (item and !IsValid(self.panels[item.id])) then
					local icon = self:AddIcon(item:GetModel() or "models/props_junk/popcan01a.mdl",
						x, y, item.width, item.height, item:GetSkin())

					if (IsValid(icon)) then
						-- bNoItemTooltip: escape hatch para paneles que no quieran el tooltip flotante.
						if (not self.bNoItemTooltip) then
							icon:SetHelixTooltip(function(tooltip)
								ix.hud.PopulateItemTooltip(tooltip, item)
							end)
						end

						self.panels[item.id] = icon
					end
				end
			end
		end
	end
end

function PANEL:SetGridSize(w, h)
	local iconSize = self.iconSize
	local newWidth = w * iconSize + 8
	local newHeight = h * iconSize + self:GetPadding(2) + self:GetPadding(4)

	self.gridW = w
	self.gridH = h

	self:SetSize(newWidth, newHeight)
	self:SetMinWidth(newWidth)
	self:SetMinHeight(newHeight)
	self:BuildSlots()
end

function PANEL:PerformLayout(width, height)
	BaseClass.PerformLayout(self, width, height)

	if (self.Sizing and self.gridW and self.gridH) then
		local newWidth = (width - 8) / self.gridW
		local newHeight = (height - self:GetPadding(2) + self:GetPadding(4)) / self.gridH

		self:SetIconSize((newWidth + newHeight) / 2)
		self:RebuildItems()
	end
end

function PANEL:BuildSlots()
	local iconSize = self.iconSize

	self.slots = self.slots or {}

	for _, v in ipairs(self.slots) do
		for _, v2 in ipairs(v) do
			v2:Remove()
		end
	end

	self.slots = {}

	for x = 1, self.gridW do
		self.slots[x] = {}

		for y = 1, self.gridH do
			local slot = self:Add("DPanel")
			slot:SetZPos(-999)
			slot.gridX = x
			slot.gridY = y
			slot:SetPos((x - 1) * iconSize + 4, (y - 1) * iconSize + self:GetPadding(2))
			slot:SetSize(iconSize, iconSize)
			slot.OnMouseWheeled = BubbleMouseWheel
			slot.Paint = function(panel, width, height)
				derma.SkinHook("Paint", "InventorySlot", panel, width, height)
			end

			self.slots[x][y] = slot
		end
	end
end

function PANEL:RebuildItems()
	local iconSize = self.iconSize
	local scrollY = self.scrollY or 0

	for x = 1, self.gridW do
		for y = 1, self.gridH do
			local slot = self.slots[x][y]

			slot:SetPos((x - 1) * iconSize + 4, (y - 1) * iconSize + self:GetPadding(2) - scrollY)
			slot:SetSize(iconSize, iconSize)
		end
	end

	for _, v in pairs(self.panels) do
		local slot = IsValid(v) and self.slots[v.gridX] and self.slots[v.gridX][v.gridY]

		if (slot) then
			v:SetPos(slot:GetPos())
			v:SetSize(v.gridW * iconSize, v.gridH * iconSize)
		end
	end
end

function PANEL:PaintDragPreview(width, height, mouseX, mouseY, itemPanel)
	local iconSize = self.iconSize
	local item = itemPanel:GetItemTable()

	if (item) then
		local inventory = ix.item.inventories[self.invID]
		local dropX = math.ceil((mouseX - 4 - (itemPanel.gridW - 1) * 32) / iconSize)
		local dropY = math.ceil((mouseY - self:GetPadding(2) + (self.scrollY or 0) - (itemPanel.gridH - 1) * 32) / iconSize)

		local hoveredPanel = vgui.GetHoveredPanel()

		if (IsValid(hoveredPanel) and hoveredPanel != itemPanel and hoveredPanel.GetItemTable) then
			local hoveredItem = hoveredPanel:GetItemTable()

			if (hoveredItem) then
				local info = hoveredItem.functions.combine

				if (info and info.OnCanRun and info.OnCanRun(hoveredItem, {item.id}) != false) then
					surface.SetDrawColor(ix.efgui and ColorAlpha(ix.efgui.color.info, 40) or ColorAlpha(derma.GetColor("Info", self, Color(200, 0, 0)), 20))
					surface.DrawRect(
						hoveredPanel.x,
						hoveredPanel.y,
						hoveredPanel:GetWide(),
						hoveredPanel:GetTall()
					)

					self.combineItem = hoveredItem

					return
				end
			end
		end

		self.combineItem = nil

		-- don't draw grid if we're dragging it out of bounds
		if (inventory) then
			local invWidth, invHeight = inventory:GetSize()

			if (dropX < 1 or dropY < 1 or
				dropX + itemPanel.gridW - 1 > invWidth or
				dropY + itemPanel.gridH - 1 > invHeight) then
				return
			end
		end

		local bEmpty = true

		for x = 0, itemPanel.gridW - 1 do
			for y = 0, itemPanel.gridH - 1 do
				local x2 = dropX + x
				local y2 = dropY + y

				bEmpty = self:IsEmpty(x2, y2, itemPanel)

				if (!bEmpty) then
					-- no need to iterate further since we know something is blocking the hovered grid cells, break through both loops
					goto finish
				end
			end
		end

		::finish::
		local px = (dropX - 1) * iconSize + 4
		local py = (dropY - 1) * iconSize + self:GetPadding(2) - (self.scrollY or 0)

		if (ix.efgui) then
			-- destino válido en verde, inválido en rojo (estados de Pizarra)
			ix.efgui.DrawCell(px, py, itemPanel:GetWide(), itemPanel:GetTall(), bEmpty and "valid" or "invalid")
		else
			surface.SetDrawColor(ColorAlpha(derma.GetColor(bEmpty and "Success" or "Error", self, Color(200, 0, 0)), 20))
			surface.DrawRect(px, py, itemPanel:GetWide(), itemPanel:GetTall())
		end
	end
end

function PANEL:PaintOver(width, height)
	local panel = self.previewPanel

	if (IsValid(panel)) then
		local itemPanel = (dragndrop.GetDroppable() or {})[1]

		if (IsValid(itemPanel)) then
			self:PaintDragPreview(width, height, self.previewX, self.previewY, itemPanel)
		end
	end

	self.previewPanel = nil
end

function PANEL:IsEmpty(x, y, this)
	return (self.slots[x] and self.slots[x][y]) and (!IsValid(self.slots[x][y].item) or self.slots[x][y].item == this)
end

function PANEL:IsAllEmpty(x, y, width, height, this)
	for x2 = 0, width - 1 do
		for y2 = 0, height - 1 do
			if (!self:IsEmpty(x + x2, y + y2, this)) then
				return false
			end
		end
	end

	return true
end

-- Busca el primer hueco libre que pueda contener un ítem de tamaño width x height.
function PANEL:FindEmptySlot(width, height, this)
	for x = 1, (self.gridW or 0) - width + 1 do
		for y = 1, (self.gridH or 0) - height + 1 do
			if (self:IsAllEmpty(x, y, width, height, this)) then
				return x, y
			end
		end
	end
end

function PANEL:OnTransfer(oldX, oldY, x, y, oldInventory, noSend)
	local inventories = ix.item.inventories
	local inventory = inventories[oldInventory.invID]
	local inventory2 = inventories[self.invID]
	local item

	if (inventory) then
		item = inventory:GetItemAt(oldX, oldY)

		if (!item) then
			return false
		end

		if (hook.Run("CanTransferItem", item, inventories[oldInventory.invID], inventories[self.invID]) == false) then
			return false, "notAllowed"
		end

		if (item.CanTransfer and
			item:CanTransfer(inventory, inventory != inventory2 and inventory2 or nil) == false) then
			return false
		end
	end

	if (!noSend) then
		net.Start("ixInventoryMove")
			net.WriteUInt(oldX, 6)
			net.WriteUInt(oldY, 6)
			net.WriteUInt(x, 6)
			net.WriteUInt(y, 6)
			net.WriteUInt(oldInventory.invID, 32)
			net.WriteUInt(self != oldInventory and self.invID or oldInventory.invID, 32)
		net.SendToServer()
	end

	if (inventory) then
		inventory.slots[oldX][oldY] = nil
	end

	if (item and inventory2) then
		inventory2.slots[x] = inventory2.slots[x] or {}
		inventory2.slots[x][y] = item
	end
end

function PANEL:AddIcon(model, x, y, w, h, skin)
	local iconSize = self.iconSize

	w = w or 1
	h = h or 1

	if (self.slots[x] and self.slots[x][y]) then
		local panel = self:Add("ixItemIcon")
		panel:SetSize(w * iconSize, h * iconSize)
		panel:SetZPos(999)
		panel:InvalidateLayout(true)
		panel:SetModel(model, skin)
		panel:SetPos(self.slots[x][y]:GetPos())
		panel.gridX = x
		panel.gridY = y
		panel.gridW = w
		panel.gridH = h

		local inventory = ix.item.inventories[self.invID]

		if (!inventory) then
			return
		end

		local itemTable = inventory:GetItemAt(panel.gridX, panel.gridY)

		panel:SetInventoryID(inventory:GetID())
		panel:SetItemTable(itemTable)

		if (self.panels[itemTable:GetID()]) then
			self.panels[itemTable:GetID()]:Remove()
		end

		if (ix.efg and ix.efg.icons and ix.efg.icons.Get(itemTable)) then
			-- icono 2D (efg_icons); si falta la imagen se usa el modelo como siempre
			panel.Icon:SetVisible(false)
			panel.ExtraPaint = function(this, panelX, panelY)
				ix.efg.icons.Draw(itemTable, 2, 2, panelX - 4, panelY - 4)
			end
		elseif (itemTable.iconCam) then
			panel.Icon:SetVisible(false)

			local mdl = vgui.Create("DModelPanel", panel)
			mdl:SetSize(panel:GetSize())
			mdl:SetModel(itemTable:GetModel())
			mdl:SetCamPos(itemTable.iconCam.pos)
			mdl:SetLookAng(itemTable.iconCam.ang)
			mdl:SetFOV(itemTable.iconCam.fov)
			mdl:SetMouseInputEnabled(false)
			mdl:SetKeyboardInputEnabled(false)
			mdl.LayoutEntity = function() end
			mdl.Entity:SetPos(Vector(0, 0, 0))
			mdl.Entity:SetAngles(Angle(0, 0, 0))
		elseif (itemTable.exRender) then
			panel.Icon:SetVisible(false)
			panel.ExtraPaint = function(this, panelX, panelY)
				local exIcon = ikon:GetIcon(itemTable.uniqueID)
				if (exIcon) then
					surface.SetMaterial(exIcon)
					surface.SetDrawColor(color_white)
					surface.DrawTexturedRect(0, 0, panelX, panelY)
				else
					ikon:renderIcon(
						itemTable.uniqueID,
						itemTable.width,
						itemTable.height,
						itemTable:GetModel(),
						itemTable.iconCam
					)
				end
			end
		else
			RenderNewIcon(panel, itemTable)
		end

		panel.slots = {}

		for i = 0, w - 1 do
			for i2 = 0, h - 1 do
				local slot = self.slots[x + i] and self.slots[x + i][y + i2]

				if (IsValid(slot)) then
					slot.item = panel
					panel.slots[#panel.slots + 1] = slot
				else
					for _, v in ipairs(panel.slots) do
						v.item = nil
					end

					panel:Remove()

					return
				end
			end
		end

		return panel
	end
end

function PANEL:ReceiveDrop(panels, bDropped, menuIndex, x, y)
	-- rejilla bloqueada por un filtro: no se aceptan ítems (ver bFilterLocked)
	if (self.bFilterLocked) then
		self.previewPanel = nil
		return
	end

	local panel = panels[1]

	if (!IsValid(panel)) then
		self.previewPanel = nil
		return
	end

	if (bDropped) then
		local inventory = ix.item.inventories[self.invID]

		if (inventory and panel.OnDrop) then
			local dropX = math.ceil((x - 4 - (panel.gridW - 1) * 32) / self.iconSize)
			local dropY = math.ceil((y - self:GetPadding(2) + (self.scrollY or 0) - (panel.gridH - 1) * 32) / self.iconSize)

			panel:OnDrop(true, self, inventory, dropX, dropY)
		end

		self.previewPanel = nil
	else
		self.previewPanel = panel
		self.previewX = x
		self.previewY = y
	end
end

function PANEL:OnMouseWheeled(delta)
	local scrollMax = self.scrollMax or 0

	if (scrollMax > 0) then
		self.scrollY = math.Clamp((self.scrollY or 0) - delta * self.iconSize, 0, scrollMax)
		self:RebuildItems()

		return true
	end

	return BubbleMouseWheel(self, delta)
end

vgui.Register("ixInventory", PANEL, "DFrame")

hook.Add("CreateMenuButtons", "ixInventory", function(tabs)
	if (hook.Run("CanPlayerViewInventory") == false) then
		return
	end

	tabs["inv"] = {
		icon = 'efgui/icons/icon_inventory64.png',
		name = 'Inventario',
		bDefault = true,
		Create = function(info, container)
			local char = LocalPlayer():GetCharacter()
			if (not char) then return container end

			local inv    = char:GetInventory()
			local sw, sh = container:GetSize()
			local GAP        = 5
			local SECTION_H  = 20
			local MIN_ICON   = 44

			-- ── helpers (paleta idéntica a ixMetroInventory) ───────────────
			local function drawBg(w, h, r, g, b, a, border)
				draw.RoundedBox(0, 0, 0, w, h, Color(r, g, b, a or 220))
				if (border) then
					surface.SetDrawColor(50, 50, 50, 200)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			local function drawSectionHdr(w, h, text)
				draw.RoundedBox(6, 0, 0, w, h, Color(18, 20, 20, 255))
				surface.SetFont("ixSmallFont")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(199, 190, 150, 255)
				surface.SetTextPos(8, h / 2 - th / 2)
				surface.DrawText(text)
			end

			-- ── datos de facción ───────────────────────────────────────────
			local factionIndex = char:GetFaction()
			local factionData  = ix.faction and ix.faction.indices and ix.faction.indices[factionIndex]
			local factionColor = (factionData and factionData.color) or Color(160, 160, 160)
			local factionName  = (factionData and factionData.name) or "Desconocida"

			local ry = 0

			-- ── filas de info (Facción, Oficio, Dinero) ────────────────────
			local function addInfoRow(label, value, valueColor)
				local row = container:Add("DPanel")
				row:SetPos(GAP, ry)
				row:SetSize(sw - GAP * 2, 24)
				row.Paint = function(_, w, h)
					surface.SetDrawColor(28, 28, 28, 200)
					surface.DrawRect(0, 0, w, h)
				end

				local kl = row:Add("DLabel")
				kl:SetPos(6, 0)
				kl:SetSize(80, 24)
				kl:SetFont("ixSmallFont")
				kl:SetTextColor(Color(185, 148, 70))
				kl:SetContentAlignment(4)
				kl:SetText(label)

				local vl = row:Add("DLabel")
				vl:SetPos(88, 0)
				vl:SetSize(sw - GAP * 2 - 96, 24)
				vl:SetFont("ixSmallFont")
				vl:SetTextColor(valueColor or Color(210, 210, 210))
				vl:SetContentAlignment(4)
				vl:SetText(value)

				ry = ry + 27
			end

			addInfoRow("Facción", factionName, Color(factionColor.r, factionColor.g, factionColor.b))

			local oficio = char.GetOficio and char:GetOficio()
			if (oficio and oficio != "ninguno") then
				local lista  = ix.oficios and ix.oficios.lista
				local nombre = (lista and lista[oficio]) or oficio
				local tier   = (char.GetOficioTier and char:GetOficioTier()) or 0
				addInfoRow("Oficio", nombre .. "  (Tier " .. tier .. ")")
			end

			addInfoRow("Dinero", tostring(char:GetMoney()) .. " " .. (ix.currency.plural or "Balas"), Color(215, 175, 55))
			ry = ry + GAP

			-- ── cabecera "INVENTARIO" ──────────────────────────────────────
			local invHdr = container:Add("DPanel")
			invHdr:SetPos(GAP, ry)
			invHdr:SetSize(sw - GAP * 2, SECTION_H)
			invHdr.Paint = function(_, w, h) drawSectionHdr(w, h, "INVENTARIO") end
			ry = ry + SECTION_H + GAP

			-- ── cálculo de espacio para el grid ────────────────────────────
			-- Detección de la mochila primaria (metrobags) para reservarle sitio.
			local bagItem, bagInv, bagW, bagH
			if (ix.plugin.Get("metrobags") and char.GetPrimaryBag) then
				local primaryBag = char:GetPrimaryBag()
				if (primaryBag) then
					local bagId     = primaryBag:GetData("id")
					local inventory = bagId and ix.item.inventories[bagId]
					if (inventory and inventory.slots) then
						bagItem    = primaryBag
						bagInv     = inventory
						bagW, bagH = inventory:GetSize()
					end
				end
			end

			local wBarH    = 26
			local combH    = 80   -- panel combinado descripción + misión (lado a lado)
			local attHdrH  = SECTION_H
			local attScrH  = 90

			-- Reserva de espacio para la sección de la mochila (si existe).
			local bagHdrH    = SECTION_H
			local bagIconSz  = 0
			local bagReserve = 0
			if (bagInv and bagW and bagW > 0 and bagH and bagH > 0) then
				local maxBagSection = math.floor((sh - ry) * 0.32)
				bagIconSz = math.min(
					math.floor((sw - GAP * 2) / bagW),
					math.floor(maxBagSection / bagH)
				)
				bagIconSz  = math.max(bagIconSz, 28)
				bagReserve = bagHdrH + GAP + (bagH * bagIconSz + 8) + GAP
			end

			local invAreaH = sh - ry - wBarH - GAP - combH - GAP - attHdrH - GAP - attScrH - GAP * 2 - bagReserve

			-- ── grid de inventario ─────────────────────────────────────────
			local invPanel = container:Add("ixInventory")
			invPanel:SetPos(GAP, ry)
			invPanel:SetDraggable(false)
			invPanel:SetSizable(false)
			invPanel:SetTitle(nil)
			invPanel.bNoBackgroundBlur = true
			invPanel.childPanels = {}
			invPanel.Paint = function(_, w, h)
				draw.RoundedBox(3, 0, 0, w, h, Color(26, 26, 26, 210))
			end

			if (inv) then
				local invW, invH = inv:GetSize()
				invW = invW or 6
				invH = invH or 6
				local iconSize = math.min(
					math.floor(invAreaH / invH),
					math.floor((sw - GAP * 4) / invW)
				)
				iconSize = math.max(iconSize, MIN_ICON)
				invPanel:SetIconSize(iconSize)
				invPanel:SetInventory(inv)
			end

			ix.gui.menuInventoryContainer = container
			ix.gui.inv1 = invPanel

			ry = ry + invPanel:GetTall() + GAP

			-- ── sección de la mochila (siempre visible si hay bolsa) ───────
			if (bagInv) then
				local bagName = (bagItem.GetName and bagItem:GetName()) or L(bagItem.name)

				local bagHdr = container:Add("DPanel")
				bagHdr:SetPos(GAP, ry)
				bagHdr:SetSize(sw - GAP * 2, bagHdrH)
				bagHdr.Paint = function(_, w, h)
					draw.RoundedBox(6, 0, 0, w, h, Color(18, 20, 20, 255))
					surface.SetFont("ixSmallFont")
					surface.SetTextColor(199, 190, 150, 255)
					local _, th = surface.GetTextSize("MOCHILA")
					surface.SetTextPos(8, h / 2 - th / 2)
					surface.DrawText("MOCHILA")
					-- Nombre de la mochila alineado a la derecha
					surface.SetTextColor(150, 120, 70, 255)
					local nw, nh = surface.GetTextSize(bagName)
					surface.SetTextPos(w - nw - 8, h / 2 - nh / 2)
					surface.DrawText(bagName)
				end
				ry = ry + bagHdrH + GAP

				-- Evitamos la rama automática de childPanels (que fuerza
				-- SetPaintedManually y comparte iconSize) para que el grid se
				-- pinte con normalidad y con su propio tamaño.
				local savedChild = invPanel.childPanels
				invPanel.childPanels = nil

				local bagPanel = container:Add("ixInventory")
				bagPanel:SetPos(GAP, ry)
				bagPanel:SetDraggable(false)
				bagPanel:SetSizable(false)
				bagPanel:SetTitle(nil)
				bagPanel.bNoBackgroundBlur = true
				bagPanel.childPanels = {}
				bagPanel.Paint = function(_, w, h)
					draw.RoundedBox(3, 0, 0, w, h, Color(26, 26, 26, 210))
				end
				bagPanel:SetIconSize(bagIconSz)
				bagPanel:SetInventory(bagInv)

				-- Restauramos y registramos la bolsa para el ctrl+click entre inventarios.
				invPanel.childPanels = savedChild
				invPanel.childPanels[#invPanel.childPanels + 1] = bagPanel
				ix.gui["inv" .. bagInv:GetID()] = bagPanel

				ry = ry + bagPanel:GetTall() + GAP
			end

			-- ── barra de peso ──────────────────────────────────────────────
			local wBar = container:Add("DPanel")
			wBar:SetPos(GAP, ry)
			wBar:SetSize(sw - GAP * 2, wBarH)
			wBar.Paint = function(_, w, h)
				local carry = char:GetData("carry", 0)
				local maxW  = char:GetMaxWeight()
				local frac  = math.Clamp(carry / maxW, 0, 1)
				local fill  = frac < 0.60 and Color(80, 200, 80, 255)
				           or frac < 0.85 and Color(220, 200, 50, 255)
				           or Color(200, 50, 50, 255)
				draw.RoundedBox(3, 0, 0, w, h, Color(40, 40, 40, 200))
				if (frac > 0) then
					draw.RoundedBox(3, 0, 0, math.max(0, math.floor(w * frac)), h, fill)
				end
				surface.SetFont("ixSmallFont")
				local txt    = math.Round(carry, 1) .. " / " .. maxW .. " kg"
				local tw, th = surface.GetTextSize(txt)
				surface.SetTextColor(240, 240, 240, 255)
				surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
				surface.DrawText(txt)
			end
			ry = ry + wBarH + GAP

			-- ── panel combinado: descripción (izq) + misión en curso (der) ─────
			local charDesc = ""
			if (char.GetDescription) then charDesc = char:GetDescription() or ""
			elseif (char.GetDesc)    then charDesc = char:GetDesc() or "" end

			local currentDesc = {text = charDesc != "" and charDesc or "Sin descripción."}

			local halfW  = math.floor((sw - GAP * 3) / 2)
			local rightW = sw - GAP * 3 - halfW

			-- ── Mitad izquierda: descripción del personaje ────────────────────
			local descDisplay = container:Add("DPanel")
			descDisplay:SetPos(GAP, ry)
			descDisplay:SetSize(halfW, combH)
			descDisplay:SetMouseInputEnabled(true)
			descDisplay:SetCursor("hand")
			descDisplay.Paint = function(_, w, h)
				draw.RoundedBox(3, 0, 0, w, h, Color(24, 24, 24, 220))
				surface.SetDrawColor(55, 55, 55, 180)
				surface.DrawOutlinedRect(0, 0, w, h)
				-- Etiqueta "DESCRIPCIÓN" al estilo sectionHdr
				draw.RoundedBox(0, 0, 0, w, 18, Color(18, 20, 20, 255))
				surface.SetFont("ixSmallFont")
				surface.SetTextColor(199, 190, 150, 255)
				local lw, lh = surface.GetTextSize("DESCRIPCIÓN")
				surface.SetTextPos(8, 9 - lh / 2)
				surface.DrawText("DESCRIPCIÓN")
				-- Hint editable
				surface.SetTextColor(70, 70, 70, 255)
				local hw, hh = surface.GetTextSize("✎")
				surface.SetTextPos(w - hw - 6, 9 - hh / 2)
				surface.DrawText("✎")
			end

			local descLabel = descDisplay:Add("DLabel")
			descLabel:SetPos(6, 22)
			descLabel:SetSize(halfW - 12, combH - 26)
			descLabel:SetFont("ixSmallFont")
			descLabel:SetTextColor(Color(185, 185, 185))
			descLabel:SetWrap(true)
			descLabel:SetAutoStretchVertical(false)
			descLabel:SetText(currentDesc.text)

			function descDisplay:DoClick()
				if (IsValid(ix.gui.descEditor)) then ix.gui.descEditor:Remove() end
				local frame = vgui.Create("DFrame")
				ix.gui.descEditor = frame
				frame:SetTitle("Editar Descripción")
				frame:SetSize(420, 200)
				frame:Center()
				frame:MakePopup()
				frame:SetDeleteOnClose(true)
				local entry = frame:Add("DTextEntry")
				entry:SetPos(8, 32)
				entry:SetSize(404, 110)
				entry:SetMultiline(true)
				entry:SetFont("ixSmallFont")
				entry:SetText(currentDesc.text != "Sin descripción." and currentDesc.text or "")
				entry:RequestFocus()
				local saveBtn = frame:Add("DButton")
				saveBtn:SetPos(8, 150)
				saveBtn:SetSize(200, 28)
				saveBtn:SetText("Guardar")
				saveBtn.DoClick = function()
					local newDesc = entry:GetValue()
					if (newDesc == "") then newDesc = "Sin descripción." end
					currentDesc.text = newDesc
					if (IsValid(descLabel)) then descLabel:SetText(newDesc) end
					net.Start("ixInvSaveDesc")
						net.WriteString(newDesc)
					net.SendToServer()
					frame:Remove()
				end
				local cancelBtn = frame:Add("DButton")
				cancelBtn:SetPos(214, 150)
				cancelBtn:SetSize(200, 28)
				cancelBtn:SetText("Cancelar")
				cancelBtn.DoClick = function() frame:Remove() end
			end

			-- ── Mitad derecha: misión en curso ────────────────────────────────
			local msnPanel = container:Add("DPanel")
			msnPanel:SetPos(GAP + halfW + GAP, ry)
			msnPanel:SetSize(rightW, combH)
			msnPanel.Paint = function(_, w, h)
				draw.RoundedBox(3, 0, 0, w, h, Color(22, 22, 22, 210))
				surface.SetDrawColor(55, 55, 55, 120)
				surface.DrawOutlinedRect(0, 0, w, h)

				-- Cabecera "MISIÓN EN CURSO" (mismo estilo que las otras secciones)
				drawSectionHdr(w, 18, "MISIÓN EN CURSO")

				local _c     = IsValid(LocalPlayer()) and LocalPlayer():GetCharacter()
				local active = _c and _c.GetMissionActive and _c:GetMissionActive()

				if (not active or not active.missionId) then
					surface.SetFont("ixSmallFont")
					surface.SetTextColor(70, 70, 70, 255)
					local tw, th = surface.GetTextSize("Sin misión activa")
					surface.SetTextPos(w / 2 - tw / 2, (h + 18) / 2 - th / 2)
					surface.DrawText("Sin misión activa")
					return
				end

				-- Nombre de la misión en pequeño bajo la cabecera
				surface.SetFont("ixSmallFont")
				surface.SetTextColor(199, 190, 150, 200)
				surface.SetTextPos(6, 21)
				surface.DrawText(active.missionName or "Misión")

				-- Separador bajo el nombre
				surface.SetDrawColor(199, 190, 150, 35)
				surface.DrawRect(6, 33, w - 12, 1)

				local totalSteps    = active.totalSteps    or 0
				local stepSummaries = active.stepSummaries or {}
				local stepIndex     = active.stepIndex     or 1
				local ready         = active.readyToComplete

				local lineH = 13
				local lineY = 36
				local maxY  = h - 3

				if (ready) then
					for i = 1, totalSteps do
						if (lineY + lineH > maxY) then break end
						surface.SetFont("ixSmallFont")
						surface.SetTextColor(80, 150, 80, 200)
						surface.SetTextPos(5, lineY)
						surface.DrawText("+  " .. (stepSummaries[i] or ("Paso " .. i)))
						lineY = lineY + lineH
					end
					if (lineY + lineH <= maxY) then
						surface.SetFont("ixSmallFont")
						surface.SetTextColor(199, 190, 150, 255)
						surface.SetTextPos(5, lineY)
						surface.DrawText(">  ¡Entregar al comerciante!")
					end
				else
					for i = 1, totalSteps do
						if (lineY + lineH > maxY) then break end
						local label = stepSummaries[i] or ("Paso " .. i)
						surface.SetFont("ixSmallFont")
						if (i < stepIndex) then
							surface.SetTextColor(75, 135, 75, 200)
							surface.SetTextPos(5, lineY)
							surface.DrawText("+  " .. label)
						elseif (i == stepIndex) then
							surface.SetDrawColor(199, 190, 150, 16)
							surface.DrawRect(0, lineY - 1, w, lineH + 2)
							surface.SetTextColor(225, 205, 85, 255)
							surface.SetTextPos(5, lineY)
							surface.DrawText(">  " .. label)
						else
							surface.SetTextColor(55, 55, 55, 200)
							surface.SetTextPos(5, lineY)
							surface.DrawText("○  " .. label)
						end
						lineY = lineY + lineH
					end
				end
			end

			ry = ry + combH + GAP

			-- ── cabecera "ATRIBUTOS" ───────────────────────────────────────
			local attHdr = container:Add("DPanel")
			attHdr:SetPos(GAP, ry)
			attHdr:SetSize(sw - GAP * 2, attHdrH)
			attHdr.Paint = function(_, w, h) drawSectionHdr(w, h, "ATRIBUTOS") end
			ry = ry + attHdrH + GAP

			local attScroll = container:Add("DScrollPanel")
			attScroll:SetPos(GAP, ry)
			attScroll:SetSize(sw - GAP * 2, sh - ry - GAP)
			attScroll:GetVBar():SetWide(4)

			for attID, attrib in SortedPairs((ix.attributes and ix.attributes.list) or {}) do
				local aID   = attID
				local aName = attrib.name or attID
				local aRow  = attScroll:Add("DPanel")
				aRow:Dock(TOP)
				aRow:DockMargin(0, 0, 0, 2)
				aRow:SetTall(22)
				aRow.Paint = function(_, w, h)
					local val  = char:GetAttribute(aID, 0)
					local frac = math.Clamp(val / 100, 0, 1)
					draw.RoundedBox(3, 0, 0, w, h, Color(40, 40, 40, 200))
					if (frac > 0) then
						draw.RoundedBox(3, 0, 0, math.max(0, math.floor(w * frac)), h, Color(60, 95, 150, 220))
					end
					surface.SetFont("ixSmallFont")
					local pct    = math.Round(frac * 100, 1)
					local txt    = aName .. "  " .. val .. " / 100  (" .. pct .. "%)"
					local tw, th = surface.GetTextSize(txt)
					surface.SetTextColor(215, 215, 215, 255)
					surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
					surface.DrawText(txt)
				end
			end

			return container
		end
	}
end)

hook.Add("PostRenderVGUI", "ixInvHelper", function()
	local pnl = ix.gui.inv1

	hook.Run("PostDrawInventory", pnl)
end)
