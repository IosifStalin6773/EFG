ITEM.name = "Chaqueta de matón veterano"
ITEM.coldThreshold = 0 -- Abrigo parcheado (plugin temperatura)
ITEM.description = "Abrigo parcheado y tuneado, en general lo suelen llevar los matones a sueldo de algún desgraciado. Protección: Moderada"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Bullets
			0.7, -- Slash
			0.9, -- Shock
			0.9, -- Burn
			1, -- Radiation
			0.9, -- Acid
			0.9, -- Explosion
}
ITEM.replacements = "models/magma/bandits/bandit_vishibala.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_underarmour.mdl"

