ITEM.name = "Botiquín de montaña"
ITEM.description = "400 puntos de vida. Detiene sangrados leves."
ITEM.model = "models/Items/HealthKit.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.useTime = 3
ITEM.maxUses = 400 -- puntos de vida
ITEM.healPerUse = 85
ITEM.stopsBleed = "light"
ITEM.price = 19000

function ITEM:CanApply(client, part)
	return ix.efg.health.MedkitCanApply(self, client, part)
end

function ITEM:Apply(client, part)
	return ix.efg.health.MedkitApply(self, client, part)
end
