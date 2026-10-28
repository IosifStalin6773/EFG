-- Estimulante (efg_effects). Efectos en ix.efg.effects.stims.l1
ITEM.name = "L1 (Norepinefrina)"
ITEM.description = "Estimulante inyectable."
ITEM.model = "models/weapons/sweps/eft/injector/w_meds_injector.mdl"
ITEM.medAnim = "injector" -- animación (efg_health/sh_medanim.lua)
ITEM.skin = 4
ITEM.iconMaterial = "efg/meds/injectorl1.png"
ITEM.useTime = 2
ITEM.useSound = "pills"
ITEM.category = "Estimulantes"
ITEM.efgStim = "l1"
ITEM.price = ix.efg.effects and ix.efg.effects.stims.l1[2] or 30000

function ITEM:GetDescription()
	return self.description .. (ix.efg.effects and ("\n\n" .. ix.efg.effects.Describe(self.efgStim)) or "")
end

function ITEM:CanApply(client)
	return ix.efg.effects != nil, "Los estimulantes no están disponibles."
end

function ITEM:Apply(client)
	return ix.efg.effects.ApplyStim(client, self.efgStim) and 1 or 0
end
