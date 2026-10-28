ITEM.name = "Chaleco de Guerrillero"
ITEM.coldThreshold = -10 -- Chaleco ligero y pantalones rasgados, pasa frío (plugin temperatura)
ITEM.description = "Chaleco ligero y unos pantalones rasgados, una defensa decente en el metro, no se puede decir lo mismo de tus pintas"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Bullets
			0.8, -- Slash
			0.9, -- Shock
			0.9, -- Burn
			1, -- Radiation
			0.9, -- Acid
			0.9, -- Explosion
}
ITEM.replacements = "models/magma/bandits/bandit1_n.mdl"

ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"