ITEM.name = "Jersey con Chaleco de cuero"
ITEM.coldThreshold = 0 -- Jersey abriga algo, equipo ligero (plugin temperatura)
ITEM.weight = 1.5
ITEM.description = "Equipo ligero, con algo de protección general, común en túneles. Protección: Decadente"
ITEM.model = "models/kek1ch/rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.85, -- Balas
			0.85, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/bandits/bandit6.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"
