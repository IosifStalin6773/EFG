PLUGIN.name = "Plantacion y Crianza"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Setas silvestres y jaulas de ratas recolectables mediante un minijuego de habilidad."

ix.harvest = ix.harvest or {}

-- Recolectables en cooldown esperando respawn: clave = timerKey, valor = {pos, ang, model, type}
ix.harvest.pending = ix.harvest.pending or {}

-- Distancia maxima (en unidades) para poder interactuar con un recolectable.
ix.harvest.range = 150

-- Configuracion de cada tipo de recolectable.
-- item: uniqueID del item que se entrega por cada acierto del minijuego.
-- rounds: numero de rondas (aciertos maximos) del minijuego.
-- cooldownMin/Max: segundos hasta que el recolectable vuelve a estar disponible.
-- failCooldown: segundos de espera si fallas todas las rondas.
-- defaultModel: modelo usado si el comando de spawn no recibe uno.
ix.harvest.types = {
	mushroom = {
		label = "Setas silvestres",
		hint = "Pulsa E para recolectar las setas.",
		item = "setas",
		rounds = 3,
		cooldownMin = 600,
		cooldownMax = 900,
		failCooldown = 90,
		zoneColor = Color(120, 200, 120),
		giveSound = "physics/flesh/flesh_squishy_impact_hard1.wav",
		defaultModel = "models/props_junk/wood_crate001a.mdl"
	},

	ratcage = {
		label = "Jaula de ratas",
		hint = "Pulsa E para capturar una rata.",
		item = "carne_extrana",
		rounds = 3,
		cooldownMin = 720,
		cooldownMax = 1080,
		failCooldown = 120,
		zoneColor = Color(200, 150, 120),
		giveSound = "physics/flesh/flesh_squishy_impact_hard2.wav",
		defaultModel = "models/props_junk/wood_crate001a.mdl"
	},

	well = {
		label = "Pozo de agua",
		hint = "Pulsa E para recoger agua sucia.",
		item = "agua_sucia",
		rounds = 3,
		cooldownMin = 600,
		cooldownMax = 900,
		failCooldown = 90,
		zoneColor = Color(120, 160, 220),
		giveSound = "ambient/water/water_pour1.wav",
		defaultModel = "models/props_c17/oildrum001.mdl",
		persistent = true
	},

	log = {
		label = "Tocon de arbol",
		hint = "Pulsa E para talar el tocon y conseguir madera humeda.",
		item = "madera_humeda",
		rounds = 3,
		amountPerSuccess = 5,
		requiredItem = "hacha",
		cooldownMin = 900,
		cooldownMax = 1200,
		failCooldown = 120,
		zoneColor = Color(140, 100, 60),
		giveSound = "physics/wood/wood_plank_impact_hard1.wav",
		defaultModel = "models/props_junk/wood_crate001a.mdl"
	}
}

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

ix.command.Add("PlantarSeta", {
	description = "Coloca un recolectable de setas donde estas mirando.",
	privilege = "Manage Harvestables",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			ix.harvest.SpawnFromTrace(client, "mushroom", model)
		end
	end
})

ix.command.Add("PlantarPozo", {
	description = "Coloca un recolectable de agua sucia donde estas mirando.",
	privilege = "Manage Harvestables",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			ix.harvest.SpawnFromTrace(client, "well", model)
		end
	end
})

ix.command.Add("PlantarTocon", {
	description = "Coloca un tocon de arbol donde estas mirando.",
	privilege = "Manage Harvestables",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			ix.harvest.SpawnFromTrace(client, "log", model)
		end
	end
})

ix.command.Add("ColocarJaula", {
	description = "Coloca una jaula de ratas donde estas mirando.",
	privilege = "Manage Harvestables",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			ix.harvest.SpawnFromTrace(client, "ratcage", model)
		end
	end
})

ix.command.Add("RecargarRecolectables", {
	description = "Respawnea al instante todos los recolectables que esten en cooldown.",
	privilege = "Manage Harvestables",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local count = 0

			for timerKey, data in pairs(ix.harvest.pending) do
				timer.Remove(timerKey)
				ix.harvest.pending[timerKey] = nil
				ix.harvest.SpawnEntity(data[1], data[2], data[3], data[4])
				count = count + 1
			end

			client:ChatPrint("Recolectables recargados: " .. count .. " respawneados.")
		end
	end
})

ix.command.Add("QuitarRecolectable", {
	description = "Elimina el recolectable al que estas mirando (max. 256 unidades).",
	privilege = "Manage Harvestables",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 256
			data.filter = client

			local entity = util.TraceLine(data).Entity

			if (!IsValid(entity) or !ix.harvest.types[entity.HarvestType or ""]) then
				client:ChatPrint("No estas mirando a un recolectable.")
				return false
			end

			entity:Remove()
			client:ChatPrint("Recolectable eliminado.")
		end
	end
})