-- Valores fijos de cámara — no configurables por el jugador
local CAM_VERTICAL   = 5
local CAM_HORIZONTAL = 15
local CAM_DISTANCE   = 27
local CAM_CLASSIC    = true

-- Solo el toggle de activar/desactivar queda en manos del jugador (Bloq Mayús)
ix.option.Add("thirdpersonEnabled", ix.type.bool, false, {
	category = "thirdperson",
	OnChanged = function(_, value)
		hook.Run("ThirdPersonToggled", value)
	end
})

-- Variables locales de estado de cámara
local traceMin    = Vector(-10, -10, -10)
local traceMax    = Vector(10, 10, 10)
local clmp        = math.Clamp
local crouchFactor = 0
local capslockWasDown = false

local view, traceData, traceData2, aimOrigin, ft, curAng, owner

-- Devuelve true si el servidor permite la tercera persona
local function isAllowed()
	return ix.config.Get("thirdperson", true)
end

-- Extiende la metatable Player con CanOverrideView (igual que Helix)
local playerMeta = FindMetaTable("Player")

function playerMeta:CanOverrideView()
	-- No activar si el menú de personaje está abierto
	if (IsValid(ix.gui.characterMenu) and !ix.gui.characterMenu:IsClosing()
		and ix.gui.characterMenu:IsVisible()) then
		return false
	end

	if (IsValid(ix.gui.menu) and ix.gui.menu:GetCharacterOverview()) then
		return false
	end

	if (ix.option.Get("thirdpersonEnabled", false) and
		!IsValid(self:GetVehicle()) and
		isAllowed() and
		IsValid(self) and
		self:GetCharacter() and
		!self:GetNetVar("actEnterAngle") and
		!IsValid(Entity(self:GetLocalVar("ragdoll", 0))) and
		LocalPlayer():Alive()) then
		return true
	end
end

-- Toggle con Bloq Mayús
hook.Add("Think", "ThirdPerson_KeyToggle", function()
	local isDown = input.IsKeyDown(KEY_CAPSLOCK)

	if (isDown and !capslockWasDown) then
		ix.option.Set("thirdpersonEnabled", !ix.option.Get("thirdpersonEnabled", false))
	end

	capslockWasDown = isDown
end)

-- Posicionamiento de la cámara con TraceHull y suavizado de agacharse
function PLUGIN:CalcView(client, origin, angles, fov)
	ft = FrameTime()

	if (client:CanOverrideView() and LocalPlayer():GetViewEntity() == LocalPlayer()) then
		local bNoclip = LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP

		-- Suaviza la transición al agacharse
		if ((client:OnGround() and client:KeyDown(IN_DUCK)) or client:Crouching()) then
			crouchFactor = Lerp(ft * 5, crouchFactor, 1)
		else
			crouchFactor = Lerp(ft * 5, crouchFactor, 0)
		end

		curAng = client.camAng or angle_zero

		traceData        = {}
		traceData.start  = client:GetPos()
			+ client:GetViewOffset()
			+ curAng:Up()    * CAM_VERTICAL
			+ curAng:Right() * CAM_HORIZONTAL
			- client:GetViewOffsetDucked() * 0.5 * crouchFactor
		traceData.endpos = traceData.start - curAng:Forward() * CAM_DISTANCE
		traceData.filter      = client
		traceData.ignoreworld = bNoclip
		traceData.mins        = traceMin
		traceData.maxs        = traceMax

		view         = {}
		view.origin  = util.TraceHull(traceData).HitPos
		aimOrigin    = view.origin
		view.angles  = curAng + client:GetViewPunchAngles()
		view.fov     = fov
		view.drawviewer = true

		-- Ajuste de ángulos de apunte según modo y movimiento
		traceData2        = {}
		traceData2.start  = aimOrigin
		traceData2.endpos = aimOrigin + curAng:Forward() * 65535
		traceData2.filter = client
		traceData2.ignoreworld = bNoclip

		local bClassic = CAM_CLASSIC
		local bMoving  = client:KeyDown(bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT))
			and client:GetVelocity():Length() >= 10

		if (bClassic or client:IsWepRaised() or bMoving) then
			client:SetEyeAngles((util.TraceLine(traceData2).HitPos - client:GetShootPos()):Angle())
		else
			local ang       = client:EyeAngles()
			ang.pitch       = (util.TraceLine(traceData2).HitPos - client:GetShootPos()):Angle().pitch
			client:SetEyeAngles(ang)
		end

		return view
	end
end

-- Rota los inputs de movimiento según la orientación de la cámara
function PLUGIN:CreateMove(cmd)
	owner = LocalPlayer()

	if (owner:CanOverrideView() and
		owner:GetMoveType() != MOVETYPE_NOCLIP and
		LocalPlayer():GetViewEntity() == LocalPlayer()) then

		local fm   = cmd:GetForwardMove()
		local sm   = cmd:GetSideMove()
		local diff = ((owner:EyeAngles() - (owner.camAng or Angle(0, 0, 0)))[2] or 0) / 90

		cmd:SetForwardMove(fm + sm * diff)
		cmd:SetSideMove(sm + fm * diff)
		return false
	end
end

-- Rotación de cámara independiente con el ratón
function PLUGIN:InputMouseApply(cmd, x, y, ang)
	owner = LocalPlayer()

	if (!owner.camAng) then
		owner.camAng = Angle(0, 0, 0)
	end

	owner.camAng.p = clmp(math.NormalizeAngle(owner.camAng.p + y / 50), -85, 85)
	owner.camAng.y = math.NormalizeAngle(owner.camAng.y - x / 50)

	if (owner:CanOverrideView() and LocalPlayer():GetViewEntity() == LocalPlayer()) then
		return true
	end
end

-- Muestra el modelo del jugador local en tercera persona
function PLUGIN:ShouldDrawLocalPlayer()
	local ply = LocalPlayer()
	if (ply:GetViewEntity() == ply and !IsValid(ply:GetVehicle())) then
		return ply:CanOverrideView()
	end
end
