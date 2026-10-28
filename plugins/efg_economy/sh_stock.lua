-- Surtido de EFT que se añade al de traders/sh_eft_stock.lua.
-- {uniqueID, cantidad, nivel de lealtad, precio opcional}. [VERIFICAR wiki: cada comerciante]
local ECO = ix.efg.economy

local function ammo(cal, round) return "ammo_" .. cal .. "_" .. round end

ECO.extraStock = {
	prapor = {
		{ammo("545x39", "hp"), 300, 1}, {ammo("545x39", "ps"), 300, 1}, {ammo("762x39", "ps"), 300, 1},
		{ammo("9x18", "pst"), 300, 1}, {ammo("762x25", "pst"), 300, 1}, {ammo("12g", "buck7"), 200, 1},
		{ammo("545x39", "bt"), 240, 2}, {ammo("762x39", "pp"), 200, 2}, {ammo("9x19", "pst"), 300, 2},
		{ammo("762x54r", "lps"), 100, 2}, {ammo("366tkm", "fmj"), 120, 2},
		{ammo("545x39", "bp"), 150, 3}, {ammo("762x39", "bp"), 120, 3}, {ammo("762x54r", "ps"), 80, 3},
		{ammo("9x39", "sp6"), 80, 3}, {ammo("545x39", "bs"), 60, 4}, {ammo("762x54r", "bt"), 40, 4},
		{ammo("9x39", "bp"), 40, 4}
	},
	therapist = {
		{"venda_aseptica", 20, 1}, {"venda_militar", 20, 1}, {"vaselina", 6, 1}, {"balsamo_estrella", 4, 2},
		{"calok", 6, 2}, {"afak", 4, 2}, {"ferula_aluminio", 4, 2}, {"ibuprofeno_efg", 4, 3},
		{"grizzly", 2, 3}, {"surv12", 1, 4},
		{"stim_propital", 3, 2}, {"stim_adrenaline", 3, 2}, {"stim_morphine", 3, 1}, {"stim_ahf1m", 2, 3},
		{"stim_zagustin", 2, 3}, {"stim_xtg12", 2, 3}, {"stim_perfotoran", 1, 4}, {"stim_etgc", 1, 4},
		{"keytool", 1, 3}, {"case_sicc", 1, 4}
	},
	peacekeeper = {
		{ammo("556x45", "fmj"), 300, 1}, {ammo("9x19", "luger"), 300, 1},
		{ammo("45acp", "match"), 200, 1}, {ammo("556x45", "m855"), 240, 2}, {ammo("762x51", "bcpfmj"), 100, 2},
		{ammo("57x28", "ss197"), 200, 2}, {ammo("46x30", "fmj"), 200, 2}, {ammo("300blk", "bcpfmj"), 150, 2},
		{ammo("556x45", "m856a1"), 200, 3}, {ammo("762x51", "m80"), 80, 3}, {ammo("45acp", "ap"), 100, 3},
		{ammo("556x45", "m855a1"), 120, 4}, {ammo("762x51", "m62"), 60, 4}, {ammo("57x28", "ss190"), 100, 4},
		{"case_docs", 1, 2}
	},
	skier = {
		{ammo("9x19", "gt"), 300, 1}, {ammo("762x39", "us"), 200, 1},
		{ammo("9x21", "ps"), 150, 2}, {ammo("366tkm", "eko"), 100, 2}, {ammo("20g", "star"), 100, 2},
		{ammo("9x39", "spp"), 80, 3}, {ammo("366tkm", "apm"), 60, 3}, {ammo("12g", "ftx"), 80, 3}
	},
	mechanic = {
		{ammo("9x19", "ap63"), 200, 1}, {ammo("556x45", "mk318"), 120, 2}, {ammo("9x19", "pbp"), 150, 3},
		{ammo("46x30", "ap"), 80, 3}, {ammo("68x51", "sigfmj"), 60, 3}, {ammo("556x45", "m995"), 80, 4},
		{ammo("762x51", "m61"), 40, 4}, {ammo("338lm", "fmj"), 40, 4}, {ammo("68x51", "hybrid"), 40, 4},
		{"weptools", 10, 1}
	},
	jaeger = {
		{ammo("762x54r", "hpbt"), 100, 1}, {ammo("762x54r", "spbt"), 100, 1}, {ammo("12g", "magnum"), 200, 1},
		{ammo("366tkm", "geksa"), 100, 1}, {ammo("762x54r", "t46m"), 80, 2}, {ammo("12g", "poleva6u"), 100, 2},
		{ammo("762x51", "tcwsp"), 80, 2}, {ammo("12g", "ap20"), 60, 3}, {ammo("762x54r", "snb"), 30, 4}
	},
	fence = {
		{"key_gas_station", 1, 1}, {"key_dorms_214", 1, 1}, {"key_portable_bunkhouse", 1, 1},
		{"key_factory_exit", 1, 1}, {"key_woods_yotota", 1, 1}, {"key_shoreline_cottage", 1, 1}
	}
}
