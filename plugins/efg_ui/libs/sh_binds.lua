-- Teclas del modo EFG, configurables desde AJUSTES > CONTROLES del TAB.
-- Cada acción se guarda como opción de Helix oculta ("efgBind_<id>", texto
-- "tecla" o "alt+tecla"), así que se conserva entre sesiones. Los plugins la
-- leen en tiempo de ejecución (efg_ui carga después de casi todos):
--   ix.efg.binds.Key(id)            código de tecla
--   ix.efg.binds.IsDown(id)         tecla (y modificador) pulsados ahora
--   ix.efg.binds.Matches(id, btn)   para PlayerButtonDown
ix.efg = ix.efg or {}
ix.efg.binds = ix.efg.binds or {}

local BINDS = ix.efg.binds

BINDS.groups = {"MOVIMIENTO", "COMBATE", "ACCESO RÁPIDO", "INTERFAZ"}

-- {id, nombre, grupo, tecla por defecto, modificador por defecto}
BINDS.list = {
	{"thirdperson", "Tercera persona", "MOVIMIENTO", KEY_CAPSLOCK},
	{"nightvision", "Visión nocturna", "MOVIMIENTO", KEY_N},
	{"weapon1", "Pistola", "COMBATE", KEY_1},
	{"weapon2", "Arma en bandolera", "COMBATE", KEY_2},
	{"weapon3", "Arma a la espalda", "COMBATE", KEY_3},
	{"magcheck", "Comprobar cargador", "COMBATE", KEY_T, "alt"},
	{"firemode", "Comprobar modo de disparo", "COMBATE", KEY_B, "alt"},
	{"quick1", "Acceso rápido 1", "ACCESO RÁPIDO", KEY_4},
	{"quick2", "Acceso rápido 2", "ACCESO RÁPIDO", KEY_5},
	{"quick3", "Acceso rápido 3", "ACCESO RÁPIDO", KEY_6},
	{"quick4", "Acceso rápido 4", "ACCESO RÁPIDO", KEY_7},
	{"quick5", "Acceso rápido 5", "ACCESO RÁPIDO", KEY_8},
	{"inventory", "Inventario", "INTERFAZ", KEY_TAB},
	{"radial", "Menú radial (mantener)", "INTERFAZ", KEY_Z},
	{"raidtime", "Tiempo y extracciones", "INTERFAZ", KEY_O},
	{"rotate", "Girar al arrastrar", "INTERFAZ", KEY_R},
}

BINDS.byID = {}

local MODS = {
	alt = {KEY_LALT, KEY_RALT},
	ctrl = {KEY_LCONTROL, KEY_RCONTROL},
	shift = {KEY_LSHIFT, KEY_RSHIFT},
}

BINDS.MODS = MODS

local function encode(key, mod)
	return (mod and (mod .. "+") or "") .. tostring(key or 0)
end

local function decode(value)
	value = tostring(value or "")

	local mod, key = value:match("^(%a+)%+(%d+)$")
	if (key) then return tonumber(key), MODS[mod] and mod or nil end

	return tonumber(value) or 0
end

for _, entry in ipairs(BINDS.list) do
	local id = entry[1]
	BINDS.byID[id] = entry

	ix.option.Add("efgBind_" .. id, ix.type.string, encode(entry[4], entry[5]), {
		category = "Controles",
		hidden = function() return true end
	})
end

-- tecla y modificador actuales de una acción
function BINDS.Get(id)
	local entry = BINDS.byID[id]
	if (!entry) then return 0 end

	if (CLIENT) then
		return decode(ix.option.Get("efgBind_" .. id, encode(entry[4], entry[5])))
	end

	return entry[4], entry[5]
end

function BINDS.Key(id)
	return (BINDS.Get(id))
end

function BINDS.ModDown(mod)
	if (!mod) then return true end

	for _, key in ipairs(MODS[mod] or {}) do
		if (input.IsKeyDown(key)) then return true end
	end

	return false
end

function BINDS.IsDown(id)
	local key, mod = BINDS.Get(id)
	return key > 0 and input.IsKeyDown(key) and BINDS.ModDown(mod)
end

function BINDS.Matches(id, button)
	local key, mod = BINDS.Get(id)
	return key > 0 and button == key and BINDS.ModDown(mod)
end

if (CLIENT) then
	function BINDS.Set(id, key, mod)
		if (!BINDS.byID[id]) then return end
		ix.option.Set("efgBind_" .. id, encode(key, mod))
	end

	function BINDS.Reset(id)
		local entry = BINDS.byID[id]
		if (entry) then BINDS.Set(id, entry[4], entry[5]) end
	end

	function BINDS.ResetAll()
		for _, entry in ipairs(BINDS.list) do BINDS.Reset(entry[1]) end
	end

	-- "ALT + T", "TAB", "SIN ASIGNAR"
	function BINDS.Name(id)
		local key, mod = BINDS.Get(id)
		if (key <= 0) then return "SIN ASIGNAR" end

		local name = string.upper(input.GetKeyName(key) or ("#" .. key))
		return mod and (string.upper(mod) .. " + " .. name) or name
	end

	-- otras acciones con la misma tecla y modificador
	function BINDS.Conflicts(id)
		local key, mod = BINDS.Get(id)
		local out = {}
		if (key <= 0) then return out end

		for _, entry in ipairs(BINDS.list) do
			if (entry[1] != id) then
				local k, m = BINDS.Get(entry[1])
				if (k == key and m == mod) then out[#out + 1] = entry[2] end
			end
		end

		return out
	end
end
