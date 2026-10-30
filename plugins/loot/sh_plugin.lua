-- ============================================================
--  loot  |  sh_plugin.lua  (SHARED)
--  Sistema de loot basado en áreas, presets de props y tiers
--  configurables. Punto de entrada y definición de comandos.
-- ============================================================

PLUGIN.name        = "Loot System"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Sistema de loot basado en áreas, presets de props y tiers configurables."

ix.loot         = ix.loot         or {}
ix.loot.tables  = ix.loot.tables  or {}

ix.util.Include("sh_loot.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

-- ── Helpers de red (JSON + compress) ─────────────────────────

function ix.loot.WriteCompressed(tbl)
	local json = util.TableToJSON(tbl)
	local compressed = util.Compress(json)
	local len = #compressed
	net.WriteUInt(len, 32)
	net.WriteData(compressed, len)
end

function ix.loot.ReadCompressed()
	local len = net.ReadUInt(32)
	if (len == 0) then return {} end
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	if (!json) then return {} end
	return util.JSONToTable(json) or {}
end

-- ── Comandos ──────────────────────────────────────────────────

-- /LootAreaStart <nombre>
-- /LootAreaCreate
ix.command.Add("LootAreaCreate", {
	adminOnly   = true,
	description = "Activa el modo de colocación visual de zona de loot (2 clics + nombre).",
	OnRun = function(self, client)
		if (SERVER) then
			net.Start("ixLootAreaCreateMode")
			net.Send(client)
		end
	end
})

-- /LootAreaRemove [nombre]
ix.command.Add("LootAreaRemove", {
	adminOnly   = true,
	description = "Elimina una zona de loot (puntos de spawn, props y datos asociados), por nombre o la del área en la que estás.",
	arguments   = { bit.bor(ix.type.string, ix.type.optional) },
	OnRun = function(self, client, areaArg)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")

			local areaName = (areaArg and areaArg != "") and areaArg or nil
			if (!areaName) then
				local areaId = client:GetArea()
				if (areaId and areaId != "") then areaName = areaId end
			end

			if (!areaName) then
				return "No se encontró área. Párate dentro de una zona de loot o pasa el nombre como argumento."
			end

			local areaData = ix.area.stored and ix.area.stored[areaName]
			if (!areaData or areaData.type != "loot_zone") then
				return "El área '" .. areaName .. "' no existe o no es de tipo loot_zone."
			end

			-- Eliminar entidades ix_loot dentro de los límites del área
			for _, ent in ipairs(ents.FindByClass("ix_loot")) do
				if (IsValid(ent) and ent:GetPos():WithinAABox(areaData.startPosition, areaData.endPosition)) then
					ent:Remove()
				end
			end

			-- Limpiar datos del plugin asociados a esta área
			if (plugin.data.spawnPoints)  then plugin.data.spawnPoints[areaName]  = nil end
			if (plugin.data.areaTiers)    then plugin.data.areaTiers[areaName]    = nil end
			if (plugin.data.areaPresets)  then plugin.data.areaPresets[areaName]  = nil end
			if (plugin.data.respawnTimes) then plugin.data.respawnTimes[areaName] = nil end
			if (plugin.data.spawnCounts)  then plugin.data.spawnCounts[areaName]  = nil end

			ix.area.Remove(areaName)

			local areaPlugin = ix.plugin.Get("area")
			if (areaPlugin) then areaPlugin:SaveData() end

			plugin:SaveData()
			plugin.pushPointsUpdate()

			client:ChatPrint("[Loot] Zona de loot '" .. areaName .. "' eliminada.")
		end
	end
})

-- Encuentra una posición válida fuera de geometría partiendo del hit.
-- Empuja en la dirección de la normal hasta salir, luego cae al suelo.
local function FindValidLootPos(hitPos, hitNormal)
	local MINS = Vector(-10, -10, 0)
	local MAXS = Vector(10, 10, 32)

	local candidate = hitPos + hitNormal * 5

	-- Si ya está libre, solo ajustar al suelo
	local function dropToFloor(pos)
		local tr = util.TraceLine({
			start  = pos + Vector(0, 0, 4),
			endpos = pos - Vector(0, 0, 128),
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (tr.HitWorld) then
			return tr.HitPos + Vector(0, 0, 2)
		end
		return pos
	end

	-- Empujar por la normal hasta encontrar espacio libre (máx 64 u)
	for dist = 0, 64, 4 do
		local test = hitPos + hitNormal * (5 + dist)
		local tr   = util.TraceHull({
			start  = test,
			endpos = test,
			mins   = MINS,
			maxs   = MAXS,
			mask   = MASK_SOLID_BRUSHONLY,
		})
		if (!tr.StartSolid) then
			return dropToFloor(test), dist > 0
		end
	end

	return nil, false
end

-- /LootAddPoint [area]
ix.command.Add("LootAddPoint", {
	adminOnly   = true,
	description = "Añade un punto de spawn de loot donde estás mirando, en el área indicada o en la del admin.",
	arguments   = { bit.bor(ix.type.string, ix.type.optional) },
	OnRun = function(self, client, areaArg)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			local trace  = client:GetEyeTraceNoCursor()
			if (!trace or !trace.HitPos) then
				return "Mira hacia una superficie."
			end

			-- Determinar área objetivo
			local areaName = (areaArg and areaArg != "") and areaArg or nil
			if (!areaName) then
				local areaId = client:GetArea()
				if (areaId and areaId != "") then areaName = areaId end
			end

			if (!areaName) then
				return "No se encontró área. Párate dentro de una zona loot o pasa el nombre como argumento."
			end

			local areaData = ix.area.stored and ix.area.stored[areaName]
			if (!areaData or areaData.type != "loot_zone") then
				return "El área '" .. areaName .. "' no existe o no es de tipo loot_zone."
			end

			local pos, corrected = FindValidLootPos(trace.HitPos, trace.HitNormal)
			if (!pos) then
				return "La posición está dentro de geometría sólida y no se pudo corregir automáticamente."
			end

			-- Calcular yaw: la normal apunta HACIA el jugador (afuera de la pared),
			-- sumamos 180° para que el prop mire hacia afuera (de espaldas a la pared)
			local flat = Vector(trace.HitNormal.x, trace.HitNormal.y, 0)
			local yaw  = (flat:Length() > 0.1) and (flat:Angle().y + 180) or 0

			if (!plugin.data.spawnPoints) then plugin.data.spawnPoints = {} end
			if (!plugin.data.spawnPoints[areaName]) then plugin.data.spawnPoints[areaName] = {} end

			table.insert(plugin.data.spawnPoints[areaName], { x = pos.x, y = pos.y, z = pos.z, yaw = yaw })
			plugin:SaveData()
			plugin.pushPointsUpdate()

			if (corrected) then
				client:ChatPrint("[Loot] Punto corregido automáticamente y añadido al área '" .. areaName .. "'.")
			else
				client:ChatPrint("[Loot] Punto añadido al área '" .. areaName .. "'.")
			end
		end
	end
})

-- /LootRemovePoint
ix.command.Add("LootRemovePoint", {
	adminOnly   = true,
	description = "Elimina el punto de spawn de loot más cercano a donde miras (máx 200 u).",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin  = ix.plugin.Get("loot")
			local trace   = client:GetEyeTraceNoCursor()
			if (!trace or !trace.HitPos) then
				return "Mira hacia una superficie."
			end

			local hitPos  = trace.HitPos
			local maxDist = 200 * 200

			local closestArea, closestIdx, closestDist = nil, nil, math.huge

			if (plugin.data.spawnPoints) then
				for areaName, points in pairs(plugin.data.spawnPoints) do
					for i, pt in ipairs(points) do
						local pos  = Vector(pt.x or 0, pt.y or 0, pt.z or 0)
						local dist = pos:DistToSqr(hitPos)
						if (dist < maxDist and dist < closestDist) then
							closestArea  = areaName
							closestIdx   = i
							closestDist  = dist
						end
					end
				end
			end

			if (!closestArea) then
				return "No hay puntos de spawn dentro de 200 unidades."
			end

			local removedPt = plugin.data.spawnPoints[closestArea][closestIdx]
			table.remove(plugin.data.spawnPoints[closestArea], closestIdx)

			-- Eliminar entidades ix_loot en esa posición
			local removedPos = Vector(removedPt.x, removedPt.y, removedPt.z)
			for _, ent in ipairs(ents.FindByClass("ix_loot")) do
				if (IsValid(ent) and ent:GetPos():DistToSqr(removedPos) < 64 * 64) then
					ent:Remove()
				end
			end

			plugin:SaveData()
			plugin.pushPointsUpdate()

			return "Punto de spawn eliminado del área '" .. closestArea .. "'."
		end
	end
})

-- /LootMostrar
ix.command.Add("LootMostrar", {
	adminOnly   = true,
	description = "Activa o desactiva la visualización de los puntos de spawn de loot.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			plugin.showingPlayers[client] = plugin.showingPlayers[client] and nil or true
			plugin.pushPointsUpdate(client, true)
		end
	end
})

-- /LootPresetCreate <nombre>
ix.command.Add("LootPresetCreate", {
	adminOnly   = true,
	description = "Crea un nuevo preset de props de loot.",
	arguments   = { ix.type.string },
	OnRun = function(self, client, nombre)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			if (!plugin.data.presets) then plugin.data.presets = {} end
			if (plugin.data.presets[nombre]) then
				return "Ya existe un preset con el nombre '" .. nombre .. "'."
			end
			plugin.data.presets[nombre] = { models = {} }
			plugin:SaveData()
			client:ChatPrint("[Loot] Preset '" .. nombre .. "' creado.")
		end
	end
})

-- /LootPresetAddProp <preset> <modelo>
ix.command.Add("LootPresetAddProp", {
	adminOnly   = true,
	description = "Añade un modelo de prop a un preset de loot.",
	arguments   = { ix.type.string, ix.type.string },
	OnRun = function(self, client, preset, modelo)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			if (!plugin.data.presets or !plugin.data.presets[preset]) then
				return "El preset '" .. preset .. "' no existe. Créalo primero con /LootPresetCreate."
			end
			if (!util.IsValidModel(modelo)) then
				return "El modelo '" .. modelo .. "' no es válido."
			end
			table.insert(plugin.data.presets[preset].models, modelo)
			plugin:SaveData()
			client:ChatPrint("[Loot] Modelo añadido al preset '" .. preset .. "' (total: " .. #plugin.data.presets[preset].models .. ").")
		end
	end
})

-- /LootPresetRemoveProp <preset> <index>
ix.command.Add("LootPresetRemoveProp", {
	adminOnly   = true,
	description = "Elimina un modelo de un preset de loot por índice.",
	arguments   = { ix.type.string, ix.type.number },
	OnRun = function(self, client, preset, idx)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			idx = math.floor(idx)
			if (!plugin.data.presets or !plugin.data.presets[preset]) then
				return "El preset '" .. preset .. "' no existe."
			end
			local models = plugin.data.presets[preset].models
			if (idx < 1 or idx > #models) then
				return "Índice fuera de rango (1-" .. #models .. ")."
			end
			local removed = models[idx]
			table.remove(models, idx)
			plugin:SaveData()
			client:ChatPrint("[Loot] Modelo '" .. removed .. "' eliminado del preset '" .. preset .. "'.")
		end
	end
})

-- /LootAssign <area> <preset>
ix.command.Add("LootAssign", {
	adminOnly   = true,
	description = "Asigna un preset de props a una zona de loot.",
	arguments   = { ix.type.string, ix.type.string },
	OnRun = function(self, client, area, preset)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			if (!plugin.data.presets or !plugin.data.presets[preset]) then
				return "El preset '" .. preset .. "' no existe."
			end
			local areaInfo = ix.area.stored and ix.area.stored[area]
			if (!areaInfo or areaInfo.type != "loot_zone") then
				return "El área '" .. area .. "' no existe o no es de tipo loot_zone."
			end
			if (!plugin.data.areaPresets) then plugin.data.areaPresets = {} end
			plugin.data.areaPresets[area] = preset
			plugin:SaveData()
			client:ChatPrint("[Loot] Preset '" .. preset .. "' asignado al área '" .. area .. "'.")
		end
	end
})

-- /LootAdmin
ix.command.Add("LootAdmin", {
	adminOnly   = true,
	description = "Abre el panel de administración del sistema de loot.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("loot")
			if (!plugin) then return end

			local itemList = {}
			for id, def in pairs(ix.item.list) do
				itemList[id] = {
					name     = def.name or id,
					category = def.category or "Sin categoría",
				}
			end

			net.Start("ixLootAdminOpen")
				ix.loot.WriteCompressed(plugin.data)
				ix.loot.WriteCompressed(itemList)
			net.Send(client)
		end
	end
})
