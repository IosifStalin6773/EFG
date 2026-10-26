ITEM.name = "Férula inmovilizadora"
ITEM.description = "Inmoviliza una fractura. Un solo uso."
ITEM.model = "models/props_junk/wood_crate001a_chunk05.mdl"
ITEM.width = 2
ITEM.useTime = 5
ITEM.price = 6000

function ITEM:CanApply(client)
	if (next(ix.efg.health.GetStatus(client).fracture)) then return true end
	return false, "No tienes ninguna fractura."
end

function ITEM:Apply(client)
	return ix.efg.health.FixFracture(client) and 1 or 0
end
