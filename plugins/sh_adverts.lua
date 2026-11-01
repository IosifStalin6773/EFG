PLUGIN.name = "Advert"
PLUGIN.author = "EFG Project" -- original: Strasser
PLUGIN.desc = "Añade el comando de advert."


ix.chat.Register("advert", {
	format = "%s Anuncia: \"%s\"",
	GetColor = function(self, speaker, text)
		local color = ix.chat.classes.ic:GetColor(speaker, text)

		-- Make the yell chat slightly brighter than IC chat.
		return Color(205, 195, 61)
	end,
	CanHear = ix.config.Get("chatRange", 10000) * 2,
	prefix = {"/adv", "/advert"},
	description = "@cmdY",
	indicator = "chatYelling"
})