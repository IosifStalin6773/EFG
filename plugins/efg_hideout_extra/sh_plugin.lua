local PLUGIN = PLUGIN

PLUGIN.name = "EFG Escondite (módulos de EFT)"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Resto de módulos del escondite de EFT, combustible del generador, granja de bitcoin, Scav Case, recolector de agua y destilería."

-- Fuentes (wiki de EFT): Hideout, Bitcoin_Farm, Scav_Case, Generator.
-- [VERIFICAR wiki: Hideout] requisitos de memoria y adaptados a los recursos del schema.

local hideout = ix.efg.hideout

ix.config.Add("efgFuelPerHour", 1, "Unidades de combustible que gasta el generador por hora real.", nil, {
	data = {min = 0, max = 20, decimals = 1}, category = "EFG Escondite"
})
ix.config.Add("efgBitcoinHours", 4, "[VERIFICAR wiki: Bitcoin_Farm] Horas reales para un bitcoin con una tarjeta gráfica (EFT: ~40 h).", nil, {
	data = {min = 0.1, max = 100, decimals = 1}, category = "EFG Escondite"
})
ix.config.Add("efgScavCaseMinutes", 40, "[VERIFICAR wiki: Scav_Case] Minutos de espera del Scav Case.", nil, {
	data = {min = 1, max = 1440}, category = "EFG Escondite"
})

hideout.extraModules = {
	{
		id = "security", name = "Seguridad",
		description = "Puerta y vigilancia del escondite. Necesario para Iluminación y Ventilación.",
		levels = {
			{money = 20000, items = {madera = 4}, level = 1},
			{money = 90000, items = {tornillos = 6, placas_metalicas = 2}, level = 8},
			{money = 300000, items = {circuitos = 2, bateria = 2}, level = 18, modules = {generator = 2}}
		}
	},
	{
		id = "heating", name = "Calefacción",
		description = "Reduce el gasto de energía e hidratación en el escondite y acelera la regeneración.",
		levels = {
			{money = 25000, items = {piezas_metalicas = 4}, level = 1},
			{money = 100000, items = {cobre = 3, tornillos = 4}, level = 10, modules = {generator = 1}},
			{money = 260000, items = {bateria = 1, circuitos = 1}, level = 20, modules = {generator = 2}}
		}
	},
	{
		id = "illumination", name = "Iluminación",
		description = "Luz en el escondite. Requisito de la galería de tiro y la biblioteca.",
		levels = {
			{money = 15000, items = {vidrio = 2}, level = 1, modules = {security = 1}},
			{money = 80000, items = {cobre = 2, vidrio = 4}, level = 8, modules = {generator = 1}},
			{money = 200000, items = {circuitos = 2}, level = 16, modules = {generator = 2}}
		}
	},
	{
		id = "vents", name = "Ventilación",
		description = "Requisito del filtro de aire y de la granja de bitcoin.",
		levels = {
			{money = 20000, items = {plastico = 2}, level = 1, modules = {security = 1}},
			{money = 90000, items = {engranajes = 2, cobre = 2}, level = 10, modules = {generator = 1}},
			{money = 240000, items = {componentes_mecanicos = 3}, level = 20, modules = {generator = 2}}
		}
	},
	{
		id = "water_collector", name = "Recolector de agua",
		description = "Produce agua potable cada cierto tiempo (se entrega al alijo).",
		produce = {item = "water", minutes = 60},
		levels = {
			{money = 60000, items = {plastico = 4, tornillos = 4}, level = 5, modules = {generator = 1}},
			{money = 180000, items = {cobre = 4, quimicos = 2}, level = 15, modules = {generator = 2}},
			{money = 400000, items = {circuitos = 2, herramientas_precision = 1}, level = 25, modules = {generator = 3}}
		}
	},
	{
		id = "air_filter", name = "Unidad de filtrado de aire",
		description = "Acelera la experiencia de las habilidades físicas (gasta filtros).",
		levels = {
			{money = 450000, items = {componentes_militares = 2, circuitos = 3}, level = 30, modules = {vents = 3, generator = 3}}
		}
	},
	{
		id = "solar", name = "Panel solar",
		description = "Reduce a la mitad el combustible que gasta el generador.",
		fuelMult = 0.5,
		levels = {
			{money = 900000, items = {circuitos = 6, bateria = 4, herramientas_precision = 2}, level = 35, modules = {generator = 3}}
		}
	},
	{
		id = "booze", name = "Destilería",
		description = "Produce licor casero (moonshine) con azúcar y agua.",
		produce = {item = "vodka", minutes = 90},
		levels = {
			{money = 280000, items = {botella_cristal = 4, cobre = 4}, level = 20, modules = {water_collector = 3}}
		}
	},
	{
		id = "bitcoin", name = "Granja de bitcoin",
		description = "Mina bitcoins con tarjetas gráficas (1/10/25/50 según el nivel). Recoge con /Bitcoin.",
		gpuSlots = {10, 25, 50},
		levels = {
			{money = 300000, items = {circuitos = 4, basura_electronica = 6}, level = 20, modules = {vents = 2, generator = 2}},
			{money = 900000, items = {circuitos = 8, bateria = 4}, level = 30, modules = {generator = 3}},
			{money = 2000000, items = {herramientas_precision = 4, componentes_militares = 4}, level = 40, modules = {solar = 1}}
		}
	},
	{
		id = "scav_case", name = "Scav Case",
		description = "Envía a un Scav a buscar botín: /ScavCase 2500, 15000 o 95000.",
		levels = {
			{money = 200000, items = {placas_metalicas = 4, tela = 4}, level = 15, modules = {intelligence = 1}}
		}
	},
	{
		id = "shooting_range", name = "Galería de tiro",
		description = "Practica con las armas en el escondite.",
		levels = {
			{money = 50000, items = {madera = 6, tornillos = 4}, level = 5, modules = {illumination = 1}},
			{money = 150000, items = {placas_metalicas = 4}, level = 15, modules = {illumination = 2}},
			{money = 350000, items = {circuitos = 2, herramientas_precision = 1}, level = 25, modules = {illumination = 3}}
		}
	},
	{
		id = "library", name = "Biblioteca",
		description = "+15 % de experiencia de habilidades.",
		levels = {
			{money = 400000, items = {madera = 8, cuero = 4}, level = 20, modules = {rest = 2, illumination = 3}}
		}
	},
	{
		id = "gym", name = "Gimnasio",
		description = "Entrena Fuerza y Resistencia en el escondite.",
		levels = {
			{money = 500000, items = {hierro = 10, placas_metalicas = 6}, level = 25, modules = {rest = 3}}
		}
	},
	{
		id = "weapon_rack", name = "Armero de pared",
		description = "Más espacio de alijo para armas.",
		stashBonus = true,
		levels = {
			{money = 80000, items = {madera = 6, tornillos = 6}, level = 5},
			{money = 200000, items = {placas_metalicas = 4}, level = 15},
			{money = 500000, items = {aleacion_reforzada = 2}, level = 25}
		}
	},
	{
		id = "hall_of_fame", name = "Salón de la fama",
		description = "Expón chapas de PMC. Cada nivel da más espacio de exposición.",
		levels = {
			{money = 150000, items = {madera = 6}, level = 15},
			{money = 400000, items = {placas_metalicas = 4}, level = 25},
			{money = 900000, items = {aleacion_reforzada = 3}, level = 35}
		}
	}
}

