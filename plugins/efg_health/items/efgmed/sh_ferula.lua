ITEM.name = "Férula inmovilizadora"
ITEM.description = "Inmoviliza una fractura. Un solo uso."
ITEM.model = "models/props_junk/wood_crate001a_chunk05.mdl"
ITEM.width = 2
ITEM.useTime = 5
ITEM.price = 6000
ITEM.useSound = "splint"

function ITEM:CanApply(client, part)
	local fracture = ix.efg.health.GetStatus(client).fracture

	if (part) then
		if (fracture[part]) then return true end
		return false, "Esa parte no está fracturada."
	end

	if (next(fracture)) then return true end
	return false, "No tienes ninguna fractura."
end

function ITEM:Apply(client, part)
	return ix.efg.health.FixFracture(client, part) and 1 or 0
end
