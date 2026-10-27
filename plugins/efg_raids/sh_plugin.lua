local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Raids"
PLUGIN.author      = "EFG"
PLUGIN.description = "Ciclo de raid: despliegue desde el escondite, temporizador, extracciones, raids en grupo, Scav run y experiencia del PMC."

ix.efg = ix.efg or {}

-- ─── Configuración ───────────────────────────────────────────────────────────
ix.config.Add("efgRaidMinutes", 35, "Duración de una raid en minutos. Al acabarse, el jugador muere (MIA) y pierde el equipo.", nil, {
	data = {min = 5, max = 120},
	category = "EFG Raids"
})

ix.config.Add("efgExtractSeconds", 8, "Segundos que hay que permanecer en la zona de extracción para extraer.", nil, {
	data = {min = 1, max = 60},
	category = "EFG Raids"
})

ix.config.Add("efgDeploySeconds", 10, "Cuenta atrás antes de desplegar en la raid.", nil, {
	data = {min = 0, max = 60},
	category = "EFG Raids"
})

ix.config.Add("efgRandomExtractChance", 50, "Probabilidad (%) de que una extracción aleatoria esté abierta en una raid.", nil, {
	data = {min = 0, max = 100},
	category = "EFG Raids"
})

ix.config.Add("efgHideoutRadius", 1500, "Radio (unidades) de la zona segura del escondite alrededor de su punto.", nil, {
	data = {min = 100, max = 10000},
	category = "EFG Raids"
})

ix.config.Add("efgConfineHideout", true, "Si está activo, quien no esté en raid no puede salir del escondite a pie (vuelve al punto del escondite).", nil, {
	category = "EFG Raids"
})

ix.config.Add("efgScavCooldown", 20, "Minutos de espera entre dos Scav runs del mismo jugador.", nil, {
	data = {min = 0, max = 240},
	category = "EFG Raids"
})

ix.config.Add("efgGroupMax", 5, "Máximo de jugadores por grupo.", nil, {
	data = {min = 2, max = 10},
	category = "EFG Raids"
})

-- ─── Tipos de extracción ─────────────────────────────────────────────────────
-- siempre:     siempre abierta
-- aleatoria:   abierta solo en algunas raids (efgRandomExtractChance)
-- pago:        abierta, pero cuesta rublos al extraer
-- sin_mochila: abierta, pero solo si no llevas mochila equipada
ix.efg.extractTypes = {
	siempre     = "Siempre abierta",
	aleatoria   = "Aleatoria",
	pago        = "De pago",
	sin_mochila = "Sin mochila"
}

-- Bando que puede usar una extracción
ix.efg.extractSides = {
	todos = true,
	pmc   = true,
	scav  = true
}

-- ─── Experiencia y nivel del PMC ─────────────────────────────────────────────
ix.efg.xp = {
	survived    = 600, -- extraer con vida
	runThrough  = 200, -- extraer antes de efgRunThroughMinutes (EFT: "Run Through")
	killPMC     = 350,
	killScav    = 120,
	killNPC     = 60
}

ix.efg.runThroughMinutes = 7

-- XP total necesaria para cada nivel (nivel 1 = 0 XP). Curva aproximada a la de EFT.
ix.efg.levels = {0}
do
	local total = 0
	for lvl = 2, 79 do
		total = total + math.floor(1000 + (lvl - 2) ^ 1.6 * 450)
		ix.efg.levels[lvl] = total
	end
end

function ix.efg.GetLevel(xp)
	xp = xp or 0
	local level = 1

	for lvl, needed in ipairs(ix.efg.levels) do
		if (xp >= needed) then
			level = lvl
		else
			break
		end
	end

	return level
end

do
	local CHAR = ix.meta.character

	function CHAR:GetEFGXP()
		return self:GetData("efgXP", 0)
	end

	function CHAR:GetEFGLevel()
		return ix.efg.GetLevel(self:GetEFGXP())
	end
end

do
	local PLAYER = FindMetaTable("Player")

	-- true mientras el jugador está desplegado en una raid
	function PLAYER:InRaid()
		return self:GetNetVar("efgRaidEnd") != nil
	end

	-- "pmc", "scav" o nil
	function PLAYER:GetRaidSide()
		return self:GetNetVar("efgRaidSide")
	end
end

-- ─── Comandos ────────────────────────────────────────────────────────────────
ix.command.Add("Raid", {
	description = "Despliega a tu PMC (y a tu grupo, si eres el líder) en una raid.",
	OnRun = function(self, client)
		return PLUGIN:RequestDeploy(client, "pmc")
	end
})

ix.command.Add("RaidScav", {
	description = "Entra a la raid como Scav con equipo aleatorio. Tu PMC no arriesga nada.",
	OnRun = function(self, client)
		return PLUGIN:RequestDeploy(client, "scav")
	end
})

ix.command.Add("Extracciones", {
	description = "Muestra el tiempo restante y tus extracciones (también con la tecla O).",
	OnRun = function(self, client)
		if (!client:InRaid()) then
			return "No estás en una raid."
		end

		net.Start("ixEFGShowExtracts")
		net.Send(client)
	end
})

