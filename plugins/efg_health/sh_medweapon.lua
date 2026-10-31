-- Arma de medicina (efg_med): la mano con el objeto médico durante el uso.
-- La da ix.efg.medAnim.Start y se quita al terminar o al cambiar de arma.

local MA = ix.efg.medAnim

local SWEP = {}

SWEP.PrintName = "Medicina"
SWEP.Author = "EFG (animaciones y modelos: Craft_Pig, EFT Medical Items)"
SWEP.Category = "EFG"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.ViewModelFOV = 85
SWEP.ViewModel = MA.Model("injector", "v")
SWEP.WorldModel = MA.Model("injector", "w")
SWEP.UseHands = true
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false
SWEP.Slot = 5
SWEP.SlotPos = 9
SWEP.SwayScale = 0.15
SWEP.BobScale = 0.75
SWEP.HoldType = "slam"
SWEP.IsAlwaysRaised = true

-- SWEP es una tabla local: Primary hay que crearla antes de rellenarla
-- (sin esto el archivo fallaba en esta línea y weapons.Register nunca corría)
SWEP.Primary = {}
SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Secondary = table.Copy(SWEP.Primary)

function SWEP:SetupDataTables()
	self:NetworkVar("String", 0, "Profile")
	self:NetworkVar("Int", 0, "MedSkin")
	self:NetworkVar("Bool", 0, "MedActive")
	self:NetworkVar("Float", 0, "MedEnd")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:GetProfileData()
	return MA.profiles[self:GetProfile()]
end

-- Pone el modelo de vista del perfil actual (en los dos lados)
function SWEP:ApplyProfileModel()
	local profile = self:GetProfileData()
	if (!profile) then return end

	self.ViewModel = MA.Model(profile.vm, "v")
	self.WorldModel = MA.Model(profile.vm, "w")

	local owner = self:GetOwner()
	local vm = IsValid(owner) and owner:GetViewModel()

	if (IsValid(vm)) then
		if (SERVER and vm:GetModel() != self.ViewModel) then
			vm:SetWeaponModel(self.ViewModel, self)
		end

		if (vm:GetSkin() != self:GetMedSkin()) then
			vm:SetSkin(self:GetMedSkin())
		end
	end
end

function SWEP:ResetViewModel()
	local owner = self:GetOwner()
	local vm = IsValid(owner) and owner:GetViewModel()

	if (IsValid(vm)) then
		vm:SetSkin(0)
		vm:SetPlaybackRate(1)
	end
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

