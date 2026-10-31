-- Configs del loot. Los tiempos de búsqueda y el examen reutilizan los de
-- efg_invrules: efgSearchBase, efgSearchPerItem y efgExamineEnabled.

ix.config.Add("efgLootScavRareChance", 20, "Probabilidad (%) de que un Scav lleve un objeto raro (tabla scav_rare). [VERIFICAR]", nil, {
	data = {min = 0, max = 100},
	category = "EFG Loot"
})

ix.config.Add("efgLootPMCPriceWeight", 1, "Fuerza de la ponderación inversa al precio en el loot de PMC: 0 = sin efecto, 1 = normal, 3 = lo caro casi nunca sale. [VERIFICAR]", nil, {
	data = {min = 0, max = 3, decimals = 2},
	category = "EFG Loot"
})

ix.config.Add("efgLootPMCExtractValue", 250000, "Valor acumulado de botín (RUB) a partir del cual un PMC de IA intenta extraer. [VERIFICAR]", nil, {
	data = {min = 0, max = 5000000},
	category = "EFG Loot"
})

ix.config.Add("efgLootPMCExtractMinutes", 25, "Minutos tras los que un PMC de IA intenta extraer aunque no haya llegado al valor. [VERIFICAR]", nil, {
	data = {min = 1, max = 120},
	category = "EFG Loot"
})

ix.config.Add("efgLootPMCUpgrade", true, "Los PMC de IA cambian su arma o su blindaje por uno mejor si lo encuentran.", nil, {
	category = "EFG Loot"
})
