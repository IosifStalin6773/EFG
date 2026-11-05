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

-- ─── Pantalla de equipo protector (solo lectura): ranuras y stats en vivo ───
-- El cliente pide el estado de una pieza; el servidor calcula el recálculo del
-- jugador (ix.efg.armor.Recalc) y devuelve las ranuras que declara la pieza.
util.AddNetworkString("ixEFGArmorStats")

local function armorPayload(client, item)
	local recalc = ix.efg.armor.Recalc(client)
	local labels = ix.efg.equipment and ix.efg.equipment.slotLabels or {}
	local container = {slots = item.efgCarrierSlots or item.efgHelmetSlots}
	local slots, zones = {}, {}

	for _, k in ipairs(ix.efg.slots.Declared(container)) do
		slots[#slots + 1] = {k = k, label = labels[k] or k}
	end

	for partID, zone in pairs(recalc.zones) do
		zones[#zones + 1] = {label = ix.efg.armor.partNames[partID] or partID, class = zone.class, item = zone.item}
	end

	table.sort(zones, function(a, b) return a.label < b.label end)

	return {
		name = item.name,
		slots = slots,
		zones = zones,
		stats = {weight = recalc.weight, ergo = recalc.ergo, turn = recalc.turn},
		modular = ix.config.Get("efgArmorModular", true) == true
	}
end

net.Receive("ixEFGArmorStats", function(_, client)
	local item = ix.item.instances[net.ReadUInt(32)]

	if (!item or !item.isEFGArmor or !owns(client, item)) then return end

	net.Start("ixEFGArmorStats")
	net.WriteString(util.TableToJSON(armorPayload(client, item)))
	net.Send(client)
end)
