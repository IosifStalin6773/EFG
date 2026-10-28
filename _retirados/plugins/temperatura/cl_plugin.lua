local PLUGIN = PLUGIN

local FROST = Color(150, 200, 255)
local WARM = Color(255, 140, 60)

-- ─── Viñeta radial de escarcha (redondeada, sin números ni barras) ────────────
-- Anillo de color dibujado con mesh + color por vértice: va del centro transparente
-- al borde opaco, con caída CIRCULAR (no las 4 bandas rectas que se veían cuadradas).
-- Al interpolar el alpha en la GPU sale suave, sin pixelado.

local function DrawVignette(color, frac, maxAlpha, innerBase, innerShrink)
	-- Curva ease-in: apenas perceptible al principio, se cierra al acercarse al máximo.
	local eased = frac * frac
	local alpha = eased * maxAlpha
	if (alpha < 2) then return end

	-- Latido lento y sutil para que el hielo "respire" y no parezca una capa estática.
	alpha = math.Clamp(alpha * (1 + math.sin(CurTime() * 1.4) * 0.06 * frac), 0, 255)

	local sw, sh = ScrW(), ScrH()
	local cx, cy = sw * 0.5, sh * 0.5
	local rOuter = math.sqrt(cx * cx + cy * cy)            -- alcanza las esquinas
	local rInner = rOuter * math.max(0, innerBase - innerShrink * frac) -- se cierra al centro

	local r, g, b = color.r, color.g, color.b
	local segs = 64

	cam.Start2D()
		render.SetColorMaterial()
		mesh.Begin(MATERIAL_QUADS, segs)
			for i = 0, segs - 1 do
				local a0 = (i / segs) * math.pi * 2
				local a1 = ((i + 1) / segs) * math.pi * 2
				local c0, s0 = math.cos(a0), math.sin(a0)
				local c1, s1 = math.cos(a1), math.sin(a1)

				mesh.Color(r, g, b, alpha)
				mesh.Position(Vector(cx + c0 * rOuter, cy + s0 * rOuter, 0))
				mesh.AdvanceVertex()

				mesh.Color(r, g, b, alpha)
				mesh.Position(Vector(cx + c1 * rOuter, cy + s1 * rOuter, 0))
				mesh.AdvanceVertex()

				mesh.Color(r, g, b, 0)
				mesh.Position(Vector(cx + c1 * rInner, cy + s1 * rInner, 0))
				mesh.AdvanceVertex()

				mesh.Color(r, g, b, 0)
				mesh.Position(Vector(cx + c0 * rInner, cy + s0 * rInner, 0))
				mesh.AdvanceVertex()
			end
		mesh.End()
	cam.End2D()
end

function PLUGIN:HUDPaintBackground()
	local client = LocalPlayer()
	local char = client:GetCharacter()
	if (not char) then return end
	if (not client:Alive()) then return end

	local cong = char:GetCongelacion() or 0
	if (cong <= 0) then return end

	local frac = math.Clamp(cong / 100, 0, 1)
	DrawVignette(FROST, frac, 160, 0.78, 0.45)

	-- Junto a una fuente de calor: brillo cálido tenue que sustituye al aviso de texto.
	if (client:GetNetVar("nearHeat")) then
		DrawVignette(WARM, frac, 60, 0.80, 0.35)
	end
end

-- ─── Modificación de color a alta congelación (tinte azul + desaturación) ─────

local colmod = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

function PLUGIN:RenderScreenspaceEffects()
	local char = LocalPlayer():GetCharacter()
	if (not char) then return end

	local cong = char:GetCongelacion() or 0
	if (cong < 20) then return end

	-- Arranca tenue a los 20 y se profundiza suave hasta el máximo (sin salto brusco).
	local frac = math.Clamp((cong - 20) / 80, 0, 1)

	colmod["$pp_colour_colour"] = 1 - 0.4 * frac
	colmod["$pp_colour_addb"] = 0.05 * frac
	colmod["$pp_colour_brightness"] = -0.04 * frac

	DrawColorModify(colmod)
end

-- ─── Avisos de frío/calor en pantalla (mismo estilo que el loot) ──────────────
-- El servidor envía el texto y el color (celeste=frío, cálido=hoguera, verde=frío a 0)
-- y se dibujan como una cola que se desvanece, igual que las notificaciones de loot.

local function makeNotifFont()
	surface.CreateFont("ixTempNotif", {
		font      = "Capture Smallz",
		size      = ScreenScale(8),
		weight    = 500,
		antialias = true,
	})
