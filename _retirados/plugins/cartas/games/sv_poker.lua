local PLUGIN = PLUGIN
local baraja = ix.cartas.baraja

-- ════════════════════════════════════════════════════════════════════
--  HELPERS DE ASIENTOS
-- ════════════════════════════════════════════════════════════════════

local function PCfg()
	return ix.cartas.config.poker
end

-- Siguiente asiento (circular) desde `from` que cumpla pred(seat).
local function NextSeat(ent, from, pred)
	local n = PCfg().maxSeats
	for step = 1, n do
		local idx = ((from - 1 + step) % n) + 1
		local s = ent.seats[idx]
		if (s and pred(s)) then
			return idx
		end
	end
	return nil
end

-- Primer asiento activo (en juego, sin all-in, con fichas) desde `from`.
local function FindActive(ent, from, inclusive)
	local n = PCfg().maxSeats
	local begin = inclusive and 0 or 1
	for step = begin, n do
		local idx = ((from - 1 + step) % n) + 1
		local s = ent.seats[idx]
		if (s and s.inHand and not s.allIn and s.stack > 0) then
			return idx
		end
	end
	return nil
end

local function SeatOf(ent, client)
	for i, s in pairs(ent.seats) do
		if (s and s.client == client) then
			return i
		end
	end
	return nil
end

local function CountInHand(ent)
	local n = 0
	for _, s in pairs(ent.seats) do
		if (s and s.inHand) then n = n + 1 end
	end
	return n
end

local function CountReady(ent)
	local n = 0
	for _, s in pairs(ent.seats) do
		if (s and s.stack > 0 and not s.leaving) then n = n + 1 end
	end
	return n
end

local function FreeSeat(ent)
	for i = 1, PCfg().maxSeats do
		if (not ent.seats[i]) then return i end
	end
	return nil
end

local inHandPred = function(s) return s.inHand end

-- ════════════════════════════════════════════════════════════════════
--  TIMERS DE TURNO
-- ════════════════════════════════════════════════════════════════════

local function TurnTimerName(ent)
	return "ixPokerTurn_" .. ent:EntIndex()
end

local function KillTurnTimer(ent)
	timer.Remove(TurnTimerName(ent))
end

local AutoAct  -- fwd

local function StartTurnTimer(ent)
	local cfg = PCfg()
	ent.turnDeadline = CurTime() + cfg.turnTime
	timer.Create(TurnTimerName(ent), cfg.turnTime, 1, function()
		if (IsValid(ent)) then AutoAct(ent) end
	end)
end

-- ════════════════════════════════════════════════════════════════════
--  DINERO / FICHAS
-- ════════════════════════════════════════════════════════════════════

local function CommitChips(ent, s, amount)
	amount = math.min(amount, s.stack)
	if (amount <= 0) then return end

	s.stack = s.stack - amount
	s.roundCommitted = s.roundCommitted + amount
	s.committed = s.committed + amount
	ent.pot = ent.pot + amount

	if (s.stack <= 0) then
		s.allIn = true
	end
end

-- ════════════════════════════════════════════════════════════════════
--  BROADCAST DE ESTADO
-- ════════════════════════════════════════════════════════════════════

