
ITEM.name = "Traje CO Hanza"
ITEM.coldThreshold = -10 -- Uniforme de comandante, mejor calidad (plugin temperatura)
ITEM.description = "Uniforme del comandante de la estación"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.6, -- Bullets
			0.6, -- Slash
			0.6, -- Shock
			0.6, -- Burn
			1, -- Radiation
			0.6, -- Acid
			0.6, -- Explosion
}
ITEM.replacements = "models/ganza/hanza_officer.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_scavelite.mdl"