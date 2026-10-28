
ITEM.name = "Uniforme de Ranger"
ITEM.weight = 4.5
ITEM.description = "Uniforme del oficial al mando de la unidad expedicionaria del cuerpo de Rangers"
ITEM.model = "models/kek1ch/cs_heavy_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.noLoot = true
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.6, -- Balas
			0.6, -- Corte
			0.7, -- Electricidad
			0.7, -- Fuego
			0.7, -- Radiación
			0.7, -- Ácido
			0.7, -- Explosión
}
ITEM.coldThreshold = -25 -- Aísla del frío hasta -25°C (plugin temperatura)
ITEM.handsModel = "models/eft/hands/hand_scav_0.mdl"
ITEM.replacements = "models/magma/storycharacters/spartan_ilya.mdl"