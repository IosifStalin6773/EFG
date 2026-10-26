-- ============================================================
--  vigilancia  |  cl_plugin.lua  (CLIENT)
--  Panel de administración: lista de personajes, activar/quitar
--  vigilancia y revisar inventario en vivo + logs de movimientos.
-- ============================================================

local COL_ACCENT = Color(185, 175, 140)     -- ámbar Metro
local COL_RED    = Color(220, 70, 70)
local COL_GREEN  = Color(80, 180, 90)
local COL_TEXT   = Color(215, 215, 215)
local COL_DIM    = Color(160, 160, 160)
local COL_FAINT  = Color(120, 120, 120)

ix.vigilancia = ix.vigilancia or {}

local function fmtTime(t)
	if (not t or t == 0) then return "—" end
	return os.date("%d/%m/%y %H:%M", t)
end

-- Escala conservadora: SScaleMin usa el MENOR factor (ancho/alto), así el panel
-- no se desborda en pantallas anchas como sí hacía SScale (= ancho/640).
-- Se resuelve en runtime para no depender del orden de carga de metroui.
local function S(n) return SScaleMin(n) end

-- Fuentes propias (se crean una sola vez)
local fontsMade = false
local function makeFonts()
	if (fontsMade) then return end
	fontsMade = true
	surface.CreateFont("vigilancia.Title", {font = "EFGX Display", size = math.max(15, S(12)),  weight = 700})
	surface.CreateFont("vigilancia.Item",  {font = "EFGX Body", size = math.max(12, S(8.5)), weight = 500})
	surface.CreateFont("vigilancia.Small", {font = "EFGX Body", size = math.max(10, S(7)),   weight = 400})
end

-- ── Helpers de dibujo ────────────────────────────────────────────────────────
local function paintFrame(self, w, h)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(30, 30, 30, 235)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 200)
	surface.DrawRect(0, 0, w, 3)
	surface.SetDrawColor(66, 66, 66, 90)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function makeBtn(parent, text, r, g, b, cb)
	local btn = parent:Add("DButton")
	btn:SetText(text)
	btn:SetFont("vigilancia.Small")
	btn:SetTextColor(Color(math.min(r + 120, 255), math.min(g + 120, 255), math.min(b + 120, 255)))
	btn.Paint = function(s, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 30 or 14)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 80 or 30)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end
	btn.DoClick = cb or function() end
	return btn
end

-- ============================================================
--  Panel principal
-- ============================================================

local PANEL = {}

