PLUGIN.name = "Puertas Brecheables"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Puertas configurables que se abren con botones o se volan con explosivos."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

-- /RegistrarPuerta
ix.command.Add("RegistrarPuerta", {
	adminOnly   = true,
	description = "Registra la puerta frente a ti como brecha demolible.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas_brecheables")
			local ent    = client:GetEyeTraceNoCursor().Entity

			if (!IsValid(ent)) then
				return "Mira hacia una puerta para registrarla."
			end

			local mCID = ent:MapCreationID()
			if (mCID == -1) then
				return "Esta entidad no tiene ID de mapa válido. Solo se pueden registrar entidades compiladas en el mapa."
			end

			for id, info in pairs(plugin.doors) do
				if (info.mapCreationID == mCID) then
					return "Esta puerta ya está registrada con ID: " .. id
				end
			end

			local newID = plugin.nextDoorID
			plugin.nextDoorID = plugin.nextDoorID + 1

			plugin.doors[newID] = {
				id               = newID,
				mapCreationID    = mCID,
				entity           = ent,
				isDestroyed      = false,
				hasExplosive     = false,
				destroyedAt      = nil,
				linkedButtonMCID = nil,
			}

			plugin:SaveConfig()
			client:ChatPrint("[Brechas] Puerta registrada. ID: " .. newID .. " | " .. ent:GetClass())
		end
	end
})

-- /EliminarPuerta
ix.command.Add("EliminarPuerta", {
	adminOnly   = true,
	description = "Elimina el registro de brecha de la puerta frente a ti.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin   = ix.plugin.Get("puertas_brecheables")
			local ent      = client:GetEyeTraceNoCursor().Entity
			local doorInfo = plugin:GetDoorByEntity(ent)

			if (!doorInfo) then
				return "La entidad frente a ti no está registrada como brecha."
			end

			local id = doorInfo.id
			timer.Remove("PB_Explode_" .. id)
			timer.Remove("PB_Respawn_" .. id)

			if (doorInfo.isDestroyed) then
				plugin:ShowDoor(ent)
				if (IsValid(ent)) then ent:Fire("Close", "", 0) end
			end

			plugin.doors[id] = nil
			plugin:RebuildButtonMap()
			plugin:SaveConfig()

			client:ChatPrint("[Brechas] Puerta ID " .. id .. " eliminada.")
		end
	end
})

-- /VincularBoton <id>
ix.command.Add("VincularBoton", {
	adminOnly   = true,
	description = "Vincula la entidad frente a ti como botón de apertura de la puerta indicada.",
	arguments   = { ix.type.number },
	OnRun = function(self, client, doorID)
		if (SERVER) then
			local plugin   = ix.plugin.Get("puertas_brecheables")
			doorID         = math.Round(doorID)
			local doorInfo = plugin.doors[doorID]

			if (!doorInfo) then
				return "No existe una puerta con ID: " .. doorID
			end

			local ent = client:GetEyeTraceNoCursor().Entity
			if (!IsValid(ent)) then
				return "Mira hacia el botón que quieres vincular."
			end

			local mCID = ent:MapCreationID()
			if (mCID == -1) then
				return "Esta entidad no tiene ID de mapa válido."
			end

			doorInfo.linkedButtonMCID = mCID
			plugin:RebuildButtonMap()
			plugin:SaveConfig()

			client:ChatPrint("[Brechas] '" .. ent:GetClass() .. "' vinculado a puerta ID " .. doorID)
		end
	end
})

-- /DesvincularBoton <id>
ix.command.Add("DesvincularBoton", {
	adminOnly   = true,
	description = "Desvincula el botón de la puerta indicada.",
	arguments   = { ix.type.number },
	OnRun = function(self, client, doorID)
		if (SERVER) then
			local plugin   = ix.plugin.Get("puertas_brecheables")
			doorID         = math.Round(doorID)
			local doorInfo = plugin.doors[doorID]

			if (!doorInfo) then
				return "No existe una puerta con ID: " .. doorID
			end

			doorInfo.linkedButtonMCID = nil
			plugin:RebuildButtonMap()
			plugin:SaveConfig()

			client:ChatPrint("[Brechas] Botón desvinculado de puerta ID " .. doorID)
		end
	end
})

-- /ListarPuertas
ix.command.Add("ListarPuertas", {
	adminOnly   = true,
	description = "Lista todas las puertas brecha registradas.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas_brecheables")

			if (table.IsEmpty(plugin.doors)) then
				return "No hay puertas registradas."
			end

			client:ChatPrint("[Brechas] === Puertas registradas ===")
			for id, info in pairs(plugin.doors) do
				local status = "OK"
				if (info.isDestroyed) then
					status = "DESTRUIDA"
				elseif (info.hasExplosive) then
					status = "EXPLOSIVO ACTIVO"
				end
				local btn = info.linkedButtonMCID and ("Botón MCID:" .. info.linkedButtonMCID) or "Sin botón"
				local cls = IsValid(info.entity) and info.entity:GetClass() or "entidad inválida"
				client:ChatPrint(string.format("  [%d] %s | %s | %s", id, cls, status, btn))
			end
		end
	end
})

-- /RestaurarPuerta [id]
ix.command.Add("RestaurarPuerta", {
	adminOnly   = true,
	description = "Restaura inmediatamente una puerta destruida. Sin ID restaura la más cercana.",
	arguments   = { bit.bor(ix.type.number, ix.type.optional) },
	OnRun = function(self, client, doorID)
		if (SERVER) then
			local plugin   = ix.plugin.Get("puertas_brecheables")
			local doorInfo = nil

			if (doorID) then
				doorInfo = plugin.doors[math.Round(doorID)]
				if (!doorInfo) then
					return "No existe una puerta con ID: " .. math.Round(doorID)
				end
				if (!doorInfo.isDestroyed) then
					return "La puerta ID " .. doorInfo.id .. " no está destruida."
				end
			else
				local myPos   = client:GetPos()
				local closest = math.huge
				for _, info in pairs(plugin.doors) do
					if (!info.isDestroyed or !IsValid(info.entity)) then continue end
					local dist = myPos:DistToSqr(info.entity:GetPos())
					if (dist < closest) then
						closest  = dist
						doorInfo = info
					end
				end
				if (!doorInfo) then
					return "No hay puertas destruidas registradas."
				end
			end

			timer.Remove("PB_Respawn_" .. doorInfo.id)
			plugin:RespawnDoor(doorInfo)

			client:ChatPrint("[Brechas] Puerta ID " .. doorInfo.id .. " restaurada.")
		end
	end
})

-- /MostrarPuertas
ix.command.Add("MostrarPuertas", {
	adminOnly   = true,
	description = "Activa/desactiva el overlay visual de puertas brecheables.",
	OnRun = function(self, client)
		if (SERVER) then
			local plugin = ix.plugin.Get("puertas_brecheables")
			plugin:SendDoorListTo(client)
		end
	end
})
