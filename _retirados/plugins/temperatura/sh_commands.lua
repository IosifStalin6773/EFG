-- Comandos del sistema de temperatura. Se definen en el realm compartido para que
-- el cliente tenga autocompletado; el OnRun se ejecuta siempre en el servidor.

-- Abre el menú de administración de temperatura (ambiente global + zonas).
ix.command.Add("FrioAdmin", {
	description = "Abre el menú de administración de temperatura (ambiente global y zonas de frío).",
	adminOnly = true,
	OnRun = function(self, client)
		ix.temperatura.sendAdminData(client)
	end
})

-- Crea una zona fría en dos pasos: primer uso fija una esquina (mirando al suelo)
-- con la temperatura indicada; segundo uso fija la esquina opuesta y crea la zona.
ix.command.Add("FrioZona", {
	description = "Crea una zona fría en dos pasos. La primera vez indica la temperatura (°C); la segunda fija la esquina opuesta.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.number, ix.type.optional),
	},
	OnRun = function(self, client, temp)
		local pos = client:GetEyeTraceNoCursor().HitPos

		if (not client.ixFrioMin) then
			client.ixFrioMin = pos
			client.ixFrioTemp = math.Round(tonumber(temp) or -20)
			client:Notify("Esquina 1 fijada (" .. client.ixFrioTemp .. "°C). Mira a la esquina opuesta y ejecuta /FrioZona de nuevo.")
		else
			ix.temperatura.addArea(client.ixFrioMin, pos, client.ixFrioTemp)

			local plugin = ix.plugin.Get("temperatura")
			if (plugin) then plugin:SaveData() end

			client:Notify("Zona fría creada (" .. client.ixFrioTemp .. "°C).")

			client.ixFrioMin = nil
			client.ixFrioTemp = nil

			if (client.ixTempShowZones) then
				ix.temperatura.sendZones(client, true)
			end
		end
	end
})

-- Elimina la zona fría en la que se encuentra el administrador.
ix.command.Add("FrioQuitar", {
	description = "Elimina la zona fría en la que estás situado.",
	adminOnly = true,
	OnRun = function(self, client)
		local pos = client:GetPos() + client:OBBCenter()
		local index = ix.temperatura.getAreaAt(pos)

		if (not index) then
			return client:Notify("No estás dentro de ninguna zona fría.")
		end

		ix.temperatura.removeArea(index)

		local plugin = ix.plugin.Get("temperatura")
		if (plugin) then plugin:SaveData() end

		client:Notify("Zona fría eliminada.")

		if (client.ixTempShowZones) then
			ix.temperatura.sendZones(client, true)
		end
	end
})

-- Activa/desactiva la visualización de las zonas frías (wireframe) para el admin.
ix.command.Add("FrioMostrar", {
	description = "Muestra u oculta las zonas frías como cajas wireframe.",
	adminOnly = true,
	OnRun = function(self, client)
		client.ixTempShowZones = not client.ixTempShowZones
		ix.temperatura.sendZones(client, client.ixTempShowZones)
	end
})

-- Establece manualmente la congelación de un personaje (0-100).
ix.command.Add("SetCongelacion", {
	description = "Establece la congelación de un personaje (0-100).",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number,
	},
	OnRun = function(self, client, target, amount)
		local char = target:GetCharacter()
		if (not char) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		local value = math.Clamp(math.floor(amount), 0, 100)
		char:SetCongelacion(value)

		target:Notify("Un administrador ha establecido tu congelación en " .. value .. ".")
		client:Notify("Has establecido la congelación de " .. target:Name() .. " en " .. value .. ".")
	end
})

-- Pone la congelación de un personaje a 0.
ix.command.Add("LimpiarCongelacion", {
	description = "Pone la congelación de un personaje a 0.",
	adminOnly = true,
	arguments = {
		ix.type.player,
	},
	OnRun = function(self, client, target)
		local char = target:GetCharacter()
		if (not char) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		char:SetCongelacion(0)

		target:Notify("Un administrador ha limpiado tu congelación.")
		client:Notify("Has limpiado la congelación de " .. target:Name() .. ".")
	end
})
