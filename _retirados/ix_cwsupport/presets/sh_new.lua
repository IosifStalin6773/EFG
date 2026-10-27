
-- ── Slot 1 · Pistolas (2×2) ──────────────────────────────────────────────────

PLUGIN.gunData["cw_kry_metro_2k33_revolver"] = {
    name = "Revolver",
    desc = "Revólver artesanal ensamblado con tubería y muelles recuperados. Poco preciso, pero seis balas en un cilindro pueden salvarte la vida.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 1, price = 150, width = 2, height = 2, weight = 0.8,
    iconCam = {
        pos = Vector(167.56, 135.85, 98.36),
        ang = Angle(25, 220, 0),
        fov = 2.76
    }

}

PLUGIN.gunData["cw_metro2033_ashot"] = {
    name = "Ashot",
    desc = "Pistola-escopeta casera hecha con restos de cañerías. Un disparo de postas a quemarropa y poco más, pero en los túneles oscuros eso basta.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 1, price = 100, width = 2, height = 2, weight = 1.5,
    iconCam = {
        pos = Vector(167.56, 135.85, 98.36),
        ang = Angle(25, 220, 0),
        fov = 2.76
    }
}

PLUGIN.gunData["cw_metro2033_padonak"] = {
    name = "Padonak",
    desc = "Pistola semiautomática casera. Escupe balas rapidamente y es mortal antes de necesitar recarga.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 1, price = 150, width = 2, height = 2, weight = 2.0,
    iconCam = {
        pos = Vector(268.34, 222.76, 160.73),
        ang = Angle(25, 220, 0),
        fov = 2.39
    }

}

-- ── Slot 2 · Rifles y escopetas (3×2) ────────────────────────────────────────

PLUGIN.gunData["cw_kry_metro_2k33_ak"] = {
    name = "Kalash",
    desc = "El viejo y fiable AK-47. Sobrevivió al fin del mundo igual que sus portadores. Cada facción del metro lucha por hacerse con uno.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 400, width = 3, height = 2, weight = 3.6,
    iconCam = {
	pos = Vector(523.46, 429.43, 312.1),
	ang = Angle(25, 220, 0),
	fov = 2.26
    }
}

PLUGIN.gunData["cw_kry_metro_2k33_ak2012"] = {
    name = "Kalash 2012",
    desc = "Variante modernizada del Kalash diseñada antes de las bombas. Más preciso, más fiable, y mucho más difícil de conseguir.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 550, width = 3, height = 2, weight = 3.8,
    iconCam = {
        pos = Vector(436.81, 372.26, 269.8),
        ang = Angle(25, 220, 0),
        fov = 3.04
    },
}

PLUGIN.gunData["cw_kry_metro_2k33_aksu"] = {
    name = "Kalash su",
    desc = "Versión acortada del Kalash, ideal para los espacios estrechos del metro. Lo que pierde en precisión lo gana en movilidad.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 380, width = 3, height = 2, weight = 3.0,
    iconCam = {
        pos = Vector(523.46, 429.43, 312.1),
        ang = Angle(25, 220, 0),
        fov = 2.13
    }

}

PLUGIN.gunData["cw_kry_metro_2k33_duplet"] = {
    name = "Duplet",
    desc = "Escopeta de doble cañón soldada a mano en algún taller del metro. Dos disparos, dos oportunidades. Si no basta, corre.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-9, 8, -4) },
    slot = 2, price = 220, width = 3, height = 2, weight = 3.2,
    iconCam = {
        pos = Vector(598.05, 502.75, 363.66),
        ang = Angle(25, 220, 0),
        fov = 2.83
    }

}

PLUGIN.gunData["cw_kry_metro_2k33_rpk"] = {
    name = "RPK",
    desc = "Ametralladora ligera soviética con cargador extendido. Pesada y ruidosa, pero cuando hay una horda de mutantes el ruido es lo de menos.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 600, width = 3, height = 2, weight = 5.5,
    iconCam = {
        pos = Vector(495.58, 422.28, 303.37),
        ang = Angle(25, 220, 0),
        fov = 3.35
    }
}

PLUGIN.gunData["cw_kry_metro_2k33_saiga"] = {
    name = "Saiga",
    desc = "Escopeta semiautomática con cargador de tambor. Un lujo destructivo que solo los mejor armados del metro pueden permitirse.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 600, width = 3, height = 2, weight = 3.8,
    iconCam = {
        pos = Vector(584.82, 491.2, 353.93),
        ang = Angle(25, 220, 0),
        fov = 2.97
    }
}

PLUGIN.gunData["cw_kry_metro_2k33_ubludok"] = {
    name = "Bastarda",
    desc = "Subfusil artesanal fabricado en los talleres del metro. Tosco pero funcional, como casi todo lo que mantiene viva a la gente aquí abajo.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 350, width = 3, height = 2, weight = 3.5,
    iconCam = {
	pos = Vector(245.62, 199.62, 147.15),
	ang = Angle(25, 220, 0),
	fov = 4.92
    },
}

