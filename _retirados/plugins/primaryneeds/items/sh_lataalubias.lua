
ITEM.name = "Lata de alubias"
ITEM.weight = 0.4
ITEM.description = "Una lata de alubias en conserva"
ITEM.model = Model("models/lostsignalproject/items/consumable/beans.mdl")
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
			character:RestoreSatiety(40)
			ix.needs.ApplyNutrido(client)
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}