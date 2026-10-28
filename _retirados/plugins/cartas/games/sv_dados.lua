local PLUGIN = ix.plugin.Get("cartas") or PLUGIN

local DADOS = {}

-- Antes pagaba 2x exacto (juego perfectamente equilibrado); bajado para que la
-- banca tenga una ventaja estructural real.
local WIN_MULTIPLIER = 1.9

-- ════════════════════════════════════════════════════════════════════
--  ESTADO → CLIENTE
-- ════════════════════════════════════════════════════════════════════

local function WriteDice(dice)
	net.WriteUInt(#dice, 3)
	for _, v in ipairs(dice) do
		net.WriteUInt(v, 3)  -- 1-6
	end
end

function DADOS.SendState(client, ent)
	local char = client:GetCharacter()
	if (not char) then return end

	local cfg = ix.cartas.config
	local game = ent.games and ent.games[client]

	net.Start(PLUGIN.netState)
		net.WriteString("dados")
		net.WriteUInt(cfg.minBet, 32)
		net.WriteUInt(cfg.maxBet, 32)
		net.WriteUInt(math.Clamp(char:GetMoney(), 0, 4294967295), 32)

		if (not game) then
			net.WriteString("betting")
			net.WriteUInt(0, 32)
			net.WriteString("")
			WriteDice({})
			WriteDice({})
			net.WriteUInt(0, 6)
			net.WriteUInt(0, 6)
		else
			net.WriteString(game.state)
			net.WriteUInt(game.bet, 32)
			net.WriteString(game.result or "")
			WriteDice(game.player)
			WriteDice(game.dealer)
			net.WriteUInt(game.playerTotal or 0, 6)
			net.WriteUInt(game.dealerTotal or 0, 6)
		end
	net.Send(client)
end

-- ════════════════════════════════════════════════════════════════════
--  LÓGICA — tira 2 dados contra la banca, mayor gana (empate devuelve)
-- ════════════════════════════════════════════════════════════════════

local function Roll()
	return {math.random(1, 6), math.random(1, 6)}
end

local function Sum(dice)
	local total = 0
	for _, v in ipairs(dice) do
		total = total + v
	end
	return total
end

local function PlayRound(client, ent, amount)
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

	local player = Roll()
	local dealer = Roll()
	local pt = Sum(player)
	local dt = Sum(dealer)

	local result
	if (pt > dt) then
		result = ("%i contra %i. ¡Ganas %i Balas!"):format(pt, dt, amount)
		char:GiveMoney(math.floor(amount * WIN_MULTIPLIER))
	elseif (pt < dt) then
		result = ("%i contra %i. La banca gana."):format(pt, dt)
		ix.cartas.DepositLoss(amount)
	else
		result = ("Empate a %i. Recuperas tu apuesta."):format(pt)
		char:GiveMoney(amount)
	end

	ent.games = ent.games or {}
	ent.games[client] = {
		state = "done",
		bet = amount,
		result = result,
		player = player,
		dealer = dealer,
		playerTotal = pt,
		dealerTotal = dt,
	}

	DADOS.SendState(client, ent)
end

function DADOS.Action(client, ent, action, amount)
	if (action == "bet") then
		PlayRound(client, ent, amount)
	end
end

ix.cartas.games.dados = DADOS
