
ITEM.name = "Traje Stalker Hansa"
ITEM.coldThreshold = -15 -- Traje sellado para entornos peligrosos (plugin temperatura)
ITEM.description = "Traje especializado de Hansa para entornos peligrosos, "
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.maxArmor = 150
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Bullets
			0.7, -- Slash
			0.7, -- Shock
			0.7, -- Burn
			0.3, -- Radiation
			0.7, -- Acid
			0.7, -- Explosion
}
ITEM.replacements = "models/magma/exodushanza/hazmat.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_meteor.mdl"