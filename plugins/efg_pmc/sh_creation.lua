-- Datos del creador de PMC: apariencia (cabeza, chaqueta, pantalón, accesorios),
-- atributos de inicio, roles y equipo inicial. Lo comparten el creador (cliente),
-- la pestaña PERSONAJE del TAB y la validación del servidor.
--
-- Los índices son opciones de bodygroup leídas de los propios .mdl:
--   models/eft/pmcs/<bando>_extended_pm.mdl  → 0 Head, 1 Body, 2 Legs
--   models/eft/pm_gear/accs.mdl              → 0 Facecover, 1 Headset
--   models/eft/pm_gear/glasses.mdl           → 0 Glasses
--   models/eft/pm_gear/headwear.mdl          → 0 Headwear
-- Ninguno de los modelos trae flexes ni morphs: la variedad de cara sale de las
-- cabezas del modelo (8 USEC, 7 BEAR) y del tono de piel (2 skins en BEAR).

local PMC = ix.efg.pmc

PMC.BG_HEAD, PMC.BG_TOP, PMC.BG_LEGS = 0, 1, 2

PMC.sides.usec.skins = 1
PMC.sides.bear.skins = 2

-- {opción de bodygroup, nombre}. Quedan fuera los atuendos de jefes y cultistas.
PMC.tops = {
	usec = {
		{0, "USEC Crye Combat Shirt"}, {1, "USEC Crye Combat Shirt (verde)"}, {7, "USEC Velocity"},
		{8, "USEC Velocity Multicam"}, {13, "USEC Clawgear"}, {14, "USEC Commando"}, {17, "USEC Combat Shirt"},
		{4, "USEC ORC PCU"}, {5, "USEC Aggressor Parka"}, {6, "USEC Carinthia Softshell"}, {9, "USEC ACU"},
		{10, "USEC Beltstaff"}, {11, "USEC Softshell"}, {12, "USEC Chameleon Softshell"}, {15, "USEC Tier 3"},
		{16, "USEC Cereum"}, {19, "USEC PCS Shirt"}, {20, "USEC Tier 2"}, {21, "USEC Hoody"},
		{22, "USEC Night Patrol"}, {23, "USEC Blue Team I"}, {24, "USEC Blue Team II"}, {25, "USEC Blue Team III"},
	},
	bear = {
		{0, "BEAR Thermo"}, {1, "BEAR Thermo (negra)"}, {4, "BEAR Black T-Shirt"}, {5, "BEAR Termo"},
		{7, "BEAR Summer Field"}, {6, "BEAR SpNa"}, {8, "BEAR Tactical Long"}, {9, "BEAR FSB Fast Response"},
		{10, "BEAR OPS Windshirt"}, {11, "BEAR Voin"}, {12, "BEAR Borey"}, {13, "BEAR Phoenix"},
		{14, "BEAR Ghost Marksman"}, {15, "BEAR Sumrak"}, {16, "BEAR Black Lynx"}, {18, "BEAR Zaslon"},
		{19, "BEAR Tiger"}, {20, "BEAR Telnik"}, {21, "BEAR G99"}, {22, "BEAR Red Team I"},
		{23, "BEAR Red Team II"}, {24, "BEAR Red Team III"},
	}
}

