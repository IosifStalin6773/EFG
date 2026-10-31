ITEM.name = "Kit quirúrgico de campaña"
ITEM.description = "Recupera una extremidad destruida (queda con 1 de vida). 5 usos."
ITEM.model = "models/weapons/sweps/eft/surgicalkit/w_meds_surgicalkit.mdl"
ITEM.medWeapon = "weapon_eft_surgicalkit" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.width = 2
ITEM.useTime = 15
ITEM.maxUses = 5
ITEM.price = 22000
ITEM.useSound = "surgery"

function ITEM:CanApply(client, part)
	local hp = ix.efg.health.GetHP(client)

	if (part) then
		if (!ix.efg.health.byID[part].vital and hp[part] <= 0) then return true end
		return false, "Esa parte no está destruida (cabeza y tórax no se operan)."
	end

	for _, part in ipairs(ix.efg.health.parts) do
		if (!part.vital and hp[part.id] <= 0) then return true end
	end

	return false, "No tienes ninguna extremidad destruida."
end

function ITEM:Apply(client, part)
	return ix.efg.health.RestoreBlacked(client, part) and 1 or 0
end
