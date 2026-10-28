-- Cada entrada: {points = {Vector, ...}, loop = bool, color = Color}. Ya no es
-- solo la ruta que se edita: el servidor manda TODAS para poder ver de un
-- vistazo dónde se separan las ramas (cada una en su color).
local routeList = {}
local overlayActive = false

-- plugins/legs.lua clona el modelo del jugador para dibujar sus piernas en
-- primera persona, copiando 1:1 la secuencia actual (GetSequence()) sobre un
-- recorte/offset calibrado para estar de pie. Al forzar la secuencia de
-- "sentado" (forcedSequence, ver AplicarPoseSentada en sv_plugin.lua) ese
-- clon queda con una pose que el recorte no espera, deformando el modelo en
-- un cono gigante. SetParent es exclusivo de este plugin entre los jugadores
-- (ningún otro sistema del schema parentea al jugador), así que sirve como
-- señal fiable de "está sentado en la draisina" sin necesitar un netvar propio.
function PLUGIN:ShouldDisableLegs()
	local client = LocalPlayer()
	return IsValid(client) and IsValid(client:GetParent())
end

-- El bloqueo de vista (yaw fijo al asiento, ver más abajo) pisa el ángulo del
-- jugador CADA TICK — eso es justo lo que rompe la toolgun/cámara de
-- sandbox: en vez de apuntar donde el ratón mueve la vista, se recoloca al
-- rumbo del vagón en el siguiente tick, así que "no enfoca" y da tirones. Las
-- herramientas de sandbox (gmod_tool, gmod_camera, physgun...) necesitan
-- vista libre para apuntar, así que el bloqueo se salta mientras alguna de
-- ellas esté equipada.
local function HasFreeLookTool(client)
	local wep = client:GetActiveWeapon()
	return IsValid(wep) and string.sub(wep:GetClass(), 1, 5) == "gmod_"
end

-- Bloquea la cámara mientras está sentado en la draisina. El ángulo de vista
-- del jugador local es puramente cliente (se calcula del ratón en CreateMove
-- y de ahí se manda al servidor); por eso el body-lock del cuerpo (ver
-- sv_plugin.lua) no sirve para esto y hay que interceptarlo aquí, ANTES de
-- que el motor lo use para ese frame. Se fija al ángulo del prop de asiento
-- (el padre del jugador) cada frame, así gira CON la draisina en las curvas
-- en vez de quedarse mirando a un rumbo fijo del mapa.
-- El ángulo del prop de asiento no está pensado para "hacia dónde mira el
-- jugador": son los cubos de colisión que ya creaba MHCCreate (Angle(0, 90, 0)
-- para los de un extremo, Angle(0, -90, 0) para el otro), orientados a lo
-- que le hiciera falta al addon original, no a la vista del pasajero. Sin
-- corrección, el jugador queda sentado de lado en vez de mirando hacia el
-- centro del vagón. La corrección es POR ASIENTO (ix.config "dresinaSeatYawN",
-- ver sh_plugin.lua) porque no todos necesitan el mismo signo — dresinaSeatIdx
-- lo manda el servidor (AplicarPoseSentada en sv_plugin.lua) al sentarse.
hook.Add("CreateMove", "DresinaVia_LockView", function(cmd)
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local seat = client:GetParent()
	if (!IsValid(seat)) then return end
	if (HasFreeLookTool(client)) then return end

	local seatIdx = client:GetNetVar("dresinaSeatIdx")
	local yawOffset = (seatIdx != nil) and ix.config.Get("dresinaSeatYaw" .. seatIdx, 90) or 90

	-- Solo se fija el yaw (gira con la draisina); el pitch se deja tal cual lo
	-- traiga el comando (el ratón ya lo actualizó antes de llegar aquí), así
	-- se puede seguir mirando arriba/abajo con libertad.
	local ang = seat:GetAngles()
	ang.y = ang.y + yawOffset
	ang.p = cmd:GetViewAngles().p

	cmd:SetViewAngles(ang)

	-- plugins/thirdperson mantiene su PROPIO ángulo de cámara independiente
	-- (client.camAng, solo actualizado por el ratón en su InputMouseApply) y
	-- renderiza desde ahí en vez de EyeAngles — cmd:SetViewAngles no lo toca.
	-- Sin esto, con la tercera persona activada (Bloq Mayús) la cámara se
	-- quedaba congelada mirando a donde fuera al sentarse, mientras el disparo
	-- (que sí usa el ángulo real) apuntaba correctamente hacia delante.
	if (client.camAng) then
		client.camAng = ang
	end
end)

