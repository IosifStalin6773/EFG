local PLUGIN = PLUGIN

util.AddNetworkString("flujo_Save")    -- cl→sv: guardar y compilar un grafo (admin)
util.AddNetworkString("flujo_Request") -- cl→sv: pedir los grafos (admin)
util.AddNetworkString("flujo_Data")    -- sv→cl: lista de grafos para el editor

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
