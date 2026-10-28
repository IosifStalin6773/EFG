-- Librería de baraja, agnóstica al juego. La reutilizan Blackjack, Dados, etc.
ix.cartas = ix.cartas or {}
ix.cartas.baraja = ix.cartas.baraja or {}

-- Palos: 1 = corazones, 2 = picas, 3 = diamantes, 4 = tréboles
-- Rangos: 1 = As, 2-10 numéricas, 11 = J, 12 = Q, 13 = K
ix.cartas.RANK_NAMES = {
	[1] = "A", [11] = "J", [12] = "Q", [13] = "K",
}

ix.cartas.SUIT_CHARS = {
	[1] = "\xE2\x99\xA5", -- ♥
	[2] = "\xE2\x99\xA0", -- ♠
	[3] = "\xE2\x99\xA6", -- ♦
	[4] = "\xE2\x99\xA3", -- ♣
}

ix.cartas.SUIT_RED = {
	[1] = true,  -- corazones
	[3] = true,  -- diamantes
}

-- Devuelve una baraja completa de 52 cartas, sin barajar.
function ix.cartas.baraja.New()
	local deck = {}

	for suit = 1, 4 do
		for rank = 1, 13 do
			deck[#deck + 1] = {rank = rank, suit = suit}
		end
	end

	return deck
end

-- Baraja una baraja in-place (Fisher-Yates) y la devuelve.
function ix.cartas.baraja.Shuffle(deck)
	for i = #deck, 2, -1 do
		local j = math.random(i)
		deck[i], deck[j] = deck[j], deck[i]
	end

	return deck
end

-- Roba la carta superior de la baraja.
function ix.cartas.baraja.Draw(deck)
	return table.remove(deck)
end

-- Valor de una mano de Blackjack. Los Ases valen 11 o 1 (lo que más convenga).
function ix.cartas.baraja.BlackjackValue(hand)
	local total, aces = 0, 0

	for _, card in ipairs(hand) do
		local r = card.rank
		if (r == 1) then
			aces = aces + 1
			total = total + 11
		elseif (r >= 11) then
			total = total + 10
		else
			total = total + r
		end
	end

	while (total > 21 and aces > 0) do
		total = total - 10
		aces = aces - 1
	end

	return total
end

-- Nombre legible de una carta (ej. "A♥", "10♠").
function ix.cartas.baraja.CardName(card)
	if (not card or card.rank == 0) then
		return "??"
	end

	local rankStr = ix.cartas.RANK_NAMES[card.rank] or tostring(card.rank)
	local suitStr = ix.cartas.SUIT_CHARS[card.suit] or "?"

	return rankStr .. suitStr
end
