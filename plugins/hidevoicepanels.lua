local PLUGIN = PLUGIN

PLUGIN.name = "HideVoicePanels"
PLUGIN.author = "EFG Project" -- original: Kira
PLUGIN.description = "Hide voice panels"

function PLUGIN:PlayerStartVoice()
	GM = GM or GAMEMODE
	function GM:PlayerStartVoice(ply)
		return
	end
end