-- libs/sh_wearable.lua
-- Utilidades para ítems de equipo de EFT que van en ranuras dedicadas
-- (auriculares, gafas, cubrecaras, brazalete, chaleco táctico).

ix.efg = ix.efg or {}
ix.efg.gear = ix.efg.gear or {}

-- Añade la acción "Equipar" a un ítem wearable de EFT usando ix.EquipToSlot.
function ix.efg.gear.AddEquipAction(ITEM)
	ITEM.functions = ITEM.functions or {}
	ITEM.functions.EfgEquip = {
		name  = "Equipar",
		OnRun = function(item)
			if (SERVER and ix.EquipToSlot) then
				ix.EquipToSlot(item.player, item)
			end
			return false
		end,
		OnCanRun = function(item)
			-- solo cuando está en el inventario (no en el suelo) y no equipado aún
			if (IsValid(item.entity)) then return false end
			local eqInv = item.player and ix.GetEquipInventory and ix.GetEquipInventory(item.player:GetCharacter())
			return not eqInv or item.invID != eqInv:GetID()
		end
	}
end

-- Añade la acción "Desequipar" a un ítem wearable.
function ix.efg.gear.AddUnequipAction(ITEM)
	ITEM.functions = ITEM.functions or {}
	ITEM.functions.EfgUnequip = {
		name  = "Desequipar",
		OnRun = function(item)
			if (SERVER) then
				net.Start("ixUnequipSlot"); net.WriteUInt(item.id, 32); net.SendToServer()
			end
			if (CLIENT) then
				net.Start("ixUnequipSlot"); net.WriteUInt(item.id, 32); net.SendToServer()
			end
			return false
		end,
		OnCanRun = function(item)
			if (IsValid(item.entity)) then return false end
			local eqInv = item.player and ix.GetEquipInventory and ix.GetEquipInventory(item.player:GetCharacter())
			return eqInv and item.invID == eqInv:GetID()
		end
	}
end
