
ITEM.name = "Traje Alcalde Hanza"
ITEM.coldThreshold = -10 -- Traje del alcalde, mejor calidad (plugin temperatura)
ITEM.description = "Traje del alcalde de la estación"
ITEM.model = "models/kek1ch/rookie_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.85, -- Balas
			0.85, -- Corte
			0.9, -- Electricidad
			0.9, -- Fuego
			1, -- Radiación
			0.9, -- Ácido
			0.9, -- Explosión
}
ITEM.replacements = "models/magma/hansa/hansa_officer_01.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_scavelite.mdl"