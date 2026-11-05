-- Datos del equipo modular (chalecos, placas, cascos, módulos y mochilas).
-- Fuente: tablas de la wiki de EFT que pasó Oscar (2026-11-05). Lo que no tiene
-- valor confirmado va marcado [VERIFICAR].
-- Va en libs/ para que los ítems y efg_ballistics puedan leerlo al cargar.

ix.efg = ix.efg or {}
ix.efg.equipment = ix.efg.equipment or {}

local equipment = ix.efg.equipment

-- Coeficiente de destructibilidad por material (EFT). Durabilidad efectiva =
-- durabilidad nominal / coeficiente. Cuanto menor, más débil frente a impactos.
equipment.materials = {
	aramid = {name = "Aramida", coef = 0.1875},
	uhmwpe = {name = "UHMWPE", coef = 0.3375},
	combined = {name = "Material combinado", coef = 0.375},
	titanium = {name = "Titanio", coef = 0.4125},
	aluminium = {name = "Aluminio", coef = 0.45},
	steel = {name = "Acero balístico", coef = 0.525},
	ceramic = {name = "Cerámica", coef = 0.6},
	glass = {name = "Vidrio", coef = 0.6}
}

-- Alias: efg_ballistics llama "titan" al titanio.
equipment.materials.titan = equipment.materials.titanium

-- Durabilidad efectiva de una placa o un blindaje según su material.
function equipment.EffectiveDurability(nominal, material)
	local data = equipment.materials[material]
	return data and (nominal / data.coef) or nominal
end

-- Coeficiente que usa efg_ballistics como destructibilidad al recibir un impacto.
-- [VERIFICAR con Oscar] El texto de la especificación dice a la vez que un coeficiente
-- menor pierde integridad más rápido y que la cerámica (0.6) se degrada más que el
-- acero (0.525). Aquí se aplica tal cual: cerámica degrada más que acero.
function equipment.LossFactor(material)
	local data = equipment.materials[material]
	return data and data.coef or nil
end

-- Portaplacas y chalecos. slots: ranuras de placa que declara el carrier.
-- softClass: clase del blindaje blando integrado (0 si no lleva).
equipment.carriers = {
	paca_soft = {
		name = "PACA Soft Armor", weight = 4.0, softClass = 2,
		softZones = {"stomach", "thorax", "back", "sides"},
		slots = {}
	},
	armor_6b13 = {
		name = "6B13 chaleco de asalto", weight = 7.0, softClass = 2,
		softZones = {"stomach", "thorax", "back", "sides", "throat", "nape", "groin"},
		slots = {front = true, back = true}
	},
	lbt_6094a = {
		name = "LBT-6094A Slick", weight = 1.0, softClass = 3,
		softZones = {"thorax", "back"},
		slots = {front = true, back = true}
	},
	korund_vm = {
		name = "Korund-VM", weight = 8.0, softClass = 2,
		softZones = {"stomach", "thorax", "back", "sides", "throat", "nape", "groin", "buttocks"},
		slots = {front = true, back = true, sides = true}
	},
	tactical_hexgrid = {
		name = "5.11 Tactical Hexgrid", weight = 1.02, softClass = 0,
		softZones = {},
		slots = {front = true, back = true}
	}
}

-- Placas. zones: posición física en el carrier (front, back, sides).
-- covers: zonas del cuerpo que protege (de efg_health).
-- durability: durabilidad nominal (la efectiva sale de equipment.EffectiveDurability).
equipment.plates = {
	gac_3s15m = {
		name = "GAC 3s15m", class = 5, material = "uhmwpe", zones = {"front", "back"},
		covers = {"thorax"}, durability = 45, weight = 0.97
	},
	gac_4sss2 = {
		name = "GAC 4sss2", class = 6, material = "uhmwpe", zones = {"front", "back"},
		covers = {"thorax"}, durability = 55, weight = 1.1
	},
	bar_6b12 = {
		name = "6B12 (frontal)", class = 3, material = "steel", zones = {"front"},
		covers = {"thorax"}, durability = 50, weight = 4.6
	},
	zhuk_3 = {
		name = "Zhuk-3 (frontal)", class = 3, material = "uhmwpe", zones = {"front"},
		covers = {"thorax"}, durability = 40, weight = 2.4
	},
	ar500_legacy = {
		name = "AR500 Legacy", class = 3, material = "combined", zones = {"front", "back"},
		covers = {"thorax"}, durability = 45, weight = 3.85
	}
}

-- Cascos. slots: ranuras de módulo que declara el casco.
-- Los slots de FAST y Altyn son [VERIFICAR]: la wiki no dio tabla de cascos.
equipment.helmets = {
	fast = {
		name = "Ops-Core FAST (ligero)", class = 2, weight = 1.2, ergoPenalty = 0,
		slots = {nvg = true, headset = true, light = true} -- [VERIFICAR]
	},
	altyn = {
		name = "Altyn (pesado)", class = 4, weight = 2.6, ergoPenalty = 10,
		slots = {visor = true, jaw = true, ears = true} -- [VERIFICAR]
	}
}

-- Módulos de casco. slot: ranura que ocupa. zones: zonas de cabeza que cubre.
equipment.helmetModules = {
	visor_ballistic = {
		name = "Visor balístico", slot = "visor", material = "glass",
		zones = {"head", "eyes"}, flashbangReduction = 0.5, weight = 0.4, ergoPenalty = 3, turnSpeedPenalty = 2 -- [VERIFICAR]
	},
	jaw_guard = {
		name = "Protector de mandíbula", slot = "jaw", class = 3,
		zones = {"head"}, weight = 0.5, ergoPenalty = 2, turnSpeedPenalty = 1 -- [VERIFICAR]
	},
	nvg_mount = {
		name = "Montura NVG", slot = "nvg", weight = 0.2, ergoPenalty = 1, turnSpeedPenalty = 0 -- [VERIFICAR]
	},
	headset_std = {
		name = "Headset", slot = "headset", weight = 0.2, ergoPenalty = 0, turnSpeedPenalty = 0 -- [VERIFICAR]
	}
}

-- Mochilas modulares. removableModules: módulos que se pueden quitar.
equipment.backpacks = {
	tt_modular_45 = {
		name = "Tasmanian Tiger Modular Pack 45", weight = 1.4, capacity = 45,
		removableModules = {
			topFlap = {capacityDelta = -5, profileDelta = -1, weight = 0.2} -- [VERIFICAR]
		}
	}
}

-- Ranuras por tipo de equipo, para validar en slots.
equipment.slotLabels = {
	front = "Frontal", back = "Trasera", sides = "Laterales",
	visor = "Visor", jaw = "Mandíbula", ears = "Orejas",
	nvg = "NVG", light = "Luz", headset = "Headset"
}