PMC.legs = {
	usec = {
		{0, "USEC Crye Combat"}, {1, "USEC Crye Combat (verde)"}, {2, "USEC Blackhawk Tac Life"}, {3, "USEC Jeans"},
		{4, "USEC Beltstaff"}, {5, "USEC Tier 3"}, {6, "USEC Velocity"}, {7, "USEC Velocity (gris)"},
		{8, "USEC Carinthia Softshell"}, {9, "USEC Raider"}, {10, "USEC Gen2"}, {11, "USEC Chameleon Softshell"},
		{12, "USEC Cerium"}, {13, "USEC TruSPEC"}, {14, "USEC Crye Precision"}, {15, "USEC Tier 2"},
		{16, "USEC Commando"}, {17, "USEC Deep Recon"}, {18, "USEC Urban Responder"}, {19, "USEC Blue Team I"},
		{20, "USEC Blue Team II"}, {21, "USEC Blue Team III"},
	},
	bear = {
		{0, "BEAR SRVV"}, {1, "BEAR SRVV (Surpat)"}, {2, "BEAR Gorka SSO"}, {3, "BEAR SpNa"},
		{4, "BEAR URON"}, {5, "BEAR OPS Windshirt"}, {6, "BEAR OPS Windshirt (tan)"}, {7, "BEAR Triarius"},
		{8, "BEAR Tactical Long"}, {9, "BEAR Voin"}, {10, "BEAR Phoenix"}, {11, "BEAR FSB Urban"},
		{12, "BEAR Gorka E"}, {13, "BEAR Striker"}, {14, "BEAR Sumrak"}, {15, "BEAR Oldschool"},
		{16, "BEAR Zaslon"}, {17, "BEAR Combat"}, {18, "BEAR G99"}, {19, "BEAR Red Team I"},
		{20, "BEAR Red Team II"}, {21, "BEAR Red Team III"},
	}
}

-- Accesorios estéticos. Se ocultan solos si el jugador lleva equipado un objeto
-- real en el mismo hueco (efgSlot del ítem): el casco tapa el gorro, etc.
PMC.cosmetics = {
	{
		id = "headwear", name = "Gorro", model = "models/eft/pm_gear/headwear.mdl", bodygroup = 0, slot = "helmet",
		options = {
			{0, "Ninguno"}, {1, "Gorro de punto"}, {2, "Gorro de algodón"}, {3, "Gorra militar"},
			{4, "Gorra militar negra"}, {5, "Gorra militar marrón"}, {6, "Gorra CADPAT"}, {7, "Gorra Flora"},
			{8, "Gorra arena"}, {9, "Gorra UCP"}, {12, "Gorro polar"}, {13, "Gorro UF PRO"},
			{14, "Gorra USEC (tan)"}, {15, "Gorra USEC (negra)"}, {16, "Gorra BEAR (verde)"}, {17, "Gorra BEAR (negra)"},
			{18, "Gorra MHS"}, {19, "Gorro con pompón"}, {20, "Bandana"}, {22, "Boina negra"},
			{23, "Boina azul"}, {24, "Boina verde oliva"}, {25, "Gorra de cuero"}, {29, "Panamá Jack Pyke"},
			{30, "Panamá Stich Profi"}, {32, "Ushanka"}, {33, "Panamá"}, {34, "Gorra Door Kicker"},
		}
	},
	{
		id = "facecover", name = "Máscara", model = "models/eft/pm_gear/accs.mdl", bodygroup = 0, slot = "facecover",
		options = {
			{0, "Ninguna"}, {27, "Pasamontañas"}, {28, "Pasamontañas (abierto)"}, {23, "Pasamontañas Nomex"},
			{20, "Pasamontañas Wildman"}, {22, "Pasamontañas calavera"}, {21, "Máscara ColdGear"}, {24, "Máscara Smoke"},
			{25, "Shemagh"}, {26, "Pañuelo árabe"}, {12, "Respirador 3M"}, {9, "Máscara de gas GP-5"},
			{10, "Máscara de gas GP-7"}, {11, "Máscara calavera"}, {30, "Bigote"}, {31, "Barba roja"},
		}
	},
	{
		id = "glasses", name = "Gafas", model = "models/eft/pm_gear/glasses.mdl", bodygroup = 0, slot = "eyewear",
		options = {
			{0, "Ninguna"}, {1, "Oakley SI"}, {2, "NPP KlASS Tor"}, {3, "Gafas tácticas"}, {4, "Gafas AFG"},
			{5, "6B34"}, {6, "Dundukk"}, {7, "Oakley M Frame"}, {8, "Pyramex Proximity"}, {9, "Oakley Gascan"},
			{10, "Gafas Aoron"}, {11, "RayBench"}, {12, "Gafas de aviador"}, {13, "JohnB Liquid DNB"},
			{14, "ESS Crossbow"},
		}
	},
	{
		id = "headset", name = "Auriculares", model = "models/eft/pm_gear/accs.mdl", bodygroup = 1, slot = "headset",
		options = {
			{0, "Ninguno"}, {1, "GSSh-01"}, {2, "MSA Sordin"}, {3, "Howard M32"}, {4, "Peltor ComTac II"},
			{5, "Peltor Tactical Sport"}, {6, "Walker's Razor"}, {7, "Walker's XCEL 500BT"}, {8, "Peltor ComTac IV"},
		}
	},
}

