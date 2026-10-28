local PLUGIN = PLUGIN

PLUGIN.name = "Juegos de Cartas"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Mesas de juego para la estación. Apuesta Balas: Blackjack y Dados contra la banca, y Póker Texas Hold'em entre jugadores."

ix.cartas = ix.cartas or {}

ix.cartas.config = {
	minBet = 5,
	maxBet = 100,
	useRange = 200,        -- distancia máxima (unidades) para seguir jugando una mesa de banca
	dealerStandsOn = 17,   -- la banca se planta al alcanzar este total (Blackjack)

	-- Contra la banca (Blackjack/Dados) lo perdido no se destruye entero: una
	-- parte financia las arcas de Hanza y el resto se quema de verdad, para que
	-- el juego siga actuando como sumidero neto y no solo como faucet cuando se
	-- gana (ver PlayerHit/PlayerStand en sv_blackjack.lua y PlayRound en sv_dados.lua).
	lossToArcasRate = 0.5,

	poker = {
		smallBlind = 25,
		bigBlind = 50,
		maxSeats = 6,
		useRange = 300,
		turnTime = 40,     -- segundos por turno antes de auto-retirarse/pasar
		minBuyMult = 1,    -- balas mínimas para sentarse = bigBlind * este factor
	},
}

-- Deposita en las arcas de Hanza la parte que le corresponde de una apuesta
-- perdida contra la banca (Blackjack/Dados); el resto queda destruido, sin
-- devolverse a nadie, para conservar un sumidero real de la economía.
function ix.cartas.DepositLoss(amount)
	if (SERVER and ix.arcas and ix.arcas.Deposit) then
		local toArcas = math.floor((tonumber(amount) or 0) * ix.cartas.config.lossToArcasRate)
		ix.arcas.Deposit(toArcas)
	end
end

-- Tipos de juego válidos para la mesa de banca (metro_mesa_cartas).
ix.cartas.BANK_GAMES = {
	blackjack = "Blackjack",
	dados = "Dados",
}

-- Registry de juegos de banca. Cada juego registra { SendState, Action }.
-- Lo rellenan los archivos de games/ (servidor).
ix.cartas.games = ix.cartas.games or {}

-- Net strings — mesas de banca (Blackjack / Dados)
PLUGIN.netState = "Cartas.State"
PLUGIN.netAction = "Cartas.Action"
PLUGIN.netClose = "Cartas.Close"

-- Net strings — Póker
PLUGIN.netPokerState = "Cartas.PokerState"
PLUGIN.netPokerAction = "Cartas.PokerAction"
PLUGIN.netPokerClose = "Cartas.PokerClose"

-- ════════════════════════════════════════════════════════════════════
--  COMANDOS ADMIN
-- ════════════════════════════════════════════════════════════════════

ix.command.Add("ColocarMesa", {
	description = "Coloca una Mesa de banca (Blackjack/Dados). Uso: /ColocarMesa <blackjack|dados> [modelo].",
	adminOnly = true,
	arguments = {
		ix.type.string,
		bit.bor(ix.type.string, ix.type.optional),
	},
	OnRun = function(self, client, gameType, model)
		if (SERVER) then
			gameType = string.lower(gameType or "")
			if (not ix.cartas.BANK_GAMES[gameType]) then
				return client:Notify("Tipo no válido. Usa: blackjack o dados.")
			end

			if (model and model != "" and not util.IsValidModel(model)) then
				return client:Notify("Modelo no válido: " .. model)
			end

			local trace = client:GetEyeTraceNoCursor()
			local pos = trace.HitPos + trace.HitNormal * 5
			local ang = (client:GetPos() - pos):Angle()
			ang.pitch = 0
			ang.roll = 0

			local ent = ents.Create("metro_mesa_cartas")
			if (not IsValid(ent)) then
				return client:Notify("No se pudo crear la entidad.")
			end

			ent.gameType = gameType
			if (model and model != "") then
				ent.mesaModel = model
			end

			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:Activate()

			ix.cartas.SaveMesas()
			client:Notify(("Mesa de %s colocada."):format(ix.cartas.BANK_GAMES[gameType]))
		end
	end
})

ix.command.Add("ColocarPoker", {
	description = "Coloca una Mesa de Póker Texas Hold'em. Opcional: ruta de un modelo custom.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional),
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			if (model and model != "" and not util.IsValidModel(model)) then
				return client:Notify("Modelo no válido: " .. model)
			end

			local trace = client:GetEyeTraceNoCursor()
			local pos = trace.HitPos + trace.HitNormal * 5
			local ang = (client:GetPos() - pos):Angle()
			ang.pitch = 0
			ang.roll = 0

			local ent = ents.Create("metro_mesa_poker")
			if (not IsValid(ent)) then
				return client:Notify("No se pudo crear la entidad.")
			end

			if (model and model != "") then
				ent.mesaModel = model
			end

			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:Activate()

			ix.cartas.SaveMesas()
			client:Notify("Mesa de Póker colocada.")
		end
	end
})

-- Nombre distinto a "QuitarMesa" (metrocrafting registra un comando CON ESE MISMO
-- NOMBRE para sus mesas de crafteo). ix.command.Add sobrescribe sin avisar, así que
-- si coincidieran, la última en cargar ganaría y la otra quedaría inservible: eso
-- es justo lo que pasaba con las mesas de póker/dados/blackjack (metrocrafting
-- carga después alfabéticamente y su QuitarMesa solo reconoce mesas de crafteo).
ix.command.Add("QuitarMesaCartas", {
	description = "Elimina la Mesa de Cartas (Blackjack/Dados) o Póker a la que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local ent = client:GetEyeTrace().Entity
			if (not IsValid(ent) or (ent:GetClass() != "metro_mesa_cartas" and ent:GetClass() != "metro_mesa_poker")) then
				return client:Notify("No estás mirando a ninguna mesa de juego.")
			end

			ix.cartas.RemoveMesa(ent)
			ent:Remove()
			client:Notify("Mesa eliminada.")
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
