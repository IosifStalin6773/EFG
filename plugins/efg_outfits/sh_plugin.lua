local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Atuendos"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "PMC modulares de Welcome To Tarkov (cabeza, chaqueta y pantalón) y equipo visible sobre el jugador."

ix.efg = ix.efg or {}
ix.efg.outfits = ix.efg.outfits or {}

local outfits = ix.efg.outfits

-- Cada cabeza es el modelo del jugador; la ropa va encima con bonemerge y se
-- elige con el grupo de cuerpo 0 de cada modelo.
outfits.sets = {
	usec = {
		name = "USEC",
		heads = {"models/eft_usec1.mdl", "models/eft_usec3.mdl", "models/eft_usec4.mdl", "models/eft_usec5.mdl"},
		top = "models/eft_usec_clothes.mdl", tops = 12,
		legs = "models/eft_usec_bottoms.mdl", legsCount = 10
	},
	bear = {
		name = "BEAR",
		heads = {"models/eft_bear0.mdl", "models/eft_bear1.mdl", "models/eft_bear3.mdl", "models/eft_bear4.mdl"},
		top = "models/eft_bear_clothes.mdl", tops = 9,
		legs = "models/eft_bear_bottoms.mdl", legsCount = 5
	}
}

outfits.byHead = {}

for id, set in pairs(outfits.sets) do
	set.id = id

	for _, head in ipairs(set.heads) do
		outfits.byHead[head] = set
	end
end

function outfits.GetSet(model)
	return model and outfits.byHead[string.lower(model)]
end

-- devuelve top y legs válidos para el conjunto
function outfits.Clamp(set, top, legs)
	return math.Clamp(math.floor(tonumber(top) or 0), 0, set.tops - 1), math.Clamp(math.floor(tonumber(legs) or 0), 0, set.legsCount - 1)
end

if (SERVER) then
	-- contenido de los addons Welcome To Tarkov (BEAR, USEC y Extras), ahora en el esquema
	local function addDir(dir)
		local files, dirs = file.Find(dir .. "/*", "GAME")

		for _, name in ipairs(files or {}) do
			local ext = string.GetExtensionFromFilename(name)
			if (ext == "mdl" or ext == "vtf" or ext == "vmt") then resource.AddFile(dir .. "/" .. name) end
		end

		for _, name in ipairs(dirs or {}) do addDir(dir .. "/" .. name) end
	end

	for _, name in ipairs(file.Find("models/eft_*.mdl", "GAME")) do resource.AddFile("models/" .. name) end
	addDir("models/player/hats_police")
	addDir("models/player/hats_slots")
	addDir("models/player/hats_uf_pro")
	addDir("models/player/hats_ushanka")
	addDir("models/player/respirator_3m")
	addDir("models/player/respirator_sotr")
	addDir("models/player/rig_a18")
	addDir("models/player/rig_m2")
	addDir("models/player/rig_tv109")
	addDir("models/player/vest_tarzan")
	addDir("models/player/vest_wild")
	addDir("models/tarkov/equipment/props")
	addDir("materials/models/player/character")
	addDir("materials/models/tarkov/equipment/props")

	for _, name in ipairs({"hats_police", "hats_slots", "hats_uf_pro", "hats_ushanka", "respirator_3m", "respirator_sotr", "rig_a18", "rig_m2", "rig_tv109", "vest_tarzan", "vest_wild"}) do
		addDir("materials/models/player/" .. name)
	end
end

ix.command.Add("Atuendo", {
	description = "Elige la cabeza, la chaqueta y el pantalón de tu PMC.",
	OnRun = function(self, client)
		if (!outfits.GetSet(client:GetModel())) then
			return "Tu modelo no tiene atuendo modular. Elige una cabeza USEC o BEAR de Welcome To Tarkov al crear el personaje."
		end

		if (client.InRaid and client:InRaid()) then
			return "No puedes cambiarte de ropa en plena raid."
		end

		net.Start("ixEFGOutfitMenu")
		net.Send(client)
	end
})

ix.util.Include("sh_pac.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- ix_invkey (ranuras) e ix.pac ya están cargados
function PLUGIN:InitializedPlugins()
	outfits.SetupPAC()
end
