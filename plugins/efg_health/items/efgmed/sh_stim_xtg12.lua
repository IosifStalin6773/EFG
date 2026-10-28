-- Estimulante (efg_effects). Efectos en ix.efg.effects.stims.xtg12
ITEM.name = "xTG-12 (antídoto)"
ITEM.description = "Estimulante inyectable."
ITEM.model = "models/weapons/sweps/eft/injector/w_meds_injector.mdl"
ITEM.medAnim = "injector" -- animación (efg_health/sh_medanim.lua)
ITEM.skin = 13
ITEM.iconMaterial = "efg/meds/injectortg12.png"
ITEM.useTime = 2
ITEM.useSound = "pills"
ITEM.category = "Estimulantes"
ITEM.efgStim = "xtg12"
ITEM.price = ix.efg.effects and ix.efg.effects.stims.xtg12[2] or 30000

function ITEM:GetDescription()
	return self.description .. (ix.efg.effects and ("\n\n" .. ix.efg.effects.Describe(self.efgStim)) or "")
end

function ITEM:CanApply(client)
	return ix.efg.effects != nil, "Los estimulantes no están disponibles."
end

function ITEM:Apply(client)
	return ix.efg.effects.ApplyStim(client, self.efgStim) and 1 or 0
end
