ITEM.name = "Manual: Químico Nivel 2"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/quest/document_01.mdl")
ITEM.description = "Tratado de química aplicada. Permite procesar materiales más complejos en el metro."
ITEM.category = "Aprendizaje"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

local OFICIO = "quimico"
local TIER = 2

ITEM.functions.Estudiar = {
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (!character) then return false end

		if (character:GetOficio() != OFICIO) then
			client:Notify("Solo un Químico puede usar este manual.")
			return false
		end

		if (character:GetOficioTier() >= TIER) then
			client:Notify("Ya conoces las técnicas de este nivel.")
			return false
		end

		if (character:GetOficioTier() != TIER - 1) then
			client:Notify("Necesitas dominar el nivel anterior primero.")
			return false
		end

		character:SetOficioTier(TIER)
		client:Notify("¡Has alcanzado el Nivel " .. TIER .. " como Químico!")
		return true
	end
}
