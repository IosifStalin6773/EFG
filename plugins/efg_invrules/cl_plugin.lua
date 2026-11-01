local PLUGIN = PLUGIN

local INV = ix.efg.inv

-- ─── R gira el objeto bajo el ratón con el inventario abierto ───────────────
local function hoveredItem()
	local panel = vgui.GetHoveredPanel()

	for _ = 1, 4 do
		if (!IsValid(panel)) then return end
		if (panel.itemTable and panel.itemTable.id) then return panel.itemTable end

		panel = panel:GetParent()
	end
end

local wasDown = false

function PLUGIN:Think()
	local down = input.IsKeyDown(ix.efg.binds and ix.efg.binds.Key("rotate") or KEY_R)

	-- arrastrando en el inventario de EFT la R gira lo que se arrastra (efg_invgrid)
	if (INV.dragging) then
		wasDown = down
		return
	end

	if (down and !wasDown and IsValid(ix.gui.efgInventory) and !IsValid(vgui.GetKeyboardFocus())) then
		local item = hoveredItem()

		if (item and item.width != item.height) then
			net.Start("ixEFGRotate")
				net.WriteUInt(item.id, 32)
			net.SendToServer()
		end
	end

	wasDown = down
end

net.Receive("ixEFGRotated", function()
	-- girado en su sitio: la esquina superior izquierda no cambia y el cliente
	-- solo guarda esa casilla, así que no hay que tocar inv.slots
	net.ReadUInt(32)
	net.ReadUInt(32)

	surface.PlaySound("efg/ui/click.wav")

	local panel = ix.gui.efgInventory

	if (IsValid(panel) and panel.RebuildInventoryView) then
		panel:RebuildInventoryView()
	end
end)

-- girado y movido dentro del mismo inventario: en el cliente solo se guarda la
-- esquina superior izquierda
net.Receive("ixEFGRotMoved", function()
	local item = ix.item.instances[net.ReadUInt(32)]
	local inventory = ix.item.inventories[net.ReadUInt(32)]
	local x, y = net.ReadUInt(6), net.ReadUInt(6)
	if (!item or !inventory) then return end

	for _, column in pairs(inventory.slots) do
		for cy, other in pairs(column) do
			if (other == item) then column[cy] = nil end
		end
	end

	inventory.slots[x] = inventory.slots[x] or {}
	inventory.slots[x][y] = item
	item.gridX, item.gridY = x, y

	surface.PlaySound("efg/ui/click.wav")
end)

-- ─── Tooltip: encontrado en raid ─────────────────────────────────────────────
hook.Add("PopulateItemTooltip", "efgInvRules.FIR", function(tooltip, item)
	if (!item.GetData or !item:GetData("fir")) then return end

	local row = tooltip:AddRow("efg_fir")
	row:SetText("✔ ENCONTRADO EN RAID")
	row:SetTextColor(Color(150, 215, 90))
	row:SizeToContents()
end)
