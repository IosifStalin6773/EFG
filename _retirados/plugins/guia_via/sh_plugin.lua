local PLUGIN = PLUGIN

PLUGIN.name = "Guía de Vía"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Muros invisibles colocables por admin que canalizan vehículos sobre raíles (como la draisina) por tramos del mapa donde el rail físico no existe."

ix.guiavia = ix.guiavia or {}
ix.guiavia.segments = ix.guiavia.segments or {}
ix.guiavia.editing = ix.guiavia.editing or {} -- [client] = Vector de inicio pendiente

ix.guiavia.defaultWidth = 90   -- ancho del canal si no se especifica
ix.guiavia.wallThickness = 6   -- grosor de cada muro guía
ix.guiavia.wallHeight = 60     -- alto de cada muro guía
ix.guiavia.floorThickness = 8  -- grosor de la losa de suelo (su superficie va a la altura del rail)

ix.command.Add("GuiaViaInicio", {
	description = "Marca el punto de inicio de un tramo de guía en tu posición actual.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			ix.guiavia.editing[client] = client:GetPos()
			client:Notify("Punto de inicio marcado. Ve al otro extremo del tramo sin rail y usa /GuiaViaFin.")
		end
	end
})

ix.command.Add("GuiaViaFin", {
	description = "Marca el final del tramo y crea los muros guía. Uso: /GuiaViaFin [ancho, por defecto 90].",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, width)
		if (SERVER) then
			local startPos = ix.guiavia.editing[client]
			if (!startPos) then
				return client:Notify("Primero marca el inicio con /GuiaViaInicio.")
			end

			width = math.Clamp(math.floor(width or ix.guiavia.defaultWidth), 20, 400)

			local id = ix.guiavia.CreateSegment(startPos, client:GetPos(), width)
			ix.guiavia.editing[client] = nil

			client:Notify(("Tramo de guía #%i creado (ancho %i)."):format(id, width))
		end
	end
})

ix.command.Add("GuiaViaListar", {
	description = "Lista todos los tramos de guía registrados.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local count = table.Count(ix.guiavia.segments)
			if (count == 0) then
				return client:Notify("No hay tramos de guía registrados.")
			end

			client:ChatPrint("=== Tramos de Guía de Vía (" .. count .. ") ===")
			for id, seg in pairs(ix.guiavia.segments) do
				local a = Vector(seg.startPos.x, seg.startPos.y, seg.startPos.z)
				local b = Vector(seg.endPos.x, seg.endPos.y, seg.endPos.z)
				client:ChatPrint(("#%i — longitud %i u, ancho %i u"):format(id, math.floor(a:Distance(b)), seg.width))
			end
		end
	end
})

ix.command.Add("GuiaViaQuitar", {
	description = "Elimina un tramo de guía por su ID (ver /GuiaViaListar).",
	adminOnly = true,
	arguments = {ix.type.number},
	OnRun = function(self, client, id)
		if (SERVER) then
			if (ix.guiavia.RemoveSegment(math.floor(id))) then
				client:Notify("Tramo #" .. math.floor(id) .. " eliminado.")
			else
				client:Notify("No existe ningún tramo con ese ID.")
			end
		end
	end
})

ix.command.Add("GuiaViaMostrar", {
	description = "Activa o desactiva la visualización de los tramos de guía.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("guia_via")
			if (plugin) then plugin:SendSegmentListTo(client) end
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
