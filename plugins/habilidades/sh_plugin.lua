local PLUGIN = PLUGIN

PLUGIN.name = "Habilidades"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Sistema de habilidades (perks) que suben por experiencia de forma progresiva. Reemplaza los atributos de inicio de Helix."

ix.perks = ix.perks or {}
ix.perks.maxLevel = 50

-- XP necesario para pasar de un nivel al siguiente (columna "XP para subir" del CSV).
-- curve[L] = XP para pasar del nivel L al nivel L+1. Niveles 1 → 50.
ix.perks.curve = {
	750, 744, 739, 733, 727, 721, 716, 710, 704, 698,  -- 1→2 .. 10→11
	693, 687, 681, 676, 670, 664, 658, 653, 647, 641,  -- 11→12 .. 20→21
	633, 628, 623, 617, 611, 606, 600, 594, 589, 583,  -- 21→22 .. 30→31
	578, 572, 567, 561, 555, 549, 544, 538, 532, 527,  -- 31→32 .. 40→41
	521, 515, 509, 504, 498, 492, 486, 481, 475,       -- 41→42 .. 49→50
}

-- Nivel (1–50) derivado del XP total acumulado de un perk.
function ix.perks.GetLevelFromXP(xp)
	xp = xp or 0
	local level = 1
	local remaining = xp

	for L = 1, ix.perks.maxLevel - 1 do
		local cost = ix.perks.curve[L]

		if (remaining >= cost) then
			remaining = remaining - cost
			level = level + 1
		else
			break
		end
	end

	return level
end

-- XP total acumulado necesario para alcanzar un nivel concreto desde el nivel 1.
function ix.perks.GetXPForLevel(level)
	level = math.Clamp(level or 1, 1, ix.perks.maxLevel)

	local total = 0
	for L = 1, level - 1 do
		total = total + ix.perks.curve[L]
	end

	return total
end

-- Fracción de progreso de un perk según su nivel: 0 en nivel 1, 1 en nivel máximo.
-- Útil para escalar los efectos linealmente.
function ix.perks.Fraction(level)
	level = math.Clamp(level or 1, 1, ix.perks.maxLevel)
	return (level - 1) / (ix.perks.maxLevel - 1)
end

-- Devuelve nivel actual, XP acumulado dentro del nivel y XP necesario para subir.
-- Si está a nivel máximo, xpNeeded == 0.
function ix.perks.GetProgress(xp)
	xp = xp or 0
	local level = ix.perks.GetLevelFromXP(xp)
	local xpInto = xp - ix.perks.GetXPForLevel(level)
	local xpNeeded = (level < ix.perks.maxLevel) and ix.perks.curve[level] or 0

	return level, xpInto, xpNeeded
end

