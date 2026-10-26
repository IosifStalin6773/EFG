ITEM.name = "Torniquete Esmarch"
ITEM.description = "Detiene un sangrado grave. Un solo uso."
ITEM.model = "models/props_junk/garbage_bag001a.mdl"
ITEM.useTime = 4
ITEM.price = 4500

function ITEM:CanApply(client)
	for _, level in pairs(ix.efg.health.GetStatus(client).bleed) do
		if (level == "heavy") then return true end
	end

	return false, "No tienes ningún sangrado grave."
end

function ITEM:Apply(client)
	return ix.efg.health.StopBleeding(client, "heavy") and 1 or 0
end
