PLUGIN.name        = "Misiones Comunitarias"
PLUGIN.author      = "Metro RP By Cono y Manperra"
PLUGIN.description = "Misiones cooperativas con progreso compartido. Todos los jugadores contribuyen al mismo objetivo."

ix.communityMissions = ix.communityMissions or {}

-- Tipos de misión comunitaria
ix.communityMissions.types = {
	{key = "kill",    name = "Eliminación", desc = "Eliminar NPCs de un tipo concreto."},
	{key = "deliver", name = "Entrega",     desc = "Entregar objetos a cualquier comerciante."},
}

function ix.communityMissions.GetTypeInfo(key)
	for _, t in ipairs(ix.communityMissions.types) do
		if (t.key == key) then return t end
	end
end

function ix.communityMissions.GetObjectiveText(data)
	if (!data) then return "---" end

	local progress  = data.progress  or 0
	local goalCount = data.goalCount or 1

	if (data.type == "kill") then
		local name = data.targetName or data.npcClass or "enemigos"
		if (name == "") then name = data.npcClass or "enemigos" end
		return "Eliminar " .. name .. " (" .. progress .. "/" .. goalCount .. ")"
	elseif (data.type == "deliver") then
		if (data.deliverItems and #data.deliverItems > 0) then
			local parts = {}
			for _, di in ipairs(data.deliverItems) do
				local name = ""
				if (CLIENT and ix.item and ix.item.list and di.id) then
					local d = ix.item.list[di.id]
					if (d) then name = d.name end
				end
				if (name == "") then name = di.id or "objetos" end
				local done = data.deliverProgress and data.deliverProgress[di.id] or 0
				table.insert(parts, name .. " " .. done .. "/" .. (di.count or 1))
			end
			return "Entregar: " .. table.concat(parts, ", ")
		end
		return "Entregar objetos (" .. progress .. "/" .. goalCount .. ")"
	end

	return "Objetivo desconocido."
end

-- Stubs cliente para autocompletado de comandos
if (CLIENT) then
	ix.command.Add("MisionComunitariaAdmin", {adminOnly = true, description = "Abre el panel de administración de misiones comunitarias.", OnRun = function() end})
	ix.command.Add("unirseComunitaria",      {description = "Únete a la misión comunitaria activa.", OnRun = function() end})
	ix.command.Add("estadoComunitaria",      {description = "Muestra el estado de la misión comunitaria activa.", OnRun = function() end})
	ix.command.Add("entregarComunitaria",    {description = "Entrega objetos para la misión comunitaria (cerca de un comerciante).", OnRun = function() end})
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
