-- ============================================================
--  dresina_via  |  sh_commands.lua
-- ============================================================

-- Activa/desactiva el modo interactivo de edición de waypoints: clic
-- izquierdo añade, clic derecho coge/suelta (mover), R elimina el más
-- cercano a donde miras. La lógica real vive en sv_plugin.lua
-- (net.Receive("DresinaVia_WPAction")) y cl_plugin.lua (PlayerBindPress + HUD).
ix.command.Add("DresinaViaWP", {
	description = "Activa/desactiva el modo de edición de waypoints (clic izq. añade, clic der. mueve, R elimina). Vuelve a usar el comando para salir.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local active = !ix.dresinavia.wpModeActive[client]

			if (active) then
				ix.dresinavia.wpModeActive[client] = true
			else
				ix.dresinavia.wpModeActive[client] = nil
			end
			ix.dresinavia.wpHeldIndex[client] = nil

			net.Start("DresinaVia_WPMode")
				net.WriteBool(active)
				net.WriteString(ix.dresinavia.editingRouteId)
			net.Send(client)

			-- Al entrar en el modo, refrescar el overlay con los waypoints
			-- actuales para poder ver dónde insertar/mover/borrar.
			if (active) then
				local plugin = ix.plugin.Get("dresina_via")
				if (plugin) then plugin:SendRouteRefresh(client) end
			end

			client:Notify(active and "Modo de edición de vía ACTIVADO. Vuelve a escribir /DresinaViaWP para salir." or "Modo de edición de vía DESACTIVADO.")
		end
	end
})

