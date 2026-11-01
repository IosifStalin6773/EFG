-- Paso de la carpeta antigua del gamemode a "escapefromgmod". Helix guarda los
-- personajes con el nombre de la carpeta (columna schema) y los datos en
-- data/helix/<carpeta>/, así que sin esto se perderían al cambiar de nombre.
local OLD_FOLDER = "metrorp"

local function CopyDir(from, to)
	local files, dirs = file.Find(from .. "/*", "DATA")

	file.CreateDir(to)

	for _, name in ipairs(files or {}) do
		if (!file.Exists(to .. "/" .. name, "DATA")) then
			file.Write(to .. "/" .. name, file.Read(from .. "/" .. name, "DATA") or "")
		end
	end

	for _, name in ipairs(dirs or {}) do
		CopyDir(from .. "/" .. name, to .. "/" .. name)
	end
end

if (Schema.folder != OLD_FOLDER and file.IsDir("helix/" .. OLD_FOLDER, "DATA")
	and !file.Exists("helix/" .. Schema.folder .. "/.migrado.txt", "DATA")) then
	CopyDir("helix/" .. OLD_FOLDER, "helix/" .. Schema.folder)
	file.Write("helix/" .. Schema.folder .. "/.migrado.txt", os.date("%Y-%m-%d %H:%M:%S"))
	MsgC(Color(120, 200, 120), "[EFG] Datos de helix/" .. OLD_FOLDER .. " copiados a helix/" .. Schema.folder .. "\n")
end

-- Plugins que cambiaron de carpeta: sus datos (helix/<carpeta>/<mapa>/plugins/<id>.txt)
-- se copian con el nombre nuevo si aún no existe.
local PLUGIN_RENAMES = {
	metrocrafting = "mesa_crafteo",
	metrobags = "mochilas",
	metroui = "menu_ui"
}

local root = "helix/" .. Schema.folder
local _, maps = file.Find(root .. "/*", "DATA")

for _, map in ipairs(maps or {}) do
	for old, new in pairs(PLUGIN_RENAMES) do
		local from = root .. "/" .. map .. "/plugins/" .. old .. ".txt"
		local to = root .. "/" .. map .. "/plugins/" .. new .. ".txt"

		if (file.Exists(from, "DATA") and !file.Exists(to, "DATA")) then
			file.Write(to, file.Read(from, "DATA") or "")
		end
	end
end

function Schema:DatabaseConnected()
	if (Schema.folder == OLD_FOLDER) then
		return
	end

	local query = mysql:Update("ix_characters")
		query:Update("schema", Schema.folder)
		query:Where("schema", OLD_FOLDER)
	query:Execute()
end
