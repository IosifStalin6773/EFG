AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Recolectable"
ENT.Author = "Metro RP By Cono y Manperra"
ENT.Category = "Helix"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.AdminOnly = true
ENT.bNoPersist = true

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_junk/wood_crate001a.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:Wake()
			physObj:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		self.nextUse = self.nextUse or CurTime()

		if (self.nextUse > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1

		ix.harvest.Start(activator, self)
	end
end