ix.command.Add("DresinaViaQuitar", {
	description = "Elimina el waypoint del camino de la draisina más cercano a donde miras (máx 200u).",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local trace = client:GetEyeTraceNoCursor()
			if (!trace or !trace.HitPos) then
				return client:Notify("Mira hacia una superficie.")
			end

			local routeId = ix.dresinavia.editingRouteId
			local route = ix.dresinavia.EnsureRoute(routeId)
			local wps = route.waypoints

			local closestIdx, closestDist = nil, math.huge
			for i, wp in ipairs(wps) do
				local dist = Vector(wp.x, wp.y, wp.z):Distance(trace.HitPos)
				if (dist < ix.dresinavia.wpRemoveRange and dist < closestDist) then
					closestIdx = i
					closestDist = dist
				end
			end

			if (!closestIdx) then
				return client:Notify("No hay ningún waypoint cerca de donde miras.")
			end

			table.remove(wps, closestIdx)
			ix.dresinavia.RebuildCache(routeId)

			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			client:Notify(("[%s] Waypoint #%i eliminado (%i restantes)."):format(routeId, closestIdx, #wps))
		end
	end
})

ix.command.Add("DresinaViaListar", {
	description = "Muestra cuántos waypoints tiene la ruta que estás editando (y su longitud total), y un resumen de todas las demás.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local routeId = ix.dresinavia.editingRouteId
			local route = ix.dresinavia.EnsureRoute(routeId)
			local cum = ix.dresinavia.cumDist[routeId]
			local total = (cum and #route.waypoints > 0) and cum[#route.waypoints] or 0

			client:ChatPrint(("[Vía de Draisina] Editando ahora: '%s' — %i waypoints, %i u de longitud, loop: %s"):format(routeId, #route.waypoints, math.floor(total), route.loop and "sí" or "no"))

			-- Cuenta de waypoints por cada ruta, para detectar de un vistazo los
			-- tramos "huérfanos" (1 solo waypoint de anclaje, creados al abrir o
			-- cerrar una rama con E, a los que aún no se les añadió nada más).
			local names = {}
			for id in pairs(ix.dresinavia.routes) do table.insert(names, id) end
			table.sort(names)

			client:ChatPrint("Rutas existentes:")
			for _, id in ipairs(names) do
				local count = #ix.dresinavia.routes[id].waypoints
				local warn = (count < 2) and "  ⚠ sin terminar" or ""
				client:ChatPrint(("  - %s%s: %i waypoint(s)%s"):format(id, (id == routeId) and " (activa)" or "", count, warn))
			end
		end
	end
})

ix.command.Add("DresinaViaRuta", {
	description = "Cambia (o crea) la ruta que editan /DresinaViaWP, /DresinaViaQuitar, /DresinaViaLoop y /DresinaViaMostrar. Uso: /DresinaViaRuta <nombre>",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, name)
		if (SERVER) then
			name = string.lower(string.Trim(name))
			if (name == "") then
				return client:Notify("Indica un nombre de ruta.")
			end

			local isNew = !ix.dresinavia.routes[name]
			if (isNew) then
				ix.dresinavia.routes[name] = {waypoints = {}, loop = false}
				ix.dresinavia.RebuildCache(name)
			end

			ix.dresinavia.editingRouteId = name

			-- Persistir SIEMPRE (no solo si es nueva): si no, tras un reinicio
			-- del servidor "editingRouteId" no sobrevive y los comandos vuelven
			-- a apuntar a "main" en silencio sin que el admin se dé cuenta.
			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then plugin:SaveData() end

			client:Notify(isNew and ("Ruta '" .. name .. "' creada. Editándola ahora.") or ("Editando ahora la ruta '" .. name .. "'."))
		end
	end
})

ix.command.Add("DresinaViaEliminarRuta", {
	description = "Elimina una ruta entera (no solo sus waypoints), sin excepciones. Uso: /DresinaViaEliminarRuta <nombre> <nombre otra vez, para confirmar>. /DresinaViaEliminarRuta all all borra TODAS las rutas y agujas.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.string},
	OnRun = function(self, client, name, confirmName)
		if (SERVER) then
			name = string.lower(string.Trim(name))
			confirmName = string.lower(string.Trim(confirmName or ""))

			-- "all all": borra TODAS las rutas y agujas de golpe (útil tras un
			-- montón de pruebas con ramas sueltas). Mismo patrón de doble
			-- confirmación que borrar una sola ruta, con la palabra "all" en
			-- vez del nombre.
			if (name == "all") then
				if (confirmName != "all") then
					return client:Notify("Escribe /DresinaViaEliminarRuta all all para confirmar que quieres eliminar TODAS las rutas y agujas.")
				end

				local routeCount, switchCount = 0, 0
				for _ in pairs(ix.dresinavia.routes) do routeCount = routeCount + 1 end
				for _ in pairs(ix.dresinavia.switches) do switchCount = switchCount + 1 end

				for id in pairs(ix.dresinavia.switches) do
					ix.dresinavia.RemoveSwitchEntities(id)
				end

				ix.dresinavia.routes = {}
				ix.dresinavia.cumDist = {}
				ix.dresinavia.switches = {}
				ix.dresinavia.RebuildSwitchIndex()
				ix.dresinavia.wpBranchStack = {} -- ramas abiertas de cualquier admin quedan obsoletas

				ix.dresinavia.editingRouteId = "main"
				ix.dresinavia.EnsureRoute("main")

				local plugin = ix.plugin.Get("dresina_via")
				if (plugin) then
					plugin:SaveData()
					plugin:BroadcastToViewers()
				end

				client:Notify(("Eliminadas %i ruta(s) y %i aguja(s). Solo queda 'main', vacía."):format(routeCount, switchCount))
				return
			end

			if (!ix.dresinavia.routes[name]) then
				return client:Notify("No existe ninguna ruta llamada '" .. name .. "'.")
			end

			if (confirmName != name) then
				return client:Notify(("Escribe /DresinaViaEliminarRuta %s %s para confirmar que quieres eliminar la ruta entera."):format(name, name))
			end

			if (ix.dresinavia.routeEndpointSwitch[name]) then
				client:Notify("Aviso: esa ruta tenía una aguja conectada — esa conexión ha quedado rota, quítala con /DresinaSwitchQuitar.")
			end

			ix.dresinavia.routes[name] = nil
			ix.dresinavia.cumDist[name] = nil

			if (ix.dresinavia.editingRouteId == name) then
				ix.dresinavia.editingRouteId = "main"
			end

			-- "main" es donde siempre aparece la draisina: si se borró (con o sin
			-- estar editándola), recrearla vacía en el acto evita que el próximo
			-- spawn o el próximo /DresinaViaWP/Quitar/Loop/Listar crasheen.
			ix.dresinavia.EnsureRoute("main")

			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			client:Notify(("Ruta '%s' eliminada."):format(name))
		end
	end
})

ix.command.Add("DresinaViaLimpiar", {
	description = "Borra TODOS los waypoints de la ruta que estás editando (irreversible). Uso: /DresinaViaLimpiar <nombre de la ruta, para confirmar>",
	adminOnly = true,
	arguments = {ix.type.string},
	OnRun = function(self, client, confirmName)
		if (SERVER) then
			local routeId = ix.dresinavia.editingRouteId

			-- Confirmación obligatoria: hay que escribir el nombre exacto de la
			-- ruta que se está editando ahora mismo. Sin esto, un admin que
			-- pierda de vista qué ruta tiene activa (p. ej. tras un reinicio del
			-- servidor) puede vaciar la ruta equivocada sin darse cuenta.
			if (string.lower(string.Trim(confirmName or "")) != routeId) then
				return client:Notify(("Estás editando la ruta '%s'. Escribe /DresinaViaLimpiar %s para confirmar que quieres borrar TODOS sus waypoints."):format(routeId, routeId))
			end

			local route = ix.dresinavia.EnsureRoute(routeId)

			local count = #route.waypoints
			route.waypoints = {}
			ix.dresinavia.RebuildCache(routeId)

			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			client:Notify(("Ruta '%s': %i waypoints eliminados."):format(routeId, count))
		end
	end
})

ix.command.Add("DresinaViaDensificar", {
	description = "Remuestrea la curva actual de la ruta que editas en waypoints automáticos cada X unidades (50 por defecto), para que siga la curva con más precisión. Uso: /DresinaViaDensificar [espaciado]",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, spacing)
		if (SERVER) then
			local routeId = ix.dresinavia.editingRouteId
			local ok, result = ix.dresinavia.DensifyRoute(routeId, spacing)
			if (!ok) then
				return client:Notify(result)
			end

			local plugin = ix.plugin.Get("dresina_via")

			-- TEMPORAL: diagnóstico para ver si BroadcastToViewers realmente
			-- alcanza a quien ejecuta el comando. Quitar cuando se confirme.
			local viewerCount, isViewer = 0, false
			for v in pairs(ix.dresinavia.viewers) do
				viewerCount = viewerCount + 1
				if (v == client) then isViewer = true end
			end
			print(("[DresinaVia][debug] Densificar: plugin=%s viewers=%i esteCliente=%s"):format(
				tostring(plugin != nil), viewerCount, tostring(isViewer)))

			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			client:Notify(("Ruta '%s' remuestreada: ahora tiene %i waypoints."):format(routeId, result))
		end
	end
})

ix.command.Add("DresinaViaSuavizar", {
	description = "Ensancha las curvas de la ruta que editas donde el giro es más cerrado de lo que la longitud del vehículo permitiría en la realidad. Uso: /DresinaViaSuavizar [radio mínimo, por defecto según el modelo]",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, radius)
		if (SERVER) then
			local routeId = ix.dresinavia.editingRouteId
			local route = ix.dresinavia.EnsureRoute(routeId)

			if (#route.waypoints < 3) then
				return client:Notify("La ruta necesita al menos 3 waypoints para poder suavizar curvas.")
			end

			local minRadius = radius and math.Clamp(radius, ix.dresinavia.vehicleLength, 5000) or nil
			local fixedCount = ix.dresinavia.EnforceMinRadius(routeId, minRadius)

			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			local usedRadius = minRadius or ix.dresinavia.minTurnRadius
			if (fixedCount == 0) then
				client:Notify(("[%s] Ninguna curva por debajo del radio mínimo (%iu)."):format(routeId, usedRadius))
			else
				client:Notify(("[%s] %i waypoint(s) ajustados para ensanchar curvas demasiado cerradas (radio mínimo %iu)."):format(routeId, fixedCount, usedRadius))
			end
		end
	end
})

ix.command.Add("DresinaViaAlturaAsiento", {
	description = "Consulta o ajusta la altura (Z) del jugador sobre el asiento de la draisina, aplicándola al instante a los pasajeros ya sentados. Uso: /DresinaViaAlturaAsiento [valor]",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, value)
		if (SERVER) then
			if (!value) then
				return client:Notify(("Altura de asiento actual: %su."):format(ix.dresinavia.seatHeightOffset))
			end

			ix.dresinavia.seatHeightOffset = value

			for veh, data in pairs(ix.dresinavia.active) do
				for seatIdx = 0, 3 do
					local ply = data.passengers[seatIdx]
					if (IsValid(ply) and ply != NULL) then
						ply:SetLocalPos(Vector(0, 0, value))
					end
				end
			end

			client:Notify(("Altura de asiento ajustada a %su."):format(value))
		end
	end
})

ix.command.Add("DresinaViaAlturaCamara", {
	description = "Consulta o ajusta la altura (Z) de la cámara mientras vas sentado en la draisina, aplicándola al instante a los pasajeros ya sentados. Uso: /DresinaViaAlturaCamara [valor]",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, value)
		if (SERVER) then
			if (!value) then
				return client:Notify(("Altura de cámara sentado actual: %su."):format(ix.dresinavia.seatedViewOffset))
			end

			ix.dresinavia.seatedViewOffset = value

			for veh, data in pairs(ix.dresinavia.active) do
				for seatIdx = 0, 3 do
					local ply = data.passengers[seatIdx]
					if (IsValid(ply) and ply != NULL) then
						ply:SetViewOffset(Vector(0, 0, value))
						ply:SetViewOffsetDucked(Vector(0, 0, value))
					end
				end
			end

			client:Notify(("Altura de cámara sentado ajustada a %su."):format(value))
		end
	end
})

ix.command.Add("DresinaViaMostrar", {
	description = "Activa o desactiva la visualización del camino de la draisina.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then plugin:SendRouteTo(client) end
		end
	end
})

ix.command.Add("DresinaViaLoop", {
	description = "Activa o desactiva que el camino de la draisina sea un circuito cerrado.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local routeId = ix.dresinavia.editingRouteId
			local route = ix.dresinavia.EnsureRoute(routeId)
			route.loop = !route.loop

			local plugin = ix.plugin.Get("dresina_via")
			if (plugin) then
				plugin:SaveData()
				plugin:BroadcastToViewers()
			end

			client:Notify(route.loop and "Camino marcado como circuito cerrado." or "Camino marcado como lineal (con dos extremos).")
		end
	end
})

-- ============================================================
--  Agujas (bifurcaciones)
-- ============================================================

ix.command.Add("DresinaSwitchColocar", {
	description = "Coloca una aguja (palanca) en tu posición, conectando 3 rutas ya creadas por el extremo de cada una más cercano a ti. Uso: /DresinaSwitchColocar <tronco> <ramaA> <ramaB>",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.string, ix.type.string},
	OnRun = function(self, client, trunkId, branchAId, branchBId)
		if (SERVER) then
			trunkId = string.lower(string.Trim(trunkId))
			branchAId = string.lower(string.Trim(branchAId))
			branchBId = string.lower(string.Trim(branchBId))

			local ok, idOrErr = ix.dresinavia.CreateSwitch(client:GetPos(), client:EyeAngles(), trunkId, branchAId, branchBId)
			if (!ok) then
				return client:Notify(idOrErr)
			end

			client:Notify(("Aguja #%i creada: tronco '%s' ↔ rama A '%s' / rama B '%s'."):format(idOrErr, trunkId, branchAId, branchBId))
		end
	end
})

