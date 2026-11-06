local PLUGIN = PLUGIN

util.AddNetworkString("flujo_Save")    -- cl→sv: guardar y compilar un grafo (admin)
util.AddNetworkString("flujo_Request") -- cl→sv: pedir los grafos (admin)
util.AddNetworkString("flujo_Data")    -- sv→cl: lista de grafos para el editor
util.AddNetworkString("flujo_Branches") -- sv→cl: comerciantes con grafo ramificado
util.AddNetworkString("flujo_Start")    -- cl→sv: empezar el diálogo de un comerciante
util.AddNetworkString("flujo_Choose")   -- cl→sv: elegir opción (1..4)
util.AddNetworkString("flujo_Node")     -- sv→cl: nodo que el jugador ve

ix.util.Include("sv_compiler.lua")
ix.util.Include("sv_import.lua")
ix.util.Include("sv_branch.lua")

function PLUGIN:LoadData()
	ix.flujo.graphs = self:GetData() or {}
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end
	self:SetData(ix.flujo.graphs)
end

-- Guarda el grafo, lo valida y compila a una misión de ix.missions.
function ix.flujo.Save(graph)
	local ok, msg = ix.flujo.ValidateAny(graph)
	if (!ok) then return false, msg end

	local missions
	if (ix.flujo.IsBranching(graph)) then
		missions = ix.flujo.CompileBranch(graph)
	else
		local mission = ix.flujo.Compile(graph)
		if (!mission) then return false, "no se pudo compilar." end
		missions = {mission}
	end

	ix.flujo.graphs[graph.id] = graph
	for _, mission in ipairs(missions) do
		ix.missions.list[mission.id] = mission
	end

	local missions = ix.plugin.Get("missions")
	if (missions) then missions:SaveData() end

	PLUGIN:SaveData()
	PLUGIN:SendBranches(nil)
	return true
end

-- Lista de grafos como array (el editor la recorre con índices).
function PLUGIN:SendGraphs(client)
	local list = {}
	for _, graph in pairs(ix.flujo.graphs) do list[#list + 1] = graph end

	net.Start("flujo_Data")
		net.WriteTable(list)
	net.Send(client)
end

net.Receive("flujo_Request", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end
	PLUGIN:SendGraphs(client)
end)

net.Receive("flujo_Save", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local graph = net.ReadTable()
	local ok, msg = ix.flujo.Save(graph)
	client:Notify(ok and "Grafo guardado y compilado." or ("Grafo no guardado: " .. tostring(msg)))
	PLUGIN:SendGraphs(client)
end)

-- Comerciantes con grafo ramificado. nil = a todos.
function PLUGIN:SendBranches(target)
	local keys, list = {}, {}
	for _, graph in pairs(ix.flujo.graphs) do
		if (ix.flujo.IsBranching(graph) and !keys[graph.traderKey]) then
			keys[graph.traderKey] = true
			list[#list + 1] = graph.traderKey
		end
	end

	net.Start("flujo_Branches")
		net.WriteTable(list)
	if (target) then net.Send(target) else net.Broadcast() end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	self:SendBranches(client)
end

local function sendNode(client, ok, data)
	net.Start("flujo_Node")
		net.WriteBool(ok)
		if (ok) then net.WriteTable(data) else net.WriteString(tostring(data)) end
	net.Send(client)
end

net.Receive("flujo_Start", function(_, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local ent = net.ReadEntity()
	if (!IsValid(ent) or ent:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, ent)) then return end

	local graphID
	for id, graph in pairs(ix.flujo.graphs) do
		if (graph.traderKey == (ent.factionKey or "") and ix.flujo.IsBranching(graph)) then
			graphID = id
		end
	end

	if (!graphID) then return sendNode(client, false, "Este comerciante no tiene diálogo.") end

	local payload, msg = ix.flujo.Start(client:GetCharacter(), graphID)
	if (!payload) then return sendNode(client, false, msg) end
	sendNode(client, true, payload)
end)

net.Receive("flujo_Choose", function(_, client)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local ent = net.ReadEntity()
	local choice = net.ReadUInt(4)
	if (!IsValid(ent) or ent:GetClass() != "ix_trader") then return end
	if (!ix.traders.CanReach(client, ent)) then return end

	local payload, msg = ix.flujo.Advance(client:GetCharacter(), choice)
	if (!payload) then return sendNode(client, false, msg) end
	sendNode(client, true, payload)
end)
