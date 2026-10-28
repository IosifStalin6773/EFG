ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "Mesa de Inspección"
ENT.Author      = "IosifStalin#6773"
ENT.Category    = "Helix - Metro"
ENT.Spawnable   = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "LampOn")
    self:NetworkVar("String", 0, "StationName")
    self:NetworkVar("String", 1, "StationFaction")
    if (SERVER) then
        self:SetLampOn(false)
        self:SetStationName("Sin definir")
        self:SetStationFaction("")
    end
end