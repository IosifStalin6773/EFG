local PLUGIN = PLUGIN

PLUGIN.name = "Tareas diarias"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Tareas diarias procedurales por personaje y comerciante, escaladas por nivel de PMC y lealtad."

-- Nombre elegido para cargar después de missions y efg_tasks (orden alfabético).
-- traders carga después de este plugin, así que ix.traders solo se usa en tiempo de ejecución.

ix.tareasDiarias = ix.tareasDiarias or {}

-- Puntos de zona fijados por admin: [mapa][índice] = {pos = {x,y,z}, radius}
ix.tareasDiarias.zonePoints = ix.tareasDiarias.zonePoints or {}

ix.config.Add("tareasDiariasActivas", true, "Activa las tareas diarias procedurales de los comerciantes. [VERIFICAR]", nil, {
	category = "Misiones"
})

ix.config.Add("tareasDiariasHoras", 24, "Horas hasta que un comerciante asigna una tarea nueva al personaje. [VERIFICAR]", nil, {
	data = {min = 1, max = 168},
	category = "Misiones"
})

-- Banda de escalado (1-4) según el nivel de PMC; las bandas siguen los minLevel de lealtad.
function ix.tareasDiarias.GetBand(level)
	local band = 1

	for i, entry in ipairs(ix.traders.repLevels or {}) do
		if (level >= entry.minLevel) then band = i end
	end

	return band
end

-- Estado por personaje: { [traderKey] = {at = os.time(), task = {...}} }
ix.char.RegisterVar("tareasDiarias", {
	field      = "tareas_diarias",
	fieldType  = ix.type.string,
	default    = "{}",
	bNoDisplay = true,
	OnGet = function(self, default)
		local raw = self.vars["tareasDiarias"] or default
		if (type(raw) == "string") then
			return util.JSONToTable(raw) or {}
		end
		return raw
	end,
	OnSet = function(self, value)
		if (type(value) == "table") then
			self.vars["tareasDiarias"] = util.TableToJSON(value)
		else
			self.vars["tareasDiarias"] = value
		end
	end,
})

ix.util.Include("sh_templates.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("sv_plugin.lua")