local function SendPokerState(client, ent)
	if (not IsValid(client)) then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = PCfg()
	local mySeat = SeatOf(ent, client) or 0
	local turnTimeLeft = 0
	if (ent.turnSeat and ent.turnDeadline) then
		turnTimeLeft = math.Clamp(math.ceil(ent.turnDeadline - CurTime()), 0, 255)
	end

	net.Start(PLUGIN.netPokerState)
		net.WriteUInt(cfg.maxSeats, 4)
		net.WriteString(ent.state)
		net.WriteUInt(math.Clamp(ent.pot, 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(ent.currentBet, 0, 4294967295), 32)
		net.WriteUInt(cfg.smallBlind, 32)
		net.WriteUInt(cfg.bigBlind, 32)
		net.WriteUInt(cfg.bigBlind * cfg.minBuyMult, 32) -- entrada mínima para sentarse
		net.WriteUInt(ix.cartas.config.maxBet, 32) -- tope de apuesta por acción (compartido con Blackjack/Dados)
		net.WriteUInt(ent.dealerSeat or 0, 4)
		net.WriteUInt(ent.turnSeat or 0, 4)
		net.WriteUInt(turnTimeLeft, 8)
		net.WriteUInt(math.Clamp(ent.minRaise or cfg.bigBlind, 0, 4294967295), 32)
		net.WriteUInt(mySeat, 4)
		net.WriteUInt(math.Clamp(char:GetMoney(), 0, 4294967295), 32)
		net.WriteString(ent.result or "")

		net.WriteUInt(#ent.board, 3)
		for _, card in ipairs(ent.board) do
			ix.cartas.WriteCard(card)
		end

		for i = 1, cfg.maxSeats do
			local s = ent.seats[i]
			if (not s) then
				net.WriteBool(false)
			else
				net.WriteBool(true)
				net.WriteString(s.name or "?")
				net.WriteUInt(math.Clamp(s.stack, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(s.roundCommitted, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(s.committed, 0, 4294967295), 32)
				net.WriteBool(s.folded == true)
				net.WriteBool(s.allIn == true)
				net.WriteBool(s.inHand == true)

				local reveal = (i == mySeat) or (ent.showCards and s.inHand and not s.folded)
				local hasCards = (#s.hand > 0)

				net.WriteBool(hasCards)
				if (hasCards) then
					net.WriteBool(reveal)
					if (reveal) then
						ix.cartas.WriteCard(s.hand[1])
						ix.cartas.WriteCard(s.hand[2])

						local hasCat = (ent.showCards and s.handCat != nil)
						net.WriteBool(hasCat)
						if (hasCat) then
							net.WriteUInt(s.handCat, 4)
						end
					end
				end
			end
		end
	net.Send(client)
end

local function BroadcastPoker(ent)
	if (not ent.viewers) then return end

	for client in pairs(ent.viewers) do
		if (IsValid(client)) then
			SendPokerState(client, ent)
		else
			ent.viewers[client] = nil
		end
	end
end

-- ════════════════════════════════════════════════════════════════════
--  REPARTO DEL BOTE (side pots)
-- ════════════════════════════════════════════════════════════════════

local function DistributePot(ent)
	local seats = ent.seats

	-- Puntuar las manos no retiradas.
	for _, s in pairs(seats) do
		if (s and not s.folded and s.committed > 0 and #s.hand == 2) then
			local cards = {}
			for _, c in ipairs(s.hand) do cards[#cards + 1] = c end
			for _, c in ipairs(ent.board) do cards[#cards + 1] = c end

			local score, cat = ix.cartas.poker.Evaluate(cards)
			s.handScore = score
			s.handCat = cat
		end
	end

	-- Contribuciones por asiento (incluye retirados: su dinero forma capas del bote).
	local remaining = {}
	for i, s in pairs(seats) do
		if (s and s.committed > 0) then
			remaining[i] = s.committed
		end
	end

	local payouts = {}
	local guard = 0

	while (true) do
		guard = guard + 1
		if (guard > 64) then break end

		local minAmt
		for _, amt in pairs(remaining) do
			if (amt > 0 and (not minAmt or amt < minAmt)) then minAmt = amt end
		end
		if (not minAmt) then break end

		-- Construir la capa.
		local layer, contributors = 0, {}
		for i, amt in pairs(remaining) do
			if (amt > 0) then
				layer = layer + minAmt
				remaining[i] = amt - minAmt
				contributors[#contributors + 1] = i
			end
		end

		-- Ganadores = contribuyentes no retirados con mejor puntuación.
		local bestScore, winners = -1, {}
		for _, i in ipairs(contributors) do
			local s = seats[i]
			if (s and not s.folded and s.handScore) then
				if (s.handScore > bestScore) then
					bestScore = s.handScore
					winners = {i}
				elseif (s.handScore == bestScore) then
					winners[#winners + 1] = i
				end
			end
		end

		if (#winners > 0) then
			local share = math.floor(layer / #winners)
			local rem = layer - share * #winners
			for wi, i in ipairs(winners) do
				payouts[i] = (payouts[i] or 0) + share + (wi <= rem and 1 or 0)
			end
		end
	end

	-- Aplicar y construir texto de resultado.
	local parts = {}
	for i, amt in pairs(payouts) do
		local s = seats[i]
		if (s) then
			s.stack = s.stack + amt
			local catName = s.handCat and ix.cartas.poker.CategoryName(s.handCat) or ""
			parts[#parts + 1] = ("%s gana %i Balas (%s)"):format(s.name, amt, catName)
		end
	end

	ent.result = #parts > 0 and table.concat(parts, " · ") or "Sin ganadores."
	ent.pot = 0
end

-- ════════════════════════════════════════════════════════════════════
--  FIN DE MANO
-- ════════════════════════════════════════════════════════════════════

local MaybeStartHand  -- fwd

local function EndHandTimerName(ent)
	return "ixPokerEnd_" .. ent:EntIndex()
end

local function EndHand(ent)
	KillTurnTimer(ent)

	-- Procesar jugadores que se marcharon durante la mano.
	for i, s in pairs(ent.seats) do
		if (s and s.leaving) then
			if (s.stack > 0 and IsValid(s.client) and s.client:GetCharacter()) then
				s.client:GetCharacter():GiveMoney(s.stack)
			end
			if (IsValid(s.client)) then
				s.client.ixPokerLeftStack = nil
			end
			ent.seats[i] = nil
		end
	end

	-- Reset de mano.
	for _, s in pairs(ent.seats) do
		if (s) then
			s.hand = {}
			s.folded = false
			s.allIn = false
			s.inHand = false
			s.committed = 0
			s.roundCommitted = 0
			s.hasActed = false
			s.handScore = nil
			s.handCat = nil
		end
	end

	ent.board = {}
	ent.deck = {}
	ent.pot = 0
	ent.currentBet = 0
	ent.turnSeat = nil
	ent.showCards = false
	ent.state = "waiting"

	MaybeStartHand(ent)
	BroadcastPoker(ent)
end

local function ScheduleEndHand(ent, delay)
	timer.Create(EndHandTimerName(ent), delay, 1, function()
		if (IsValid(ent)) then EndHand(ent) end
	end)
end

local function AwardSinglePlayer(ent)
	KillTurnTimer(ent)

	local winner
	for i, s in pairs(ent.seats) do
		if (s and s.inHand) then winner = i break end
	end

	if (winner) then
		local s = ent.seats[winner]
		s.stack = s.stack + ent.pot
		ent.result = ("%s se lleva el bote de %i Balas."):format(s.name, ent.pot)
	end

	ent.pot = 0
	ent.showCards = false
	ent.state = "showdown"
	BroadcastPoker(ent)
	ScheduleEndHand(ent, 4)
end

local function Showdown(ent)
	KillTurnTimer(ent)
	ent.state = "showdown"
	ent.showCards = true
	DistributePot(ent)
	BroadcastPoker(ent)
	ScheduleEndHand(ent, 8)
end

-- ════════════════════════════════════════════════════════════════════
--  RONDAS DE APUESTAS
-- ════════════════════════════════════════════════════════════════════

local function DealStreet(ent)
	if (ent.state == "preflop") then
		ent.state = "flop"
		for _ = 1, 3 do table.insert(ent.board, baraja.Draw(ent.deck)) end
	elseif (ent.state == "flop") then
		ent.state = "turn"
		table.insert(ent.board, baraja.Draw(ent.deck))
	elseif (ent.state == "turn") then
		ent.state = "river"
		table.insert(ent.board, baraja.Draw(ent.deck))
	elseif (ent.state == "river") then
		ent.state = "showdown"
	end
end

local function BeginBettingRound(ent)
	for _, s in pairs(ent.seats) do
		if (s and s.inHand) then
			s.roundCommitted = 0
			s.hasActed = false
		end
	end

	ent.currentBet = 0
	ent.minRaise = PCfg().bigBlind

	local first = FindActive(ent, ent.dealerSeat or 0, false)
	ent.turnSeat = first
	if (first) then
		StartTurnTimer(ent)
	end
end

local function AdvanceStreet(ent)
	DealStreet(ent)

	if (ent.state == "showdown") then
		Showdown(ent)
		return
	end

	-- ¿Queda alguien que pueda apostar?
	local active = 0
	for _, s in pairs(ent.seats) do
		if (s and s.inHand and not s.allIn and s.stack > 0) then active = active + 1 end
	end

	if (active <= 1) then
		-- Nadie más puede apostar: repartir el resto y al showdown.
		AdvanceStreet(ent)
	else
		BeginBettingRound(ent)
	end
end

local function RoundComplete(ent)
	for _, s in pairs(ent.seats) do
		if (s and s.inHand and not s.allIn) then
			if (not s.hasActed or s.roundCommitted != ent.currentBet) then
				return false
			end
		end
	end
	return true
end

local function ProgressGame(ent)
	if (CountInHand(ent) <= 1) then
		AwardSinglePlayer(ent)
		return
	end

	if (RoundComplete(ent)) then
		AdvanceStreet(ent)
	else
		ent.turnSeat = FindActive(ent, ent.turnSeat, false)
		if (ent.turnSeat) then
			StartTurnTimer(ent)
		else
			AdvanceStreet(ent)
		end
	end
end

-- ════════════════════════════════════════════════════════════════════
--  ACCIONES DE JUGADOR
-- ════════════════════════════════════════════════════════════════════

local function ApplyPlayerAction(ent, seatIdx, action, amount)
	local s = ent.seats[seatIdx]
	if (not s or not s.inHand or s.allIn) then return false end

	if (action == "fold") then
		s.folded = true
		s.inHand = false
		s.hasActed = true
		return true
	elseif (action == "check") then
		if (s.roundCommitted != ent.currentBet) then return false end
		s.hasActed = true
		return true
	elseif (action == "call") then
		local need = ent.currentBet - s.roundCommitted
		if (need > 0) then
			CommitChips(ent, s, need)
		end
		s.hasActed = true
		return true
	elseif (action == "raise") then
		amount = math.floor(tonumber(amount) or 0)  -- objetivo total de la ronda
		amount = math.min(amount, ix.cartas.config.maxBet) -- tope de apuesta por acción

		local maxTarget = math.min(s.roundCommitted + s.stack, ix.cartas.config.maxBet)
		local isAllIn = false
		if (amount >= maxTarget) then
			amount = maxTarget
			isAllIn = true
		else
			local minTarget = ent.currentBet + ent.minRaise
			if (amount < minTarget) then return false end
		end

		if (amount <= ent.currentBet) then return false end

		local oldBet = ent.currentBet
		CommitChips(ent, s, amount - s.roundCommitted)

		local fullRaise = (s.roundCommitted - oldBet) >= ent.minRaise
		ent.currentBet = math.max(ent.currentBet, s.roundCommitted)

		if (fullRaise or not isAllIn) then
			ent.minRaise = s.roundCommitted - oldBet
			for i, os in pairs(ent.seats) do
				if (os and os.inHand and not os.allIn and i != seatIdx) then
					os.hasActed = false
				end
			end
		end

		s.hasActed = true
		return true
	end

	return false
end

function AutoAct(ent)
	local idx = ent.turnSeat
	if (not idx) then return end

	local s = ent.seats[idx]
	if (not s) then return end

	-- Pasar si es gratis; si no, retirarse.
	if (s.roundCommitted == ent.currentBet) then
		ApplyPlayerAction(ent, idx, "check")
	else
		ApplyPlayerAction(ent, idx, "fold")
	end

	ProgressGame(ent)
	BroadcastPoker(ent)
end

-- ════════════════════════════════════════════════════════════════════
--  INICIO DE MANO
-- ════════════════════════════════════════════════════════════════════

local function StartHand(ent)
	if (ent.state != "waiting") then return end

	-- Asientos listos en orden.
	local ready = {}
	for i = 1, PCfg().maxSeats do
		local s = ent.seats[i]
		if (s and s.stack > 0 and not s.leaving) then
			ready[#ready + 1] = i
		end
	end

	if (#ready < 2) then
		ent.state = "waiting"
		BroadcastPoker(ent)
		return
	end

	ent.result = ""
	ent.showCards = false
	ent.board = {}
	ent.pot = 0
	ent.currentBet = 0
	ent.minRaise = PCfg().bigBlind
	ent.deck = baraja.Shuffle(baraja.New())

	for _, i in ipairs(ready) do
		local s = ent.seats[i]
		s.hand = {}
		s.folded = false
		s.allIn = false
		s.inHand = true
		s.committed = 0
		s.roundCommitted = 0
		s.hasActed = false
		s.handScore = nil
		s.handCat = nil
	end

	-- Botón del repartidor.
	ent.dealerSeat = NextSeat(ent, ent.dealerSeat or 0, inHandPred) or ready[1]

	-- Repartir 2 cartas a cada uno.
	for _ = 1, 2 do
		for _, i in ipairs(ready) do
			table.insert(ent.seats[i].hand, baraja.Draw(ent.deck))
		end
	end

	-- Ciegas.
	local cfg = PCfg()
	local sbSeat, bbSeat
	if (#ready == 2) then
		sbSeat = ent.dealerSeat
		bbSeat = NextSeat(ent, ent.dealerSeat, inHandPred)
	else
		sbSeat = NextSeat(ent, ent.dealerSeat, inHandPred)
		bbSeat = NextSeat(ent, sbSeat, inHandPred)
	end

	CommitChips(ent, ent.seats[sbSeat], cfg.smallBlind)
	CommitChips(ent, ent.seats[bbSeat], cfg.bigBlind)
	ent.currentBet = cfg.bigBlind
	ent.minRaise = cfg.bigBlind

	ent.state = "preflop"

	-- Primer turno.
	local utg
	if (#ready == 2) then
		utg = ent.dealerSeat
	else
		utg = NextSeat(ent, bbSeat, inHandPred)
	end
	ent.turnSeat = FindActive(ent, utg, true)

	if (ent.turnSeat) then
		StartTurnTimer(ent)
	else
		-- Todos all-in por las ciegas: repartir y showdown.
		AdvanceStreet(ent)
		return
	end

	BroadcastPoker(ent)
end

function MaybeStartHand(ent)
	if (ent.state != "waiting") then return end
	if (CountReady(ent) < 2) then return end

	timer.Create("ixPokerStart_" .. ent:EntIndex(), 3, 1, function()
		if (IsValid(ent)) then StartHand(ent) end
	end)
end

-- ════════════════════════════════════════════════════════════════════
--  SENTARSE / LEVANTARSE / ABRIR
-- ════════════════════════════════════════════════════════════════════

local function NewSeat(client, char, buyin)
	return {
		client = client,
		name = char:GetName(),
		stack = buyin,
		committed = 0,
		roundCommitted = 0,
		folded = false,
		allIn = false,
		inHand = false,
		hasActed = false,
		hand = {},
	}
end

local function PokerSit(client, ent, buyin)
	local char = client:GetCharacter()
	if (not char) then return end

	if (SeatOf(ent, client)) then return end

	local free = FreeSeat(ent)
	if (not free) then
		client:Notify("La mesa está llena.")
		return
	end

	local cfg = PCfg()
	local minBuy = cfg.bigBlind * cfg.minBuyMult
	local money = char:GetMoney()

	if (money < minBuy) then
		client:Notify(("Necesitas al menos %i Balas para sentarte."):format(minBuy))
		return
	end

	buyin = math.Clamp(math.floor(tonumber(buyin) or 0), minBuy, money)
	char:TakeMoney(buyin)

	ent.seats[free] = NewSeat(client, char, buyin)
	ent.viewers = ent.viewers or {}
	ent.viewers[client] = true
	client.ixPokerTable = ent

	client:Notify(("Te has sentado con %i Balas."):format(buyin))
	MaybeStartHand(ent)
	BroadcastPoker(ent)
end

local function PokerStand(client, ent)
	local idx = SeatOf(ent, client)
	if (not idx) then return end

	local char = client:GetCharacter()
	local s = ent.seats[idx]
	local midHand = (s.inHand and ent.state != "waiting" and ent.state != "showdown")

	if (midHand) then
		-- Se retira: el dinero ya apostado queda en el bote; devolver lo restante.
		s.folded = true
		s.inHand = false
		s.hasActed = true
		s.leaving = true

		if (s.stack > 0 and char) then
			char:GiveMoney(s.stack)
		end
		s.stack = 0

		client:Notify("Te has retirado y has dejado la mesa.")

		if (ent.turnSeat == idx) then
			ProgressGame(ent)
		elseif (CountInHand(ent) <= 1) then
			AwardSinglePlayer(ent)
		else
			BroadcastPoker(ent)
		end
	else
		if (s.stack > 0 and char) then
			char:GiveMoney(s.stack)
		end
		ent.seats[idx] = nil
		client:Notify("Te has levantado de la mesa.")
		BroadcastPoker(ent)
	end
end

function ix.cartas.PokerOpen(client, ent)
	ent.seats = ent.seats or {}
	ent.viewers = ent.viewers or {}
	ent.viewers[client] = true
	client.ixPokerTable = ent

	SendPokerState(client, ent)
end

function ix.cartas.PokerOnDisconnect(client)
	local ent = client.ixPokerTable
	if (IsValid(ent) and ent.seats) then
		local idx = SeatOf(ent, client)
		if (idx) then
			local s = ent.seats[idx]
			local char = client:GetCharacter()
			local midHand = (s.inHand and ent.state != "waiting" and ent.state != "showdown")

			if (midHand) then
				s.folded = true
				s.inHand = false
				s.hasActed = true
				s.leaving = true
				if (s.stack > 0 and char) then char:GiveMoney(s.stack) end
				s.stack = 0

				if (ent.turnSeat == idx) then
					ProgressGame(ent)
				elseif (CountInHand(ent) <= 1) then
					AwardSinglePlayer(ent)
				else
					BroadcastPoker(ent)
				end
			else
				if (s.stack > 0 and char) then char:GiveMoney(s.stack) end
				ent.seats[idx] = nil
				BroadcastPoker(ent)
			end
		end

		if (ent.viewers) then ent.viewers[client] = nil end
	end

	client.ixPokerTable = nil
end

-- ════════════════════════════════════════════════════════════════════
--  RECEIVERS
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netPokerAction, function(_, client)
	local action = net.ReadString()
	local amount = net.ReadUInt(32)

	local ent = client.ixPokerTable
	if (not IsValid(ent) or ent:GetClass() != "metro_mesa_poker") then return end
	if (not client:GetCharacter()) then return end

	if (client:GetPos():DistToSqr(ent:GetPos()) > PCfg().useRange ^ 2) then
		client:Notify("Estás demasiado lejos de la mesa.")
		return
	end

	if (action == "sit") then
		PokerSit(client, ent, amount)
		return
	elseif (action == "stand") then
		PokerStand(client, ent)
		return
	end

	-- Acciones de juego: solo en tu turno.
	if ((client.ixPokerActionCD or 0) > CurTime()) then return end
	client.ixPokerActionCD = CurTime() + 0.15

	local seatIdx = SeatOf(ent, client)
	if (not seatIdx or ent.turnSeat != seatIdx) then return end

	if (ApplyPlayerAction(ent, seatIdx, action, amount)) then
		ProgressGame(ent)
		BroadcastPoker(ent)
	end
end)

net.Receive(PLUGIN.netPokerClose, function(_, client)
	local ent = client.ixPokerTable
	if (IsValid(ent) and ent.viewers) then
		ent.viewers[client] = nil
	end
	-- No se levanta automáticamente: sigue sentado aunque cierre la UI.
	client.ixPokerTable = nil
end)
