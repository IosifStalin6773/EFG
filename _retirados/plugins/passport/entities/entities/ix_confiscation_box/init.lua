-- gamemodes/ixmeter/plugins/passport/entities/entities/ix_confiscation_box/init.lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

----------------------------------------------------------------
-- Helpers de inventario (servidor)
----------------------------------------------------------------
local function SetEntityInventory(ent, inv)
    if not (IsValid(ent) and inv) then return end
    ent.ixInventory = inv

    -- ID en NetworkVar + NetVar (compat backwards)
    if ent.SetInventoryID then ent:SetInventoryID(inv:GetID()) end
    if ent.SetNetVar then ent:SetNetVar("inv", inv:GetID()) end

    inv.noBags = true -- opcional
end

local function GetInventoryByID(id)
    if not (istable(ix) and ix.item and ix.item.inventories) then return nil end
    return ix.item.inventories[id]
end

local function GetEntityInventory(ent)
    if not IsValid(ent) then return nil end

    local id = (ent.GetInventoryID and ent:GetInventoryID()) or 0

    -- cache coherente con el ID actual
    if ent.ixInventory and ent.ixInventory.GetID and ent.ixInventory:GetID() == id then
        return ent.ixInventory
    end

    local inv = (id > 0) and GetInventoryByID(id) or nil
    if inv then
        ent.ixInventory = inv
        return inv
    end

    return nil
end

----------------------------------------------------------------
-- Creación / Restauración (asíncrono)
----------------------------------------------------------------
function ENT:CreateInventory(cb)
    if not (ix and ix.inventory and ix.inventory.New) then
        if isfunction(cb) then cb(nil) end
        return
    end

    local w, h = self.invWidth or 8, self.invHeight or 6

    ix.inventory.New(0, "confiscation_box", function(newInv)
        if not IsValid(self) then return end
        if not newInv then
            if isfunction(cb) then cb(nil) end
            return
        end

        newInv:SetSize(w, h)
        newInv:SetOwner(0) -- contenedor del mundo
        SetEntityInventory(self, newInv)

        -- da 1 tick al core para registrar el inv en ix.item.inventories
        timer.Simple(0, function()
            if not IsValid(self) then return end
            if isfunction(cb) then cb(newInv) end
        end)
    end)
end

function ENT:RestoreInventory(id, cb)
    if not (ix and ix.inventory and ix.inventory.Restore) then
        if isfunction(cb) then cb(nil) end
        return
    end

    ix.inventory.Restore(id, function(restored)
        if not IsValid(self) then return end
        if restored then
            SetEntityInventory(self, restored)
            timer.Simple(0, function()
                if not IsValid(self) then return end
                if isfunction(cb) then cb(restored) end
            end)
        else
            -- si no se pudo restaurar, crear uno nuevo
            self:CreateInventory(cb)
        end
    end)
end

-- Garantiza inventario; cb(inv) puede recibir nil si algo falla
function ENT:EnsureInventory(cb)
    local inv = GetEntityInventory(self)
    if inv then
        if isfunction(cb) then cb(inv) end
        return
    end

    local id = (self.GetInventoryID and self:GetInventoryID()) or 0
    if id > 0 then
        self:RestoreInventory(id, cb)
    else
        self:CreateInventory(cb)
    end
end

----------------------------------------------------------------
-- Ciclo de vida
----------------------------------------------------------------
function ENT:Initialize()
    self:SetModel("models/props_c17/FurnitureDrawer001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    -- precalienta inventario (NO abre aquí)
    timer.Simple(0, function()
        if not IsValid(self) then return end
        self:EnsureInventory(function(_) end)
    end)
end

----------------------------------------------------------------
-- Interacción: SAFE-OPEN
----------------------------------------------------------------
function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    -- Vuelve a leer SIEMPRE de la tabla global por ID (evita referencias stale)
    local invID = (self.GetInventoryID and self:GetInventoryID()) or 0
    local inv   = (invID > 0) and GetInventoryByID(invID) or nil

    -- Simple validation like other working entities
    if not inv then
        -- fuerza init/restauración si aún no existe
        self:EnsureInventory(function(validInv)
            if IsValid(self) and validInv then
                -- Try opening again after ensuring inventory
                ix.storage.CloseCurrent(ply, validInv)
                ix.storage.Open(ply, validInv, {
                    name           = self.containerName or "Contenedor",
                    entity         = self,
                    searchTime     = 0,
                    bNoIcon        = false,
                    -- contenedor compartido del mundo: multiusuario para que un receptor
                    -- colgado (panel cerrado sin avisar al servidor) no lo deje "en uso"
                    -- para siempre. Ver persistent_corpses.lua / strongbox.
                    bMultipleUsers = true
                })
            end
        end)

        if ply.Notify then
            ply:Notify("El contenedor se está inicializando… vuelve a intentarlo en un segundo.")
        end
        return
    end

    -- Simple and direct approach like scavenging entity
    local success, err = pcall(function()
        ix.storage.CloseCurrent(ply, inv)
        ix.storage.Open(ply, inv, {
            name           = self.containerName or "Contenedor",
            entity         = self,
            searchTime     = 0,
            bNoIcon        = false,
            -- contenedor compartido del mundo: multiusuario para que un receptor
            -- colgado (panel cerrado sin avisar al servidor) no lo deje "en uso"
            -- para siempre. Ver persistent_corpses.lua / strongbox.
            bMultipleUsers = true
        })
    end)
    
    if not success then
        print("[ix_confiscation_box] ERROR: Failed to open storage:", err)
        print("[ix_confiscation_box] Inventory details:", type(inv), invID)
        
        -- Fallback: try to create fresh inventory and open
        self:CreateInventory(function(newInv)
            if IsValid(self) and newInv then
                local success2, err2 = pcall(function()
                    ix.storage.CloseCurrent(ply, newInv)
                    ix.storage.Open(ply, newInv, {
                        name           = self.containerName or "Contenedor",
                        entity         = self,
                        searchTime     = 0,
                        bNoIcon        = false,
                        -- contenedor compartido del mundo: multiusuario para que un
                        -- receptor colgado no lo deje "en uso" para siempre.
                        bMultipleUsers = true
                    })
                end)
                
                if not success2 then
                    ply:Notify("Error crítico: No se pudo abrir el contenedor.")
                    print("[ix_confiscation_box] Fallback also failed:", err2)
                end
            else
                ply:Notify("Error: No se pudo crear un inventario válido.")
            end
        end)
    end
end

----------------------------------------------------------------
-- API para el plugin (ConfiscateDoc lo usa)
----------------------------------------------------------------
function ENT:GetInventory()
    local id = (self.GetInventoryID and self:GetInventoryID()) or 0
    return (id > 0) and GetInventoryByID(id) or nil
end

function ENT:SetInventory(inv)
    SetEntityInventory(self, inv)
end