-- Lector del estado de póker (fuera del timer: lo usa el receiver de cl_plugin).
function ix.cartas.ReadPokerState()
	local d = {}

	d.maxSeats = net.ReadUInt(4)
	d.state = net.ReadString()
	d.pot = net.ReadUInt(32)
	d.currentBet = net.ReadUInt(32)
	d.smallBlind = net.ReadUInt(32)
	d.bigBlind = net.ReadUInt(32)
	d.minBuy = net.ReadUInt(32)
	d.maxBet = net.ReadUInt(32)
	d.dealerSeat = net.ReadUInt(4)
	d.turnSeat = net.ReadUInt(4)
	d.turnTimeLeft = net.ReadUInt(8)
	d.minRaise = net.ReadUInt(32)
	d.mySeat = net.ReadUInt(4)
	d.myMoney = net.ReadUInt(32)
	d.result = net.ReadString()

	d.board = {}
	local bc = net.ReadUInt(3)
	for _ = 1, bc do
		d.board[#d.board + 1] = {rank = net.ReadUInt(4), suit = net.ReadUInt(3)}
	end

	d.seats = {}
	for i = 1, d.maxSeats do
		if (net.ReadBool()) then
			local s = {cards = {}, revealed = false, hasCards = false}
			s.name = net.ReadString()
			s.stack = net.ReadUInt(32)
			s.roundCommitted = net.ReadUInt(32)
			s.committed = net.ReadUInt(32)
			s.folded = net.ReadBool()
			s.allIn = net.ReadBool()
			s.inHand = net.ReadBool()

			if (net.ReadBool()) then
				s.hasCards = true
				if (net.ReadBool()) then
					s.revealed = true
					s.cards[1] = {rank = net.ReadUInt(4), suit = net.ReadUInt(3)}
					s.cards[2] = {rank = net.ReadUInt(4), suit = net.ReadUInt(3)}
					if (net.ReadBool()) then
						s.cat = net.ReadUInt(4)
					end
				end
			end

			d.seats[i] = s
		end
	end

	return d
end

timer.Simple(0, function()
	local PLUGIN = ix.plugin.Get("cartas")
	if (not PLUGIN) then return end

	local function S(v)
		return math.ceil(v * (ScrH() / 1080))
	end

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
	local COLOR_FELT = Color(28, 70, 45, 245) -- mismo verde que la mesa de Blackjack/Dados
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

		draw.SimpleText(rankStr, "metroCartaRank", x + S(4), y + S(2), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(suitStr, "metroCartaSuit", x + w / 2, y + h / 2 + S(2), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		-- rango en espejo abajo a la derecha, igual que Blackjack/Dados; las mini-cartas
		-- de los asientos (22px) son demasiado pequeñas para el segundo rango sin solapar.
		if (w >= S(35)) then
			draw.SimpleText(rankStr, "metroCartaRank", x + w - S(4), y + h - S(2), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  PANEL
	-- ════════════════════════════════════════════════════════════════

	local PANEL = {}
	DEFINE_BASECLASS("EditablePanel")

	function PANEL:Init()
		if (IsValid(ix.gui.cartasPoker)) then
			ix.gui.cartasPoker:Remove()
		end
		ix.gui.cartasPoker = self

		surface.PlaySound("interface/inv_belt.mp3")

		self:SetSize(ScrW(), ScrH())
		self:MakePopup()
		self:SetAlpha(0)
		self:AlphaTo(255, 0.25)

		self.data = nil
		self.recvTime = CurTime()
		self.buyIn = 0
		self.raiseAmount = 0

		local pw, ph = S(760), S(540)

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

		self.header = self.mainPanel:Add("EditablePanel")
		self.header:Dock(TOP)
		self.header:SetTall(S(34))
		self.header.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 26)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 60)
			surface.DrawRect(0, h - 1, w, 1)

			draw.SimpleText("PÓKER · TEXAS HOLD'EM", "metroCartasTitle", S(12), h / 2, COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local money = self.data and self.data.myMoney or 0
			draw.SimpleText(("Tus Balas: %i"):format(money), "metroCartasLabel", w - S(84), h / 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

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

		self.felt = self.mainPanel:Add("EditablePanel")
		self.felt:Dock(FILL)
		self.felt:SetMouseInputEnabled(false)
		self.felt.Paint = function(_, w, h)
			self:PaintFelt(w, h)
		end

		self.controls = self.mainPanel:Add("EditablePanel")
		self.controls:Dock(BOTTOM)
		self.controls:SetTall(S(50))
		self.controls:DockMargin(S(8), S(6), S(8), S(8))

		self.closeHint = self.mainPanel:Add("DLabel")
		self.closeHint:Dock(BOTTOM)
		self.closeHint:SetTall(S(16))
		self.closeHint:SetMouseInputEnabled(false)
		self.closeHint:SetFont("metroCartasSmall")
		self.closeHint:SetTextColor(Color(255, 255, 255, 60))
		self.closeHint:SetContentAlignment(5)
		self.closeHint:SetText("Presiona 'ESPACIO' para cerrar (sigues sentado)")
	end

	-- ════════════════════════════════════════════════════════════════
	--  DIBUJO DE LA MESA
	-- ════════════════════════════════════════════════════════════════

	function PANEL:PaintFelt(w, h)
		surface.SetDrawColor(COLOR_FELT)
		surface.DrawRect(0, 0, w, h)

		local data = self.data
		if (not data) then return end

		local cx, cy = w / 2, h / 2 - S(6)

		surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 50)
		surface.DrawOutlinedRect(S(110), S(60), w - S(220), h - S(130), 2)

		-- Cartas comunitarias.
		local cwc, chc, gap = S(44), S(62), S(8)
		local totalW = 5 * cwc + 4 * gap
		local bx = cx - totalW / 2
		for i = 1, 5 do
			local card = data.board[i]
			local x = bx + (i - 1) * (cwc + gap)
			if (card) then
				DrawCard(x, cy - chc / 2, cwc, chc, card, false)
			else
				surface.SetDrawColor(255, 255, 255, 14)
				surface.DrawOutlinedRect(x, cy - chc / 2, cwc, chc, 1)
			end
		end

		draw.SimpleText(("BOTE: %i Balas"):format(data.pot), "metroCartasLabel",
			cx, cy - chc / 2 - S(14), COLOR_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (data.state == "waiting") then
			draw.SimpleText("Esperando jugadores (mínimo 2)...", "metroCartasSmall",
				cx, cy + chc / 2 + S(12), COLOR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif (data.state == "showdown" and data.result != "") then
			draw.SimpleText(data.result, "metroCartasSmall",
				cx, cy + chc / 2 + S(12), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- Asientos alrededor del óvalo (mi asiento abajo).
		local n = data.maxSeats
		local rx, ry = w / 2 - S(80), h / 2 - S(46)
		local pivot = data.mySeat > 0 and data.mySeat or 1

		for i = 1, n do
			local rel = (i - pivot) % n
			local theta = math.rad(90 + rel * (360 / n))
			self:DrawSeat(data, i, cx + rx * math.cos(theta), cy + ry * math.sin(theta))
		end
	end

	function PANEL:DrawSeat(data, i, cx, cy)
		local seat = data.seats[i]
		local bw, bh = S(118), S(46)
		local x, y = cx - bw / 2, cy - bh / 2

		if (not seat) then
			surface.SetDrawColor(255, 255, 255, 12)
			surface.DrawOutlinedRect(x, y, bw, bh, 1)
			draw.SimpleText("Asiento " .. i, "metroCartasSmall", cx, cy, COLOR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local isTurn = (data.turnSeat == i)
		draw.RoundedBox(S(4), x, y, bw, bh, seat.folded and Color(20, 20, 20, 210) or Color(42, 42, 42, 230))

		surface.SetDrawColor(isTurn and COLOR_GREEN or COLOR_BORDER)
		surface.DrawOutlinedRect(x, y, bw, bh, isTurn and 2 or 1)

		draw.SimpleText(seat.name, "metroCartasSmall", x + S(6), y + S(5),
			seat.folded and COLOR_DIM or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(("%i Balas"):format(seat.stack), "metroCartasSmall", x + S(6), y + S(18),
			COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local tag
		if (seat.folded) then tag = "RETIRADO"
		elseif (seat.allIn) then tag = "ALL-IN"
		elseif (seat.roundCommitted > 0) then tag = ("Apuesta: %i"):format(seat.roundCommitted) end
		if (tag) then
			draw.SimpleText(tag, "metroCartasSmall", x + S(6), y + S(31), COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		if (seat.hasCards) then
			local mcw, mch = S(22), S(30)
			local mcx = x + bw - mcw * 2 - S(8)
			local mcy = y + bh / 2 - mch / 2
			if (seat.revealed) then
				DrawCard(mcx, mcy, mcw, mch, seat.cards[1], false)
				DrawCard(mcx + mcw + S(2), mcy, mcw, mch, seat.cards[2], false)
				if (seat.cat) then
					draw.SimpleText(ix.cartas.poker.CategoryName(seat.cat), "metroCartasSmall",
						x + bw - S(4), y + bh - S(2), COLOR_GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				end
			else
				DrawCard(mcx, mcy, mcw, mch, nil, true)
				DrawCard(mcx + mcw + S(2), mcy, mcw, mch, nil, true)
			end
		end

		if (data.dealerSeat == i) then
			draw.RoundedBox(S(10), x - S(8), y, S(20), S(20), Color(230, 230, 230))
			draw.SimpleText("D", "metroCartasSmall", x + S(2), y + S(10), COLOR_CARD_BLACK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if (isTurn) then
			local left = math.max(0, math.floor((data.turnTimeLeft or 0) - (CurTime() - self.recvTime)))
			draw.SimpleText(left .. "s", "metroCartasSmall", x + bw - S(6), y + S(5), COLOR_GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  ESTADO + CONTROLES
	-- ════════════════════════════════════════════════════════════════

	function PANEL:SetState(data)
		self.data = data
		self.recvTime = CurTime()

		if (self.buyIn <= 0) then
			self.buyIn = math.min(data.myMoney, data.minBuy)
		end

		self:BuildControls()
	end

	function PANEL:Send(action, amount)
		net.Start(PLUGIN.netPokerAction)
			net.WriteString(action)
			net.WriteUInt(math.Clamp(math.floor(amount or 0), 0, 4294967295), 32)
		net.SendToServer()
	end

	function PANEL:BuildControls()
		self.controls:Clear()

		local data = self.data
		if (not data) then return end

		-- Espectador: sentarse.
		if (data.mySeat == 0) then
			local minBuy = data.minBuy
			self.buyIn = math.Clamp(self.buyIn, minBuy, math.max(data.myMoney, minBuy))

			local label = self.controls:Add("DLabel")
			label:Dock(LEFT)
			label:SetWide(S(150))
			label:SetFont("metroCartasLabel")
			label:SetTextColor(COLOR_ACCENT)
			label:SetContentAlignment(5)
			label.Think = function(me) me:SetText(("Entrada: %i Balas"):format(self.buyIn)) end

			local function AddChip(text, delta)
				local c = MakeButton(self.controls, text, COLOR_TEXT, function()
					self.buyIn = math.Clamp(self.buyIn + delta, minBuy, math.max(data.myMoney, minBuy))
				end)
				c:Dock(LEFT)
				c:SetWide(S(56))
				c:DockMargin(S(2), 0, S(2), 0)
			end
			AddChip("+" .. data.bigBlind, data.bigBlind)
			AddChip("+" .. data.maxBet, data.maxBet)
			AddChip("MIN", -math.huge)

			local sit = MakeButton(self.controls, "SENTARSE", COLOR_GREEN, function()
				if (data.myMoney < minBuy) then
					LocalPlayer():Notify(("Necesitas al menos %i Balas."):format(minBuy))
					return
				end
				self:Send("sit", self.buyIn)
			end)
			sit:Dock(FILL)
			sit:DockMargin(S(6), 0, 0, 0)
			return
		end

		local mine = data.seats[data.mySeat]
		local isMyTurn = (data.turnSeat == data.mySeat)

		local stand = MakeButton(self.controls, "LEVANTARSE", COLOR_RED, function()
			self:Send("stand")
		end)
		stand:Dock(RIGHT)
		stand:SetWide(S(100))
		stand:DockMargin(S(6), 0, 0, 0)

		if (not isMyTurn or not mine or not mine.inHand) then
			local wait = self.controls:Add("DLabel")
			wait:Dock(FILL)
			wait:SetFont("metroCartasLabel")
			wait:SetTextColor(COLOR_DIM)
			wait:SetContentAlignment(5)
			if (data.state == "waiting") then
				wait:SetText("Esperando a que empiece la mano...")
			elseif (data.state == "showdown") then
				wait:SetText("Fin de la mano. Mostrando cartas...")
			elseif (mine and not mine.inHand) then
				wait:SetText("Estás fuera de esta mano.")
			else
				wait:SetText("Esperando tu turno...")
			end
			return
		end

		local toCall = data.currentBet - mine.roundCommitted
		local maxTarget = math.min(mine.roundCommitted + mine.stack, data.maxBet)
		local minTarget = data.currentBet + data.minRaise

		local fold = MakeButton(self.controls, "RETIRARSE", COLOR_RED, function()
			self:Send("fold")
		end)
		fold:Dock(LEFT)
		fold:SetWide(S(100))
		fold:DockMargin(0, 0, S(6), 0)

		if (toCall <= 0) then
			local check = MakeButton(self.controls, "PASAR", COLOR_TEXT, function()
				self:Send("check")
			end)
			check:Dock(LEFT)
			check:SetWide(S(100))
			check:DockMargin(0, 0, S(6), 0)
		else
			local callTxt = (toCall >= mine.stack) and "IGUALAR (ALL-IN)" or ("IGUALAR %i"):format(toCall)
			local call = MakeButton(self.controls, callTxt, COLOR_GREEN, function()
				self:Send("call")
			end)
			call:Dock(LEFT)
			call:SetWide(S(130))
			call:DockMargin(0, 0, S(6), 0)
		end

		if (mine.stack > toCall and maxTarget >= minTarget) then
			self.raiseAmount = math.Clamp(self.raiseAmount, minTarget, maxTarget)

			local raiseLabel = self.controls:Add("DLabel")
			raiseLabel:Dock(LEFT)
			raiseLabel:SetWide(S(86))
			raiseLabel:SetFont("metroCartasSmall")
			raiseLabel:SetTextColor(COLOR_ACCENT)
			raiseLabel:SetContentAlignment(5)
			raiseLabel.Think = function(me) me:SetText(("Subir a: %i"):format(self.raiseAmount)) end

			local function AddChip(text, delta)
				local c = MakeButton(self.controls, text, COLOR_TEXT, function()
					self.raiseAmount = math.Clamp(self.raiseAmount + delta, minTarget, maxTarget)
				end)
				c:Dock(LEFT)
				c:SetWide(S(46))
				c:DockMargin(S(2), 0, S(2), 0)
			end
			AddChip("+" .. data.bigBlind, data.bigBlind)
			AddChip("+" .. (data.bigBlind * 5), data.bigBlind * 5)

			local raise = MakeButton(self.controls, "SUBIR", COLOR_ACCENT, function()
				self:Send("raise", self.raiseAmount)
			end)
			raise:Dock(LEFT)
			raise:SetWide(S(80))
			raise:DockMargin(0, 0, S(6), 0)
		end

		if (mine.stack > 0) then
			-- si el tope de mesa (maxBet) es menor que tu stack, esto no es un all-in
			-- real (te queda stack sin poder apostar); el botón lo refleja.
			local trueAllIn = (mine.roundCommitted + mine.stack) <= data.maxBet
			local allin = MakeButton(self.controls, trueAllIn and "ALL-IN" or "MÁXIMO", COLOR_RED, function()
				self:Send("raise", maxTarget)
			end)
			allin:Dock(LEFT)
			allin:SetWide(S(80))
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  PAINT / REMOVE
	-- ════════════════════════════════════════════════════════════════

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
		net.Start(PLUGIN.netPokerClose)
		net.SendToServer()

		self:AlphaTo(0, 0.25, 0, function()
			BaseClass.Remove(self)
		end)
	end

	vgui.Register("metroMesaPoker", PANEL, "EditablePanel")
end)
