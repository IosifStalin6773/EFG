ITEM.name = "Botiquín de coche"
ITEM.description = "220 puntos de vida. Detiene sangrados leves."
ITEM.model = "models/weapons/sweps/eft/automedkit/w_meds_automedkit.mdl"
ITEM.medWeapon = "weapon_eft_automedkit" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.width = 2
ITEM.height = 1
ITEM.useTime = 3
ITEM.maxUses = 220 -- puntos de vida
ITEM.healPerUse = 70
ITEM.stopsBleed = "light"
ITEM.price = 9000

function ITEM:CanApply(client, part)
	return ix.efg.health.MedkitCanApply(self, client, part)
end

function ITEM:Apply(client, part)
	return ix.efg.health.MedkitApply(self, client, part)
end
