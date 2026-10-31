local PLUGIN = PLUGIN

PLUGIN.name = "EFG UI"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Kit visual Pizarra de EFG: paleta, fuente Bender (MBender, la de EFT), texturas propias (content/materials/efgui) y componentes Derma."

-- Colores y fuentes por defecto de Helix: todo lo que use ix.config.Get("color")
-- o las fuentes genéricas de Helix pasa a la identidad Pizarra.
ix.config.SetDefault("color", Color(227, 114, 45))
ix.config.SetDefault("font", "MBender")
ix.config.SetDefault("genericFont", "MBender")

ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_panels.lua")
ix.util.Include("cl_css.lua")
ix.util.Include("cl_escape.lua")

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

	-- Content_Test_Metro_P2: sonidos y modelos de STALKER 2 (comida y mochila)
	resource.AddWorkshop("3744199003")

	-- Pantalla de carga propia (content/html/efg_loading.html, sale del contenido
	-- montado del gamemode). GMod solo la usa con más de 1 jugador; en un jugador
	-- el fondo es la miniatura del mapa (content/maps/thumb).
	if (GetConVarString("sv_loadingurl") == "") then
		RunConsoleCommand("sv_loadingurl", "asset://garrysmod/html/efg_loading.html")
	end
end
