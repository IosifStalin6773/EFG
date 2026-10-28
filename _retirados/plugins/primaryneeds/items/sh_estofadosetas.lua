
ITEM.name = "Estofado de setas"
ITEM.weight = 0.3
ITEM.description = "Estofado de setas cultivadas en el metro"
ITEM.model = Model("models/lostsignalproject/items/consumable/food_chimera.mdl")
ITEM.category = "Comestibles"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 5

-- Devuelve la vida máxima real teniendo en cuenta las heridas acumuladas.
-- Usa el plugin medico si está disponible; cae a GetMaxHealth() si no.
local function GetVidaMaxima(client)
	local char = IsValid(client) and client:GetCharacter()
	local medicoPlugin = ix.plugin.Get("medico")
	if (medicoPlugin and char) then
		return medicoPlugin:CalcularVidaMaxima(char:GetHeridas() or 0)
	end
	return client:GetMaxHealth()
end

ITEM.functions.Comer = {
	sound = "npc/barnacle/barnacle_crunch3.wav",
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (character) then
			character:RestoreSatiety(25)
			client:SetHealth(math.min(client:Health() + 5, GetVidaMaxima(client)))
			ix.needs.ApplyNutrido(client)

			if (ix.temperatura) then
				ix.temperatura.Calentar(client, 15)
			end
		end
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}

ix.spoilage.Register(ITEM, ix.spoilage.COOKED_DURATION)