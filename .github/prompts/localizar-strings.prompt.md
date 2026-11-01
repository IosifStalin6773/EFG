---
mode: agent
description: Añade o edita strings de idioma en el schema EFG (Escape from Gmod).
---

Gestiona las cadenas de localización del schema EFG (Escape from Gmod). El sistema de idiomas usa el archivo `schema/languages/sh_english.lua` como base.

## Cómo funciona el sistema de idiomas en Helix

```lua
-- Definición en schema/languages/sh_english.lua
LANGUAGE = {
    clave = "Texto en el idioma."
    claveConParam = "Hola, %s! Tienes %d rublos."
}

-- Uso en código
L("clave")                          -- devuelve el string
L("claveConParam", nombre, cantidad) -- con parámetros
client:NotifyLocalized("clave")     -- notificación al jugador
```

## Cuándo añadir cadenas

Añade siempre una clave de idioma cuando el código muestre texto al jugador:
- Notificaciones (`client:NotifyLocalized`)
- Comandos (`description = "@clave"`)
- UI/HUD con texto
- Mensajes de chat

## Qué necesito que hagas

1. **Si me pides añadir nuevas cadenas**: genera las entradas para `sh_english.lua` con claves descriptivas en camelCase.
2. **Si hay strings hardcodeadas**: identifícalas y refactoriza el código para usar `L()`.
3. **Si hay conflictos de claves**: avisa y propón nombres alternativos.

## Convenciones de nombres de claves

| Contexto            | Prefijo    | Ejemplo                      |
|---------------------|------------|------------------------------|
| Comandos            | `cmd`      | `cmdCharSetRank`             |
| Notificaciones gen. | (ninguno)  | `serverWelcome`              |
| Errores             | `error`    | `errorNoPermission`          |
| Notif. de plugin    | nombre     | `characterRaiseAdmin`        |

## Estructura del archivo

```lua
-- schema/languages/sh_english.lua

LANGUAGE = {
    -- Generales
    serverWelcome = "Welcome to the server, %s!",

    -- Plugin: Ranks
    cmdCharSetRank = "Sets the rank of a character.",
    cmdCharRaise   = "Raises the rank of a character.",
    undefinedRank  = "That rank does not exist.",
    cannotAllowRaise = "You cannot raise this character's rank.",
    -- ...
}
```

## Reglas

- Usar **camelCase** para las claves.
- El texto en inglés como base; si el juego se juega en español, añadir `sh_spanish.lua` con las traducciones.
- Los parámetros usan formato `%s` (string) o `%d` (número).
- No duplicar claves ya existentes.

Dime qué cadenas necesitas añadir o qué código quieres que localice:
