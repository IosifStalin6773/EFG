local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Escondite"
PLUGIN.author      = "EFG"
PLUGIN.description = "Módulos del escondite (generador, banco de trabajo, estación médica...) que se mejoran con rublos y objetos y desbloquean la fabricación."

ix.efg = ix.efg or {}
ix.efg.hideout = ix.efg.hideout or {}

local hideout = ix.efg.hideout

hideout.modules = {
	-- ─── Alijo ─────────────────────────────────────────────────────────────────
	{
		id = "stash", name = "Alijo",
		description = "Más filas en el alijo: 10×30 de base, 10×40, 10×50 y 10×63 a nivel máximo.",
		levels = {
			{money = 150000, items = {tornillos = 6, hierro = 4}, level = 5},
			{money = 500000, items = {placas_metalicas = 4, plastico = 6}, level = 15, modules = {generator = 1}},
			{money = 1500000, items = {circuitos = 4, herramientas_precision = 2}, level = 25, modules = {generator = 2}}
		}
	},
	-- ─── Generador ─────────────────────────────────────────────────────────────
	{
		id = "generator", name = "Generador",
		description = "Da corriente al escondite. Hace falta para mejorar casi todo lo demás.",
		levels = {
			{money = 50000,  items = {hierro = 5, tornillos = 4}, level = 1},
			{money = 150000, items = {bateria = 2, cobre = 4}, level = 10},
			{money = 400000, items = {bateria = 4, circuitos = 4}, level = 20}
		}
	},
	{
		id = "workbench", name = "Banco de trabajo", mesa = "armas_armaduras",
		description = "Fabrica munición, armas, chalecos y kits de reparación.",
		levels = {
			{money = 30000,  items = {tornillos = 4, hierro = 4}, level = 1},
			{money = 120000, items = {engranajes = 3, muelles = 4}, level = 10, modules = {generator = 1}},
			{money = 350000, items = {componentes_militares = 2, herramientas_precision = 1}, level = 20, modules = {generator = 2}}
		}
	},
	{
		id = "medstation", name = "Estación médica", mesa = "quimica_medica",
		description = "Fabrica botiquines y medicinas. Cada nivel acelera la curación en el escondite.",
		levels = {
			{money = 40000,  items = {vendas = 4, quimicos = 2}, level = 1},
			{money = 150000, items = {jeringa = 4, quimicos = 4}, level = 12, modules = {generator = 1}},
			{money = 400000, items = {desfibrilador_roto = 1, circuitos = 2}, level = 25, modules = {generator = 2}}
		}
	},
	{
		id = "lavatory", name = "Lavabo", mesa = "reciclaje",
		description = "Convierte la chatarra en materiales útiles para el resto de módulos.",
		levels = {
			{money = 20000,  items = {piezas_metalicas = 4}, level = 1},
			{money = 80000,  items = {tornillos = 6, plastico = 4}, level = 8, modules = {generator = 1}},
			{money = 250000, items = {cobre = 4, placas_metalicas = 4}, level = 18, modules = {generator = 2}}
		}
	},
	{
		id = "nutrition", name = "Unidad de nutrición",
		description = "Cocina: agua potable, comida y bebidas energéticas.",
		levels = {
			{money = 30000,  items = {botella_cristal = 3}, level = 1},
			{money = 100000, items = {cobre = 2, plastico = 4}, level = 10, modules = {generator = 1}},
			{money = 300000, items = {bateria = 1, circuitos = 2}, level = 20, modules = {generator = 2}}
		}
	},
	{
		id = "rest", name = "Zona de descanso",
		description = "Cada nivel acelera un 25% la recuperación de salud fuera de raid.",
		levels = {
			{money = 25000,  items = {madera = 4, tela = 4}, level = 1},
			{money = 100000, items = {cuero = 4, tela = 6}, level = 8, modules = {generator = 1}},
			{money = 300000, items = {placas_metalicas = 2, circuitos = 1}, level = 18, modules = {generator = 2}}
		}
	},
	{
		id = "intelligence", name = "Centro de inteligencia",
		description = "Cada nivel reduce un 20% la espera entre Scav runs.",
		levels = {
			{money = 150000, items = {basura_electronica = 4, circuitos = 2}, level = 10, modules = {generator = 1}},
			{money = 500000, items = {bateria = 2, herramientas_precision = 2}, level = 20, modules = {generator = 2}}
		}
	}
}

hideout.byID = {}
for _, module in ipairs(hideout.modules) do
	hideout.byID[module.id] = module
end

function hideout.GetLevel(character, moduleID)
	return (character:GetData("efgHideout", {}) or {})[moduleID] or 0
end

local oficioModules = {
	armero = "workbench", sastre = "workbench",
	medico = "medstation", quimico = "medstation",
	chatarrero = "lavatory", cocinero = "nutrition"
}

ix.oficios = {
	lista = {},
	CanCraft = function(character, oficio, tier)
		local moduleID = oficioModules[oficio]
		if (!moduleID) then return true end
		return hideout.GetLevel(character, moduleID) >= (tier or 1)
	end
}

for oficio, moduleID in pairs(oficioModules) do
	ix.oficios.lista[oficio] = hideout.byID[moduleID].name
end

ix.command.Add("Escondite", {
	description = "Abre el panel de mejoras del escondite.",
	OnRun = function(self, client)
		if (client:InRaid()) then
			return "No puedes gestionar el escondite durante una raid."
		end
		PLUGIN:SendState(client)
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