end
makeNotifFont()
hook.Add("OnScreenSizeChanged", "ixTempNotifFont", makeNotifFont)

local tempNotifs = {}

net.Receive("ixTempMessage", function()
	local text = net.ReadString()
	local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
	if (text == "") then return end

	tempNotifs[#tempNotifs + 1] = {
		text  = text,
		color = Color(r, g, b),
		start = CurTime(),
		dur   = 5,
	}
end)

hook.Add("HUDPaint", "ixTemperatura_notifs", function()
	if (#tempNotifs == 0) then return end

	local now = CurTime()
	local lineH = ScreenScale(8) + 6
	local toRemove = {}

	for i, notif in ipairs(tempNotifs) do
		local elapsed = now - notif.start

		if (elapsed >= notif.dur) then
			toRemove[#toRemove + 1] = i
		else
			local alpha = 255
			local fadeStart = notif.dur - 0.8

			if (elapsed > fadeStart) then
				alpha = math.floor(255 * (1 - (elapsed - fadeStart) / 0.8))
			end

			local c = notif.color
			local yPos = ScrH() - 400 - (i - 1) * lineH

			surface.SetFont("ixTempNotif")
			ix.util.DrawText(notif.text, ScrW() * 0.5, yPos, Color(c.r, c.g, c.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	for i = #toRemove, 1, -1 do
		table.remove(tempNotifs, toRemove[i])
	end
end)

-- ─── Visualización de zonas para admins ───────────────────────────────────────

local bShowZones = false
local zones = {}

net.Receive("ixTempZonesSync", function()
	bShowZones = net.ReadBool()
	zones = {}

	if (not bShowZones) then
		LocalPlayer():ChatPrint("[Temperatura] Visualización de zonas desactivada.")
		return
	end

	local count = net.ReadUInt(8)
	for _ = 1, count do
		local vMin = net.ReadVector()
		local vMax = net.ReadVector()
		local temp = net.ReadFloat()
		zones[#zones + 1] = {vMin, vMax, temp}
	end

	LocalPlayer():ChatPrint("[Temperatura] " .. count .. " zona(s) fría(s) mostradas.")
end)

local COLOR_ZONE = Color(120, 190, 255, 255)

function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)
	if (bSkybox or not bShowZones) then return end

	for i, zone in ipairs(zones) do
		local startPos, endPos = zone[1], zone[2]
		local center = LerpVector(0.5, startPos, endPos)
		local min = WorldToLocal(startPos, angle_zero, center, angle_zero)
		local max = WorldToLocal(endPos, angle_zero, center, angle_zero)

		render.DrawWireframeBox(center, angle_zero, min, max, COLOR_ZONE)

		cam.Start2D()
			local screen = center:ToScreen()
			if (screen.visible) then
				local label = "Zona Fría #" .. i .. "  (" .. zone[3] .. "°C)"
				draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(label, "BudgetLabel", screen.x, screen.y, COLOR_ZONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		cam.End2D()
	end
end

-- ─── Tiritona: temblor de cámara que crece con la congelación ─────────────────
-- Temblor rápido de alta frecuencia (sensación de tiritar). Solo en 1ª persona
-- para no pelear con la cámara de tercera persona.

hook.Add("CalcView", "ixTemperatura_shiver", function(client, pos, ang, fov)
	if (client:ShouldDrawLocalPlayer()) then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local cong = char:GetCongelacion() or 0
	if (cong < 25) then return end

	local intensity = math.Clamp((cong - 25) / 75, 0, 1)
	local amp = 0.05 + 0.45 * intensity

	local t = CurTime()
	local shiverP = (math.sin(t * 41) + math.sin(t * 28.7)) * 0.5
	local shiverY = (math.sin(t * 36.5) + math.sin(t * 24.3)) * 0.5

	return {
		origin = pos,
		angles = Angle(ang.p + shiverP * amp, ang.y + shiverY * amp, ang.r),
		fov = fov,
	}
end)

-- ─── Respiración temblorosa cuando hace mucho frío ────────────────────────────

local nextShiverSound = 0

hook.Add("Think", "ixTemperatura_shiverSound", function()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local cong = char:GetCongelacion() or 0
	if (cong < 40) then return end

	if (CurTime() < nextShiverSound) then return end

	-- Cuanto más frío, más seguidas las respiraciones temblorosas.
	local interval = Lerp(math.Clamp((cong - 40) / 60, 0, 1), 5, 2.2)
	nextShiverSound = CurTime() + interval

	client:EmitSound("metromod/breath_1.wav", 45, math.random(80, 95))
end)

-- ─── Menú de administración ───────────────────────────────────────────────────

-- Escala metroui con fallback si metroui no está cargado.
local function S(n)
	if (SScaleMin) then return SScaleMin(n) end
	return math.Round(n * (ScrH() / 1080))
end

local fontsMade = false
local function makeAdminFonts()
	if (fontsMade) then return end
	fontsMade = true
	surface.CreateFont("ixTempAdmin.Title", {font = "Roboto", size = math.max(17, S(15)), weight = 700})
	surface.CreateFont("ixTempAdmin.Text",  {font = "Roboto", size = math.max(13, S(11)), weight = 500})
	surface.CreateFont("ixTempAdmin.Small", {font = "Roboto", size = math.max(11, S(9)),  weight = 400})
end

local FROST_A = Color(120, 190, 255)

local function paintFrame(self, w, h)
	if (ix.util and ix.util.DrawBlur) then ix.util.DrawBlur(self, 5) end
	surface.SetDrawColor(24, 28, 34, 240)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(FROST_A.r, FROST_A.g, FROST_A.b, 210)
	surface.DrawRect(0, 0, w, 3)
	surface.SetDrawColor(70, 80, 95, 90)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function styleButton(btn, r, g, b)
	btn:SetFont("ixTempAdmin.Small")
	btn:SetTextColor(color_white)
	btn.Paint = function(s, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 60 or 28)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 160 or 80)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
end

-- ── Estado de colocación de zona (2 clics) ───────────────────────────────────
local ZONE_HEIGHT_DEFAULT = 320
local placing = false
local placeTemp = -20
local placeHeight = ZONE_HEIGHT_DEFAULT
local placeStart = nil
local StartZonePlacement -- forward-declare (usado en el panel)

-- Construye el volumen de la zona: rectángulo XY de las dos esquinas del suelo,
-- elevado "height" unidades (por defecto 320) para cubrir techo y jugadores.
local function BuildZoneBox(c1, c2, height)
	local minX, maxX = math.min(c1.x, c2.x), math.max(c1.x, c2.x)
	local minY, maxY = math.min(c1.y, c2.y), math.max(c1.y, c2.y)
	local floorZ = math.min(c1.z, c2.z)

	return Vector(minX, minY, floorZ - 8), Vector(maxX, maxY, floorZ + (height or ZONE_HEIGHT_DEFAULT))
end

-- ── Panel ─────────────────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	makeAdminFonts()

	local sw, sh = ScrW(), ScrH()
	self.W = math.Clamp(S(400), 360, sw - 40)
	self.H = math.Clamp(S(400), 340, sh - 40)
	self:SetSize(self.W, self.H)
	self:Center()
	self:MakePopup()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self.Paint = paintFrame

	local pad = S(12)

	local title = self:Add("DLabel")
	title:SetFont("ixTempAdmin.Title")
	title:SetText("TEMPERATURA — ADMINISTRACIÓN")
	title:SetTextColor(FROST_A)
	title:SizeToContents()
	title:SetPos(pad, pad)

	local close = self:Add("DButton")
	close:SetSize(S(24), S(24))
	close:SetPos(self.W - S(24) - pad, pad - S(2))
	close:SetText("X")
	styleButton(close, 200, 70, 70)
	close.DoClick = function() self:Remove() end

	local y = pad + S(32)

	local aLbl = self:Add("DLabel")
	aLbl:SetFont("ixTempAdmin.Text")
	aLbl:SetText("Temperatura ambiente del mapa (°C):")
	aLbl:SetTextColor(color_white)
	aLbl:SizeToContents()
	aLbl:SetPos(pad, y)
	y = y + S(20)

	self.ambientEntry = self:Add("DTextEntry")
	self.ambientEntry:SetPos(pad, y)
	self.ambientEntry:SetSize(S(70), S(24))
	self.ambientEntry:SetFont("ixTempAdmin.Text")

	local aBtn = self:Add("DButton")
	aBtn:SetPos(pad + S(80), y)
	aBtn:SetSize(S(90), S(24))
	aBtn:SetText("Aplicar")
	styleButton(aBtn, 90, 150, 220)
	aBtn.DoClick = function()
		net.Start("ixTempAdmin_SetAmbient")
			net.WriteFloat(tonumber(self.ambientEntry:GetValue()) or 5)
		net.SendToServer()
	end
	y = y + S(36)

	self.showBtn = self:Add("DButton")
	self.showBtn:SetPos(pad, y)
	self.showBtn:SetSize(S(160), S(24))
	self.showBtn:SetText("Ver zonas: —")
	styleButton(self.showBtn, 120, 120, 120)
	self.showBtn.DoClick = function()
		net.Start("ixTempAdmin_ToggleShow")
		net.SendToServer()
	end
	y = y + S(34)

	local nLbl = self:Add("DLabel")
	nLbl:SetFont("ixTempAdmin.Text")
	nLbl:SetText("Nueva zona (°C):")
	nLbl:SetTextColor(color_white)
	nLbl:SizeToContents()
	nLbl:SetPos(pad, y + S(4))

	self.newTempEntry = self:Add("DTextEntry")
	self.newTempEntry:SetPos(pad + S(120), y)
	self.newTempEntry:SetSize(S(50), S(24))
	self.newTempEntry:SetFont("ixTempAdmin.Text")
	self.newTempEntry:SetText("-20")

	local hLbl = self:Add("DLabel")
	hLbl:SetFont("ixTempAdmin.Text")
	hLbl:SetText("Altura (u):")
	hLbl:SetTextColor(color_white)
	hLbl:SizeToContents()
	hLbl:SetPos(pad + S(178), y + S(4))

	self.newHeightEntry = self:Add("DTextEntry")
	self.newHeightEntry:SetPos(pad + S(240), y)
	self.newHeightEntry:SetSize(S(50), S(24))
	self.newHeightEntry:SetFont("ixTempAdmin.Text")
	self.newHeightEntry:SetText(tostring(ZONE_HEIGHT_DEFAULT))
	y = y + S(30)

	local addBtn = self:Add("DButton")
	addBtn:SetPos(pad, y)
	addBtn:SetSize(S(160), S(24))
	addBtn:SetText("Colocar (2 clics)")
	styleButton(addBtn, 90, 180, 120)
	addBtn.DoClick = function()
		StartZonePlacement(tonumber(self.newTempEntry:GetValue()) or -20, tonumber(self.newHeightEntry:GetValue()))
		self:Remove()
	end
	y = y + S(36)

	local lLbl = self:Add("DLabel")
	lLbl:SetFont("ixTempAdmin.Text")
	lLbl:SetText("Zonas de frío:")
	lLbl:SetTextColor(FROST_A)
	lLbl:SizeToContents()
	lLbl:SetPos(pad, y)
	y = y + S(20)

	self.list = self:Add("DScrollPanel")
	self.list:SetPos(pad, y)
	self.list:SetSize(self.W - pad * 2, self.H - y - pad)
end

function PANEL:SetData(ambient, showing, zones)
	if (IsValid(self.ambientEntry) and not self.ambientEntry:HasFocus()) then
		self.ambientEntry:SetText(tostring(math.Round(ambient)))
	end

	if (IsValid(self.showBtn)) then
		self.showBtn:SetText(showing and "Ver zonas: SÍ" or "Ver zonas: NO")
	end

	if (not IsValid(self.list)) then return end
	self.list:Clear()

	for i, z in ipairs(zones) do
		local row = self.list:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, S(4), S(4))
		row:SetTall(S(28))
		row.Paint = function(s, w, h)
			surface.SetDrawColor(255, 255, 255, 10)
			surface.DrawRect(0, 0, w, h)
		end

		local lbl = row:Add("DLabel")
		lbl:Dock(LEFT)
		lbl:DockMargin(S(6), 0, 0, 0)
		lbl:SetWide(S(64))
		lbl:SetFont("ixTempAdmin.Small")
		lbl:SetTextColor(color_white)
		lbl:SetText("Zona #" .. i)

		local tempEntry = row:Add("DTextEntry")
		tempEntry:Dock(LEFT)
		tempEntry:DockMargin(S(4), S(3), 0, S(3))
		tempEntry:SetWide(S(52))
		tempEntry:SetFont("ixTempAdmin.Small")
		tempEntry:SetText(tostring(math.Round(z.temp)))
		tempEntry.OnEnter = function(s)
			net.Start("ixTempAdmin_SetZoneTemp")
				net.WriteUInt(i, 8)
				net.WriteFloat(tonumber(s:GetValue()) or z.temp)
			net.SendToServer()
		end

		local delBtn = row:Add("DButton")
		delBtn:Dock(RIGHT)
		delBtn:DockMargin(0, S(3), S(6), S(3))
		delBtn:SetWide(S(56))
		delBtn:SetText("Borrar")
		styleButton(delBtn, 200, 70, 70)
		delBtn.DoClick = function()
			net.Start("ixTempAdmin_RemoveZone")
				net.WriteUInt(i, 8)
			net.SendToServer()
		end

		local gotoBtn = row:Add("DButton")
		gotoBtn:Dock(RIGHT)
		gotoBtn:DockMargin(0, S(3), S(4), S(3))
		gotoBtn:SetWide(S(40))
		gotoBtn:SetText("Ir")
		styleButton(gotoBtn, 90, 150, 220)
		gotoBtn.DoClick = function()
			net.Start("ixTempAdmin_Goto")
				net.WriteUInt(i, 8)
			net.SendToServer()
		end
	end
end

vgui.Register("ixTempAdminPanel", PANEL, "DFrame")

-- ── Apertura / actualización del panel ───────────────────────────────────────
local adminPanel

net.Receive("ixTempAdmin_Open", function()
	local ambient = net.ReadFloat()
	local showing = net.ReadBool()
	local count = net.ReadUInt(8)

	local zones = {}
	for i = 1, count do
		local temp = net.ReadFloat()
		local center = net.ReadVector()
		zones[i] = {temp = temp, center = center}
	end

	if (not IsValid(adminPanel)) then
		adminPanel = vgui.Create("ixTempAdminPanel")
	end

	if (IsValid(adminPanel)) then
		adminPanel:SetData(ambient, showing, zones)
	end
end)

-- ── Colocación de zona (2 clics en el mundo) ─────────────────────────────────
function StartZonePlacement(temp, height)
	makeAdminFonts()
	placing = true
	placeTemp = math.Round(temp)
	placeHeight = math.Clamp(math.Round(height or ZONE_HEIGHT_DEFAULT), 32, 8192)
	placeStart = nil
	LocalPlayer():ChatPrint("[Temperatura] Coloca la zona (altura " .. placeHeight .. "u): clic IZQ en 2 esquinas del suelo. Clic DER = cancelar.")
end

hook.Add("PlayerBindPress", "ixTempZonePlacement", function(client, bind, pressed)
	if (not placing or not pressed) then return end

	if (bind:find("attack2")) then
		placing = false
		placeStart = nil
		LocalPlayer():ChatPrint("[Temperatura] Colocación cancelada.")
		return true
	end

	if (bind:find("attack") and not bind:find("attack2")) then
		local hitPos = LocalPlayer():GetEyeTraceNoCursor().HitPos

		if (not placeStart) then
			placeStart = hitPos
			LocalPlayer():ChatPrint("[Temperatura] Esquina 1 fijada. Clic en la esquina opuesta del suelo.")
		else
			local vMin, vMax = BuildZoneBox(placeStart, hitPos, placeHeight)

			net.Start("ixTempAdmin_AddZone")
				net.WriteVector(vMin)
				net.WriteVector(vMax)
				net.WriteFloat(placeTemp)
			net.SendToServer()

			placing = false
			placeStart = nil

			-- Reabrir el menú tras crear la zona.
			net.Start("ixTempAdmin_Req")
			net.SendToServer()
		end

		return true
	end
end)

hook.Add("HUDPaint", "ixTempZonePlacementHUD", function()
	if (not placing) then return end

	local cx = ScrW() * 0.5
	local step = placeStart and "Clic IZQ en la 2ª esquina del suelo" or "Clic IZQ en la 1ª esquina del suelo"

	draw.SimpleText("[Nueva zona " .. placeTemp .. "°C · " .. placeHeight .. "u]  " .. step, "ixTempAdmin.Text", cx, 82, FROST_A, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("Clic derecho para cancelar", "ixTempAdmin.Small", cx, 100, Color(210, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("PostDrawTranslucentRenderables", "ixTempZonePlacementPreview", function(bDepth, bSky)
	if (bSky or not placing) then return end

	local hit = LocalPlayer():GetEyeTraceNoCursor().HitPos

	if (placeStart) then
		render.DrawSphere(placeStart, 8, 12, 12, Color(150, 200, 255, 200))

		local vMin, vMax = BuildZoneBox(placeStart, hit, placeHeight)
		local center = (vMin + vMax) * 0.5
		local mn = WorldToLocal(vMin, angle_zero, center, angle_zero)
		local mx = WorldToLocal(vMax, angle_zero, center, angle_zero)
		render.DrawWireframeBox(center, angle_zero, mn, mx, Color(150, 200, 255))
	else
		render.DrawSphere(hit, 6, 12, 12, Color(150, 220, 255, 220))
	end
end)
