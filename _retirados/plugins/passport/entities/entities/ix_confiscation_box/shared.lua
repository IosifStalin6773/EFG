-- entities/entities/ix_confiscation_box/shared.lua
ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"  -- no dependemos de ix_container
ENT.PrintName       = "Contenedor de Documentos"
ENT.Author          = "IosifStalin#6773"
ENT.Category        = "Helix - Metro"
ENT.Spawnable       = true
ENT.AdminSpawnable  = true

-- Tamaño del inventario del contenedor (puedes ajustarlo)
ENT.invWidth        = 8
ENT.invHeight       = 6
ENT.containerName   = "Contenedor de Documentos Confiscados"
ENT.description     = "Caja sellada para custodiar documentos intervenidos."

-- Netvar para que clientes/servidor conozcan el ID del inventario
function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "InventoryID")
end