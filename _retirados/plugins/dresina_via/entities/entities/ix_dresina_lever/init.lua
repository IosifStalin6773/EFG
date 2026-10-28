AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_wasteland/tram_lever01.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(true)

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:EnableMotion(false)
	end
end

function ENT:Use(activator)
	if (!IsValid(activator) or !activator:IsPlayer()) then return end

	self.nextUse = self.nextUse or CurTime()
	if (self.nextUse > CurTime()) then return end
	self.nextUse = CurTime() + 1

	if (!isnumber(self.switchId)) then return end

	ix.dresinavia.ToggleSwitch(self.switchId, activator)
end
