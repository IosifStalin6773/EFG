local PLUGIN = PLUGIN

PLUGIN.name = "EFG PMC"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Creador de PMC (bando, apariencia y accesorios, atributos, rol y equipo inicial), voces en juego y lobby principal."

ix.efg = ix.efg or {}
ix.efg.pmc = ix.efg.pmc or {}

local PMC = ix.efg.pmc

-- ─── Bandos jugables ─────────────────────────────────────────────────────────
-- key = prefijo de los sonidos de voz (vo/scales/eft_<key>_...) y de los emblemas
-- (efgui/factions/<key>.png). faces = opciones del bodygroup "Head" del modelo
-- extendido (models/eft/pmcs/<key>_extended_pm.mdl), leídas del propio .mdl.
PMC.sides = {
	usec = {
		name = "USEC",
		model = "models/eft/pmcs/usec_extended_pm.mdl",
		faces = 8,
		description = "Operador de USEC, la compañía militar privada contratada por TerraGroup."
	},
	bear = {
		name = "BEAR",
		model = "models/eft/pmcs/bear_extended_pm.mdl",
		faces = 7,
		description = "Operador de BEAR, la unidad militar privada creada por el gobierno ruso."
	}
}

-- Voces: el addon de voces de EFT solo trae una voz por bando, así que la
-- segunda es la misma grabación con otro tono. Para añadir voces reales basta
-- con meter otra entrada con su propio "prefix".
PMC.voices = {
	{name = "Voz 1", pitch = 100},
	{name = "Voz 2", pitch = 88},
}

-- Nº de líneas de cada evento (vo/scales/eft_<bando>_<evento><n>.mp3, n = 1..N).
-- Sacado de los addons TFA-VOX EFT USEC (1970593283) y BEAR (1952504766).
PMC.voiceLines = {
	usec = {
		ammo = 6, back = 2, battlecry = 27, cheer = 5, clear = 9, coop = 8, cover = 4, death = 9,
		enemy_snip = 3, enemydown = 14, enemyspotted = 18, fall = 3, fallback = 1, follow = 10,
		friendlydown = 6, friendlyfire = 13, go = 10, good2fire = 7, hand = 4, helpme = 7, hold = 2,
		leg = 6, lowhp = 24, no = 8, noise = 5, onyourown = 5, pickup = 12, ready = 4, reload = 15,
		["repeat"] = 4, spawn = 12, stop = 5, wound = 11, yes = 7
	},
	bear = {
		ammo = 7, back = 8, battlecry = 40, cheer = 6, clear = 6, coop = 7, cover = 6, death = 8,
		enemy_snip = 5, enemy_zombie = 4, enemydown = 15, enemyspotted = 27, fall = 3, fallback = 5,
		follow = 7, friendlydown = 5, friendlyfire = 17, go = 12, good2fire = 8, group = 3, hand = 5,
		helpme = 6, hold = 7, leg = 4, lowhp = 31, no = 8, noise = 5, onpos = 9, onyourown = 7,
		pickup = 10, ready = 9, reload = 13, spawn = 12, stop = 6, wound = 13, yes = 8
	}
}

-- Frases que el jugador puede decir con /Frase (como la rueda de frases de EFT)
PMC.phrases = {
	si = "yes", no = "no", sigueme = "follow", espera = "hold", vamos = "go", cubrete = "cover",
	listo = "ready", enemigo = "enemyspotted", ayuda = "helpme", alto = "stop", despejado = "clear"
}

-- Bando de una facción de Helix ("usec", "bear" o nil)
function PMC.GetSideKey(factionIndex)
	if (FACTION_USEC and factionIndex == FACTION_USEC) then return "usec" end
	if (FACTION_BEAR and factionIndex == FACTION_BEAR) then return "bear" end
end

function PMC.GetVoicePath(sideKey, event, index)
	return ("vo/scales/eft_%s_%s%d.mp3"):format(sideKey, event, index)
end

function PMC.RandomVoicePath(sideKey, event)
	local count = PMC.voiceLines[sideKey] and PMC.voiceLines[sideKey][event]
	if (!count) then return end

	return PMC.GetVoicePath(sideKey, event, math.random(count))
end

-- ─── Variables del personaje ─────────────────────────────────────────────────
-- La cara se elige al crear el PMC y no se puede cambiar (como en EFT). La voz
-- se puede cambiar después desde el lobby (Ajustes) o con /Voz.
ix.char.RegisterVar("efgFace", {
	field = "efg_face",
	fieldType = ix.type.number,
	default = 1,
	bNoDisplay = true,
	OnValidate = function(self, value, payload, client)
		local side = PMC.sides[PMC.GetSideKey(payload.faction) or ""]
		value = tonumber(value)

		if (!side) then
			return 1
		end

		if (!value or value < 1 or value > side.faces or value != math.floor(value)) then
			return false, "efgInvalidFace"
		end

		return value
	end
})

ix.char.RegisterVar("efgVoice", {
	field = "efg_voice",
	fieldType = ix.type.number,
	default = 1,
	bNoDisplay = true,
	OnValidate = function(self, value, payload, client)
		value = tonumber(value)

		if (!value or !PMC.voices[value]) then
			return false, "efgInvalidVoice"
		end

		return value
	end
})

-- ─── Nombre (nickname de EFT) ────────────────────────────────────────────────
-- 3-15 caracteres: letras, números, guion y guion bajo, sin espacios.
function PMC.ValidateNickname(name)
	name = tostring(name or "")

	if (#name < 3 or #name > 15) then
		return false, "efgNameLength"
	end

	if (!name:match("^[%w_%-]+$")) then
		return false, "efgNameChars"
	end

	return true
end

-- ─── Comandos ────────────────────────────────────────────────────────────────
ix.command.Add("Voz", {
	description = "Cambia la voz de tu PMC (1 o 2). La cara no se puede cambiar.",
	arguments = ix.type.number,
	OnRun = function(self, client, voice)
		return PLUGIN:SetVoice(client, voice)
	end
})

ix.command.Add("Frase", {
	description = "Tu PMC dice una frase: si, no, sigueme, espera, vamos, cubrete, listo, enemigo, ayuda, alto, despejado.",
	arguments = ix.type.string,
	OnRun = function(self, client, phrase)
		local event = PMC.phrases[string.lower(phrase)]

		if (!event) then
			return "Frases: si, no, sigueme, espera, vamos, cubrete, listo, enemigo, ayuda, alto, despejado."
		end

		PLUGIN:PlayVoice(client, event, true)
	end
})

ix.command.Add("Lobby", {
	description = "Abre el menú TAB en la pestaña de raid.",
	OnRun = function(self, client)
		net.Start("ixEFGOpenLobby")
		net.Send(client)
	end
})

ix.util.Include("sh_creation.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_creation.lua")
ix.util.Include("cl_cosmetic.lua")
ix.util.Include("cl_creator.lua")
ix.util.Include("cl_lobby.lua")
