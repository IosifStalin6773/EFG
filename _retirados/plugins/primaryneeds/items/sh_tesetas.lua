
ITEM.name = "Té de setas"
ITEM.weight = 0.2
ITEM.description = "Infusión común en el metro."
ITEM.model = Model("models/lostsignalproject/items/consumable/tea.mdl")
ITEM.category = "Bebidas"
ITEM.width = 1
ITEM.height = 2
ITEM.price = 20

ITEM.functions.Beber = {
	sound = "npc/barnacle/barnacle_gulp1.wav",
	OnRun = function(item)
		local character = item.player:GetCharacter()
		if (character) then
			character:RestoreSaturation(60)
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}