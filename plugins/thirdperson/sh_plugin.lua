PLUGIN.name = "Third Person Toggle"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Activa/desactiva tercera persona con Bloq Mayús, usando el sistema de ix.option de Helix."

ix.util.Include("cl_plugin.lua")

-- Permite o prohíbe la tercera persona desde la config del servidor
ix.config.Add("thirdperson", true, "Permite la tercera persona en el servidor.", nil, {
	category = "server"
})
