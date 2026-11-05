-- Mochilas modulares: la tapa superior es un módulo que se puede quitar.
-- Quitarla reduce el inventario real de Helix (SetSize) y sube las filas de
-- ítems una posición. No se quita si hay ítems en las filas que desaparecen.

ix.efg = ix.efg or {}
ix.efg.backpack = ix.efg.backpack or {}

local B = ix.efg.backpack

-- Definición de la mochila (tamaño base y módulos) desde ix.efg.equipment.backpacks
function B.Def(item)
	local id = item and item.efgBackpack
	return id and ix.efg.equipment.backpacks[id] or nil
end

function B.Flap(item)
	local def = B.Def(item)
	return def and def.removableModules and def.removableModules.topFlap or nil
end

function B.FlapOn(item)
	return item:GetData("efgFlap", true) != false
end

-- Filas que ocupa la tapa (desde arriba)
local function Rows(item)
	local flap = B.Flap(item)
	return flap and flap.rows or 1
end

-- ¿Hay algún ítem en las filas que la tapa ocupa?
local function Blocked(inv, rows)
	for _, it in pairs(inv:GetItems(true)) do
		if (it.gridY and it.gridY <= rows) then
			return true
		end
	end

	return false
end

-- Desplaza todos los ítems dy filas. Con dy < 0 se empieza por arriba para no pisar.
local function Shift(inv, dy, client)
	local list = inv:GetItems(true)

	table.sort(list, function(a, b)
		if (dy < 0) then return (a.gridY or 0) < (b.gridY or 0) end
		return (a.gridY or 0) > (b.gridY or 0)
	end)

	for _, it in ipairs(list) do
		if (it.gridX and it.gridY) then
			it:Transfer(inv:GetID(), it.gridX, it.gridY + dy, client)
		end
	end
end

-- Pone o quita la tapa. Devuelve true, o false y la clave de error.
function B.SetFlap(item, on, client)
	if (!SERVER) then return false end

	local inv = item:GetInventory()
	if (!inv) then return false end

	if (B.FlapOn(item) == on) then return true end

	local rows = Rows(item)
	local w, h = inv:GetSize()

	if (!on) then
		if (Blocked(inv, rows)) then
			return false, "efgFlapBlocked"
		end

		Shift(inv, -rows, client)
		inv:SetSize(w, h - rows)
	else
		Shift(inv, rows, client)
		inv:SetSize(w, h + rows)
	end

	item:SetData("efgFlap", on)

	return true
end

-- Ajusta el tamaño del inventario de la mochila según su tapa. Solo servidor.
function B.Apply(item)
	if (!SERVER) then return end

	local def = B.Def(item)
	local inv = item:GetInventory()
	if (!def or !inv) then return end

	local rows = Rows(item)
	local h = def.size.h - (B.FlapOn(item) and 0 or rows)

	inv:SetSize(def.size.w, h)
end

if (SERVER) then
	hook.Add("PlayerLoadedCharacter", "efgBackpackApply", function(client)
		-- Espera a que Helix restaure los inventarios de los ítems
		timer.Simple(1, function()
			if (!IsValid(client)) then return end

			local character = client:GetCharacter()
			if (!character) then return end

			local inv = character:GetInventory()
			if (!inv) then return end

			for _, it in pairs(inv:GetItems(true)) do
				if (it.efgBackpack) then
					B.Apply(it)
				end
			end
		end)
	end)
end
