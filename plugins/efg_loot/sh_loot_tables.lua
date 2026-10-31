-- ============================================================================
--  Tablas de loot (datos). Nada de esto lleva lógica: sh_roll.lua las lee.
--
--  Categorías (LOOT.Categories)
--    weight  peso base cuando una tabla no da el suyo (tablas con base = true)
--    pool    de dónde salen los objetos:
--              flags      = {"isAmmo"}               campos del ITEM que deben ser true
--              categories = {"Medicamentos"}         ITEM.category admitidas
--              items      = {"id", {id = "bala", weight = 2, count = {500, 15000}}}
--            una entrada de items puede llevar:
--              weight   peso propio (si no, el de rareza o el de precio)
--              count    {min, max} para objetos con cantidad
--              dataKey  dato que guarda la cantidad (por defecto "count")
--    stack   cantidad para los objetos del pool que se apilan:
--              {key = "rounds", field = "ammoAmount", min = 0.3, max = 1}
--              key = dato del objeto, field = campo del ITEM con el máximo,
--              min/max = fracción de ese máximo.
--
--  Tablas (LOOT.Tables)
--    rolls       {min, max} objetos que se generan
--    categories  {categoria = peso}; si falta, se usan los pesos base
--    base        true = usar los pesos base de LOOT.Categories
--    filters     nombres de LOOT.Filters que debe pasar cada objeto
--    weighting   "rarity" (por defecto), "price" (inversa al precio) o "flat"
--    w, h        tamaño de la rejilla cuando la tabla es un contenedor
--
--  Tablas por mapa (LOOT.MapTables)
--    LOOT.MapTables[mapa][tabla] = {add = {categoria = {entradas}}, categories = {...}}
--    "add" añade objetos al pool de una categoría solo en ese mapa y
--    "categories" sustituye pesos. El Documento A solo da objetos exclusivos
--    de mapa para los escondites (stashes), que no son de este plugin, así que
--    para contenedores del mundo y cadáveres no hay ninguna entrada.
--
--  Precios y probabilidades marcados [VERIFICAR]: aproximación a la wiki de EFT.
-- ============================================================================

local LOOT = ix.efg.loot

-- Referencia de la ponderación por precio: un objeto de este precio (RUB)
-- pesa la mitad que uno gratis con efgLootPMCPriceWeight = 1.
LOOT.priceReference = 10000

LOOT.Categories = {
	medicina = {
		weight = 30,
		name = "Medicina",
		pool = {
			categories = {"Medicamentos", "Estimulantes"},
			items = {"ophthalmoscope", "bottle_of_hydrogen_peroxide", "pile_of_meds", "ledx_skin_transilluminator"}
		}
	},
	municion = {
		weight = 25,
		name = "Munición",
		pool = {flags = {"isAmmo"}},
		stack = {key = "rounds", field = "ammoAmount", min = 0.3, max = 1}
	},
	cargadores = {
		weight = 0,
		name = "Cargadores",
		pool = {flags = {"isMagazine"}}
	},
	mods = {
		weight = 20,
		name = "Accesorios de arma",
		pool = {flags = {"isEFGMod"}, categories = {"ARC9 Attachments"}}
	},
	dinero = {
		weight = 15,
		name = "Dinero",
		pool = {
			items = {
				{id = "bala", weight = 10, count = {500, 15000}},
				{id = "dolares", weight = 2, count = {10, 200}},
				{id = "euros", weight = 1, count = {10, 150}},
				{id = "simple_wallet", weight = 3, count = {1000, 15000}},
				{id = "wz_wallet", weight = 1, count = {5000, 40000}}
			}
		}
	},
	llaves = {
		weight = 3,
		name = "Llaves",
		pool = {flags = {"isEFGKey"}}
	},
	inteligencia = {
		weight = 2,
		name = "Inteligencia",
		pool = {
			items = {
				{id = "slim_diary", weight = 4},
				{id = "secure_flash_drive", weight = 3},
				{id = "sas_drive", weight = 1.5},
				{id = "intelligence_folder", weight = 1},
				{id = "military_flash_drive", weight = 0.5}
			}
		}
	},
	raro = {
		weight = 1,
		name = "Objetos raros",
		pool = {
			items = {
				{id = "gingy_keychain", weight = 6},
				{id = "simple_wallet", weight = 5, count = {1000, 15000}},
				{id = "wz_wallet", weight = 2, count = {5000, 40000}},
				{id = "golden_neck_chain", weight = 4},
				{id = "roler_submariner_gold_wrist_watch", weight = 2},
				{id = "golden_rooster_figurine", weight = 1.5},
				{id = "secure_flash_drive", weight = 2},
				{id = "intelligence_folder", weight = 1},
				{id = "bitcoin", weight = 0.6},
				{id = "tarjeta_grafica", weight = 0.4},
				{id = "ledx_skin_transilluminator", weight = 0.3}
			}
		}
	},
	-- Las de abajo no salen en las tablas con pesos base (weight = 0):
	-- solo donde una tabla las pide.
	trueque = {
		weight = 0,
		name = "Trueque",
		pool = {
			items = {
				"bolts", "pack_of_screws", "pack_of_nails", "duct_tape", "insulating_tape",
				"corrugated_hose", "toilet_paper", "wd_40_100ml", "light_bulb", "spark_plug"
			}
		}
	},
	electronica = {
		weight = 0,
		name = "Electrónica",
		pool = {
			items = {
				"bundle_of_wires", "capacitors", "printed_circuit_board", "cpu_fan", "broken_gphone_smartphone",
				"phase_control_relay", "tetriz_portable_game_console", "military_cable", "tarjeta_grafica"
			}
		}
	},
	provisiones = {
		weight = 0,
		name = "Comida y bebida",
		pool = {items = {"water", "canned", "bread", "sausage", "milk", "energy", "vodka", "soda"}}
	},
	armas = {
		weight = 0,
		name = "Armas",
		pool = {flags = {"isARC9"}}
	}
}