-- CreateMove fija el ángulo "oficial" (el que usan disparo/movimiento), pero
-- solo se actualiza al ritmo de los TICKS de simulación, no de los
-- fotogramas de pantalla — confirmado con logs: EyeAngles() avanzaba a
-- saltos (se quedaba igual varias líneas seguidas) mientras el ángulo
-- objetivo cambiaba de forma continua, dando sensación de "temblor"/desfase
-- en cámara aunque la puntería fuera correcta. CalcView es el hook que
-- decide qué se DIBUJA cada fotograma — con este añadido, la cámara sigue a
-- la draisina con fluidez aunque la simulación vaya a un ritmo más lento.
-- Se cede el paso si thirdperson tiene la vista tomada (CanOverrideView):
-- ese plugin ya recibe nuestro ángulo objetivo vía client.camAng (arriba) y
-- renderiza él mismo.
hook.Add("CalcView", "DresinaVia_LockViewRender", function(client, origin, angles, fov)
	if (!IsValid(client) or client != LocalPlayer()) then return end
	if (client:CanOverrideView()) then return end

	local seat = client:GetParent()
	if (!IsValid(seat)) then return end
	if (HasFreeLookTool(client)) then return end

	local seatIdx = client:GetNetVar("dresinaSeatIdx")
	local yawOffset = (seatIdx != nil) and ix.config.Get("dresinaSeatYaw" .. seatIdx, 90) or 90

	local finalAngles = Angle(angles.p, seat:GetAngles().y + yawOffset, 0)

	-- El maniquí visual (ver CreatePlayerReplica en sv_plugin.lua) ocupa el
	-- mismo punto base que la cámara; si su cabeza en la pose sentada queda
	-- más adelantada que el ojo, se ve el propio cuerpo en primer plano.
	-- dresinaSeatViewForward (ix.config, ajustable con dresina_seatview)
	-- empuja la cámara a lo largo de su propio ángulo para sacarla de ahí.
	local forwardOffset = ix.config.Get("dresinaSeatViewForward", 0)

	return {
		origin = origin + finalAngles:Forward() * forwardOffset,
		angles = finalAngles,
		fov = fov,
	}
end)

net.Receive("DresinaVia_SendList", function()
	local isToggle = net.ReadBool()

	local routes = {}
	local routeCount = net.ReadUInt(8)
	for i = 1, routeCount do
		local name = net.ReadString()
		local wps = {}
		local count = net.ReadUInt(16)
		for j = 1, count do
			table.insert(wps, net.ReadVector())
		end
		local loop = net.ReadBool()
		local r = net.ReadUInt(8)
		local g = net.ReadUInt(8)
		local b = net.ReadUInt(8)

		routes[i] = {name = name, points = wps, loop = loop, color = Color(r, g, b)}
	end

	routeList = routes

	if (isToggle) then
		overlayActive = !overlayActive
		LocalPlayer():Notify(overlayActive and "Visualización del camino de la draisina activada." or "Visualización del camino de la draisina desactivada.")
	end
end)

-- ============================================================
--  Modo de edición interactivo (/DresinaViaWP)
--  Clic izquierdo añade, clic derecho coge/suelta (mover), R elimina el
--  waypoint más cercano a donde miras. La lógica real corre en el servidor
--  (net.Receive("DresinaVia_WPAction") en sv_plugin.lua); aquí solo se
--  interceptan los binds (bloqueando el disparo/recarga real mientras el
--  modo está activo) y se dibuja el HUD con los controles.
-- ============================================================

local wpModeActive = false
local wpModeRouteId = "main"

net.Receive("DresinaVia_WPMode", function()
	wpModeActive = net.ReadBool()
	wpModeRouteId = net.ReadString()

	-- Al entrar en el modo, forzar el overlay visible (el servidor manda un
	-- refresco justo después) para poder ver dónde se está insertando/
	-- moviendo/borrando. Al salir se deja el overlay como estuviera.
	if (wpModeActive) then
		overlayActive = true
	end
end)

