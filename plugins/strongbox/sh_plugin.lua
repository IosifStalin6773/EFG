PLUGIN.name = "Strongbox"
PLUGIN.author = "EFG Project" -- original: Vex / EFG
PLUGIN.description = "Alijo personal: empieza 10×30 y crece con el módulo Alijo del escondite."

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

-- ¿puede el jugador usar su alijo? Solo fuera de raid y dentro del escondite
-- (efg_raids: efgHideoutRadius). En el cliente se lee la netvar efgStashOK que
-- pone el servidor. Devuelve ok, motivo.
function ix.strongbox.CanAccess(client)
	if (client.InRaid and client:InRaid()) then
		return false, "No puedes usar el alijo durante una raid."
	end

	if (CLIENT) then
		return client:GetNetVar("efgStashOK", true) != false, "El alijo solo está disponible en el escondite."
	end

	local raids = ix.plugin.Get("efg_raids")

	if (raids) then
		if (raids.deploys and raids.deploys[client]) then
			return false, "No puedes usar el alijo mientras te despliegas."
		end

		if (raids.GetMapData and raids:GetMapData().hideout and !raids:InHideout(client:GetPos())) then
			return false, "El alijo solo está disponible en el escondite."
		end
	end

	return true
end

ix.command.Add("Alijo", {
	description = "Abre tu alijo personal sin necesitar una taquilla.",
	OnRun = function(self, client)
		local ok, reason = ix.strongbox.CanAccess(client)
		if (!ok) then return reason end

		if (SERVER and ix.strongbox.OpenRemote) then
			ix.strongbox.OpenRemote(client)
		end
	end
})

ix.util.Include("sv_plugin.lua")
