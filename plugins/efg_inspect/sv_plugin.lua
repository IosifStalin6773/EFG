-- Acciones de la ventana de inspección: montar y desmontar accesorios
-- arrastrándolos. Las demás acciones (equipar, usar, tirar...) van por el
-- ixInventoryAction normal de Helix.

if (!SERVER) then return end

util.AddNetworkString("ixEFGInspectMod")

-- el ítem está en un inventario del personaje (bolsillos, mochila, chaleco...)
local function owns(client, item)
	local character = client:GetCharacter()
	local inventory = item and ix.item.inventories[item.invID]

	return character and inventory and inventory.owner == character:GetID()
end

net.Receive("ixEFGInspectMod", function(_, client)
	if ((client.efgInspectNext or 0) > CurTime()) then return end
	client.efgInspectNext = CurTime() + 0.25

	local action = net.ReadString()
	local weapon = ix.item.instances[net.ReadUInt(32)]
	local mods = ix.efg.mods

	if (!mods or !weapon or !weapon.isARC9 or !owns(client, weapon)) then return end

	if (client.InRaid and client:InRaid() and ix.config.Get("efgModInRaid", false) != true) then
		client:Notify("No puedes cambiar accesorios durante la raid.")
		return
	end

	if (weapon:GetData("equip")) then
		client:Notify("Desequipa el arma antes de cambiar accesorios.")
		return
	end

	if (action == "install") then
		local mod = ix.item.instances[net.ReadUInt(32)]
		if (!mod or !mod.isEFGMod or !owns(client, mod)) then return end

		-- si la ranura está ocupada, primero se desmonta lo que hay
		local current = mods.GetMods(weapon)[mod.modSlot]
		if (current and !mods.Remove(client, weapon, mod.modSlot)) then return end

		mods.Install(client, mod, weapon)
	elseif (action == "remove") then
		local slot = net.ReadString()
		if (mods.slotNames[slot]) then mods.Remove(client, weapon, slot) end
	end
end)
