
-- weapons/sh_weapon_eft_afak.lua
if SERVER then AddCSLuaFile() end

local SWEP = {}
SWEP.PrintName      = "AFAK First Aid Kit"
SWEP.Author         = "Craft_Pig"
SWEP.Purpose        = [[Heals up to 30HP
Cures Bleeding]]
SWEP.Category       = "EFT"
SWEP.Category1      = "EFT"
SWEP.Category2      = "Medkits"

-- Modelos / vista
SWEP.ViewModelFOV   = 100
SWEP.ViewModel      = "models/weapons/sweps/eft/afak/v_meds_afak.mdl"
SWEP.WorldModel     = "models/weapons/sweps/eft/afak/w_meds_afak.mdl"
SWEP.UseHands       = true
SWEP.DrawCrosshair  = false

-- Spawn / slot / HUD
SWEP.Spawnable      = true
SWEP.Slot           = 5
SWEP.SlotPos        = 7
SWEP.DrawAmmo       = true

-- Movimiento arma
SWEP.SwayScale      = 0.15
SWEP.BobScale       = 0.75
SWEP.IsAlwaysRaised = true

-- Munición lógica del kit
SWEP.Primary                 = SWEP.Primary or {}
SWEP.Primary.Ammo            = "afak"
SWEP.Primary.ClipSize        = -1
SWEP.Primary.DefaultClip     = 400
SWEP.Primary.Automatic       = false

SWEP.Secondary               = SWEP.Secondary or {}
SWEP.Secondary.Ammo          = "none"
SWEP.Secondary.ClipSize      = -1
SWEP.Secondary.DefaultClip   = -1
SWEP.Secondary.Automatic     = false

SWEP.MaxHeal        = 30

local INI_SEF        = false
local INI_VIVO       = false
local ID_WEAPON      = "weapon_eft_afak"
local ID_PRIMARYAMMO = "afak"

-- Utilidad para reproducir anim en SV/CL con sensación inmediata
local function PlayVM(self, act)
    if SERVER then self:SendWeaponAnim(act) end
    if CLIENT and IsFirstTimePredicted() then self:SendWeaponAnim(act) end
end

function SWEP:Initialize()
    self:SetHoldType("slam")
    if file.Exists("lua/SEF/SEF_Functions.lua", "GAME") then INI_SEF = true end
    if file.Exists("lua/autorun/ojsshared.lua", "GAME") then INI_VIVO = true end
    self.IniAnimBandage = 0
    self.AnimTimes      = 0
    self.IniHeal        = 0
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    self.IniAnimBandage = 0
    self.AnimTimes      = 0
    self.IniHeal        = 0
    PlayVM(self, ACT_VM_IDLE)

    if IsValid(owner) and owner:GetAmmoCount(self.Primary.Ammo) == 0 then
        if SERVER then
            owner:StripWeapon(ID_WEAPON)
            local prev = owner:GetPreviousWeapon()
            if (IsValid(prev)) then owner:SelectWeapon(prev:GetClass()) end
        end
    end

    if (SERVER and IsValid(owner)) then
        owner:SetWepRaised(true, self)
    end

    return true
end

-- API expuesta para ítems de Helix: inicia la secuencia animada
function SWEP:StartBandageSequence(bHelixManaged)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if owner:GetAmmoCount(self.Primary.Ammo) == 0 then return end
    if self.IniAnimBandage == 1 or self.IniAnimSyringe == 1 or self.IniAnimPills == 1 then return end

    self.IniAnimBandage = 1
    self.AnimTimes      = 0
    self.IniHeal        = 0
    self.HelixManaged   = bHelixManaged or false

    PlayVM(self, ACT_VM_RECOIL1)
    if owner:GetViewModel() then
        self.IdleTimer = CurTime() + owner:GetViewModel():SequenceDuration()
    else
        self.IdleTimer = CurTime() + 0.6
    end

    -- Sonido de apertura (usa nombres de sh_sounds.lua)
    timer.Simple(0.6, function()
        if IsValid(self) and IsValid(owner) then
            if owner:GetActiveWeapon():GetClass() == ID_WEAPON then
                owner:EmitSound("MedsGrizzly.Open")
            end
        end
    end)