PLUGIN.gunData["cw_kry_metro_2k33_uboynik"] = {
    name = "Shambler",
    desc = "Escopeta artesanal. Cada disparo retumba como un trueno en los túneles, y suele ser igual de definitivo.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 250, width = 3, height = 2, weight = 3.8,
    iconCam = {
        pos = Vector(523.46, 429.43, 312.1),
        ang = Angle(25, 220, 0),
        fov = 2.39
    }

}

PLUGIN.gunData["cw_kry_metro_tikhar"] = {
    name = "Tikhar",
    desc = "Rifle neumático artesanal que dispara rodamientos de acero. Silencioso y letal, pero hay que bombear presión entre cada tiro.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 270, width = 3, height = 2, weight = 2.8,
    iconCam = {
        pos = Vector(375.66, 310.18, 226.69),
        ang = Angle(25, 220, 0),
        fov = 3.06
    }
}

PLUGIN.gunData["cw_metro2033_hellsing"] = {
    name = "Hellsing",
    desc = "Ballesta neumática artesanal que dispara pernos de acero impulsados por aire comprimido. Silenciosa y letal, cada impacto atraviesa sin anunciarse.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 350, width = 3, height = 2, weight = 3.5,
    model = "models/w_weapons/hellsing/w_hellsing.mdl",
    iconCam = {
        pos = Vector(375.66, 310.18, 226.69),
        ang = Angle(25, 220, 0),
        fov = 3.06
    }
}

PLUGIN.gunData["cw_metro2033_vsv"] = {
    name = "VSV",
    desc = "Rifle semiautomático con silenciador integrado. Una reliquia militar pre-guerra, codiciada por stalkers y Rangers por igual.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 475, width = 3, height = 2, weight = 3.0,
    model = "models/w_weapons/vsv/w_vsv.mdl",
    iconCam = {
        pos = Vector(325.33, 270.34, 195.07),
        ang = Angle(25, 220, 0),
	    fov = 3.51
    },

}

-- ── Slot 2 · Armas pesadas anchas (4×2) ──────────────────────────────────────

PLUGIN.gunData["cw_kry_metro_2k33_gatling"] = {
    name = "Gatling",
    desc = "Ametralladora rotativa montada sobre un armazón artesanal. Devora munición como nada, pero nada sobrevive a su paso.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 750, width = 4, height = 2, weight = 12.0,
    model = "models/w_weapons/w_gatling.mdl",
    iconCam = {
        pos = Vector(696.94, 589.73, 426.67),
        ang = Angle(25, 220, 0),
	    fov = 3.58
    },

}

PLUGIN.gunData["cw_metro2033_abzats"] = {
    name = "Abzats",
    desc = "Escopeta automática pesada de fabricación casera. Cuando los túneles se llenan de garras y colmillos, esta es la respuesta.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 600, width = 4, height = 2, weight = 6.5,
    iconCam = {
        pos = Vector(746.06, 629.68, 460.69),
        ang = Angle(25, 220, 0),
        fov = 4.09
    }

}

PLUGIN.gunData["cw_mexo_flamethrower"] = {
    desc = "Tanque de combustible, válvula y un encendedor. Elemental en su diseño, devastador en su propósito. El fuego no negocia.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 2, price = 800, width = 4, height = 2, weight = 11.0,
}

-- ── Slot 3 · Armas largas/pesadas (4×2) ──────────────────────────────────────

PLUGIN.gunData["cw_kry_metro_2k33_ventil"] = {
    name = "Ventil",
    desc = "Rifle neumático de alta presión con cargador rotativo. Silencioso y preciso, para stalkers que prefieren no anunciar su presencia.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 3, price = 700, width = 4, height = 2, weight = 5.5,
    iconCam = {
        pos = Vector(714.6, 605.57, 437.84),
        ang = Angle(25, 220, 0),
        fov = 3.41
    },
}

PLUGIN.gunData["cw_kry_metro_relsa"] = {
    name = "HellBreath",
    desc = "Fusil electromagnético artesanal que acelera proyectiles por un riel improvisado. Tan peligroso para el objetivo como para quien lo porta.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 3, price = 500, width = 4, height = 2, weight = 6.0,
    iconCam = {
        pos = Vector(714.6, 605.57, 437.84),
        ang = Angle(25, 220, 0),
        fov = 3.41
    },

}

PLUGIN.gunData["cw_metro2033_preved"] = {
    name = "Preved",
    desc = "Lanzagranadas artesanal de tubo. Un disparo, una explosión. Lo que había en el otro extremo del túnel ya no está.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 3, price = 1000, width = 4, height = 2, weight = 8.0,
    iconCam = {
        pos = Vector(714.6, 605.57, 437.84),
        ang = Angle(25, 220, 0),
        fov = 4.41
    },
}

PLUGIN.gunData["cw_metro2033_vihlop"] = {
    name = "Vihlop",
    desc = "Rifle antimateria artesanal. El retroceso rompe hombros, pero el proyectil rompe todo lo demás.",
    holster = { bone = "ValveBiped.Bip01_R_Clavicle", ang = Angle(-4.219, 1.031, 7.094), pos = Vector(-6, 8, -4) },
    slot = 3, price = 1250, width = 4, height = 2, weight = 11.0,
       iconCam = {
        pos = Vector(714.6, 605.57, 437.84),
        ang = Angle(25, 220, 0),
        fov = 4.41
    },
}
