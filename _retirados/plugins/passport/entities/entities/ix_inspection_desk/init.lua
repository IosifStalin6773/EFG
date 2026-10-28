AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Failsafe: pool de mensajes por si el plugin aún no corrió (idempotente)
if SERVER and util and util.AddNetworkString then
    util.AddNetworkString("ix.passport.OpenDesk")
    util.AddNetworkString("ix.passport.FetchPassportForDesk")
    util.AddNetworkString("ix.passport.DeskPassportData")
    util.AddNetworkString("ix.passport.SubmitDesk")
    util.AddNetworkString("ix.passport.ToggleLamp")
end

function ENT:Initialize()
    self:SetModel("models/z-o-m-b-i-e/metro_2033/furniture/m33_table_01.mdl") -- HL2 safe
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self._using = nil
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if self._using and IsValid(self._using) and self._using ~= ply then
        if ply.Notify then ply:Notify("La mesa está ocupada.") end
        return
    end

    self._using = ply
    timer.Create("ixInspectionDesk_Release_" .. self:EntIndex(), 10, 1, function()
        if IsValid(self) then self._using = nil end
    end)

    net.Start("ix.passport.OpenDesk")
        net.WriteEntity(self)
    net.Send(ply)
end

-- Liberar si el jugador se va
hook.Add("PlayerDisconnected", "ixInspectionDesk_Release", function(ply)
    for _, ent in ipairs(ents.FindByClass("ix_inspection_desk")) do
        if IsValid(ent) and ent._using == ply then
            ent._using = nil
        end
    end
end)