ix.command.Add("DresinaSwitchQuitar", {
	description = "Elimina la aguja más cercana a donde miras (máx 200u).",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local trace = client:GetEyeTraceNoCursor()
			if (!trace or !trace.HitPos) then
				return client:Notify("Mira hacia una superficie.")
			end

			local closestId, closestDist = nil, math.huge
			for id, sw in pairs(ix.dresinavia.switches) do
				local dist = Vector(sw.pos.x, sw.pos.y, sw.pos.z):Distance(trace.HitPos)
				if (dist < 200 and dist < closestDist) then
					closestId = id
					closestDist = dist
				end
			end

			if (!closestId) then
				return client:Notify("No hay ninguna aguja cerca de donde miras.")
			end

			ix.dresinavia.RemoveSwitch(closestId)
			client:Notify("Aguja #" .. closestId .. " eliminada.")
		end
	end
})

ix.command.Add("DresinaSwitchListar", {
	description = "Lista todas las agujas registradas.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local count = table.Count(ix.dresinavia.switches)
			if (count == 0) then
				return client:Notify("No hay ninguna aguja registrada.")
			end

			client:ChatPrint("=== Agujas (" .. count .. ") ===")
			for id, sw in pairs(ix.dresinavia.switches) do
				client:ChatPrint(("#%i — tronco '%s' ↔ A '%s' / B '%s' (activa: %s)"):format(id, sw.trunk.routeId, sw.branchA.routeId, sw.branchB.routeId, sw.state))
			end
		end
	end
})