-- E (toque/mantener para ramas) NO se intercepta aquí: se probó con
-- PlayerBindPress midiendo la duración en el cliente y no era fiable (el
-- servidor a veces recibía "toque" aunque hubieras mantenido pulsado 2s).
-- Igual que las bridas de handcuffs, esto necesita el patrón de servidor
-- KeyPress/KeyRelease con un timer (ver sv_plugin.lua) — y ese patrón solo
-- funciona si el bind +use LLEGA con normalidad al servidor, así que aquí no
-- se suprime ni se le hace nada especial.
hook.Add("PlayerBindPress", "DresinaVia_WPMode_Binds", function(ply, bind, pressed)
	if (!wpModeActive or !pressed) then return end

	bind = string.lower(bind)

	local action
	if (bind == "+attack") then
		action = "add"
	elseif (bind == "+attack2") then
		action = "move"
	elseif (bind == "+reload") then
		action = "remove"
	else
		return
	end

	net.Start("DresinaVia_WPAction")
		net.WriteString(action)
	net.SendToServer()

	return true
end)

hook.Add("HUDPaint", "DresinaVia_WPMode_HUD", function()
	if (!wpModeActive) then return end

	local x, y = 20, 20
	local lineH = 18

	local lines = {
		{"MODO EDICIÓN DE VÍA — ruta: " .. wpModeRouteId, Color(255, 200, 0)},
		{"Clic Izquierdo — Añadir waypoint", Color(255, 255, 255)},
		{"Clic Derecho — Coger / soltar waypoint o aguja (mover)", Color(255, 255, 255)},
		{"R — Eliminar waypoint más cercano", Color(255, 255, 255)},
		{"E (toque) — Crear una rama nueva desde aquí", Color(150, 220, 255)},
		{"E (mantener 2s) — Terminar la rama y volver", Color(150, 220, 255)},
		{"/DresinaViaWP — Salir del modo", Color(180, 180, 180)},
	}

	local boxW = 400
	surface.SetDrawColor(0, 0, 0, 160)
	surface.DrawRect(x - 8, y - 6, boxW, #lines * lineH + 12)

	for i, entry in ipairs(lines) do
		draw.SimpleText(entry[1], "DermaDefault", x, y + (i - 1) * lineH, entry[2])
	end

	-- Cruceta central: en modo edición no hay crosshair normal (armas
	-- bloqueadas), así que sin esto es dificil saber a qué punto exacto vas a
	-- afectar con clic/R.
	local cx, cy = ScrW() / 2, ScrH() / 2
	local size, gap = 6, 3
	surface.SetDrawColor(255, 255, 255, 220)
	surface.DrawLine(cx - size - gap, cy, cx - gap, cy)
	surface.DrawLine(cx + gap, cy, cx + size + gap, cy)
	surface.DrawLine(cx, cy - size - gap, cx, cy - gap)
	surface.DrawLine(cx, cy + gap, cx, cy + size + gap)
end)

hook.Add("PostDrawTranslucentRenderables", "DresinaVia_Overlay3D", function(_, bSkybox)
	if (bSkybox or !overlayActive) then return end

	for _, route in ipairs(routeList) do
		local points = route.points
		if (#points == 0) then continue end

		local segCount = route.loop and #points or (#points - 1)
		for i = 1, segCount do
			local a = points[i]
			local b = points[(i % #points) + 1]

			render.DrawLine(a, b, route.color, true)
			render.DrawWireframeBox(a, angle_zero, Vector(-6, -6, 0), Vector(6, 6, 40), route.color)
		end

		local last = points[#points]
		render.DrawWireframeBox(last, angle_zero, Vector(-6, -6, 0), Vector(6, 6, 40), Color(255, 60, 60))
	end

	cam.Start2D()
		for _, route in ipairs(routeList) do
			for i, wp in ipairs(route.points) do
				local screen = (wp + Vector(0, 0, 30)):ToScreen()
				if (!screen.visible) then continue end

				-- Nombre de la ruta encima del número, para saber a qué rama
				-- pertenece cada waypoint de un vistazo sin tener que adivinarlo
				-- por el color.
				draw.SimpleText(route.name or "", "BudgetLabel", screen.x + 1, screen.y - 11, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(route.name or "", "BudgetLabel", screen.x, screen.y - 12, route.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				local label = "#" .. i
				draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(label, "BudgetLabel", screen.x, screen.y, route.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	cam.End2D()
end)
