AddCSLuaFile()

SWEP.PrintName = "Using medkit..."
SWEP.Author = "JohnyReaper"
SWEP.Purpose = ""
SWEP.Category = ""

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = false

SWEP.ViewModel = Model( "models/weapons/krycek/metro_2k33/v_medkit.mdl" )
SWEP.WorldModel = Model( "models/weapons/krycek/metro_2k33/fx_empty.mdl" )
SWEP.ViewModelFOV = 70
SWEP.UseHands = true
SWEP.HoldType 				= "normal"

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= 1
SWEP.Secondary.DefaultClip	= 1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

local HealSound = Sound( "K_Metro_Medkit_Use" )
local DenySound = Sound( "WallHealth.Deny" )
	
function SWEP:OnRemove()
end

if SERVER then
	function SWEP:Deploy()
		self.Owner:EmitSound( HealSound )
		local client = self.Owner

		if client.syringeAnim == 0 or client.syringeAnim == nil then
			client.syringeAnim = 1
		end
		
		local vm = self.Owner:GetViewModel()
		vm:SendViewModelMatchingSequence( vm:LookupSequence( 6 - client.syringeAnim ) )
		self.Owner:ViewPunch( Angle( 3,0,0 ) )

		
	end
end

function SWEP:Holster()
	return true
end


function SWEP:OnRemove()
	return true
end


function SWEP:PrimaryAttack()
	return false
end;


function SWEP:SecondaryAttack()
	return false
end

