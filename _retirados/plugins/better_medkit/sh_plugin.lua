local PLUGIN = PLUGIN
PLUGIN.name = "Better Medkit"
PLUGIN.author = "JohnyReaper"
PLUGIN.description = "Heal yourself like in a metro"

ALWAYS_RAISED["weapon_jr_m2k33_medkit"] = true

// Equip like in metro style

if (SERVER) then

	function PLUGIN:PlayerDeath(client)
		
		if (timer.Exists( "medkit_healing_" .. client:AccountID() )) then
			timer.Remove( "medkit_healing_" .. client:AccountID() )
		end
		
	end

end