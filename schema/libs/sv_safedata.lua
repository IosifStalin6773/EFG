
-- Sobreescribe ix.data.Set y ix.data.Get para proteger TODOS los plugins
-- contra corrupción de datos cuando el servidor se cierra o crashea.
--
-- Estrategia:
--   1) Antes de escribir, guarda una copia .bak del archivo existente.
--   2) Escribe en un archivo .tmp.txt temporal.
--   3) Valida que el temporal contenga JSON válido.
--   4) Solo entonces reemplaza el archivo final.
--   5) Al leer, si el archivo principal está corrupto, intenta el .bak.

local MAX_BACKUPS = 2

local function GetPath(key, bGlobal, bIgnoreMap)
	return "helix/" .. (bGlobal and "" or Schema.folder .. "/") .. (bIgnoreMap and "" or game.GetMap() .. "/")
end

local function EnsureDirs(path, bGlobal)
	if (!bGlobal) then
		file.CreateDir("helix/" .. Schema.folder .. "/")
	end

	file.CreateDir(path)
end

local function ValidateJSON(raw)
	if (!raw or raw == "") then return false end

	local ok, decoded = pcall(util.JSONToTable, raw)
	return ok and decoded and decoded[1] != nil
end

-- Rotación de backups: .bak1 (más reciente), .bak2 (anterior)
local function RotateBackups(path, finalFile)
	if (!file.Exists(finalFile, "DATA")) then return end

	local raw = file.Read(finalFile, "DATA")
	if (!ValidateJSON(raw)) then return end

	for i = MAX_BACKUPS, 2, -1 do
		local older = path .. ".bak" .. (i - 1)
		local newer = path .. ".bak" .. i
		if (file.Exists(older, "DATA")) then
			file.Write(newer, file.Read(older, "DATA"))
		end
	end

	file.Write(path .. ".bak1", raw)
end

function ix.data.Set(key, value, bGlobal, bIgnoreMap)
	local path = GetPath(key, bGlobal, bIgnoreMap)
	EnsureDirs(path, bGlobal)

	local finalFile = path .. key .. ".txt"
	local tempFile = path .. key .. ".tmp.txt"

	local json = util.TableToJSON({value})

	-- Durante shutdown, no sobreescribir datos existentes con datos
	-- significativamente más pequeños (entidades ya destruidas = datos vacíos)
	if (ix.shuttingDown and file.Exists(finalFile, "DATA")) then
		local oldRaw = file.Read(finalFile, "DATA")
		if (oldRaw and #oldRaw > 64 and #json < #oldRaw * 0.5) then
			ErrorNoHalt("[EFG SafeData] Bloqueada escritura de '" .. key .. "' durante shutdown: datos nuevos (" .. #json .. "B) mucho menores que existentes (" .. #oldRaw .. "B).\n")
			return false
		end
	end

	RotateBackups(path .. key, finalFile)

	file.Write(tempFile, json)

	local written = file.Read(tempFile, "DATA")
	if (!ValidateJSON(written)) then
		ErrorNoHalt("[EFG SafeData] Fallo al guardar '" .. key .. "': el archivo temporal no es JSON válido. Se mantiene el anterior.\n")
		file.Delete(tempFile)
		return false
	end

	if (file.Exists(finalFile, "DATA")) then
		file.Delete(finalFile)
	end

	file.Rename(tempFile, finalFile)

	ix.data.stored[key] = value

	return path
end

ix.data.SetSafe = ix.data.Set

function ix.data.Get(key, default, bGlobal, bIgnoreMap, bRefresh)
	if (!bRefresh) then
		local stored = ix.data.stored[key]

		if (stored != nil) then
			return stored
		end
	end

	local path = GetPath(key, bGlobal, bIgnoreMap)
	local finalFile = path .. key .. ".txt"
	local contents = file.Read(finalFile, "DATA")

	if (contents and contents != "") then
		local status, decoded = pcall(util.JSONToTable, contents)

		if (status and decoded) then
			local val = decoded[1]

			if (val != nil) then
				return val
			end
		end

		-- Compatibilidad con formato antiguo (pon)
		status, decoded = pcall(pon.decode, contents)

		if (status and decoded) then
			local val = decoded[1]

			if (val != nil) then
				return val
			end
		end
	end

	-- El archivo principal está corrupto o vacío — intentar backups
	for i = 1, MAX_BACKUPS do
		local bakFile = path .. key .. ".bak" .. i
		local bakContents = file.Read(bakFile, "DATA")

		if (bakContents and bakContents != "") then
			local ok, decoded = pcall(util.JSONToTable, bakContents)

			if (ok and decoded and decoded[1] != nil) then
				ErrorNoHalt("[EFG SafeData] '" .. key .. "' corrupto — restaurado desde .bak" .. i .. "\n")

				file.Write(finalFile, bakContents)
				ix.data.stored[key] = decoded[1]

				return decoded[1]
			end
		end
	end

	return default
end

