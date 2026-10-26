
if SERVER then AddCSLuaFile() end

SWEP = {}
if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/hud/vgui_morphine")
    SWEP.BounceWeaponIcon = true
    SWEP.DrawWeaponInfoBox = true
end

SWEP.PrintName = "Morphine"
SWEP.Author = "Craft_Pig (adaptado)"
SWEP.Purpose = [[Endurance 305s (15%), Hindered 120s (30u), cures Concussion/Dark Vision]]
SWEP.Category = "EFG"

SWEP.ViewModelFOV = 85
SWEP.ViewModel = "models/weapons/sweps/eft/injector/v_meds_injector.mdl"
SWEP.WorldModel = "models/weapons/sweps/eft/injector/w_meds_injector.mdl"

SWEP.UseHands = true
SWEP.DrawCrosshair = false
SWEP.Spawnable = true
SWEP.Slot = 5
SWEP.SlotPos = 7
SWEP.DrawAmmo = true
SWEP.SwayScale = 0.15
SWEP.BobScale = 0.75
SWEP.IsAlwaysRaised = true

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Ammo = "morphine"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false

SWEP.Secondary = SWEP.Secondary or {}
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false

SWEP.MaxHeal = 0

local INI_SEF = false
local ID_WEAPON      = "weapon_eft_injectormorphine"
local ID_PRIMARYAMMO = "morphine"

local function PlayVM(self, act)
    if SERVER then self:SendWeaponAnim(act) end
    if CLIENT and IsFirstTimePredicted() then self:SendWeaponAnim(act) end
end

function SWEP:Initialize()
    self:SetHoldType("slam")
    self.IniAnimBandage = 0
    self.AnimTimes = 0
    self.IniHeal = 0
    self.IdleTimer = 0

    if file.Exists("lua/SEF/SEF_Functions.lua", "GAME") then
        INI_SEF = true
    else
        INI_SEF = false
    end
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    self.IniAnimBandage = 0
    self.AnimTimes = 0
    self.IniHeal = 0
    PlayVM(self, ACT_VM_IDLE)

    -- set skin (1) como tu original
    timer.Simple(0.05, function()
        if IsValid(self) and IsValid(self.Owner) then
            local vm = self.Owner:GetViewModel()
            if IsValid(vm) then vm:SetSkin(1) end
        end
    end)

    if SERVER and IsValid(owner) then
        if owner:GetAmmoCount(self.Primary.Ammo) == 0 then
            owner:StripWeapon(ID_WEAPON)
            local prevW = owner:GetPreviousWeapon()
            if IsValid(prevW) and prevW.GetClass then
                owner:SelectWeapon(prevW:GetClass())
            end
        end
        owner:SetWepRaised(true, self)
    end
    return true
end

function SWEP:HealNow()
    local owner = self:GetOwner()
    if not IsValid(owner) or not SERVER then return end
    if owner:GetActiveWeapon():GetClass() ~= ID_WEAPON then return end

    if INI_SEF and owner.ApplyEffect then
        owner:ApplyEffect("Endurance", 305, 15)
        owner:ApplyEffect("Hindered", 120, 30)
        owner:RemoveEffect("Concussion")
        owner:RemoveEffect("DarkVision")
    end

    owner:RemoveAmmo(1, ID_PRIMARYAMMO)
    self:Deploy()
    hook.Run("EFT_MedApplied", owner, "morphine", { endurance = 305, hindered = 120, cures = {"Concussion","DarkVision"} })
end

function SWEP:StartInjectorSequence(customDur)
    if self.IniAnimBandage == 1 then return end
    PlayVM(self, ACT_VM_RECOIL1)
    local dur = tonumber(customDur) or 10.0
    self.IdleTimer = CurTime() + dur
    self.IniAnimBandage = 1
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if owner:GetAmmoCount(self.Primary.Ammo) == 0 then return end
    if self.IniAnimBandage == 1 or self.IniAnimSyringe == 1 or self.IniAnimPills == 1 then return end
    self:StartInjectorSequence(10.0)
end

function SWEP:SecondaryAttack() end

function SWEP:Think()
    if SERVER and self.IniAnimBandage == 1 and self.IdleTimer <= CurTime() then
        self.IniAnimBandage = 0
        self:HealNow()
    end
end

function SWEP:Holster()
    if (self.IniAnimBandage == 1) then return false end
    if CLIENT then LocalPlayer():ConCommand("-attack") end
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
    WorldModel:SetSkin(1)
    WorldModel:SetNoDraw(true)
    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        if IsValid(owner) then
            local offsetVec = Vector(3, -1, 2)
            local offsetAng = Angle(-180, 0, 0)
            local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
            if not boneid then return end
            local matrix = owner:GetBoneMatrix(boneid)
            if not matrix then return end
            local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
            WorldModel:SetPos(newPos)
            WorldModel:SetAngles(newAng)
            WorldModel:SetupBones()
        else
            WorldModel:SetPos(self:GetPos())
            WorldModel:SetAngles(self:GetAngles())
            self:DrawModel()
        end
        WorldModel:DrawModel()
    end
end

