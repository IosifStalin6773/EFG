local PLUGIN = PLUGIN

PLUGIN.name        = "EFG HUD"
PLUGIN.author      = "EFG"
PLUGIN.description = "HUD propio de EFG (estilo Pizarra): estado físico, necesidades, resistencia, arma con comprobación de cargador, barra de acción y etiquetas. Sustituye al HUD Metro y no depende de addons de HUD."

ix.efg = ix.efg or {}
ix.efg.hud = ix.efg.hud or {}

-- elementos del HUD de GMod que sustituye este plugin
PLUGIN.hide = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true,
	CHudCrosshair = true, CHudWeaponSelection = true, CHudDamageIndicator = true,
	CHudPoisonDamageIndicator = true, CHudSquadStatus = true, CHudZoom = true
}

ix.util.Include("cl_plugin.lua")
