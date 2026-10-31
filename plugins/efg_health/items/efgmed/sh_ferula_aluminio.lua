-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Férula de aluminio"
ITEM.description = "Inmoviliza una fractura. Cinco usos."
ITEM.model = "models/weapons/sweps/eft/alusplint/w_meds_alusplint.mdl"
ITEM.medWeapon = "weapon_eft_alusplint" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.iconMaterial = "efg/meds/alusplint.png"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 5
ITEM.maxUses = 5
ITEM.price = 15000
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
