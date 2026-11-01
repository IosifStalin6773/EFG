
PLUGIN.name = "Flashlight item"
PLUGIN.author = "EFG Project" -- original: SleepyMode
PLUGIN.description = "Adds an item allowing players to toggle their flashlight."

ix.char.RegisterVar("flashlightCharge", {
	field = "flashlight_charge",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

-- Compatibilidad con addons externos (ej. Metro 2033 Spiderbugs, workshop 3763365449) que
-- comprueban Player:FlashlightIsOn() para saber si el jugador está iluminado. Nuestra linterna
-- no usa el sistema nativo (ver sv_plugin.lua, PlayerSwitchFlashlight siempre devuelve false),
-- así que sin este override esos NPCs nunca detectan la linterna del jugador como encendida.
local PLAYER = FindMetaTable("Player")
local BaseFlashlightIsOn = PLAYER.FlashlightIsOn

function PLAYER:FlashlightIsOn()
	return self:GetNW2Bool("flashlight_active", false) or BaseFlashlightIsOn(self)
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")