local PLUGIN = PLUGIN

PLUGIN.name = "EFG Reglas de inventario"
PLUGIN.author = "EFG"
PLUGIN.description = "Rotación de objetos (R), qué cabe en cada contenedor y objetos encontrados en raid (FIR)."

-- Fuentes (wiki de EFT):
--   Inventory ........ https://escapefromtarkov.fandom.com/wiki/Inventory  (rotar con R)
--   Containers ....... https://escapefromtarkov.fandom.com/wiki/Containers (restricciones de cada caja)
--   Secure containers  https://escapefromtarkov.fandom.com/wiki/Secure_containers
--   Found in raid .... https://escapefromtarkov.fandom.com/wiki/Found_in_raid

ix.efg = ix.efg or {}
ix.efg.inv = ix.efg.inv or {}

local INV = ix.efg.inv

-- ─── Rotación ────────────────────────────────────────────────────────────────
-- Un objeto girado guarda data.rot = true. Las instancias devuelven ancho y
-- alto intercambiados, así que la rejilla de Helix, el arrastre y los iconos
-- usan el tamaño girado sin tocar el código de Helix.
local function rotatedIndex(stock)
	return function(item, key)
		if (key == "width" or key == "height") then
			local data = rawget(item, "data")

			if (data and data.rot) then
				return stock[key == "width" and "height" or "width"]
			end
		end

		return stock[key]
	end
end

local function patch(item)
	local meta = getmetatable(item)
	local stock = ix.item.list[item.uniqueID]

	if (meta and stock and meta.__index == stock) then
		meta.__index = rotatedIndex(stock)
	end
end

if (!INV.originalNew) then
	INV.originalNew = ix.item.New

	function ix.item.New(uniqueID, id)
		local item = INV.originalNew(uniqueID, id)

		if (item) then patch(item) end

		return item
	end
end

for _, item in pairs(ix.item.instances) do
	patch(item)
end

function INV.IsRotated(item)
	return item and item.data and item.data.rot == true
end

-- Marca un objeto para que los clientes muevan sus casillas (shared)
function INV.ApplyFootprint(inventory, item, x, y, w, h)
	for cx, column in pairs(inventory.slots) do
		for cy, other in pairs(column) do
			if (other == item) then column[cy] = nil end
		end
	end

	for dx = 0, w - 1 do
		for dy = 0, h - 1 do
			inventory.slots[x + dx] = inventory.slots[x + dx] or {}
			inventory.slots[x + dx][y + dy] = item
		end
	end
end

-- ─── Qué cabe en cada contenedor ─────────────────────────────────────────────
-- uniqueID del contenedor → función(item) que devuelve true si se puede meter.
-- Containers: la caja de munición solo acepta munición; la médica, medicamentos;
-- la de armas, armas y accesorios; la de objetos, todo menos contenedores.
local function category(...)
	local set = {}
	for _, name in ipairs({...}) do set[name] = true end

	return function(item) return set[item.category or ""] == true end
end

local function notContainer(item)
	return !item.isBag
end

INV.allow = {
	case_ammo = category("Munición", "Municion"),
	case_med = category("Medicamentos"),
	case_weapon = function(item) return item.isWeapon or item.isEFGMod or item.category == "Mods" or item.category == "Accesorios" end,
	case_item = notContainer,
	-- Secure containers: no admiten mochilas, chalecos tácticos ni otros contenedores
	secure_alpha = notContainer,
	secure_beta = notContainer,
	secure_gamma = notContainer,
	secure_kappa = notContainer,
}

INV.reason = {
	case_ammo = "La caja de munición solo admite munición.",
	case_med = "La caja médica solo admite medicamentos.",
	case_weapon = "La caja de armas solo admite armas y accesorios.",
}

-- Contenedor (uniqueID) al que pertenece un inventario de bolsa, o nil
function INV.GetContainerID(inventory)
	return inventory and inventory.vars and isstring(inventory.vars.isBag) and inventory.vars.isBag or nil
end

function PLUGIN:CanTransferItem(item, oldInv, newInv)
	local containerID = INV.GetContainerID(newInv)
	local allow = containerID and INV.allow[containerID]

	if (allow and !allow(item)) then
		if (SERVER) then
			local character = newInv.owner and ix.char.loaded[newInv.owner]
			local client = character and character:GetPlayer()

			if (IsValid(client)) then
				client:Notify(INV.reason[containerID] or "Eso no cabe en este contenedor.")
			end
		end

		return false
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
