-- ============================================================
--  dresina_via  |  sv_plugin.lua  (SERVER)
--  Sustituye el movimiento físico del addon "CBH's Metro Dresine"
--  (hooks Tick/KeyPress/PlayerSpawnedVehicle/EntityRemoved, todos
--  identificados por nombre en lua/autorun/metrohandcar.lua) por
--  un camino de waypoints. Reutiliza MHCCreate y MHCSetPassengerTable
--  (globals del addon) para no reimplementar la creación de los
--  props hijos (ruedas/palancas/asientos) ni el bloqueo de inputs
--  del pasajero (MHCBlockBinds/MHCFixPassengerAngles/MHCFinishMove,
--  que no se tocan y siguen funcionando solos).
-- ============================================================

util.AddNetworkString("DresinaVia_SendList")
util.AddNetworkString("DresinaVia_WPMode")
util.AddNetworkString("DresinaVia_WPAction")

-- Ajuste rápido de dresinaSeatYawN desde consola (servidor o admin en su
-- consola de cliente, el motor la reenvía igual), sin tener que escribir
-- ix.config.Set a mano cada vez mientras se calibra con /DresinaViaDebugAsiento.
-- Sin el segundo argumento, solo imprime el valor actual.
concommand.Add("dresina_seatyaw", function(ply, _, args)
	if (IsValid(ply) and !ply:IsAdmin()) then
		ply:ChatPrint("[DresinaVia] Solo administradores.")
		return
	end

	local function out(msg)
		if (IsValid(ply)) then ply:ChatPrint(msg) else print(msg) end
	end

	local seatIdx = tonumber(args[1])
	if (!seatIdx or seatIdx < 0 or seatIdx > 3) then
		out("Uso: dresina_seatyaw <asiento 0-3> <grados>")
		return
	end

	local key = "dresinaSeatYaw" .. seatIdx
	local degrees = tonumber(args[2])

	if (!degrees) then
		out(("%s = %d"):format(key, ix.config.Get(key, 90)))
		return
	end

	ix.config.Set(key, degrees)
	out(("[DresinaVia] %s puesto a %d."):format(key, degrees))
end, nil, "Ajusta el yaw de camara/maniqui del asiento N (0-3) de la draisina. Uso: dresina_seatyaw <asiento> <grados>")

-- Ajuste rápido de la altura/adelanto de cámara al sentarse (dresinaSeatView*),
-- para no ver el propio maniquí en primer plano. dresina_seatview <alto>
-- [adelante] — el adelante es opcional (se mantiene el actual si se omite).
-- La altura se reaplica en caliente a quien ya esté sentado (SetViewOffset
-- normalmente solo se aplica una vez al sentarse); el adelante no hace falta
-- reaplicarlo porque CalcView lo lee del ix.config cada fotograma.
concommand.Add("dresina_seatview", function(ply, _, args)
	if (IsValid(ply) and !ply:IsAdmin()) then
		ply:ChatPrint("[DresinaVia] Solo administradores.")
		return
	end

	local function out(msg)
		if (IsValid(ply)) then ply:ChatPrint(msg) else print(msg) end
	end

	local height = tonumber(args[1])
	if (!height) then
		out(("dresinaSeatViewHeight = %d | dresinaSeatViewForward = %d"):format(
			ix.config.Get("dresinaSeatViewHeight", ix.dresinavia.seatedViewOffset),
			ix.config.Get("dresinaSeatViewForward", 0)))
		out("Uso: dresina_seatview <alto> [adelante]")
		return
	end

	ix.config.Set("dresinaSeatViewHeight", height)

	local forward = tonumber(args[2])
	if (forward) then
		ix.config.Set("dresinaSeatViewForward", forward)
	end

	for veh, data in pairs(ix.dresinavia.active) do
		for seatIdx = 0, 3 do
			local seated = data.passengers[seatIdx]
			if (IsValid(seated) and seated != NULL) then
				seated:SetViewOffset(Vector(0, 0, height))
				seated:SetViewOffsetDucked(Vector(0, 0, height))
			end
		end
	end

	out(("[DresinaVia] Altura %d%s."):format(height, forward and (", adelante " .. forward) or ""))
end, nil, "Ajusta la altura/adelanto de camara al sentarse en la draisina. Uso: dresina_seatview <alto> [adelante]")

-- Ajuste rápido de la inclinación de la palanca de aguja al pasar a la rama B
-- (dresinaLeverOffsetPitch/Yaw/Roll). Reaplica el ángulo a TODAS las agujas
-- ya existentes al momento (ix.dresinavia.ApplySwitchAngle usa el estado
-- actual de cada una), sin tener que accionarlas para ver el cambio.
concommand.Add("dresina_leverangle", function(ply, _, args)
	if (IsValid(ply) and !ply:IsAdmin()) then
		ply:ChatPrint("[DresinaVia] Solo administradores.")
		return
	end

	local function out(msg)
		if (IsValid(ply)) then ply:ChatPrint(msg) else print(msg) end
	end

	local pitch = tonumber(args[1])
	if (!pitch) then
		out(("pitch=%d yaw=%d roll=%d"):format(
			ix.config.Get("dresinaLeverOffsetPitch", ix.dresinavia.switchLeverAngleOffset),
			ix.config.Get("dresinaLeverOffsetYaw", 0),
			ix.config.Get("dresinaLeverOffsetRoll", 0)))
		out("Uso: dresina_leverangle <pitch> [yaw] [roll]")
		return
	end

	ix.config.Set("dresinaLeverOffsetPitch", pitch)

	local yaw = tonumber(args[2])
	if (yaw) then ix.config.Set("dresinaLeverOffsetYaw", yaw) end

	local roll = tonumber(args[3])
	if (roll) then ix.config.Set("dresinaLeverOffsetRoll", roll) end

	for id in pairs(ix.dresinavia.switches) do
		ix.dresinavia.ApplySwitchAngle(id)
	end

	out(("[DresinaVia] Palanca: pitch=%d yaw=%d roll=%d."):format(
		pitch,
		yaw or ix.config.Get("dresinaLeverOffsetYaw", 0),
		roll or ix.config.Get("dresinaLeverOffsetRoll", 0)))
end, nil, "Ajusta la inclinacion de la palanca de aguja al pasar a rama B. Uso: dresina_leverangle <pitch> [yaw] [roll]")

ix.dresinavia.routes = ix.dresinavia.routes or {}
ix.dresinavia.cumDist = ix.dresinavia.cumDist or {}
ix.dresinavia.active = ix.dresinavia.active or {} -- [veh] = data
ix.dresinavia.viewers = ix.dresinavia.viewers or {} -- [client] = true (overlay abierto)
ix.dresinavia.switches = ix.dresinavia.switches or {} -- [id] = {pos, ang, trunk, branchA, branchB, state}
ix.dresinavia.switchEnts = ix.dresinavia.switchEnts or {} -- [id] = {base = ent, lever = ent}
ix.dresinavia.routeEndpointSwitch = ix.dresinavia.routeEndpointSwitch or {} -- [routeId] = {startSwitch=.., endSwitch=..}
ix.dresinavia.wpModeActive = ix.dresinavia.wpModeActive or {} -- [client] = true (modo edición con clic/R activo)
ix.dresinavia.wpHeldIndex = ix.dresinavia.wpHeldIndex or {} -- [client] = índice del waypoint "cogido" con clic derecho, pendiente de soltar
ix.dresinavia.wpBranchStack = ix.dresinavia.wpBranchStack or {} -- [client] = {{parentRouteId, branchRouteId, pos, ang}, ...} ramas abiertas (toque de E), pila para poder anidar
ix.dresinavia.branchCounter = ix.dresinavia.branchCounter or 0 -- para nombrar "rama1", "rama2"... sin que el admin tenga que escribir nombres

-- Color por defecto (el naranja de siempre) para "main" y cualquier ruta
-- creada a mano con /DresinaViaRuta. Las ramas creadas con E (toque) sacan
-- un color de la paleta, distinto del de su ruta padre, para poder
-- distinguirlas de un vistazo en el overlay 3D; una continuación (E
-- mantenido, ver "branch_end") hereda el color de la ruta que continúa, para
-- que se siga viendo como "la misma línea".
local ROUTE_COLOR_DEFAULT = {r = 255, g = 140, b = 0}
local ROUTE_COLOR_PALETTE = {
	{r = 80, g = 200, b = 255},
	{r = 255, g = 80, b = 200},
	{r = 120, g = 255, b = 120},
	{r = 255, g = 220, b = 80},
	{r = 180, g = 120, b = 255},
	{r = 255, g = 120, b = 120},
}

