
ITEM.uniqueID = "pinchocarne"
ITEM.name = "Pincho de carne"
ITEM.weight = 0.2
ITEM.description = "Unos trozos de carne dura pinchados en un palo."
ITEM.model = Model("models/lostsignalproject/items/consumable/meat_tushkano.mdl")
ITEM.category = "Comestibles"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 5

ITEM.functions.Comer = {
	sound = "npc/barnacle/barnacle_crunch3.wav",
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (character) then
			character:RestoreSatiety(15)
			ix.needs.ApplyNutrido(client)

			if (ix.temperatura) then
				ix.temperatura.Calentar(client, 12)
			end
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}

ix.spoilage.Register(ITEM, ix.spoilage.COOKED_DURATION)