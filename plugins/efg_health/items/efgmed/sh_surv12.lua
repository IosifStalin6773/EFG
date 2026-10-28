-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Kit quirúrgico Surv12"
ITEM.description = "Recupera una extremidad destruida (queda con 1 de vida). 15 usos."
ITEM.model = "models/weapons/sweps/eft/surgicalkit/w_meds_surgicalkit.mdl"
ITEM.medAnim = "surgery" -- animación (efg_health/sh_medanim.lua)
ITEM.iconMaterial = "efg/meds/surgicalkit.png"
ITEM.width = 3
ITEM.height = 1
ITEM.useTime = 20
ITEM.maxUses = 15
ITEM.price = 50000
ITEM.useSound = "surgery"

function ITEM:CanApply(client, part)
	local hp = ix.efg.health.GetHP(client)

	if (part) then
		if (!ix.efg.health.byID[part].vital and hp[part] <= 0) then return true end
		return false, "Esa parte no está destruida (cabeza y tórax no se operan)."
	end

	for _, info in ipairs(ix.efg.health.parts) do
		if (!info.vital and hp[info.id] <= 0) then return true end
	end

	return false, "No tienes ninguna extremidad destruida."
end

function ITEM:Apply(client, part)
	return ix.efg.health.RestoreBlacked(client, part) and 1 or 0
end
