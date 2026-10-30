local PLUGIN = PLUGIN

surface.CreateFont("ixEFGBig", {font = "MBender", extended = true, size = ScreenScale(14), weight = 700})
surface.CreateFont("ixEFGMedium", {font = "MBender", extended = true, size = ScreenScale(9), weight = 600})
surface.CreateFont("ixEFGSmall", {font = "MBender", extended = true, size = ScreenScale(7), weight = 500})

-- tokens Pizarra (efg_ui/cl_plugin.lua)
local colorText   = Color(230, 226, 216)
local colorQuiet  = Color(154, 165, 175)
local colorGood   = Color(127, 176, 105)
local colorBad    = Color(224, 90, 71)
local colorPanel  = Color(22, 28, 34, 225)

PLUGIN.result = nil

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end


-- el bando se borra al salir de la raid, antes de que llegue el resultado
hook.Add("Think", "efgResult.Side", function()
	local client = LocalPlayer()
	local side = IsValid(client) and client.GetRaidSide and client:GetRaidSide()
	if (side) then PLUGIN.lastSide = side end
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

	result.side = LocalPlayer():GetRaidSide() or PLUGIN.lastSide

	PLUGIN.result = nil

	if (result.survived) then surface.PlaySound("efg/raids/exit_yes.wav") end

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
	btn:SetText("SIGUIENTE")
	btn:SetSize(UI.Scale(180), UI.Scale(40))
	btn:SetPos(ScrW() - btn:GetWide() - UI.Scale(48), ScrH() - btn:GetTall() - UI.Scale(40))
	UI.StyleButton(btn, "efgx.Header", "primary")
	btn.DoClick = function() self:Next() end
	self.nextBtn = btn

	-- página de tratamiento: omitir
	local skip = self:Add("DButton")
	skip:SetText("OMITIR")
	skip:SetSize(UI.Scale(140), UI.Scale(40))
	skip:SetPos(btn:GetX() - skip:GetWide() - UI.Scale(12), btn:GetY())
	UI.StyleButton(skip, "efgx.Header", "ghost")
	skip.DoClick = function() self:Close() end
	skip:SetVisible(false)
	self.skipBtn = skip
end

function RESULT:SetResult(result)
	self.result = result
end

function RESULT:Close()
	self:AlphaTo(0, 0.2, 0, function() self:Remove() end)
end

-- presupuesto de curación tras sobrevivir
function RESULT:GetQuote()
	local health = ix.efg and ix.efg.health
	if (!health or !health.TreatmentQuote) then return end

	local quote = health.TreatmentQuote(LocalPlayer():GetNetVar("efgHP"))
	if (quote.total > 0) then return quote end
end

function RESULT:Next()
	if (self.page != "treatment" and self.result.survived and self:GetQuote()) then
		self.page = "treatment"
		self.nextBtn:SetText("APLICAR")
		self.skipBtn:SetVisible(true)
		return
	end

	if (self.page == "treatment") then
		net.Start("ixEFGTreatment")
		net.SendToServer()
	end

	self:Close()
end

function RESULT:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Close()
	elseif (key == KEY_ENTER) then self:Next() end
end

local treatmentRows = {
	{"hp", "PUNTOS DE VIDA", "PV"},
	{"lightBleed", "SANGRADO LEVE"},
	{"heavyBleed", "SANGRADO GRAVE"},
	{"fracture", "FRACTURA"},
	{"destroyed", "ZONA DESTRUIDA"},
}

function RESULT:PaintTreatment(w, h)
	local UI, c = ix.efgui, ix.efgui.color
	local S = UI.Scale
	local quote = self:GetQuote() or {total = 0}
	local price = ix.efg.health.treatmentPrice

	local pw, ph = math.min(w - S(96), S(860)), S(440)
	local px, py = w / 2 - pw / 2, h / 2 - ph / 2

	draw.SimpleText("TRATAMIENTO", "efgx.Display", w / 2, py - S(56), c.text, TEXT_ALIGN_CENTER)
	draw.SimpleText("El médico del escondite puede curarte antes del siguiente despliegue.", "efgx.Body",
		w / 2, py - S(20), c.text2, TEXT_ALIGN_CENTER)

	UI.DrawPanel(px, py, pw, ph, 240)

	-- silueta
	local bw = S(150)
	UI.DrawBody(px + S(30), py + S(30), bw, ph - S(60), UI.BodyFromNet(LocalPlayer():GetNetVar("efgHP")))

	-- desglose
	local tx = px + bw + S(70)
	local tw = px + pw - S(30) - tx
	local y = py + S(30)

	UI.DrawHeader(tx, y, tw, S(28), "SERVICIOS")
	y = y + S(40)

	for _, row in ipairs(treatmentRows) do
		local count = quote[row[1]] or 0

		if (count > 0) then
			local cost = count * (price[row[1]] or 0)
			draw.SimpleText(row[2], "efgx.Body", tx + S(8), y, c.text)
			draw.SimpleText(row[3] and (count .. " " .. row[3]) or ("x" .. count), "efgx.Num", tx + tw * 0.55, y, c.text2, TEXT_ALIGN_RIGHT)
			draw.SimpleText(string.Comma(cost) .. " ₽", "efgx.Num", tx + tw - S(8), y, c.text, TEXT_ALIGN_RIGHT)

			surface.SetDrawColor(c.line)
			surface.DrawRect(tx, y + S(26), tw, 1)
			y = y + S(34)
		end
	end

	local character = LocalPlayer():GetCharacter()
	local money = character and character:GetMoney() or 0
	local affordable = money >= quote.total

	local by = py + ph - S(84)
	draw.SimpleText("TOTAL", "efgx.Label", tx + S(8), by, c.textDim)
	draw.SimpleText(string.Comma(quote.total) .. " ₽", "efgx.NumBig", tx + S(8), by + S(14), affordable and c.text or c.crit)
	draw.SimpleText("DISPONIBLE", "efgx.Label", tx + tw - S(8), by, c.textDim, TEXT_ALIGN_RIGHT)
	draw.SimpleText(string.Comma(money) .. " ₽", "efgx.NumBig", tx + tw - S(8), by + S(14), c.text2, TEXT_ALIGN_RIGHT)

	self.nextBtn:SetEnabled(affordable)
end

-- Pantalla "RAID TERMINADA" como la de EFT: arte de fondo, el estado en
-- grande en el centro (sobreviviste, muerto o desaparecido), el nivel con la
-- experiencia ganada y debajo el resumen y la cronología.
local resultArt = {
	pmc = Material("efg/menu/bg2.jpg", "smooth"),
	scav = Material("efg/menu/bg3.jpg", "smooth"),
}

local function resultFonts()
	local S = ix.efgui.Scale
	surface.CreateFont("efgResult.Status", {font = "MBender", extended = true, size = S(84), weight = 700})
	surface.CreateFont("efgResult.Small", {font = "MBender", extended = true, size = S(20), weight = 500})
end

hook.Add("OnScreenSizeChanged", "efgResult.Fonts", resultFonts)

function RESULT:Paint(w, h)
	local UI, c = ix.efgui, ix.efgui.color
	local r = self.result
	local S = UI.Scale
	local m = S(48)

	if (!self.fonts) then
		self.fonts = true
		resultFonts()
	end

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, h)
	UI.DrawCover(resultArt[r.side == "scav" and "scav" or "pmc"], 0, 0, w, h, 255)
	surface.SetDrawColor(6, 7, 7, 215)
	surface.DrawRect(0, 0, w, h)

	if (self.page == "treatment") then
		return self:PaintTreatment(w, h)
	end

	-- estado
	local status, stateColor
	if (r.survived) then
		status, stateColor = "SOBREVIVISTE", Color(110, 200, 70)
	elseif (r.killedBy and r.killedBy != "") then
		status, stateColor = "MUERTO EN COMBATE", Color(205, 45, 35)
	else
		status, stateColor = "DESAPARECIDO", Color(205, 45, 35)
	end

	draw.SimpleText("RAID TERMINADA", "efgResult.Small", w / 2, S(70), c.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText(status, "efgResult.Status", w / 2, S(96), stateColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	local icon = UI.Mat(r.survived and "efg/raids/icon_exit_pmc_yes.png" or "efg/raids/icon_exit_pmc_no.png", "smooth")
	if (icon) then
		surface.SetFont("efgResult.Status")
		local tw = surface.GetTextSize(status)
		surface.SetMaterial(icon)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(w / 2 - tw / 2 - S(52), S(116), S(39), S(48))
	end

	draw.SimpleText(r.text or "", "efgx.Body", w / 2, S(200), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText(("%s  ·  %s EN RAID"):format(string.upper(game.GetMap()), formatTime(r.duration or 0)), "efgx.Label",
		w / 2, S(228), c.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	-- nivel y barra de experiencia (lo ganado en esta raid, resaltado)
	local character = LocalPlayer():GetCharacter()
	local barW, barY = math.min(w * 0.5, S(760)), S(276)
	local bx = w / 2 - barW / 2

	if (character and ix.efg.levels) then
		local xp = character:GetEFGXP()
		local level = character:GetEFGLevel()
		local from = ix.efg.levels[level] or 0
		local to = ix.efg.levels[level + 1] or (from + 1)
		local frac = math.Clamp((xp - from) / math.max(to - from, 1), 0, 1)
		local gainedFrac = math.Clamp((r.xp or 0) / math.max(to - from, 1), 0, frac)

		local badge = UI.Mat("efg/ui/skill_level_panel.png", "smooth")
		if (badge) then
			surface.SetMaterial(badge)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(bx - S(54), barY - S(14), S(40), S(40))
		end
		draw.SimpleText(level, "efgx.Title", bx - S(34), barY + S(6), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(bx, barY, barW, S(12))
		surface.SetDrawColor(c.text2)
		surface.DrawRect(bx, barY, barW * (frac - gainedFrac), S(12))
		surface.SetDrawColor(stateColor)
		surface.DrawRect(bx + barW * (frac - gainedFrac), barY, barW * gainedFrac, S(12))
		surface.SetDrawColor(c.line)
		surface.DrawOutlinedRect(bx, barY, barW, S(12))

		draw.SimpleText(("%s / %s"):format(string.Comma(xp), string.Comma(to)), "efgx.Num", bx + barW, barY + S(18), c.text2, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(("+%s XP"):format(string.Comma(r.xp or 0)), "efgx.Header", bx, barY + S(18), stateColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	-- resumen en fichas
	local rows = {
		{"TIEMPO EN RAID", formatTime(r.duration or 0)},
		{"BAJAS", tostring(r.kills or 0)},
		{"EXPERIENCIA", "+" .. string.Comma(r.xp or 0)},
	}

	if (r.killedBy and r.killedBy != "") then
		rows[#rows + 1] = {"ABATIDO POR", r.killedBy}
	end

	local cardY = barY + S(64)
	local gap = S(10)
	local cardW = (barW + S(54) - gap * (#rows - 1)) / #rows
	local cx = bx - S(54)

	for _, row in ipairs(rows) do
		surface.SetDrawColor(14, 16, 16, 225)
		surface.DrawRect(cx, cardY, cardW, S(74))
		surface.SetDrawColor(c.line)
		surface.DrawOutlinedRect(cx, cardY, cardW, S(74))
		draw.SimpleText(row[1], "efgx.Label", cx + cardW / 2, cardY + S(10), c.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(row[2], #row[2] > 10 and "efgx.Header" or "efgx.NumBig", cx + cardW / 2, cardY + S(46), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cx = cx + cardW + gap
	end

	-- cronología
	local ty = cardY + S(94)
	local tw = barW + S(54)
	local tx = bx - S(54)
	local th = math.min(h - ty - S(110), S(30) + #r.events * S(26) + S(12))
	if (th < S(60)) then return end

	surface.SetDrawColor(14, 16, 16, 225)
	surface.DrawRect(tx, ty, tw, th)
	surface.SetDrawColor(c.line)
	surface.DrawOutlinedRect(tx, ty, tw, th)
	draw.SimpleText("CRONOLOGÍA", "efgx.Label", tx + S(14), ty + S(8), c.textDim)

	for i, event in ipairs(r.events) do
		local ey = ty + S(30) + (i - 1) * S(26)
		if (ey > ty + th - S(24)) then break end

		surface.SetDrawColor(i == #r.events and stateColor or c.lineHi)
		surface.DrawRect(tx + S(14), ey + S(6), S(6), S(6))
		draw.SimpleText(formatTime(event[1]), "efgx.Num", tx + S(30), ey, c.text2)
		draw.SimpleText(event[2], "efgx.Body", tx + S(100), ey, c.text)
	end
end

vgui.Register("efgxRaidResult", RESULT, "EditablePanel")

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local w, h = ScrW(), ScrH()

	-- cuenta atrás de despliegue
	local deployAt = client:GetNetVar("efgDeployAt")

	if (deployAt and deployAt > CurTime() and !vgui.GetControlTable("efgxDeploy")) then
		draw.SimpleTextOutlined(("Desplegando en %d"):format(math.ceil(deployAt - CurTime())), "ixEFGBig",
			w / 2, h * 0.3, colorText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	-- la lista de extracciones (tecla O) y la barra de extracción están en cl_extracts.lua
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
