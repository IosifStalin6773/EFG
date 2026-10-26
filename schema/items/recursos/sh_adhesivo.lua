ITEM.name = "Cinta Americana"
ITEM.weight = 0.1
ITEM.model = Model("models/lostsignalproject/items/outfit_parts/retardant9.mdl")
ITEM.description = "Rollo de cinta americana resistente. Imprescindible para reparaciones rápidas y fabricación de equipamiento en el metro."
ITEM.category = "Recursos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false
ITEM.maxUses = 3 -- Reparaciones de máscara antes de gastarse el rollo.

function ITEM:getUses()
	return self:GetData("uses", self.maxUses)
end

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local panel = tooltip:AddRowAfter("name", "tapeUses")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText("Usos: " .. self:getUses() .. "/" .. self.maxUses)
		panel:SizeToContents()
	end
end
