-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Hemostático Calok-B"
ITEM.description = "Detiene un sangrado leve o grave. Tres usos."
ITEM.model = "models/props_lab/jar01b.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 3
ITEM.maxUses = 3
ITEM.price = 9000
ITEM.useSound = "esmarch"
ITEM.bleedLevel = "all1"

function ITEM:CanApply(client, part)
	local bleed = ix.efg.health.GetStatus(client).bleed
	local want = self.bleedLevel

	local function ok(level) return level and (want == "all1" or level == want) end

	if (part) then
		if (ok(bleed[part])) then return true end
		return false, "Esa parte no tiene un sangrado que pueda parar."
	end

	for _, level in pairs(bleed) do
		if (ok(level)) then return true end
	end

	return false, "No tienes ningún sangrado que pueda parar."
end

function ITEM:Apply(client, part)
	local health = ix.efg.health

	if (self.bleedLevel == "all1") then
		return (health.StopBleeding(client, "heavy", part) or health.StopBleeding(client, "light", part)) and 1 or 0
	end

	return health.StopBleeding(client, self.bleedLevel, part) and 1 or 0
end