-- Crea una draisina que viaja sola (sin piloto real) entre dos waypoints de
-- una ruta ya existente, con hasta 4 NPCs "a bordo" que se bajan al llegar.
-- La lógica real vive en ix.dresinavia.SpawnNPCDresina (sv_plugin.lua).
ix.command.Add("DresinaNPCViaje", {
	description = "Crea una draisina automática (sin piloto) con 4 NPCs a bordo que viaja del WP de inicio al WP final de una ruta, y los desembarca al llegar. Sin especificar arma, cada NPC sale con una aleatoria. Uso: /DresinaNPCViaje <WP inicio> <WP final> [clase NPC] [arma1,arma2,...] [ruta]",
	adminOnly = true,
	arguments = {
		ix.type.number,
		ix.type.number,
		bit.bor(ix.type.string, ix.type.optional),
		bit.bor(ix.type.string, ix.type.optional),
		bit.bor(ix.type.string, ix.type.optional),
	},
	OnRun = function(self, client, wpInicio, wpFinal, npcClass, npcWeapon, routeId)
		if (SERVER) then
			if (!ix.dresinavia.SpawnNPCDresina) then
				return client:Notify("El sistema de draisina no está activo (¿falta el addon CBH's Metro Dresine?).")
			end

			local ok, result = ix.dresinavia.SpawnNPCDresina(client, wpInicio, wpFinal, npcClass, npcWeapon, routeId)
			if (!ok) then
				return client:Notify(result)
			end
		end
	end
})

