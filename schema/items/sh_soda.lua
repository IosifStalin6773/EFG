
ITEM.name = "Soda"
ITEM.weight = 0.3
ITEM.model = Model("models/props_junk/popcan01a.mdl")
ITEM.description = "A blue can filled with some carbonated flavoured water. Delicious."
ITEM.category = "Bebidas"
ITEM.width = 1 -- Width and height refer to how many grid spaces this item takes up.
ITEM.height = 1

-- Items will be purchasable through the business menu. To disable the purchasing of this item, we specify ITEM.noBusiness.
ITEM.noBusiness = false

-- If you'd rather have the item only purchasable by a specific criteria, then you can specify it as such.
-- Make sure you haven't defined ITEM.noBusiness if you are going to be doing this.
--[[
ITEM.factions = {FACTION_POLICE} -- Only a certain faction can buy this.
ITEM.classes = {FACTION_POLICE_CHIEF} -- Only a certain class can buy this.
ITEM.flag = "z" -- Only a character having a certain flag can buy this.
]]

-- If the item is purchasable, then you'll probably want to set a price for it:
--[[
ITEM.price = 5
]]

-- You can define additional actions for this item as such:
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

ITEM.functions.Drink = {
	OnRun = function(item)
		-- IMPORTANT: Make sure you use "item" instead of "ITEM" here - these two are entirely different things!
		local client = item.player

		client:SetHealth(math.min(client:Health() + 10, GetVidaMaxima(client)))
		-- Returning true will cause the item to be removed from the character's inventory.
		return true
	end
}
