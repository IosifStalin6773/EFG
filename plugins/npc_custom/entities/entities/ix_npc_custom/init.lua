AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_MODEL = "models/magma/civilian/intro_civ.mdl"

local DEFAULT_DIALOGUES = {
	root = {
		text = "Hola, viajero. ¿Qué necesitas?",
		options = {
			{label = "Adiós.", action = "close"},
		}
	}
}

function ENT:Initialize()
	self:SetModel(DEFAULT_MODEL)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(true)
	self:SetCollisionGroup(COLLISION_GROUP_NPC)

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Wake()
	end

	self.lastUse       = {}
	self.npcName        = "NPC"
	self.npcDescription = ""
	self.npcModel       = nil
	self.npcAnim        = ""
	self.npcBodygroups  = {}
	self.dialogues      = table.Copy(DEFAULT_DIALOGUES)
end

function ENT:ApplyAppearance()
	local model = self.npcModel or DEFAULT_MODEL
	if (util.IsValidModel(model)) then
		self:SetModel(model)
	end
	self:SetNetVar("npcModel", self:GetModel())
	self:SetNetVar("npcAnim", self.npcAnim or "")

	for id, val in pairs(self.npcBodygroups or {}) do
		self:SetBodygroup(tonumber(id) or 0, tonumber(val) or 0)
	end

	if (self.npcAnim and self.npcAnim != "") then
		local seq = self:LookupSequence(self.npcAnim)
		if (seq and seq > 0) then
			self:ResetSequence(seq)
			self:SetPlaybackRate(1)
		end
	end
end

function ENT:Spawn()
	self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
	if (not self._setupDone) then
		self:SetupNPC()
	end
end

function ENT:SetupNPC(data)
	self._setupDone = true

	if (data) then
		self.npcName        = data.npcName or "NPC"
		self.npcDescription = data.npcDescription or ""
		self.npcModel       = data.npcModel or nil
		self.npcAnim        = data.npcAnim or ""
		self.npcBodygroups  = data.npcBodygroups or {}
		self.dialogues      = data.dialogues or table.Copy(DEFAULT_DIALOGUES)
	end

	self:SetNetVar("npcName", self.npcName)
	self:SetNetVar("npcDescription", self.npcDescription)
	self:ApplyAppearance()
end

function ENT:Think()
	if (self.npcAnim and self.npcAnim != "") then
		self:FrameAdvance()
	end
	self:NextThink(CurTime())
	return true
end

function ENT:GetPersistKey()
	if (not self.npcID) then
		self.npcID = ix.npcs.GenerateID()
	end
	return self.npcID
end

function ENT:Use(activator)
	if (not IsValid(activator) or not activator:IsPlayer()) then return end
	if (not activator:GetCharacter()) then return end

	local steamID = activator:SteamID()
	self.lastUse = self.lastUse or {}
	if (self.lastUse[steamID] and self.lastUse[steamID] > CurTime()) then
		return
	end
	self.lastUse[steamID] = CurTime() + 1

	local dialoguesJSON = util.TableToJSON(self.dialogues or DEFAULT_DIALOGUES)

	if (#dialoguesJSON > 60000) then
		activator:Notify("Error: los diálogos de este NPC son demasiado grandes.")
		return
	end

	net.Start("npc_OpenDialogue")
		net.WriteEntity(self)
		net.WriteString(self.npcName or "NPC")
		net.WriteString(dialoguesJSON)
	net.Send(activator)
end

function ENT:SaveToData()
	ix.npcs.data = ix.npcs.data or {}
	local key = self:GetPersistKey()
	local pos = self:GetPos()
	local ang = self:GetAngles()
	ix.npcs.data[key] = {
		npcID          = key,
		pos            = {x = pos.x, y = pos.y, z = pos.z},
		ang            = {p = ang.p, y = ang.y, r = ang.r},
		npcName        = self.npcName,
		npcDescription = self.npcDescription,
		npcModel       = self.npcModel,
		npcAnim        = self.npcAnim,
		npcBodygroups  = self.npcBodygroups or {},
		dialogues      = self.dialogues or {},
	}
	local plugin = ix.plugin and ix.plugin.Get("npc_custom")
	if (plugin) then
		plugin:SaveData()
	end
end

function ENT:OnRemove()
	if (self._deleting) then return end
	self:SaveToData()
end

function ENT:PhysgunPickup(ply)
	if (not ply:IsAdmin()) then return false end
	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then phys:EnableMotion(true) end
	return true
end

function ENT:PhysgunDrop(ply)
	timer.Simple(0.5, function()
		if (not IsValid(self)) then return end
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then phys:EnableMotion(false) end
		self:SaveToData()
	end)
end
