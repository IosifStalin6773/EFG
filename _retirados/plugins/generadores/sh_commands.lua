-- Comandos del sistema de generadores. Se definen en el realm compartido para el
-- autocompletado del cliente; el OnRun se ejecuta siempre en el servidor.

-- Crea un área de generador en dos pasos (mirando al suelo) y coloca el generador
-- en el centro del área, con el tanque lleno.
ix.command.Add("createGenArea", {
	description = "Crea un área de generador en dos pasos (mira a cada esquina) y coloca el generador con el tanque lleno.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("generadores")
		if (not plugin) then return end

		local pos = client:GetEyeTraceNoCursor().HitPos

		if (not client.ixGenCorner1) then
			client.ixGenCorner1 = pos
			client:Notify("Esquina 1 del SUELO fijada. Mira a la esquina opuesta del suelo y ejecuta /createGenArea de nuevo.")
		else
			local c1 = client.ixGenCorner1
			local c2 = pos
			client.ixGenCorner1 = nil

			-- Las dos esquinas definen el rectángulo (XY) en el suelo; el área se
			-- eleva hacia arriba una altura configurable para cubrir el techo (y sus
			-- luces) y a los jugadores de pie.
			local altura = ix.config.Get("gen_area_altura", 320)
			local minX, maxX = math.min(c1.x, c2.x), math.max(c1.x, c2.x)
			local minY, maxY = math.min(c1.y, c2.y), math.max(c1.y, c2.y)
			local floorZ = math.min(c1.z, c2.z)

			local vMin = Vector(minX, minY, floorZ - 8)
			local vMax = Vector(maxX, maxY, floorZ + altura)

			-- El generador se coloca en el centro del área, apoyado en el suelo.
			local center = Vector((minX + maxX) * 0.5, (minY + maxY) * 0.5, floorZ + 16)
			local tr = util.TraceLine({
				start = center,
				endpos = center - Vector(0, 0, 256),
				filter = client,
			})

			local genPos = tr.Hit and tr.HitPos or Vector(center.x, center.y, floorZ)
			local genAng = Angle(0, client:EyeAngles().y, 0)

			plugin:AddGenerator(vMin, vMax, genPos, genAng)

			client:Notify(string.format("Generador creado (tanque lleno %dh, área de %d unidades de alto).",
				ix.config.Get("gen_max_horas", 24), altura))
		end
	end
})

-- Elimina el generador (y su área) en el que se encuentra el administrador.
ix.command.Add("removeGenArea", {
	description = "Elimina el generador y su área en el que estás situado.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("generadores")
		if (not plugin) then return end

		local entry = ix.generadores.getGeneratorAt(client:GetPos() + client:OBBCenter())
		if (not entry) then
			return client:Notify("No estás dentro del área de ningún generador.")
		end

		plugin:RemoveGenerator(entry)
		client:Notify("Generador y su área eliminados.")
	end
})

-- Muestra el estado del generador en el que estás.
ix.command.Add("genInfo", {
	description = "Muestra el combustible y el estado del generador en el que estás.",
	adminOnly = true,
	OnRun = function(self, client)
		local entry = ix.generadores.getGeneratorAt(client:GetPos() + client:OBBCenter())
		if (not entry) then
			return client:Notify("No estás dentro del área de ningún generador.")
		end

		client:ChatPrint(string.format("[Generador #%d] Combustible: %s | Energía: %s",
			entry.id, GeneratorFormatFuel(entry.fuel), entry.powered and "ENCENDIDO" or "APAGADO"))
	end
})

-- Ajusta manualmente el combustible del generador en el que estás (horas). Útil
-- para pruebas (p. ej. /setGenFuel 0 para simular que se agota).
ix.command.Add("setGenFuel", {
	description = "Establece el combustible (en horas) del generador en el que estás.",
	adminOnly = true,
	arguments = {
		ix.type.number,
	},
	OnRun = function(self, client, hours)
		local plugin = ix.plugin.Get("generadores")
		if (not plugin) then return end

		local entry = ix.generadores.getGeneratorAt(client:GetPos() + client:OBBCenter())
		if (not entry) then
			return client:Notify("No estás dentro del área de ningún generador.")
		end

		local maxFuel = ix.config.Get("gen_max_horas", 24) * 3600
		entry.fuel = math.Clamp(hours * 3600, 0, maxFuel)
		plugin:SetGeneratorPowered(entry, entry.fuel > 0)
		plugin:UpdateGeneratorNetVars(entry)
		plugin:SaveData()

		client:Notify("Combustible ajustado a " .. GeneratorFormatFuel(entry.fuel) .. ".")
	end
})
