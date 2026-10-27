ITEM.name = "Botiquín individual"
ITEM.description = "300 puntos de vida. Detiene sangrados leves y graves."
ITEM.model = "models/Items/HealthKit.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 3
ITEM.maxUses = 300 -- puntos de vida
ITEM.healPerUse = 50
ITEM.stopsBleed = "heavy"
ITEM.price = 15000

function ITEM:CanApply(client, part)
	return ix.efg.health.MedkitCanApply(self, client, part)
end

function ITEM:Apply(client, part)
	return ix.efg.health.MedkitApply(self, client, part)
end
