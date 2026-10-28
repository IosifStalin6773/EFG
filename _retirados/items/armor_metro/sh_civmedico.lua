
ITEM.name = "Traje medico civil"
ITEM.coldThreshold = 5 -- Bata médica ligera (plugin temperatura)
ITEM.weight = 1.5
ITEM.description = "Traje usado por los medicos civiles para ser reconocidos"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.9, -- Balas
			0.9, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/civilian/civilian_medic_2033.mdl"