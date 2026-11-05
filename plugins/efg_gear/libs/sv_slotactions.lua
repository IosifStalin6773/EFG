-- Instalar y quitar placas en las ranuras de un chaleco (data "efgSlots"). Solo servidor.
-- La compatibilidad la decide ix.efg.slots.CanFit (zonas de la placa contra la ranura).
-- Mientras no haya reglas de cambio en raid (efg_invrules), se permite en cualquier momento.

if (!SERVER) then return end

local armor = ix.efg.armor

local function slotsOf(carrier)
	return carrier:GetData("efgSlots") or {}
end

-- Reglas de cambio (efg_invrules): hook EFGArmorSlotBlock devuelve un texto si bloquea.
local function blockedBy(client, carrier)
	return hook.Run("EFGArmorSlotBlock", client, carrier)
end

-- Instala una placa (instancia) en una ranura libre. Devuelve true o false, motivo.
function armor.SlotInstall(client, carrier, slotID, plate)
	if (!carrier or !plate or !plate.isEFGPlate) then return false, "noPlate" end

	local reason = blockedBy(client, carrier)
	if (reason) then return false, reason end

	local character = client:GetCharacter()
	if (!character or plate.invID != character:GetInventory():GetID()) then return false, "noPlate" end

	if (!ix.efg.slots.CanFit(carrier.efgCarrierSlots and {slots = carrier.efgCarrierSlots}, slotID, {zones = plate.efgPlateZones})) then
		return false, "noFit"
	end

	local slots = slotsOf(carrier)
	if (slots[slotID]) then return false, "occupied" end

	slots[slotID] = {id = plate.uniqueID, durability = plate:GetData("durability", plate.plateDurability)}
	carrier:SetData("efgSlots", slots)
	plate:Remove()

	return true
end

-- Saca la placa de una ranura y la devuelve al inventario. Si no cabe, no la quita.
function armor.SlotRemove(client, carrier, slotID)
	local reason = blockedBy(client, carrier)
	if (reason) then return false, reason end

	local slots = slotsOf(carrier)
	local entry = slots[slotID]
	if (!entry) then return false, "empty" end

	local character = client:GetCharacter()
	local ok, err = character:GetInventory():Add(entry.id, 1, {durability = entry.durability})
	if (!ok) then return false, err or "noFit" end

	slots[slotID] = nil
	carrier:SetData("efgSlots", slots)

	return true
end
