ITEM.name = "Pasamontañas"
ITEM.description = "Un pasamontañas de lana raída que cubre por completo el rostro, dejando solo los ojos al descubierto. Nadie podrá reconocerte mientras lo lleves puesto."
ITEM.model = Model("models/z-o-m-b-i-e/metro_ll/equipment/m_ll_npc_civilian_03.mdl")
ITEM.category = "Equipamiento"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true

if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

function ITEM:isEquipped()
	return self:GetData("equip", false)
end

local function setEquipped(client, item, bool)
	item:SetData("equip", bool)
	client:SetNetVar("faceHidden", bool)
end

ITEM:Hook("drop", function(item)
	if (item:isEquipped()) then
		setEquipped(item:GetOwner(), item, false)
	end
end)

function ITEM:OnRemoved()
	if (self.invID != 0 and self:isEquipped()) then
		local owner = self:GetOwner()

		if (IsValid(owner)) then
			setEquipped(owner, self, false)
		end
	end
end

ITEM.functions.EquipUn = {
	name = "Quitar",
	tip = "unequipTip",
	icon = "icon16/cross.png",
	OnRun = function(item)
		setEquipped(item.player, item, false)

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and item:isEquipped())
	end
}

ITEM.functions.Equip = {
	name = "Equipar",
	tip = "equipTip",
	icon = "icon16/tick.png",
	OnRun = function(item)
		setEquipped(item.player, item, true)

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and !item:isEquipped())
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and self:isEquipped()) then
		return false
	end

	return true
end
