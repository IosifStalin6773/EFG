ix.command.Add("SetTimbre", {
	description = "Asigna un timbre al prop que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		local entity = trace.Entity

		if (!IsValid(entity) or entity == game.GetWorld()) then
			client:Notify("No estás mirando a ningún prop.")
			return
		end

		local plugin = ix.plugin.Get("timbres")
		plugin.timbres = plugin.timbres or {}
		local existing = plugin:GetTimbreByEntity(entity)

		if (existing) then
			client:Notify("Este prop ya tiene un timbre asignado.")
			return
		end

		local pos = entity:WorldSpaceCenter()
		local mapID = entity:MapCreationID()
		local id = tostring(os.time()) .. "_" .. math.random(1000, 9999)

		plugin.timbres[id] = {
			pos = {pos.x, pos.y, pos.z},
			mapCreationID = (mapID and mapID >= 0) and mapID or nil
		}
		plugin:SaveTimbres()

		client:Notify("Timbre asignado al prop.")
	end
})

ix.command.Add("RemoveTimbre", {
	description = "Elimina el timbre del prop que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		local entity = trace.Entity

		if (!IsValid(entity) or entity == game.GetWorld()) then
			client:Notify("No estás mirando a ningún prop.")
			return
		end

		local plugin = ix.plugin.Get("timbres")
		plugin.timbres = plugin.timbres or {}
		local id = plugin:GetTimbreByEntity(entity)

		if (!id) then
			client:Notify("Este prop no tiene un timbre asignado.")
			return
		end

		plugin.timbres[id] = nil
		plugin:SaveTimbres()

		client:Notify("Timbre eliminado del prop.")
	end
})

ix.command.Add("MostrarTimbres", {
	description = "Activa o desactiva la visualización de los timbres en el mapa.",
	adminOnly = true,
	OnRun = function(self, client)
		local plugin = ix.plugin.Get("timbres")
		plugin.timbres = plugin.timbres or {}
		local list = {}
		local idx = 1

		for id, data in pairs(plugin.timbres) do
			table.insert(list, {
				idx = idx,
				pos = data.pos
			})
			idx = idx + 1
		end

		net.Start("timbres_PointsData")
			net.WriteString(util.TableToJSON(list))
		net.Send(client)
	end
})
