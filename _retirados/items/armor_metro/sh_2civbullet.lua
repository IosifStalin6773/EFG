ITEM.name = "Chaleco de Seguridad Metro"
ITEM.coldThreshold = -10 -- Chaleco con placas, no es abrigo (plugin temperatura)
ITEM.weight = 2.5
ITEM.description = "Equipo reutilizado de seguridad ferroviaria con placas ligeras y casco básico, te hace resistente, pero también más lento. Protección: Moderada"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.7, -- Balas
			0.7, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/civilian/survivor10_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_2.mdl"
