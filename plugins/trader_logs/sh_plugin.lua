PLUGIN.name        = "Trader Logs"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Trazabilidad de los ítems vendidos por traders: registra comprador, poseedores sucesivos, detecta duplicados y permite eliminar el objeto desde un panel de administración."

ix.traderlogs = ix.traderlogs or {}

-- Cuántas entradas de historial de traspasos se guardan por ítem (las más antiguas se descartan)
ix.traderlogs.maxHistory = 40

-- Stubs de cliente para el autocompletado de los comandos en el chat
if (CLIENT) then
	ix.command.Add("TraderLogs", {
		adminOnly   = true,
		description = "Abre el panel de trazabilidad de ítems vendidos por traders.",
		OnRun = function(self, client) end
	})
	ix.command.Add("DupeScanner", {
		adminOnly   = true,
		description = "Escanea todos los ítems cargados del servidor buscando duplicados.",
		OnRun = function(self, client) end
	})
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
