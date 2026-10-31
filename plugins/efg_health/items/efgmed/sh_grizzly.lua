-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Botiquín Grizzly"
ITEM.description = "1800 puntos de vida. Detiene sangrados leves y graves y trata fracturas."
ITEM.model = "models/weapons/sweps/eft/grizzly/w_meds_grizzly.mdl"
ITEM.medWeapon = "weapon_eft_grizzly" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.iconMaterial = "efg/meds/grizzly.png"
ITEM.width = 2
ITEM.height = 2
ITEM.useTime = 5
ITEM.maxUses = 1800
ITEM.price = 42000
ITEM.useSound = "salewa"
ITEM.healPerUse = 175
ITEM.stopsBleed = "heavy"
ITEM.fixesFracture = true

function ITEM:CanApply(client, part)
	local ok, why = ix.efg.health.MedkitCanApply(self, client, part)
	if (ok or !self.fixesFracture) then return ok, why end

	-- también entablilla: en la parte elegida, o en cualquiera si no se ha elegido
	local fracture = ix.efg.health.GetStatus(client).fracture

	if (part and ix.efg.health.GetHP(client)[part] > 0) then
		if (fracture[part]) then return true end
		return ok, why
	end

	if (!part and next(fracture)) then return true end
	return ok, why
end

function ITEM:Apply(client, part)
	local spent = ix.efg.health.MedkitApply(self, client, part)

	if (self.fixesFracture and ix.efg.health.FixFracture(client, part)) then
		spent = spent + 50
	end

	return spent
end
