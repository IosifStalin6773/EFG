ITEM.name = "Manual: Médico Nivel 2"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/quest/document_01.mdl")
ITEM.description = "Tratado de medicina avanzada del metro. Permite preparar medicamentos más complejos."
ITEM.category = "Aprendizaje"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

local OFICIO = "medico"
local TIER = 2

ITEM.functions.Estudiar = {
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (!character) then return false end

		if (character:GetOficio() != OFICIO) then
			client:Notify("Solo un Médico puede usar este manual.")
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
		client:Notify("¡Has alcanzado el Nivel " .. TIER .. " como Médico!")
		return true
	end
}
