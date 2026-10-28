
ITEM.name = "Bridas"
ITEM.weight = 0.1
ITEM.model = Model("models/metro/cablerope_bundle_3.mdl")
ITEM.description = "Un manojo de bridas de plástico reforzado. Sirven para inmovilizar las muñecas de alguien en un apuro."
ITEM.category = "Equipamiento"
ITEM.width = 1
ITEM.height = 1
ITEM.chance = 31
ITEM.rare = true

ITEM.functions.Atar = {
	name = "Atar",
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

		if (IsValid(target) and target:IsPlayer() and target:GetCharacter()
		and !target:GetNetVar("tying") and !target:IsRestricted()) then
			item.bBeingUsed = true

			client:SetAction("Atando", 5)
			target:SetAction("Siendo atado", 5)
			target:SetNetVar("tying", true)
			client:Say("/me le ata las manos con unas bridas al sujeto")

			client:DoStaredAction(target, function()
				-- bNoMessage = true: suprime el aviso nativo de Helix ("You have been
				-- restrained.") porque cl_hooks.lua dibuja uno propio en español.
				target:SetRestricted(true, true)
				target:SetNetVar("tying")
				target:NotifyLocalized("bridasTiedUp")
				client:NotifyLocalized("bridasTiedUpSelf", target:Name())

				item:Remove()
			end, 5, function()
				client:SetAction()

				if (IsValid(target)) then
					target:SetAction()
					target:SetNetVar("tying")
				end

				item.bBeingUsed = false
			end)
		else
			client:NotifyLocalized("plyNotValid")
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
