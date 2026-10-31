ITEM.name = "Analgésico"
ITEM.description = "Analgésico: quita el dolor durante 95 segundos. 4 usos."
ITEM.model = "models/weapons/sweps/eft/anaglin/w_meds_anaglin.mdl"
ITEM.medWeapon = "weapon_eft_anaglin" -- arma de la animación (efg_health/sh_medanim.lua)
ITEM.useTime = 2
ITEM.maxUses = 4
ITEM.price = 7000
ITEM.useSound = "pills"

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, 95)
	return 1
end
