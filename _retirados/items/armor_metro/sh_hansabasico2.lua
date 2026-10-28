ITEM.name = "Uniforme de guardia de Hanza"
ITEM.coldThreshold = -10 -- Uniforme básico de guardia (plugin temperatura)
ITEM.description = "Traje básico utilizado por los guardias de las estaciones de Hanza"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.maxArmor = 100
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Bullets
			0.7, -- Slash
			0.8, -- Shock
			0.8, -- Burn
			1, -- Radiation
			0.8, -- Acid
			0.8, -- Explosion
}
ITEM.replacements = "models/magma/hanzasoldier.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"