local PLUGIN = PLUGIN
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

function ENT:Initialize()
    self:SetModel(Model('models/mosi/fallout4/furniture/workstations/weaponworkbench02.mdl'))
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
    if (client.metro_craftingstation || 0) > CurTime() then return end

    net.Start(PLUGIN.netNameCraftingGUI)
    net.WriteString('armas_armaduras')
    net.Send(client)

    client.metro_craftingstation = CurTime() + .5
end