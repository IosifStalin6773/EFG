
ITEM.name = "Botella de Cerveza"
ITEM.weight = 0.5
ITEM.description = "Una botella de Cerveza hecha artesanalmente."
ITEM.model = Model("models/props_junk/GlassBottle01a.mdl")
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
			character:RestoreSaturation(50)
		end

		if (SERVER and ix.drogas) then
			ix.drogas.Apply(client, "alcohol")
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}