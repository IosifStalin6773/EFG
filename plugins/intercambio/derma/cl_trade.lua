timer.Simple(0, function()
	local PLUGIN = ix.plugin.Get("intercambio")
	if (not PLUGIN) then return end

	local function S(v)
		return math.ceil(v * (ScrH() / 1080))
	end

	if (not TRADE_FONTS_READY or TRADE_FONTS_H != ScrH()) then
		surface.CreateFont("metroTradeTitle", {font = "EFGX Display", size = S(22), weight = 700, antialias = true, extended = true})
		surface.CreateFont("metroTradeLabel", {font = "EFGX Header", size = S(16), weight = 600, antialias = true, extended = true})
		surface.CreateFont("metroTradeSmall", {font = "EFGX Body", size = S(13), weight = 500, antialias = true, extended = true})
		surface.CreateFont("metroTradeBtn", {font = "EFGX Display", size = S(15), weight = 700, antialias = true, extended = true})
		TRADE_FONTS_READY = true
		TRADE_FONTS_H = ScrH()
	end

	local COLOR_BG = Color(15, 15, 15, 230)
	local COLOR_PANEL = Color(33, 33, 33, 245)
	local COLOR_SUB = Color(26, 26, 26, 240)
	local COLOR_BORDER = Color(70, 70, 70, 120)
	local COLOR_ACCENT = Color(190, 150, 70)
	local COLOR_GREEN = Color(66, 166, 66)
	local COLOR_RED = Color(200, 66, 66)
	local COLOR_TEXT = Color(205, 205, 205)
	local COLOR_DIM = Color(120, 120, 120)

	local function MakeButton(parent, text, color, callback)
		local btn = parent:Add("DButton")
		btn:SetText(text)
		btn:SetFont("metroTradeBtn")
		btn:SetTextColor(color)
		btn.Paint = function(me, w, h)
			local alpha = me:IsHovered() and 55 or 22
			surface.SetDrawColor(color.r, color.g, color.b, me.filled and 90 or alpha)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(color.r, color.g, color.b, 110)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		btn.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			if (callback) then callback() end
		end
		return btn
	end

	local function StyleScroll(scroll)
		scroll.Paint = nil
		local bar = scroll:GetVBar()
		bar:SetWide(S(4))
		bar.Paint = function(_, w, h)
			surface.SetDrawColor(20, 20, 20, 120)
			surface.DrawRect(0, 0, w, h)
		end
		bar.btnGrip.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 120)
			surface.DrawRect(0, 0, w, h)
		end
		bar.btnUp.Paint = function() end
		bar.btnDown.Paint = function() end
	end

	-- Crea una fila de item (icono + nombre + cantidad). hint/callback opcionales.
	local function MakeItemRow(parent, info, accent, hint, callback)
		local row = parent:Add("DButton")
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(S(42))
		row:DockMargin(0, 0, 0, S(4))
		row.Paint = function(me, w, h)
			local hover = me:IsHovered() and callback
			surface.SetDrawColor(60, 60, 60, hover and 60 or 28)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(accent.r, accent.g, accent.b, 50)
			surface.DrawRect(0, 0, S(2), h)

			draw.SimpleText(info.name, "metroTradeLabel", S(48), h / 2 - S(8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if ((info.amount or 1) > 1) then
				draw.SimpleText("x" .. info.amount, "metroTradeSmall", S(48), h / 2 + S(9), COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			if (hover and hint) then
				draw.SimpleText(hint, "metroTradeSmall", w - S(8), h / 2, COLOR_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		local icon = row:Add("SpawnIcon")
		icon:SetModel((info.model and info.model != "") and info.model or "models/props_junk/cardboard_box001a.mdl")
		icon:SetSize(S(38), S(38))
		icon:SetPos(S(4), S(2))
		icon:SetMouseInputEnabled(false)

		if (callback) then
			row.DoClick = function()
				surface.PlaySound("efg/ui/click.wav")
				callback(info)
			end
		end
		return row
	end

	-- ════════════════════════════════════════════════════════════════
	--  VENTANA DE INTERCAMBIO
	-- ════════════════════════════════════════════════════════════════

	local PANEL = {}
	DEFINE_BASECLASS("EditablePanel")

	function PANEL:Init()
		if (IsValid(ix.gui.intercambio)) then
			ix.gui.intercambio:Remove()
		end
		ix.gui.intercambio = self

		surface.PlaySound("interface/inv_belt.mp3")

		self:SetSize(ScrW(), ScrH())
		self:MakePopup()
		self:SetAlpha(0)
		self:AlphaTo(255, 0.25)

		self.data = nil

		local pw, ph = S(840), S(640)

		self.main = self:Add("EditablePanel")
		self.main:SetSize(pw, ph)
		self.main:SetPos(ScrW() / 2 - pw / 2, ScrH() / 2 - ph / 2)
		self.main.Paint = function(_, w, h)
			ix.util.DrawBlur(self.main, 5)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		-- Cabecera
		self.header = self.main:Add("EditablePanel")
		self.header:Dock(TOP)
		self.header:SetTall(S(36))
		self.header.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 26)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 60)
			surface.DrawRect(0, h - 1, w, 1)

			local other = self.data and self.data.otherName or "..."
			draw.SimpleText("INTERCAMBIO con " .. other, "metroTradeTitle", S(12), h / 2, COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		self.closeBtn = self.header:Add("DButton")
		self.closeBtn:Dock(RIGHT)
		self.closeBtn:SetWide(S(70))
		self.closeBtn:SetText("")
		self.closeBtn.Paint = function(me, w, h)
			draw.SimpleText("CERRAR X", "metroTradeLabel", w / 2, h / 2, me:IsHovered() and COLOR_RED or COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		self.closeBtn.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self:SendCancel()
		end

		-- Pie con acciones
		self.footer = self.main:Add("EditablePanel")
		self.footer:Dock(BOTTOM)
		self.footer:SetTall(S(48))
		self.footer:DockMargin(S(10), S(8), S(10), S(10))

		self.btnCancel = MakeButton(self.footer, "CANCELAR", COLOR_RED, function()
			self:SendCancel()
		end)
		self.btnCancel:Dock(LEFT)
		self.btnCancel:SetWide(S(160))

		self.btnConfirm = MakeButton(self.footer, "CONFIRMAR", COLOR_GREEN, function()
			local newVal = not (self.data and self.data.myConfirm)
			net.Start(PLUGIN.netConfirm)
				net.WriteBool(newVal)
			net.SendToServer()
		end)
		self.btnConfirm:Dock(FILL)
		self.btnConfirm:DockMargin(S(8), 0, 0, 0)

		-- Cuerpo
		self.body = self.main:Add("EditablePanel")
		self.body:Dock(FILL)
		self.body:DockMargin(S(10), S(8), S(10), S(4))

		-- Fila de ofertas (arriba)
		self.offers = self.body:Add("EditablePanel")
		self.offers:Dock(TOP)
		self.offers:SetTall(S(250))
		self.offers:DockMargin(0, 0, 0, S(8))

		self.myOfferPanel = self:MakeColumn(self.offers, true)
		self.myOfferPanel:Dock(LEFT)
		self.myOfferPanel:SetWide(S(400))

		self.theirOfferPanel = self:MakeColumn(self.offers, false)
		self.theirOfferPanel:Dock(RIGHT)
		self.theirOfferPanel:SetWide(S(400))

		-- Inventario (abajo)
		self.invHeader = self.body:Add("DLabel")
		self.invHeader:Dock(TOP)
		self.invHeader:SetTall(S(20))
		self.invHeader:SetFont("metroTradeLabel")
		self.invHeader:SetTextColor(COLOR_ACCENT)
		self.invHeader:SetText("TU INVENTARIO  (clic para ofrecer)")

		self.invScroll = self.body:Add("DScrollPanel")
		self.invScroll:Dock(FILL)
		StyleScroll(self.invScroll)
	end

	function PANEL:MakeColumn(parent, mine)
		local col = parent:Add("EditablePanel")
		col.mine = mine
		col.Paint = function(pnl, w, h)
			surface.SetDrawColor(COLOR_SUB)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)

			local data = self.data
			local confirmed = false
			if (data) then
				confirmed = mine and data.myConfirm or (not mine and data.theirConfirm)
			end
			local title = mine and "TU OFERTA" or ("OFERTA DE " .. (data and data.otherName or "..."))
			draw.SimpleText(title, "metroTradeLabel", S(8), S(8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			if (confirmed) then
				draw.SimpleText("+ CONFIRMADO", "metroTradeSmall", w - S(8), S(10), COLOR_GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			else
				draw.SimpleText("● sin confirmar", "metroTradeSmall", w - S(8), S(10), COLOR_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			end
		end

		col.scroll = col:Add("DScrollPanel")
		col.scroll:Dock(FILL)
		col.scroll:DockMargin(S(8), S(30), S(8), S(8))
		StyleScroll(col.scroll)
		return col
	end

	-- ════════════════════════════════════════════════════════════════
	--  ESTADO
	-- ════════════════════════════════════════════════════════════════

	function PANEL:SendCancel()
		net.Start(PLUGIN.netCancel)
		net.SendToServer()
	end

	function PANEL:SetState(data)
		self.data = data
		self:Rebuild()
	end

	function PANEL:Rebuild()
		local data = self.data
		if (not data) then return end

		-- Ofertas
		self.myOfferPanel.scroll:Clear()
		for _, info in ipairs(data.myOffer) do
			MakeItemRow(self.myOfferPanel.scroll, info, COLOR_GREEN, "QUITAR", function(itm)
				net.Start(PLUGIN.netOffer)
					net.WriteString("remove")
					net.WriteUInt(itm.id, 32)
				net.SendToServer()
			end)
		end

		self.theirOfferPanel.scroll:Clear()
		for _, info in ipairs(data.theirOffer) do
			MakeItemRow(self.theirOfferPanel.scroll, info, COLOR_ACCENT)
		end

		-- Inventario local (excluye lo ya ofrecido)
		self.invScroll:Clear()

		local offered = {}
		for _, info in ipairs(data.myOffer) do
			offered[info.id] = true
		end

		local char = LocalPlayer():GetCharacter()
		local inv = char and char:GetInventory()
		if (inv) then
			local items = {}
			for _, item in pairs(inv:GetItems()) do
				if (not offered[item:GetID()]) then
					items[#items + 1] = item
				end
			end
			table.sort(items, function(x, y) return x:GetName() < y:GetName() end)

			if (#items == 0) then
				local empty = self.invScroll:Add("DLabel")
				empty:Dock(TOP)
				empty:SetTall(S(30))
				empty:SetFont("metroTradeSmall")
				empty:SetTextColor(COLOR_DIM)
				empty:SetContentAlignment(5)
				empty:SetText("No tienes objetos disponibles para ofrecer.")
			else
				for _, item in ipairs(items) do
					local info = {
						id = item:GetID(),
						name = item:GetName(),
						model = item:GetModel(),
						amount = item:GetData("Amount", 1),
					}
					MakeItemRow(self.invScroll, info, COLOR_TEXT, "OFRECER", function(itm)
						net.Start(PLUGIN.netOffer)
							net.WriteString("add")
							net.WriteUInt(itm.id, 32)
						net.SendToServer()
					end)
				end
			end
		end

		-- Botón confirmar
		if (data.myConfirm) then
			self.btnConfirm:SetText("CONFIRMADO +  (clic para anular)")
			self.btnConfirm.filled = true
		else
			self.btnConfirm:SetText("CONFIRMAR")
			self.btnConfirm.filled = false
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  PAINT / CIERRE
	-- ════════════════════════════════════════════════════════════════

	function PANEL:Paint(w, h)
		ix.util.DrawBlur(self, 4)
		surface.SetDrawColor(COLOR_BG)
		surface.DrawRect(0, 0, w, h)
	end

	function PANEL:OnKeyCodePressed(keyCode)
		if (keyCode == KEY_SPACE) then
			self:SendCancel()
		end
	end

	-- Cierre solicitado por el servidor (intercambio terminado).
	function PANEL:Close(reason)
		self.closing = true
		self:AlphaTo(0, 0.2, 0, function()
			BaseClass.Remove(self)
		end)
	end

	vgui.Register("metroIntercambio", PANEL, "EditablePanel")

	-- ════════════════════════════════════════════════════════════════
	--  PROMPT DE SOLICITUD
	-- ════════════════════════════════════════════════════════════════

	function ix.intercambio.ShowRequest(name)
		if (IsValid(ix.gui.intercambioReq)) then
			ix.gui.intercambioReq:Remove()
		end

		surface.PlaySound("buttons/button15.wav")

		local frame = vgui.Create("EditablePanel")
		ix.gui.intercambioReq = frame
		local fw, fh = S(360), S(150)
		frame:SetSize(fw, fh)
		frame:SetPos(ScrW() / 2 - fw / 2, ScrH() * 0.7)
		frame:MakePopup()
		frame:SetAlpha(0)
		frame:AlphaTo(255, 0.2)
		frame.Paint = function(pnl, w, h)
			ix.util.DrawBlur(pnl, 5)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 90)
			surface.DrawOutlinedRect(0, 0, w, h, 2)

			draw.SimpleText("SOLICITUD DE INTERCAMBIO", "metroTradeLabel", w / 2, S(18), COLOR_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(name .. " quiere intercambiar contigo.", "metroTradeSmall", w / 2, S(46), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local function respond(accept)
			net.Start(PLUGIN.netRespond)
				net.WriteBool(accept)
			net.SendToServer()
			frame:AlphaTo(0, 0.15, 0, function() frame:Remove() end)
		end

		local accept = MakeButton(frame, "ACEPTAR", COLOR_GREEN, function() respond(true) end)
		accept:SetSize(S(150), S(34))
		accept:SetPos(S(20), fh - S(48))

		local decline = MakeButton(frame, "RECHAZAR", COLOR_RED, function() respond(false) end)
		decline:SetSize(S(150), S(34))
		decline:SetPos(fw - S(170), fh - S(48))

		-- Auto-cierre a los 30s.
		timer.Simple(30, function()
			if (IsValid(frame)) then frame:Remove() end
		end)
	end
end)