PMC.cosmeticByID = {}
for _, info in ipairs(PMC.cosmetics) do PMC.cosmeticByID[info.id] = info end

-- Conjuntos predefinidos: rellenan chaqueta, pantalón y accesorios de una vez.
-- Valores = posición en las listas de arriba (1 = primera opción).
PMC.presets = {
	usec = {
		{name = "PMC novato", top = 1, legs = 1, headwear = 1, facecover = 1, glasses = 1, headset = 1},
		{name = "Operador", top = 15, legs = 6, headwear = 15, facecover = 1, glasses = 2, headset = 5},
		{name = "Patrulla nocturna", top = 20, legs = 16, headwear = 1, facecover = 3, glasses = 1, headset = 9},
		{name = "Contratista", top = 19, legs = 4, headwear = 14, facecover = 1, glasses = 13, headset = 1},
		{name = "Tirador", top = 12, legs = 12, headwear = 6, facecover = 9, glasses = 1, headset = 6},
	},
	bear = {
		{name = "PMC novato", top = 1, legs = 1, headwear = 1, facecover = 1, glasses = 1, headset = 1},
		{name = "Spetsnaz", top = 6, legs = 4, headwear = 17, facecover = 2, glasses = 1, headset = 2},
		{name = "FSB", top = 8, legs = 12, headwear = 1, facecover = 4, glasses = 6, headset = 3},
		{name = "Veterano", top = 5, legs = 5, headwear = 26, facecover = 1, glasses = 1, headset = 1},
		{name = "Tirador", top = 13, legs = 13, headwear = 2, facecover = 10, glasses = 1, headset = 7},
	}
}

-- ─── Atributos de inicio (ix.attributes, plugins/efg_pmc/attributes) ──────────
-- Cada punto da PMC.levelsPerPoint niveles de la habilidad de EFT asociada.
PMC.attribPoints = 10
PMC.attribMax = 5
PMC.levelsPerPoint = 2
PMC.attribOrder = {"fue", "res", "sal", "pun"}

-- Fuerza mínima para empezar con chaleco o casco de clase >= PMC.heavyClass
PMC.heavyClass = 4
PMC.heavyStrength = 3

-- ─── Roles ───────────────────────────────────────────────────────────────────
-- items: comunes; usec/bear: armas del bando. Cada entrada es {uniqueID, cantidad}
-- o {uniqueID, cantidad, alternativa} para el equipo pesado: si el PMC no tiene
-- la Fuerza necesaria, recibe la alternativa (más ligera). Los cargadores y la
-- munición los pone efg_mags (GiveStarterMags) para cada arma ARC9.
PMC.roles = {
	{
		id = "asaltante", name = "Asaltante", icon = "assault_rifles",
		description = "Combate a media distancia. Empieza con subfusil, chaleco y casco.",
		usec = {{"arc9_eft_mp5", 1}}, bear = {{"arc9_eft_aks74u", 1}},
		items = {
			{"armor_trooper", 1, "armor_6b23_1"}, {"helmet_ssh68", 1}, {"rig_m2", 1},
			{"arc9_eft_pm", 1}, {"ai2", 1}, {"venda_militar", 2}, {"esmarch", 1},
		}
	},
	{
		id = "tirador", name = "Tirador", icon = "bolt_action",
		description = "Larga distancia. Fusil de cerrojo, protección ligera y gafas.",
		usec = {{"arc9_eft_vpo215", 1}}, bear = {{"arc9_eft_mosin_infantry", 1}},
		items = {
			{"armor_paca", 1}, {"rig_wild", 1}, {"efg_eye_tactical", 1},
			{"arc9_eft_pm", 1}, {"ai2", 1}, {"venda_militar", 2},
		}
	},
	{
		id = "medico", name = "Médico", icon = "surgery",
		description = "Apoyo. Escopeta y un botiquín completo para tratar heridas y fracturas.",
		usec = {{"arc9_eft_mr133", 1}}, bear = {{"arc9_eft_mr133", 1}},
		items = {
			{"armor_paca", 1}, {"rig_alpha", 1}, {"ifak", 1}, {"ai2", 2}, {"esmarch", 2},
			{"ferula", 1}, {"analgin", 1}, {"venda_militar", 3},
		}
	},
}

