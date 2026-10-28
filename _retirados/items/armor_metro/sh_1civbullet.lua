ITEM.name = "Traje de cuero"
ITEM.coldThreshold = -5 -- Chaqueta de cuero fina (plugin temperatura)
ITEM.weight = 2.0
ITEM.description = "Chaqueta de cuero con algunas protecciones, si el enemigo atina mal te salvará de algún disparo. Protección: Decadente"
ITEM.model = "models/kek1ch/rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Balas
			0.9, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/bandits/bandit4.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_bomber.mdl"