function PANEL:Init()
	makeFonts()
	self.BaseClass.Init(self)

	local sw, sh = ScrW(), ScrH()
	self.W = math.min(S(400), sw - S(30))
	self.H = math.min(S(300), sh - S(30))

	self:SetSize(self.W, self.H)
	self:SetPos(sw / 2 - self.W / 2, sh / 2 - self.H / 2)
	self:SetTitle("")
	self:SetDraggable(true)
	self:MakePopup()
	self.Paint = paintFrame

	-- Quitar la decoración base de GMod (X, botones min/max y título) para dejar
	-- solo el estilo propio; ponemos nuestra propia X más abajo.
	self:ShowCloseButton(false)
	if (IsValid(self.btnMaxim)) then self.btnMaxim:Hide() end
	if (IsValid(self.btnMinim)) then self.btnMinim:Hide() end
	if (IsValid(self.lblTitle)) then self.lblTitle:Hide() end

	self.selectedCharID = nil
	self.selectedName   = nil
	self.selectedList   = {}   -- referencia a la última lista recibida
	self.mode           = "logs"

	local pad = S(6)

	-- Botón de cierre propio (estilo del resto de UIs)
	local closeBtn = self:Add("DButton")
	closeBtn:SetText("")
	closeBtn:SetSize(S(15), S(15))
	closeBtn:SetPos(self.W - S(15) - pad, pad)
	closeBtn.Paint = function(s, w, h)
		local hov = s:IsHovered()
		surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, hov and 60 or 22)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, hov and 220 or 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("X", "vigilancia.Small", w / 2, h / 2,
			hov and Color(255, 150, 150) or COL_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function() self:Remove() end

	-- Cabecera
	local title = self:Add("DLabel")
	title:SetFont("vigilancia.Title")
	title:SetTextColor(COL_ACCENT)
	title:SetText("VIGILANCIA")
	title:SizeToContents()
	title:SetPos(pad, pad)

	local top = pad + S(26)

	-- Columna izquierda: lista de personajes
	local listW = S(130)
	self.list = self:Add("DScrollPanel")
	self.list:SetPos(pad, top)
	self.list:SetSize(listW, self.H - top - pad)

	-- Columna derecha: detalle
	local rightX = pad + listW + pad
	local rightW = self.W - rightX - pad

	self.header = self:Add("DLabel")
	self.header:SetFont("vigilancia.Item")
	self.header:SetTextColor(COL_TEXT)
	self.header:SetText("Selecciona un personaje")
	self.header:SetPos(rightX, top)
	self.header:SetSize(rightW, S(16))

	-- Botonera de acciones
	local btnY = top + S(22)
	local gap  = S(4)
	local bh   = S(20)
	local bw   = (rightW - gap * 3) / 4

	self.btnWatch = makeBtn(self, "Vigilar", 200, 160, 60, function()
		if (not self.selectedCharID) then return end
		net.Start("vigilancia_Toggle")
			net.WriteUInt(self.selectedCharID, 32)
		net.SendToServer()
	end)
	self.btnWatch:SetPos(rightX, btnY)
	self.btnWatch:SetSize(bw, bh)

	self.btnInv = makeBtn(self, "Inventario", 70, 130, 200, function()
		if (not self.selectedCharID) then return end
		self.mode = "inv"
		self:RequestData()
	end)
	self.btnInv:SetPos(rightX + (bw + gap), btnY)
	self.btnInv:SetSize(bw, bh)

	self.btnLockers = makeBtn(self, "Taquillas", 150, 110, 190, function()
		if (not self.selectedCharID) then return end
		self.mode = "lockers"
		self:RequestData()
	end)
	self.btnLockers:SetPos(rightX + (bw + gap) * 2, btnY)
	self.btnLockers:SetSize(bw, bh)

	self.btnLogs = makeBtn(self, "Logs", 90, 170, 100, function()
		if (not self.selectedCharID) then return end
		self.mode = "logs"
		self:RequestData()
	end)
	self.btnLogs:SetPos(rightX + (bw + gap) * 3, btnY)
	self.btnLogs:SetSize(bw, bh)

	-- Área de contenido (inventario / logs)
	local contentY = btnY + bh + S(6)
	self.content = self:Add("DScrollPanel")
	self.content:SetPos(rightX, contentY)
	self.content:SetSize(rightW, self.H - contentY - pad)
end

-- Rellena la lista de personajes
function PANEL:SetList(list)
	self.selectedList = list or {}
	self.list:Clear()

	for _, char in ipairs(self.selectedList) do
		local row = self.list:Add("DButton")
		row:SetText("")
		row:Dock(TOP)
		row:DockMargin(0, 0, S(3), S(3))
		row:SetTall(S(21))

		local c = char
		row.Paint = function(s, w, h)
			local selected = (self.selectedCharID == c.charID)
			surface.SetDrawColor(50, 50, 50, s:IsHovered() and 230 or 190)
			surface.DrawRect(0, 0, w, h)
			if (selected) then
				surface.SetDrawColor(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 220)
				surface.DrawRect(0, 0, 3, h)
			end

			-- Punto de estado (online/offline)
			local dot = c.online and COL_GREEN or COL_FAINT
			surface.SetDrawColor(dot.r, dot.g, dot.b, 255)
			surface.DrawRect(S(7), h / 2 - S(3), S(6), S(6))

			draw.SimpleText(c.name or "?", "vigilancia.Item", S(18), S(4), COL_TEXT, 0, 0)
			draw.SimpleText(c.steamID or "?", "vigilancia.Small", S(18), S(12), COL_DIM, 0, 0)

			if (c.vigilado) then
				draw.SimpleText("● VIGILADO", "vigilancia.Small", w - S(6), S(4), COL_RED, TEXT_ALIGN_RIGHT, 0)
			end
		end

		row.DoClick = function()
			self.selectedCharID = c.charID
			self.selectedName   = c.name
			self.header:SetText(c.name .. "  —  " .. (c.steamID or "?") .. (c.online and "  (online)" or "  (offline)"))
			self.btnWatch:SetText(c.vigilado and "Quitar vigilancia" or "Vigilar")
			self:RequestData()
		end

		-- Mantener sincronizado el botón de vigilancia tras un refresco de lista
		if (self.selectedCharID == c.charID) then
			self.btnWatch:SetText(c.vigilado and "Quitar vigilancia" or "Vigilar")
		end
	end
end

-- Pide al servidor los datos del modo actual para el personaje seleccionado
function PANEL:RequestData()
	if (not self.selectedCharID) then return end
	self.content:Clear()

	local wait = self.content:Add("DLabel")
	wait:Dock(TOP)
	wait:SetTall(S(14))
	wait:SetFont("vigilancia.Small")
	wait:SetTextColor(COL_FAINT)
	wait:SetText("Cargando...")

	local msg =
		(self.mode == "inv"     and "vigilancia_ReqInv") or
		(self.mode == "lockers" and "vigilancia_ReqLockers") or
		"vigilancia_ReqLogs"

	net.Start(msg)
		net.WriteUInt(self.selectedCharID, 32)
	net.SendToServer()
end

-- Rellena el área con el inventario recibido
function PANEL:SetInventory(charID, payload)
	if (charID != self.selectedCharID or self.mode != "inv") then return end
	self.content:Clear()

	if (not payload.online) then
		local l = self.content:Add("DLabel")
		l:Dock(TOP); l:SetFont("vigilancia.Item"); l:SetTextColor(COL_FAINT)
		l:SetText("El personaje está offline: no se puede leer su inventario en vivo.")
		l:SetTall(S(15))
		return
	end

	if (#payload.items == 0) then
		local l = self.content:Add("DLabel")
		l:Dock(TOP); l:SetFont("vigilancia.Item"); l:SetTextColor(COL_FAINT)
		l:SetText("Inventario vacío.")
		l:SetTall(S(15))
		return
	end

	for _, it in ipairs(payload.items) do
		local row = self.content:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, S(3), S(3))
		row:SetTall(S(16))
		local item = it
		row.Paint = function(s, w, h)
			surface.SetDrawColor(46, 46, 46, 200)
			surface.DrawRect(0, 0, w, h)
			local label = item.name .. (item.qty and item.qty > 1 and ("  x" .. item.qty) or "")
			draw.SimpleText(label, "vigilancia.Item", S(6), h / 2, COL_TEXT, 0, TEXT_ALIGN_CENTER)
			draw.SimpleText(item.source .. "  ·  " .. (item.category or ""), "vigilancia.Small",
				w - S(6), h / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

-- Rellena el área con las taquillas recibidas
function PANEL:SetLockers(charID, payload)
	if (charID != self.selectedCharID or self.mode != "lockers") then return end
	self.content:Clear()

	local lockers = payload.lockers or {}

	if (#lockers == 0) then
		local l = self.content:Add("DLabel")
		l:Dock(TOP); l:SetFont("vigilancia.Item"); l:SetTextColor(COL_FAINT)
		l:SetText("Este personaje no tiene taquillas registradas.")
		l:SetTall(S(15))
		return
	end

	table.sort(lockers, function(a, b) return (a.lockerID or 0) < (b.lockerID or 0) end)

	for _, locker in ipairs(lockers) do
		-- Cabecera de la taquilla
		local head = self.content:Add("DPanel")
		head:Dock(TOP)
		head:DockMargin(0, S(4), S(3), S(1))
		head:SetTall(S(15))
		local lk = locker
		head.Paint = function(s, w, h)
			surface.SetDrawColor(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 26)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 200)
			surface.DrawRect(0, 0, 3, h)
			draw.SimpleText("TAQUILLA #" .. (lk.lockerID or "?") .. "  ·  " .. (lk.type or ""),
				"vigilancia.Small", S(7), h / 2, COL_ACCENT, 0, TEXT_ALIGN_CENTER)
			draw.SimpleText(#lk.items .. " objeto(s)", "vigilancia.Small",
				w - S(6), h / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		if (#locker.items == 0) then
			local l = self.content:Add("DLabel")
			l:Dock(TOP); l:DockMargin(S(4), 0, 0, 0)
			l:SetFont("vigilancia.Small"); l:SetTextColor(COL_FAINT)
			l:SetText("(vacía)")
			l:SetTall(S(12))
		end

		for _, it in ipairs(locker.items) do
			local row = self.content:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(S(4), 0, S(3), S(2))
			row:SetTall(S(15))
			local item = it
			row.Paint = function(s, w, h)
				surface.SetDrawColor(46, 46, 46, 200)
				surface.DrawRect(0, 0, w, h)
				local label = item.name .. (item.qty and item.qty > 1 and ("  x" .. item.qty) or "")
				draw.SimpleText(label, "vigilancia.Item", S(6), h / 2, COL_TEXT, 0, TEXT_ALIGN_CENTER)
				draw.SimpleText(item.category or "", "vigilancia.Small",
					w - S(6), h / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end
end

-- Rellena el área con los logs recibidos
function PANEL:SetLogs(charID, logs)
	if (charID != self.selectedCharID or self.mode != "logs") then return end
	self.content:Clear()

	if (#logs == 0) then
		local l = self.content:Add("DLabel")
		l:Dock(TOP); l:SetFont("vigilancia.Item"); l:SetTextColor(COL_FAINT)
		l:SetText("Sin registros para este personaje.")
		l:SetTall(S(15))
		return
	end

	for _, log in ipairs(logs) do
		local row = self.content:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, S(3), S(3))
		row:SetTall(S(22))
		local e = log
		local catCol =
			(e.category == "eco" and COL_ACCENT) or
			(e.category == "compra" and Color(120, 160, 220)) or
			(e.category == "sistema" and COL_RED) or COL_TEXT
		row.Paint = function(s, w, h)
			surface.SetDrawColor(46, 46, 46, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(catCol.r, catCol.g, catCol.b, 200)
			surface.DrawRect(0, 0, 3, h)
			draw.SimpleText(e.message or "", "vigilancia.Small", S(7), S(4), COL_TEXT, 0, 0)
			draw.SimpleText(fmtTime(e.at) .. "  ·  " .. string.upper(e.category or ""),
				"vigilancia.Small", S(7), S(13), COL_DIM, 0, 0)
		end
	end
end

vgui.Register("vigilancia_Panel", PANEL, "DFrame")

-- ============================================================
--  Recepción de red
-- ============================================================

local function readCompressed(len)
	local size = net.ReadUInt(32)
	local data = net.ReadData(size)
	local json = util.Decompress(data)
	return util.JSONToTable(json or "") or nil
end

net.Receive("vigilancia_Open", function(len)
	local list = readCompressed(len) or {}

	if (not IsValid(ix.vigilancia.panel)) then
		ix.vigilancia.panel = vgui.Create("vigilancia_Panel")
	end
	ix.vigilancia.panel:SetList(list)
end)

net.Receive("vigilancia_ReqInv", function(len)
	local charID  = net.ReadUInt(32)
	local payload = readCompressed(len) or {online = false, items = {}}
	payload.items = payload.items or {}
	if (IsValid(ix.vigilancia.panel)) then
		ix.vigilancia.panel:SetInventory(charID, payload)
	end
end)

net.Receive("vigilancia_ReqLockers", function(len)
	local charID  = net.ReadUInt(32)
	local payload = readCompressed(len) or {online = false, lockers = {}}
	payload.lockers = payload.lockers or {}
	if (IsValid(ix.vigilancia.panel)) then
		ix.vigilancia.panel:SetLockers(charID, payload)
	end
end)

net.Receive("vigilancia_ReqLogs", function(len)
	local charID = net.ReadUInt(32)
	local logs   = readCompressed(len) or {}
	if (IsValid(ix.vigilancia.panel)) then
		ix.vigilancia.panel:SetLogs(charID, logs)
	end
end)
