-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Augmentin (antibiótico)"
ITEM.description = "Analgésico durante 155 segundos. Un uso."
ITEM.model = "models/weapons/sweps/eft/augmentin/w_meds_augmentin.mdl"
ITEM.medAnim = "bottle" -- animación (efg_health/sh_medanim.lua)
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 5
ITEM.maxUses = 1
ITEM.price = 9500
ITEM.useSound = "pills"
ITEM.painSeconds = 155

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, self.painSeconds)
	return 1
end
