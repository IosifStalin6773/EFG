PLUGIN.name        = "Misiones"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Sistema de misiones parametrizables y multi-paso (exploración, eliminación, búsqueda y entrega), creables in-game por administradores desde los traders."

ix.missions = ix.missions or {}

-- Definición de misiones (server-authoritative; el cliente recibe copias)
ix.missions.list = ix.missions.list or {}

-- Misión diaria activa por trader: [traderKey] = {missionId, at = timestamp}
ix.missions.dailyState = ix.missions.dailyState or {}

-- Tipos de paso disponibles. Cada uno mapea 1:1 con un comando de captura.
ix.missions.STEP_EXPLORE = "explore"
ix.missions.STEP_KILL    = "kill"
ix.missions.STEP_FETCH   = "fetch"
ix.missions.STEP_DELIVER = "deliver"

ix.missions.stepTypes = {
	{key = "explore", name = "Exploración",      desc = "Llegar a un punto del mapa.",          command = "/setPuntoMision"},
	{key = "kill",    name = "Eliminación",      desc = "Eliminar enemigos en una zona.",       command = "/setSpawnEnemy"},
	{key = "fetch",   name = "Búsqueda",         desc = "Recoger objetos del mundo.",           command = "/setSpawnObject"},
	{key = "deliver", name = "Entrega",          desc = "Entregar objetos al comerciante.",     command = "/setQuestObject"},
}

-- Devuelve la definición de tipo de paso por su clave
function ix.missions.GetStepType(key)
	for _, t in ipairs(ix.missions.stepTypes) do
		if (t.key == key) then return t end
	end
	return nil
end

-- Modos de repetición
ix.missions.repeatModes = {
	{key = "once",      name = "Una vez por personaje"},
	{key = "cooldown",  name = "Repetible con espera"},
	{key = "unlimited", name = "Repetible sin límite"},
}

-- Facciones que pueden ofrecer misiones (coincide con las del plugin de traders)
ix.missions.factions = {
	"prapor", "therapist", "fence", "skier", "peacekeeper", "mechanic", "ragman", "jaeger"
}

-- ── Medidas por defecto (unidades de source) ────────────────────────────────────
ix.config.Add("missions_completeRadius", 128, "Radio por defecto para completar un punto de exploración.", nil, {
	data     = {min = 16, max = 1024},
	category = "Misiones"
})

ix.config.Add("missions_spawnRadius", 1500, "Distancia a la que aparecen los NPCs/objetos de un paso (spawn por proximidad).", nil, {
	data     = {min = 256, max = 8192},
	category = "Misiones"
})

-- ── Variables de personaje (persisten en BD; patrón traderRep) ───────────────────

-- Misión activa: { missionId, traderFaction, stepIndex, progress = {...} }
ix.char.RegisterVar("missionActive", {
	field      = "mission_active",
	fieldType  = ix.type.string,
	default    = "",
	bNoDisplay = true,
	OnGet = function(self, default)
		local raw = self.vars["missionActive"] or default
		if (type(raw) == "string") then
			if (raw == "") then return nil end
			return util.JSONToTable(raw)
		end
		return raw
	end,
	OnSet = function(self, value)
		local oldVar = self.vars["missionActive"]

		if (value == nil) then
			self.vars["missionActive"] = ""
		elseif (type(value) == "table") then
			self.vars["missionActive"] = util.TableToJSON(value)
		else
			self.vars["missionActive"] = value
		end

		-- sin jugador válido (desconectado) net.Send falla y deja el mensaje abierto
		if (SERVER and IsValid(self.player)) then
			net.Start("ixCharacterVarChanged")
				net.WriteUInt(self:GetID(), 32)
				net.WriteString("missionActive")
				net.WriteType(self.vars["missionActive"])
			net.Send(self.player)

			hook.Run("CharacterVarChanged", self, "missionActive", oldVar, self.vars["missionActive"])
		end
	end,
})

