ITEM.name = "Uniforme de guardia veterano de Hanza con pasamontañas"
ITEM.coldThreshold = -10 -- Uniforme pertrechado + pasamontañas (plugin temperatura)
ITEM.description = "Traje pertrechado con algo más de protección que los uniformes básicos"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.maxArmor = 100
ITEM.price = 20
ITEM.gasmask = false -- It will protect you from bad air
ITEM.resistance = true -- This will activate the protection bellow
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
            0.65, -- Bullets
            0.65, -- Slash
            0.8, -- Shock
            0.8, -- Burn
            1, -- Radiation
            0.8, -- Acid
            0.8, -- Explosion
}
ITEM.replacements = "models/magma/hanzasoldier2_nosok.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_1.mdl"
