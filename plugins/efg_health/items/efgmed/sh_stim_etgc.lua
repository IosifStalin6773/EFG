-- Estimulante (efg_effects). Efectos en ix.efg.effects.stims.etgc
ITEM.name = "eTG-change"
ITEM.description = "Estimulante inyectable."
ITEM.model = "models/healthvial.mdl"
ITEM.useTime = 2
ITEM.useSound = "pills"
ITEM.category = "Estimulantes"
ITEM.efgStim = "etgc"
ITEM.price = ix.efg.effects and ix.efg.effects.stims.etgc[2] or 30000

function ITEM:GetDescription()
	return self.description .. (ix.efg.effects and ("\n\n" .. ix.efg.effects.Describe(self.efgStim)) or "")
end

function ITEM:CanApply(client)
	return ix.efg.effects != nil, "Los estimulantes no están disponibles."
end

function ITEM:Apply(client)
	return ix.efg.effects.ApplyStim(client, self.efgStim) and 1 or 0
end
