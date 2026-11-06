-- Plantillas de tareas diarias. count[banda] = {mín, máx}.
-- Valores y zonas [VERIFICAR]: pendientes de datos de EFT.
-- Las de "explore" solo se generan en zonas con punto fijado (/TareasZonaFijar).

ix.tareasDiarias.maps = {
	customs = "Aduanas", factory = "Fábrica", woods = "Bosque", shoreline = "Costa",
	interchange = "Intercambiador", reserve = "Reserva", lighthouse = "Faro",
	streets = "Calles de Tarkov", groundzero = "Zona cero", labs = "Laboratorio"
}

ix.tareasDiarias.templates = {
	{
		id = "prapor_scavs", trader = "prapor", kind = "kill", npcGroup = "scav",
		title = "Limpieza en {map}", description = "Elimina {count} Scavs en {map}.",
		count = {{3, 5}, {8, 12}, {12, 18}, {18, 25}},
		maps = {"customs", "woods", "shoreline", "interchange", "reserve", "lighthouse", "streets", "groundzero", "factory"},
		minRep = 0, reward = {rublos = 15000, rep = 10, xp = 100}
	},
	{
		id = "prapor_pmc", trader = "prapor", kind = "kill", npcGroup = "pmc",
		title = "Caza de PMC en {map}", description = "Elimina {count} PMC enemigos en {map}.",
		count = {{1, 2}, {2, 3}, {3, 4}, {4, 5}},
		maps = {"customs", "woods", "shoreline", "interchange", "reserve", "lighthouse", "streets"},
		minRep = 200, reward = {rublos = 30000, rep = 20, xp = 200}
	},
	{
		id = "therapist_salewa", trader = "therapist", kind = "deliver", itemID = "salewa",
		title = "Botiquines para el hospital", description = "Entrega {count} Salewa encontrados en raid.",
		count = {{1, 2}, {2, 3}, {3, 4}, {4, 5}},
		maps = {"customs", "woods", "shoreline", "interchange", "reserve", "lighthouse", "streets", "groundzero", "factory"},
		minRep = 0, reward = {rublos = 12000, rep = 10, xp = 120}
	},
	{
		id = "peacekeeper_pmc", trader = "peacekeeper", kind = "kill", npcGroup = "pmc",
		title = "Vigilancia en {map}", description = "Elimina {count} PMC en {map} y vuelve con vida.",
		count = {{2, 3}, {3, 4}, {4, 5}, {5, 7}},
		maps = {"customs", "woods", "shoreline", "interchange", "reserve"},
		minRep = 200, reward = {rublos = 25000, rep = 15, xp = 180}
	},
	{
		id = "jaeger_survive", trader = "jaeger", kind = "survive",
		title = "Racha en {map}", description = "Extrae {count} veces seguidas de {map} sin morir.",
		count = {{2, 2}, {2, 3}, {3, 4}, {3, 5}},
		maps = {"customs", "woods", "shoreline", "interchange", "reserve", "lighthouse", "streets"},
		minRep = 0, reward = {rublos = 18000, rep = 15, xp = 150}
	},
	{
		id = "skier_explore", trader = "skier", kind = "explore",
		title = "Reconocimiento en {map}", description = "Visita {zone} en {map} y extrae con vida.",
		count = {{1, 1}, {1, 1}, {1, 1}, {1, 1}},
		maps = {"customs", "factory", "woods", "interchange"},
		minRep = 0, reward = {rublos = 15000, rep = 10, xp = 120}
	}
}

-- Patrones de mapa (mismos que efg_maps) para comprobar si el mapa actual es el de la tarea.
ix.tareasDiarias.mapPatterns = {
	customs = {"customs"}, factory = {"factory"}, woods = {"woods"}, shoreline = {"shoreline"},
	interchange = {"interchange"}, reserve = {"reserve", "rezerv"}, lighthouse = {"lighthouse"},
	streets = {"streets", "tarkov_city"}, groundzero = {"ground_zero", "groundzero"}, labs = {"labs", "laboratory"}
}

-- Zonas de exploración por mapa (indice = número que usa /TareasZonaFijar).
ix.tareasDiarias.zones = {
	customs = {"Las Naves / Almacenes de construcción", "La Gasolinera", "Oficinas de la Estación", "El Cruce / Zona de vehículos"},
	factory = {"Las Oficinas principales (Planta 3)", "Los Sótanos / Túneles", "El Patio principal"},
	woods = {"El Aserradero", "El Campamento abandonado", "Las Ruinas del poblado"},
	interchange = {"El centro comercial ULTRA", "Los aparcamientos subterráneos", "Las tiendas centrales"}
}
