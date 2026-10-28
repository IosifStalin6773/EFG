
ITEM.name = "Ración militar"
ITEM.weight = 0.5
ITEM.description = "Ración militar de conservas de la preguerra."
ITEM.model = Model("models/illusion/eftcontainers/mre.mdl")
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
			character:RestoreSatiety(90)
			ix.needs.ApplyNutrido(client)
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}