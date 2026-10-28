local PLUGIN = PLUGIN

-- ════════════════════════════════════════════════════════════════════
--  MESAS DE BANCA (Blackjack / Dados) — comparten panel metroMesaCartas
-- ════════════════════════════════════════════════════════════════════

local function ReadCard()
	local rank = net.ReadUInt(4)
	local suit = net.ReadUInt(3)
	return {rank = rank, suit = suit}
end

local function ReadDice()
	local dice = {}
	local count = net.ReadUInt(3)
	for _ = 1, count do
		table.insert(dice, net.ReadUInt(3))
	end
	return dice
end

net.Receive(PLUGIN.netState, function()
	local data = {}

	data.gameType = net.ReadString()
	data.minBet = net.ReadUInt(32)
	data.maxBet = net.ReadUInt(32)
	data.money = net.ReadUInt(32)
	data.state = net.ReadString()
	data.bet = net.ReadUInt(32)
	data.result = net.ReadString()

	if (data.gameType == "dados") then
		data.player = ReadDice()
		data.dealer = ReadDice()
		data.playerTotal = net.ReadUInt(6)
		data.dealerTotal = net.ReadUInt(6)
	else
		data.player = {}
		local playerCount = net.ReadUInt(4)
		for _ = 1, playerCount do
			table.insert(data.player, ReadCard())
		end
		data.playerTotal = net.ReadUInt(6)

		data.dealer = {}
		local dealerCount = net.ReadUInt(4)
		for _ = 1, dealerCount do
			table.insert(data.dealer, ReadCard())
		end
		data.dealerTotal = net.ReadUInt(6)
	end

	if (IsValid(ix.gui.cartasMesa)) then
		ix.gui.cartasMesa:SetState(data)
	else
		local panel = vgui.Create("metroMesaCartas")
		panel:SetState(data)
	end
end)

-- ════════════════════════════════════════════════════════════════════
--  MESA DE PÓKER
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netPokerState, function()
	local data = ix.cartas.ReadPokerState()

	if (IsValid(ix.gui.cartasPoker)) then
		ix.gui.cartasPoker:SetState(data)
	else
		local panel = vgui.Create("metroMesaPoker")
		panel:SetState(data)
	end
end)
