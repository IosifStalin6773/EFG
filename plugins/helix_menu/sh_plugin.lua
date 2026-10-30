PLUGIN.name = "Helix Menu"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Comando /OpenHelixMenu para administradores."

-- Stubs de cliente para que los comandos aparezcan en el autocompletado del chat
if (CLIENT) then
	ix.command.Add("OpenHelixMenu", { adminOnly=true, description="Abre el menú base de Helix.", OnRun=function(self, client) end })
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
