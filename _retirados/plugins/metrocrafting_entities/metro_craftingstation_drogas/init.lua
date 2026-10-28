local PLUGIN = PLUGIN
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

function ENT:Initialize()
	self:SetModel(Model('models/mosi/fallout4/furniture/workstations/chemistrystation01.mdl'))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(false)

	local physObj = self:GetPhysicsObject()
	if IsValid(physObj) then
		physObj:Wake()
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:Use(client, caller)
	if (client.metro_craftingstation_drogas || 0) > CurTime() then return end

	client.metro_craftingstation_drogas = CurTime() + .5

	local character = client:GetCharacter()
	if (not character) then return end

	if (character:GetFaction() != FACTION_BANDIT) then
		client:Notify('Solo los bandidos usan este laboratorio.')
		return
	end

	net.Start(PLUGIN.netNameCraftingGUI)
	net.WriteString('drogas')
	net.Send(client)
end
