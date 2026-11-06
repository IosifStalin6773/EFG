local PLUGIN = PLUGIN

util.AddNetworkString("flujo_Save") -- cl→sv: guardar y compilar un grafo (admin)

ix.util.Include("sv_compiler.lua")

function PLUGIN:LoadData()
	ix.flujo.graphs = self:GetData() or {}
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end
	self:SetData(ix.flujo.graphs)
end

-- Guarda el grafo, lo valida y compila a una misión de ix.missions.
function ix.flujo.Save(graph)
	local ok, msg = ix.flujo.Validate(graph)
	if (!ok) then return false, msg end

	local mission = ix.flujo.Compile(graph)
	if (!mission) then return false, "no se pudo compilar." end

	ix.flujo.graphs[graph.id] = graph
	ix.missions.list[mission.id] = mission

	local missions = ix.plugin.Get("missions")
	if (missions) then missions:SaveData() end

	PLUGIN:SaveData()
	return true
end

net.Receive("flujo_Save", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local graph = net.ReadTable()
	local ok, msg = ix.flujo.Save(graph)
	client:Notify(ok and "Grafo guardado y compilado." or ("Grafo no guardado: " .. tostring(msg)))
end)
