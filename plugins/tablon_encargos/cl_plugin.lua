local PLUGIN = PLUGIN

ix.util.IncludeDir(("%s/plugins/%s/derma"):format(Schema.folder, PLUGIN.uniqueID), true)

net.Receive(PLUGIN.netOpen, function()
	local orderCount = net.ReadUInt(16)
	local orders = {}

	for _ = 1, orderCount do
		table.insert(orders, {
			id = net.ReadUInt(32),
			itemID = net.ReadString(),
			itemName = net.ReadString(),
			quantity = net.ReadUInt(16),
			reward = net.ReadUInt(32),
			posterName = net.ReadString(),
			posterSteamID = net.ReadString(),
		})
	end

	local pickupCount = net.ReadUInt(8)
	local pickups = {}

	for _ = 1, pickupCount do
		local pType = net.ReadString()
		local pickup = {type = pType}

		if (pType == "item") then
			pickup.itemID = net.ReadString()
			pickup.itemName = net.ReadString()
			pickup.quantity = net.ReadUInt(16)
		elseif (pType == "payment") then
			pickup.amount = net.ReadUInt(32)
			pickup.reason = net.ReadString()
		end

		table.insert(pickups, pickup)
	end

	if (IsValid(ix.gui.metroTablon)) then
		ix.gui.metroTablon:SetData(orders, pickups)
	else
		local panel = vgui.Create("metroTablonEncargos")
		panel:SetData(orders, pickups)
	end
end)
