
ITEM.name = "Botella de plastico con algo de agua sucia"
ITEM.weight = 0.5
ITEM.description = "Agua rescatada de algún pozuelo del metro, deberías hervirla."
ITEM.model = Model("models/fallout 3/water.mdl")
ITEM.category = "Bebidas"
ITEM.width = 1
ITEM.height = 2
ITEM.price = 20

ITEM.functions.Beber = {
	sound = "npc/barnacle/barnacle_gulp1.wav",
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (character) then
			character:RestoreSaturation(5)
			ix.needs.TryIntoxicate(client)
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}