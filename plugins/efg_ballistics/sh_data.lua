-- Datos de munición de EFT por calibre.
-- [VERIFICAR wiki: Ballistics / página de cada calibre] Valores tomados de memoria
-- (parche 0.14–0.15 aprox.). La wiki y tarkov.dev no son accesibles desde el entorno
-- de desarrollo: cuando lo sean, este archivo se regenera con tools/ (ver COMANDOS.md).
--
-- ronda = {id, nombre, daño, penetración, daño a blindaje (%), fragmentación (0-1), [perdigones], precio}
-- calibre = {name, stack (máx. por montón), pack (balas por caja), match = {patrones}, rounds}

local B = ix.efg.ballistics

B.calibers = {
	["545x39"] = {
		name = "5.45x39 mm", stack = 60, pack = 30, match = {"5%.45", "545x39"},
		rounds = {
			{"hp",    "HP",        61,  9, 35, 0.32, nil, 90},
			{"prs",   "PRS gs",    50, 13, 30, 0.05, nil, 95},
			{"sp",    "SP",        58, 11, 33, 0.25, nil, 100},
			{"us",    "US gs",     56, 15, 31, 0.07, nil, 110},
			{"t",     "T gs",      54, 20, 37, 0.17, nil, 130},
			{"fmj",   "FMJ",       55, 24, 37, 0.17, nil, 140},
			{"ps",    "PS gs",     50, 28, 34, 0.17, nil, 160},
			{"pp",    "PP gs",     44, 34, 36, 0.17, nil, 230},
			{"bt",    "BT gs",     42, 37, 39, 0.16, nil, 260},
			{"7n40",  "7N40",      55, 42, 48, 0.02, nil, 450},
			{"bp",    "BP gs",     48, 45, 45, 0.16, nil, 520},
			{"bs",    "BS gs",     45, 54, 58, 0.17, nil, 780},
			{"ppbs",  "PPBS gs Igolnik", 37, 62, 82, 0.02, nil, 1200}
		}
	},
	["556x45"] = {
		name = "5.56x45 mm", stack = 60, pack = 30, match = {"5%.56", "556x45", "%.223"},
		rounds = {
			{"warmageddon", "Warmageddon", 88,  3, 90, 0.00, nil, 120},
			{"hp",    "HP",        79,  7, 15, 0.29, nil, 110},
			{"mk255", "Mk 255 Mod 0 (RRLP)", 72, 11, 18, 0.03, nil, 130},
			{"m856",  "M856",      59, 18, 39, 0.33, nil, 150},
			{"fmj",   "FMJ",       54, 23, 33, 0.40, nil, 160},
			{"m855",  "M855",      54, 31, 46, 0.39, nil, 220},
			{"mk318", "Mk 318 Mod 0 (SOST)", 53, 33, 52, 0.15, nil, 300},
			{"m856a1","M856A1",    52, 37, 52, 0.30, nil, 400},
			{"m855a1","M855A1",    49, 44, 52, 0.34, nil, 650},
			{"m995",  "M995",      42, 53, 58, 0.32, nil, 900},
			{"ssaap", "SSA AP",    38, 57, 60, 0.02, nil, 1300}
		}
	},
	["762x39"] = {
		name = "7.62x39 mm", stack = 60, pack = 30, match = {"7%.62x39", "762x39"},
		rounds = {
			{"hp",    "HP",        87, 15, 35, 0.32, nil, 120},
			{"sp",    "SP",        68, 20, 35, 0.25, nil, 130},
			{"us",    "US gzh",    56, 29, 32, 0.08, nil, 150},
			{"t45m1", "T-45M1 gzh",64, 30, 36, 0.12, nil, 160},
			{"ps",    "PS gzh",    57, 35, 52, 0.25, nil, 200},
			{"pp",    "PP gzh",    55, 41, 53, 0.16, nil, 300},
			{"bp",    "BP gzh",    58, 47, 63, 0.12, nil, 600},
			{"maiap", "MAI AP",    53, 58, 76, 0.05, nil, 1300}
		}
	},
	["762x51"] = {
		name = "7.62x51 mm", stack = 40, pack = 20, match = {"7%.62x51", "762x51", "%.308"},
		rounds = {
			{"ultranosler", "Ultra Nosler", 107, 15, 20, 0.70, nil, 250},
			{"tcwsp", "TCW SP",    87, 30, 40, 0.20, nil, 300},
			{"bcpfmj","BCP FMJ",   83, 37, 57, 0.20, nil, 450},
			{"m80",   "M80",       80, 41, 66, 0.12, nil, 700},
			{"m62",   "M62 Tracer",79, 44, 75, 0.12, nil, 900},
			{"m61",   "M61",       70, 64, 83, 0.13, nil, 2200},
			{"m993",  "M993",      67, 70, 85, 0.13, nil, 3500}
		}
	},
	["762x54r"] = {
		name = "7.62x54R", stack = 40, pack = 20, match = {"7%.62x54", "762x54"},
		rounds = {
			{"hpbt",  "HP BT",     102, 23, 41, 0.25, nil, 300},
			{"spbt",  "SP BT",      92, 27, 43, 0.20, nil, 350},
			{"fmj",   "FMJ",        84, 35, 46, 0.18, nil, 400},
			{"t46m",  "T-46M gzh",  82, 41, 83, 0.18, nil, 500},
			{"lps",   "LPS gzh",    81, 42, 78, 0.18, nil, 550},
			{"ps",    "PS gzh",     84, 45, 84, 0.08, nil, 700},
			{"bt",    "BT gzh",     78, 55, 87, 0.08, nil, 1300},
			{"snb",   "SNB gzh",    75, 62, 87, 0.08, nil, 2000},
			{"bs",    "BS gs",      72, 70, 88, 0.08, nil, 3200}
		}
	},
	["9x19"] = {
		name = "9x19 mm", stack = 50, pack = 50, match = {"9x19", "9mm para", "9 ?mm luger"},
		rounds = {
			{"rip",   "RIP",       102,  2, 11, 1.00, nil, 120},
			{"quakemaker","QuakeMaker", 85, 8, 22, 0.10, nil, 80},
			{"luger", "Luger CCI",  70, 10, 26, 0.25, nil, 70},
			{"gt",    "Green Tracer", 58, 14, 33, 0.15, nil, 70},
			{"m882",  "FMJ M882",   56, 18, 33, 0.10, nil, 90},
			{"pst",   "Pst gzh",    54, 20, 33, 0.15, nil, 100},
			{"ap63",  "AP 6.3",     52, 30, 48, 0.05, nil, 250},
			{"pbp",   "PBP gzh (7N31)", 52, 39, 53, 0.05, nil, 450}
		}
	},
	["9x18"] = {
		name = "9x18 mm PM", stack = 50, pack = 50, match = {"9x18", "9 ?mm makarov"},
		rounds = {
			{"sp7",   "SP7 gzh",    77,  2, 20, 0.15, nil, 60},
			{"p",     "P gzh",      50,  5, 16, 0.25, nil, 40},
			{"pst",   "PSt gzh",    50, 12, 26, 0.20, nil, 55},
			{"bzht",  "BZhT gzh",   53, 18, 28, 0.10, nil, 80},
			{"pbm",   "PBM gzh",    40, 28, 30, 0.10, nil, 150}
		}
	},
	["9x39"] = {
		name = "9x39 mm", stack = 40, pack = 20, match = {"9x39"},
		rounds = {
			{"sp5",   "SP-5 gs",    71, 28, 50, 0.20, nil, 300},
			{"spp",   "SPP gs",     68, 35, 55, 0.10, nil, 450},
			{"pab9",  "PAB-9 gs",   62, 43, 65, 0.10, nil, 600},
			{"sp6",   "SP-6 gs",    60, 48, 60, 0.10, nil, 700},
			{"bp",    "BP gs",      58, 54, 70, 0.10, nil, 1100}
		}
	},
	["366tkm"] = {
		name = ".366 TKM", stack = 40, pack = 20, match = {"%.366", "366 ?tkm"},
		rounds = {
			{"geksa", "Geksa",      110, 14, 45, 0.30, nil, 100},
			{"fmj",   "FMJ",         98, 23, 48, 0.25, nil, 120},
			{"eko",   "EKO",         73, 30, 46, 0.20, nil, 180},
			{"apm",   "AP-M",        90, 42, 60, 0.01, nil, 450}
		}
	},
	["12g"] = {
		name = "12/70", stack = 20, pack = 20, match = {"12/70", "12 ?ga", "12g", "12 ?gauge"},
		rounds = {
			{"magnum","8.5 mm Magnum", 50,  2, 26, 0, 8, 60},
			{"buck7", "7 mm buckshot", 39,  3, 26, 0, 8, 50},
			{"flechette","Flechette", 25, 31, 26, 0, 8, 250},
			{"poleva6u","Poleva-6u",  150, 20, 50, 0, 1, 200},
			{"ftx",   "FTX Custom Lite", 183, 17, 30, 0, 1, 250},
			{"ap20",  "AP-20",       164, 37, 65, 0, 1, 900},
			{"rip",   "RIP",         265,  2, 11, 1, 1, 300}
		}
	},
	["20g"] = {
		name = "20/70", stack = 20, pack = 20, match = {"20/70", "20 ?ga", "20g"},
		rounds = {
			{"buck56","5.6 mm buckshot", 26, 1, 26, 0, 8, 40},
			{"buck75","7.5 mm buckshot", 25, 3, 26, 0, 8, 45},
			{"poleva3","Poleva-3",   120, 14, 40, 0, 1, 150},
			{"star",  "Star slug",   154, 16, 45, 0, 1, 180},
			{"devastator","Devastator", 198, 5, 20, 1, 1, 250}
		}
	},
	["46x30"] = {
		name = "4.6x30 mm", stack = 70, pack = 40, match = {"4%.6x30", "46x30"},
		rounds = {
			{"action","Action SX",   65, 18, 26, 0.50, nil, 120},
			{"subsonic","Subsonic SX",45, 23, 33, 0.20, nil, 140},
			{"jsp",   "JSP SX",      46, 32, 42, 0.05, nil, 180},
			{"fmj",   "FMJ SX",      43, 40, 41, 0.20, nil, 250},
			{"ap",    "AP SX",       35, 53, 46, 0.03, nil, 700}
		}
	},
	["57x28"] = {
		name = "5.7x28 mm", stack = 60, pack = 50, match = {"5%.7x28", "57x28"},
		rounds = {
			{"r37f",  "R37.F",       98,  8, 11, 1.00, nil, 120},
			{"ss198", "SS198LF",     70, 17, 33, 0.20, nil, 150},
			{"ss197", "SS197SR",     62, 25, 43, 0.20, nil, 200},
			{"sb193", "SB193",       54, 27, 34, 0.20, nil, 220},
			{"l191",  "L191",        53, 33, 50, 0.20, nil, 300},
			{"ss190", "SS190",       49, 37, 53, 0.20, nil, 600}
		}
	},
	["762x25"] = {
		name = "7.62x25 mm TT", stack = 50, pack = 50, match = {"7%.62x25", "762x25"},
		rounds = {
			{"lrnpc", "LRNPC",       66,  7, 24, 0.35, nil, 50},
			{"lrn",   "LRN",         64,  8, 25, 0.35, nil, 50},
			{"fmj43", "FMJ43",       60, 11, 25, 0.20, nil, 60},
			{"akbs",  "AKBS",        58, 12, 30, 0.20, nil, 60},
			{"pgl",   "P gl",        58, 14, 28, 0.20, nil, 70},
			{"pt",    "PT gzh",      55, 18, 32, 0.17, nil, 80},
			{"pst",   "Pst gzh",     50, 25, 36, 0.20, nil, 110}
		}
	},
	["45acp"] = {
		name = ".45 ACP", stack = 50, pack = 50, match = {"%.45 ?acp", "45acp", "11%.43"},
		rounds = {
			{"rip",   "RIP",        130,  3, 15, 1.00, nil, 200},
			{"hydra", "Hydra-Shok", 100, 13, 22, 0.50, nil, 150},
			{"lasermatch","Lasermatch FMJ", 76, 19, 30, 0.01, nil, 120},
			{"match", "Match FMJ",   72, 25, 36, 0.01, nil, 140},
			{"ap",    "AP",          66, 38, 48, 0.01, nil, 450}
		}
	},
	["9x21"] = {
		name = "9x21 mm", stack = 50, pack = 50, match = {"9x21"},
		rounds = {
			{"pe",    "PE gzh",      80, 15, 30, 0.20, nil, 120},
			{"p",     "P gzh",       65, 18, 30, 0.20, nil, 100},
			{"ps",    "PS gzh",      70, 22, 33, 0.20, nil, 140},
			{"bt",    "BT gzh",      49, 32, 40, 0.20, nil, 250},
			{"7n42",  "7N42",        49, 38, 45, 0.05, nil, 400}
		}
	},
	["300blk"] = {
		name = ".300 Blackout", stack = 50, pack = 30, match = {"%.300", "300 ?blk", "300 ?aac", "762x35"},
		rounds = {
			{"whisper","Whisper",    90, 14, 20, 0.20, nil, 250},
			{"vmax",  "V-Max",       72, 20, 35, 0.40, nil, 250},
			{"bcpfmj","BCP FMJ",     60, 30, 42, 0.30, nil, 220},
			{"m62",   "M62 Tracer",  54, 36, 48, 0.25, nil, 300},
			{"cbj",   "CBJ",         58, 43, 50, 0.10, nil, 600},
			{"ap",    "AP",          51, 48, 60, 0.10, nil, 900}
		}
	},
	["338lm"] = {
		name = ".338 Lapua Magnum", stack = 40, pack = 20, match = {"%.338", "338 ?lapua", "8%.6x70"},
		rounds = {
			{"tacx",  "TAC-X",      196, 18, 55, 0.15, nil, 900},
			{"ucw",   "UCW",        242, 32, 60, 0.15, nil, 1200},
			{"fmj",   "FMJ",        122, 47, 83, 0.20, nil, 1500},
			{"ap",    "AP",         115, 79, 89, 0.10, nil, 6000}
		}
	},
	["127x55"] = {
		name = "12.7x55 mm", stack = 40, pack = 20, match = {"12%.7x55", "127x55"},
		rounds = {
			{"ps12a", "PS12A",      165, 10, 22, 0.70, nil, 400},
			{"ps12",  "PS12",       115, 28, 60, 0.30, nil, 500},
			{"ps12b", "PS12B",      102, 46, 57, 0.30, nil, 900}
		}
	},
	["68x51"] = {
		name = "6.8x51 mm", stack = 40, pack = 20, match = {"6%.8x51", "68x51", "%.277"},
		rounds = {
			{"sigfmj","SIG FMJ",     80, 36, 60, 0.20, nil, 600},
			{"hybrid","SIG Hybrid",  72, 47, 65, 0.20, nil, 1100}
		}
	},
	["357mag"] = {
		name = ".357 Magnum", stack = 40, pack = 25, match = {"%.357", "357 ?mag", "9x33"},
		rounds = {
			{"sp",    "SP",         108, 12, 20, 0.30, nil, 150},
			{"jhp",   "JHP",         98, 24, 30, 0.30, nil, 200},
			{"fmj",   "FMJ",         70, 35, 40, 0.10, nil, 300}
		}
	},
	["23x75"] = {
		name = "23x75 mm", stack = 20, pack = 10, match = {"23x75"},
		rounds = {
			{"shrapnel25","Shrapnel-25", 78, 10, 20, 0, 8, 300},
			{"barrikada","Barrikada",   192, 39, 75, 0, 1, 1500}
		}
	}
}

