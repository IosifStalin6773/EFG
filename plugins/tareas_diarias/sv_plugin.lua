local PLUGIN = PLUGIN

util.AddNetworkString("tareasDiarias_Accept")   -- cl→sv: aceptar la tarea de un comerciante
util.AddNetworkString("tareasDiarias_Deliver")  -- cl→sv: entregar objetos de una tarea de entrega
util.AddNetworkString("tareasDiarias_Result")   -- sv→cl: resultado de una acción

-- Puntos de zona de exploración, guardados en el plugin.
function PLUGIN:LoadData()
	ix.tareasDiarias.zonePoints = self:GetData() or {}
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end
	self:SetData(ix.tareasDiarias.zonePoints)
end

-- Fija el punto de una zona en la posición dada. Devuelve true o false, mensaje.
function ix.tareasDiarias.SetZonePoint(mapID, index, pos)
	local names = ix.tareasDiarias.zones[mapID]
	if (!names or !names[index]) then return false, "Mapa o zona no válidos." end

	ix.tareasDiarias.zonePoints[mapID] = ix.tareasDiarias.zonePoints[mapID] or {}
	ix.tareasDiarias.zonePoints[mapID][index] = {
		pos = {x = pos.x, y = pos.y, z = pos.z},
		radius = 600
	}

	PLUGIN:SaveData()
	return true, "Zona fijada: " .. names[index] .. "."
end

ix.util.Include("sv_generator.lua")
ix.util.Include("sv_progress.lua")

-- El jugador debe estar cerca de un comerciante de esa clave para aceptar o entregar.
local function nearTrader(client, traderKey)
	for _, ent in ipairs(ents.FindByClass("ix_trader")) do
		if (IsValid(ent) and ent.factionKey == traderKey and client:GetPos():Distance(ent:GetPos()) <= 256) then
			return true
		end
	end

	return false
end

local function reply(client, ok, msg)
	net.Start("tareasDiarias_Result")
		net.WriteBool(ok)
		net.WriteString(msg or "")
	net.Send(client)
end

net.Receive("tareasDiarias_Accept", function(_, client)
	local traderKey = net.ReadString()
	if (!nearTrader(client, traderKey)) then return reply(client, false, "Acércate al comerciante.") end

	local ok, msg = ix.tareasDiarias.Accept(client, traderKey)
	reply(client, ok, msg)
end)

net.Receive("tareasDiarias_Deliver", function(_, client)
	local traderKey = net.ReadString()
	if (!nearTrader(client, traderKey)) then return reply(client, false, "Acércate al comerciante.") end

	local ok, msg = ix.tareasDiarias.Deliver(client, traderKey)
	reply(client, ok, msg)
end)
