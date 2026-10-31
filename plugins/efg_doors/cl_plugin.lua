local PLUGIN = PLUGIN
local DOORS = ix.efg.doors

-- puerta a la que se apunta y opción elegida con la rueda
local menu = {door = nil, index = 1, signature = ""}
local keyhole = {active = false}

local function lookDoor(client)
	local shootPos = client:GetShootPos()
	local trace = util.TraceLine({
		start = shootPos,
		endpos = shootPos + client:GetAimVector() * DOORS.range,
		filter = client
	})

	if (DOORS.IsManaged(trace.Entity)) then
		return trace.Entity
	end
end

local function current()
	local client = LocalPlayer()

	if (!ix.config.Get("efgDoors", true) or keyhole.active or vgui.CursorVisible()) then return end
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	local door = lookDoor(client)

	if (!door) then
		menu.door = nil
		return
	end

	local actions = DOORS.GetActions(door)
	local signature = table.concat(actions, ",")

	if (door != menu.door or signature != menu.signature) then
		menu.door, menu.signature, menu.index = door, signature, 1
	end

	menu.index = math.Clamp(menu.index, 1, #actions)

	return door, actions
end

-- efg_hud pinta la lista con su cursor de interacción (mano + etiquetas)
-- false = no pintar nada (p. ej. mirando por la mirilla)
function PLUGIN:EFGInteraction(client, entity)
	if (keyhole.active) then return false end

	local door, actions = current()
	if (!door or door != entity) then return end

	local options = {}

	for i, id in ipairs(actions) do
		options[i] = L(DOORS.actions[id].label)
	end

	local _, locked = DOORS.GetState(door)

	return options[menu.index], L(locked and "efgDoorNameLocked" or "efgDoorName"), options, menu.index
end

local exitBinds = {"+use", "+jump", "+attack", "+attack2", "+forward", "+back", "+moveleft", "+moveright", "+duck", "+reload"}

function PLUGIN:PlayerBindPress(client, bind, pressed)
	if (!pressed) then return end

	if (keyhole.active) then
		for _, exit in ipairs(exitBinds) do
			if (bind:find(exit, 1, true)) then
				net.Start("efgDoorKeyhole")
				net.SendToServer()
				return true
			end
		end

		return
	end

	local door, actions = current()
	if (!door) then return end

	-- la rueda (invnext / invprev) mueve la selección; ix_invkey la bloquea
	-- con hook.Add, que corre después de los hooks de plugin
	if (bind == "invnext") then
		menu.index = menu.index % #actions + 1
		surface.PlaySound("ui/buttonrollover.wav")
		return true
	elseif (bind == "invprev") then
		menu.index = (menu.index - 2) % #actions + 1
		surface.PlaySound("ui/buttonrollover.wav")
		return true
	elseif (bind:find("+use", 1, true)) then
		net.Start("efgDoorAction")
			net.WriteEntity(door)
			net.WriteString(actions[menu.index])
		net.SendToServer()
		return true
	end
end

net.Receive("efgDoorNotice", function()
	local text = L(net.ReadString())
	local red = net.ReadBool()

	if (ix.efg.hud and ix.efg.hud.Notify) then
		ix.efg.hud.Notify(text, red)
	else
		ix.util.Notify(text)
	end
end)

-- ─── Mirilla ─────────────────────────────────────────────────────────────────
net.Receive("efgDoorKeyhole", function()
	keyhole.active = net.ReadBool()

	if (keyhole.active) then
		keyhole.pos = net.ReadVector()
		keyhole.ang = net.ReadAngle()
		keyhole.yaw, keyhole.pitch = 0, 0
		surface.PlaySound("doors/door_latch1.wav")
	end
end)

function PLUGIN:CalcView(client, origin, angles, fov)
	if (!keyhole.active) then return end

	return {
		origin = keyhole.pos,
		angles = keyhole.ang + Angle(keyhole.pitch, keyhole.yaw, 0),
		fov = 60,
		drawviewer = true
	}
end

function PLUGIN:ShouldDrawLocalPlayer()
	if (keyhole.active) then return true end
end

function PLUGIN:InputMouseApply(cmd, x, y)
	if (!keyhole.active) then return end

	keyhole.yaw = math.Clamp(keyhole.yaw - x * 0.02, -30, 30)
	keyhole.pitch = math.Clamp(keyhole.pitch + y * 0.02, -20, 20)

	return true
end

local circle, circleSize

local function buildCircle(x, y, r)
	local poly = {}

	for i = 0, 47 do
		local a = math.rad(i / 48 * -360)
		poly[#poly + 1] = {x = x + math.sin(a) * r, y = y + math.cos(a) * r}
	end

	return poly
end

function PLUGIN:HUDPaint()
	if (!keyhole.active) then return end

	local w, h = ScrW(), ScrH()
	local r = math.floor(h * 0.3)

	if (circleSize != w .. "x" .. h) then
		circle, circleSize = buildCircle(w / 2, h / 2, r), w .. "x" .. h
	end

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)

	render.OverrideColorWriteEnable(true, false)
		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawPoly(circle)
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, h)
	render.SetStencilEnable(false)

	local c = ix.efgui and ix.efgui.color
	local font = ix.efgui and "efgx.Body" or "DermaDefault"

	surface.DrawCircle(w / 2, h / 2, r, c and c.lineHi or Color(86, 90, 80))

	draw.SimpleText(L("efgDoorKeyholeExit"), font, w / 2, h / 2 + r + 24, c and c.text2 or color_white, TEXT_ALIGN_CENTER)
end

function PLUGIN:HUDShouldDraw(name)
	if (keyhole.active and name == "CHudCrosshair") then return false end
end
