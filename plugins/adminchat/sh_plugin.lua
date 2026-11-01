PLUGIN.name = "Admin Chat"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Chat exclusivo para administradores con prefijo [ADMIN]."

ix.chat.Register("adminchat", {
	format = "[ADMIN] %s: %s",
	GetColor = function(self, speaker, text)
		return Color(255, 50, 50)
	end,
	CanHear = function(self, speaker, listener)
		return listener:IsAdmin()
	end,
	CanSay = function(self, speaker, text)
		if (!speaker:IsAdmin()) then
			speaker:Notify("No tienes permisos para usar el chat de administración.")
			return false
		end
	end,
	prefix = {"/a", "/admin"},
	description = "Chat exclusivo para administradores.",
	indicator = "chatTalking",
	deadAllow = true
})
