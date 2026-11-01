---
mode: agent
description: Crea una nueva facción completa para el schema EFG (Escape from Gmod).
---

Crea una nueva facción para el schema EFG (Escape from Gmod) siguiendo estrictamente las convenciones del proyecto.

## Qué necesito saber

Antes de generar el archivo pregúntame (si no te lo he indicado):
1. **Nombre** de la facción (en español, como aparece en el juego)
2. **Descripción** del lore de la facción (breve, en español)
3. **Color** representativo (RGB o nombre de color)
4. **Salario** por intervalo en Rublos (por defecto 0 si es civil/sin sueldo)
5. **Modelos** de personaje (puedo proporcionar una lista o usar los genéricos)
6. ¿Es la **facción por defecto** al crear personaje? (`isDefault`)
7. ¿Es **globalmente reconocida** (nombre visible para todos)? (`isGloballyRecognized`)
8. ¿Tiene **ítems iniciales** al crear personaje?
9. ¿Tiene **clases** internas (rangos con CLASS)?
10. ¿Tiene tabla de **Ranks** para el plugin `ranks`?

## Archivo a generar

Crea el archivo en `schema/factions/sh_<nombre_corto>.lua` con esta estructura:

```lua
FACTION.name = "Nombre"
FACTION.description = "Descripción."
FACTION.color = Color(r, g, b)
FACTION.pay = 0

FACTION.models = {
    -- lista de modelos
}

FACTION.isDefault = false
FACTION.isGloballyRecognized = false

-- Si tiene ranks:
FACTION.Ranks = {
    [1] = {"Nombre Rango", nil, nil},
}

FACTION_NOMBRECORTO = FACTION.index

-- Solo si tiene ítems iniciales:
function FACTION:OnCharacterCreated(client, character)
    local inventory = character:GetInventory()
    inventory:Add("nombre_item", cantidad)
end

-- Solo si tiene callback de cambio de rango:
function FACTION:OnRankChanged(client, oldValue, value)
    -- lógica
end
```

## Reglas obligatorias

- El nombre del archivo debe ser `sh_<nombre_corto>.lua` (minúsculas, sin espacios).
- La constante `FACTION_X` debe asignarse **al final** del archivo.
- Usar **tabulaciones** para indentar, nunca espacios.
- Las **cadenas** van entre comillas dobles.
- Incluir paréntesis en las condiciones: `if (condicion) then`.
- Dentro de `OnCharacterCreated` usar `character:GetInventory()`, no acceder directamente a `ITEM`.
- Si se definen clases (`CLASS`), hacerlo en el **mismo archivo** o en un archivo `sh_<faccion>_clases.lua` separado e incluirlo en `sh_schema.lua`.
- Añadir la constante `FACTION_X` a la tabla de referencia en `copilot-instructions.md` si procede.

## Después de generar

Recuérdame que debo:
- Añadir los modelos reales si usé placeholders.
- Incluir el archivo en `sh_schema.lua` si no está en la carpeta `factions/` (Helix auto-incluye esta carpeta).
- Añadir cadenas de lenguaje en `schema/languages/sh_english.lua` si el código usa `L()`.
