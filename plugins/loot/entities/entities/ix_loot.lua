AddCSLuaFile()

ENT.Type           = "anim"
ENT.PrintName      = "Loot Container"
ENT.Author         = "EFG Project"
ENT.Category       = "Helix"
ENT.Spawnable      = false
ENT.AdminSpawnable = false
ENT.AdminOnly      = true
ENT.bNoPersist     = true

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
		self:SetNetVar("areaName", "")
		self:SetNetVar("name", "")
		self:SetNetVar("tier", "t1")
		self:SetNetVar("color", Color(220, 120, 40))

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:Wake()
			physObj:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator)) then return end

		self.nextUse = self.nextUse or CurTime()
		if (self.nextUse > CurTime()) then return end
		self.nextUse = CurTime() + 4

		ix.loot.StartSearch(activator, self)
	end
end
