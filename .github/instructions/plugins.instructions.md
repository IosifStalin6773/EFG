---
applyTo: "plugins/**/*.lua"
---

## Plugins — Metro RP 2033

Estos archivos pertenecen a plugins del schema Helix. Convenciones específicas:

- Usar `PLUGIN:NombreHook(...)` para hooks del framework (no `Schema:`).
- El punto de entrada de cada plugin es `sh_plugin.lua` con `PLUGIN.author = "Metro RP By Cono y Manperra"`.
- Incluir sub-archivos con `ix.util.Include("cl_plugin.lua")` y `ix.util.Include("sv_plugin.lua")`.
- **Net strings** deben declararse con `util.AddNetworkString("Nombre")` en `sv_plugin.lua` antes de usarlas.
- **Timers por jugador**: siempre limpiarlos en `PLUGIN:PlayerDisconnected(client)`.
- No hardcodear strings visibles al jugador; usar `client:NotifyLocalized("clave")`.
- Registrar variables de personaje con `ix.char.RegisterVar` en `sh_plugin.lua`.
- La lógica exclusiva de servidor va en `sv_plugin.lua`; la de cliente en `cl_plugin.lua`.

### Estructura mínima de sh_plugin.lua
```lua
PLUGIN.name = "Nombre"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Descripción."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
```

### Hook del framework vs hook de GMod
```lua
-- Framework Helix (en PLUGIN)
function PLUGIN:CharacterLoaded(character) end

-- GMod nativo (con hook.Add)
hook.Add("PlayerSpawn", "MiPlugin_Spawn", function(client) end)
```
