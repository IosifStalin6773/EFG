local PLUGIN = ix.plugin.Get("cartas") or PLUGIN
local baraja = ix.cartas.baraja

local BLACKJACK = {}

-- Multiplicadores de pago (antes 2.5x / 2x exactos): bajados ligeramente para
-- que la banca tenga una ventaja estructural real y el juego no sea puro
-- faucet de Balas creadas de la nada en cada mano ganada.
local BLACKJACK_MULTIPLIER = 2.3
local WIN_MULTIPLIER = 1.9

-- ════════════════════════════════════════════════════════════════════
--  ESTADO → CLIENTE
-- ════════════════════════════════════════════════════════════════════

function BLACKJACK.SendState(client, ent)
	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = ix.cartas.config
	local game = ent.games and ent.games[client]

	net.Start(PLUGIN.netState)
		net.WriteString("blackjack")
		net.WriteUInt(cfg.minBet, 32)
		net.WriteUInt(cfg.maxBet, 32)
		net.WriteUInt(math.Clamp(char:GetMoney(), 0, 4294967295), 32)

		if (not game) then
			net.WriteString("betting")
			net.WriteUInt(0, 32)
			net.WriteString("")
			net.WriteUInt(0, 4)
			net.WriteUInt(0, 6)
			net.WriteUInt(0, 4)
			net.WriteUInt(0, 6)
		else
			local hideHole = (game.state == "playing")

			net.WriteString(game.state)
			net.WriteUInt(game.bet, 32)
			net.WriteString(game.result or "")

			net.WriteUInt(#game.player, 4)
			for _, card in ipairs(game.player) do
				ix.cartas.WriteCard(card)
			end
			net.WriteUInt(baraja.BlackjackValue(game.player), 6)

			net.WriteUInt(#game.dealer, 4)
			for i, card in ipairs(game.dealer) do
				if (hideHole and i == 2) then
					ix.cartas.WriteCard(nil)
				else
					ix.cartas.WriteCard(card)
				end
			end

			if (hideHole) then
				net.WriteUInt(baraja.BlackjackValue({game.dealer[1]}), 6)
			else
				net.WriteUInt(baraja.BlackjackValue(game.dealer), 6)
			end
		end
	net.Send(client)
end

-- ════════════════════════════════════════════════════════════════════
--  LÓGICA
-- ════════════════════════════════════════════════════════════════════

local function StartHand(client, ent, amount)
	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = ix.cartas.config
	amount = math.floor(tonumber(amount) or 0)

	if (amount < cfg.minBet) then
		client:Notify(("La apuesta mínima es %i Balas."):format(cfg.minBet))
		return
	end

	if (amount > cfg.maxBet) then
		client:Notify(("La apuesta máxima es %i Balas."):format(cfg.maxBet))
		return
	end

	if (char:GetMoney() < amount) then
		client:Notify("No tienes suficientes Balas para esa apuesta.")
		return
	end

	char:TakeMoney(amount)

	local deck = baraja.Shuffle(baraja.New())
	local game = {
		deck = deck,
		player = {baraja.Draw(deck), baraja.Draw(deck)},
		dealer = {baraja.Draw(deck), baraja.Draw(deck)},
		bet = amount,
		state = "playing",
		result = "",
	}

	ent.games = ent.games or {}
	ent.games[client] = game

	local pv = baraja.BlackjackValue(game.player)
	if (pv == 21) then
		local dv = baraja.BlackjackValue(game.dealer)

		if (dv == 21) then
			game.result = "Doble Blackjack. Empate, recuperas tu apuesta."
			char:GiveMoney(amount)
		else
			local win = math.floor(amount * BLACKJACK_MULTIPLIER)
			game.result = ("¡Blackjack! La banca paga %i Balas."):format(win - amount)
			char:GiveMoney(win)
		end

		game.state = "done"
	end

	BLACKJACK.SendState(client, ent)
end

local function PlayerHit(client, ent)
	local game = ent.games and ent.games[client]
	if (not game or game.state != "playing") then return end

	table.insert(game.player, baraja.Draw(game.deck))

	local pv = baraja.BlackjackValue(game.player)
	if (pv > 21) then
		game.state = "done"
		game.result = ("Te pasaste con %i. Pierdes %i Balas."):format(pv, game.bet)
		ix.cartas.DepositLoss(game.bet)
	end

	BLACKJACK.SendState(client, ent)
end

local function PlayerStand(client, ent)
	local game = ent.games and ent.games[client]
	if (not game or game.state != "playing") then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = ix.cartas.config

	while (baraja.BlackjackValue(game.dealer) < cfg.dealerStandsOn) do
		table.insert(game.dealer, baraja.Draw(game.deck))
	end

	local pv = baraja.BlackjackValue(game.player)
	local dv = baraja.BlackjackValue(game.dealer)
	local bet = game.bet

	if (dv > 21) then
		game.result = ("La banca se pasa con %i. ¡Ganas %i Balas!"):format(dv, bet)
		char:GiveMoney(math.floor(bet * WIN_MULTIPLIER))
	elseif (pv > dv) then
		game.result = ("%i contra %i. ¡Ganas %i Balas!"):format(pv, dv, bet)
		char:GiveMoney(math.floor(bet * WIN_MULTIPLIER))
	elseif (pv < dv) then
		game.result = ("%i contra %i. La banca gana."):format(pv, dv)
		ix.cartas.DepositLoss(bet)
	else
		game.result = ("Empate a %i. Recuperas tu apuesta."):format(pv)
		char:GiveMoney(bet)
	end

	game.state = "done"
	BLACKJACK.SendState(client, ent)
end

function BLACKJACK.Action(client, ent, action, amount)
	if (action == "bet") then
		local game = ent.games and ent.games[client]
		if (game and game.state == "playing") then return end
		StartHand(client, ent, amount)
	elseif (action == "hit") then
		PlayerHit(client, ent)
	elseif (action == "stand") then
		PlayerStand(client, ent)
	end
end

ix.cartas.games.blackjack = BLACKJACK
