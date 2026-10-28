ITEM.name = "Ropa de mercader"
ITEM.coldThreshold = 0 -- Ropa cómoda de comercio (plugin temperatura)
ITEM.weight = 1.5
ITEM.description = "Ropa comoda para dedicarse al comercio, con multitud de bolsillos y lugares donde guardarse unas balas Protección: Baja."
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
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
ITEM.replacements = "models/magma/civilian/survivor9_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_0.mdl"