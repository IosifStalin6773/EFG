-- items/base/sh_efg_rig.lua
-- Chaleco táctico (rig): va a la ranura "rig" del inventario de equipo y
-- además tiene un inventario interno (rejilla) para llevar objetos pequeños.

ITEM.name        = "Chaleco táctico"
ITEM.description = "Chaleco táctico con bolsillos modulares."
ITEM.model       = "models/props_junk/garbage_bag001a.mdl"
ITEM.width       = 3
ITEM.height      = 3
ITEM.weight      = 1.5
ITEM.category    = "Equipo"
ITEM.bDropOnDeath = true

ITEM.efgSlot     = "rig"
ITEM.invWidth    = 2  -- cols del inventario interno (se sobreescribe en cada rig)
ITEM.invHeight   = 2  -- filas del inventario interno

ITEM.functions = {}

ITEM.functions.EfgEquip = {
	name  = "Equipar",
	OnRun = function(item)
		if (SERVER and ix.EquipToSlot) then ix.EquipToSlot(item.player, item) end
		return false
	end,
	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		local eqInv = item.player and ix.GetEquipInventory and ix.GetEquipInventory(item.player:GetCharacter())
		return not eqInv or item.invID != eqInv:GetID()
	end
}

ITEM.functions.EfgUnequip = {
	name  = "Desequipar",
	OnRun = function(item)
		if (CLIENT) then net.Start("ixUnequipSlot"); net.WriteUInt(item.id, 32); net.SendToServer() end
		return false
	end,
	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		local eqInv = item.player and ix.GetEquipInventory and ix.GetEquipInventory(item.player:GetCharacter())
		return eqInv and item.invID == eqInv:GetID()
	end
}

-- Crear el inventario interno cuando se inicializa el ítem en el servidor
if (SERVER) then
	function ITEM:OnEquip(client)
		if (self:GetData("id")) then return end  -- ya tiene inv
		local w, h = self.invWidth or 2, self.invHeight or 2
		ix.inventory.New(client:GetCharacter():GetID(), "efg_rig", function(inv)
			-- NO es bolsa para poder meter bolsas/mochilas dentro
			inv.vars.isBag = nil
			inv:SetSize(w, h)
			inv:AddReceiver(client)
			inv:Sync(client)
			self:SetData("id", inv:GetID())
		end)
	end
end
