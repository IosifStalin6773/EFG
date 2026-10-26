ITEM.name = "Contenedor seguro IV"
ITEM.description = "Contenedor seguro de 4x3, recompensa de la misión más larga del juego."
ITEM.model = "models/eft_props/secureconts/kappa.mdl"
ITEM.category = "Contenedores"
ITEM.width = 2
ITEM.height = 2
ITEM.invWidth = 4
ITEM.invHeight = 3
ITEM.weight = 1
ITEM.noLoot = true -- no cae al cadáver: se conserva con su contenido al morir
ITEM.noBusiness = true
ITEM.isSecureContainer = true

-- El contenedor seguro no se puede tirar, guardar ni dar: solo moverse dentro
-- del inventario de su dueño (y al inventario oculto del Scav run).
function ITEM:CanTransfer(oldInventory, newInventory)
	-- el inventario oculto del Scav run y la ranura de equipo (contenedor seguro)
	local function isHold(inventory)
		return inventory and inventory.vars and (inventory.vars.isEFGHold or inventory.vars.isEquipment)
	end

	if (!isHold(oldInventory) and !isHold(newInventory)) then
		if (!newInventory or newInventory:GetID() == 0) then
			return false
		end

		if (oldInventory and oldInventory:GetID() != 0 and newInventory:GetID() != oldInventory:GetID()) then
			return false
		end
	end

	local base = ix.item.base["base_bags"]

	if (base and base.CanTransfer) then
		return base.CanTransfer(self, oldInventory, newInventory)
	end

	return true
end
