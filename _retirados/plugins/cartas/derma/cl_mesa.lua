timer.Simple(0, function()
	local PLUGIN = ix.plugin.Get("cartas")
	if (not PLUGIN) then return end

	-- Escala basada en la ALTURA (un panel diseñado a 1080p siempre cabe).
	local function S(v)
		return math.ceil(v * (ScrH() / 1080))
	end

	-- Fuentes propias (coherentes con la escala; metroui usa base 640 y desborda).
	if (not CARTAS_FONTS_READY or CARTAS_FONTS_H != ScrH()) then
		surface.CreateFont("metroCartasTitle", {font = "Roboto", size = S(22), weight = 700, antialias = true, extended = true})
		surface.CreateFont("metroCartasLabel", {font = "Roboto", size = S(16), weight = 600, antialias = true, extended = true})
		surface.CreateFont("metroCartasSmall", {font = "Roboto", size = S(12), weight = 500, antialias = true, extended = true})
		surface.CreateFont("metroCartasBtn", {font = "Roboto", size = S(15), weight = 700, antialias = true, extended = true})
		surface.CreateFont("metroCartaRank", {font = "Roboto", size = S(19), weight = 800, antialias = true, extended = true})
		surface.CreateFont("metroCartaSuit", {font = "Roboto", size = S(28), weight = 500, antialias = true, extended = true})
		CARTAS_FONTS_READY = true
		CARTAS_FONTS_H = ScrH()
	end

	local COLOR_BG = Color(15, 15, 15, 230)
	local COLOR_PANEL = Color(33, 33, 33, 240)
	local COLOR_BORDER = Color(70, 70, 70, 120)
	local COLOR_ACCENT = Color(190, 150, 70)
	local COLOR_GREEN = Color(66, 166, 66)
	local COLOR_RED = Color(200, 66, 66)
	local COLOR_TEXT = Color(205, 205, 205)
	local COLOR_DIM = Color(120, 120, 120)
	local COLOR_FELT = Color(28, 70, 45, 245)
	local COLOR_CARD = Color(236, 234, 226)
	local COLOR_CARD_BLACK = Color(28, 28, 28)
	local COLOR_CARD_RED = Color(180, 40, 40)

	local function MakeButton(parent, text, color, callback)
		local btn = parent:Add("DButton")
		btn:SetText(text)
		btn:SetFont("metroCartasBtn")
		btn:SetTextColor(color)
		btn.Paint = function(_, w, h)
			local alpha = btn:IsHovered() and 55 or 22
			surface.SetDrawColor(color.r, color.g, color.b, alpha)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(color.r, color.g, color.b, 90)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		btn.DoClick = function()
			surface.PlaySound("tls/click.wav")
			if (callback) then callback() end
		end
		return btn
	end

	local function DrawCard(x, y, w, h, card, faceDown)
		if (faceDown or not card or card.rank == 0) then
			draw.RoundedBox(S(4), x, y, w, h, Color(150, 45, 45))
			draw.RoundedBox(S(3), x + S(4), y + S(4), w - S(8), h - S(8), Color(90, 28, 28))
			return
		end

		draw.RoundedBox(S(4), x, y, w, h, COLOR_CARD)
		local rankStr = ix.cartas.RANK_NAMES[card.rank] or tostring(card.rank)
		local suitStr = ix.cartas.SUIT_CHARS[card.suit] or "?"
		local col = ix.cartas.SUIT_RED[card.suit] and COLOR_CARD_RED or COLOR_CARD_BLACK

		draw.SimpleText(rankStr, "metroCartaRank", x + S(5), y + S(3), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(suitStr, "metroCartaSuit", x + w / 2, y + h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(rankStr, "metroCartaRank", x + w - S(5), y + h - S(3), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	local PIP_LAYOUT = {
		[1] = {{0.5, 0.5}},
		[2] = {{0.3, 0.3}, {0.7, 0.7}},
		[3] = {{0.3, 0.3}, {0.5, 0.5}, {0.7, 0.7}},
		[4] = {{0.3, 0.3}, {0.7, 0.3}, {0.3, 0.7}, {0.7, 0.7}},
		[5] = {{0.3, 0.3}, {0.7, 0.3}, {0.5, 0.5}, {0.3, 0.7}, {0.7, 0.7}},
		[6] = {{0.3, 0.3}, {0.7, 0.3}, {0.3, 0.5}, {0.7, 0.5}, {0.3, 0.7}, {0.7, 0.7}},
	}

	local function DrawDie(x, y, size, value)
		draw.RoundedBox(S(6), x, y, size, size, COLOR_CARD)
		local pips = PIP_LAYOUT[value]
		if (not pips) then return end

		local r = math.max(S(4), size * 0.09)
		surface.SetDrawColor(COLOR_CARD_BLACK)
		for _, p in ipairs(pips) do
			surface.DrawRect(x + p[1] * size - r, y + p[2] * size - r, r * 2, r * 2)
		end
	end

	local function DrawDiceRow(panelW, y, dice)
		local n = #dice
		if (n == 0) then return end
		local size, gap = S(72), S(16)
		local totalW = n * size + (n - 1) * gap
		local startX = panelW / 2 - totalW / 2
		for i, value in ipairs(dice) do
			DrawDie(startX + (i - 1) * (size + gap), y, size, value)
		end
	end

	local function DrawHand(panelW, y, cards, hideHole)
		local cw, ch, gap = S(74), S(104), S(12)
		local n = #cards
		if (n == 0) then return end
		local totalW = n * cw + (n - 1) * gap
		local startX = panelW / 2 - totalW / 2
		for i, card in ipairs(cards) do
			DrawCard(startX + (i - 1) * (cw + gap), y, cw, ch, card, hideHole and card.rank == 0)
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  PANEL
	-- ════════════════════════════════════════════════════════════════

	local PANEL = {}
	DEFINE_BASECLASS("EditablePanel")

	function PANEL:Init()
		if (IsValid(ix.gui.cartasMesa)) then
			ix.gui.cartasMesa:Remove()
		end
		ix.gui.cartasMesa = self

		surface.PlaySound("interface/inv_belt.mp3")

		self:SetSize(ScrW(), ScrH())
		self:MakePopup()
		self:SetAlpha(0)
		self:AlphaTo(255, 0.25)

		self.data = nil
		self.betAmount = 0

		local pw, ph = S(900), S(700)

		self.mainPanel = self:Add("EditablePanel")
		self.mainPanel:SetSize(pw, ph)
		self.mainPanel:SetPos(ScrW() / 2 - pw / 2, ScrH() / 2 - ph / 2)
		self.mainPanel.Paint = function(_, w, h)
			ix.util.DrawBlur(self.mainPanel, 5)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		-- Cabecera
		self.header = self.mainPanel:Add("EditablePanel")
		self.header:Dock(TOP)
		self.header:SetTall(S(34))
		self.header:SetMouseInputEnabled(false)
		self.header.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 26)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 60)
			surface.DrawRect(0, h - 1, w, 1)

			local title = (self.data and self.data.gameType == "dados") and "MESA DE DADOS" or "MESA DE BLACKJACK"
			draw.SimpleText(title, "metroCartasTitle", S(12), h / 2, COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local money = self.data and self.data.money or 0
			draw.SimpleText(("%i Balas"):format(money), "metroCartasLabel", w - S(84), h / 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		-- Botón cerrar (dentro de la cabecera, clicable)
		self.closeBtn = self.header:Add("DButton")
		self.closeBtn:Dock(RIGHT)
		self.closeBtn:SetWide(S(70))
		self.closeBtn:SetText("")
		self.closeBtn.Paint = function(me, w, h)
			local c = me:IsHovered() and COLOR_RED or COLOR_TEXT
			draw.SimpleText("CERRAR ✕", "metroCartasLabel", w / 2, h / 2, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		self.closeBtn.DoClick = function()
			surface.PlaySound("tls/click.wav")
			self:Remove()
		end
		-- la cabecera ignora el ratón salvo este botón
		self.header:SetMouseInputEnabled(true)
		self.header.OnMousePressed = function() end

		-- Tapete
		self.felt = self.mainPanel:Add("EditablePanel")
		self.felt:Dock(FILL)
		self.felt:SetMouseInputEnabled(false)
		self.felt.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_FELT)
			surface.DrawRect(0, 0, w, h)

			local data = self.data
			if (not data) then return end
			local isDados = (data.gameType == "dados")

			draw.SimpleText("LA BANCA", "metroCartasSmall", w / 2, S(8), COLOR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			if (isDados) then
				DrawDiceRow(w, S(30), data.dealer)
			else
				DrawHand(w, S(24), data.dealer, data.state == "playing")
			end

			if (#data.dealer > 0) then
				local dealerText = (not isDados and data.state == "playing") and ("Muestra: %i"):format(data.dealerTotal) or ("Total: %i"):format(data.dealerTotal)
				draw.SimpleText(dealerText, "metroCartasLabel", w / 2, S(140), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			if (data.state == "done" and data.result != "") then
				draw.SimpleText(data.result, "metroCartasTitle", w / 2, h / 2, COLOR_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if (isDados) then
				DrawDiceRow(w, h - S(150), data.player)
			else
				DrawHand(w, h - S(152), data.player, false)
			end

			if (#data.player > 0) then
				local label = isDados and ("Tu tirada: %i"):format(data.playerTotal) or ("Tu mano: %i"):format(data.playerTotal)
				draw.SimpleText(label, "metroCartasLabel", w / 2, h - S(40), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			else
				local hint = isDados and "Haz tu apuesta para tirar los dados." or "Haz tu apuesta para repartir."
				draw.SimpleText(hint, "metroCartasLabel", w / 2, h / 2, COLOR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		-- Controles
		self.controls = self.mainPanel:Add("EditablePanel")
		self.controls:Dock(BOTTOM)
		self.controls:SetTall(S(50))
		self.controls:DockMargin(S(8), S(6), S(8), S(8))

		-- Hint de cierre (NO captura el ratón)
		self.closeHint = self.mainPanel:Add("DLabel")
		self.closeHint:Dock(BOTTOM)
		self.closeHint:SetTall(S(16))
		self.closeHint:SetMouseInputEnabled(false)
		self.closeHint:SetFont("metroCartasSmall")
		self.closeHint:SetTextColor(Color(255, 255, 255, 60))
		self.closeHint:SetContentAlignment(5)
		self.closeHint:SetText("Presiona 'ESPACIO' para cerrar")
	end

	function PANEL:SetState(data)
		local firstTime = (self.data == nil)
		self.data = data

		if (firstTime or self.betAmount < data.minBet) then
			self.betAmount = data.minBet
		end
		self.betAmount = math.Clamp(self.betAmount, data.minBet, math.min(data.maxBet, math.max(data.money, data.minBet)))

		self:BuildControls()
	end

	function PANEL:SendAction(action, amount)
		net.Start(PLUGIN.netAction)
			net.WriteString(action)
			net.WriteUInt(amount or 0, 32)
		net.SendToServer()
	end

	function PANEL:BuildControls()
		self.controls:Clear()

		local data = self.data
		if (not data) then return end

		if (data.state == "playing") then
			local hit = MakeButton(self.controls, "PEDIR CARTA", COLOR_GREEN, function()
				self:SendAction("hit")
			end)
			hit:Dock(LEFT)
			hit:SetWide(S(150))
			hit:DockMargin(0, 0, S(8), 0)

			local stand = MakeButton(self.controls, "PLANTARSE", COLOR_ACCENT, function()
				self:SendAction("stand")
			end)
			stand:Dock(FILL)
		else
			local betLabel = self.controls:Add("DLabel")
			betLabel:Dock(LEFT)
			betLabel:SetWide(S(120))
			betLabel:SetFont("metroCartasLabel")
			betLabel:SetTextColor(COLOR_ACCENT)
			betLabel:SetContentAlignment(5)
			betLabel.Think = function(me) me:SetText(("Apuesta: %i"):format(self.betAmount)) end

			local function AddChip(text, delta)
				local c = MakeButton(self.controls, text, COLOR_TEXT, function()
					self.betAmount = math.Clamp(self.betAmount + delta, data.minBet,
						math.min(data.maxBet, math.max(data.money, data.minBet)))
				end)
				c:Dock(LEFT)
				c:SetWide(S(48))
				c:DockMargin(S(2), 0, S(2), 0)
			end
			AddChip("+5", 5)
			AddChip("+25", 25)
			AddChip("+50", 50)
			AddChip("MIN", -math.huge)
			AddChip("MÁX", math.huge)

			local dealText
			if (data.gameType == "dados") then
				dealText = (data.state == "done") and "TIRAR DE NUEVO" or "TIRAR DADOS"
			else
				dealText = (data.state == "done") and "NUEVA MANO" or "REPARTIR"
			end

			local deal = MakeButton(self.controls, dealText, COLOR_GREEN, function()
				if (self.betAmount > self.data.money) then
					LocalPlayer():Notify("No tienes suficientes Balas.")
					return
				end
				self:SendAction("bet", self.betAmount)
			end)
			deal:Dock(FILL)
			deal:DockMargin(S(8), 0, 0, 0)
		end
	end

	function PANEL:Paint(w, h)
		ix.util.DrawBlur(self, 4)
		surface.SetDrawColor(COLOR_BG)
		surface.DrawRect(0, 0, w, h)
	end

	function PANEL:OnKeyCodePressed(keyCode)
		if (keyCode == KEY_SPACE) then
			self:Remove()
		end
	end

	function PANEL:Remove()
		net.Start(PLUGIN.netClose)
		net.SendToServer()

		self:AlphaTo(0, 0.25, 0, function()
			BaseClass.Remove(self)
		end)
	end

	vgui.Register("metroMesaCartas", PANEL, "EditablePanel")
end)
