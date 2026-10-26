-- ============================================================
--  npc_presets  |  sh_commands.lua  (SHARED)
--  Definición de comandos — compartido para que aparezcan
--  en el autocompletado del chat del cliente.
-- ============================================================

ix.command.Add("npcAdmin", {
	adminOnly   = true,
	description = "Abre el panel de administración de presets de NPCs.",
	OnRun = function(self, client)
		net.Start("npcpresets_AdminOpen")
		net.Send(client)
	end
})

ix.command.Add("npcSpawn", {
	adminOnly   = true,
	description = "Selecciona un preset y crea un punto de spawn donde estás mirando.",
	OnRun = function(self, client)
		if (table.Count(ix.npcpresets.presets) == 0) then
			return "No hay presets creados. Usa /npcAdmin para crear uno."
		end

		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "No se pudo determinar la posición. Mira hacia una superficie."
		end

		local plugin = ix.plugin.Get("npc_presets")
		plugin.pendingSpawn[client] = trace.HitPos + trace.HitNormal * 5

		local list = {}
		for id, preset in pairs(ix.npcpresets.presets) do
			table.insert(list, { id = id, name = preset.name, cooldown = preset.cooldown, npcCount = #preset.npcs })
		end

		net.Start("npcpresets_SpawnOpen")
			ix.npcpresets.WriteCompressed(list)
		net.Send(client)
	end
})

ix.command.Add("npcMostrar", {
	adminOnly   = true,
	description = "Activa o desactiva la visualización de los puntos de spawn y alarma de NPCs.",
	OnRun = function(self, client)
		local pointsWithPreset = {}
		for _, point in ipairs(ix.npcpresets.points) do
			local preset = ix.npcpresets.presets[point.presetId]
			table.insert(pointsWithPreset, {
				id          = point.id,
				pos         = point.pos,
				presetName  = preset and preset.name or "?",
				isHorde     = preset and preset.isHorde == true or false,
				isPatrol    = preset and preset.isPatrol == true or false,
				radius      = preset and (preset.radius or 800) or 800,
				spawnRadius = preset and (preset.spawnRadius or 2500) or 2500,
			})
		end

		local alarmPointsData = {}
		for _, ap in ipairs(ix.npcpresets.alarmPoints) do
			local preset = ix.npcpresets.presets[ap.presetId]
			table.insert(alarmPointsData, {
				pos        = ap.pos,
				presetName = preset and preset.name or "?",
			})
		end

		local hordeTargetsData = {}
		for _, ht in ipairs(ix.npcpresets.hordeTargets) do
			local preset = ix.npcpresets.presets[ht.presetId]
			table.insert(hordeTargetsData, {
				pos        = ht.pos,
				presetName = preset and preset.name or "?",
			})
		end

		local patrolWPData = {}
		for pointId, waypoints in pairs(ix.npcpresets.patrolWaypoints) do
			local presetName = "?"
			for _, pt in ipairs(ix.npcpresets.points) do
				if (pt.id == pointId) then
					local preset = ix.npcpresets.presets[pt.presetId]
					presetName = preset and preset.name or "?"
					break
				end
			end
			for idx, wp in ipairs(waypoints) do
				table.insert(patrolWPData, {
					pos        = wp.pos,
					presetName = presetName,
					index      = idx,
					total      = #waypoints,
					pointId    = pointId,
				})
			end
		end

		-- Registrar/desregistrar al jugador en la lista de actualización automática
		local plugin = ix.plugin.Get("npc_presets")
		plugin.showingPlayers[client] = plugin.showingPlayers[client] and nil or true

		net.Start("npcpresets_PointsData")
			ix.npcpresets.WriteCompressed({
				points          = pointsWithPreset,
				alarmPoints     = alarmPointsData,
				hordeTargets    = hordeTargetsData,
				patrolWaypoints = patrolWPData,
				isUpdate        = false,
			})
		net.Send(client)
	end
})

ix.command.Add("npcEliminar", {
	adminOnly   = true,
	description = "Elimina el punto de spawn de NPC más cercano a donde miras (máx 200 u).",
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "Mira hacia una superficie."
		end
		local hitPos  = trace.HitPos
		local maxDist = 200 * 200

		local closest, closestDist, closestIdx = nil, math.huge, nil

		for i, point in ipairs(ix.npcpresets.points) do
			local pos = Vector(point.pos.x or 0, point.pos.y or 0, point.pos.z or 0)
			local dist = pos:DistToSqr(hitPos)
			if (dist < maxDist and dist < closestDist) then
				closest     = point
				closestDist = dist
				closestIdx  = i
			end
		end

		if (!closest) then
			return "No hay puntos de spawn dentro de 200 unidades."
		end

		local plugin = ix.plugin.Get("npc_presets")
		local state  = plugin.spawnState[closest.id]
		if (state and state.entities) then
			for _, ent in ipairs(state.entities) do
				if (IsValid(ent)) then ent:Remove() end
			end
		end
		plugin.spawnState[closest.id] = nil
		timer.Remove("npcpresets_cleanup_" .. closest.id)
		timer.Remove("npcpresets_hordeai_" .. closest.id)
		timer.Remove("npcpresets_patrolai_" .. closest.id)

		table.remove(ix.npcpresets.points, closestIdx)

		-- Eliminar waypoints del punto eliminado
		ix.npcpresets.patrolWaypoints[closest.id] = nil

		local p = ix.plugin.Get("npc_presets")
		if (p) then
			p:SaveData()
			if (p.pushPointsUpdate) then p.pushPointsUpdate() end
		end

		local preset = ix.npcpresets.presets[closest.presetId]
		return "Punto de spawn eliminado" .. (preset and (" (preset: " .. preset.name .. ")") or "") .. "."
	end
})

ix.command.Add("npcEliminarAlarma", {
	adminOnly   = true,
	description = "Elimina el punto de alarma más cercano a donde miras (máx 200 u).",
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "Mira hacia una superficie."
		end
		local hitPos  = trace.HitPos
		local maxDist = 200 * 200

		local closest, closestDist, closestIdx = nil, math.huge, nil

		for i, ap in ipairs(ix.npcpresets.alarmPoints) do
			local pos  = Vector(ap.pos.x or 0, ap.pos.y or 0, ap.pos.z or 0)
			local dist = pos:DistToSqr(hitPos)
			if (dist < maxDist and dist < closestDist) then
				closest     = ap
				closestDist = dist
				closestIdx  = i
			end
		end

		if (!closest) then
			return "No hay puntos de alarma dentro de 200 unidades."
		end

		table.remove(ix.npcpresets.alarmPoints, closestIdx)

		local plugin = ix.plugin.Get("npc_presets")
		if (plugin) then
			plugin:SaveData()
			if (plugin.pushPointsUpdate) then plugin.pushPointsUpdate() end
		end

		local preset = ix.npcpresets.presets[closest.presetId]
		return "Punto de alarma eliminado" .. (preset and (" (horda: " .. preset.name .. ")") or "") .. "."
	end
})

ix.command.Add("npcActivateHorde", {
	adminOnly   = true,
	description = "Activa manualmente una horda: spawna todos sus NPCs y suena la alarma.",
	OnRun = function(self, client)
		local hordeList = {}
		for id, preset in pairs(ix.npcpresets.presets) do
			if (preset.isHorde) then
				table.insert(hordeList, {
					id       = id,
					name     = preset.name,
					npcCount = #(preset.npcs or {}),
				})
			end
		end
		if (#hordeList == 0) then
			return "No hay presets de tipo Horda. Crea uno con /npcAdmin marcando '¿Es Horda?'."
		end
		net.Start("npcpresets_HordeOpen")
			ix.npcpresets.WriteCompressed(hordeList)
		net.Send(client)
	end
})

ix.command.Add("npcAlarma", {
	adminOnly   = true,
	description = "Coloca un punto de alarma (campanadas) para una horda donde estás mirando.",
	OnRun = function(self, client)
		local hordeList = {}
		for id, preset in pairs(ix.npcpresets.presets) do
			if (preset.isHorde) then
				table.insert(hordeList, { id = id, name = preset.name, npcCount = #(preset.npcs or {}) })
			end
		end
		if (#hordeList == 0) then
			return "No hay presets de tipo Horda para asignar el punto de alarma."
		end

		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "No se pudo determinar la posición. Mira hacia una superficie."
		end

		local plugin = ix.plugin.Get("npc_presets")
		plugin.pendingAlarm[client] = trace.HitPos + trace.HitNormal * 5

		net.Start("npcpresets_AlarmOpen")
			ix.npcpresets.WriteCompressed(hordeList)
		net.Send(client)
	end
})

ix.command.Add("npcHordaObj", {
	adminOnly   = true,
	description = "Coloca un punto de objetivo para una horda donde estás mirando. Los NPCs avanzarán hacia él.",
	OnRun = function(self, client)
		local hordeList = {}
		for id, preset in pairs(ix.npcpresets.presets) do
			if (preset.isHorde) then
				table.insert(hordeList, { id = id, name = preset.name, npcCount = #(preset.npcs or {}) })
			end
		end
		if (#hordeList == 0) then
			return "No hay presets de tipo Horda para asignar el objetivo."
		end

		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "No se pudo determinar la posición. Mira hacia una superficie."
		end

		local plugin = ix.plugin.Get("npc_presets")
		plugin.pendingHordeTarget[client] = trace.HitPos + trace.HitNormal * 5

		net.Start("npcpresets_HordeTargetOpen")
			ix.npcpresets.WriteCompressed(hordeList)
		net.Send(client)
	end
})

ix.command.Add("npcPatrullaWP", {
	adminOnly   = true,
	description = "Mira a un spawn de patrulla para seleccionarlo, luego mira al suelo para colocar waypoints.",
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "No se pudo determinar la posición. Mira hacia una superficie."
		end

		local hitPos = trace.HitPos
		local plugin = ix.plugin.Get("npc_presets")

		-- ¿Estamos mirando cerca de un spawn de patrulla? → seleccionarlo
		local selectDist = 200 * 200
		local nearestPoint, nearestDist = nil, math.huge

		for _, point in ipairs(ix.npcpresets.points) do
			local preset = ix.npcpresets.presets[point.presetId]
			if (preset and preset.isPatrol) then
				local pos  = Vector(point.pos.x or 0, point.pos.y or 0, point.pos.z or 0)
				local dist = pos:DistToSqr(hitPos)
				if (dist < selectDist and dist < nearestDist) then
					nearestPoint = point
					nearestDist  = dist
				end
			end
		end

		if (nearestPoint) then
			plugin.pendingPatrolPoint[client] = nearestPoint.id
			local preset  = ix.npcpresets.presets[nearestPoint.presetId]
			local wpCount = ix.npcpresets.patrolWaypoints[nearestPoint.id] and #ix.npcpresets.patrolWaypoints[nearestPoint.id] or 0
			client:Notify("[NPC Presets] Spawn '" .. (preset and preset.name or "?") .. "' seleccionado (" .. wpCount .. " WPs). Usa /npcPatrullaWP mirando al suelo para colocar waypoints.")
			return
		end

		-- No hay spawn cerca → colocar waypoint en el spawn seleccionado
		local selectedId = plugin.pendingPatrolPoint[client]
		if (!selectedId) then
			return "Primero mira a un punto de spawn de patrulla (máx 200 u) y usa /npcPatrullaWP para seleccionarlo."
		end

		local targetPoint = nil
		for _, pt in ipairs(ix.npcpresets.points) do
			if (pt.id == selectedId) then
				targetPoint = pt
				break
			end
		end
		if (!targetPoint) then
			plugin.pendingPatrolPoint[client] = nil
			return "El punto de spawn seleccionado ya no existe. Selecciona otro."
		end

		local preset = ix.npcpresets.presets[targetPoint.presetId]
		if (!preset or !preset.isPatrol) then
			plugin.pendingPatrolPoint[client] = nil
			return "El punto seleccionado ya no es de tipo patrulla."
		end

		local pos = hitPos + trace.HitNormal * 5
		ix.npcpresets.patrolWaypoints[selectedId] = ix.npcpresets.patrolWaypoints[selectedId] or {}
		table.insert(ix.npcpresets.patrolWaypoints[selectedId], {
			pos = { x = pos.x, y = pos.y, z = pos.z },
		})

		local p = ix.plugin.Get("npc_presets")
		if (p) then
			p:SaveData()
			if (p.pushPointsUpdate) then p.pushPointsUpdate() end
		end

		local idx = #ix.npcpresets.patrolWaypoints[selectedId]
		client:Notify("[NPC Presets] Waypoint #" .. idx .. " añadido a '" .. preset.name .. "'.")
	end
})

ix.command.Add("npcEliminarWP", {
	adminOnly   = true,
	description = "Elimina el waypoint de patrulla más cercano a donde miras (máx 200 u).",
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		if (!trace or !trace.HitPos) then
			return "Mira hacia una superficie."
		end
		local hitPos  = trace.HitPos
		local maxDist = 200 * 200

		local closest, closestDist = nil, math.huge
		local closestPointId, closestIdx = nil, nil

		for pointId, waypoints in pairs(ix.npcpresets.patrolWaypoints) do
			for i, wp in ipairs(waypoints) do
				local pos  = Vector(wp.pos.x or 0, wp.pos.y or 0, wp.pos.z or 0)
				local dist = pos:DistToSqr(hitPos)
				if (dist < maxDist and dist < closestDist) then
					closest        = wp
					closestDist    = dist
					closestPointId = pointId
					closestIdx     = i
				end
			end
		end

		if (!closest) then
			return "No hay waypoints de patrulla dentro de 200 unidades."
		end

		table.remove(ix.npcpresets.patrolWaypoints[closestPointId], closestIdx)

		if (#ix.npcpresets.patrolWaypoints[closestPointId] == 0) then
			ix.npcpresets.patrolWaypoints[closestPointId] = nil
		end

		local plugin = ix.plugin.Get("npc_presets")
		if (plugin) then
			plugin:SaveData()
			if (plugin.pushPointsUpdate) then plugin.pushPointsUpdate() end
		end

		local presetName = "?"
		for _, pt in ipairs(ix.npcpresets.points) do
			if (pt.id == closestPointId) then
				local preset = ix.npcpresets.presets[pt.presetId]
				presetName = preset and preset.name or "?"
				break
			end
		end
		return "Waypoint #" .. closestIdx .. " eliminado (patrulla: " .. presetName .. ")."
	end
})

ix.command.Add("npcDebug", {
	adminOnly   = true,
	description = "Diagnostica por qué el punto de spawn de NPCs más cercano a ti no está generando NPCs.",
	OnRun = function(self, client)
		if (#ix.npcpresets.points == 0) then
			return "No hay puntos de spawn creados."
		end

		local plyPos = client:GetPos()
		local closest, closestDistSq = nil, math.huge

		for _, point in ipairs(ix.npcpresets.points) do
			local pos = Vector(point.pos.x or 0, point.pos.y or 0, point.pos.z or 0)
			local distSq = pos:DistToSqr(plyPos)
			if (distSq < closestDistSq) then
				closest       = point
				closestDistSq = distSq
			end
		end

		if (!closest) then return "No se encontró ningún punto de spawn." end

		local preset = ix.npcpresets.presets[closest.presetId]
		local dist   = math.sqrt(closestDistSq)

		client:ChatPrint("== NPC Debug: punto más cercano (" .. math.Round(dist) .. "u) ==")

		if (!preset) then
			client:ChatPrint("El preset asociado ya no existe (id: " .. tostring(closest.presetId) .. ").")
			return
		end

		client:ChatPrint("Preset: " .. preset.name)

		local plugin = ix.plugin.Get("npc_presets")

		if (!plugin.spawnReady) then
			client:ChatPrint("BLOQUEADO: han pasado menos de 5 min desde el arranque del servidor.")
		end

		if (preset.isHorde) then
			client:ChatPrint("BLOQUEADO: el preset es de tipo Horda (solo spawnea manualmente con /npcActivateHorde).")
		end

		local totalAlive = 0
		for _, state in pairs(plugin.spawnState) do
			if (state.entities) then
				for _, ent in ipairs(state.entities) do
					if (IsValid(ent)) then totalAlive = totalAlive + 1 end
				end
			end
		end
		client:ChatPrint("NPCs vivos (todos los puntos): " .. totalAlive .. " / 100")
		if (totalAlive >= 100) then
			client:ChatPrint("BLOQUEADO: límite global de NPCs alcanzado.")
		end

		local outerRadius = preset.spawnRadius or 2500
		local proxRadius  = preset.radius or 800

		client:ChatPrint("Radio de presencia (spawnRadius): " .. outerRadius .. "u  |  Radio de proximidad (radius): " .. proxRadius .. "u")

		if (proxRadius >= outerRadius) then
			client:ChatPrint("BLOQUEADO PERMANENTEMENTE: 'radius' (" .. proxRadius .. ") >= 'spawnRadius' (" .. outerRadius .. "). No existe ninguna distancia válida para spawnear. Baja 'Radio sin jugadores' o sube 'Radio de seguridad/presencia' en /npcAdmin.")
		elseif (dist < proxRadius) then
			client:ChatPrint("BLOQUEADO: estás a " .. math.Round(dist) .. "u, dentro del radio de proximidad (" .. proxRadius .. "u). Aléjate a más de " .. proxRadius .. "u pero menos de " .. outerRadius .. "u.")
		elseif (dist > outerRadius) then
			client:ChatPrint("BLOQUEADO: estás a " .. math.Round(dist) .. "u, fuera del radio de presencia (" .. outerRadius .. "u). Acércate a menos de " .. outerRadius .. "u.")
		else
			client:ChatPrint("OK: estás en la banda válida de spawn (" .. proxRadius .. "u - " .. outerRadius .. "u).")
		end

		local state = plugin.spawnState[closest.id]
		if (state and state.entities) then
			local alive = 0
			for _, ent in ipairs(state.entities) do
				if (IsValid(ent)) then alive = alive + 1 end
			end
			if (alive > 0) then
				client:ChatPrint("BLOQUEADO: ya hay " .. alive .. " NPC(s) vivo(s) de este punto (debe morir el wave anterior primero).")
			end
			if (state.lastDeath) then
				local remaining = (preset.cooldown or 0) - (CurTime() - state.lastDeath)
				if (remaining > 0) then
					client:ChatPrint("BLOQUEADO: cooldown activo, quedan " .. math.Round(remaining) .. "s.")
				end
			end
		end

		if (!preset.npcs or #preset.npcs == 0) then
			client:ChatPrint("AVISO: el preset no tiene ningún NPC configurado.")
		else
			local badClasses = {}
			for _, npcInfo in ipairs(preset.npcs) do
				local class = npcInfo.class or ""
				if (class == "" or (!scripted_ents.GetStored()[class] and !list.Get("NPC")[class])) then
					table.insert(badClasses, class == "" and "(vacío)" or class)
				end
			end
			if (#badClasses > 0) then
				client:ChatPrint("AVISO: clase(s) de NPC no reconocidas, puede que no spawneen: " .. table.concat(badClasses, ", "))
			end
		end
	end
})

ix.command.Add("npcAyuda", {
	adminOnly   = true,
	description = "Muestra en el chat todos los comandos del sistema de presets de NPCs.",
	OnRun = function(self, client)
		local presetCount = table.Count(ix.npcpresets.presets)
		local pointCount  = #ix.npcpresets.points

		client:ChatPrint("╔══ NPC Presets — Comandos ═══════════════════╗")
		client:ChatPrint("║  /npcAdmin")
		client:ChatPrint("║    Abre el panel para crear, editar y eliminar")
		client:ChatPrint("║    presets de NPCs (clase, cantidad, arma, cooldown).")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcSpawn")
		client:ChatPrint("║    Mira una superficie y ejecuta el comando.")
		client:ChatPrint("║    Se abre un selector; elige el preset para")
		client:ChatPrint("║    colocar un punto de spawn en esa posición.")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcMostrar")
		client:ChatPrint("║    Activa / desactiva la visualización de todos")
		client:ChatPrint("║    los puntos de spawn con su nombre en el mundo.")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcEliminar")
		client:ChatPrint("║    Mira hacia un punto de spawn (máx 200 u)")
		client:ChatPrint("║    y ejecuta el comando para eliminarlo junto")
		client:ChatPrint("║    con los NPCs que haya spawneado.")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcPatrullaWP")
		client:ChatPrint("║    1) Mira a un spawn de patrulla → selecciónalo.")
		client:ChatPrint("║    2) Mira al suelo → coloca waypoints para ese spawn.")
		client:ChatPrint("║    Cada spawn tiene su propia ruta independiente.")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcEliminarWP")
		client:ChatPrint("║    Elimina el waypoint de patrulla más cercano")
		client:ChatPrint("║    a donde miras (máx 200 u).")
		client:ChatPrint("║")
		client:ChatPrint("║  /npcAyuda  — muestra este mensaje.")
		client:ChatPrint("╠══ Estado actual ════════════════════════════╣")
		client:ChatPrint("║  Presets configurados : " .. presetCount)
		client:ChatPrint("║  Puntos de spawn      : " .. pointCount)
		client:ChatPrint("╚═════════════════════════════════════════════╝")
	end
})
