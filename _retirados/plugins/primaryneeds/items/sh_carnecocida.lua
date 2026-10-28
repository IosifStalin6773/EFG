
ITEM.name = "Carne cocida"
ITEM.weight = 0.3
ITEM.description = "Carne cocida, esta algo dura e insipida, pero es mejor que nada."
ITEM.model = Model("models/lostsignalproject/items/consumable/meat_boar.mdl")
ITEM.category = "Comestibles"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 15

ITEM.functions.Comer = {
	sound = "npc/barnacle/barnacle_crunch3.wav",
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (character) then
			character:RestoreSatiety(10)

			if (ix.temperatura) then
				ix.temperatura.Calentar(client, 5)
			end
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}

ix.spoilage.Register(ITEM, ix.spoilage.COOKED_DURATION)