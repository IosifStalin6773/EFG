ITEM.name = "Botiquín básico"
ITEM.description = "Botiquín básico: 100 puntos de vida. No detiene sangrados."
ITEM.model = "models/props_junk/garbage_metalcan002a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 2
ITEM.maxUses = 100 -- puntos de vida
ITEM.healPerUse = 50
ITEM.stopsBleed = ""
ITEM.price = 2500

function ITEM:CanApply(client)
	local health = ix.efg.health
	local hp = health.GetHP(client)

	for _, part in ipairs(health.parts) do
		if (hp[part.id] > 0 and hp[part.id] < part.max) then return true end
	end

	if (self.stopsBleed != "" and next(health.GetStatus(client).bleed)) then return true end

	return false, "Estás sano."
end

function ITEM:Apply(client)
	local health = ix.efg.health
	local spent = health.Heal(client, math.min(self.healPerUse, self:GetUses()))

	-- detener un sangrado cuesta puntos del botiquín, como en EFT
	if (self.stopsBleed != "" and health.StopBleeding(client, self.stopsBleed)) then
		spent = spent + (self.stopsBleed == "heavy" and 175 or 50)
	end

	return math.ceil(spent)
end
