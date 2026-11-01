local PLUGIN = PLUGIN

PLUGIN.name        = "EFG HUD"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "HUD de EFG: port del addon EFT HUD (estado por zonas, postura, resistencia, cargador, avisos, cursor) con sus texturas en content/materials/efg/hud, más necesidades, barra de acción y etiquetas. No necesita el addon instalado."

ix.efg = ix.efg or {}
ix.efg.hud = ix.efg.hud or {}

-- elementos del HUD de GMod que sustituye este plugin
PLUGIN.hide = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true,
	CHudCrosshair = true, CHudWeaponSelection = true, CHudDamageIndicator = true,
	CHudPoisonDamageIndicator = true, CHudSquadStatus = true, CHudZoom = true
}

ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_tarkov.lua")

if (SERVER) then
	resource.AddFile("sound/efg/notification_exp.wav")
end
