PLUGIN.gunData = {}
PLUGIN.modelCam = {}
PLUGIN.slotCategory = {
	[1] = "secondary",
	[2] = "primary",
	[3] = "primary",
	[4] = "primary",
}

-- I don't want to make them to buy 50 different kind of ammo
PLUGIN.changeAmmo = {
	["7.92x33mm Kurz"] = "ar2",
	["300 AAC Blackout"] = "ar2",
	["5.7x28mm"] = "pistol",
	["7.65x17MM"] = "smg1",
	["7.62x25mm Tokarev"] = "smg1",
	["7.62x25MM"] = "smg1",
	[".50 BMG"] = "ar2",
	["5.56x45mm"] = "ar2",
	["7.62x51mm"] = "ar2",
	["7.62x31mm"] = "ar2",
	["Frag Grenades"] = "grenade",
	["Flash Grenades"] = "grenade",
	["Smoke Grenades"] = "grenade",
	["9x17MM"] = "smg1",
	["9x19MM"] = "smg1",
	["glock_ammo"] = "smg1",
	[".45 ACP"] = "pistol",
	["9x18MM"] = "pistol",
	["9x39MM"] = "ar2",
	[".40 S&W"] = "pistol",
	[".44 Magnum"] = "pistol",
	[".50 AE"] = "357",
	["5.45x39MM"] = "ar2",
	["5.56x45MM"] = "ar2",
	["5.7x28MM"] = "pistol",
	["7.62x51MM"] = "ar2",
	["7.62x54mmR"] = "ar2",
	["12 Gauge"] = "buckshot",
	["7.62x54R"] = "sniperround",
	[".338 Lapua"] = "sniperround",
	["RPG_Round"] = "rpg_round",
	[".338mm"] = "sniperround",
	["7.62x39MM"] = "ar2",
	["6.8MM"] = "ar2",
	["9x39MM"] = "ar2",
	["9X19MM"] = "smg1",
	["Gauss Ammo"] = "sniperround",
}


--[[
local AMMO_BOX = "models/Items/BoxSRounds.mdl"
local AMMO_CASE = "models/Items/357ammo.mdl"
local AMMO_FLARE = "models/Items/BoxFlares.mdl"
local AMMO_BIGBOX = "models/Items/BoxMRounds.mdl"
local AMMO_BUCKSHOT = "models/Items/BoxBuckshot.mdl"
local AMMO_GREN = "models/Items/AR2_Grenade.mdl"
local AMMO_RPG = "models/spenser/ssk/item/rpg7_grenade.mdl" --"models/weapons/w_missile_closed.mdl"
local AMMO_VOG = "models/spenser/ssk/item/vog_25.mdl" --"models/items/ar2_grenade.mdl"
]]

PLUGIN.ammoInfo = {}
PLUGIN.ammoInfo["pistol"] = {
	name = "Munición de pistola (9x18, 9x19, .45)",
	amount = 16,
	price = 40,
	model = "models/lostsignalproject/items/ammo/357.mdl"
}
PLUGIN.ammoInfo["357"] = {
	name = "Munición pesada (.338, 12.7x55)",
	amount = 20,
	price = 30,
	model = "models/props_lab/box01a.mdl"
}
PLUGIN.ammoInfo["smg1"] = {
	name = "Munición 5.45x39 / 5.56x45",
	amount = 20,
	price = 45,
	model = "models/props_lab/box01a.mdl"
}
PLUGIN.ammoInfo["ar2"] = {
	name = "Munición 7.62x39 / 7.62x51 / 7.62x54R",
	amount = 30,
	price = 50,
	model = "models/devcon/mrp/props/ak_magazine.mdl"
}
PLUGIN.ammoInfo["buckshot"] = {
	name = "Cartuchos 12/70",
	amount = 16,
	price = 35,
	model = "models/lostsignalproject/items/ammo/12x70.mdl"
}
PLUGIN.ammoInfo["sniperround"] = {
	name = "Munición de francotirador",
	amount = 10,
	price = 60,
	model = "models/lostsignalproject/items/ammo/762x39.mdl"
}
PLUGIN.ammoInfo["AR2AltFire"] = {
	name = "Munición Pesada",
	amount = 40,
	price = 80,
	model = "models/devcon/mrp/props/ammo_lenta.mdl"
}

ix.util.Include("presets/sh_defcw.lua")
ix.util.Include("presets/sh_new.lua")