ix.command.Add("Nivel", {
	description = "Muestra tu nivel, tu experiencia y tus estadísticas de raids.",
	OnRun = function(self, client)
		local char = client:GetCharacter()
		local xp = char:GetEFGXP()
		local level = ix.efg.GetLevel(xp)
		local nextXP = ix.efg.levels[level + 1]
		local stats = char:GetData("efgStats", {})

		client:ChatPrint(("Nivel %d · %s XP%s"):format(level, string.Comma(xp),
			nextXP and (" (siguiente nivel: " .. string.Comma(nextXP) .. ")") or ""))
		client:ChatPrint(("Raids: %d · Sobrevividas: %d · Muertes: %d · MIA: %d · Bajas: %d"):format(
			stats.raids or 0, stats.survived or 0, stats.killed or 0, stats.mia or 0, stats.kills or 0))
	end
})

-- Grupos
ix.command.Add("GrupoInvitar", {
	description = "Invita a un jugador a tu grupo de raid.",
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		return PLUGIN:GroupInvite(client, target)
	end
})

ix.command.Add("GrupoAceptar", {
	description = "Acepta la última invitación de grupo que has recibido.",
	OnRun = function(self, client)
		return PLUGIN:GroupAccept(client)
	end
})

ix.command.Add("GrupoSalir", {
	description = "Sales de tu grupo de raid.",
	OnRun = function(self, client)
		return PLUGIN:GroupLeave(client)
	end
})

-- Administración del mapa
ix.command.Add("RaidSetEscondite", {
	description = "Fija el punto del escondite (zona segura y punto de reaparición) donde estás.",
	adminOnly = true,
	OnRun = function(self, client)
		PLUGIN:SetHideout(client:GetPos(), client:EyeAngles())
		return "Escondite fijado aquí."
	end
})

ix.command.Add("RaidAddSpawn", {
	description = "Añade un punto de aparición de raid donde estás.",
	adminOnly = true,
	OnRun = function(self, client)
		local count = PLUGIN:AddSpawn(client:GetPos(), client:EyeAngles())
		return ("Spawn de raid añadido (%d en total)."):format(count)
	end
})

ix.command.Add("RaidAddExtract", {
	description = "Añade una extracción donde estás. Tipo: siempre, aleatoria, pago, sin_mochila. Bando: todos, pmc, scav.",
	adminOnly = true,
	arguments = {
		ix.type.string,
		ix.type.string,
		bit.bor(ix.type.number, ix.type.optional),
		bit.bor(ix.type.string, ix.type.optional),
		bit.bor(ix.type.number, ix.type.optional)
	},
	argumentNames = {"nombre", "tipo", "radio", "bando", "coste"},
	OnRun = function(self, client, name, kind, radius, side, cost)
		kind = string.lower(kind)
		side = string.lower(side or "todos")

		if (!ix.efg.extractTypes[kind]) then
			return "Tipo no válido. Usa: siempre, aleatoria, pago o sin_mochila."
		end

		if (!ix.efg.extractSides[side]) then
			return "Bando no válido. Usa: todos, pmc o scav."
		end

		PLUGIN:AddExtract({
			name = name,
			type = kind,
			side = side,
			radius = math.Clamp(radius or 150, 32, 2000),
			cost = (kind == "pago") and math.max(cost or 7000, 0) or nil,
			pos = client:GetPos()
		})

		return ("Extracción \"%s\" (%s) añadida."):format(name, ix.efg.extractTypes[kind])
	end
})

ix.command.Add("RaidRemoveNearest", {
	description = "Borra el spawn o la extracción más cercana (a menos de 300 unidades).",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:RemoveNearest(client:GetPos())
	end
})

ix.command.Add("RaidList", {
	description = "Lista los puntos de raid del mapa.",
	adminOnly = true,
	OnRun = function(self, client)
		local data = PLUGIN:GetMapData()

		client:ChatPrint("Escondite: " .. (data.hideout and tostring(data.hideout.pos) or "sin fijar"))
		client:ChatPrint(("Spawns: %d"):format(#data.spawns))

		for i, v in ipairs(data.extracts) do
			client:ChatPrint(("Extracción %d: %s · %s · bando %s · radio %d%s"):format(i, v.name,
				ix.efg.extractTypes[v.type] or v.type, v.side, v.radius, v.cost and (" · " .. v.cost .. " RUB") or ""))
		end
	end
})

ix.command.Add("RaidForceEnd", {
	description = "Saca de la raid a un jugador y lo lleva al escondite sin perder el equipo.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		if (!target:InRaid()) then
			return target:Name() .. " no está en una raid."
		end

		PLUGIN:EndRaid(target, "admin")
		return target:Name() .. " ha salido de la raid."
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_scav.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_extracts.lua")

if (SERVER) then
	for _, name in ipairs({"icon_find_point", "exit_status_runner", "icon_exit_pmc_yes", "icon_exit_pmc_yes_marathon", "icon_exit_pmc_no", "notification_icon_alert_green"}) do
		resource.AddFile("materials/efg/raids/" .. name .. ".png")
	end

	for _, name in ipairs({"exit_yes", "message_notice", "error_message", "button_click", "button_over"}) do
		resource.AddFile("sound/efg/raids/" .. name .. ".wav")
	end
end
