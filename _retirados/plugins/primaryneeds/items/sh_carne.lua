
ITEM.name = "Carne cruda"
ITEM.weight = 0.3
ITEM.description = "Carne cruda, se puede comer, pero alimentará más cocida"
ITEM.model = Model("models/lostsignalproject/items/consumable/raw_boar.mdl")
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
			ix.needs.TryIntoxicate(client)
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}

ix.spoilage.Register(ITEM, ix.spoilage.RAW_DURATION)