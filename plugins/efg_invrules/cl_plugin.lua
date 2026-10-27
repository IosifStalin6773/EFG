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
	local down = input.IsKeyDown(KEY_R)

	if (down and !wasDown and IsValid(ix.gui.metroInventory) and !IsValid(vgui.GetKeyboardFocus())) then
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
	local item = ix.item.instances[net.ReadUInt(32)]
	local inventory = ix.item.inventories[net.ReadUInt(32)]

	if (item and inventory and item.gridX) then
		INV.ApplyFootprint(inventory, item, item.gridX, item.gridY, item.width, item.height)
	end

	surface.PlaySound("efg/ui/click.wav")

	local panel = ix.gui.metroInventory

	if (IsValid(panel) and panel.RebuildInventoryView) then
		panel:RebuildInventoryView()
	end
end)

-- ─── Tooltip: encontrado en raid ─────────────────────────────────────────────
hook.Add("PopulateItemTooltip", "efgInvRules.FIR", function(tooltip, item)
	if (!item.GetData or !item:GetData("fir")) then return end

	local row = tooltip:AddRow("efg_fir")
	row:SetText("✔ ENCONTRADO EN RAID")
	row:SetTextColor(Color(150, 215, 90))
	row:SizeToContents()
end)
