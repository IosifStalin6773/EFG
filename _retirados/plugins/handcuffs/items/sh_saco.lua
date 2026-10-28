
ITEM.name = "Saco"
ITEM.weight = 0.6
ITEM.model = Model("models/willardnetworks/m1nt/burlap_bag_male.mdl")
ITEM.description = "Un saco de arpillera. Colocado sobre la cabeza de alguien esposado, le impide ver."
ITEM.category = "Equipamiento"
ITEM.width = 1
ITEM.height = 1
ITEM.chance = 20
ITEM.rare = true

ITEM.functions.Colocar = {
	name = "Colocar",
	OnRun = function(item)
		local client = item.player
		local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client
		local target = util.TraceLine(data).Entity

		if (target == client) then
			client:NotifyLocalized("bridasNoSelf")
			return false
		end

		if (!IsValid(target) or !target:IsPlayer() or !target:GetCharacter()) then
			client:NotifyLocalized("plyNotValid")
			return false
		end

		local plugin = ix.plugin.Get("handcuffs")
		if (plugin) then
			plugin:EquiparSaco(client, target, item)
		end

		return false
	end,
	OnCanRun = function(item)
		return !item.bBeingUsed
	end
}

function ITEM:CanTransfer(inventory, newInventory)
	return !self.bBeingUsed
end
