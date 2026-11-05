-- Ranuras y compatibilidad del equipo modular. Lógica pura, sin hooks:
-- la usan el equipo (placas, módulos de casco) y, en el futuro, efg_mods.
-- Un contenedor declara sus ranuras (carrier.slots, helmet.slots, backpack.removableModules).
-- Un objeto se guarda como {[slotID] = uniqueID}.

ix.efg = ix.efg or {}
ix.efg.slots = ix.efg.slots or {}

local slots = ix.efg.slots

-- ¿Puede esta pieza ir en esta ranura de este contenedor?
-- Las placas usan zones (front, back, sides); los módulos de casco usan slot.
function slots.CanFit(container, slotID, part)
	if (!container or !part or !container.slots or !container.slots[slotID]) then
		return false
	end

	if (part.slot) then
		return part.slot == slotID
	end

	return table.HasValue(part.zones or {}, slotID)
end

-- Ranura en la que ya está instalado un uniqueID (o nil). Una pieza solo ocupa una.
function slots.FindInstalled(installed, uniqueID)
	for slotID, id in pairs(installed or {}) do
		if (id == uniqueID) then
			return slotID
		end
	end
end

-- Mueve una pieza de una ranura a otra. Nunca la duplica: si ya estaba en
-- otra ranura, la quita de allí. Devuelve false si el destino está ocupado.
function slots.Move(installed, uniqueID, toSlot)
	if (installed[toSlot]) then
		return false
	end

	local fromSlot = slots.FindInstalled(installed, uniqueID)

	if (fromSlot) then
		installed[fromSlot] = nil
	end

	installed[toSlot] = uniqueID

	return true
end

-- Lista de ranuras declaradas por el contenedor, en orden fijo para la UI
-- (la silueta muestra también las vacías).
function slots.Declared(container)
	local order = {"front", "back", "sides", "visor", "jaw", "ears", "nvg", "light", "headset"}
	local list = {}

	for _, slotID in ipairs(order) do
		if (container and container.slots and container.slots[slotID]) then
			list[#list + 1] = slotID
		end
	end

	return list
end
