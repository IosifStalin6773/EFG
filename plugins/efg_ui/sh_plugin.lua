local PLUGIN = PLUGIN

PLUGIN.name = "EFG UI"
PLUGIN.author = "EFG"
PLUGIN.description = "Kit visual de EFG al estilo Escape from Tarkov: paleta, fuente Bender, texturas propias (content/materials/efgui) y utilidades de dibujo."

-- Colores y fuentes de Helix por defecto: todo lo que use ix.config.Get("color")
-- o las fuentes genéricas de Helix pasa a verse como EFT.
ix.config.SetDefault("color", Color(154, 136, 102))
ix.config.SetDefault("font", "Bender")
ix.config.SetDefault("genericFont", "Bender")

ix.util.Include("cl_plugin.lua")

if (SERVER) then
	-- Envía a los clientes todo lo que hay en content/ del gamemode (texturas
	-- efgui y la fuente Bender). Se recorre la carpeta para no tener que
	-- mantener una lista a mano cuando se añadan texturas.
	local function addDir(dir)
		local files, dirs = file.Find(dir .. "/*", "GAME")

		for _, name in ipairs(files or {}) do
			local ext = string.GetExtensionFromFilename(name)

			if (ext == "png" or ext == "jpg" or ext == "vmt" or ext == "vtf") then
				resource.AddFile(dir .. "/" .. name)
			end
		end

		for _, name in ipairs(dirs or {}) do
			addDir(dir .. "/" .. name)
		end
	end

	addDir("materials/efgui")
	resource.AddFile("resource/fonts/bender.ttf")
end
