ITEM.name = "Equipo de Cazador Subterráneo"
ITEM.coldThreshold = -10 -- Ropa gruesa reforzada con cuero (plugin temperatura)
ITEM.weight = 2.5
ITEM.description = "Ropa gruesa reforzada con cuero endurecido y protección en brazos, priorizando la agilidad para combatir mutantes. Protección: Moderada"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.9, -- Balas
			0.8, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/bandits/bandit8_2_redux.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"

