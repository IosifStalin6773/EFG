local PLUGIN = PLUGIN

surface.CreateFont("ixEFGBig", {font = "EFGX Display", extended = true, size = ScreenScale(14), weight = 700})
surface.CreateFont("ixEFGMedium", {font = "EFGX Header", extended = true, size = ScreenScale(9), weight = 600})
surface.CreateFont("ixEFGSmall", {font = "EFGX Body", extended = true, size = ScreenScale(7), weight = 500})

-- tokens Pizarra (efg_ui/cl_plugin.lua)
local colorText   = Color(230, 226, 216)
local colorQuiet  = Color(154, 165, 175)
local colorGood   = Color(127, 176, 105)
local colorBad    = Color(224, 90, 71)
local colorPanel  = Color(22, 28, 34, 225)

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
	local result = {
		survived = net.ReadBool(),
		text = net.ReadString(),
		xp = net.ReadUInt(16),
		duration = net.ReadUInt(16),
		kills = net.ReadUInt(8),
		killedBy = net.ReadString(),
		events = {}
	}

	for i = 1, net.ReadUInt(6) do
		result.events[i] = {net.ReadUInt(16), net.ReadString()}
	end

	PLUGIN.result = nil

	if (IsValid(PLUGIN.resultPanel)) then PLUGIN.resultPanel:Remove() end
	PLUGIN.resultPanel = vgui.Create("efgxRaidResult")
	PLUGIN.resultPanel:SetResult(result)
end)

-- ─── Pantalla de fin de raid (Pizarra) ───────────────────────────────────────
-- Título y motivo a la izquierda, cifras en columna y cronología a la derecha.
local RESULT = {}

function RESULT:Init()
	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.3)
	self.result = {events = {}}

	local UI = ix.efgui
	local btn = self:Add("DButton")
	btn:SetText("CONTINUAR")
	btn:SetSize(UI.Scale(180), UI.Scale(40))
	btn:SetPos(ScrW() - btn:GetWide() - UI.Scale(48), ScrH() - btn:GetTall() - UI.Scale(40))
	UI.StyleButton(btn, "efgx.Header", "primary")
	btn.DoClick = function() self:AlphaTo(0, 0.2, 0, function() self:Remove() end) end
end

function RESULT:SetResult(result)
	self.result = result
end

function RESULT:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_ENTER) then self:Remove() end
end

function RESULT:Paint(w, h)
	local UI, c = ix.efgui, ix.efgui.color
	local r = self.result
	local S = UI.Scale
	local m = S(48)

	surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, 245)
	surface.DrawRect(0, 0, w, h)

	-- franja de estado a la izquierda del título
	local stateColor = r.survived and c.ok or c.crit
	surface.SetDrawColor(stateColor)
	surface.DrawRect(m, m, S(4), S(64))

	draw.SimpleText(r.survived and "SOBREVIVISTE" or "NO HAS VUELTO", "efgx.Display", m + S(16), m, c.text)
	draw.SimpleText(r.text or "", "efgx.Body", m + S(16), m + S(40), c.text2)

	-- cifras
	local colW = math.floor(w * 0.32)
	local y = m + S(110)
	local rows = {
		{"TIEMPO EN RAID", formatTime(r.duration or 0)},
		{"BAJAS", tostring(r.kills or 0)},
		{"EXPERIENCIA", "+" .. string.Comma(r.xp or 0)},
	}

	if (r.killedBy and r.killedBy != "") then
		rows[#rows + 1] = {"ABATIDO POR", r.killedBy}
	end

	UI.DrawPanel(m, y, colW, S(28) + #rows * S(56), 235)
	UI.DrawHeader(m, y, colW, S(28), "RESUMEN")

	for i, row in ipairs(rows) do
		local ry = y + S(28) + (i - 1) * S(56) + S(10)
		draw.SimpleText(row[1], "efgx.Label", m + S(14), ry, c.textDim)
		draw.SimpleText(row[2], "efgx.NumBig", m + S(14), ry + S(14), c.text)
	end

	-- cronología
	local tx = m + colW + S(24)
	local tw = w - tx - m
	local th = math.min(h - y - S(110), S(28) + #r.events * S(26) + S(16))

	UI.DrawPanel(tx, y, tw, th, 235)
	UI.DrawHeader(tx, y, tw, S(28), "CRONOLOGÍA")

	for i, event in ipairs(r.events) do
		local ey = y + S(28) + S(8) + (i - 1) * S(26)
		if (ey > y + th - S(20)) then break end

		surface.SetDrawColor(i == #r.events and stateColor or c.lineHi)
		surface.DrawRect(tx + S(14), ey + S(6), S(6), S(6))
		draw.SimpleText(formatTime(event[1]), "efgx.Num", tx + S(30), ey, c.text2)
		draw.SimpleText(event[2], "efgx.Body", tx + S(100), ey, c.text)
	end
end

vgui.Register("efgxRaidResult", RESULT, "EditablePanel")

-- tecla O: tiempo restante y extracciones
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

		if (ix.efgui) then
			ix.efgui.DrawPanel(x, y, panelW, panelH, 225)
		else
			draw.RoundedBox(0, x, y, panelW, panelH, colorPanel)
		end

		draw.SimpleText(formatTime(endTime - CurTime()), "ixEFGMedium", x + pad, y + pad, colorText)

		local side = client:GetRaidSide() == "scav" and "SCAV" or "PMC"
		draw.SimpleText(side, "ixEFGSmall", x + panelW - pad, y + pad, colorQuiet, TEXT_ALIGN_RIGHT)

		for i, index in ipairs(available) do
			local extract = all[index]

			if (extract) then
				local lineY = y + pad + lineH * (i + 1)
				draw.SimpleText(("S%02d  %s"):format(i, extract.name), "ixEFGSmall", x + pad, lineY, colorText)
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
