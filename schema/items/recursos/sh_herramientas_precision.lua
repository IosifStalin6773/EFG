ITEM.name = "Herramientas de Precisión"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/quest/toolkit_2.mdl")
ITEM.description = "Micrómetros, pinzas de punta fina y llaves de precisión. Imprescindibles para trabajos de armería y electrónica avanzada."
ITEM.category = "Recursos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false
ITEM.breakChance = 0.20   -- probabilidad de romperse en cada crafteo

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local panel = tooltip:AddRowAfter("name", "breakchance")
		panel:SetText(("Prob. de romperse: %d%%"):format(math.Round(self.breakChance * 100)))
		panel:SizeToContents()
	end
end
