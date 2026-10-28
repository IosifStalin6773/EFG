-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Bálsamo Estrella Dorada"
ITEM.description = "Analgésico durante 350 segundos. 10 usos."
ITEM.model = "models/weapons/sweps/eft/augmentin/w_meds_augmentin.mdl"
ITEM.medAnim = "bottle" -- animación (efg_health/sh_medanim.lua)
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 3
ITEM.maxUses = 10
ITEM.price = 12000
ITEM.useSound = "pills"
ITEM.painSeconds = 350

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, self.painSeconds)
	return 1
end