-- Registro de misiones completadas: { [missionId] = lastCompletedTimestamp }
ix.char.RegisterVar("missionRecord", {
	field      = "mission_record",
	fieldType  = ix.type.string,
	default    = "{}",
	bNoDisplay = true,
	OnGet = function(self, default)
		local raw = self.vars["missionRecord"] or default
		if (type(raw) == "string") then
			return util.JSONToTable(raw) or {}
		end
		return raw
	end,
	OnSet = function(self, value)
		if (type(value) == "table") then
			self.vars["missionRecord"] = util.TableToJSON(value)
		else
			self.vars["missionRecord"] = value
		end
	end,
})

-- ── Helpers compartidos ─────────────────────────────────────────────────────────

-- Texto del objetivo de un paso, con progreso opcional (para /estadoMision y UI)
function ix.missions.GetStepObjective(step, progress)
	if (!step) then return "—" end
	progress = progress or {}

	if (step.type == "explore") then
		return "Dirígete al punto marcado."
	elseif (step.type == "kill") then
		local cls   = step.npcClass or "enemigos"
		local total = step.count or 1
		local done  = math.min(progress.killed or 0, total)
		local who   = ({scav = "Scavs", pmc = "PMC", usec = "USEC", bear = "BEAR", boss = "jefes"})[step.npcGroup or ""] or "enemigos"
		return "Elimina " .. who .. " (" .. done .. "/" .. total .. ")."
	elseif (step.type == "fetch") then
		local total = step.count or 1
		local done  = math.min(progress.collected or 0, total)
		local name  = (ix.item.list[step.itemID] and ix.item.list[step.itemID].name) or "objetos"
		return "Recoge " .. name .. " (" .. done .. "/" .. total .. ")."
	elseif (step.type == "deliver") then
		local total = step.count or 1
		local name  = (ix.item.list[step.itemID] and ix.item.list[step.itemID].name) or "objetos"
		return "Entrega " .. total .. "x " .. name .. (step.fir and " (encontrado en raid)" or "") .. " al comerciante."
	end

	return "Objetivo desconocido."
end

-- Porcentaje (0-100) de completado del paso actual
function ix.missions.GetStepPercent(step, progress)
	if (!step) then return 0 end
	progress = progress or {}

	if (step.type == "kill") then
		local total = math.max(step.count or 1, 1)
		return math.Clamp(math.floor(((progress.killed or 0) / total) * 100), 0, 100)
	elseif (step.type == "fetch") then
		local total = math.max(step.count or 1, 1)
		return math.Clamp(math.floor(((progress.collected or 0) / total) * 100), 0, 100)
	end

	-- explore / deliver son binarios: 0 hasta cumplirse
	return 0
end

-- Stubs de cliente para que los comandos aparezcan en el autocompletado del chat
if (CLIENT) then
	ix.command.Add("debugMision",    { adminOnly=true, description="[DEBUG] Muestra el estado raw de la misión activa del personaje.", OnRun=function(self, client) end })
	ix.command.Add("setPuntoMision", { adminOnly=true, arguments={bit.bor(ix.type.number, ix.type.optional)}, description="Fija el punto de un paso de exploración en tu posición actual.", OnRun=function(self, client, radius) end })
	ix.command.Add("setSpawnEnemy",  { adminOnly=true, arguments={ix.type.string, ix.type.number}, description="Define la clase de NPC y la cantidad a eliminar en un paso de eliminación.", OnRun=function(self, client, npcClass, count) end })
	ix.command.Add("setSpawnObject", { adminOnly=true, arguments={ix.type.string, bit.bor(ix.type.number, ix.type.optional)}, description="Define el objeto (por nombre) y cantidad a recoger de un paso de búsqueda (en tu mira).", OnRun=function(self, client, itemName, count) end })
	ix.command.Add("setQuestObject", { adminOnly=true, arguments={ix.type.string, ix.type.number}, description="Define el objeto (por nombre) y cantidad a entregar al trader en un paso de entrega.", OnRun=function(self, client, itemName, count) end })
	ix.command.Add("MisionAdmin",    { adminOnly=true, description="Abre el panel de administración de misiones.", OnRun=function(self, client) end })
	ix.command.Add("estadoMision",   { description="Muestra el estado de tu misión activa.", OnRun=function(self, client) end })
	ix.command.Add("abandonarMision", { description="Abandona tu misión activa (se pierde el progreso).", OnRun=function(self, client) end })
end

-- Nota: la carpeta items/ se auto-carga como ítems por el loader de Helix.
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
