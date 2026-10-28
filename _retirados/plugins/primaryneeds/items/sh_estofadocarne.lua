
ITEM.name = "Estofado de carne"
ITEM.weight = 0.4
ITEM.description = "estofado de carne de topo y rata."
ITEM.model = Model("models/lostsignalproject/items/consumable/meat_dog.mdl")
ITEM.category = "Comestibles"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 25

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
			character:RestoreSatiety(70)
			ix.needs.ApplyNutrido(client)

			if (ix.temperatura) then
				ix.temperatura.Calentar(client, 20)
			end
		end
		client:SetHealth(math.min(client:Health() + 5, GetVidaMaxima(client)))
	end,
	OnCanRun = function(item)
		return IsValid(item.player)
	end,
}

ix.spoilage.Register(ITEM, ix.spoilage.COOKED_DURATION)