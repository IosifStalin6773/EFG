-- ============================================================
--  medico  |  sh_commands.lua  (SHARED)
--  Definición de comandos — compartido para que aparezcan
--  en el autocompletado del chat del cliente.
-- ============================================================

ix.command.Add("SpawnMedicoGuardia", {
	description = "Crea un NPC médico de guardia donde estás apuntando.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		local pos   = trace.HitPos + trace.HitNormal * 5

		-- Orientar al NPC mirando hacia el administrador.
		local ang = (client:GetPos() - pos):Angle()
		ang.pitch = 0
		ang.roll = 0

		local npc = ents.Create("ix_medico_guardia")
		if (!IsValid(npc)) then
			return client:Notify("No se pudo crear el médico de guardia.")
		end

		npc:SetPos(pos)
		npc:SetAngles(ang)
		npc:Spawn()
		npc:Activate()

		ix.medico = ix.medico or {}
		ix.medico.npcs = ix.medico.npcs or {}
		ix.medico.npcs[#ix.medico.npcs + 1] = {
			px = pos.x, py = pos.y, pz = pos.z, ay = ang.yaw,
			model = npc:GetModel(), anim = "",
		}
		local plugin = ix.plugin.Get("medico")
		if (plugin) then plugin:SaveData() end

		client:Notify("Médico de guardia creado.")
	end
})

ix.command.Add("RemoveMedicoGuardia", {
	description = "Elimina el médico de guardia al que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		local ent = client:GetEyeTrace().Entity
		if (!IsValid(ent) or ent:GetClass() != "ix_medico_guardia") then
			return client:Notify("No estás mirando a ningún médico de guardia.")
		end

		local pos = ent:GetPos()
		ix.medico = ix.medico or {}
		ix.medico.npcs = ix.medico.npcs or {}

		for i = #ix.medico.npcs, 1, -1 do
			local info = ix.medico.npcs[i]
			if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
				table.remove(ix.medico.npcs, i)
			end
		end

		local plugin = ix.plugin.Get("medico")
		if (plugin) then plugin:SaveData() end
		ent:Remove()
		client:Notify("Médico de guardia eliminado.")
	end
})

ix.command.Add("LimpiarHeridas", {
	description = "Elimina todas las heridas acumuladas de un personaje.",
	adminOnly = true,
	arguments = {
		ix.type.player,
	},
	OnRun = function(self, client, target)
		local character = target:GetCharacter()
		if (!character) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		character:SetHeridas(0)
		local plugin = ix.plugin.Get("medico")
		if (plugin) then plugin:AplicarHeridas(target, false) end

		target:Notify("Un administrador ha limpiado todas tus heridas.")
		client:Notify("Has limpiado las heridas de " .. target:Name() .. ".")
	end
})
