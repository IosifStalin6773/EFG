local PLUGIN = PLUGIN

PLUGIN.name = "EFG UI"
PLUGIN.author = "EFG"
PLUGIN.description = "Kit visual Pizarra de EFG: paleta, fuentes EFGX (OFL), texturas propias (content/materials/efgui) y componentes Derma."

-- Colores y fuentes por defecto de Helix: todo lo que use ix.config.Get("color")
-- o las fuentes genéricas de Helix pasa a la identidad Pizarra.
ix.config.SetDefault("color", Color(232, 131, 58))
ix.config.SetDefault("font", "EFGX Header")
ix.config.SetDefault("genericFont", "EFGX Body")

ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_panels.lua")

if (SERVER) then
	-- Envía a los clientes todo lo que hay en content/ del gamemode (texturas
	-- efgui y las fuentes EFGX). Se recorre la carpeta para no tener que
	-- mantener una lista a mano cuando se añadan texturas.
	local function addDir(dir, exts)
		local files, dirs = file.Find(dir .. "/*", "GAME")

		for _, name in ipairs(files or {}) do
			if (exts[string.GetExtensionFromFilename(name)]) then
				resource.AddFile(dir .. "/" .. name)
			end
		end

		for _, name in ipairs(dirs or {}) do
			addDir(dir .. "/" .. name, exts)
		end
	end

	addDir("materials/efgui", {png = true, jpg = true, vmt = true, vtf = true})
	addDir("materials/efg", {png = true, jpg = true, vmt = true, vtf = true})
	addDir("resource/fonts", {ttf = true, otf = true})
	addDir("sound/efg", {wav = true, mp3 = true, ogg = true})

	-- Content_Test_Metro_P2: sonidos y modelo de la mochila (ANIM_INV)
	resource.AddWorkshop("3744199003")
end
