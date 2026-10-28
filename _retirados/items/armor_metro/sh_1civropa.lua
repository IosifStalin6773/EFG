
ITEM.name = "Ropa remendada"
ITEM.coldThreshold = 0 -- Ropa para cubrirse del frío, modesta (plugin temperatura)
ITEM.weight = 1.0
ITEM.description = "Maleta con algo de ropa para cubrirse del frio. Protección: Decadente"
ITEM.model = "models/kek1ch/cs_rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.95, -- Balas
			0.95, -- Corte
			0.95, -- Electricidad
			0.95, -- Fuego
			1, -- Radiación
			0.95, -- Ácido
			0.95, -- Explosión
}
ITEM.replacements = "models/magma/civilian/max_les.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_bomber.mdl"