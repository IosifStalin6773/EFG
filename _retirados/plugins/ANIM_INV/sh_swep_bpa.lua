-- gamemodes/helix/plugins/stalker2_bpa/sh_swep_bpa.lua
local ID_WEAPON = "weapon_stalker2_bpa"
local SWEP = {}

-- if CLIENT then
--     SWEP.WepSelectIcon = surface.GetTextureID("vgui/hud/vgui_stalker2_bread")
--     SWEP.BounceWeaponIcon = true
--     SWEP.DrawWeaponInfoBox = true
-- end

SWEP.PrintName = "Backpack"
SWEP.Author = "Craft_Pig"
SWEP.Purpose = [[
]]
SWEP.Category = "S.T.A.L.K.E.R. 2"
-- SWEP.Category1 = "EFT"
-- SWEP.Category2 = "Medkits"

SWEP.ViewModelFOV = 70
SWEP.ViewModel = "models/weapons/ais/stalker2/bpa/v_bpa.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.DrawCrosshair = false
SWEP.Spawnable = false
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 0
SWEP.SlotPos = 0
SWEP.SwayScale = 0.15
SWEP.BobScale = 0.75
SWEP.IsAlwaysRaised = true

SWEP.Secondary = { Ammo = "none" }
SWEP.Primary   = { Ammo = "none", ClipSize = -1, Automatic = false, DefaultClip = 1 }
SWEP.DrawAmmo = false

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    self:SendWeaponAnim(ACT_VM_PULLBACK)
    local vm = IsValid(owner) and owner:GetViewModel()
    if IsValid(vm) then
        self.IdleTimer = CurTime() + vm:SequenceDuration()
    else
        self.IdleTimer = CurTime() + 0.1
    end
    self.Idle = 0
    self.IniHolster = 0
    if (SERVER and IsValid(owner)) then
        owner:SetWepRaised(true, self)
    end
    return true
end

function SWEP:Holster()
    if (SERVER) then
        local owner = self:GetOwner()
        if (IsValid(owner)) then
            owner:SetNetVar("raised", false)
        end
    end
    return true
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if self.Idle == 0 and (self.IdleTimer or 0) <= CurTime() then
        self.Idle = 1
        self:SendWeaponAnim(ACT_VM_IDLE)
    end
end

function SWEP:SecondaryHolster() end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    self:SendWeaponAnim(ACT_VM_PULLBACK_HIGH)
    local vm = owner:GetViewModel()
    if IsValid(vm) then
        self.IdleTimer = CurTime() + vm:SequenceDuration()
    end

    local SeqDur   = self:SequenceDuration()
    local SeqIndex = self:GetSequence()

    self:SetNextPrimaryFire(CurTime() + SeqDur)

     -- Ejecutar el cambio de arma SOLO en servidor para evitar errores en cliente
    if SERVER then
        local tName = "TimerSecondaryHolster_" .. owner:EntIndex()
        timer.Remove(tName)
        timer.Create(tName, SeqDur, 1, function()
            if not IsValid(self) or not IsValid(owner) or not owner:Alive() or not owner:IsPlayer() then return end

            -- Si el jugador volvió a abrir el inventario mientras el timer estaba
            -- pendiente, BPAIsOpen=true → no hacer nada (el abrir ya canceló el timer
            -- anterior, pero por si acaso este disparó entre mensajes de red).
            if owner.BPAIsOpen then return end

            owner.StalkerBPPrevWeapon = nil

            -- Solo forzar ix_hands si el jugador sigue con la mochila equipada.
            -- Si ya cambió de arma durante la animación de cierre, respetar su elección.
            local activeWep = owner:GetActiveWeapon()
            local stillHoldingBPA = IsValid(activeWep) and activeWep:GetClass() == ID_WEAPON

            if (stillHoldingBPA) then
                if not IsValid(owner:GetWeapon("ix_hands")) then
                    owner:Give("ix_hands")
                end
                owner:SelectWeapon("ix_hands")
            end

            -- Strip en el siguiente frame para que SelectWeapon termine antes
            timer.Simple(0, function()
                if IsValid(owner) and owner:HasWeapon(ID_WEAPON) then
                    owner:StripWeapon(ID_WEAPON)
                end
            end)
        end)
    end
end



function SWEP:SecondaryAttack() end
-- function SWEP:Holster() return false end

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

-- Registrar el SWEP dentro del plugin (sin archivo en lua/weapons)
weapons.Register(SWEP, ID_WEAPON)
