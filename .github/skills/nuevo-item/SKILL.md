---
name: nuevo-item
description: >
  Crea un nuevo ítem para el inventario de EFG (Escape from Gmod) (archivo sh_*.lua en schema/items/).
  Úsame cuando el usuario pida crear o añadir un nuevo ítem al schema.
---

## Objetivo
Crear un archivo `schema/items/sh_<nombre>.lua` completo y funcional.

## Proceso

1. **Recopila los datos necesarios** (pregunta si no se han proporcionado):
   - Nombre del ítem (en español)
   - Descripción flavor text (en español, tono de EFG)
   - Categoría: `"Consumibles"`, `"Armas"`, `"Equipamiento"`, `"Medicamentos"`, `"Recursos"`, etc.
   - Modelo 3D (ruta `models/...`)
   - Tamaño en inventario: `width` × `height`
   - ¿Comprable en tiendas? Si sí → precio en Rublos
   - ¿Restricción de facción, clase o flag?
   - ¿Qué hace al usarlo?
   - ¿Tiene acciones adicionales?

2. **Lee** `schema/items/sh_soda.lua` como referencia de estilo antes de generar.

3. **Genera** el archivo:

```lua
ITEM.name = "Nombre"
ITEM.model = Model("models/...")
ITEM.description = "Descripción en español con tono de EFG."
ITEM.category = "Consumibles"
ITEM.width = 1
ITEM.height = 1

-- Elegir UNO:
ITEM.noBusiness = true           -- No aparece en tiendas
-- ITEM.price = 5                -- Aparece en tiendas a este precio en Rublos
-- ITEM.factions = {FACTION_X}  -- Solo esta facción puede comprarlo
-- ITEM.classes  = {CLASS_X}    -- Solo esta clase puede comprarlo
-- ITEM.flag = "z"              -- Solo personajes con este flag

ITEM.functions.Usar = {
	OnRun = function(item)
		local client = item.player
		-- lógica
		return true  -- true = elimina el ítem; false = lo conserva
	end
}
```

## Reglas de generación

- Nombre de archivo: `sh_<nombre_interno>.lua` (minúsculas, sin espacios, sin acentos)
- Dentro de cualquier callback usar siempre `item` (instancia), **nunca** `ITEM`
- `return true` elimina el ítem del inventario; `return false` lo conserva
- Si afecta vida: `client:SetHealth(math.min(client:Health() + X, client:GetMaxHealth()))`
- Indentación con **tabulaciones**
- No añadir comentarios para campos estándar como `width`, `height`
- Si el modelo es placeholder, añadir `-- TODO: reemplazar modelo`

## Aviso post-generación

Al terminar, recordar al usuario:
- Helix auto-incluye `schema/items/` — no hace falta include manual
- Reemplazar modelo placeholder si es necesario
- Si el ítem se añade en `OnCharacterCreated`, verificar que el nombre interno coincide exactamente
