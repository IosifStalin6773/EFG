AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/z-o-m-b-i-e/metro_ll/ui/m_ll_typewriter_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then phys:Wake() end
end

local PRINTER_FACTIONS = {
    polis = true,
    cuartoreich = true,
    linearoja = true,
    hanza = true,
    ranger = true,
}

function ENT:Use(activator)
    if (not IsValid(activator) or not activator:IsPlayer()) then return end
    if (self._cool and self._cool > CurTime()) then return end
    self._cool = CurTime() + 1

    local faction = ix.faction.indices[activator:Team()]
    local uid = faction and faction.uniqueID or ""

    if (not PRINTER_FACTIONS[uid]) then
        activator:Notify("Tu facción no tiene autoridad para imprimir pasaportes.")
        return
    end

    net.Start("ix.passport.OpenEditor")
        net.WriteEntity(self)
    net.Send(activator)
end
