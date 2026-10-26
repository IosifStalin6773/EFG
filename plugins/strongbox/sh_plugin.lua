PLUGIN.name = "Strongbox"
PLUGIN.author = "Vex / EFG"
PLUGIN.description = "Stash personal estilo EFT: empieza 10×30 y crece con el módulo Alijo del escondite."

ix.strongbox = ix.strongbox or {}

-- Ancho fijo; altura según nivel del módulo Alijo del escondite
ix.strongbox.WIDTH      = 10
ix.strongbox.MAX_HEIGHT = 63   -- límite de 6 bits (Helix usa net.WriteUInt(x, 6))

-- Altura base (nivel 0) y por nivel del módulo hideout "stash"
ix.strongbox.HEIGHTS = {[0] = 30, [1] = 40, [2] = 50, [3] = 63}

function ix.strongbox.GetTargetHeight(character)
	local level = 0
	if (ix.efg and ix.efg.hideout and ix.efg.hideout.GetLevel) then
		level = ix.efg.hideout.GetLevel(character, "stash")
	end
	return math.min(ix.strongbox.HEIGHTS[level] or 63, ix.strongbox.MAX_HEIGHT)
end

ix.command.Add("Alijo", {
	description = "Abre tu alijo personal sin necesitar una taquilla.",
	OnRun = function(self, client)
		if (client.InRaid and client:InRaid()) then
			return "No puedes abrir el alijo durante una raid."
		end
		if (SERVER and ix.strongbox.OpenRemote) then
			ix.strongbox.OpenRemote(client)
		end
	end
})

ix.util.Include("sv_plugin.lua")