function PLUGIN:InitializedPlugins()
	for _, module in ipairs(hideout.extraModules) do
		if (!hideout.byID[module.id]) then
			hideout.modules[#hideout.modules + 1] = module
			hideout.byID[module.id] = module
		end
	end
end

-- Corriente: generador construido y con combustible
function hideout.HasPower(character)
	return hideout.GetLevel(character, "generator") > 0 and (character:GetData("efgFuel", 0) or 0) > 0
end

ix.command.Add("Generador", {
	description = "Muestra el combustible del generador; con \"repostar\" gasta un bidón de gasolina (10 unidades).",
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, action)
		if (SERVER) then return PLUGIN:GeneratorCommand(client, action) end
	end
})

ix.command.Add("Bitcoin", {
	description = "Estado de la granja de bitcoin; \"gpu\" instala una tarjeta gráfica, \"recoger\" saca los bitcoins.",
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, action)
		if (SERVER) then return PLUGIN:BitcoinCommand(client, action) end
	end
})

ix.command.Add("ScavCase", {
	description = "Envía al Scav Case con 2500, 15000 o 95000 rublos. Sin cantidad muestra el estado.",
	arguments = bit.bor(ix.type.number, ix.type.optional),
	OnRun = function(self, client, amount)
		if (SERVER) then return PLUGIN:ScavCaseCommand(client, amount) end
	end
})

ix.util.Include("sv_plugin.lua")
