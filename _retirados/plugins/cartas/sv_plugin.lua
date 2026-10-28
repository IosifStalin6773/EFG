local PLUGIN = PLUGIN

util.AddNetworkString(PLUGIN.netState)
util.AddNetworkString(PLUGIN.netAction)
util.AddNetworkString(PLUGIN.netClose)
util.AddNetworkString(PLUGIN.netPokerState)
util.AddNetworkString(PLUGIN.netPokerAction)
util.AddNetworkString(PLUGIN.netPokerClose)

ix.cartas.mesas = ix.cartas.mesas or {}

-- Helper compartido por los módulos de juego para serializar cartas.
-- card = {rank, suit}; nil = carta oculta (rank 0).
function ix.cartas.WriteCard(card)
	if (not card) then
		net.WriteUInt(0, 4)
		net.WriteUInt(0, 3)
		return
	end

	net.WriteUInt(card.rank, 4)
	net.WriteUInt(card.suit, 3)
end

-- ════════════════════════════════════════════════════════════════════
--  PERSISTENCIA DE MESAS (banca y póker)
-- ════════════════════════════════════════════════════════════════════

local MESA_CLASSES = {
	["metro_mesa_cartas"] = true,
	["metro_mesa_poker"] = true,
}

function PLUGIN:LoadData()
	local saved = self:GetData() or {}
	ix.cartas.mesas = saved.mesas or {}

	timer.Simple(1, function()
		for _, info in ipairs(ix.cartas.mesas) do
			local pos = Vector(info.px, info.py, info.pz)
			local class = info.class or "metro_mesa_cartas"

			local exists = false
			for _, e in pairs(ents.FindByClass(class)) do
				if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
					exists = true
					break
				end
			end

			if (not exists) then
				local ent = ents.Create(class)
				if (IsValid(ent)) then
					if (class == "metro_mesa_cartas") then
						ent.gameType = info.gameType or "blackjack"
					end
					if (info.model and info.model != "") then
						ent.mesaModel = info.model
					end

					ent:SetPos(pos)
					ent:SetAngles(Angle(0, info.ay or 0, 0))
					ent:Spawn()
					ent:Activate()
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData({
		mesas = ix.cartas.mesas,
	})
end

function ix.cartas.SaveMesas()
	ix.cartas.mesas = {}

	for class in pairs(MESA_CLASSES) do
		for _, ent in pairs(ents.FindByClass(class)) do
			if (IsValid(ent)) then
				local pos = ent:GetPos()
				local ang = ent:GetAngles()
				table.insert(ix.cartas.mesas, {
					class = class,
					gameType = ent.gameType,
					px = pos.x, py = pos.y, pz = pos.z,
					ay = ang.yaw,
					model = ent:GetModel(),
				})
			end
		end
	end

	local plugin = ix.plugin.Get("cartas")
	if (plugin) then
		plugin:SaveData()
	end
end

function ix.cartas.RemoveMesa(ent)
	if (not IsValid(ent)) then return end

	local pos = ent:GetPos()
	for i = #ix.cartas.mesas, 1, -1 do
		local info = ix.cartas.mesas[i]
		if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
			table.remove(ix.cartas.mesas, i)
		end
	end

	local plugin = ix.plugin.Get("cartas")
	if (plugin) then
		plugin:SaveData()
	end
end

-- ════════════════════════════════════════════════════════════════════
--  DESPACHO GENÉRICO (mesas de banca)
-- ════════════════════════════════════════════════════════════════════

-- Enruta al módulo de juego según ent.gameType. La llaman la entidad (Use) y los módulos.
function ix.cartas.SendState(client, ent)
	if (not IsValid(client) or not IsValid(ent)) then return end

	local game = ix.cartas.games[ent.gameType or "blackjack"]
	if (not game) then return end

	game.SendState(client, ent)
end

net.Receive(PLUGIN.netAction, function(_, client)
	local action = net.ReadString()
	local amount = net.ReadUInt(32)

	local ent = client.ixCartasTable
	if (not IsValid(ent) or ent:GetClass() != "metro_mesa_cartas") then return end
	if (not client:GetCharacter()) then return end

	if (client:GetPos():DistToSqr(ent:GetPos()) > ix.cartas.config.useRange ^ 2) then
		client:Notify("Estás demasiado lejos de la mesa.")
		return
	end

	if ((client.ixCartasActionCD or 0) > CurTime()) then return end
	client.ixCartasActionCD = CurTime() + 0.15

	local game = ix.cartas.games[ent.gameType or "blackjack"]
	if (not game) then return end

	game.Action(client, ent, action, amount)
end)

net.Receive(PLUGIN.netClose, function(_, client)
	local ent = client.ixCartasTable
	if (IsValid(ent) and ent.games) then
		ent.games[client] = nil
	end

	client.ixCartasTable = nil
end)

function PLUGIN:PlayerDisconnected(client)
	local ent = client.ixCartasTable
	if (IsValid(ent) and ent.games) then
		ent.games[client] = nil
	end

	client.ixCartasTable = nil
	client.ixCartasCD = nil
	client.ixCartasActionCD = nil

	-- Limpieza del póker (si estaba sentado).
	if (ix.cartas.PokerOnDisconnect) then
		ix.cartas.PokerOnDisconnect(client)
	end
end

-- ════════════════════════════════════════════════════════════════════
--  MÓDULOS DE JUEGO
-- ════════════════════════════════════════════════════════════════════

ix.util.IncludeDir(("%s/plugins/%s/games"):format(Schema.folder, PLUGIN.uniqueID), true)
