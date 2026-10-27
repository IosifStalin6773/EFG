local PLUGIN = PLUGIN

if (!SERVER) then return end

local KARMA = ix.efg.karma

function KARMA.Add(character, delta)
	if (!character or delta == 0) then return end

	local value = math.Clamp(KARMA.Get(character) + delta, KARMA.min, KARMA.max)
	character:SetData("efgKarma", math.Round(value, 2))

	local client = character:GetPlayer()

	if (IsValid(client)) then
		client:Notify(("Karma Scav %s%.2f (ahora %.2f)."):format(delta > 0 and "+" or "", delta, value))
	end
end

local function isScav(client)
	return IsValid(client) and client:IsPlayer() and client:GetNetVar("efgRaidSide") == "scav"
end

function PLUGIN:OnNPCKilled(npc, attacker)
	if (npc.efgIsScav and isScav(attacker)) then
		KARMA.Add(attacker:GetCharacter(), ix.config.Get("efgKarmaKillScav", -0.2))
	end
end

function PLUGIN:DoPlayerDeath(victim, attacker)
	if (attacker != victim and isScav(attacker) and isScav(victim)) then
		KARMA.Add(attacker:GetCharacter(), ix.config.Get("efgKarmaKillPlayerScav", -0.2))
	end
end

function PLUGIN:EFGRaidEnded(client, side, reason)
	if (side == "scav" and reason == "extract") then
		KARMA.Add(client:GetCharacter(), ix.config.Get("efgKarmaExtract", 0.01))
	end
end

-- La IA de Scavs solo es amistosa con tu Scav si tu karma no es demasiado bajo
function KARMA.IsFriendly(client)
	return KARMA.Get(client:GetCharacter()) >= ix.config.Get("efgKarmaHostile", -1)
end