local function NextBranchColor()
	local idx = ((ix.dresinavia.branchCounter - 1) % #ROUTE_COLOR_PALETTE) + 1
	return ROUTE_COLOR_PALETTE[idx]
end

-- ============================================================
--  Modo de edición interactivo (/DresinaViaWP)
--  Clic izquierdo añade, clic derecho coge/suelta (mover), R elimina el
--  waypoint más cercano a donde mira el admin — todo sobre editingRouteId.
-- ============================================================

-- Actualiza el HUD del cliente ("ruta: X") tras un branch_start/branch_end,
-- sin tocar el estado de overlayActive — mismo mensaje que activa el modo,
-- pero el cliente ya sabe que sigue activo y solo refresca el nombre.
local function ResendWPModeRoute(client)
	net.Start("DresinaVia_WPMode")
		net.WriteBool(true)
		net.WriteString(ix.dresinavia.editingRouteId)
	net.Send(client)
end

-- Toque de E: abre una rama nueva desde la ruta que estás editando ahora.
-- Se ancla al ÚLTIMO waypoint real del tronco (no a donde mires al pulsar E,
-- que casi nunca coincide pixel a pixel) para que la rama arranque pegada a
-- main sin ningún hueco visual. Llamada desde PLUGIN:KeyRelease (ver abajo),
-- no desde un net message: medir toque/mantener en el cliente con
-- PlayerBindPress no era fiable (se probó y fallaba), igual que le pasó en
-- su día a las bridas de handcuffs — de ahí que esto use el mismo patrón de
-- KeyPress/KeyRelease en servidor que ellas.
local function IniciarRama(client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	if (!ix.dresinavia.wpModeActive[client]) then return end

	local parentRouteId = ix.dresinavia.editingRouteId
	local parentRoute = ix.dresinavia.EnsureRoute(parentRouteId)

	local anchor
	if (#parentRoute.waypoints > 0) then
		local last = parentRoute.waypoints[#parentRoute.waypoints]
		anchor = Vector(last.x, last.y, last.z)
	else
		local trace = client:GetEyeTraceNoCursor()
		anchor = (trace and trace.HitPos) or client:GetPos()
	end

	ix.dresinavia.branchCounter = ix.dresinavia.branchCounter + 1
	local branchRouteId = "rama" .. ix.dresinavia.branchCounter

	ix.dresinavia.routes[branchRouteId] = {
		waypoints = {{x = anchor.x, y = anchor.y, z = anchor.z}},
		loop = false,
		color = NextBranchColor(),
	}
	ix.dresinavia.RebuildCache(branchRouteId)

	ix.dresinavia.wpBranchStack[client] = ix.dresinavia.wpBranchStack[client] or {}
	table.insert(ix.dresinavia.wpBranchStack[client], {
		parentRouteId = parentRouteId,
		branchRouteId = branchRouteId,
		pos = {x = anchor.x, y = anchor.y, z = anchor.z},
		ang = {p = 0, y = client:EyeAngles().y, r = 0},
	})

	ix.dresinavia.editingRouteId = branchRouteId
	ix.dresinavia.wpHeldIndex[client] = nil

	client:Notify(("Rama '%s' iniciada desde '%s'. Clic izquierdo añade sus waypoints; mantén E 2s para volver."):format(branchRouteId, parentRouteId))
	ResendWPModeRoute(client)

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then
		plugin:SaveData()
		plugin:SendRouteRefresh(client)
		plugin:BroadcastToViewers()
	end
end

-- E mantenido 2s: cierra la rama actual y vuelve a la ruta padre — pero como
-- una aguja solo puede engancharse en un EXTREMO de una ruta, no en un punto
-- intermedio, lo que sigas añadiendo a partir de ahora es un tramo nuevo
-- (mismo color que el padre, para que se vea como la misma línea), anclado
-- al mismo punto exacto donde se abrió la rama — así se conecta sin hueco y
-- la aguja se puede crear ya mismo, sin esperar a que pongas más waypoints.
-- Llamada desde el timer de PLUGIN:KeyPress (ver abajo) cuando la tecla
-- sigue pulsada al llegar al umbral.
local function TerminarRama(client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	if (!ix.dresinavia.wpModeActive[client]) then return end

	local stack = ix.dresinavia.wpBranchStack[client]
	local entry = stack and table.remove(stack)

	if (!entry) then
		client:Notify("No hay ninguna rama abierta que cerrar.")
		return
	end

	local branchRoute = ix.dresinavia.routes[entry.branchRouteId]

	if (!branchRoute or #branchRoute.waypoints <= 1) then
		-- Solo tiene el waypoint de anclaje: no le añadiste nada más, se descarta.
		ix.dresinavia.routes[entry.branchRouteId] = nil
		ix.dresinavia.cumDist[entry.branchRouteId] = nil
		ix.dresinavia.editingRouteId = entry.parentRouteId
		ix.dresinavia.wpHeldIndex[client] = nil

		client:Notify(("Rama '%s' vacía descartada — no llegaste a añadirle waypoints."):format(entry.branchRouteId))
	else
		ix.dresinavia.branchCounter = ix.dresinavia.branchCounter + 1
		local contRouteId = "rama" .. ix.dresinavia.branchCounter
		local parentRoute = ix.dresinavia.routes[entry.parentRouteId]
		local parentColor = (parentRoute and parentRoute.color) or ROUTE_COLOR_DEFAULT
		local anchor = Vector(entry.pos.x, entry.pos.y, entry.pos.z)

		ix.dresinavia.routes[contRouteId] = {
			waypoints = {{x = anchor.x, y = anchor.y, z = anchor.z}},
			loop = false,
			color = parentColor,
		}
		ix.dresinavia.RebuildCache(contRouteId)

		local ang = Angle(entry.ang.p, entry.ang.y, entry.ang.r)

		-- La palanca se coloca apartada del punto exacto del raíl (que es
		-- literalmente por donde pasa la draisina) para poder usarla sin que
		-- el vehículo estorbe. El offset lateral se calcula perpendicular a
		-- la dirección de la vía justo antes del punto de la rama; se queda
		-- bien dentro de switchEndpointTolerance (150u) para no romper el
		-- enganche de las 3 rutas, que sigue haciéndose en el punto real (anchor).
		local leverPos = anchor
		if (parentRoute and #parentRoute.waypoints >= 2) then
			local prev = parentRoute.waypoints[#parentRoute.waypoints - 1]
			local forward = anchor - Vector(prev.x, prev.y, prev.z)
			if (forward:Length() > 1) then
				forward:Normalize()
				local side = forward:Cross(Vector(0, 0, 1))
				leverPos = anchor + side * 80
			end
		end

		local ok, idOrErr = ix.dresinavia.CreateSwitch(leverPos, ang, entry.parentRouteId, entry.branchRouteId, contRouteId)

		if (ok) then
			client:Notify(("Rama '%s' conectada con '%s' (aguja #%i). Sigues editando la CONTINUACIÓN de '%s' (ahora '%s', mismo color)."):format(
				entry.branchRouteId, entry.parentRouteId, idOrErr, entry.parentRouteId, contRouteId))
		else
			client:Notify(("Rama '%s' cerrada, pero la aguja no se pudo crear: %s"):format(entry.branchRouteId, idOrErr))
		end

		ix.dresinavia.editingRouteId = contRouteId
		ix.dresinavia.wpHeldIndex[client] = nil
	end

	ResendWPModeRoute(client)

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then
		plugin:SaveData()
		plugin:SendRouteRefresh(client)
		plugin:BroadcastToViewers()
	end
end

-- Mismo patrón toque/mantener que las bridas de handcuffs: KeyPress arma un
-- timer de BRANCH_HOLD_THRESHOLD que, si sigue vivo cuando dispara (la tecla
-- seguía pulsada), cierra la rama; si KeyRelease llega antes de que el timer
-- dispare, es un toque corto y abre una rama nueva.
local BRANCH_HOLD_THRESHOLD = 2

function PLUGIN:KeyPress(client, key)
	if (key != IN_USE) then return end
	if (!IsValid(client) or !ix.dresinavia.wpModeActive[client]) then return end

	client.ixDresinaHoldPending = true

	-- Si KeyPress se dispara más de una vez mientras la tecla sigue pulsada
	-- (repetición), timer.Create con el mismo nombre REINICIA el timer que ya
	-- hubiera — así nunca se completaban los 2s seguidos. Si ya está corriendo,
	-- no se toca.
	local uniqueID = "DresinaViaHold_" .. client:SteamID64()
	if (timer.Exists(uniqueID)) then return end

	timer.Create(uniqueID, BRANCH_HOLD_THRESHOLD, 1, function()
		if (!IsValid(client)) then return end
		client.ixDresinaHoldPending = nil
		TerminarRama(client)
	end)
end

function PLUGIN:KeyRelease(client, key)
	if (key != IN_USE) then return end
	if (!IsValid(client)) then return end

	local wasPending = client.ixDresinaHoldPending
	client.ixDresinaHoldPending = nil
	if (!wasPending) then return end

	timer.Remove("DresinaViaHold_" .. client:SteamID64())
	IniciarRama(client)
end

net.Receive("DresinaVia_WPAction", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	if (!ix.dresinavia.wpModeActive[client]) then return end

	local action = net.ReadString()

	local trace = client:GetEyeTraceNoCursor()
	if (!trace or !trace.HitPos) then
		client:Notify("Mira hacia una superficie.")
		return
	end

	local pos = trace.HitPos + trace.HitNormal * 2

	local routeId = ix.dresinavia.editingRouteId
	local route = ix.dresinavia.EnsureRoute(routeId)
	local wps = route.waypoints

	local changed = false

	if (action == "add") then
		local insertAt = #wps + 1
		local nearestDist = math.huge

		for i, wp in ipairs(wps) do
			local dist = Vector(wp.x, wp.y, wp.z):Distance(pos)
			if (dist < ix.dresinavia.wpInsertRange and dist < nearestDist) then
				nearestDist = dist
				insertAt = i + 1
			end
		end

		table.insert(wps, insertAt, {x = pos.x, y = pos.y, z = pos.z})
		changed = true
		client:Notify(("[%s] Waypoint #%i añadido (%i en total)."):format(routeId, insertAt, #wps))

	elseif (action == "remove") then
		-- Busca en TODAS las rutas, no solo en la que estás editando: con
		-- varias ramas visibles a la vez en el overlay, tiene más sentido
		-- poder limpiar cualquier waypoint que mires sin tener que cambiar de
		-- ruta activa primero.
		local closestRouteId, closestIdx, closestDist = nil, nil, math.huge

		for rid, r in pairs(ix.dresinavia.routes) do
			for i, wp in ipairs(r.waypoints) do
				local dist = Vector(wp.x, wp.y, wp.z):Distance(trace.HitPos)
				if (dist < ix.dresinavia.wpRemoveRange and dist < closestDist) then
					closestDist = dist
					closestRouteId = rid
					closestIdx = i
				end
			end
		end

		if (!closestIdx) then
			client:Notify("No hay ningún waypoint cerca de donde miras.")
			return
		end

		local removedFrom = ix.dresinavia.routes[closestRouteId]
		table.remove(removedFrom.waypoints, closestIdx)
		ix.dresinavia.RebuildCache(closestRouteId)
		ix.dresinavia.wpHeldIndex[client] = nil -- por si el índice cogido quedaba obsoleto (de cualquier ruta)

		client:Notify(("[%s] Waypoint #%i eliminado (%i restantes)."):format(closestRouteId, closestIdx, #removedFrom.waypoints))

		local plugin = ix.plugin.Get("dresina_via")
		if (plugin) then
			plugin:SaveData()
			plugin:BroadcastToViewers()
		end

		return

	elseif (action == "move") then
		-- El clic derecho ahora coge/suelta tanto waypoints (de CUALQUIER ruta,
		-- no solo la que editas) como agujas — lo que esté más cerca de donde
		-- miras al coger. Reposicionar una aguja así evita tener que borrarla
		-- con /DresinaSwitchEliminar y recrearla desde cero solo para afinar
		-- dónde queda físicamente la palanca.
		local held = ix.dresinavia.wpHeldIndex[client]

		if (held) then
			-- Segundo clic derecho: soltar lo cogido en la posición actual
			ix.dresinavia.wpHeldIndex[client] = nil

			if (held.kind == "switch") then
				if (ix.dresinavia.MoveSwitch(held.switchId, pos)) then
					client:Notify(("Aguja #%i movida."):format(held.switchId))
				else
					client:Notify("Esa aguja ya no existe.")
				end
			else
				local heldRoute = ix.dresinavia.routes[held.routeId]
				if (heldRoute and heldRoute.waypoints[held.index]) then
					heldRoute.waypoints[held.index] = {x = pos.x, y = pos.y, z = pos.z}
					ix.dresinavia.RebuildCache(held.routeId)
					client:Notify(("[%s] Waypoint #%i movido."):format(held.routeId, held.index))

					local plugin = ix.plugin.Get("dresina_via")
					if (plugin) then
						plugin:SaveData()
						plugin:BroadcastToViewers()
					end
				else
					client:Notify("Ese waypoint ya no existe.")
				end
			end

			return
		end

		-- Primer clic derecho: coger lo más cercano a donde miras, sea
		-- waypoint (de cualquier ruta) o aguja.
		local closestKind, closestRouteId, closestIdx, closestSwitchId, closestDist = nil, nil, nil, nil, math.huge

		for rid, r in pairs(ix.dresinavia.routes) do
			for i, wp in ipairs(r.waypoints) do
				local dist = Vector(wp.x, wp.y, wp.z):Distance(trace.HitPos)
				if (dist < ix.dresinavia.wpRemoveRange and dist < closestDist) then
					closestDist = dist
					closestKind = "waypoint"
					closestRouteId = rid
					closestIdx = i
				end
			end
		end

		for id, sw in pairs(ix.dresinavia.switches) do
			local dist = Vector(sw.pos.x, sw.pos.y, sw.pos.z):Distance(trace.HitPos)
			if (dist < ix.dresinavia.wpRemoveRange and dist < closestDist) then
				closestDist = dist
				closestKind = "switch"
				closestSwitchId = id
			end
		end

		if (!closestKind) then
			client:Notify("No hay ningún waypoint ni aguja cerca de donde miras para mover.")
			return
		end

		if (closestKind == "switch") then
			ix.dresinavia.wpHeldIndex[client] = {kind = "switch", switchId = closestSwitchId}
			client:Notify(("Aguja #%i cogida — vuelve a hacer clic derecho donde quieras soltarla."):format(closestSwitchId))
		else
			ix.dresinavia.wpHeldIndex[client] = {kind = "waypoint", routeId = closestRouteId, index = closestIdx}
			client:Notify(("[%s] Waypoint #%i cogido — vuelve a hacer clic derecho donde quieras soltarlo."):format(closestRouteId, closestIdx))
		end

		return
	end

	if (changed) then
		ix.dresinavia.RebuildCache(routeId)

		local plugin = ix.plugin.Get("dresina_via")
		if (plugin) then
			plugin:SaveData()
			plugin:BroadcastToViewers()
		end
	end
end)

hook.Add("PlayerDisconnected", "DresinaVia_WPMode_Cleanup", function(client)
	ix.dresinavia.wpModeActive[client] = nil
	ix.dresinavia.wpHeldIndex[client] = nil
	ix.dresinavia.wpBranchStack[client] = nil
end)

-- ============================================================
--  Persistencia
-- ============================================================

function PLUGIN:LoadData()
	local saved = self:GetData({})
	ix.dresinavia.routes = saved.routes or {}
	ix.dresinavia.switches = saved.switches or {}
	ix.dresinavia.branchCounter = saved.branchCounter or 0

	-- Restaurar qué ruta se estaba editando: si no se persiste, tras cada
	-- reinicio del servidor vuelve siempre a "main" en silencio, y un admin
	-- que creía seguir editando una rama puede acabar borrando "main" sin darse
	-- cuenta (esto es justo lo que pasó la primera vez).
	if (saved.editingRouteId and ix.dresinavia.routes[saved.editingRouteId]) then
		ix.dresinavia.editingRouteId = saved.editingRouteId
	end

	if (!ix.dresinavia.routes[ix.dresinavia.activeRouteId]) then
		ix.dresinavia.routes[ix.dresinavia.activeRouteId] = {waypoints = {}, loop = false}
	end

	for routeId in pairs(ix.dresinavia.routes) do
		ix.dresinavia.RebuildCache(routeId)
	end

	ix.dresinavia.RebuildSwitchIndex()

	timer.Simple(1, function()
		for id in pairs(ix.dresinavia.switches) do
			ix.dresinavia.SpawnSwitchEntities(id)
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData({
		routes = ix.dresinavia.routes,
		switches = ix.dresinavia.switches,
		editingRouteId = ix.dresinavia.editingRouteId,
		branchCounter = ix.dresinavia.branchCounter,
	})
end

-- isToggle = true → el cliente alterna overlayActive (respuesta a /DresinaViaMostrar).
-- isToggle = false → solo refresca los datos de un overlay ya abierto (tras editar).
-- Se manda TODAS las rutas (no solo la que se edita) para poder ver de un
-- vistazo dónde se separan las ramas, cada una en su color.
local function SendRouteData(client, isToggle)
	local routeIds = {}
	for id in pairs(ix.dresinavia.routes) do routeIds[#routeIds + 1] = id end

	net.Start("DresinaVia_SendList")
		net.WriteBool(isToggle)
		net.WriteUInt(#routeIds, 8)

		for _, id in ipairs(routeIds) do
			local route = ix.dresinavia.routes[id]
			local color = route.color or ROUTE_COLOR_DEFAULT

			net.WriteString(id)
			net.WriteUInt(#route.waypoints, 16)
			for _, wp in ipairs(route.waypoints) do
				net.WriteVector(Vector(wp.x, wp.y, wp.z))
			end
			net.WriteBool(route.loop == true)
			net.WriteUInt(color.r, 8)
			net.WriteUInt(color.g, 8)
			net.WriteUInt(color.b, 8)
		end
	net.Send(client)
end

function PLUGIN:SendRouteTo(client)
	if (ix.dresinavia.viewers[client]) then
		ix.dresinavia.viewers[client] = nil
	else
		ix.dresinavia.viewers[client] = true
	end

	SendRouteData(client, true)
end

-- Refresco silencioso (no alterna overlayActive en el cliente): se usa al
-- entrar en el modo de edición interactivo para que el overlay ya tenga los
-- waypoints cargados, sin pisar el toggle manual de /DresinaViaMostrar.
function PLUGIN:SendRouteRefresh(client)
	ix.dresinavia.viewers[client] = true
	SendRouteData(client, false)
end

-- Refresca el overlay de todos los admins que lo tengan abierto (tras crear/quitar un waypoint)
function PLUGIN:BroadcastToViewers()
	for client in pairs(ix.dresinavia.viewers) do
		if (IsValid(client)) then
			SendRouteData(client, false)
		else
			ix.dresinavia.viewers[client] = nil
		end
	end
end

-- ============================================================
--  Interpolación sobre el camino
-- ============================================================

-- Crea la ruta vacía si no existe todavía. /DresinaViaEliminarRuta permite
-- borrar CUALQUIER ruta, incluida "main" o la que se esté editando ahora
-- mismo — sin esto, el siguiente /DresinaViaWP/Quitar/Loop/Listar crashearía
-- al intentar leer .waypoints de una ruta que ya no existe.
function ix.dresinavia.EnsureRoute(routeId)
	if (!ix.dresinavia.routes[routeId]) then
		ix.dresinavia.routes[routeId] = {waypoints = {}, loop = false, color = ROUTE_COLOR_DEFAULT}
		ix.dresinavia.RebuildCache(routeId)
	end

	return ix.dresinavia.routes[routeId]
end

-- Recalcula las distancias acumuladas de una ruta (se llama cada vez que cambia)
function ix.dresinavia.RebuildCache(routeId)
	local route = ix.dresinavia.routes[routeId]
	if (!route) then return end

	local wps = route.waypoints
	local cum = {}
	cum[1] = 0
	for i = 2, #wps do
		local a = Vector(wps[i - 1].x, wps[i - 1].y, wps[i - 1].z)
		local b = Vector(wps[i].x, wps[i].y, wps[i].z)
		cum[i] = cum[i - 1] + a:Distance(b)
	end

	ix.dresinavia.cumDist[routeId] = cum
end

-- Catmull-Rom: curva suave que pasa exactamente por cada waypoint (p1..p2 en
-- t=0..1), usando los vecinos p0/p3 para definir la tangente en los extremos
-- del tramo. Sustituye la interpolación lineal (que se veía "poligonal" en
-- curvas) tanto en posición como en el ángulo (tangente de la curva, en vez
-- de un ángulo fijo por tramo que saltaba de golpe en cada waypoint).
local function CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t

	local a = p1 * 2
	local b = (p2 - p0) * t
	local c = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
	local d = (p1 * 3 - p2 * 3 + p3 - p0) * t3

	return (a + b + c + d) * 0.5
end

local function CatmullRomTangent(p0, p1, p2, p3, t)
	local t2 = t * t

	local a = p2 - p0
	local b = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (2 * t)
	local c = (p1 * 3 - p2 * 3 + p3 - p0) * (3 * t2)

	return (a + b + c) * 0.5
end

-- Devuelve el waypoint en `idx` como Vector, sujetando (ruta abierta) o
-- envolviendo (ruta en loop) el índice fuera de rango — así el tramo inicial/
-- final de una ruta abierta también tiene una tangente razonable (duplica el
-- extremo) en vez de intentar leer un waypoint que no existe.
local function GetWP(wps, idx, loop)
	local n = #wps
	if (loop) then
		idx = ((idx - 1) % n) + 1
	else
		idx = math.Clamp(idx, 1, n)
	end
	local p = wps[idx]
	return Vector(p.x, p.y, p.z)
end

-- Como GetWP, pero si el índice cae fuera de una ruta ABIERTA justo en un
-- extremo con una aguja conectada, tira del vecino real de la ruta activa al
-- otro lado de la aguja en vez de duplicar el extremo. Sin esto, la tangente
-- Catmull-Rom en el empalme rama↔tronco solo mira hacia dentro de su propia
-- ruta y da un giro brusco/irreal justo en la unión; con esto la curva "sabe"
-- de dónde viene al otro lado de la aguja. Afecta tanto al movimiento real de
-- la draisina (GetPosAng) como a /DresinaViaDensificar (que remuestrea sobre
-- GetPosAng), que es donde se nota el arreglo al ejecutarlo cerca de la unión.
local function GetWPCrossSwitch(routeId, wps, idx, loop)
	local n = #wps

	if (loop or (idx >= 1 and idx <= n)) then
		return GetWP(wps, idx, loop)
	end

	local endpoint = ix.dresinavia.routeEndpointSwitch[routeId]
	local link = endpoint and endpoint[(idx > n) and "endSwitch" or "startSwitch"]
	local sw = link and ix.dresinavia.switches[link.switchId]

	if (sw) then
		-- Desde el tronco se sigue la rama actualmente activa (sw.state); desde
		-- una rama siempre se mira hacia el tronco, sea cual sea el estado.
		local other
		if (link.role == "trunk") then
			other = (sw.state == "B") and sw.branchB or sw.branchA
		else
			other = sw.trunk
		end

		local otherRoute = other and ix.dresinavia.routes[other.routeId]
		if (otherRoute and #otherRoute.waypoints >= 2) then
			local otherWps = otherRoute.waypoints
			local neighborIdx = other.atEnd and (#otherWps - 1) or 2
			local p = otherWps[neighborIdx]
			return Vector(p.x, p.y, p.z)
		end
	end

	return GetWP(wps, idx, loop)
end

-- Devuelve posición mundial + ángulo a una distancia dada a lo largo del camino
function ix.dresinavia.GetPosAng(routeId, dist)
	local route = ix.dresinavia.routes[routeId]
	local cum = ix.dresinavia.cumDist[routeId]
	if (!route or !cum or #route.waypoints == 0) then return nil, angle_zero end

	local wps = route.waypoints
	if (#wps == 1) then
		local p = wps[1]
		return Vector(p.x, p.y, p.z), angle_zero
	end

	local total = cum[#wps]

	if (route.loop) then
		dist = (total > 0) and (dist % total) or 0
		if (dist < 0) then dist = dist + total end
	else
		dist = math.Clamp(dist, 0, total)
	end

	for i = 1, #wps - 1 do
		local segStart, segEnd = cum[i], cum[i + 1]
		if (dist <= segEnd or i == #wps - 1) then
			local segLen = segEnd - segStart
			local t = (segLen > 0) and math.Clamp((dist - segStart) / segLen, 0, 1) or 0

			local p0 = GetWPCrossSwitch(routeId, wps, i - 1, route.loop)
			local p1 = GetWP(wps, i, route.loop)
			local p2 = GetWP(wps, i + 1, route.loop)
			local p3 = GetWPCrossSwitch(routeId, wps, i + 2, route.loop)

			local pos = CatmullRom(p0, p1, p2, p3, t)
			local tangent = CatmullRomTangent(p0, p1, p2, p3, t)

			if (tangent:LengthSqr() < 0.0001) then
				tangent = p2 - p1
			end

			return pos, tangent:Angle()
		end
	end

	local last = wps[#wps]
	return Vector(last.x, last.y, last.z), angle_zero
end

-- Proyecta worldPos sobre el segmento más cercano del camino y devuelve la
-- distancia acumulada correspondiente (para arrancar sin teletransportarse al inicio)
function ix.dresinavia.GetClosestDistance(routeId, worldPos)
	local route = ix.dresinavia.routes[routeId]
	local cum = ix.dresinavia.cumDist[routeId]
	if (!route or !cum or #route.waypoints < 2) then return 0 end

	local wps = route.waypoints
	local bestDistSqr, bestSegDist = math.huge, 0

	for i = 1, #wps - 1 do
		local a = Vector(wps[i].x, wps[i].y, wps[i].z)
		local b = Vector(wps[i + 1].x, wps[i + 1].y, wps[i + 1].z)
		local seg = b - a
		local segLen = seg:Length()

		local t = 0
		if (segLen > 0) then
			t = math.Clamp((worldPos - a):Dot(seg) / (segLen * segLen), 0, 1)
		end

		local closest = a + seg * t
		local distSqr = worldPos:DistToSqr(closest)

		if (distSqr < bestDistSqr) then
			bestDistSqr = distSqr
			bestSegDist = cum[i] + segLen * t
		end
	end

	return bestSegDist
end

-- Remuestrea la curva Catmull-Rom ACTUAL de una ruta en waypoints nuevos
-- espaciados uniformemente (aprox. cada `spacing` unidades), sustituyendo la
-- lista de waypoints por la remuestreada. Sirve tanto para que el camino siga
-- la curva con más precisión como para poder afinar tramos punto a punto
-- después. No añade ni quita longitud ni forma: solo re-describe la misma
-- curva con más puntos de control.
function ix.dresinavia.DensifyRoute(routeId, spacing)
	local route = ix.dresinavia.routes[routeId]
	if (!route or #route.waypoints < 2) then return false, "La ruta necesita al menos 2 waypoints." end

	local cum = ix.dresinavia.cumDist[routeId]
	local total = cum and cum[#route.waypoints] or 0
	if (total <= 0) then return false, "La ruta no tiene longitud." end

	spacing = math.Clamp(spacing or 50, 10, 1000)

	local steps = math.max(1, math.Round(total / spacing))
	local actualSpacing = total / steps

	local newWps = {}
	for i = 0, steps do
		local dist = math.min(i * actualSpacing, total)
		local pos = ix.dresinavia.GetPosAng(routeId, dist)
		if (pos) then
			table.insert(newWps, {x = pos.x, y = pos.y, z = pos.z})
		end
	end

	route.waypoints = newWps
	ix.dresinavia.RebuildCache(routeId)

	return true, #newWps
end

-- Radio de curva horizontal (X/Y, ignora pendiente) que forma un waypoint con
-- sus dos vecinos, aproximando el tramo como un arco circular. math.huge si
-- los vecinos coinciden con el punto o el tramo es prácticamente recto.
local function LocalTurnRadius(wps, i, n, loop)
	local prevIdx = loop and (((i - 2) % n) + 1) or (i - 1)
	local nextIdx = loop and ((i % n) + 1) or (i + 1)

	local prev = Vector(wps[prevIdx].x, wps[prevIdx].y, 0)
	local cur = Vector(wps[i].x, wps[i].y, 0)
	local nxt = Vector(wps[nextIdx].x, wps[nextIdx].y, 0)

	local toPrev, toNext = prev - cur, nxt - cur
	local lenPrev, lenNext = toPrev:Length(), toNext:Length()
	if (lenPrev < 1 or lenNext < 1) then return math.huge, prev, nxt end

	toPrev:Normalize()
	toNext:Normalize()

	local turnAngle = math.pi - math.acos(math.Clamp(toPrev:Dot(toNext), -1, 1))
	local segLen = math.min(lenPrev, lenNext)
	local radius = (turnAngle > 0.001) and (segLen / (2 * math.sin(turnAngle / 2))) or math.huge

	return radius, prev, nxt
end

-- El extremo de una ruta abierta con una aguja no se puede mover (ahí está
-- anclada la aguja), así que EnforceMinRadius no puede ensancharlo empujando
-- el propio punto como hace con los interiores. En su lugar, esta función
-- mide el giro REAL entre la dirección de llegada por la aguja (el vecino de
-- la ruta activa al otro lado, ver GetWPCrossSwitch) y el primer/último tramo
-- propio de esta ruta, y si es demasiado cerrado reubica el waypoint
-- siguiente/anterior hacia esa dirección — repartiendo el giro sobre ese
-- tramo en vez de dejarlo pegado al ángulo con el que se colocó a mano.
local function RelaxSwitchJunction(routeId, wps, atEnd, minRadius, iterations)
	local n = #wps
	if (n < 2) then return false end

	local endpoint = ix.dresinavia.routeEndpointSwitch[routeId]
	local link = endpoint and endpoint[atEnd and "endSwitch" or "startSwitch"]
	local sw = link and ix.dresinavia.switches[link.switchId]
	if (!sw) then return false end

	local other
	if (link.role == "trunk") then
		other = (sw.state == "B") and sw.branchB or sw.branchA
	else
		other = sw.trunk
	end

	local otherRoute = other and ix.dresinavia.routes[other.routeId]
	if (!otherRoute or #otherRoute.waypoints < 2) then return false end

	local otherWps = otherRoute.waypoints
	local neighborIdx = other.atEnd and (#otherWps - 1) or 2
	local neighbor = otherWps[neighborIdx]
	local neighborXY = Vector(neighbor.x, neighbor.y, 0)

	local anchorIdx = atEnd and n or 1
	local adjIdx = atEnd and (n - 1) or 2
	local anchorXY = Vector(wps[anchorIdx].x, wps[anchorIdx].y, 0)

	-- Dirección de viaje (orientada inicio→fin de esta ruta) con la que se
	-- llega/sale por la aguja.
	local travelDir = atEnd and (neighborXY - anchorXY) or (anchorXY - neighborXY)
	if (travelDir:LengthSqr() < 1) then return false end
	travelDir:Normalize()

	-- El punto ajustable va DESPUÉS del ancla si es el inicio, o ANTES si es el final.
	local expectedDir = atEnd and (travelDir * -1) or travelDir

	local anyMoved = false

	for pass = 1, iterations do
		local adjXY = Vector(wps[adjIdx].x, wps[adjIdx].y, 0)
		local toAdj = adjXY - anchorXY
		local dist = toAdj:Length()
		if (dist < 1) then break end

		local turnAngle = math.acos(math.Clamp(expectedDir:Dot(toAdj / dist), -1, 1))
		local radius = (turnAngle > 0.001) and (dist / (2 * math.sin(turnAngle / 2))) or math.huge
		if (radius >= minRadius) then break end

		local idealXY = anchorXY + expectedDir * dist
		local relaxed = LerpVector(0.35, adjXY, idealXY)

		wps[adjIdx].x, wps[adjIdx].y = relaxed.x, relaxed.y
		anyMoved = true
	end

	return anyMoved
end

-- Ensancha (en horizontal, sin tocar la altura) los tramos donde el giro es
-- más cerrado de lo que ix.dresinavia.vehicleLength permitiría en la
-- realidad: empuja cada waypoint problemático hacia el punto medio de sus
-- vecinos, unas pocas pasadas, hasta que su radio local supere minRadius (o
-- se agoten las iteraciones). Los extremos en sí nunca se mueven (ahí puede
-- estar anclada una aguja), pero si tienen una aguja conectada, el tramo
-- junto al extremo sí se ajusta vía RelaxSwitchJunction para suavizar el
-- empalme con la ruta conectada.
function ix.dresinavia.EnforceMinRadius(routeId, minRadius, iterations)
	local route = ix.dresinavia.routes[routeId]
	if (!route or #route.waypoints < 2) then return 0 end

	local wps = route.waypoints
	local n = #wps
	local loop = route.loop
	minRadius = minRadius or ix.dresinavia.minTurnRadius
	iterations = iterations or 8

	local function IsInterior(i)
		return loop or (i > 1 and i < n)
	end

	local fixedCount = 0
	for i = 1, n do
		if (IsInterior(i) and LocalTurnRadius(wps, i, n, loop) < minRadius) then
			fixedCount = fixedCount + 1
		end
	end

	if (!loop) then
		if (RelaxSwitchJunction(routeId, wps, false, minRadius, iterations)) then
			fixedCount = fixedCount + 1
		end
		if (RelaxSwitchJunction(routeId, wps, true, minRadius, iterations)) then
			fixedCount = fixedCount + 1
		end
	end

	for pass = 1, iterations do
		local anyMoved = false

		for i = 1, n do
			if (IsInterior(i)) then
				local radius, prevXY, nxtXY = LocalTurnRadius(wps, i, n, loop)

				if (radius < minRadius) then
					local curXY = Vector(wps[i].x, wps[i].y, 0)
					local midXY = (prevXY + nxtXY) / 2
					local relaxed = LerpVector(0.35, curXY, midXY)

					wps[i].x, wps[i].y = relaxed.x, relaxed.y
					anyMoved = true
				end
			end
		end

		if (!anyMoved) then break end
	end

	ix.dresinavia.RebuildCache(routeId)

	return fixedCount
end

-- ============================================================
--  Agujas (bifurcaciones)
-- ============================================================

-- Reconstruye el índice [routeId][extremo] → aguja que conecta ahí, a partir
-- de ix.dresinavia.switches. Se llama tras cargar datos o tras cualquier cambio.
function ix.dresinavia.RebuildSwitchIndex()
	ix.dresinavia.routeEndpointSwitch = {}

	local function register(link, switchId, role)
		if (!link) then return end
		ix.dresinavia.routeEndpointSwitch[link.routeId] = ix.dresinavia.routeEndpointSwitch[link.routeId] or {}
		local key = link.atEnd and "endSwitch" or "startSwitch"
		ix.dresinavia.routeEndpointSwitch[link.routeId][key] = {switchId = switchId, role = role}
	end

	for switchId, sw in pairs(ix.dresinavia.switches) do
		register(sw.trunk, switchId, "trunk")
		register(sw.branchA, switchId, "branchA")
		register(sw.branchB, switchId, "branchB")
	end
end

-- ¿A qué extremo de una ruta cae `pos` (false=inicio, true=fin)? nil si
-- ningún extremo está dentro de ix.dresinavia.switchEndpointTolerance.
local function FindNearestRouteEnd(routeId, pos)
	local route = ix.dresinavia.routes[routeId]
	if (!route or #route.waypoints == 0) then return nil end

	local wps = route.waypoints
	local startPos = Vector(wps[1].x, wps[1].y, wps[1].z)
	local endPos = Vector(wps[#wps].x, wps[#wps].y, wps[#wps].z)

	local dStart = startPos:Distance(pos)
	local dEnd = endPos:Distance(pos)
	local tol = ix.dresinavia.switchEndpointTolerance

	if (dStart > tol and dEnd > tol) then return nil end

	return dEnd < dStart
end

local function NextFreeSwitchID()
	local maxID = 0
	for id in pairs(ix.dresinavia.switches) do
		if (id > maxID) then maxID = id end
	end
	return maxID + 1
end

-- Crea una aguja en pos/ang conectando 3 rutas por el extremo de cada una más
-- cercano a pos (tolerancia ix.dresinavia.switchEndpointTolerance).
-- Devuelve true, id si tuvo éxito; false, motivo si alguna ruta no tiene
-- ningún extremo cerca de pos.
function ix.dresinavia.CreateSwitch(pos, ang, trunkId, branchAId, branchBId)
	if (!ix.dresinavia.routes[trunkId]) then return false, "La ruta tronco '" .. trunkId .. "' no existe." end
	if (!ix.dresinavia.routes[branchAId]) then return false, "La rama A '" .. branchAId .. "' no existe." end
	if (!ix.dresinavia.routes[branchBId]) then return false, "La rama B '" .. branchBId .. "' no existe." end

	local trunkEnd = FindNearestRouteEnd(trunkId, pos)
	local branchAEnd = FindNearestRouteEnd(branchAId, pos)
	local branchBEnd = FindNearestRouteEnd(branchBId, pos)

	if (trunkEnd == nil) then return false, "No hay ningún extremo de la ruta tronco '" .. trunkId .. "' cerca de tu posición." end
	if (branchAEnd == nil) then return false, "No hay ningún extremo de la rama A '" .. branchAId .. "' cerca de tu posición." end
	if (branchBEnd == nil) then return false, "No hay ningún extremo de la rama B '" .. branchBId .. "' cerca de tu posición." end

	local id = NextFreeSwitchID()
	ix.dresinavia.switches[id] = {
		pos = {x = pos.x, y = pos.y, z = pos.z},
		ang = {p = ang.p, y = ang.y, r = ang.r},
		trunk = {routeId = trunkId, atEnd = trunkEnd},
		branchA = {routeId = branchAId, atEnd = branchAEnd},
		branchB = {routeId = branchBId, atEnd = branchBEnd},
		state = "A",
	}

	ix.dresinavia.RebuildSwitchIndex()
	ix.dresinavia.SpawnSwitchEntities(id)

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then plugin:SaveData() end

	return true, id
end

function ix.dresinavia.RemoveSwitchEntities(id)
	local group = ix.dresinavia.switchEnts[id]
	if (!group) then return end

	if (IsValid(group.base)) then group.base:Remove() end
	if (IsValid(group.lever)) then group.lever:Remove() end

	ix.dresinavia.switchEnts[id] = nil
end

function ix.dresinavia.RemoveSwitch(id)
	if (!ix.dresinavia.switches[id]) then return false end

	ix.dresinavia.RemoveSwitchEntities(id)
	ix.dresinavia.switches[id] = nil
	ix.dresinavia.RebuildSwitchIndex()

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then plugin:SaveData() end

	return true
end

-- Reposiciona una aguja ya creada (solo la posición física, mantiene ángulo
-- y qué rutas conecta) — para afinarla con el clic derecho de /DresinaViaWP
-- sin tener que borrarla y volver a crearla con /DresinaSwitchCrear.
function ix.dresinavia.MoveSwitch(id, newPos)
	local sw = ix.dresinavia.switches[id]
	if (!sw) then return false end

	sw.pos = {x = newPos.x, y = newPos.y, z = newPos.z}
	ix.dresinavia.SpawnSwitchEntities(id)

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then plugin:SaveData() end

	return true
end

function ix.dresinavia.SpawnSwitchEntities(id)
	ix.dresinavia.RemoveSwitchEntities(id)

	local sw = ix.dresinavia.switches[id]
	if (!sw) then return end

	local pos = Vector(sw.pos.x, sw.pos.y, sw.pos.z)
	local ang = Angle(sw.ang.p, sw.ang.y, sw.ang.r)

	-- Base: solo decorativa, prop_dynamic estándar, sin interacción.
	local base = ents.Create("prop_dynamic")
	local baseValid = IsValid(base)
	if (baseValid) then
		base:SetModel("models/props_wasteland/tram_leverbase01.mdl")
		base:SetPos(pos)
		base:SetAngles(ang)
		base:Spawn()
		base:SetMoveType(MOVETYPE_NONE)
		base:SetSolid(SOLID_VPHYSICS)
	end

	-- Palanca: entidad custom usable que gira según el estado de la aguja.
	local lever = ents.Create("ix_dresina_lever")
	local leverValid = IsValid(lever)
	if (leverValid) then
		lever:SetPos(pos)
		lever:SetAngles(ang)
		lever.switchId = id
		lever:Spawn()
	end

	ix.dresinavia.switchEnts[id] = {base = baseValid and base or nil, lever = leverValid and lever or nil}

	if (leverValid) then
		ix.dresinavia.ApplySwitchAngle(id)
	end
end

-- Ángulo base de la aguja + inclinación (pitch/yaw/roll, ix.config) si está
-- en la rama B — pitch por defecto, para que parezca que se tira de la
-- palanca en vez de que gira sobre sí misma en el sitio.
function ix.dresinavia.ApplySwitchAngle(id)
	local sw = ix.dresinavia.switches[id]
	local group = ix.dresinavia.switchEnts[id]
	if (!sw or !group or !IsValid(group.lever)) then return end

	local ang = Angle(sw.ang.p, sw.ang.y, sw.ang.r)
	if (sw.state == "B") then
		ang.p = ang.p + ix.config.Get("dresinaLeverOffsetPitch", ix.dresinavia.switchLeverAngleOffset)
		ang.y = ang.y + ix.config.Get("dresinaLeverOffsetYaw", 0)
		ang.r = ang.r + ix.config.Get("dresinaLeverOffsetRoll", 0)
	end

	group.lever:SetAngles(ang)
end

-- Cambia el estado de una aguja (llamado al usar la palanca en el mundo)
function ix.dresinavia.ToggleSwitch(id, activator)
	local sw = ix.dresinavia.switches[id]
	if (!sw) then return end

	sw.state = (sw.state == "A") and "B" or "A"
	ix.dresinavia.ApplySwitchAngle(id)

	if (IsValid(activator)) then
		activator:EmitSound("buttons/lever1.wav", 70, 100)
		activator:Notify(("Aguja #%i cambiada a la rama %s."):format(id, sw.state))
	end

	local plugin = ix.plugin.Get("dresina_via")
	if (plugin) then plugin:SaveData() end
end

-- ============================================================
--  Enganche a las funciones/hooks del addon original
-- ============================================================

local function SetupHooks()
	if (!isfunction(MHCCreate) or !isfunction(MHCSetPassengerTable)) then
		print("[Vía de Draisina] No se encontraron MHCCreate/MHCSetPassengerTable (addon 'CBH's Metro Dresine' inactivo?). El plugin no se activará.")
		return false
	end

	local vehData = list.Get("Vehicles")[ix.dresinavia.vehicleListName]
	if (!vehData) then
		print("[Vía de Draisina] No se encontró el vehículo '" .. ix.dresinavia.vehicleListName .. "' en list.Get(\"Vehicles\"). El plugin no se activará.")
		return false
	end

	-- Modelo original del addon (ya resuelto por el addon según el mapa: ancho
	-- o estrecho) + todos los modelos extra registrados en sh_plugin.lua.
	local validModels = {[vehData.Model] = true}
	for _, info in ipairs(ix.dresinavia.extraModels) do
		validModels[info.model] = true
	end

	hook.Remove("PlayerSpawnedVehicle", "MHCSpawnVehicle")
	hook.Remove("Tick", "MHCLoop")
	hook.Remove("KeyPress", "MHCKeyPress")
	hook.Remove("EntityRemoved", "MHCRemoveVehicle")

	return true, vehData, validModels
end

local hooksReady, vehData, validModels = SetupHooks()

-- ── Atropello ──────────────────────────────────────────────────────────────
-- El movimiento es cinemático (MOVETYPE_NONE + EnableMotion(false)), así que
-- nunca genera daño de física real al chocar con un jugador: sin esto, la
-- draisina simplemente atraviesa a cualquiera que se ponga en su camino.
local RUNOVER_RADIUS     = 70
local RUNOVER_MIN_SPEED  = 40   -- u/s por debajo de esto no hace daño (toque suave/parado)
local RUNOVER_COOLDOWN   = 1    -- segundos antes de poder volver a golpear a la misma víctima
local RUNOVER_DAMAGE_MIN = 5
local RUNOVER_DAMAGE_MAX = 60

if (hooksReady) then

	-- ============================================================
	--  Maniquí sentado — sustituye visualmente al jugador mientras va
	--  sentado en la draisina. Entity:SetAngles() no tiene ningún efecto
	--  visual en la clase Player (confirmado repetidas veces): el cuerpo del
	--  jugador nunca gira con la draisina en las curvas por mucho que se le
	--  fije el ángulo. Un prop_dynamic normal, en cambio, SÍ gira con
	--  SetParent sin ningún truco — así que se clona el modelo del jugador en
	--  un prop parenteado al asiento (gira solo, gratis), se oculta al
	--  jugador real (SetNoDraw) y se reenvía al jugador cualquier daño que
	--  reciba el maniquí (ver EntityTakeDamage más abajo).
	-- ============================================================

	local function CreatePlayerReplica(client, parentProp, yawOffset)
		local replica = ents.Create("prop_dynamic")
		if (!IsValid(replica)) then return NULL end

		replica:SetModel(client:GetModel())
		replica:Spawn()

		-- Mismo aspecto que el jugador: bodygroups, skin, materiales, color
		-- (mismo patrón que Legs.lua usa para su propio clon de piernas).
		for _, v in pairs(client:GetBodyGroups()) do
			replica:SetBodygroup(v.id, client:GetBodygroup(v.id))
		end
		for k = 1, #client:GetMaterials() do
			replica:SetSubMaterial(k - 1, client:GetSubMaterial(k - 1))
		end
		replica:SetSkin(client:GetSkin())
		replica:SetColor(client:GetColor())

		replica:SetParent(parentProp)
		replica:SetLocalPos(Vector(0, 0, ix.dresinavia.seatHeightOffset))
		replica:SetLocalAngles(Angle(0, yawOffset, 0))
		replica:SetMoveType(MOVETYPE_NONE)
		replica:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local seq = replica:SelectWeightedSequence(ACT_GMOD_SIT_ROLLERCOASTER)
		if (seq and seq > 0) then
			replica:ResetSequence(seq)
			replica:SetPlaybackRate(1)
		end

		-- Health propia solo para que el motor considere al maniquí "dañable"
		-- (EntityTakeDamage no llega a disparar en algunos props sin salud);
		-- el daño real nunca lo sufre él, se reenvía siempre al jugador.
		replica:SetHealth(1)
		replica:SetMaxHealth(1)
		replica.ixDresinaOwner = client

		return replica
	end

	-- Reenvía al jugador cualquier daño recibido por su maniquí (el jugador
	-- real está invisible pero sigue siendo la entidad que de verdad importa).
	hook.Add("EntityTakeDamage", "DresinaVia_ReplicaDamage", function(target, dmgInfo)
		local owner = target.ixDresinaOwner
		if (!IsValid(owner)) then return end

		owner:TakeDamageInfo(dmgInfo)
		return true
	end)

	-- ============================================================
	--  Spawn: crea los mismos props hijos que el addon original
	--  (mismos argumentos exactos a MHCCreate que MHCSpawnVehicle,
	--  líneas 90-98 del addon), pero deshabilita la física del
	--  cuerpo principal: el movimiento pasa a ser cinemático.
	-- ============================================================

	-- Crea los props hijos (ruedas/palancas/asientos), desactiva la física real
	-- y registra el vehículo en ix.dresinavia.active. Extraído a función propia
	-- (antes vivía solo dentro del hook PlayerSpawnedVehicle) para poder
	-- reutilizarlo desde ix.dresinavia.SpawnNPCDresina, que crea la draisina
	-- por comando en vez de por PlayerSpawnedVehicle (no hay ningún ply real
	-- "entrando" al vehículo).
	local function SetupDresinaVehicle(veh, routeId)
		local props = {}
		props[0] = MHCCreate("prop_dynamic", "models/wheel/whc.mdl", veh, Vector(56, 0, 12), Angle(0, 0, 0), COLLISION_GROUP_NONE, 1, 0)
		props[1] = MHCCreate("prop_dynamic", "models/wheel/whc.mdl", veh, Vector(-57, 0, 12), Angle(0, 0, 0), COLLISION_GROUP_NONE, 1, 0)
		props[2] = MHCCreate("prop_dynamic", "models/lever/mhclever.mdl", veh, Vector(-.175, -7, 42.8), Angle(-10, 180, 0), COLLISION_GROUP_NONE, 1.25, 0)
		props[3] = MHCCreate("prop_dynamic", "models/lever/mhclever.mdl", veh, Vector(-.175, 7, 42.8), Angle(-10, 0, 0), COLLISION_GROUP_NONE, 1.25, 0)
		props[5] = MHCCreate("prop_dynamic", "models/hunter/blocks/cube025x025x025.mdl", veh, Vector(50, -20, 20), Angle(0, 90, 0), COLLISION_GROUP_IN_VEHICLE, .01, 10)
		props[6] = MHCCreate("prop_dynamic", "models/hunter/blocks/cube025x025x025.mdl", veh, Vector(50, 20, 20), Angle(0, 90, 0), COLLISION_GROUP_IN_VEHICLE, .01, 10)
		props[7] = MHCCreate("prop_dynamic", "models/hunter/blocks/cube025x025x025.mdl", veh, Vector(-50, -20, 20), Angle(0, -90, 0), COLLISION_GROUP_IN_VEHICLE, .01, 10)
		props[8] = MHCCreate("prop_dynamic", "models/hunter/blocks/cube025x025x025.mdl", veh, Vector(-50, 20, 20), Angle(0, -90, 0), COLLISION_GROUP_IN_VEHICLE, .01, 10)

		veh:SetMoveType(MOVETYPE_NONE)
		local phys = veh:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion(false)
		end

		local data = {
			veh = veh,
			routeId = routeId,
			pathDist = ix.dresinavia.GetClosestDistance(routeId, veh:GetPos()),
			speed = 0,
			approachSign = 1, -- 1 = avanzar aumenta pathDist; -1 tras entrar a una ruta por su extremo "fin" en una aguja
			props = props,
			point = veh:LocalToWorld(Vector(10, 0, 0)),
			passengers = {[0] = NULL, [1] = NULL, [2] = NULL, [3] = NULL},
			lastHit = {}, -- [jugador] = CurTime() a partir del cual puede volver a recibir daño de atropello
		}

		ix.dresinavia.active[veh] = data

		-- Sonidos de rodadura: iguales que el original pero leyendo nuestra
		-- velocidad cinemática (u/s) en vez de la velocidad física real.
		timer.Create("DV_Sound2_" .. veh:EntIndex(), 2, 0, function()
			local d = IsValid(veh) and ix.dresinavia.active[veh]
			if (d and math.abs(d.speed) > ix.dresinavia.maxSpeed * 0.5) then
				local spd = math.abs(d.speed)
				veh:EmitSound("mhc/mhctrackglide_2.wav", math.Clamp(56 + spd / 20, 54, 68), math.Clamp(150 + spd / 20, 54, 68))
			end
		end)

		timer.Create("DV_Sound1_" .. veh:EntIndex(), 0.85, 0, function()
			local d = IsValid(veh) and ix.dresinavia.active[veh]
			if (d and math.abs(d.speed) > 15) then
				local spd = math.abs(d.speed)
				veh:EmitSound("mhc/mhctrackglide_1.wav", math.Clamp(56 + spd / 20, 54, 68), math.Clamp(90 + spd / 20, 54, 68))
			end
		end)

		return data
	end

	hook.Add("PlayerSpawnedVehicle", "DresinaVia_Spawn", function(ply, veh)
		if (!IsValid(veh) or !validModels[veh:GetModel()]) then return end

		SetupDresinaVehicle(veh, ix.dresinavia.activeRouteId)
	end)

	-- ============================================================
	--  Draisina automática con NPCs (/DresinaNPCViaje)
	--  Crea una draisina que viaja sola (sin piloto) del WP de inicio al WP
	--  final de una ruta ya existente, con hasta 4 NPCs "a bordo" (su posición
	--  se fuerza cada Tick sobre los mismos props de asiento que usan los
	--  jugadores, ver más abajo). Al llegar, se bajan y recuperan su IA normal.
	-- ============================================================

	local DEFAULT_NPC_CLASS = "npc_vj_reich_soldier"
	local RIDER_SEAT_PROPS = {5, 6, 7, 8} -- mismos índices que data.props[seatIdx + 5] de los pasajeros jugadores

	-- Pool genérico de armas VJ "Redux" ya usadas en este server (mismo listado
	-- que NPC_DEFAULT_WEAPONS en plugins/npc_presets/sv_plugin.lua para las
	-- clases "soldier"). Se usa cuando /DresinaNPCViaje no recibe "arma", para
	-- que cada NPC salga armado con algo aleatorio sin tener que escribir la
	-- lista a mano cada vez.
	local DEFAULT_WEAPON_POOL = {
		"weapon_vj_aks74uredux_att", "weapon_vj_aks74uredux", "weapon_vj_saigaredux_att",
		"weapon_vj_saigaredux", "weapon_vj_ak74redux", "weapon_vj_ubludokredux",
		"weapon_vj_uboynikredux", "weapon_vj_ak74redux_att", "weapon_vj_ak74redux_att2",
		"weapon_vj_ubludokredux_att", "weapon_vj_uboynikredux_att", "weapon_vj_vsv",
		"weapon_vj_vsv_att", "weapon_vj_uboynikredux_att2", "weapon_vj_dupletredux",
		"weapon_vj_dupletredux_att",
	}

	-- Deja a los NPCs en el suelo alrededor de la draisina y les devuelve su IA
	-- normal (colisión y velocidad de movimiento originales, sin horario forzado).
	function ix.dresinavia.DisembarkRiders(veh, data)
		if (!data.riders) then return end

		local vehAng = IsValid(veh) and veh:GetAngles() or angle_zero
		local vehPos = IsValid(veh) and veh:GetPos() or nil

		-- Offsets generosos: el chasis mide ~115u de largo (ver
		-- ix.dresinavia.vehicleLength) y el tablero sobresale bastante en
		-- lateral — con solo 40u el punto de caída seguía cayendo sobre el
		-- propio tablero en vez de en el suelo junto a la vía.
		local sideOffsets = {{90, -70}, {90, 70}, {-90, -70}, {-90, 70}}

		-- El trace de "aterrizaje" debe ignorar el vehículo Y todos sus props
		-- (ruedas, palancas, asientos): sin esto, si el offset aún cae sobre el
		-- tablero, el trace lo detecta como "suelo" y el NPC se queda de pie
		-- encima de la draisina en vez de bajar a tierra.
		local ignoreList = {veh}
		if (data.props) then
			for _, prop in pairs(data.props) do
				if (IsValid(prop)) then table.insert(ignoreList, prop) end
			end
		end

		for i, rider in ipairs(data.riders) do
			if (IsValid(rider)) then
				-- Si el vehículo ya no existe (se eliminó a media ruta, ver
				-- EntityRemoved), no hay desde dónde calcular el offset lateral —
				-- se usa la propia posición forzada del NPC en el último Tick como
				-- base del trace, para que caiga al suelo en vez de quedarse
				-- flotando donde estuviera montado.
				local dropPos = rider:GetPos()
				if (vehPos) then
					local off = sideOffsets[i] or {0, 0}
					dropPos = vehPos + vehAng:Forward() * off[1] + vehAng:Right() * off[2]
				end

				local riderFilter = table.Copy(ignoreList)
				table.insert(riderFilter, rider)

				local tr = util.TraceLine({
					start = dropPos + Vector(0, 0, 64),
					endpos = dropPos - Vector(0, 0, 128),
					filter = riderFilter,
				})
				rider:SetPos(tr.Hit and (tr.HitPos + Vector(0, 0, 2)) or dropPos)
				rider:SetAngles(vehAng)

				rider:SetMoveType(MOVETYPE_STEP)
				rider:SetCollisionGroup(rider.ixDresinaOldCollision or COLLISION_GROUP_NONE)
				rider:SetSchedule(SCHED_NONE)

				rider.ixDresinaOldCollision = nil
				rider.ixDresinaRiding = nil
				rider.ixDresinaSeatIdx = nil
			end
		end

		data.riders = nil

		local owner = data.autopilot and data.autopilot.ownerClient
		if (IsValid(owner)) then
			owner:Notify("La draisina automática ha llegado a su destino y los NPCs han desembarcado.")
		end
	end

	-- Crea la draisina + 4 NPCs, todo en el WP de inicio, y la programa para
	-- viajar en automático (sin piloto) hasta el WP final de la misma ruta.
	-- Devuelve true, veh si todo fue bien; false, motivo si algo no encaja.
	function ix.dresinavia.SpawnNPCDresina(client, wpInicio, wpFinal, npcClass, npcWeapon, routeId)
		routeId = (routeId and routeId != "") and routeId or ix.dresinavia.activeRouteId
		npcClass = (npcClass and npcClass != "") and npcClass or DEFAULT_NPC_CLASS

		-- "arma" admite una lista separada por comas ("armaA,armaB,armaC"): cada
		-- uno de los 4 NPCs elige una al azar de ese pool, de forma independiente.
		-- Sin "arma", se usa DEFAULT_WEAPON_POOL (mismo criterio, pero sin tener
		-- que escribirlo cada vez) — así siempre salen armados con algo random.
		local weaponPool = DEFAULT_WEAPON_POOL
		if (npcWeapon and npcWeapon != "") then
			weaponPool = {}
			for w in string.gmatch(npcWeapon, "[^,]+") do
				w = string.Trim(w)
				if (w != "") then table.insert(weaponPool, w) end
			end
			if (#weaponPool == 0) then weaponPool = DEFAULT_WEAPON_POOL end
		end

		local route = ix.dresinavia.routes[routeId]
		local cum = ix.dresinavia.cumDist[routeId]
		if (!route or !cum or #route.waypoints < 2) then
			return false, ("La ruta '%s' no existe o necesita al menos 2 waypoints."):format(routeId)
		end

		local wps = route.waypoints
		wpInicio = math.floor(tonumber(wpInicio) or 0)
		wpFinal = math.floor(tonumber(wpFinal) or 0)

		if (!wps[wpInicio]) then
			return false, ("No existe el waypoint #%i en la ruta '%s' (tiene %i)."):format(wpInicio, routeId, #wps)
		end
		if (!wps[wpFinal]) then
			return false, ("No existe el waypoint #%i en la ruta '%s' (tiene %i)."):format(wpFinal, routeId, #wps)
		end
		if (wpInicio == wpFinal) then
			return false, "El waypoint de inicio y el de final no pueden ser el mismo."
		end

		-- list.Get("NPC") y scripted_ents.GetStored() pueden devolver nil (no un
		-- table vacío) según la versión/entorno — sin el "or {}" indexarlos
		-- crashea en vez de simplemente no encontrar la clase.
		local npcList = list.Get("NPC") or {}
		local stored = scripted_ents.GetStored() or scripted_ents.GetList() or {}
		if (!stored[npcClass] and !npcList[npcClass]) then
			return false, "Clase de NPC no reconocida: " .. npcClass
		end

		local startDist, endDist = cum[wpInicio], cum[wpFinal]

		local pos, ang = ix.dresinavia.GetPosAng(routeId, startDist)
		if (!pos) then
			return false, "No se pudo calcular la posición del waypoint de inicio."
		end

		local veh = ents.Create(vehData.Class)
		if (!IsValid(veh)) then
			return false, "No se pudo crear el vehículo de la draisina (" .. tostring(vehData.Class) .. ")."
		end

		veh:SetModel(vehData.Model)
		veh:SetPos(pos + Vector(0, 0, ix.dresinavia.heightOffset))
		veh:SetAngles(ang)
		veh:Spawn()
		veh:Activate()

		local data = SetupDresinaVehicle(veh, routeId)
		data.pathDist = startDist -- fuerza el WP exacto (GetClosestDistance puede caer ligeramente al lado)

		data.autopilot = {
			targetDist = endDist,
			wpFinal = wpFinal,
			ownerClient = IsValid(client) and client or nil,
			arrived = false,
		}

		data.riders = {}

		for i = 1, 4 do
			local npc = ents.Create(npcClass)
			if (IsValid(npc)) then
				-- Igual que hace npc_presets (NPC_DEFAULT_WEAPONS): un VJ Base NPC
				-- creado a pelo con ents.Create no se equipa solo. La keyvalue
				-- "additionalequipment" hay que fijarla ANTES de Spawn(). Cada NPC
				-- tira su propio math.random contra el pool, así que pueden salir
				-- 4 armas distintas del mismo /DresinaNPCViaje.
				if (weaponPool) then
					npc:SetKeyValue("additionalequipment", weaponPool[math.random(#weaponPool)])
				end

				npc:SetPos(pos)
				npc:SetAngles(ang)
				npc:Spawn()
				npc:Activate()

				npc.ixDresinaRiding = true
				npc.ixDresinaSeatIdx = RIDER_SEAT_PROPS[i]
				npc.ixDresinaOldCollision = npc:GetCollisionGroup()

				npc:SetMoveType(MOVETYPE_NONE)
				npc:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				npc:SetSchedule(SCHED_IDLE_STAND)

				table.insert(data.riders, npc)
			end
		end

		if (IsValid(client)) then
			client:Notify(("Draisina automática creada: ruta '%s', WP #%i → WP #%i (%i NPC(s) a bordo)."):format(routeId, wpInicio, wpFinal, #data.riders))
		end

		return true, veh
	end

	-- Al llegar al extremo de una ruta abierta, si hay una aguja conectada ahí
	-- (ver ix.dresinavia.routeEndpointSwitch), continúa en la rama/tronco
	-- correspondiente en vez de frenar en seco. Muta `data` en el sitio.
	-- Devuelve true si hizo la transición, false si no había ninguna aguja.
	local function TryAdvanceThroughSwitch(data, atEnd)
		local endpoint = ix.dresinavia.routeEndpointSwitch[data.routeId]
		local link = endpoint and endpoint[atEnd and "endSwitch" or "startSwitch"]
		if (!link) then return false end

		local sw = ix.dresinavia.switches[link.switchId]
		if (!sw) then return false end

		local nextLink
		if (link.role == "trunk") then
			nextLink = (sw.state == "A") and sw.branchA or sw.branchB
		else
			-- Se viene de una rama (A o B): siempre vuelve al tronco, sea cual
			-- sea la posición actual de la palanca (ya está comprometido).
			nextLink = sw.trunk
		end

		local nextRoute = ix.dresinavia.routes[nextLink.routeId]
		if (!nextRoute) then return false end

		data.routeId = nextLink.routeId

		local nextCum = ix.dresinavia.cumDist[nextLink.routeId]
		local nextTotal = (nextCum and #nextRoute.waypoints > 0) and nextCum[#nextRoute.waypoints] or 0

		-- El signo de approachSign no se puede fijar en absoluto según el
		-- extremo de entrada: hace falta saber TAMBIÉN por qué extremo se salió
		-- de la ruta anterior. Si se entra y se sale por el "mismo tipo" de
		-- extremo (fin→fin o inicio→inicio) las dos rutas quedan invertidas
		-- entre sí en el punto de unión y el signo se voltea; si son de tipo
		-- distinto (fin→inicio o inicio→fin) se mantiene igual. Con un valor
		-- absoluto, volver de una rama al tronco (inicio→fin) dejaba el signo
		-- apuntando hacia la propia aguja: con la tecla de retroceso mantenida,
		-- pathDist se recolocaba justo encima del límite que acababa de cruzar
		-- y la aguja se volvía a disparar el mismo tick, en bucle infinito —
		-- la draisina se quedaba fija oscilando en el punto de unión.
		if (atEnd == nextLink.atEnd) then
			data.approachSign = -data.approachSign
		end

		if (nextLink.atEnd) then
			data.pathDist = nextTotal
		else
			data.pathDist = 0
		end

		return true
	end

	-- ============================================================
	--  Tick: mueve la draisina a lo largo del camino y reproduce
	--  la animación de ruedas/palancas (igual que MHCLoop original,
	--  sustituyendo AddVelocity por interpolación sobre waypoints).
	-- ============================================================

	hook.Add("Tick", "DresinaVia_Tick", function()
		for veh, data in pairs(ix.dresinavia.active) do
			if (!IsValid(veh)) then
				ix.dresinavia.active[veh] = nil
				continue
			end

			-- Entrada: asientos 1 y 2 son los de conducción (igual que el original)
			local netInput = 0
			local driving = {[1] = false, [2] = false}

			-- ply:Alive() es imprescindible aquí: KeyDown sigue devolviendo el estado
			-- real de las teclas aunque el jugador esté muerto, así que sin este
			-- chequeo un piloto muerto seguía "conduciendo" la draisina.
			for _, seatIdx in ipairs({1, 2}) do
				local ply = data.passengers[seatIdx]
				if (IsValid(ply) and ply != NULL and ply:Alive()) then
					local fwd = ply:KeyDown(IN_FORWARD)
					local back = ply:KeyDown(IN_BACK)
					if (fwd) then netInput = netInput + 1 end
					if (back) then netInput = netInput - 1 end
					driving[seatIdx] = fwd or back
				end
			end
			netInput = math.Clamp(netInput, -1, 1)

			-- Piloto automático (/DresinaNPCViaje): sin pasajero real conduciendo,
			-- avanza sola hacia data.autopilot.targetDist y frena a tiempo usando
			-- la misma desaceleración (brake) que un jugador soltando la marcha,
			-- para no pasarse del WP final de golpe. Si un jugador real consigue
			-- ocupar un asiento de conducción (p. ej. porque el rider de ese
			-- asiento murió y liberó el hueco) y pulsa W/S, su input manda: sin
			-- este chequeo, el bloque de abajo lo pisaba sin avisar y el jugador
			-- nunca podía tomar el control.
			if (data.autopilot and !data.autopilot.arrived and !driving[1] and !driving[2]) then
				local remaining = data.autopilot.targetDist - data.pathDist
				local dir = (remaining > 0) and 1 or ((remaining < 0) and -1 or 0)
				local stopDist = (data.speed * data.speed) / (2 * ix.dresinavia.brake)

				if (dir != 0 and math.abs(remaining) > stopDist + 5) then
					netInput = dir
				else
					netInput = 0
				end
			end

			local target = netInput * ix.dresinavia.maxSpeed
			local rate = (target == 0) and ix.dresinavia.brake or ix.dresinavia.accel
			data.speed = math.Approach(data.speed, target, rate * FrameTime())

			local route = ix.dresinavia.routes[data.routeId]
			local cum = ix.dresinavia.cumDist[data.routeId]
			local total = (route and cum and #route.waypoints > 0) and cum[#route.waypoints] or 0

			if (total > 0) then
				local oldRouteId, oldPathDist, oldApproachSign = data.routeId, data.pathDist, data.approachSign

				data.pathDist = data.pathDist + data.speed * data.approachSign * FrameTime()

				if (!route.loop) then
					if (data.pathDist >= total) then
						if (!TryAdvanceThroughSwitch(data, true)) then
							data.pathDist = total
							data.speed = 0
						end
					elseif (data.pathDist <= 0) then
						if (!TryAdvanceThroughSwitch(data, false)) then
							data.pathDist = 0
							data.speed = 0
						end
					end
				end

				local pos, ang = ix.dresinavia.GetPosAng(data.routeId, data.pathDist)
				if (pos) then
					-- Choque contra props/puertas: la draisina se mueve por
					-- SetPos cinemático (sin física propia), así que sin esto
					-- atraviesa cualquier cosa sólida en la vía. TraceHull entre
					-- la posición actual y la nueva, ignorando sus propios props/
					-- pasajeros/maniquíes; !tr.HitWorld para no chocar contra el
					-- propio túnel (las paredes del mapa no deben frenarla, solo
					-- entidades — props, puertas, otra draisina...).
					local filterList = {veh}
					for _, prop in pairs(data.props) do
						if (IsValid(prop)) then table.insert(filterList, prop) end
					end
					for seatIdx = 0, 3 do
						local passenger = data.passengers[seatIdx]
						if (IsValid(passenger) and passenger != NULL) then
							table.insert(filterList, passenger)
							if (IsValid(passenger.ixDresinaReplica)) then
								table.insert(filterList, passenger.ixDresinaReplica)
							end
						end
					end
					if (data.riders) then
						for _, rider in ipairs(data.riders) do
							if (IsValid(rider)) then table.insert(filterList, rider) end
						end
					end

					local tr = util.TraceHull({
						start = veh:GetPos(),
						endpos = pos + Vector(0, 0, ix.dresinavia.heightOffset),
						mins = Vector(-60, -30, 0),
						maxs = Vector(60, 30, 60),
						filter = filterList,
						mask = MASK_SOLID,
					})

					if (tr.Hit and !tr.HitWorld) then
						data.routeId, data.pathDist, data.approachSign = oldRouteId, oldPathDist, oldApproachSign
						data.speed = 0
					else
						veh:SetPos(pos + Vector(0, 0, ix.dresinavia.heightOffset))
						veh:SetAngles(ang)
					end
				end
			end

			-- Llegada del piloto automático: el margen de frenada de arriba
			-- (stopDist + 5) hace que la draisina se quede parada para siempre a
			-- ~5u del WP final sin llegar nunca a acelerar de nuevo — exigir
			-- ADEMÁS velocidad casi nula (como se hacía antes) nunca se cumplía a
			-- la vez que la distancia, y la llegada no se disparaba jamás. Basta
			-- con la proximidad de posición (con margen holgado, 10u) para dar
			-- por llegada y frenar en seco, sin depender de la velocidad.
			if (data.autopilot and !data.autopilot.arrived) then
				if (math.abs(data.pathDist - data.autopilot.targetDist) < 10) then
					data.pathDist = data.autopilot.targetDist
					data.speed = 0
					data.autopilot.arrived = true
					ix.dresinavia.DisembarkRiders(veh, data)
				end
			end

			-- Atropello: a velocidad significativa, cualquier jugador vivo que no
			-- vaya montado y quede dentro del radio del vehículo recibe daño y un
			-- empujón hacia fuera. Cooldown por víctima para no reaplicar el daño en
			-- cada tick mientras siga dentro del radio. ents.FindInSphere en vez de
			-- player.GetAll() para que también alcance a los NPCs (bandidos, mutantes...).
			if (math.abs(data.speed) > RUNOVER_MIN_SPEED) then
				local vehPos = veh:GetPos()

				for _, victim in ipairs(ents.FindInSphere(vehPos, RUNOVER_RADIUS)) do
					if (!IsValid(victim)) then continue end
					if (!victim:IsPlayer() and !victim:IsNPC()) then continue end
					if (victim:Health() <= 0) then continue end

					if (victim == data.passengers[0] or victim == data.passengers[1]
					or victim == data.passengers[2] or victim == data.passengers[3]) then continue end
					if (victim.ixDresinaRiding) then continue end

					local nextHit = data.lastHit[victim] or 0
					if (CurTime() < nextHit) then continue end
					data.lastHit[victim] = CurTime() + RUNOVER_COOLDOWN

					local dmg = math.Clamp(math.abs(data.speed) * 0.15, RUNOVER_DAMAGE_MIN, RUNOVER_DAMAGE_MAX)

					local dmgInfo = DamageInfo()
					dmgInfo:SetDamage(dmg)
					dmgInfo:SetAttacker(veh)
					dmgInfo:SetInflictor(veh)
					dmgInfo:SetDamageType(DMG_VEHICLE)
					dmgInfo:SetDamagePosition(vehPos)
					victim:TakeDamageInfo(dmgInfo)

					if (IsValid(victim)) then
						local away = (victim:GetPos() - vehPos)
						away.z = 0
						away = away:GetNormalized() * 250 + Vector(0, 0, 150)
						victim:SetVelocity(away)
					end
				end
			end

			-- Animación de ruedas/palancas + click de palanca (igual que el original)
			local wheelOne, wheelTwo = data.props[0], data.props[1]
			local leverOne, leverTwo = data.props[3], data.props[2]

			if (IsValid(wheelOne)) then
				local rot = Angle(math.sin(math.rad(wheelOne:GetAngles().x) * .4) * 12 - 10, 0, 0)

				if (rot.x < -16) then
					veh:EmitSound("mhc/mhcleverup.wav", 58, 100)
				end
				if (rot.x > -3) then
					veh:EmitSound("mhc/mhcleverdown.wav", 58, 100)
				end

				if (driving[1] and IsValid(leverOne)) then
					leverOne:SetLocalAngles(rot)
				end
				if (driving[2] and IsValid(leverTwo)) then
					leverTwo:SetLocalAngles(rot + Angle(0, 180, 0))
				end
			end

			if (data.speed != 0 and IsValid(wheelOne) and IsValid(wheelTwo)) then
				local spinRatio = math.Clamp((veh:GetPos():Distance(data.point) - 10) * 130, -1, 1) * (-math.abs(data.speed) / 25)
				wheelOne:SetLocalAngles(Angle(wheelOne:GetLocalAngles().x + spinRatio, 0, 0))
				wheelTwo:SetLocalAngles(Angle(wheelTwo:GetLocalAngles().x + spinRatio, 0, 0))
			end

			data.point = veh:LocalToWorld(Vector(10, 0, 0))

			-- Tabla de pasajeros: de aquí cuelgan (sin tocarlos) MHCBlockBinds,
			-- MHCFixPassengerAngles y MHCFinishMove del addon original.
			--
			-- Los 4 asientos necesitan refresco CONTINUO (no solo al entrar): los
			-- asientos de conducción (1/2) ya lo tenían, pero los de acompañante
			-- (0/3) solo recibían MHCSetPassengerTable una vez al entrar ("idle")
			-- y nunca más — sin este refresco, la pose/viewmodel del pasajero se
			-- perdía tras el primer tick (se quedaba de pie y sin arma/linterna
			-- visibles), igual que los asientos de conducción necesitan que se
			-- les repita "true"/"false" cada tick para no perder su pose.
			for seatIdx = 0, 3 do
				local ply = data.passengers[seatIdx]
				if (IsValid(ply) and ply != NULL) then
					local isDriving = driving[seatIdx] or false
					local state = (seatIdx == 1 or seatIdx == 2) and tostring(isDriving) or "idle"

					ply:DrawViewModel(!isDriving)
					MHCSetPassengerTable(ply, state, true)
				end
			end

			-- NPCs a bordo (/DresinaNPCViaje): sin vehículo real ni parenteo, se
			-- fuerza su posición sobre el prop de asiento cada Tick — mismo truco
			-- "cinemático" que ya usa la propia draisina contra su físca real, para
			-- que se queden pegados pase lo que pase con su IA (VJ Base u otra)
			-- mientras SCHED_IDLE_STAND los mantiene quietos.
			if (data.riders) then
				for _, rider in ipairs(data.riders) do
					if (IsValid(rider)) then
						local seatProp = data.props[rider.ixDresinaSeatIdx]
						if (IsValid(seatProp)) then
							rider:SetPos(seatProp:LocalToWorld(Vector(0, 0, ix.dresinavia.seatHeightOffset)))
							rider:SetAngles(veh:GetAngles())
						end
					end
				end
			end
		end
	end)

	-- ============================================================
	--  KeyPress: entrar/salir y cambiar de asiento. Se elimina el
	--  "empujón" de desatasco del original (FORWARD/BACK) porque un
	--  sistema cinemático no tiene stiction que superar.
	-- ============================================================

	local CONCERNED_KEYS = {IN_USE, IN_JUMP, IN_SPEED}

	-- data.passengers y data.riders (NPCs de /DresinaNPCViaje) comparten el
	-- mismo espacio físico de asientos (data.props[seatIdx + 5]), pero se
	-- comprueban/mutan por separado: sin esto, un jugador podía sentarse
	-- encima de un NPC que la draisina automática sigue forzando cada Tick
	-- sobre ese mismo prop (ver el bloque de riders en el hook Tick).
	local function SeatTakenByRider(data, seatIdx)
		if (!data.riders) then return false end

		for _, rider in ipairs(data.riders) do
			if (IsValid(rider) and rider.ixDresinaSeatIdx == seatIdx + 5) then
				return true
			end
		end

		return false
	end

	local function FindSeatOf(ply)
		for veh, data in pairs(ix.dresinavia.active) do
			for seatIdx = 0, 3 do
				if (data.passengers[seatIdx] == ply) then
					return veh, data, seatIdx
				end
			end
		end
		return nil, nil, nil
	end

	-- Pose sentada forzada: el addon original (CBH's Metro Dresine, Workshop
	-- 3402275761) viene como .gma, así que no podemos leer cómo posicionaba a
	-- los pasajeros — y a juzgar por las pruebas en juego, no lo conseguía para
	-- los 4 asientos. Se usa el mecanismo que el propio Helix trae para esto:
	-- GM:CalcMainActivity (helix/gamemode/core/hooks/sh_hooks.lua) comprueba
	-- client:GetNetVar("forcedSequence") antes que cualquier otra lógica y, si
	-- está puesto, fuerza esa secuencia sin más. SelectWeightedSequence traduce
	-- la actividad ACT_GMOD_SIT_ROLLERCOASTER (la que usa GMod nativamente para
	-- sillas, ver lua/autorun/base_vehicles.lua) al número de secuencia que le
	-- corresponda en el playermodel concreto de cada jugador.
	--
	-- El giro del cuerpo con la cámara/en las curvas es una limitación conocida
	-- y aceptada: en Source el cuerpo de un jugador no se puede fijar con
	-- Entity:SetAngles() bajo ningún MoveType, ni siquiera vía CMoveData:SetAngles()
	-- en Move — probado varias veces. La única forma real es un vehículo de
	-- verdad (ply:EnterVehicle()), pero eso causaba un bug de posicionamiento
	-- (jugador flotando) que no se pudo resolver con garantías; se descarta.
	--
	-- La cámara sigue a EyePos() = origen del jugador + ViewOffset, y ese
	-- ViewOffset es el de estar de pie por defecto (el jugador nunca se agacha
	-- de verdad al sentarse, solo se reposiciona su origen sobre el asiento) —
	-- por eso la vista quedaba a altura de "de pie" en vez de a altura de
	-- sentado. Se guarda el offset original para poder restaurarlo tal cual al
	-- levantarse, en vez de asumir un valor "de pie" fijo.
	-- "dresinaSeatIdx" es lo que lee cl_plugin.lua (CreateMove) para saber qué
	-- config "dresinaSeatYawN" aplicar — cada asiento puede necesitar una
	-- corrección de signo distinta.
	-- Quita (si hay) y limpia la referencia al maniquí, y devuelve la
	-- visibilidad al jugador real. Se lee ply.ixDresinaReplica sin más
	-- chequeo de IsValid(ply) porque hace falta funcionar igual si el
	-- jugador se desconectó mientras estaba sentado (si no, el maniquí se
	-- quedaría flotando en el asiento para siempre).
	local function QuitarMani(ply)
		local replica = ply.ixDresinaReplica
		if (IsValid(replica)) then
			replica:Remove()
		end
		ply.ixDresinaReplica = nil

		if (IsValid(ply)) then
			ply:SetNoDraw(false)
		end
	end

	local function AplicarPoseSentada(ply, seatIdx, parentProp)
		if (!IsValid(ply)) then return end
		ply:SetNetVar("forcedSequence", ply:SelectWeightedSequence(ACT_GMOD_SIT_ROLLERCOASTER))
		ply:SetNetVar("dresinaSeatIdx", seatIdx)

		-- El jugador sigue en MOVETYPE_WALK aunque esté SetParent'eado al asiento
		-- (MHCBlockBinds, reutilizado del addon base, nunca bloquea +forward/+back).
		-- Con W/S mantenido, el motor le aplica su propio WalkMove cada tick ANTES
		-- de que MHCFinishMove le ponga la velocidad a 0 — ese desplazamiento ya
		-- aplicado no se deshace, así que se acumula sin parar mientras se
		-- mantiene la tecla. MOVETYPE_NONE lo deja completamente quieto salvo por
		-- el transform del padre; se restaura a pie (MOVETYPE_WALK) en los 4
		-- puntos de salida del asiento más abajo.
		ply:SetMoveType(MOVETYPE_NONE)

		if (!ply.ixDresinaViewOffset) then
			ply.ixDresinaViewOffset = ply:GetViewOffset()
		end
		local viewHeight = ix.config.Get("dresinaSeatViewHeight", ix.dresinavia.seatedViewOffset)
		ply:SetViewOffset(Vector(0, 0, viewHeight))
		ply:SetViewOffsetDucked(Vector(0, 0, viewHeight))

		-- Maniquí visual: sustituye al jugador (que se vuelve invisible)
		-- porque su propio cuerpo no puede girar con la draisina (ver arriba).
		QuitarMani(ply)
		local yawOffset = ix.config.Get("dresinaSeatYaw" .. seatIdx, 90)
		ply.ixDresinaReplica = CreatePlayerReplica(ply, parentProp, yawOffset)
		ply:SetNoDraw(true)
	end

	local function QuitarPoseSentada(ply)
		if (!IsValid(ply)) then return end
		ply:SetNetVar("forcedSequence", nil)
		ply:SetNetVar("dresinaSeatIdx", nil)

		if (ply.ixDresinaViewOffset) then
			ply:SetViewOffset(ply.ixDresinaViewOffset)
			ply:SetViewOffsetDucked(ply.ixDresinaViewOffset)
			ply.ixDresinaViewOffset = nil
		end

		QuitarMani(ply)
	end

	hook.Add("KeyPress", "DresinaVia_KeyPress", function(ply, key)
		if (!table.HasValue(CONCERNED_KEYS, key)) then return end

		local foundVeh, foundData, foundSeat = FindSeatOf(ply)

		-- Los pasajeros nunca están en un vehículo "de verdad" (van SetParent'eados
		-- a un prop, nunca ply:EnterVehicle()), así que ply:InVehicle() es SIEMPRE
		-- false aquí. Se usa foundVeh (nuestro propio registro de asientos) en su lugar.
		if (key == IN_USE) then
			if (foundVeh) then
				-- SALIDA
				ply:SetParent(nil)
				ply:SetPos(ply:GetPos() + Vector(0, 0, 35))
				ply:SetEyeAngles(Angle(0, 0, 0))
				ply:SetMoveType(MOVETYPE_WALK)
				foundData.passengers[foundSeat] = NULL
				MHCSetPassengerTable(ply, "idle", false)
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
				QuitarPoseSentada(ply)
				return
			end

			local lookAt = ply:GetEyeTrace().Entity

			-- ENTRADA: ¿mira a alguna draisina activa con hueco?
			-- Prioriza los asientos de conducción (1 y 2) sobre los de
			-- acompañante (0 y 3): si no, el primero en entrar a una
			-- draisina vacía cae siempre en un asiento que no mueve nada.
			for veh, data in pairs(ix.dresinavia.active) do
				if (lookAt == veh and ply:GetPos():Distance(veh:GetPos()) < 200) then
					for _, seatIdx in ipairs({1, 2, 0, 3}) do
						if (data.passengers[seatIdx] == NULL and !SeatTakenByRider(data, seatIdx)) then
							if (ply:Crouching()) then
								ply:ConCommand('say "I cant get inside the dresine while crouching..."')
								return
							end

							if (ply:GetMoveType() == MOVETYPE_NOCLIP) then
								ply:SetMoveType(MOVETYPE_WALK)
							end

							data.passengers[seatIdx] = ply
							ply:SetParent(data.props[seatIdx + 5])
							ply:SetLocalPos(Vector(0, 0, ix.dresinavia.seatHeightOffset))
							ply:SetEyeAngles(Angle(0, 0, 0))
							ply:SetCollisionGroup(COLLISION_GROUP_WORLD)

							MHCSetPassengerTable(ply, "idle", true)
							AplicarPoseSentada(ply, seatIdx, data.props[seatIdx + 5])
							return
						end
					end
				end
			end

			return
		end

		if (!foundVeh) then return end

		if (key == IN_JUMP or key == IN_SPEED) then
			-- Rota cíclicamente entre los 4 asientos (0↔3 también rota, no se para
			-- en los extremos). Lua ya normaliza el módulo de números negativos al
			-- rango [0,3], así que sirve igual para ambas direcciones.
			MHCSetPassengerTable(ply, "idle", true)

			local direction = (key == IN_JUMP) and 1 or -1

			for step = 1, 3 do
				local seatIdx = (foundSeat + direction * step) % 4
				if (foundData.passengers[seatIdx] == NULL and !SeatTakenByRider(foundData, seatIdx)) then
					foundData.passengers[foundSeat] = NULL
					foundData.passengers[seatIdx] = ply
					ply:SetParent(foundData.props[seatIdx + 5])
					ply:SetLocalPos(Vector(0, 0, ix.dresinavia.seatHeightOffset))
					AplicarPoseSentada(ply, seatIdx, foundData.props[seatIdx + 5])
					return
				end
			end

			return true
		end
	end)

	-- ============================================================
	--  Limpieza
	-- ============================================================

	hook.Add("EntityRemoved", "DresinaVia_Removed", function(ent)
		local data = ix.dresinavia.active[ent]
		if (!data) then return end

		for seatIdx = 0, 3 do
			local ply = data.passengers[seatIdx]
			if (IsValid(ply) and ply != NULL) then
				ply:ExitVehicle()
				MHCSetPassengerTable(ply, "idle", false)
				ply:SetParent(nil)
				ply:SetMoveType(MOVETYPE_WALK)
				ply:SetEyeAngles(Angle(0, 0, 0))
				QuitarPoseSentada(ply)
			end
		end

		timer.Remove("DV_Sound1_" .. ent:EntIndex())
		timer.Remove("DV_Sound2_" .. ent:EntIndex())

		-- Si la draisina se elimina a mitad de viaje (admin la borra, o
		-- cualquier otra causa) antes de que el piloto automático llegue, los
		-- NPCs a bordo quedarían congelados en MOVETYPE_NONE para siempre sin
		-- esto: se desembarcan igual, aunque no haya vehículo ya en pie.
		if (data.riders) then
			ix.dresinavia.DisembarkRiders(NULL, data)
		end

		ix.dresinavia.active[ent] = nil
	end)

	-- Si el piloto (o cualquier pasajero) muere mientras va montado, se le expulsa
	-- del asiento: el chequeo ply:Alive() del Tick ya le impide seguir "conduciendo"
	-- muerto, pero sin esto seguía parenteado al prop del asiento (glitches visuales/
	-- de cámara) y ocupando el hueco indefinidamente.
	hook.Add("PlayerDeath", "DresinaVia_PlayerDeath", function(ply)
		for veh, data in pairs(ix.dresinavia.active) do
			for seatIdx = 0, 3 do
				if (data.passengers[seatIdx] == ply) then
					data.passengers[seatIdx] = NULL
					ply:SetParent(nil)
					ply:SetMoveType(MOVETYPE_WALK)
					ply:SetEyeAngles(Angle(0, 0, 0))
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					MHCSetPassengerTable(ply, "idle", false)
					QuitarPoseSentada(ply)
				end
			end
		end
	end)

	-- Limpieza defensiva que el addon original no tiene: si un pasajero se
	-- desconecta en pleno viaje, libera su asiento en vez de dejarlo colgado.
	-- QuitarPoseSentada incluye quitar el maniquí: sin esto, el maniquí de un
	-- jugador que se desconecta sentado se quedaría flotando en el asiento
	-- para siempre (nadie más lo limpiaría).
	hook.Add("PlayerDisconnected", "DresinaVia_PlayerDisconnected", function(ply)
		for veh, data in pairs(ix.dresinavia.active) do
			for seatIdx = 0, 3 do
				if (data.passengers[seatIdx] == ply) then
					data.passengers[seatIdx] = NULL
					MHCSetPassengerTable(ply, "idle", false)
					QuitarPoseSentada(ply)
				end
			end
		end
	end)

end
