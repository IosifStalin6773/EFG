ITEM.name = "Chaqueta Gruesa"
ITEM.coldThreshold = -5 -- Chaquetón grueso, buena para el frío (plugin temperatura)
ITEM.weight = 1.5
ITEM.description = "Chaquetón grueso con algunas protecciones, resistirás a los ataques de mutantes pequeños pero no parará mucho las balas. Protección: Decadente"
ITEM.model = "models/kek1ch/rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.8, -- Balas
			0.75, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/bandits/bandit7_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_yellowcoat.mdl"
