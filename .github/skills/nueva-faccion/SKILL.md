---
name: nueva-faccion
description: >
  Crea una nueva facción completa para Metro RP 2033 (archivo sh_*.lua en schema/factions/).
  Úsame cuando el usuario pida crear o añadir una nueva facción al schema.
---

## Objetivo
Crear un archivo `schema/factions/sh_<nombre>.lua` completo y funcional siguiendo las convenciones de Metro RP 2033.

## Proceso

1. **Recopila los datos necesarios** (pregunta si no se han proporcionado):
   - Nombre en español
   - Descripción del lore (2-3 frases)
   - Color RGB representativo
   - Salario en Balas por intervalo (`pay`, 0 si no cobra)
   - Lista de modelos `.mdl`
   - `isDefault` (¿es la facción inicial al crear personaje?)
   - `isGloballyRecognized` (¿su nombre es visible para todos?)
   - Ítems iniciales al crear personaje
   - ¿Tiene clases internas?
   - ¿Tiene tabla de rangos (`Ranks`) para el plugin `ranks`?

2. **Lee** `schema/factions/sh_civil.lua` como referencia de estilo antes de generar.

3. **Genera** el archivo con esta estructura:

```lua
FACTION.name = "Nombre"
FACTION.description = "Descripción en español."
FACTION.color = Color(r, g, b)
FACTION.pay = 0

FACTION.models = {
	"models/...",
}

FACTION.weapons = {"ohandsswep"}
FACTION.isDefault = false
FACTION.isGloballyRecognized = false

-- Ranks (solo si aplica)
FACTION.Ranks = {
	[1] = {"Nombre Rango", nil, nil},
}

FACTION_NOMBRECORTO = FACTION.index

-- OnCharacterCreated (solo si tiene ítems iniciales)
function FACTION:OnCharacterCreated(client, character)
	local inventory = character:GetInventory()
	inventory:Add("nombre_item", cantidad)
end

-- OnRankChanged (solo si tiene ranks con lógica)
function FACTION:OnRankChanged(client, oldValue, value)
	-- lógica
end
```

## Reglas de generación

- Nombre de archivo: `sh_<nombre_corto>.lua` (minúsculas, sin espacios, sin acentos)
- `FACTION_X` **siempre al final** del archivo, antes de los callbacks
- Indentación con **tabulaciones**
- Strings entre comillas dobles
- `if (condicion) then` con paréntesis
- No añadir comentarios obvios sobre campos estándar
- Si usa modelos placeholder, indicarlo con un comentario `-- TODO: reemplazar modelo`

## Aviso post-generación

Al terminar, recordar al usuario:
- Helix auto-incluye `schema/factions/` — no hace falta añadir includes manuales
- Reemplazar modelos placeholder si los hay
- Si la facción tiene rangos, verificar que los índices de clase (`CLASS_X`) existen
