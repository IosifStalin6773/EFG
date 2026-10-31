ITEM.name = "Torniquete"
ITEM.description = "Detiene un sangrado grave en un brazo o una pierna. Un solo uso."
ITEM.model = "models/weapons/sweps/eft/cat/w_meds_cat.mdl"
ITEM.medAnim = "tourniquet" -- animación (efg_health/sh_medanim.lua)
ITEM.useTime = 4
ITEM.price = 4500
ITEM.useSound = "esmarch"

local function isLimb(partID)
	local info = ix.efg.health.byID[partID]
	return info and (info.arm or info.leg) or false
end

-- como en KAT y EFT, el torniquete solo va en brazos y piernas
function ITEM:CanApply(client, part)
	local bleed = ix.efg.health.GetStatus(client).bleed

	if (part) then
		if (!isLimb(part)) then return false, "El torniquete solo se pone en brazos y piernas." end
		if (bleed[part] == "heavy") then return true end
		return false, "Esa parte no tiene un sangrado grave."
	end

	for partID, level in pairs(bleed) do
		if (level == "heavy" and isLimb(partID)) then return true end
	end

	return false, "No tienes ningún sangrado grave en brazos o piernas."
end

function ITEM:Apply(client, part)
	local health = ix.efg.health

	if (!part) then
		for partID, level in pairs(health.GetStatus(client).bleed) do
			if (level == "heavy" and isLimb(partID)) then part = partID break end
		end
	end

	return (part and health.StopBleeding(client, "heavy", part)) and 1 or 0
end
