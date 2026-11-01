---
mode: agent
description: Crea un nuevo ítem para el schema EFG (Escape from Gmod).
---

Crea un nuevo ítem para el schema EFG (Escape from Gmod) siguiendo estrictamente las convenciones del proyecto.

## Qué necesito saber

Si no me has dado la información, pregúntame:
1. **Nombre** del ítem (en español)
2. **Descripción** breve (en español, flavor text del lore Metro 2033)
3. **Categoría** en el inventario (ej: `"Consumibles"`, `"Armas"`, `"Equipamiento"`, `"Medicamentos"`, `"Recursos"`)
4. **Modelo 3D** (ruta `models/...`) — si no tienes una, usa `models/props_junk/popcan01a.mdl` como placeholder
5. **Tamaño** en la cuadrícula del inventario (`width` × `height`, normalmente 1×1 o 2×1)
6. ¿Es **comprable en tiendas**? Si sí, ¿cuánto cuesta en Rublos?
7. ¿Tiene **restricción de facción/clase/flag** para comprarlo?
8. ¿Qué hace al **usarlo** (función `OnRun`)?
9. ¿Es **equipable** (armor, gasmask, etc.) o simplemente consumible?
10. ¿Tiene **acciones adicionales** además de "Usar"?

## Archivo a generar

Crea el archivo en `schema/items/sh_<nombre_interno>.lua`:

```lua
ITEM.name = "Nombre"
ITEM.model = Model("models/...")
ITEM.description = "Descripción del ítem ambientada en Metro 2033."
ITEM.category = "Consumibles"
ITEM.width = 1
ITEM.height = 1

-- Si NO se puede comprar en tiendas:
ITEM.noBusiness = true

-- Si SÍ se puede comprar (quitar noBusiness):
-- ITEM.price = 5
-- ITEM.factions = {FACTION_X}    -- solo si hay restricción de facción
-- ITEM.classes = {CLASS_X}       -- solo si hay restricción de clase
-- ITEM.flag = "z"                -- solo si hay restricción de flag

-- Acción principal
ITEM.functions.Usar = {
    OnRun = function(item)
        local client = item.player

        -- lógica aquí
        -- Ejemplo restaurar vida:
        -- client:SetHealth(math.min(client:Health() + 20, client:GetMaxHealth()))

        return true  -- true elimina el ítem; false lo conserva
    end
}

-- Acción extra opcional
-- ITEM.functions.Inspeccionar = {
--     OnRun = function(item)
--         item.player:ChatPrint("...")
--         return false
--     end
-- }
```

## Reglas obligatorias

- Nombre de archivo: `sh_<nombre_interno>.lua` (minúsculas, sin espacios, sin acentos).
- Dentro de callbacks usar siempre `item` (instancia), **nunca** `ITEM` (plantilla global).
- `return true` en `OnRun` elimina el ítem del inventario; `return false` lo conserva.
- Usar **tabulaciones** para indentar.
- Mantener las descripciones en **español** y con tono acorde al lore de Metro 2033.
- Si el ítem afecta estadísticas vitales (vida, hambre, etc.) respetar los límites con `math.min`/`math.max`.

## Después de generar

Recuérdame:
- Reemplazar el modelo placeholder por uno real si lo usé.
- Si el ítem se llama desde `OnCharacterCreated` de una facción, verificar que el nombre interno coincide.
- Añadir cadenas de idioma en `schema/languages/sh_english.lua` si se usan claves `L()`.
