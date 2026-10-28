ITEM.name = "Chaqueta pertrechada de asaltante"
ITEM.coldThreshold = -10 -- Chaqueta con módulos de metal (plugin temperatura)
ITEM.description = "Chaqueta pertrechada capaz de colocar algunos modulos de metal para resistir la metralla"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.65, -- Bullets
			0.8, -- Slash
			0.9, -- Shock
			0.9, -- Burn
			1, -- Radiation
			0.9, -- Acid
			0.9, -- Explosion
}
ITEM.replacements = "models/bandits_redux/redux_bandit_mask3.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"
