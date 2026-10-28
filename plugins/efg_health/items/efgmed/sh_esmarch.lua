ITEM.name = "Torniquete"
ITEM.description = "Detiene un sangrado grave. Un solo uso."
ITEM.model = "models/weapons/sweps/eft/cat/w_meds_cat.mdl"
ITEM.medAnim = "tourniquet" -- animación (efg_health/sh_medanim.lua)
ITEM.useTime = 4
ITEM.price = 4500
ITEM.useSound = "esmarch"

function ITEM:CanApply(client, part)
	local bleed = ix.efg.health.GetStatus(client).bleed

	if (part) then
		if (bleed[part] == "heavy") then return true end
		return false, "Esa parte no tiene un sangrado grave."
	end

	for _, level in pairs(bleed) do
		if (level == "heavy") then return true end
	end

	return false, "No tienes ningún sangrado grave."
end

function ITEM:Apply(client, part)
	return ix.efg.health.StopBleeding(client, "heavy", part) and 1 or 0
end
