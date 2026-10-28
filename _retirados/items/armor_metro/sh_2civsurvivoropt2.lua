ITEM.name = "Abrigo de buscador reforzado"
ITEM.coldThreshold = -10 -- Abrigo reforzado de exploración (plugin temperatura)
ITEM.weight = 2.5
ITEM.description = "Abrigo reforzado con sitio para pertrechos y protección algo general, es lo que quieres llevar puesto para explorar lo que hay más allá de la oscuridad. Protección: Moderada"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.70, -- Balas
			0.75, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/civilian/survivor4_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"

