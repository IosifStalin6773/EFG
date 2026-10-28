
ITEM.name = "Uniforme de sargento de la Guardia"
ITEM.coldThreshold = -10 -- Uniforme de guardia de mejor calidad (plugin temperatura)
ITEM.description = "Uniforme de Guardia de mejor calidad y que denota el rango del portador"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.maxArmor = 120
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.6, -- Bullets
			0.7, -- Slash
			0.7, -- Shock
			0.7, -- Burn
			1, -- Radiation
			0.7, -- Acid
			0.7, -- Explosion
}
ITEM.replacements = "models/magma/hansa/hansa_sgt_02.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_bomber.mdl"