LOOT.Tables = {
	-- ── Scav de IA ──────────────────────────────────────────────────────────
	-- Documento A: bolsillos solo 1x1; la mochila sin cargadores ni balas;
	-- un objeto raro posible por Scav (efgLootScavRareChance).
	scav_pockets = {
		rolls = {1, 3},
		categories = {medicina = 30, municion = 30, dinero = 25, provisiones = 15},
		filters = {"size1x1"}
	},
	scav_vest = {
		rolls = {1, 4},
		categories = {municion = 50, cargadores = 25, medicina = 25}
	},
	scav_backpack = {
		rolls = {0, 5},
		categories = {trueque = 35, provisiones = 25, electronica = 15, medicina = 15, mods = 10},
		filters = {"noAmmo", "noMagazines"}
	},
	scav_rare = {
		rolls = {1, 1},
		categories = {raro = 60, llaves = 25, inteligencia = 15}
	},
	-- Contenedor genérico "Dead Scav" del cadáver (Documento B)
	scav_body = {
		rolls = {0, 3},
		w = 4, h = 4,
		categories = {trueque = 40, provisiones = 30, medicina = 20, dinero = 10}
	},

	-- ── PMC de IA (ponderación inversa al precio) ───────────────────────────
	pmc_backpack = {
		rolls = {2, 8},
		weighting = "price",
		categories = {trueque = 25, electronica = 15, medicina = 15, mods = 15, provisiones = 10,
			municion = 10, inteligencia = 5, raro = 5},
		filters = {"noBags"}
	},
	pmc_pockets = {
		rolls = {1, 4},
		weighting = "price",
		categories = {medicina = 30, municion = 25, dinero = 25, llaves = 10, inteligencia = 5, raro = 5},
		filters = {"size1x1"}
	},
	pmc_vest = {
		rolls = {2, 6},
		weighting = "price",
		categories = {municion = 45, cargadores = 35, medicina = 20}
	},

	-- ── Contenedores del mundo ──────────────────────────────────────────────
	world_container = {
		rolls = {1, 5},
		w = 4, h = 4,
		base = true
	},
	world_jacket = {
		rolls = {0, 2},
		w = 2, h = 2,
		categories = {dinero = 40, llaves = 30, provisiones = 20, inteligencia = 5, raro = 5},
		filters = {"size1x1"}
	},
	world_drawer = {
		rolls = {0, 3},
		w = 3, h = 2,
		categories = {trueque = 35, dinero = 25, electronica = 20, llaves = 10, inteligencia = 10}
	},
	world_toolbox = {
		rolls = {1, 4},
		w = 4, h = 3,
		categories = {trueque = 70, electronica = 30}
	},
	world_pc = {
		rolls = {0, 2},
		w = 2, h = 2,
		categories = {electronica = 85, inteligencia = 15}
	},
	world_medcase = {
		rolls = {1, 4},
		w = 4, h = 4,
		categories = {medicina = 100}
	},
	world_ammo = {
		rolls = {1, 4},
		w = 4, h = 4,
		categories = {municion = 80, cargadores = 20}
	},
	world_weapon_box = {
		rolls = {1, 3},
		w = 5, h = 3,
		categories = {armas = 35, mods = 35, cargadores = 15, municion = 15}
	},
	world_ration = {
		rolls = {1, 4},
		w = 4, h = 3,
		categories = {provisiones = 100}
	}
}

-- Tipos de contenedor del mundo para /LootContainerAdd <tipo> (Fase 2).
-- name = lo que ve el jugador, table = tabla de loot, model = prop.
LOOT.ContainerTypes = {
	caja = {name = "Caja de madera", table = "world_container", model = "models/props_junk/wood_crate001a.mdl"},
	chaqueta = {name = "Chaqueta", table = "world_jacket", model = "models/props_c17/suitcase_passenger_physics.mdl"},
	cajon = {name = "Cajón", table = "world_drawer", model = "models/props_c17/furnituredrawer001a.mdl"},
	herramientas = {name = "Caja de herramientas", table = "world_toolbox", model = "models/props/cs_militia/toolbox.mdl"},
	ordenador = {name = "Torre de ordenador", table = "world_pc", model = "models/props_lab/harddrive02.mdl"},
	medica = {name = "Botiquín de pared", table = "world_medcase", model = "models/props_c17/BriefCase001a.mdl"},
	municion = {name = "Caja de munición", table = "world_ammo", model = "models/items/ammocrate_smg1.mdl"},
	armas = {name = "Caja de armas", table = "world_weapon_box", model = "models/props/cs_militia/footlocker01_closed.mdl"},
	raciones = {name = "Caja de raciones", table = "world_ration", model = "models/props_junk/cardboard_box001a.mdl"}
}

LOOT.MapTables = {}

-- Filtros que pasan siempre todos los objetos generados (ver LOOT.Filters)
LOOT.DefaultFilters = {"lootable", "noGenericAmmo"}

-- Contenedor del cuerpo de un jefe: más valioso que el de un Scav
LOOT.Tables.boss_body = {
	rolls = {2, 5},
	w = 4, h = 4,
	weighting = "price",
	categories = {raro = 25, inteligencia = 20, llaves = 15, dinero = 25, medicina = 15}
}
