-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Botiquín táctico AFAK"
ITEM.description = "400 puntos de vida. Detiene sangrados leves y graves."
ITEM.model = "models/weapons/sweps/eft/afak/w_meds_afak.mdl"
ITEM.medAnim = "afak" -- animación (efg_health/sh_medanim.lua)
ITEM.iconMaterial = "efg/meds/afak.png"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 3
ITEM.maxUses = 400
ITEM.price = 28000
ITEM.useSound = "salewa"
ITEM.healPerUse = 60
ITEM.stopsBleed = "heavy"

function ITEM:CanApply(client, part)
	local ok, why = ix.efg.health.MedkitCanApply(self, client, part)
	if (!ok and self.fixesFracture and next(ix.efg.health.GetStatus(client).fracture)) then return true end
	return ok, why
end

function ITEM:Apply(client, part)
	local spent = ix.efg.health.MedkitApply(self, client, part)

	if (self.fixesFracture and ix.efg.health.FixFracture(client, part)) then
		spent = spent + 50
	end

	return spent
end
