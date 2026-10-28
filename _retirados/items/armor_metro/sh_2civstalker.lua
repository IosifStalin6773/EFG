
ITEM.name = "Traje improvisado de Stalker"
ITEM.coldThreshold = -15 -- Traje NBC sellado improvisado (plugin temperatura)
ITEM.weight = 3.0
ITEM.description = "Equipo NBC viejo adaptado con filtros improvisados y sellados reparados. Con esto es probable que la radiación no te mate tan rapido. Protección: Decente"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.8, -- Balas
			0.8, -- Corte
			0.8, -- Electricidad
			0.8, -- Fuego
			0.4, -- Radiación
			0.8, -- Ácido
			0.8, -- Explosión
}
ITEM.replacements = "models/magma/stalker/stalker_hazmat_face.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_meteor.mdl"