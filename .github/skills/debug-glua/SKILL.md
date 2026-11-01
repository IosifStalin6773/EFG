---
name: debug-glua
description: >
  Diagnostica y corrige errores de Lua/GLua en el schema EFG (Escape from Gmod).
  Úsame cuando el usuario pegue un error de consola de Garry's Mod o reporte un bug.
---

## Objetivo
Identificar la causa raíz de un error de GLua en EFG (Escape from Gmod) y proporcionar la corrección exacta.

## Proceso

1. **Solicitar** (si no se ha proporcionado):
   - Mensaje de error completo de la consola del servidor
   - Fragmento de código del archivo y línea indicados
   - Cuándo ocurre el error (al cargar, al usar ítem, al spawnar, etc.)

2. **Analizar** el stack trace:
   - Identificar archivo y línea exacta
   - Buscar el archivo en el proyecto con la herramienta `read`
   - Entender el contexto completo del error

3. **Diagnosticar** la causa usando la guía de errores frecuentes:

### Errores frecuentes en Helix / GLua

#### `attempt to index a nil value`
Acceso a método en objeto que no existe todavía.
```lua
-- ❌
client:GetCharacter():GetName()

-- ✅
local character = client:GetCharacter()
if (character) then
    local name = character:GetName()
end
```

#### `attempt to call a nil value`
Función que no existe en el contexto actual o en la versión de Helix.
- Verificar que la función existe en la API de Helix
- Verificar que no es una función solo de servidor ejecutada en cliente

#### Confusión `ITEM` vs `item`
```lua
-- ❌ Dentro de OnRun
ITEM.player:SetHealth(100)

-- ✅
item.player:SetHealth(100)
```

#### Net string no declarada
```lua
-- Error: "Trying to use a non-existent net message"
-- ✅ En sv_plugin.lua / sv_schema.lua
util.AddNetworkString("NombreEvento")
```

#### Hook en contexto equivocado
- Funciones como `net.Send`, `Entity:SetNWInt`, son de servidor
- Funciones como `draw.RoundedBox`, `surface.DrawText` son de cliente
- Un hook en `cl_*.lua` que usa `net.Send` → mover a `sv_*.lua`

#### `table.contains` no existe en GLua
```lua
-- ❌
if (table.contains(lista, valor)) then

-- ✅
if (table.HasValue(lista, valor)) then
```

#### Timer no limpiado
```lua
-- Si el error ocurre en un timer después de que el jugador se fue:
-- ✅ Verificar validez dentro del timer
timer.Create("MiTimer", 5, 0, function()
    if (!IsValid(client)) then
        timer.Remove("MiTimer")
        return
    end
end)
```

4. **Proporcionar** la corrección con el bloque de código completo corregido.

5. **Indicar** si hay efectos secundarios en otros archivos.

## Formato de respuesta

```
📍 Causa: descripción breve de qué falla y por qué
📄 Archivo: ruta/al/archivo.lua — línea N

❌ Código actual:
[fragmento problemático]

✅ Código corregido:
[fragmento corregido]

⚠️ Efectos secundarios: [ninguno / descripción]
```