PMC.roleByID = {}
for i, role in ipairs(PMC.roles) do role.index = i; PMC.roleByID[role.id] = role end

-- ─── Utilidades ──────────────────────────────────────────────────────────────
local function hasOption(list, value)
	for _, entry in ipairs(list or {}) do
		if (entry[1] == value) then return true end
	end

	return false
end

function PMC.HasTop(sideKey, value) return hasOption(PMC.tops[sideKey], value) end
function PMC.HasLegs(sideKey, value) return hasOption(PMC.legs[sideKey], value) end

function PMC.HasCosmetic(id, value)
	local info = PMC.cosmeticByID[id]
	return info and hasOption(info.options, value) or false
end

function PMC.OptionName(list, value)
	for _, entry in ipairs(list or {}) do
		if (entry[1] == value) then return entry[2] end
	end
end

-- Atributos: solo los del creador, enteros 0..attribMax, suma <= attribPoints.
-- Devuelve la tabla limpia o false y el motivo.
function PMC.ValidateAttributes(value)
	if (value == nil) then return {} end
	if (!istable(value)) then return false, "efgInvalidAttributes" end

	local clean, total = {}, 0

	for key, amount in pairs(value) do
		local attribute = ix.attributes.list[key]
		amount = tonumber(amount)

		if (!attribute or !attribute.efgCreation or !amount or amount != math.floor(amount)
			or amount < 0 or amount > PMC.attribMax) then
			return false, "efgInvalidAttributes"
		end

		if (amount > 0) then clean[key] = amount end
		total = total + amount
	end

	if (total > PMC.attribPoints) then
		return false, "efgInvalidAttributes"
	end

	return clean
end

-- Apariencia elegida en el creador: {top, legs, skin, cosmetics = {id = opción}}
function PMC.ValidateLook(sideKey, look)
	if (!istable(look)) then return false, "efgInvalidLook" end

	local top, legs, skin = tonumber(look.top), tonumber(look.legs), tonumber(look.skin) or 0

	if (!top or !PMC.HasTop(sideKey, top) or !legs or !PMC.HasLegs(sideKey, legs)) then
		return false, "efgInvalidLook"
	end

	if (skin != math.floor(skin) or skin < 0 or skin >= (PMC.sides[sideKey].skins or 1)) then
		return false, "efgInvalidLook"
	end

	local cosmetics = {}

	for id, option in pairs(istable(look.cosmetics) and look.cosmetics or {}) do
		option = tonumber(option)

		if (!PMC.cosmeticByID[id] or !option or !PMC.HasCosmetic(id, option)) then
			return false, "efgInvalidLook"
		end

		if (option > 0) then cosmetics[id] = option end
	end

	return {top = top, legs = legs, skin = skin, cosmetics = cosmetics}
end

-- Clase de protección de un ítem (chaleco o casco), 0 si no es armadura
function PMC.ArmorClass(uniqueID)
	local item = ix.item.list[uniqueID]
	return item and tonumber(item.efgArmorClass) or 0
end

-- Lista final de {uniqueID, cantidad} para un rol, bando y atributos.
function PMC.BuildKit(roleID, sideKey, attributes)
	local role = PMC.roleByID[roleID]
	if (!role) then return {} end

	local strength = (attributes or {}).fue or 0
	local kit = {}

	local function add(list)
		for _, entry in ipairs(list or {}) do
			local id = entry[1]

			if (entry[3] and strength < PMC.heavyStrength and PMC.ArmorClass(id) >= PMC.heavyClass) then
				id = entry[3]
			end

			if (ix.item.list[id]) then kit[#kit + 1] = {id, entry[2] or 1} end
		end
	end

	add(role[sideKey])
	add(role.items)

	return kit
end
