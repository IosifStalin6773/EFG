AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/z-o-m-b-i-e/metro_2033/electro/m33_diesel_generator_01.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Wake()
	end
end

function ENT:UpdateTransmitState()
	-- Siempre transmitido: el cliente necesita los límites del área y el estado de
	-- energía (netvars) aunque no vea el prop, para aplicar el apagón de pantalla.
	return TRANSMIT_ALWAYS
end

function ENT:Use(client, caller)
	if (not IsValid(client) or not client:IsPlayer()) then return end
	if ((self.ixNextUse or 0) > CurTime()) then return end
	self.ixNextUse = CurTime() + 1

	-- El plugin se obtiene en runtime (no en el scope del archivo): las entidades
	-- se cargan ANTES de que el plugin se registre.
	local PLUGIN = ix.plugin.Get("generadores")
	if (not PLUGIN) then return end

	local entry = PLUGIN:GetGeneratorByID(self.genID)
	if (not entry) then return end

	PLUGIN:RefuelGenerator(entry, client)
end