-- Munición genérica de GMod (armas sin calibre detectado). Mantiene los ítems
-- ammo_* que ya usan comerciantes, loot y misiones. Sin daño propio: lo pone el arma.
B.generic = {
	pistol         = {"Munición de pistola", 30, 18},
	smg1           = {"Munición de subfusil", 45, 22},
	ar2            = {"Munición de fusil", 30, 35},
	buckshot       = {"Cartuchos", 12, 5},
	["357"]        = {"Munición de revólver", 12, 28},
	sniperround    = {"Munición de francotirador", 10, 55},
	ar2altfire     = {"Esfera de energía", 1, 0},
	sniperpenetratedround = {"Munición de francotirador perforante", 10, 60}
}

-- Material del blindaje: cuánto se desgasta por golpe (Armor_vests#Materials)
B.materials = {
	aramid    = {name = "Aramida",          destructibility = 0.25},
	uhmwpe    = {name = "Polietileno UHMW", destructibility = 0.45},
	combined  = {name = "Combinado",        destructibility = 0.50},
	titan     = {name = "Titanio",          destructibility = 0.55},
	aluminium = {name = "Aluminio",         destructibility = 0.60},
	steel     = {name = "Acero blindado",   destructibility = 0.70},
	ceramic   = {name = "Cerámica",         destructibility = 0.80},
	glass     = {name = "Vidrio",           destructibility = 0.80}
}

-- Por defecto según la clase si el ítem no dice su material
B.defaultMaterial = {[1] = "aramid", [2] = "aramid", [3] = "uhmwpe", [4] = "combined", [5] = "ceramic", [6] = "ceramic"}

-- Zonas de la cabeza que tapa cada casco (Helmets). Sin entrada = top, nape, ears.
B.helmetZones = {
	helmet_altyn = {"top", "nape", "ears", "eyes", "jaws"},
	helmet_maska = {"top", "nape", "ears"},
	helmet_fast  = {"top", "nape"},
	helmet_kiver = {"top", "nape", "ears"},
	helmet_ssh68 = {"top", "nape"},
	helmet_ulach = {"top", "nape", "ears"},
	helmet_6b47  = {"top", "nape", "ears"}
}

-- Probabilidad de rebote de cada casco (alta, media, baja)
B.helmetRicochet = {
	helmet_altyn = 0.6, helmet_maska = 0.3, helmet_fast = 0.2, helmet_kiver = 0.2,
	helmet_ssh68 = 0.45, helmet_ulach = 0.3, helmet_6b47 = 0.2
}

B.zoneNames = {top = "Coronilla", nape = "Nuca", ears = "Orejas", eyes = "Ojos", jaws = "Mandíbula"}
