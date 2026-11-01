ENT.Type = "anim"
ENT.PrintName = "Contenedor de loot"
ENT.Author = "EFG Project"
ENT.Category = "EFG"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "LootType")
	self:NetworkVar("String", 1, "LootName")
end
