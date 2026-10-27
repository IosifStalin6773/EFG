local PLUGIN = PLUGIN

PLUGIN.name = "EFG Guardia"
PLUGIN.author = "EFG"
PLUGIN.description = "Anti-cheat básico: limita los mensajes de red por jugador y avisa a los admins de abusos."

ix.config.Add("efgNetLimit", 150, "Mensajes de red por segundo a partir de los que se ignoran los de un jugador.", nil, {
	data = {min = 30, max = 2000}, category = "EFG"
})
ix.config.Add("efgNetKick", 600, "Mensajes de red por segundo a partir de los que se expulsa al jugador (0 = nunca).", nil, {
	data = {min = 0, max = 5000}, category = "EFG"
})

ix.util.Include("sv_plugin.lua")
