ITEM.name = "Medical Item"
ITEM.model = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.1
ITEM.maxUses = 1

function ITEM:GetUses()
	return self:GetData("uses", self.maxUses)
end

function ITEM:SetUses(n)
	self:SetData("uses", math.max(n, 0))
end

function ITEM:OnInstanced(invID, x, y, item)
	-- Solo inicializar si no hay usos previos; OnInstanced corre DESPUÉS de
	-- asignar item.data, así que sobrescribir borraría los usos preservados al
	-- recomprar un consumible usado en los traders.
	if (item and item:GetData("uses") == nil) then
		item:SetData("uses", item.maxUses)
	end
end

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local uses = self:GetData("uses", self.maxUses)
		local panel = tooltip:AddRowAfter("name", "uses")
		panel:SetText("Usos: " .. uses .. "/" .. self.maxUses)
		panel:SizeToContents()
	end
end