if (SERVER) then
	function SWEP:Begin(token)
		self.token = token
		self:SetProfile(token.profile)
		self:SetMedSkin(token.skin or 0)
		self:SetMedEnd(CurTime() + token.duration)
		self:SetMedActive(true)
		self.phase = nil
		self.loopIndex = 0
	end

	-- Duración de una actividad en el modelo de vista actual
	local function actDuration(vm, actName)
		local act = _G[actName]
		local seq = act and vm:SelectWeightedSequence(act)

		return (seq and seq >= 0) and vm:SequenceDuration(seq) or 0
	end

	-- fit: si se da, la secuencia se estira o encoge para durar eso
	function SWEP:PlayAct(actName, fit)
		local owner = self:GetOwner()
		local vm = IsValid(owner) and owner:GetViewModel()
		local act = _G[actName]
		if (!IsValid(vm) or !act) then return end

		self:SendWeaponAnim(act)

		local duration = vm:SequenceDuration()
		local rate = 1

		if (fit and fit > 0 and duration > 0) then
			rate = math.Clamp(duration / fit, 0.6, 1.6)
		end

		vm:SetPlaybackRate(rate)

		local real = duration / rate
		MA.PlayEvents(owner, self:GetProfileData().vm, actName, real)

		self.animEnd = CurTime() + real
	end

	function SWEP:Deploy()
		self:SetHoldType(self.HoldType)

		local profile = self:GetProfileData()
		if (!profile or !self:GetMedActive()) then return true end

		self:ApplyProfileModel()

		local owner = self:GetOwner()
		local vm = owner:GetViewModel()
		local remaining = math.max(self:GetMedEnd() - CurTime(), 0.3)

		self.phase = "enter"

		if (!profile.loop and !profile.exit) then
			-- una sola secuencia: dura todo el uso
			self:PlayAct(profile.enter, remaining)
		else
			local exitTime = profile.exit and actDuration(vm, profile.exit) or 0
			local enterTime = actDuration(vm, profile.enter)

			-- si no cabe la entrada a velocidad normal, se acelera
			self:PlayAct(profile.enter, enterTime + exitTime > remaining and math.max(remaining - exitTime, 0.3) or nil)
		end

		return true
	end

	function SWEP:Think()
		if (!self:GetMedActive() or !self.phase or self.phase == "done" or !self.animEnd or self.animEnd > CurTime()) then return end

		local profile = self:GetProfileData()
		local owner = self:GetOwner()
		if (!profile or !IsValid(owner)) then return end

		if (self.phase == "exit" or (!profile.loop and !profile.exit)) then
			self.phase = "done"
			self:SendWeaponAnim(ACT_VM_IDLE)
			return
		end

		local vm = owner:GetViewModel()
		local remaining = self:GetMedEnd() - CurTime()
		local exitTime = profile.exit and actDuration(vm, profile.exit) or 0

		if (profile.loop) then
			local nextAct = profile.loop[self.loopIndex % #profile.loop + 1]
			local loopTime = actDuration(vm, nextAct)

			if (remaining - exitTime >= loopTime * 0.6) then
				self.loopIndex = self.loopIndex + 1
				self.phase = "loop"
				self:PlayAct(nextAct, math.min(loopTime, remaining - exitTime))
				return
			end
		end

		if (profile.exit) then
			self.phase = "exit"
			self:PlayAct(profile.exit, math.max(remaining, 0.3))
		else
			self.phase = "done"
		end
	end

	-- Cambiar de arma antes de acabar cancela el uso (como en EFT)
	function SWEP:Holster()
		local token = self.token
		local owner = self:GetOwner()

		if (token and !token.finished and IsValid(owner)) then
			token.cancelled = true
			token.finished = true

			if (owner.efgMedUse == token) then owner.efgMedUse = nil end

			local item = ix.item.instances[token.item]
			if (item) then item:SetData("using", nil, nil, true) end

			owner.efgMedBusy = nil

			owner:SetAction()
			owner:Notify("Has dejado de usar la medicina.")

			timer.Simple(0, function()
				if (IsValid(owner) and !owner.efgMedUse and owner:HasWeapon(MA.class)) then
					owner:StripWeapon(MA.class)
				end
			end)
		end

		self:SetMedActive(false)
		self.token = nil
		self:ResetViewModel()

		return true
	end

	function SWEP:OnRemove()
		self:ResetViewModel()
	end

	function SWEP:OnDrop()
		self:Remove()
	end
else
	function SWEP:Deploy()
		self:ApplyProfileModel()
		return true
	end

	function SWEP:Holster()
		self:ResetViewModel()
		return true
	end

	function SWEP:Think()
		if (self:GetMedActive()) then
			self:ApplyProfileModel()
		end
	end

	-- La cámara sigue un poco el movimiento de las manos (como el addon)
	function SWEP:PostDrawViewModel(vm)
		local attachment = vm:GetAttachment(1)
		self.vmcamera = attachment and (vm:GetAngles() - attachment.Ang) or Angle(0, 0, 0)
	end

	function SWEP:CalcView(client, pos, ang, fov)
		local c = self.vmcamera
		if (!c) then return end

		-- normalizado para evitar el salto de -180/180 entre ángulos
		return pos, ang + Angle(math.NormalizeAngle(c.p), math.NormalizeAngle(c.y), math.NormalizeAngle(c.r)), fov
	end

	function SWEP:DrawHUD() end

	-- Objeto en la mano derecha en tercera persona
	local worldModels = {}

	function SWEP:DrawWorldModel()
		local profile = self:GetProfileData()
		local owner = self:GetOwner()

		if (!profile or !IsValid(owner)) then
			self:DrawModel()
			return
		end

		local path = MA.Model(profile.vm, "w")
		local model = worldModels[path]

		if (!IsValid(model)) then
			model = ClientsideModel(path, RENDERGROUP_OPAQUE)
			if (!IsValid(model)) then return end

			model:SetNoDraw(true)
			worldModels[path] = model
		end

		local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
		local matrix = bone and owner:GetBoneMatrix(bone)
		if (!matrix) then return end

		local pos, ang = LocalToWorld(Vector(4, -4, 5), Angle(0, -90, -180), matrix:GetTranslation(), matrix:GetAngles())

		model:SetSkin(self:GetMedSkin())
		model:SetPos(pos)
		model:SetAngles(ang)
		model:SetupBones()
		model:DrawModel()
	end
end

weapons.Register(SWEP, MA.class)