-- Lista todas las clases "npc_vj_*" que scripted_ents tiene registradas en
-- este server ahora mismo: /DresinaNPCViaje acepta cualquier NPC ya
-- registrado (VJ Base o no), pero sin saber el nombre exacto es fácil
-- equivocarse (ver el error de "Clase de NPC no reconocida").
ix.command.Add("DresinaNPCListar", {
	description = "Lista todas las clases de NPC del VJ Base registradas en este servidor, para usarlas con /DresinaNPCViaje.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			-- GetStored() puede devolver nil según la versión/entorno; GetList()
			-- es la alternativa más estable — solo hace falta las claves
			-- (nombres de clase), así que la forma distinta de sus valores no importa.
			local stored = scripted_ents.GetStored() or scripted_ents.GetList() or {}

			local classes = {}
			for class in pairs(stored) do
				if (string.sub(class, 1, 7) == "npc_vj_") then
					table.insert(classes, class)
				end
			end
			table.sort(classes)

			if (#classes == 0) then
				return client:Notify("No se encontró ninguna clase 'npc_vj_*' registrada en este servidor.")
			end

			client:ChatPrint(("=== NPCs del VJ Base registrados (%i) ==="):format(#classes))
			for _, class in ipairs(classes) do
				client:ChatPrint("  " .. class)
			end
		end
	end
})

-- Diagnóstico del asiento en el que estás sentado ahora mismo: calcula hacia
-- dónde apuntaría la cámara con el yawOffset actual y compara esa dirección
-- contra la posición de tu propio maniquí (ver CreatePlayerReplica en
-- sv_plugin.lua) para decir directamente si te mira a ti (mal, hay que
-- voltear 180°) o se aleja (bien) — así se reportan los números exactos en
-- vez de tener que describir "me veo a mí mismo" y adivinar el signo.
ix.command.Add("DresinaViaDebugAsiento", {
	description = "Diagnostica la orientación de cámara del asiento de draisina en el que estás sentado.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local seatIdx = client:GetNetVar("dresinaSeatIdx")
			if (seatIdx == nil) then
				return client:Notify("No estás sentado en ninguna draisina.")
			end

			local data, veh
			for v, d in pairs(ix.dresinavia.active) do
				if (d.passengers[seatIdx] == client) then
					data, veh = d, v
					break
				end
			end

			if (!data or !IsValid(veh)) then
				return client:Notify("No se encontró el vehículo de tu asiento.")
			end

			local seatProp = data.props[seatIdx + 5]
			if (!IsValid(seatProp)) then
				return client:Notify("No se encontró el prop de tu asiento.")
			end

			local yawOffset = ix.config.Get("dresinaSeatYaw" .. seatIdx, 90)
			local vehYaw = veh:GetAngles().y
			local propYaw = seatProp:GetAngles().y
			local camYaw = math.NormalizeAngle(propYaw + yawOffset)

			local conclusion = "No hay maniquí para comparar (¿acabas de sentarte?)."
			local replica = client.ixDresinaReplica

			if (IsValid(replica)) then
				local toReplica = replica:GetPos() - client:EyePos()
				toReplica.z = 0

				if (toReplica:LengthSqr() > 1) then
					toReplica:Normalize()

					local camForward = Angle(0, camYaw, 0):Forward()
					camForward.z = 0
					camForward:Normalize()

					local dot = camForward:Dot(toReplica)

					if (dot > 0.3) then
						conclusion = ("MAL: la cámara mira HACIA tu maniquí (dot=%.2f). yawOffset actual %d -> prueba %d."):format(dot, yawOffset, math.NormalizeAngle(yawOffset + 180))
					elseif (dot < -0.3) then
						conclusion = ("OK: la cámara mira lejos de tu maniquí (dot=%.2f)."):format(dot)
					else
						conclusion = ("AMBIGUO: la cámara mira de lado respecto al maniquí (dot=%.2f)."):format(dot)
					end
				end
			end

			local lines = {
				"=== DresinaVia Debug Asiento ===",
				("Asiento index: %d (asiento %d en el juego)"):format(seatIdx, seatIdx + 1),
				("Vehiculo yaw: %.1f"):format(vehYaw),
				("Prop asiento yaw: %.1f"):format(propYaw),
				("yawOffset (dresinaSeatYaw%d): %d"):format(seatIdx, yawOffset),
				("Yaw camara resultante: %.1f"):format(camYaw),
				conclusion,
			}

			for _, line in ipairs(lines) do
				client:ChatPrint(line)
			end

			print(("[DresinaVia] Debug asiento %d de %s:"):format(seatIdx, client:Name()))
			for _, line in ipairs(lines) do
				print("  " .. line)
			end
		end
	end
})
