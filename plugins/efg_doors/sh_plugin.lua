local PLUGIN = PLUGIN

PLUGIN.name = "EFG Puertas interactivas"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Puertas al estilo EFT: abrir, entreabrir, patear, forzar, cerradura que se rompe a tiros, mirilla y cerrojo, elegidos con la rueda en el cursor de interacción de efg_hud."

ix.efg = ix.efg or {}
ix.efg.doors = ix.efg.doors or {}

local DOORS = ix.efg.doors

DOORS.classes = {
	["prop_door_rotating"] = true,
	["func_door_rotating"] = true
}

DOORS.STATE_CLOSED = 0
DOORS.STATE_OPEN = 1
DOORS.STATE_PEEK = 2

DOORS.range = 96

-- orden en que salen en la lista del cursor
DOORS.actions = {
	open = {label = "efgDoorOpen", order = 1},
	close = {label = "efgDoorClose", order = 2},
	peek = {label = "efgDoorPeek", order = 3},
	kick = {label = "efgDoorKick", order = 4},
	keyhole = {label = "efgDoorKeyhole", order = 5},
	lock = {label = "efgDoorLock", order = 6},
	unlock = {label = "efgDoorUnlock", order = 7}
}

ix.config.Add("efgDoors", true, "Puertas interactivas de EFG (menú con la rueda en vez de abrir y cerrar sin más).", nil, {
	category = "EFG Puertas"
})

ix.config.Add("efgDoorPeekAngle", 22, "Grados que se abre una puerta al entreabrirla.", nil, {
	data = {min = 5, max = 60},
	category = "EFG Puertas"
})

ix.config.Add("efgDoorKickHits", 3, "Patadas para reventar una puerta cerrada con llave.", nil, {
	data = {min = 1, max = 10},
	category = "EFG Puertas"
})

ix.config.Add("efgDoorKickSpeed", 4, "Multiplicador de velocidad al abrir de una patada.", nil, {
	data = {min = 1, max = 10, decimals = 1},
	category = "EFG Puertas"
})

ix.config.Add("efgDoorLockHealth", 60, "Daño de bala que aguanta la cerradura antes de saltar (0 = no se rompe).", nil, {
	data = {min = 0, max = 500},
	category = "EFG Puertas"
})

ix.config.Add("efgDoorLockToggle", true, "Permitir echar y quitar el cerrojo sin llave.", nil, {
	category = "EFG Puertas"
})

ix.config.Add("efgDoorKeyholeTime", 8, "Segundos máximos mirando por la mirilla.", nil, {
	data = {min = 2, max = 30},
	category = "EFG Puertas"
})

-- Puertas de otros plugins que llevan su propio control (facción, brecha):
-- se quedan con el uso normal.
function DOORS.IsManaged(door)
	if (!IsValid(door) or !DOORS.classes[door:GetClass()]) then return false end
	if (door:GetNWInt("ixDoorID", 0) != 0 or door:GetNoDraw()) then return false end
	if (door:GetNetVar("disabled")) then return false end

	return true
end

function DOORS.GetState(door)
	return door:GetNW2Int("efgDoorState", DOORS.STATE_CLOSED), door:GetNW2Bool("efgDoorLocked", false)
end

-- Acciones disponibles según el estado; las mismas en cliente y servidor
function DOORS.GetActions(door)
	local state, locked = DOORS.GetState(door)
	local list = {}

	if (state == DOORS.STATE_CLOSED) then
		list[#list + 1] = "open"

		if (!locked) then
			list[#list + 1] = "peek"
		end

		list[#list + 1] = "kick"

		if (door:GetClass() == "prop_door_rotating") then
			list[#list + 1] = "keyhole"
		end

		if (ix.config.Get("efgDoorLockToggle", true)) then
			list[#list + 1] = locked and "unlock" or "lock"
		end
	elseif (state == DOORS.STATE_PEEK) then
		list[#list + 1] = "open"
		list[#list + 1] = "close"
		list[#list + 1] = "kick"
	else
		list[#list + 1] = "close"
	end

	return list
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
