ITEM.name = "Indumentaria de maleante"
ITEM.coldThreshold = 5 -- Cuero fino, apenas abriga (plugin temperatura)
ITEM.weight = 1.5
ITEM.description = "Chaqueta de cuero con algunas protecciones, la escoria y los maleantes del metro usan este tipo de indumentaria, pensada para imponer. Protección: Decadente"
ITEM.model = "models/kek1ch/rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.8, -- Balas
			0.8, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/bandits_redux/redux_bandit_mask.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_bomber.mdl"