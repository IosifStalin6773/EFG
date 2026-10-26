local PLUGIN = PLUGIN

PLUGIN.name        = "HUD Metro"
PLUGIN.author      = "Metro RP By Cono y Manperra"
PLUGIN.description = "HUD estilo Metro 2033 usando assets de MetroUI."

--[[
	PLUGIN.HUD_HIDE
	Lista de elementos del HUD nativo de GMod que este plugin reemplaza.
	Para reactivar un elemento individual, elimina su línea de esta tabla.
--]]
PLUGIN.HUD_HIDE = {
	"CHudHealth",          -- Reemplazado por panel vida Metro. Para reactivar: eliminar esta línea.
	"CHudBattery",         -- Reemplazado por panel armadura Metro. Para reactivar: eliminar esta línea.
	"CHudAmmo",            -- Reemplazado por panel ammo Metro. Para reactivar: eliminar esta línea.
	"CHudSecondaryAmmo",   -- Reemplazado por panel ammo Metro. Para reactivar: eliminar esta línea.
	"CHudCrosshair",       -- Crosshair deshabilitado. Para reactivar: eliminar esta línea.
	"CHudWeaponSelection", -- Eliminado en modo RP. Para reactivar: eliminar esta línea.
	"CHudDamageIndicator",
}

--[[
	PLUGIN.FACTION_ICONS
	Mapeo facción → material de icono de facción.
	Se rellena en cl_plugin.lua dentro de un timer.Simple(1, ...) para garantizar
	que las constantes FACTION_X ya estén asignadas por los sh_faction.lua.
	Material() solo existe en cliente, por lo que esta tabla se construye allí.
--]]
PLUGIN.FACTION_ICONS = {}

ix.util.Include("cl_plugin.lua")
