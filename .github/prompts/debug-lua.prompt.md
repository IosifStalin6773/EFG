---
mode: agent
description: Diagnostica y corrige errores de Lua en el schema EFG (Escape from Gmod) (Helix/GLua).
---

Eres un experto en GLua (Lua 5.1 de Garry's Mod) y en el framework Helix. Ayúdame a diagnosticar y corregir el error que te voy a mostrar.

## Contexto del proyecto

- **Framework**: Helix (`ix.*` API)
- **Gamemode base**: DarkRP-derivado → Helix
- **Lua**: GLua (Lua 5.1 con extensiones de Garry's Mod)
- **Carpeta del schema**: `schema/`
- **Carpeta de plugins**: `plugins/`

## Qué necesito que hagas

1. **Analiza el error** — identifica el archivo, línea y causa raíz.
2. **Explica por qué falla** en lenguaje sencillo.
3. **Proporciona la corrección** con el código corregido completo del bloque afectado.
4. **Indica si hay efectos secundarios** que deba revisar en otros archivos.

## Errores frecuentes en este proyecto y cómo resolverlos

### `attempt to index a nil value`
- Causa: llamar método en un objeto que aún no existe o que ya fue destruido.
- Verificar: `IsValid(entidad)`, `client:GetCharacter()` puede devolver `nil` si el personaje no ha cargado.
```lua
-- ❌ Mal
local name = client:GetCharacter():GetName()

-- ✅ Bien
local character = client:GetCharacter()
if (character) then
    local name = character:GetName()
end
```

### Confundir `ITEM` (plantilla) con `item` (instancia)
```lua
-- ❌ Mal — dentro de OnRun
ITEM.functions.Usar = {
    OnRun = function(item)
        ITEM.player:SetHealth(100)  -- ITEM es la plantilla global, no tiene .player
    end
}

-- ✅ Bien
ITEM.functions.Usar = {
    OnRun = function(item)
        item.player:SetHealth(100)
    end
}
```

### Hook en contexto equivocado (cliente vs servidor)
```lua
-- ❌ En cl_plugin.lua usando funciones solo de servidor
function PLUGIN:PlayerSpawn(client)
    client:GiveItem("pistol")  -- GiveItem no existe en cliente
end

-- ✅ Mover a sv_plugin.lua
```

### `util.AddNetworkString` no declarado
```lua
-- ❌ net.Start sin declarar la string
net.Start("MiEvento")  -- Error: Unknown net message

-- ✅ En sh_plugin.lua (o sv_plugin.lua, antes de usarlo)
util.AddNetworkString("MiEvento")
```

### Comparación incorrecta en GLua
```lua
-- ✅ GLua acepta tanto ~= como !=
if (value != nil) then end   -- válido en GLua
if (value ~= nil) then end   -- también válido
```

### Timer no limpiado al desconectarse
```lua
-- ❌ Timer por jugador que nunca se elimina
timer.Create("Plugin_" .. client:SteamID(), 5, 0, function() end)

-- ✅ Eliminar en desconexión
function PLUGIN:PlayerDisconnected(client)
    timer.Remove("Plugin_" .. client:SteamID())
end
```

## Información que me debes dar

Para diagnosticar correctamente, proporcióname:
- El **mensaje de error completo** de la consola del servidor
- El **fragmento de código** del archivo indicado en el error
- El **contexto**: ¿cuándo ocurre el error? (al cargar el mapa, al crear personaje, al usar un ítem, etc.)

Pega el error y el código a continuación:
