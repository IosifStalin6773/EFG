local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Acceso rápido"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Barra de acceso rápido de EFT (teclas 1-5) con las texturas del selector de armas de Tarkov."

if (SERVER) then
	for _, name in ipairs({"background", "binds", "null", "selection"}) do
		resource.AddFile("materials/efg/quickbar/" .. name .. ".png")
	end
end

ix.util.Include("cl_plugin.lua")
