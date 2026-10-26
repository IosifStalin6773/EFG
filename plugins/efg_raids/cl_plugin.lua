local PLUGIN = PLUGIN

surface.CreateFont("ixEFGBig", {font = "Bender", extended = true, size = ScreenScale(14), weight = 700})
surface.CreateFont("ixEFGMedium", {font = "Bender", extended = true, size = ScreenScale(9), weight = 600})
surface.CreateFont("ixEFGSmall", {font = "Bender", extended = true, size = ScreenScale(7), weight = 500})

local colorText   = Color(220, 215, 200)
local colorQuiet  = Color(150, 145, 130)
local colorGood   = Color(120, 200, 90)
local colorBad    = Color(210, 70, 60)
local colorPanel  = Color(10, 10, 10, 200)

PLUGIN.showExtractsUntil = 0
PLUGIN.result = nil

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

net.Receive("ixEFGShowExtracts", function()
	PLUGIN.showExtractsUntil = CurTime() + 6
end)

net.Receive("ixEFGRaidResult", function()
	PLUGIN.result = {
		survived = net.ReadBool(),
		text = net.ReadString(),
		xp = net.ReadUInt(16),
		untilTime = CurTime() + 8
	}
end)

-- tecla O: tiempo restante y extracciones (como el doble toque de O en EFT)
function PLUGIN:PlayerButtonDown(client, button)
	if (button == KEY_O and IsFirstTimePredicted() and client == LocalPlayer() and client:InRaid()) then
		self.showExtractsUntil = CurTime() + 6
	end
end

local function extractRequirement(extract)
	if (extract.type == "pago" and extract.cost) then
		return ("Coste: %s RUB"):format(string.Comma(extract.cost))
	elseif (extract.type == "sin_mochila") then
		return "Sin mochila"
	end

	return "Disponible"
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local w, h = ScrW(), ScrH()

	-- cuenta atrás de despliegue
	local deployAt = client:GetNetVar("efgDeployAt")

	if (deployAt and deployAt > CurTime()) then
		draw.SimpleTextOutlined(("Desplegando en %d"):format(math.ceil(deployAt - CurTime())), "ixEFGBig",
			w / 2, h * 0.3, colorText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	-- resultado de la raid
	if (self.result and self.result.untilTime > CurTime()) then
		local result = self.result

		draw.SimpleTextOutlined(result.survived and "SOBREVIVISTE" or "HAS MUERTO", "ixEFGBig",
			w / 2, h * 0.3, result.survived and colorGood or colorBad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		draw.SimpleTextOutlined(result.text, "ixEFGMedium", w / 2, h * 0.3 + ScreenScale(16),
			colorText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

		if (result.xp > 0) then
			draw.SimpleTextOutlined(("+%s XP"):format(string.Comma(result.xp)), "ixEFGMedium", w / 2, h * 0.3 + ScreenScale(28),
				colorQuiet, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		end
	end

	if (!client:InRaid()) then return end

	-- extrayendo
	local extracting = client:GetNetVar("efgExtracting")

	if (extracting) then
		local remaining = extracting[1] - CurTime()

		draw.SimpleTextOutlined("EXTRAYENDO: " .. extracting[2], "ixEFGMedium", w / 2, h * 0.22,
			colorGood, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		draw.SimpleTextOutlined(("%.1f"):format(math.max(0, remaining)), "ixEFGBig", w / 2, h * 0.22 + ScreenScale(14),
			colorGood, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	-- panel de tiempo y extracciones
	if (self.showExtractsUntil > CurTime()) then
		local endTime = client:GetNetVar("efgRaidEnd", CurTime())
		local available = client:GetNetVar("efgRaidExtracts", {})
		local all = GetNetVar("efgExtracts", {})
		local pad = ScreenScale(6)
		local lineH = ScreenScale(10)
		local panelW = ScreenScale(150)
		local panelH = pad * 2 + lineH * (2 + #available)
		local x, y = w - panelW - pad * 2, pad * 2

		draw.RoundedBox(4, x, y, panelW, panelH, colorPanel)
		draw.SimpleText(formatTime(endTime - CurTime()), "ixEFGMedium", x + pad, y + pad, colorText)

		local side = client:GetRaidSide() == "scav" and "SCAV" or "PMC"
		draw.SimpleText(side, "ixEFGSmall", x + panelW - pad, y + pad, colorQuiet, TEXT_ALIGN_RIGHT)

		for i, index in ipairs(available) do
			local extract = all[index]

			if (extract) then
				local lineY = y + pad + lineH * (i + 1)
				draw.SimpleText(("EXFIL%02d  %s"):format(i, extract.name), "ixEFGSmall", x + pad, lineY, colorText)
				draw.SimpleText(extractRequirement(extract), "ixEFGSmall", x + panelW - pad, lineY, colorQuiet, TEXT_ALIGN_RIGHT)
			end
		end
	end
end

-- nombres de los compañeros de grupo
function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)
	if (bSkybox) then return end

	local client = LocalPlayer()
	local group = client:GetNetVar("efgGroup")

	if (group) then
		for _, index in ipairs(group) do
			local member = Entity(index)

			if (IsValid(member) and member != client and member:Alive() and member:GetPos():Distance(client:GetPos()) < 3000) then
				local pos = member:GetPos() + Vector(0, 0, 80)
				local ang = EyeAngles()

				cam.Start3D2D(pos, Angle(0, ang.y - 90, 90), 0.1)
					draw.SimpleTextOutlined(member:Name(), "ixEFGMedium", 0, 0, colorGood, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				cam.End3D2D()
			end
		end
	end

	-- admins en noclip ven el escondite, los spawns y las extracciones
	if (!client:IsAdmin() or client:GetMoveType() != MOVETYPE_NOCLIP) then return end

	local hideout = GetNetVar("efgHideout")

	if (hideout) then
		render.DrawWireframeSphere(hideout, ix.config.Get("efgHideoutRadius", 1500), 16, 16, colorGood, true)
	end

	for _, pos in ipairs(GetNetVar("efgSpawns", {})) do
		render.DrawWireframeBox(pos, angle_zero, Vector(-16, -16, 0), Vector(16, 16, 72), Color(80, 160, 255), true)
	end

	for _, extract in ipairs(GetNetVar("efgExtracts", {})) do
		render.DrawWireframeSphere(extract.pos, extract.radius, 12, 12, Color(255, 200, 40), true)
	end
end

function PLUGIN:HUDPaintBackground()
	local client = LocalPlayer()
	if (!client:IsAdmin() or client:GetMoveType() != MOVETYPE_NOCLIP) then return end

	for _, extract in ipairs(GetNetVar("efgExtracts", {})) do
		local screen = (extract.pos + Vector(0, 0, 40)):ToScreen()

		if (screen.visible) then
			draw.SimpleTextOutlined(extract.name .. " (" .. extract.type .. ", " .. extract.side .. ")", "ixEFGSmall",
				screen.x, screen.y, Color(255, 200, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		end
	end
end
