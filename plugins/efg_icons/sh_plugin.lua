local PLUGIN = PLUGIN

PLUGIN.name = "EFG Iconos"
PLUGIN.author = "EFG"
PLUGIN.description = "Iconos 2D de inventario (ITEM.iconMaterial) con vuelta al modelo 3D si falta la imagen, y rareza de los objetos (ITEM.rarity)."

ix.efg = ix.efg or {}
ix.efg.icons = ix.efg.icons or {}

-- Rareza: el color y el nombre los define ix.efgui.rarity (efg_ui); el peso se
-- usa en el sorteo de loot (plugin loot).
ix.efg.rarityWeight = {common = 100, uncommon = 40, rare = 15, epic = 5, legendary = 1}

-- Carpeta por defecto según la categoría de Helix, para encontrar el icono por
-- uniqueID sin declararlo: materials/efg/icons/<carpeta>/<uniqueID>.png
ix.efg.icons.folders = {
	["Armas"] = "weapon", ["Mods"] = "mod", ["Accesorios"] = "mod", ["Chalecos"] = "armor", ["Cascos"] = "armor",
	["Placas"] = "armor", ["Mochilas"] = "gear", ["Medicamentos"] = "med", ["Comida"] = "food",
	["Munición"] = "ammo", ["Llaves"] = "key", ["Dinero"] = "money",
}

-- Ruta (relativa a materials/) del icono de un ítem, o nil si no hay ninguno.
function ix.efg.icons.Resolve(item)
	local candidates = {}

	if (isstring(item.iconMaterial)) then
		candidates[#candidates + 1] = item.iconMaterial
	end

	local folder = ix.efg.icons.folders[item.category or ""]

	if (folder) then
		candidates[#candidates + 1] = ("efg/icons/%s/%s.png"):format(folder, item.uniqueID)
	end

	for _, path in ipairs(candidates) do
		if (file.Exists("materials/" .. path, "GAME")) then
			return path
		end
	end
end

-- Rareza por defecto según el precio, para los ítems que no la declaran.
function ix.efg.GetRarity(item)
	if (item.rarity) then return item.rarity end

	local price = tonumber(item.price) or 0

	if (price >= 250000) then return "legendary" end
	if (price >= 100000) then return "epic" end
	if (price >= 40000) then return "rare" end
	if (price >= 12000) then return "uncommon" end

	return "common"
end

-- Se asigna un tick después para incluir los ítems que otros plugins registran
-- en su propio InitializedPlugins (las armas de efg_arc9).
function PLUGIN:InitializedPlugins()
	timer.Simple(0, function()
		for _, item in pairs(ix.item.list) do
			item.rarity = ix.efg.GetRarity(item)
		end
	end)
end

ix.util.Include("cl_plugin.lua")
