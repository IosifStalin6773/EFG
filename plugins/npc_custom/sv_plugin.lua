util.AddNetworkString("npc_OpenDialogue")
util.AddNetworkString("npc_AdminOpen")
util.AddNetworkString("npc_AdminSave")

-- ============================================================
--  Persistencia
-- ============================================================

function ix.npcs.GenerateID()
	ix.npcs.data = ix.npcs.data or {}
	local id
	repeat
		id = "npc_" .. os.time() .. "_" .. math.random(1000, 9999)
	until (not ix.npcs.data[id])
	return id
end

function PLUGIN:LoadData()
	ix.npcs.data = self:GetData() or {}
end

function PLUGIN:PostLoadData()
	timer.Simple(1, function()
		for key, info in pairs(ix.npcs.data or {}) do
			if (info.pos) then
				local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
				local ang = info.ang and Angle(info.ang.p, info.ang.y, info.ang.r) or angle_zero

				local exists = false
				for _, e in pairs(ents.FindByClass("ix_npc_custom")) do
					if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
						exists = true
						break
					end
				end

				if (not exists) then
					local ent = ents.Create("ix_npc_custom")
					if (IsValid(ent)) then
						ent.npcID = key
						ent:SetPos(pos)
						ent:SetAngles(ang)
						ent:Spawn()
						ent:SetupNPC(info)
					end
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(ix.npcs.data)
end

-- ============================================================
--  Net: Admin abre panel (desde diálogo del NPC)
-- ============================================================

net.Receive("npc_AdminOpen", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local ent = net.ReadEntity()
	if (not IsValid(ent) or ent:GetClass() != "ix_npc_custom") then return end
	if (client:GetPos():DistToSqr(ent:GetPos()) > 200 * 200) then return end

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
end)

-- ============================================================
--  Net: Admin guarda cambios
-- ============================================================

net.Receive("npc_AdminSave", function(len, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local ent = net.ReadEntity()
	if (not IsValid(ent) or ent:GetClass() != "ix_npc_custom") then return end
	if (client:GetPos():DistToSqr(ent:GetPos()) > 200 * 200) then return end

	local newName  = net.ReadString()
	local newDesc  = net.ReadString()
	local newModel = net.ReadString()
	local newAnim  = net.ReadString()

	local bgCount = net.ReadUInt(8)
	local newBodygroups = {}
	for i = 1, bgCount do
		local id  = net.ReadUInt(8)
		local val = net.ReadUInt(8)
		newBodygroups[id] = val
	end

	local dialoguesJSON = net.ReadString()
	local newDialogues = util.JSONToTable(dialoguesJSON)
	if (not newDialogues or not newDialogues.root) then
		client:Notify("Error: diálogos inválidos.")
		return
	end

	local modelChanged = (newModel != "" and newModel != (ent.npcModel or ent:GetModel()))

	ent.npcName        = newName != "" and newName or "NPC"
	ent.npcDescription = newDesc
	ent.npcAnim        = newAnim
	ent.npcBodygroups  = newBodygroups
	ent.dialogues      = newDialogues

	ent:SetNetVar("npcName", ent.npcName)
	ent:SetNetVar("npcDescription", ent.npcDescription)

	if (modelChanged) then
		local key = ent:GetPersistKey()
		local pos = ent:GetPos()
		local ang = ent:GetAngles()

		ent.npcModel = newModel
		ent._deleting = true
		ent:Remove()

		timer.Simple(0.1, function()
			local newEnt = ents.Create("ix_npc_custom")
			if (IsValid(newEnt)) then
				newEnt.npcID = key
				newEnt:SetPos(pos)
				newEnt:SetAngles(ang)
				newEnt:Spawn()

				local data = ix.npcs.data[key] or {}
				data.npcName        = newName != "" and newName or "NPC"
				data.npcDescription = newDesc
				data.npcModel       = newModel
				data.npcAnim        = newAnim
				data.npcBodygroups  = newBodygroups
				data.dialogues      = newDialogues
				ix.npcs.data[key]   = data

				newEnt:SetupNPC(data)
				newEnt:SaveToData()
			end
		end)
	else
		ent.npcModel = (newModel != "") and newModel or ent.npcModel
		ent:ApplyAppearance()
		ent:SaveToData()
	end
end)

