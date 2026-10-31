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
ITEM.efgPockets  = {{1, 2, 2}} -- {ancho, alto, cantidad}; cada chaleco pone los suyos

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

-- ─── Rejilla interna (bolsillos) ────────────────────────────────────────────
-- ITEM.efgPockets = {{ancho, alto, cantidad}, ...}; libs/sh_rigpockets.lua
-- coloca los bolsillos y no deja que un objeto cruce de uno a otro.
function ITEM:GetRigSize()
	local layout = ix.efg.rig.Layout(self)

	if (layout) then return layout.w, layout.h end

	return self.invWidth or 2, self.invHeight or 2
end

function ITEM:GetInventory()
	local index = self:GetData("id")

	return index and ix.item.inventories[index] or nil
end

ITEM.GetInv = ITEM.GetInventory

function ITEM:OnRegistered()
	if (self.efgPockets) then
		self.invWidth, self.invHeight = self:GetRigSize()
	end

	-- no es bolsa (4º parámetro) para que efg_invrules decida qué entra
	ix.inventory.Register(self.uniqueID, self.invWidth or 2, self.invHeight or 2)
end

if (SERVER) then
	local function setupRig(item, inv, client)
		inv.vars.isBag = nil
		inv.vars.efgRig = item.uniqueID
		inv:SetSize(item:GetRigSize())

		if (IsValid(client)) then
			inv:AddReceiver(client)
			inv:Sync(client)
		end
	end

	local function ownerOf(inventory)
		local character = inventory and inventory.owner and ix.char.loaded[inventory.owner]
		return character and character:GetPlayer()
	end

	function ITEM:OnInstanced(invID)
		local inventory = ix.item.inventories[invID]

		ix.inventory.New(inventory and inventory.owner or 0, self.uniqueID, function(inv)
			self:SetData("id", inv:GetID())
			setupRig(self, inv, ownerOf(inventory))
		end)
	end

	-- restaura la rejilla al cargar el personaje y crea la de los chalecos
	-- antiguos que nunca la tuvieron
	function ITEM:OnSendData()
		local client = self.player
		local index = self:GetData("id")
		local inventory = index and ix.item.inventories[index]

		if (inventory) then
			setupRig(self, inventory, client)
		elseif (index) then
			local w, h = self:GetRigSize()

			ix.inventory.Restore(index, w, h, function(inv)
				local character = IsValid(client) and client:GetCharacter()
				if (character) then inv:SetOwner(character:GetID(), true) end

				setupRig(self, inv, client)
			end)
		elseif (not self.efgRigPending) then
			self.efgRigPending = true

			local character = IsValid(client) and client:GetCharacter()

			ix.inventory.New(character and character:GetID() or 0, self.uniqueID, function(inv)
				self.efgRigPending = nil
				self:SetData("id", inv:GetID())
				setupRig(self, inv, client)
			end)
		end
	end

	function ITEM:OnTransferred(oldInv, newInv)
		local inventory = self:GetInventory()
		if (not inventory) then return end

		local oldOwner = ownerOf(oldInv)
		local newOwner = ownerOf(newInv)

		if (IsValid(oldOwner) and oldOwner != newOwner) then inventory:RemoveReceiver(oldOwner) end

		if (IsValid(newOwner)) then
			inventory:SetOwner(newOwner:GetCharacter():GetID(), true)
			inventory:AddReceiver(newOwner)
			inventory:Sync(newOwner)
		end
	end

	function ITEM:OnRemoved()
		local index = self:GetData("id")
		if (not index) then return end

		local query = mysql:Delete("ix_items")
			query:Where("inventory_id", index)
		query:Execute()

		query = mysql:Delete("ix_inventories")
			query:Where("inventory_id", index)
		query:Execute()
	end
end

-- nada de meter el chaleco en su propia rejilla ni en algo que va dentro de ella
function ITEM:CanTransfer(oldInventory, newInventory)
	local index = self:GetData("id")
	if (not index or not newInventory) then return true end

	local target = newInventory:GetID()
	if (target == index) then return false end

	local inventory = self:GetInventory()

	if (inventory) then
		for _, inner in pairs(inventory:GetItems()) do
			if (inner:GetData("id") == target) then return false end
		end
	end

	return true
end
