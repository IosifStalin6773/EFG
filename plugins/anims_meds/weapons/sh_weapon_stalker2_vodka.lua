if SERVER then
    AddCSLuaFile()
end

local SWEP = {}
SWEP.Base = "weapon_base"

SWEP.Primary = {}
SWEP.Secondary = {}

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/hud/vgui_stalker2_vodka")
    SWEP.BounceWeaponIcon = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.PrintName = "Vodka"
SWEP.Author = "Craft_Pig (portable)"
SWEP.Category = "S.T.A.L.K.E.R. 2"

SWEP.ViewModelFOV = 55
SWEP.ViewModel = "models/weapons/sweps/stalker2/vodka/v_item_vodka.mdl"
SWEP.WorldModel = "models/weapons/sweps/stalker2/vodka/w_item_vodka.mdl"
SWEP.UseHands = true
SWEP.IsAlwaysRaised = true

SWEP.DrawCrosshair = false
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 5
SWEP.SlotPos = 12
SWEP.SwayScale = 0.15
SWEP.BobScale = 0.75

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false

SWEP.Primary.Ammo = "vodka"
SWEP.Primary.ClipSize = -1
SWEP.Primary.Automatic = false
SWEP.Primary.DefaultClip = 1

SWEP.DrawAmmo = false

local ID_WEAPON = "weapon_stalker2_vodka"

local function SafeSelectPrevious(owner)
    if not IsValid(owner) then return end
    local prev = owner:GetPreviousWeapon()
    if IsValid(prev) and prev.GetClass then
        owner:SelectWeapon(prev:GetClass())
    end
end

function SWEP:Initialize()
    self:SetHoldType("slam")
    self.Consuming = false
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    self:SendWeaponAnim(ACT_VM_IDLE)
    if (SERVER and IsValid(owner)) then
        owner:SetWepRaised(true, self)
    elseif (CLIENT and owner == LocalPlayer()) then
        owner.ixRaisedFraction = 0
        owner.ixWasWeaponRaised = true
    end
    self.Consuming = true
    self:InitializeConsumable()
    return true
end

-- API opcional (por si quieres iniciarlo manualmente)
function SWEP:StartConsumeSequence()
    if self.Consuming then return end
    self.Consuming = true
    self:InitializeConsumable()
end

function SWEP:InitializeConsumable()
    local owner = self:GetOwner()
    if not IsValid(self) or not IsValid(owner) or not owner:IsPlayer() then
        self.Consuming = false
        return
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)

    if not SERVER then return end

    local dur = self:SequenceDuration()
    if not dur or dur <= 0 then dur = 1.5 end

    -- Momento del consumo (similar al addon original)
    timer.Simple(dur * 0.85, function()
        if not IsValid(self) or not IsValid(owner) or not owner:Alive() then return end
        if owner:GetActiveWeapon() ~= self then return end
    owner:EmitSound("Stalker2.Drink")
        hook.Run("Stalker2Consumable_Moment", owner, self, "vodka")
    end)

    -- Fin: quitar arma y volver a la anterior
    timer.Simple(dur, function()
        if not IsValid(self) then return end
        self.Consuming = false

        local ow = self:GetOwner()
        if not IsValid(ow) or not ow:Alive() then return end

        SafeSelectPrevious(ow)
        if IsValid(ow:GetWeapon(ID_WEAPON)) then
            ow:StripWeapon(ID_WEAPON)
        end
    end)
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Think() end

function SWEP:Holster()
    if self.Consuming then return false end
    return true
end

function SWEP:PostDrawViewModel(vm)
    local attachment = vm:GetAttachment(1)
    if attachment then
        self.vmcamera = vm:GetAngles() - attachment.Ang
    else
        self.vmcamera = Angle(0, 0, 0)
    end
end

function SWEP:CalcView(ply, pos, ang, fov)
    self.vmcamera = self.vmcamera or Angle(0, 0, 0)
    return pos, ang + self.vmcamera, fov
end

if CLIENT then
    local WorldModel = ClientsideModel(SWEP.WorldModel)
    if IsValid(WorldModel) then
        WorldModel:SetSkin(0)
        WorldModel:SetNoDraw(true)
    end

    function SWEP:DrawWorldModel()
        if not IsValid(WorldModel) then
            self:DrawModel()
            return
        end

        local owner = self:GetOwner()
        if IsValid(owner) then
            local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
            if not boneid then return end

            local matrix = owner:GetBoneMatrix(boneid)
            if not matrix then return end

            local offsetVec = Vector(3, -1, 1)
            local offsetAng = Angle(0, 0, -180)

            local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
            WorldModel:SetPos(newPos)
            WorldModel:SetAngles(newAng)
            WorldModel:SetupBones()
        else
            WorldModel:SetPos(self:GetPos())
            WorldModel:SetAngles(self:GetAngles())
            WorldModel:SetupBones()
        end

        WorldModel:DrawModel()
    end
end

weapons.Register(SWEP, ID_WEAPON)
