-- Bloquea los menús C y Q de GMod a menos que el personaje tenga la flag "z".
-- hook.Call("ContextMenuOpen"/"SpawnMenuOpen") interpreta truthy = abrir, falsy = bloquear,
-- y al devolver siempre un booleano se evita por completo el chequeo de admin/CAMI de SAM.
local function HasMenuAccess()
	local character = LocalPlayer():GetCharacter()

	return character != nil and character:HasFlags("z")
end

function PLUGIN:ContextMenuOpen()
	return HasMenuAccess()
end

function PLUGIN:SpawnMenuOpen()
	return HasMenuAccess()
end
