ITEM.name = "Kit quirúrgico CMS"
ITEM.description = "Recupera una extremidad destruida (queda con 1 de vida). 5 usos."
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.width = 2
ITEM.useTime = 15
ITEM.maxUses = 5
ITEM.price = 22000

function ITEM:CanApply(client)
	local hp = ix.efg.health.GetHP(client)

	for _, part in ipairs(ix.efg.health.parts) do
		if (!part.vital and hp[part.id] <= 0) then return true end
	end

	return false, "No tienes ninguna extremidad destruida."
end

function ITEM:Apply(client)
	return ix.efg.health.RestoreBlacked(client) and 1 or 0
end
