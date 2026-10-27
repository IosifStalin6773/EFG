
if !ARC9 then return end

ENT.Type = "anim"
ENT.PrintName = "Weapon Workbench"
ENT.Category = "Helix - ARC9"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true

if (SERVER) then
    local PLUGIN = PLUGIN

    function ENT:Initialize()

        self:SetModel("models/props_wasteland/controlroom_desk001b.mdl")
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)

        local physObj = self:GetPhysicsObject()

        if (IsValid(physObj)) then
            physObj:EnableMotion(false)
            physObj:Sleep()
        end

        PLUGIN:SaveData()
    end

    function ENT:OnRemove()
        if !ix.shuttingDown then
            PLUGIN:SaveData()
        end
    end

    function ENT:Use(activator)
        if IsValid(activator) and (activator:GetPos():DistToSqr(self:GetPos()) < 100 * 100) and activator:GetCharacter() then
            if (activator.efgBenchNext or 0) > CurTime() then return end
            activator.efgBenchNext = CurTime() + 0.5

            local weapon = activator:GetActiveWeapon()

            if !IsValid(weapon) or !weapon.ARC9 then
                activator:Notify("Saca el arma que quieres modificar.")
                return
            end

            -- EFT: ventana DHTML de inspección/modding con el arma activa
            if ix.arc9.UseEFTInspect() then
                if !ix.arc9.OpenEFTInspect(activator, weapon) then
                    activator:Notify("Esta arma no es un objeto de tu inventario.")
                end
            else
                hook.Run("StartCustomizing", activator, weapon)
            end
        end
    end
else
    ENT.PopulateEntityInfo = true

    function ENT:OnPopulateEntityInfo(tooltip)

        if ix.option.Get("showWeaponBenchTooltip(ARC9)", true) then
            local name = tooltip:AddRow("name")
            name:SetImportant()
            name:SetText(self.PrintName)
            name:SizeToContents()

            local description = tooltip:AddRow("description")
            description:SetText("A workbench where you can customize your weapons with attachments.")
            description:SizeToContents()
        end
    end

    function ENT:Draw()
        self:DrawModel()
    end
end