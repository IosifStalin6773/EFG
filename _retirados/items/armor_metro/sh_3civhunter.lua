ITEM.name = "Equipo de Cazador Veterano"
ITEM.coldThreshold = -15 -- Cuero endurecido + piel de mutante, muy cálido (plugin temperatura)
ITEM.weight = 3.5
ITEM.description = "Ropa gruesa reforzada con cuero endurecido y piel de mutante, muy resistente a los ataques de estos, algo débil en conflictos contra humanos. Protección: Buena"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.8, -- Balas
			0.6, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/stalker/stalker_01.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"

