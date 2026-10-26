local PLUGIN = PLUGIN

util.AddNetworkString(PLUGIN.netRequest)
util.AddNetworkString(PLUGIN.netRespond)
util.AddNetworkString(PLUGIN.netState)
util.AddNetworkString(PLUGIN.netOffer)
util.AddNetworkString(PLUGIN.netConfirm)
util.AddNetworkString(PLUGIN.netCancel)
util.AddNetworkString(PLUGIN.netClose)

local function Cfg()
	return ix.intercambio.config
end

local function CharName(client)
	return (IsValid(client) and client:GetCharacter() and client:GetCharacter():GetName()) or "Alguien"
end

-- ════════════════════════════════════════════════════════════════════
--  ESTADO → CLIENTE
-- ════════════════════════════════════════════════════════════════════

local function WriteOffer(offer)
	net.WriteUInt(#offer, 8)
	for _, id in ipairs(offer) do
		local item = ix.item.instances[id]
		net.WriteUInt(id, 32)
		net.WriteString(item and item:GetName() or "???")
		net.WriteString((item and item:GetModel()) or "")
		net.WriteUInt(item and item:GetData("Amount", 1) or 1, 16)
	end
end

local function SendStateTo(client, session)
	if (not IsValid(client)) then return end

	local isA = (session.a == client)
	local other = isA and session.b or session.a

	net.Start(PLUGIN.netState)
		net.WriteString(CharName(other))
		WriteOffer(isA and session.offerA or session.offerB)
		WriteOffer(isA and session.offerB or session.offerA)
		net.WriteBool(isA and session.confirmA or session.confirmB)
		net.WriteBool(isA and session.confirmB or session.confirmA)
	net.Send(client)
end

local function Broadcast(session)
	SendStateTo(session.a, session)
	SendStateTo(session.b, session)
end

-- ════════════════════════════════════════════════════════════════════
--  GESTIÓN DE SESIÓN
-- ════════════════════════════════════════════════════════════════════

function ix.intercambio.InRange(session)
	if (not IsValid(session.a) or not IsValid(session.b)) then return false end
	return session.a:GetPos():DistToSqr(session.b:GetPos()) <= Cfg().useRange ^ 2
end

function ix.intercambio.End(session, reason)
	if (session.ended) then return end
	session.ended = true

	if (session.timer) then timer.Remove(session.timer) end

	for _, client in ipairs({session.a, session.b}) do
		if (IsValid(client) and client.ixTrade == session) then
			client.ixTrade = nil
			net.Start(PLUGIN.netClose)
				net.WriteString(reason or "Intercambio cerrado.")
			net.Send(client)
		end
	end
end

function ix.intercambio.Validate(session)
	if (session.ended) then return end

	if (not IsValid(session.a) or not IsValid(session.b) or not session.a:GetCharacter() or not session.b:GetCharacter()) then
		return ix.intercambio.End(session, "Intercambio cancelado.")
	end

	if (not ix.intercambio.InRange(session)) then
		return ix.intercambio.End(session, "Os habéis alejado demasiado.")
	end
end

function ix.intercambio.Begin(a, b)
	local session = {
		a = a, b = b,
		offerA = {}, offerB = {},
		confirmA = false, confirmB = false,
	}

	a.ixTrade = session
	b.ixTrade = session

	session.timer = "ixTrade_" .. a:EntIndex() .. "_" .. b:EntIndex()
	timer.Create(session.timer, 1.5, 0, function()
		if (session.ended) then return end
		ix.intercambio.Validate(session)
	end)

	a:Notify("Intercambio iniciado con " .. CharName(b) .. ".")
	b:Notify("Intercambio iniciado con " .. CharName(a) .. ".")
	Broadcast(session)
end

-- ════════════════════════════════════════════════════════════════════
--  INTERCAMBIO ATÓMICO (con rollback)
-- ════════════════════════════════════════════════════════════════════

function ix.intercambio.Execute(session)
	local a, b = session.a, session.b

	if (not IsValid(a) or not IsValid(b)) then
		return ix.intercambio.End(session, "Un jugador ya no está disponible.")
	end

	local aChar, bChar = a:GetCharacter(), b:GetCharacter()
	if (not aChar or not bChar) then
		return ix.intercambio.End(session, "Personaje no disponible.")
	end

	if (not ix.intercambio.InRange(session)) then
		return ix.intercambio.End(session, "Os habéis alejado demasiado.")
	end

	local aInv, bInv = aChar:GetInventory(), bChar:GetInventory()
	if (not aInv or not bInv) then
		return ix.intercambio.End(session, "Inventario no disponible.")
	end

	local aInvID, bInvID = aInv:GetID(), bInv:GetID()

	-- Reunir y validar que los items siguen en su inventario.
	local aItems, bItems = {}, {}
	for _, id in ipairs(session.offerA) do
		local item = ix.item.instances[id]
		if (not item or item.invID != aInvID) then
			return ix.intercambio.End(session, "Un objeto ya no está disponible.")
		end
		aItems[#aItems + 1] = item
	end
	for _, id in ipairs(session.offerB) do
		local item = ix.item.instances[id]
		if (not item or item.invID != bInvID) then
			return ix.intercambio.End(session, "Un objeto ya no está disponible.")
		end
		bItems[#bItems + 1] = item
	end

	-- Mover con rollback si algo no cabe (peso/espacio).
	local moved = {}
	local function rollback()
		for i = #moved, 1, -1 do
			moved[i].item:Transfer(moved[i].from)
		end
	end

	for _, item in ipairs(aItems) do
		if (item:Transfer(bInvID)) then
			moved[#moved + 1] = {item = item, from = aInvID}
		else
			rollback()
			return ix.intercambio.End(session, CharName(b) .. " no tiene espacio o peso suficiente.")
		end
	end

	for _, item in ipairs(bItems) do
		if (item:Transfer(aInvID)) then
			moved[#moved + 1] = {item = item, from = bInvID}
		else
			rollback()
			return ix.intercambio.End(session, CharName(a) .. " no tiene espacio o peso suficiente.")
		end
	end

	a:Notify("Intercambio completado.")
	b:Notify("Intercambio completado.")
	ix.intercambio.End(session, "¡Intercambio completado!")
end

-- ════════════════════════════════════════════════════════════════════
--  SOLICITUD
-- ════════════════════════════════════════════════════════════════════

function ix.intercambio.Request(client)
	local char = client:GetCharacter()
	if (not char) then return end

	if (client.ixTrade) then
		return client:Notify("Ya estás en un intercambio.")
	end

	local target = client:GetEyeTrace().Entity
	if (not IsValid(target) or not target:IsPlayer()) then
		return client:Notify("No estás mirando a ningún jugador.")
	end
	if (target == client) then return end
	if (not target:GetCharacter()) then
		return client:Notify("Ese jugador no está disponible.")
	end
	if (client:GetPos():DistToSqr(target:GetPos()) > Cfg().useRange ^ 2) then
		return client:Notify("Estás demasiado lejos de ese jugador.")
	end
	if (target.ixTrade) then
		return client:Notify("Ese jugador ya está intercambiando.")
	end
	if (IsValid(target.ixTradeReqFrom)) then
		return client:Notify("Ese jugador ya tiene una solicitud pendiente.")
	end

	target.ixTradeReqFrom = client

	timer.Create("ixTradeReq_" .. target:EntIndex(), Cfg().requestTimeout, 1, function()
		if (IsValid(target) and target.ixTradeReqFrom == client) then
			target.ixTradeReqFrom = nil
			if (IsValid(client)) then client:Notify("La solicitud de intercambio expiró.") end
		end
	end)

	net.Start(PLUGIN.netRequest)
		net.WriteEntity(client)
		net.WriteString(CharName(client))
	net.Send(target)

	client:Notify("Solicitud de intercambio enviada a " .. CharName(target) .. ".")
end

-- ════════════════════════════════════════════════════════════════════
--  RECEIVERS
-- ════════════════════════════════════════════════════════════════════

net.Receive(PLUGIN.netRespond, function(_, client)
	local accept = net.ReadBool()
	local requester = client.ixTradeReqFrom

	client.ixTradeReqFrom = nil
	timer.Remove("ixTradeReq_" .. client:EntIndex())

	if (not accept) then
		if (IsValid(requester)) then
			requester:Notify(CharName(client) .. " rechazó el intercambio.")
		end
		return
	end

	if (not IsValid(requester) or not requester:GetCharacter() or not client:GetCharacter()) then
		return client:Notify("No se pudo iniciar el intercambio.")
	end
	if (requester.ixTrade or client.ixTrade) then
		return client:Notify("No se pudo iniciar el intercambio.")
	end
	if (client:GetPos():DistToSqr(requester:GetPos()) > Cfg().useRange ^ 2) then
		return client:Notify("Estás demasiado lejos para intercambiar.")
	end

	ix.intercambio.Begin(requester, client)
end)

net.Receive(PLUGIN.netOffer, function(_, client)
	local action = net.ReadString()
	local itemID = net.ReadUInt(32)

	local session = client.ixTrade
	if (not session or session.ended) then return end

	local char = client:GetCharacter()
	if (not char) then return end

	local isA = (session.a == client)
	local offer = isA and session.offerA or session.offerB

	if (action == "add") then
		if (#offer >= Cfg().maxItems) then
			return client:Notify(("Solo puedes ofrecer %i objetos."):format(Cfg().maxItems))
		end

		local item = ix.item.instances[itemID]
		local inv = char:GetInventory()
		if (not item or not inv or item.invID != inv:GetID()) then return end
		if (table.HasValue(offer, itemID)) then return end

		offer[#offer + 1] = itemID
	elseif (action == "remove") then
		for i, id in ipairs(offer) do
			if (id == itemID) then
				table.remove(offer, i)
				break
			end
		end
	else
		return
	end

	-- Cualquier cambio en la oferta reinicia las confirmaciones (anti-scam).
	session.confirmA = false
	session.confirmB = false
	Broadcast(session)
end)

net.Receive(PLUGIN.netConfirm, function(_, client)
	local confirmed = net.ReadBool()

	local session = client.ixTrade
	if (not session or session.ended) then return end
	if (not ix.intercambio.InRange(session)) then
		return ix.intercambio.End(session, "Os habéis alejado demasiado.")
	end

	if (session.a == client) then
		session.confirmA = confirmed
	else
		session.confirmB = confirmed
	end

	if (session.confirmA and session.confirmB) then
		ix.intercambio.Execute(session)
	else
		Broadcast(session)
	end
end)

net.Receive(PLUGIN.netCancel, function(_, client)
	local session = client.ixTrade
	if (session) then
		ix.intercambio.End(session, "Intercambio cancelado.")
	end
end)

function PLUGIN:PlayerDisconnected(client)
	if (client.ixTrade) then
		ix.intercambio.End(client.ixTrade, "El otro jugador se desconectó.")
	end
	client.ixTradeReqFrom = nil
end
