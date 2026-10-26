local PLUGIN = PLUGIN

util.AddNetworkString("ixAreaVisRequest")
util.AddNetworkString("ixAreaVisBadairSync")
util.AddNetworkString("ixAreaVisAdd")

-- El cliente admin solicita las zonas de badair.
-- ix.badair solo existe en servidor, así que las enviamos aquí.
net.Receive("ixAreaVisRequest", function(_, client)
	if (not client:IsAdmin()) then return end

	local zones = (ix.badair and ix.badair.getAll()) or {}
	local count = math.min(#zones, 255)  -- UInt8 máx 255 zonas

	net.Start("ixAreaVisBadairSync")
		net.WriteUInt(count, 8)
		for i = 1, count do
			net.WriteVector(zones[i][1])
			net.WriteVector(zones[i][2])
		end
	net.Send(client)
end)

-- Recibe una nueva zona del cliente admin y la crea en el sistema correspondiente.
net.Receive("ixAreaVisAdd", function(_, client)
	if (not client:IsAdmin()) then return end

	local areaType = net.ReadString()
	local vMin     = net.ReadVector()
	local vMax     = net.ReadVector()

	if (areaType == "badair") then
		if (not ix.badair) then
			client:ChatPrint("[AreaVis] Error: plugin badair no disponible.")
			return
		end
		ix.badair.addArea(vMin, vMax)
		local badairPlugin = ix.plugin.Get("badair")
		if (badairPlugin) then badairPlugin:SaveData() end
		client:ChatPrint("[AreaVis] Zona badair creada y guardada.")
	else
		client:ChatPrint("[AreaVis] Tipo '" .. areaType .. "' no soportado aún.")
	end
end)
