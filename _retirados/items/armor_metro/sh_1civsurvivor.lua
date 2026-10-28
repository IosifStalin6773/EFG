ITEM.name = "Abrigo de superviviente"
ITEM.coldThreshold = -5 -- Abrigo de túnel (plugin temperatura)
ITEM.weight = 2.0
ITEM.description = "Equipo remendado con ropa reutilizada. Común en túneles. Protección: Decadente"
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
ITEM.replacements = "models/magma/bandits/bandit6_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_3.mdl"
