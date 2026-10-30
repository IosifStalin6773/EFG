---
mode: agent
description: Crea un nuevo plugin para el schema Metro RP 2033.
---

Crea un nuevo plugin autocontenido para Metro RP 2033 siguiendo las convenciones del framework Helix.

## Qué necesito saber

Si no me lo has indicado, pregúntame:
1. **Nombre** del plugin (en inglés, estilo título)
2. **Descripción** de qué hace el plugin
3. ¿Tiene lógica de **cliente** (`cl_plugin.lua`)?
4. ¿Tiene lógica de **servidor** (`sv_plugin.lua`)?
5. ¿Registra **comandos de chat** (`ix.command.Add`)?
6. ¿Registra **variables de personaje** (`ix.char.RegisterVar`)?
7. ¿Añade **hooks** del schema o de GMod?
8. ¿Necesita **cadenas de idioma** propias?
9. ¿Depende de otros plugins o facciones existentes?

## Estructura de archivos a generar

Carpeta: `plugins/<nombre_carpeta>/`

### `sh_plugin.lua` (obligatorio)
```lua
PLUGIN.name = "Nombre del Plugin"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Descripción del plugin."

-- Incluir sub-archivos si existen
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

-- Variables de personaje (si las hay)
ix.char.RegisterVar("miVar", {
    field = "mi_var",
    fieldType = ix.type.number,
    default = 0
})

-- Comandos compartidos (si los hay)
ix.command.Add("MiComando", {
    arguments = { ix.type.player },
    description = "@cmdMiComando",
    OnRun = function(self, client, target)
        -- lógica
    end
})
```

### `cl_plugin.lua` (si tiene lógica cliente)
```lua
-- Hooks de cliente, HUD, paneles, etc.
function PLUGIN:HUDPaint()
    -- ...
end
```

### `sv_plugin.lua` (si tiene lógica servidor)
```lua
-- Hooks de servidor, timers, acceso a DB, etc.
function PLUGIN:PlayerSpawn(client)
    -- ...
end
```

### `languages/sh_english.lua` (si tiene cadenas propias)
```lua
LANGUAGE = {
    cmdMiComando = "Descripción del comando."
}
```

## Patrones comunes

### Timer periódico
```lua
-- En sv_plugin.lua dentro de un hook o directamente
timer.Create("MiPlugin_Timer", 30, 0, function()
    for _, client in ipairs(player.GetAll()) do
        if (IsValid(client) and client:GetCharacter()) then
            -- lógica por jugador
        end
    end
end)
```

### Netmessage cliente ↔ servidor
```lua
-- sv_plugin.lua — enviar al cliente
net.Start("MiPlugin_Evento")
    net.WriteString("datos")
net.Send(client)

-- cl_plugin.lua — recibir
net.Receive("MiPlugin_Evento", function()
    local datos = net.ReadString()
end)
```

### Hook del schema
```lua
function PLUGIN:CharacterLoaded(character)
    -- Se llama cuando un personaje termina de cargar
end
```

## Reglas obligatorias

- Nombre de carpeta: `plugins/<nombre_en_minusculas_con_guiones_bajos>/`
- Usar `PLUGIN:` para hooks del framework (no `Schema:`).
- Usar **tabulaciones** para indentar.
- Registrar **net strings** en `sh_plugin.lua` con `util.AddNetworkString("Nombre")` (lado servidor únicamente).
- Si el plugin usa `timer.Create`, asegurarse de que el timer se elimina en `PLUGIN:PlayerDisconnected` si es por jugador.
- Mantener la lógica del cliente separada de la del servidor.
- No hardcodear strings visibles al jugador; usar `L()` o `client:NotifyLocalized()`.

## Después de generar

Recuérdame:
- Helix auto-incluye la carpeta `plugins/` — no hace falta añadir includes manuales en `sh_schema.lua`.
- Si el plugin añade net strings, deben declararse con `util.AddNetworkString` antes de usarlas.
- Verificar que el nombre del plugin no colisiona con plugins existentes en `plugins/`.
