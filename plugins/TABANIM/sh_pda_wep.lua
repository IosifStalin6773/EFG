AddCSLuaFile()

local SWEP = {}

SWEP.PrintName = "PDA"
SWEP.Author = "Aaron"
SWEP.Instructions = "Quieres?"
SWEP.Category = "PDA"

SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.UseHands = true

SWEP.ViewModel      = "models/v_item_pda.mdl"
SWEP.WorldModel     = "models/v_item_pda.mdl"
SWEP.ViewModelFOV   = 80
SWEP.SwayScale      = 0.1
SWEP.BobScale       = 0.1

SWEP.Primary = {
  ClipSize = -1,
  DefaultClip = -1,
  Automatic = false,
  Ammo = "none"
}

SWEP.Secondary = {
  ClipSize = -1,
  DefaultClip = -1,
  Automatic = false,
  Ammo = "none"
}

local lastAngles = Angle(0, 0, 0)

function SWEP:Initialize()
  self:SetHoldType("camera")
end

function SWEP:Deploy()
  self:SendWeaponAnim(ACT_VM_DRAW)
  self:ResetSequence(self:LookupSequence("Draw"))
  self:EmitSound("Stalker2.PDAEquip")
end

function SWEP:Holster()
  -- Emitimos aquí también por seguridad al hacer holster directo
  self:EmitSound("Stalker2.PDAUnequip")
  return true
end

function SWEP:CalcView(player, pos, viewAngles, fov)
  local VModel = self:GetOwner():GetViewModel()
  local attachmentID = self:LookupAttachment("1")
  local attachment = self:GetAttachment(attachmentID)

  if attachment then
    if VModel:GetSequenceActivity(VModel:GetSequence()) == ACT_VM_DRAW then
      local newAngle = attachment.Ang - self:GetAngles()
      lastAngles = LerpAngle(0.1, lastAngles, newAngle)
      viewAngles:Add(lastAngles)
    elseif VModel:GetSequenceActivity(VModel:GetSequence()) == ACT_VM_HOLSTER then
      local newAngle = Angle(0, 0, 0)
      lastAngles = LerpAngle(0.1, lastAngles, newAngle)
      viewAngles:Add(lastAngles)
    end
  end

  return pos, viewAngles, fov
end

if CLIENT then
  local WorldModel = ClientsideModel(SWEP.WorldModel)
  WorldModel:SetNoDraw(true)

  function SWEP:DrawWorldModel()
    local _Owner = self:GetOwner()
    if (IsValid(_Owner)) then
      local offsetVec = Vector(-1, -4, -1.6)
      local offsetAng = Angle(15, -10, -165)
      local boneid = _Owner:LookupBone("ValveBiped.Bip01_R_Hand")
      if not boneid then return end

      local matrix = _Owner:GetBoneMatrix(boneid)
      if not matrix then return end

      local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
      WorldModel:SetPos(newPos)
      WorldModel:SetAngles(newAng)
      WorldModel:SetupBones()
    else
      WorldModel:SetPos(self:GetPos())
      WorldModel:SetAngles(self:GetAngles())
    end

    WorldModel:DrawModel()
  end
end

-- Registro del SWEP sin archivo en lua/weapons
if not weapons.Get("pda_spawnmenu") then
  weapons.Register(SWEP, "pda_spawnmenu")
end