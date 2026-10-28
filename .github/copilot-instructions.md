# Metro RP 2033 — Instrucciones para GitHub Copilot

## Descripción del proyecto
**Metro RP 2033** es un schema de roleplay para Garry's Mod construido sobre el framework **[Helix](https://github.com/nebulouscloud/helix)**. El proyecto es mantenido por **Metro RP By Cono y Manperra** y ambienta a los jugadores en el universo de Metro 2033/2034 bajo el metro de Moscú.

- **Idioma del código**: Lua (GLua — variante de Lua 5.1 de Garry's Mod)
- **Idioma del contenido del juego**: Español (nombres de facciones, descripciones, mensajes)
- **Moneda del juego**: Balas (`ix.currency.singular = "Bala"`, `ix.currency.plural = "Balas"`)
- **Framework**: Helix (`ix.*` API)

---

## Estructura de carpetas

```
metrorp/
├── gamemode/          # Punto de entrada del gamemode (cl_init.lua, init.lua)
├── schema/            # Lógica principal del schema
│   ├── attributes/    # Atributos de personaje (sh_*.lua)
│   ├── factions/      # Definiciones de facciones (sh_*.lua)
│   ├── items/         # Definiciones de ítems (sh_*.lua)
│   ├── languages/     # Strings localizados (sh_english.lua, etc.)
│   ├── libs/          # Librerías propias del schema (auto-incluidas)
│   ├── meta/          # Extensiones de meta-tablas (personaje, jugador)
│   ├── cl_schema.lua  # Lógica cliente
│   ├── sv_schema.lua  # Lógica servidor
│   ├── sh_schema.lua  # Lógica compartida + includes
│   ├── cl_hooks.lua   # Hooks cliente
│   ├── sh_hooks.lua   # Hooks compartidos
│   └── sv_hooks.lua   # Hooks servidor
└── plugins/           # Plugins del schema (cada uno en su propia carpeta)
    └── mi_plugin/
        ├── sh_plugin.lua   # Punto de entrada del plugin
        ├── cl_plugin.lua   # Lógica cliente
        └── sv_plugin.lua   # Lógica servidor
```

---

## Convenciones de nomenclatura de archivos

| Prefijo | Contexto      | Dónde se ejecuta                    |
|---------|---------------|-------------------------------------|
| `sh_`   | Shared        | Cliente **y** servidor              |
| `cl_`   | Client-only   | Solo cliente                        |
| `sv_`   | Server-only   | Solo servidor                       |

`ix.util.Include` gestiona automáticamente `AddCSLuaFile` según el prefijo.

---

## Facciones existentes

| Constante           | Nombre                  | Por defecto |
|---------------------|-------------------------|-------------|
| `FACTION_CIVIL`     | Civil del Metro         | ✅ sí       |
| `FACTION_POLIS`     | Polis                   | No          |
| `FACTION_HANZA`     | Ejercito de Hanza       | No          |
| `FACTION_LINEAROJA` | Línea Roja              | No          |
| `FACTION_CUARTOREICH` | Cuarto Reich          | No          |
| `FACTION_BANDIT`    | Bandido                 | No          |
| `FACTION_RANGER`    | Ranger                  | No          |
| `FACTION_SINDICATO` | Sindicato               | No          |
| `FACTION_STAFF`     | Staff                   | No          |

---

## Patrones de la API de Helix

### Facciones (`schema/factions/sh_*.lua`)
```lua
FACTION.name = "Nombre de Facción"
FACTION.description = "Descripción de la facción."
FACTION.color = Color(r, g, b)         -- Color en el scoreboard
FACTION.pay = 15                        -- Salario en Balas por intervalo
FACTION.models = { "models/..." }       -- Modelos disponibles
FACTION.isDefault = false               -- true = facción inicial al crear personaje
FACTION.isGloballyRecognized = false    -- true = nombre visible para todos

FACTION_MIFACCION = FACTION.index       -- Siempre al final

-- Opcional: equipo inicial al crear personaje
function FACTION:OnCharacterCreated(client, character)
    local inventory = character:GetInventory()
    inventory:Add("nombre_item", cantidad)
end
```

### Clases (`schema/factions/sh_*.lua` o archivo propio)
```lua
CLASS.name = "Nombre de Clase"
CLASS.description = "Descripción."
CLASS.faction = FACTION_MIFACCION
CLASS.models = { "models/..." }
CLASS.color = Color(r, g, b)

CLASS_MIFACCION_CLASE = CLASS.index
```

### Ítems (`schema/items/sh_*.lua`)
```lua
ITEM.name = "Nombre"
ITEM.model = Model("models/...")
ITEM.description = "Descripción del ítem."
ITEM.category = "Consumibles"   -- Categoría en el inventario
ITEM.width = 1                  -- Espacios de cuadrícula (ancho)
ITEM.height = 1                 -- Espacios de cuadrícula (alto)
ITEM.noBusiness = true          -- true = no aparece en tiendas
-- ITEM.price = 5               -- Precio si está en tienda

ITEM.functions.Usar = {
    OnRun = function(item)
        local client = item.player
        -- Usar "item" (instancia), no "ITEM" (plantilla)
        return true  -- true = elimina el ítem del inventario tras usarlo
    end
}
```

### Atributos (`schema/attributes/sh_*.lua`)
```lua
ATTRIBUTE.name = "Nombre Atributo"
ATTRIBUTE.description = "Descripción."
ATTRIBUTE.noStartBonus = true  -- true = no se puede subir al crear personaje
```

### Comandos (`ix.command.Add`)
```lua
ix.command.Add("NombreComando", {
    arguments = { ix.type.player, ix.type.number },
    description = "@clave_lenguaje",
    adminOnly = true,   -- opcional
    OnRun = function(self, client, ...)
        -- lógica
    end
})
```

### Plugins (`plugins/mi_plugin/sh_plugin.lua`)
```lua
PLUGIN.name = "Nombre del Plugin"
PLUGIN.author = "Autor"
PLUGIN.description = "Qué hace este plugin."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
```

### Hooks
```lua
-- Schema hooks: function Schema:NombreHook(...)
-- Plugin hooks: function PLUGIN:NombreHook(...)
-- Hook de GMod nativo: hook.Add("NombreHook", "identificador", function(...) end)
```

### Variables de personaje
```lua
ix.char.RegisterVar("miVariable", {
    field = "mi_variable",
    fieldType = ix.type.number,
    default = 0
})
-- Acceso: character:GetMiVariable() / character:SetMiVariable(valor)
```

---

## Reglas de estilo de código

1. **Indentación**: tabulaciones (`\t`), no espacios.
2. **Strings**: comillas dobles `"texto"` para strings; comillas simples para casos especiales.
3. **Comparaciones**: usar `==` y `!=` (GLua acepta `!=` como `~=`).
4. **Paréntesis en condiciones**: `if (condicion) then` — incluir paréntesis.
5. **No comentar código obvio**; comentar solo lógica no trivial.
6. **Constantes de facciones** (`FACTION_X`) siempre asignadas al final del archivo.
7. **Usar `item` (instancia) y no `ITEM` (plantilla)** dentro de callbacks de ítems.
8. **Localización**: preferir claves `L("clave")` en lugar de strings hardcodeadas en el cliente.

---

## Contexto del lore (Metro 2033)

El juego transcurre en el **Metro de Moscú** post-apocalíptico (2033). Los jugadores sobreviven en túneles y estaciones. Las facciones principales son:
- **Polis**: Capital diplomática del metro, rica y neutral.
- **Hanza**: Confederación de la línea de circunvalación, mercantil y militarizada.
- **Línea Roja**: Facción comunista/soviética.
- **Cuarto Reich**: Facción fascista/nazi.
- **Rangers of the Order**: Élite de exploradores.
- **Bandidos**: Saqueadores sin afiliación.
- **Sindicato**: Organización criminal.
- **Civiles**: Población general del metro.

La **moneda son las Balas** (munición pre-guerra, especialmente calibre 5.45 y similares).
