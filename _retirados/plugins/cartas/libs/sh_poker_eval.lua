-- Evaluador de manos de póker (Texas Hold'em): mejor mano de 5 entre 7 cartas.
ix.cartas = ix.cartas or {}
ix.cartas.poker = ix.cartas.poker or {}

-- Nombres de categoría (índice = categoría devuelta por Evaluate).
ix.cartas.poker.CATEGORY_NAMES = {
	[0] = "Carta alta",
	[1] = "Pareja",
	[2] = "Doble pareja",
	[3] = "Trío",
	[4] = "Escalera",
	[5] = "Color",
	[6] = "Full",
	[7] = "Póker",
	[8] = "Escalera de color",
}

-- El As (rank 1) vale 14 salvo en la escalera baja A-2-3-4-5.
local function RankVal(r)
	return r == 1 and 14 or r
end

-- Puntúa una mano exacta de 5 cartas. Devuelve score numérico, categoría y desempates.
local function Score5(hand)
	local ranks, suits = {}, {}
	for i = 1, 5 do
		ranks[i] = RankVal(hand[i].rank)
		suits[i] = hand[i].suit
	end

	table.sort(ranks, function(a, b) return a > b end)

	-- Conteo por rango.
	local count = {}
	for _, r in ipairs(ranks) do
		count[r] = (count[r] or 0) + 1
	end

	-- Grupos ordenados por (frecuencia desc, rango desc).
	local groups = {}
	for r, c in pairs(count) do
		groups[#groups + 1] = {r = r, c = c}
	end
	table.sort(groups, function(a, b)
		if (a.c != b.c) then return a.c > b.c end
		return a.r > b.r
	end)

	-- Color.
	local isFlush = true
	for i = 2, 5 do
		if (suits[i] != suits[1]) then
			isFlush = false
			break
		end
	end

	-- Escalera (requiere 5 rangos distintos consecutivos; contempla la rueda A-5).
	local uniq, seen = {}, {}
	for _, r in ipairs(ranks) do
		if (not seen[r]) then
			seen[r] = true
			uniq[#uniq + 1] = r
		end
	end
	table.sort(uniq, function(a, b) return a > b end)

	local isStraight, straightHigh = false, nil
	if (#uniq == 5) then
		if (uniq[1] - uniq[5] == 4) then
			isStraight, straightHigh = true, uniq[1]
		elseif (uniq[1] == 14 and uniq[2] == 5 and uniq[3] == 4 and uniq[4] == 3 and uniq[5] == 2) then
			isStraight, straightHigh = true, 5
		end
	end

	local cat, tb
	if (isStraight and isFlush) then
		cat, tb = 8, {straightHigh}
	elseif (groups[1].c == 4) then
		cat, tb = 7, {groups[1].r, groups[2].r}
	elseif (groups[1].c == 3 and groups[2].c == 2) then
		cat, tb = 6, {groups[1].r, groups[2].r}
	elseif (isFlush) then
		cat, tb = 5, {ranks[1], ranks[2], ranks[3], ranks[4], ranks[5]}
	elseif (isStraight) then
		cat, tb = 4, {straightHigh}
	elseif (groups[1].c == 3) then
		cat, tb = 3, {groups[1].r, groups[2].r, groups[3].r}
	elseif (groups[1].c == 2 and groups[2].c == 2) then
		cat, tb = 2, {groups[1].r, groups[2].r, groups[3].r}
	elseif (groups[1].c == 2) then
		cat, tb = 1, {groups[1].r, groups[2].r, groups[3].r, groups[4].r}
	else
		cat, tb = 0, {ranks[1], ranks[2], ranks[3], ranks[4], ranks[5]}
	end

	local score = cat
	for i = 1, 5 do
		score = score * 15 + (tb[i] or 0)
	end

	return score, cat, tb
end

-- Combinaciones de 5 entre 7 (índices). C(7,5) = 21.
local COMBOS = {}
do
	for a = 1, 7 do
		for b = a + 1, 7 do
			for c = b + 1, 7 do
				for d = c + 1, 7 do
					for e = d + 1, 7 do
						COMBOS[#COMBOS + 1] = {a, b, c, d, e}
					end
				end
			end
		end
	end
end

-- Evalúa el mejor 5 de entre las cartas dadas (5 a 7). Devuelve score, categoría, desempates.
function ix.cartas.poker.Evaluate(cards)
	if (#cards < 5) then return -1, 0, {} end

	-- Con exactamente 5, evalúa directo.
	if (#cards == 5) then
		return Score5(cards)
	end

	local best, bestCat, bestTb = -1, 0, {}
	for _, idx in ipairs(COMBOS) do
		if (idx[5] <= #cards) then
			local hand = {cards[idx[1]], cards[idx[2]], cards[idx[3]], cards[idx[4]], cards[idx[5]]}
			local s, cat, tb = Score5(hand)
			if (s > best) then
				best, bestCat, bestTb = s, cat, tb
			end
		end
	end

	return best, bestCat, bestTb
end

function ix.cartas.poker.CategoryName(cat)
	return ix.cartas.poker.CATEGORY_NAMES[cat] or "?"
end
