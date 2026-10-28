local PLUGIN = PLUGIN

local MAPS = ix.efg.maps

net.Receive("ixEFGRelight", function()
	render.RedownloadAllLightmaps(true)
end)

local function weather()
	return MAPS.weathers[GetNetVar("efgWeather", "despejado")] or MAPS.weathers.despejado
end

-- ─── Niebla: clima y noche ──────────────────────────────────────────────────
local function fogParams()
	local w = weather()
	local daylight = ix.config.Get("efgDayNight", true) and MAPS.Daylight() or 1
	local density = math.Clamp(w.fog * 0.85 + (1 - daylight) * 0.35, 0, 0.95)
	local shade = 30 + daylight * 120

	return density, shade, 6000 - w.fog * 4500
end

function PLUGIN:SetupWorldFog()
	local density, shade, distance = fogParams()
	if (density <= 0.01) then return end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(distance * 0.1)
	render.FogEnd(distance)
	render.FogMaxDensity(density)
	render.FogColor(shade, shade, shade + 8)

	return true
end

function PLUGIN:SetupSkyboxFog(scale)
	local density, shade, distance = fogParams()
	if (density <= 0.01) then return end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(distance * 0.1 * scale)
	render.FogEnd(distance * scale)
	render.FogMaxDensity(density)
	render.FogColor(shade, shade, shade + 8)

	return true
end

-- ─── Lluvia ─────────────────────────────────────────────────────────────────
local emitter
local nextDrop = 0

function PLUGIN:Think()
	if (weather().rain <= 0) then return end
	if (nextDrop > CurTime()) then return end
	nextDrop = CurTime() + 0.05

	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local origin = client:EyePos()

	-- bajo techo no llueve
	local roof = util.TraceLine({start = origin, endpos = origin + Vector(0, 0, 2000), mask = MASK_SOLID_BRUSHONLY})
	if (roof.Hit and !roof.HitSky) then return end

	emitter = emitter or ParticleEmitter(origin)
	emitter:SetPos(origin)

	for _ = 1, 30 do
		local pos = origin + Vector(math.Rand(-700, 700), math.Rand(-700, 700), math.Rand(250, 450))
		local p = emitter:Add("particle/Water/WaterDrop_001a", pos)

		if (p) then
			p:SetVelocity(Vector(0, 0, -900))
			p:SetDieTime(0.8)
			p:SetStartAlpha(110)
			p:SetEndAlpha(110)
			p:SetStartSize(1.2)
			p:SetEndSize(1.2)
			p:SetStartLength(28)
			p:SetEndLength(28)
			p:SetColor(190, 200, 210)
			p:SetCollide(true)
			p:SetCollideCallback(function(part) part:SetDieTime(0) end)
		end
	end
end

-- Hora en el HUD mientras se está en raid (como el reloj de EFT, tecla O)
function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (!client.InRaid or !client:InRaid() or !input.IsKeyDown(KEY_O)) then return end

	draw.SimpleTextOutlined(MAPS.FormatClock(MAPS.GetClock()), "ixMediumFont", ScrW() - 24, 24, Color(205, 203, 190),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, color_black)
end
