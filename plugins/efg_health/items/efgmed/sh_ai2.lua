ITEM.name = "Botiquín básico"
ITEM.description = "Botiquín básico: 100 puntos de vida. No detiene sangrados."
ITEM.model = "models/props_junk/garbage_metalcan002a.mdl"
ITEM.medAnim = "car_syringe" -- animación (efg_health/sh_medanim.lua)
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 2
ITEM.maxUses = 100 -- puntos de vida
ITEM.healPerUse = 50
ITEM.stopsBleed = ""
ITEM.price = 2500

function ITEM:CanApply(client, part)
	return ix.efg.health.MedkitCanApply(self, client, part)
end

function ITEM:Apply(client, part)
	return ix.efg.health.MedkitApply(self, client, part)
end
