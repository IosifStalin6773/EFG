local PLUGIN = PLUGIN

PLUGIN.name = "Descuartizar"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Permite descuartizar cadáveres de mutantes (Nosalis, Watchers, demonios) con un cuchillo para obtener piel, carne... o nada."

-- Patrones de clase (en minúsculas) que identifican a un NPC descuartizable.
-- Se comprueba por subcadena, así cubre variantes (nosalis, nosalis_female, etc.).
-- Usa el comando /DescuartizarClase mirando a un NPC para descubrir su clase.
PLUGIN.carneablePatterns = {
	"nosach",       -- npc_nosach_samec y variantes
	"nosalis",      -- drgbase_nosalis y variantes
	"churzik",      -- churzik y variantes
	"murzik",       -- murzik y variantes
	"krisomutant",  -- krisomutant y variantes
	"watcher",
	"demon",
	"devil"
}

-- Modelos de ragdoll conocidos que deben marcarse como descuartizables directamente.
-- Más fiable que la detección por proximidad cuando la base crea el ragdoll tarde.
PLUGIN.carneableModels = {
	["models/m2033r/npc/nosach_male.mdl"] = true,
	["models/magma/nosalis_male_pm.mdl"]  = true,
	["models/magnusson.mdl"] = true,
}

-- Modelos pendientes de marcar: se rellena en OnNPCKilled cuando muere un NPC
-- descuartizable y se limpia tras un par de segundos. Permite asociar el ragdoll
-- creado por la base poco después con el NPC que acaba de morir.
PLUGIN.pendingCarneable = PLUGIN.pendingCarneable or {}

-- Ítems posibles al descuartizar. Se eligen al azar y uno de los slots estará vacío.
PLUGIN.lootItems = { "carne", "piel_mutante" }

ix.config.Add("descuartizarRondas", 3, "Número de rondas del minijuego de descuartizar.", nil, {
	data = { min = 2, max = 6 },
	category = "Descuartizar"
})

ix.config.Add("descuartizarItem", "cuchillo", "uniqueID del ítem necesario para poder descuartizar.", nil, {
	category = "Descuartizar"
})

-- Distancia máxima (unidades) para mostrar el aviso de descuartizar en el HUD.
PLUGIN.promptRange = 100

function PLUGIN:IsCarneableClass(class)
	class = string.lower(class or "")

	for _, pattern in ipairs(self.carneablePatterns) do
		if (string.find(class, pattern, 1, true)) then
			return true
		end
	end

	return false
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

ix.command.Add("DescuartizarClase", {
	description = "Muestra la clase del NPC/ragdoll al que estás mirando, útil para configurar el descuartizado.",
	adminOnly = true,
	OnRun = function(self, client)
		local entity = client:GetEyeTraceNoCursor().Entity

		if (!IsValid(entity)) then
			return "No estás mirando a ninguna entidad."
		end

		local class = entity:GetClass()

		return "Clase: " .. class .. " | Descuartizable: " .. (PLUGIN:IsCarneableClass(class) and "Sí" or "No")
	end
})
