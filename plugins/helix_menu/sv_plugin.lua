util.AddNetworkString("ixOpenHelixMenu")

ix.command.Add("OpenHelixMenu", {
	description = "Abre el menú base de Helix.",
	adminOnly = true,
	OnRun = function(self, client)
		net.Start("ixOpenHelixMenu")
		net.Send(client)
	end
})
