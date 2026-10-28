AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props/cs_militia/footlocker01_closed.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(false)

	local physObj = self:GetPhysicsObject()
	if (IsValid(physObj)) then
		physObj:EnableMotion(false)
		physObj:Sleep()
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:Use(activator)
	if (not IsValid(activator) or not activator:IsPlayer()) then return end

	self.nextUse = self.nextUse or CurTime()
	if (self.nextUse > CurTime()) then return end
	self.nextUse = CurTime() + 0.5

	local character = activator:GetCharacter()
	if (not character) then return end

	if (character:GetFaction() != FACTION_HANZA) then
		activator:Notify("Esta hucha pertenece a Hanza. No tienes acceso a ella.")
		return
	end

	local PLUGIN = ix.plugin.Get("arcas_hanza")
	if (not PLUGIN) then return end

	net.Start(PLUGIN.netOpen)
		net.WriteEntity(self)
		net.WriteUInt(math.Clamp(ix.arcas.hanza or 0, 0, 4294967295), 32)
	net.Send(activator)
end
