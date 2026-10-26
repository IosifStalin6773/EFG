ITEM.name = "Destornillador"
ITEM.weight = 0.2
ITEM.model = Model("models/illusion/eftcontainers/screwdriver.mdl")
ITEM.description = "Destornillador de punta plana reforzado. Esencial para trabajar con tornillos y paneles."
ITEM.category = "Herramientas"
ITEM.width = 1
ITEM.height = 2
ITEM.noBusiness = false
ITEM.breakChance = 0.20   -- probabilidad de romperse en cada crafteo

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local panel = tooltip:AddRowAfter("name", "breakchance")
		panel:SetText(("Prob. de romperse: %d%%"):format(math.Round(self.breakChance * 100)))
		panel:SizeToContents()
	end
end