-- Definición de cada perk. Los nombres son los de las habilidades de EFT
-- (https://escapefromtarkov.fandom.com/wiki/Skills); los id se mantienen para
-- no perder la XP guardada ni los efectos de sv_effects.lua.
ix.perks.list = {
	{
		id = "aguante", name = "Vitalidad", category = "perk",
		objetivo = "Mantenerte vivo y aguantar el daño recibido.",
		recompensa = "Recibes menos daño cuanto más alto es tu nivel.",
	},
	{
		id = "mantenimiento", name = "Mantenimiento de armas", category = "perk",
		objetivo = "Reparar tu equipo (armas y armaduras).",
		recompensa = "Tus armas y armaduras se desgastan más despacio y las reparas con mejor calidad.",
	},
	{
		id = "medicina", name = "Primeros auxilios", category = "perk",
		objetivo = "Curar o tratar heridas a ti mismo o a otros.",
		recompensa = "Curas más con los mismos objetos médicos.",
	},
	{
		id = "resistencia", name = "Resistencia física", category = "perk",
		objetivo = "Realizar acciones físicas repetidas (esprintar).",
		recompensa = "Dispones de más estamina para gastar.",
	},
	{
		id = "fuerza", name = "Fuerza", category = "perk",
		objetivo = "Llevar peso de más en el inventario.",
		recompensa = "Aumenta tu peso máximo en el inventario.",
	},
	{
		id = "explorador", name = "Búsqueda", category = "perk",
		objetivo = "Explorar y saquear contenedores.",
		recompensa = "Saqueas más rápido.",
	},
	{
		id = "superviviente", name = "Metabolismo", category = "perk",
		objetivo = "Comer y beber durante las raids.",
		recompensa = "Menos desgaste de hambre y sed.",
	},
	{
		id = "radiacion", name = "Inmunidad", category = "perk",
		objetivo = "Mantenerte vivo dentro de zonas radioactivas.",
		recompensa = "Más resistencia a la radiación y el filtro dura más.",
	},
	{
		id = "manitas", name = "Fabricación", category = "perk",
		objetivo = "Craftear armas, armaduras y útiles.",
		recompensa = "Los objetos que crafteas tienen más durabilidad.",
	},
	{
		id = "negociador", name = "Carisma", category = "perk",
		objetivo = "Completar misiones de NPCs.",
		recompensa = "Mayores recompensas al finalizar las misiones.",
	},
	{
		id = "apanado", name = "Gestión del escondite", category = "perk",
		objetivo = "Craftear objetos en las mesas de trabajo y cocinas.",
		recompensa = "Al craftear, tienes una probabilidad de no gastar cada material.",
	},

}

-- Mapa id → definición, para acceso rápido.
ix.perks.byID = {}
for _, perk in ipairs(ix.perks.list) do
	ix.perks.byID[perk.id] = perk
end

function ix.perks.IsValidID(id)
	return ix.perks.byID[id] != nil
end

-- Bonus de peso máximo (kg) que aporta el perk Fuerza.
-- Es shared porque la barra de peso del inventario se dibuja en el cliente.
ix.perks.fuerzaMaxBonus = 20

function ix.perks.GetWeightBonus(character)
	if (!character) then return 0 end

	return math.floor(ix.perks.fuerzaMaxBonus * ix.perks.Fraction(character:GetPerkLevel("fuerza")))
end

-- ── Variable de personaje: tabla { [perkId] = xp } serializada a JSON ───────────
ix.char.RegisterVar("perks", {
	field      = "perks",
	fieldType  = ix.type.string,
	default    = "{}",
	bNoDisplay = true,
	OnGet = function(self, default)
		local raw = self.vars["perks"] or default
		if (type(raw) == "string") then
			return util.JSONToTable(raw) or {}
		end
		return raw
	end,
	OnSet = function(self, value)
		local oldVar = self.vars["perks"]

		if (type(value) == "table") then
			self.vars["perks"] = util.TableToJSON(value)
		else
			self.vars["perks"] = value
		end

		-- sin jugador válido (desconectado) net.Send falla y deja el mensaje abierto
		if (SERVER and IsValid(self.player)) then
			net.Start("ixCharacterVarChanged")
				net.WriteUInt(self:GetID(), 32)
				net.WriteString("perks")
				net.WriteType(self.vars["perks"])
			net.Send(self.player)

			hook.Run("CharacterVarChanged", self, "perks", oldVar, self.vars["perks"])
		end
	end,
})

-- ── Métodos de personaje (shared lectura) ───────────────────────────────────────
do
	local CHAR = ix.meta.character

	function CHAR:GetPerkXP(id)
		local perks = self:GetPerks() or {}
		return perks[id] or 0
	end

	function CHAR:GetPerkLevel(id)
		return ix.perks.GetLevelFromXP(self:GetPerkXP(id))
	end
end

-- ── Técnico de radiación: duración del filtro de máscara ────────────────────────
-- Es shared porque tanto el desgaste real (sv_effects.lua) como el HUD (cliente,
-- que necesita saber el tiempo REAL restante para el countdown) deben usar el
-- mismo multiplicador; de lo contrario el HUD asume que el filtro siempre dura
-- ix.config "gasmask_filter" (4 min) aunque el desgaste real sea más lento.
ix.perks.filtroMaxDuracion = 600 -- el filtro dura hasta 10 minutos a nivel 50

function ix.perks.GetFilterMultiplier(character)
	if (!character) then return 1 end

	local baseDuration = ix.config.Get("gasmask_filter", 240)
	local minMultiplier = baseDuration / ix.perks.filtroMaxDuracion

	return 1 - ((1 - minMultiplier) * ix.perks.Fraction(character:GetPerkLevel("radiacion")))
end

-- ── Eliminar atributos de inicio de Helix ───────────────────────────────────────
-- Se quitan los atributos de Helix tras cargar los plugins, salvo los del creador
-- de PMC (efg_pmc/attributes, marcados con efgCreation), que reparten los puntos
-- iniciales y se convierten en niveles de habilidad al crear el personaje.
function PLUGIN:InitializedPlugins()
	for id, attribute in pairs(ix.attributes.list) do
		if (!attribute.efgCreation) then ix.attributes.list[id] = nil end
	end

	if (SERVER and self.SetupServerEffects) then
		self:SetupServerEffects()
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_effects.lua")
ix.util.Include("cl_plugin.lua")
