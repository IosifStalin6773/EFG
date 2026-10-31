-- Estimulante (efg_effects). Efectos en ix.efg.effects.stims.adrenaline
ITEM.name = "Inyector de adrenalina"
ITEM.description = "Estimulante inyectable."
ITEM.model = "models/weapons/sweps/eft/injector/w_meds_injector.mdl"
ITEM.medWeapon = "weapon_eft_injectoradrenaline" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.skin = 7
ITEM.useTime = 2
ITEM.useSound = "pills"
ITEM.category = "Estimulantes"
ITEM.efgStim = "adrenaline"
ITEM.price = ix.efg.effects and ix.efg.effects.stims.adrenaline[2] or 30000

function ITEM:GetDescription()
	return self.description .. (ix.efg.effects and ("\n\n" .. ix.efg.effects.Describe(self.efgStim)) or "")
end

function ITEM:CanApply(client)
	return ix.efg.effects != nil, "Los estimulantes no están disponibles."
end

function ITEM:Apply(client)
	return ix.efg.effects.ApplyStim(client, self.efgStim) and 1 or 0
end
