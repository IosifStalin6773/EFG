ix.command.Add("CustomNPCSpawn", {
	description = "Spawnea un NPC personalizable.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		if (not trace.Hit) then
			client:Notify("No se encontró superficie.")
			return
		end

		local pos = trace.HitPos + trace.HitNormal * 5
		local ang = Angle(0, (client:GetPos() - pos):Angle().y, 0)

		local ent = ents.Create("ix_npc_custom")
		if (IsValid(ent)) then
			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:SetupNPC()
			ent:SaveToData()
			client:Notify("NPC spawneado.")
		end
	end
})

ix.command.Add("CustomNPCDelete", {
	description = "Elimina el NPC personalizable al que apuntas.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		local ent = trace.Entity
		if (not IsValid(ent) or ent:GetClass() != "ix_npc_custom") then
			client:Notify("Apunta a un NPC personalizable.")
			return
		end

		local key = ent:GetPersistKey()
		ix.npcs.data[key] = nil

		ent._deleting = true
		ent:Remove()

		local plugin = ix.plugin and ix.plugin.Get("npc_custom")
		if (plugin) then plugin:SaveData() end

		client:Notify("NPC eliminado.")
	end
})

ix.command.Add("CustomNPCAdmin", {
	description = "Abre el panel de admin del NPC al que apuntas.",
	adminOnly = true,
	OnRun = function(self, client)
		local trace = client:GetEyeTraceNoCursor()
		local ent = trace.Entity
		if (not IsValid(ent) or ent:GetClass() != "ix_npc_custom") then
			client:Notify("Apunta a un NPC personalizable.")
			return
		end

		local dialoguesJSON = util.TableToJSON(ent.dialogues or {})
		if (#dialoguesJSON > 60000) then
			client:Notify("Error: los diálogos son demasiado grandes para enviar.")
			return
		end

		local bodygroups = ent.npcBodygroups or {}
		local bgList = {}
		for id, val in pairs(bodygroups) do
			table.insert(bgList, {id = tonumber(id) or 0, val = tonumber(val) or 0})
		end

		net.Start("npc_AdminOpen")
			net.WriteEntity(ent)
			net.WriteString(ent.npcName or "NPC")
			net.WriteString(ent.npcDescription or "")
			net.WriteString(ent.npcModel or ent:GetModel())
			net.WriteString(ent.npcAnim or "")
			net.WriteUInt(#bgList, 8)
			for _, bg in ipairs(bgList) do
				net.WriteUInt(bg.id, 8)
				net.WriteUInt(bg.val, 8)
			end
			net.WriteString(dialoguesJSON)
		net.Send(client)
	end
})
