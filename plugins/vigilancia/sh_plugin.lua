-- ============================================================
--  vigilancia  |  sh_plugin.lua  (SHARED)
--  Marca personajes como "vigilados" (flag persistente en BD,
--  invisible para el jugador) y registra sus movimientos de
--  inventario y economía para revisión desde un panel de admin.
-- ============================================================

PLUGIN.name        = "Vigilancia"
PLUGIN.author      = "Metro RP By Cono y Manperra"
PLUGIN.description = "Permite a los administradores marcar personajes como vigilados y revisar sus inventarios y sus movimientos de ítems y balas desde un panel."

ix.vigilancia = ix.vigilancia or {}

-- Cuántas entradas de log se conservan por personaje (las más antiguas se descartan)
ix.vigilancia.maxLog = 500

-- ── Variable de personaje: flag de vigilancia ────────────────────────────────
-- bNoNetworking  → nunca se envía al cliente: el jugador vigilado NO puede saberlo.
--                  Además hace que Set<Var> solo escriba en el servidor.
-- bNoDisplay     → no aparece en la creación/edición de personaje (no editable por el cliente).
-- NOTA: no usar bNotModifiable — en Helix eso impide generar el setter SetVigilado.
ix.char.RegisterVar("vigilado", {
	field         = "vigilado",
	fieldType     = ix.type.bool,
	default       = false,
	bNoDisplay    = true,
	bNoNetworking = true
})

-- Stubs de cliente para el autocompletado del comando en el chat
if (CLIENT) then
	ix.command.Add("Vigilancia", {
		adminOnly   = true,
		description = "Abre el panel de vigilancia de personajes.",
		OnRun = function(self, client) end
	})

	ix.command.Add("Vigilar", {
		adminOnly   = true,
		description = "Activa o desactiva en silencio la vigilancia del jugador indicado.",
		arguments   = ix.type.player,
		OnRun = function(self, client, target) end
	})
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
