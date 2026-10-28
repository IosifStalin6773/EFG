ITEM.name = "Manual: Chatarrero Nivel 2"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/quest/document_01.mdl")
ITEM.description = "Guía de ingeniería improvisada. Permite fabricar estructuras y equipos más complejos con chatarra."
ITEM.category = "Aprendizaje"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

local TIER = 2

ITEM.functions.Estudiar = {
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (!character) then return false end

		-- Chatarrero es transversal: cualquiera puede estudiarlo, gestiona su propio tier.
		if ((character:GetChatarreroTier() or 0) >= TIER) then
			client:Notify("Ya conoces las técnicas de este nivel.")
			return false
		end

		if ((character:GetChatarreroTier() or 0) != TIER - 1) then
			client:Notify("Necesitas dominar el nivel anterior primero.")
			return false
		end

		character:SetChatarreroTier(TIER)
		client:Notify("¡Has alcanzado el Nivel " .. TIER .. " como Chatarrero!")
		return true
	end
}
