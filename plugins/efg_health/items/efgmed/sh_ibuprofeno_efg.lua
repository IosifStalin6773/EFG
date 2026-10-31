-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Ibuprofeno"
ITEM.description = "Analgésico durante 280 segundos. 15 usos."
ITEM.model = "models/weapons/sweps/eft/augmentin/w_meds_augmentin.mdl"
ITEM.medWeapon = "weapon_eft_augmentin" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 2
ITEM.maxUses = 15
ITEM.price = 14000
ITEM.useSound = "pills"
ITEM.painSeconds = 280

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, self.painSeconds)
	return 1
end