end

function SWEP:Heal()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if self.HelixManaged then
        self.HelixManaged = false
        self:Deploy()
        return
    end

    local VarMissingHealth = owner:GetMaxHealth() - owner:Health()
    local VarGetHealth     = math.min(VarMissingHealth, owner:GetAmmoCount(ID_PRIMARYAMMO))
    local VarHealHealth    = math.min(VarGetHealth, self.MaxHeal)

    if SERVER and owner:GetActiveWeapon():GetClass() == ID_WEAPON then
        local removedBleed = false

        if INI_SEF == true then
            if owner:HaveEffect("Bleeding") then
                owner:RemoveEffect("Bleeding")
                owner:RemoveAmmo(30, ID_PRIMARYAMMO)
                removedBleed = true
            end
        end

        if INI_VIVO == true then
            math.Round(OJSWounds:HealHP(owner, self.MaxHeal, VarHealHealth), 0)
            if (OJSWounds:HasStatusWholeBody(owner, "Bleed")) then
                OJSWounds:HealBleed(owner)
                owner:RemoveAmmo(30, ID_PRIMARYAMMO)
                removedBleed = true
            end
        else
            owner:SetHealth(math.min(owner:GetMaxHealth(), owner:Health() + VarHealHealth))
        end

        owner:RemoveAmmo(VarHealHealth, ID_PRIMARYAMMO)
        self:Deploy()

        hook.Run("EFT_MedApplied", owner, "afak", {
            healed       = VarHealHealth,
            bleedRemoved = removedBleed
        })
    end
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if owner:GetAmmoCount(self.Primary.Ammo) == 0 then return end
    if self.IniAnimBandage == 1 or self.IniAnimSyringe == 1 or self.IniAnimPills == 1 then return end

    self:StartBandageSequence()
end

function SWEP:SecondaryAttack() end

function SWEP:Think()
    local owner = self:GetOwner()
    if SERVER then
        if self.IniHeal == 1 and self.IdleTimer <= CurTime() then
            self.IniAnimBandage = 0
            self.AnimTimes      = 0
            self.IniHeal        = 0
            self:Heal()
        end

        if self.IniAnimBandage == 1 and self.AnimTimes <= 1 and self.IdleTimer <= CurTime() then
            local act = (math.random(1,2) == 1) and ACT_VM_RECOIL2 or ACT_VM_HITRIGHT
            PlayVM(self, act)
            if IsValid(owner) and owner:GetViewModel() then
                self.IdleTimer = CurTime() + owner:GetViewModel():SequenceDuration()
            else
                self.IdleTimer = CurTime() + 0.6
            end
            self.AnimTimes = self.AnimTimes + 1

        elseif self.IniAnimBandage == 1 and self.AnimTimes == 2 and self.IdleTimer <= CurTime() then
            PlayVM(self, ACT_VM_RECOIL3)
            if IsValid(owner) and owner:GetViewModel() then
                self.IdleTimer = CurTime() + owner:GetViewModel():SequenceDuration()
            else
                self.IdleTimer = CurTime() + 0.6
            end
            self.IniHeal = 1
        end
    end
end

function SWEP:Holster()
    if (self.IniAnimBandage == 1) then return false end
    if CLIENT then LocalPlayer():ConCommand("-attack") end
    return true
end

-- Ajuste de cámara (opcional)
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

-- WorldModel offset (lado cliente)
if CLIENT then
    local WorldModel = ClientsideModel("models/weapons/sweps/eft/afak/w_meds_afak.mdl")
    WorldModel:SetSkin(0)
    WorldModel:SetNoDraw(true)

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        if IsValid(owner) then
            local offsetVec = Vector(3, -4, 3)
            local offsetAng = Angle(-0, -0, -180)
            local boneid    = owner:LookupBone("ValveBiped.Bip01_R_Hand")
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

weapons.Register(SWEP, "weapon_eft_afak", true)
