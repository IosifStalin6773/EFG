local PLUGIN = PLUGIN

PLUGIN.name = "EFG Datos EFT"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Base de datos de objetos de Escape from Tarkov sacada de la wiki (nombre, tipo, peso, tamaño, stats, descripción) y sus iconos en materials/eftwiki/icons."

-- Datos: content/data_static/efg/eft_items.json (lista de objetos).
-- Iconos: content/materials/eftwiki/icons/<key>.png (tamaño nativo de EFT, 64 px por casilla).
-- Uso:
--   ix.eftdata.Get("salewa_first_aid_kit")      -> tabla con los datos
--   ix.eftdata.FindByName("Salewa")             -> primera coincidencia por nombre
--   ix.eftdata.Search("bolts", 10)              -> lista de coincidencias
--   ix.eftdata.GetIcon(key)                     -> IMaterial del icono (solo cliente)
--   ix.eftdata.ApplyToItem(ITEM, key)           -> copia nombre, tamaño, peso, descripción e icono a un item de Helix
ix.eftdata = ix.eftdata or {}
ix.eftdata.items = ix.eftdata.items or {}
ix.eftdata.list = ix.eftdata.list or {}

local DATA_FILE = "data_static/efg/eft_items.json"

function ix.eftdata.Load()
	local raw = file.Read(DATA_FILE, "GAME")

	if (!raw) then
		ErrorNoHalt("[EFG] No se encuentra " .. DATA_FILE .. "\n")
		return
	end

	local list = util.JSONToTable(raw) or {}

	ix.eftdata.list = list
	ix.eftdata.items = {}

	for _, entry in ipairs(list) do
		ix.eftdata.items[entry.key] = entry
	end
end

function ix.eftdata.Get(key)
	return ix.eftdata.items[key]
end

function ix.eftdata.Search(text, limit)
	local results = {}
	text = string.lower(text)

	for _, entry in ipairs(ix.eftdata.list) do
		if (string.find(string.lower(entry.name), text, 1, true)) then
			results[#results + 1] = entry

			if (limit and #results >= limit) then
				break
			end
		end
	end

	return results
end

function ix.eftdata.FindByName(text)
	return ix.eftdata.Search(text, 1)[1]
end

if (CLIENT) then
	local cache = {}

	function ix.eftdata.GetIcon(key)
		local entry = ix.eftdata.items[key]

		if (!entry) then
			return
		end

		if (!cache[key]) then
			cache[key] = Material(entry.icon, "smooth")
		end

		return cache[key]
	end
end

-- Rellena un ITEM de Helix con los datos de la wiki. Se llama dentro del archivo del item,
-- por ejemplo: ix.eftdata.ApplyToItem(ITEM, "bolts")
function ix.eftdata.ApplyToItem(item, key)
	if (table.IsEmpty(ix.eftdata.items)) then
		ix.eftdata.Load()
	end

	local entry = ix.eftdata.items[key]

	if (!entry) then
		return
	end

	item.name = item.name or entry.name
	item.width = entry.w or item.width
	item.height = entry.h or item.height
	item.weight = entry.weight or item.weight
	item.description = (item.description and item.description != "") and item.description or entry.description
	item.eftKey = key
	item.iconMaterial = entry.icon
end

ix.eftdata.Load()
ix.util.Include("sh_iconmap.lua")

local function hasIcon(path)
	return isstring(path) and file.Exists("materials/" .. path, "GAME")
end

-- Arma ARC9 -> objeto EFT con el mismo nombre (los packs EFT de ARC9 usan los
-- nombres del juego, p. ej. "AKM" -> "Kalashnikov AKM 7.62x39 assault rifle").
local weaponTypes = {"rifle", "carbine", "pistol", "revolver", "submachine", "shotgun", "machine gun", "launcher", "sniper", "marksman"}

local function findWeapon(printName)
	local wanted = string.lower(printName or "")
	if (wanted == "") then return end

	local best

	for _, entry in ipairs(ix.eftdata.list) do
		if (entry.template == "weapon") then
			local name = string.lower(entry.name)
			local typ = string.lower(entry.type or "")
			local isGun = false

			for _, word in ipairs(weaponTypes) do
				if (string.find(typ, word, 1, true) or string.find(name, word, 1, true)) then
					isGun = true
					break
				end
			end

			if (isGun) then
				if (name == wanted) then
					return entry
				end

				-- el nombre del arma aparece como palabra completa dentro del nombre EFT
				local pattern = "%f[%w]" .. string.PatternSafe(wanted) .. "%f[%W]"

				if (!best and string.find(name, pattern)) then
					best = entry
				end
			end
		end
	end

	return best
end

-- Se asigna un tick después de InitializedPlugins para incluir las armas que
-- efg_arc9 registra ahí. Solo se rellena el icono si el item no tiene uno válido.
function PLUGIN:InitializedPlugins()
	timer.Simple(0, function()
		local count = 0

		for uniqueID, item in pairs(ix.item.list) do
			if (!hasIcon(item.iconMaterial)) then
				local entry = ix.eftdata.items[ix.eftdata.iconMap[uniqueID] or ""]

				if (!entry and item.isARC9) then
					entry = findWeapon(item.name)
				end

				if (entry and hasIcon(entry.icon)) then
					item.iconMaterial = entry.icon
					item.eftKey = entry.key
					count = count + 1
				end
			end
		end

		MsgC(Color(154, 136, 102), "[efg_eftdata] Iconos EFT asignados a " .. count .. " items\n")
	end)
end

if (SERVER) then
	-- Los iconos ocupan ~60 MB; solo se envían por descarga si se activa a mano.
	-- Lo normal es subirlos dentro del pack de contenido del Workshop.
	ix.config.Add("eftIconsFastDL", false, "Enviar los iconos de objetos EFT por descarga directa (FastDL).", nil, {
		category = "EFG"
	})

	function PLUGIN:InitializedConfig()
		if (!ix.config.Get("eftIconsFastDL", false)) then
			return
		end

		local files = file.Find("materials/eftwiki/icons/*.png", "GAME")

		for _, name in ipairs(files or {}) do
			resource.AddFile("materials/eftwiki/icons/" .. name)
		end
	end
end
