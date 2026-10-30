# Metro RP 2033 — Instrucciones para Claude

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

| Prefijo | Contexto    | Dónde se ejecuta       |
|---------|-------------|------------------------|
| `sh_`   | Shared      | Cliente **y** servidor |
| `cl_`   | Client-only | Solo cliente           |
| `sv_`   | Server-only | Solo servidor          |

`ix.util.Include` gestiona automáticamente `AddCSLuaFile` según el prefijo.

---

## Facciones existentes

| Constante              | Nombre           | Por defecto |
|------------------------|------------------|-------------|
| `FACTION_CIVIL`        | Civil del Metro  | ✅ sí       |
| `FACTION_POLIS`        | Polis            | No          |
| `FACTION_HANZA`        | Ejercito de Hanza| No          |
| `FACTION_LINEAROJA`    | Línea Roja       | No          |
| `FACTION_CUARTOREICH`  | Cuarto Reich     | No          |
| `FACTION_BANDIT`       | Bandido          | No          |
| `FACTION_RANGER`       | Ranger           | No          |
| `FACTION_SINDICATO`    | Sindicato        | No          |
| `FACTION_STAFF`        | Staff            | No          |

---

## Sistemas de EFG (modo Escape from Tarkov)

| Plugin | Qué hace |
|---|---|
| `efg_raids` | Raids por jugador en el mapa compartido: despliegue, tiempo, extracciones (siempre, aleatoria, de pago, sin mochila), MIA, XP y nivel, grupos y Scav run (`sv_scav.lua`). |
| `efg_health` | Salud por partes (440 en total), sangrados, fracturas, dolor, botiquines (`items/efgmed`) y protección de chalecos y cascos (`ScalePlayerDamage`). |
| `efg_physio` | Fisiología al estilo KAT encima de `efg_health`: sangre (6 L) y tensión, shock hipovolémico II-IV, SpO2, neumotórax (abierto / a tensión), vía aérea, inconsciencia (ragdoll de Helix), parada cardiaca, daño cerebral por hipoxia y grupos sanguíneos (`efgBloodType`, transfusión incompatible = reacción hemolítica). Estado solo en el servidor (`client.efgPhysio`), netvar `efgVitals` para el HUD. Ítems `items/efgphysio` (Usar / Aplicar al compañero con `DoStaredAction`), `/RCP`, `/GrupoSanguineo`, `/EFGFisiologia`. Brazos dañados: `ix.efg.health.UseTimeMult` alarga objetos y recargas ARC9. |
| `efg_gear` | Contenedores seguros y armaduras de EFT. `libs/sh_armor.lua` define `ix.efg.armor.Setup` (va en libs/ porque Helix carga libs antes que los ítems). |
| `efg_arc9` | Registra cada arma ARC9 de EFT como ítem `base_weapons`. |
| `efg_ai` | Zonas de Scavs, francotiradores, PMC y jefes de IA (VJ Base). |
| `efg_hideout` | Módulos del escondite. Sustituye a `ix.oficios`: el oficio de una receta es el módulo y `tierRequired` su nivel. |
| `efg_flea` | Mercadillo entre jugadores (desde nivel 15). |
| `traders` | Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman y Jaeger con lealtad 1 a 4 (`ix.traders.GetEffectiveRep` limita la rep por nivel de PMC). Stock inicial en `sh_eft_stock.lua`. Pantalla de EFT en DHTML (`cl_eft.lua` + `cl_eft_html.lua`, panel `efgxTrader`): diálogo con retrato (o vídeo en bucle `materials/efg/traders/<clave>.webm` si existe), compra y venta por objetos (`traders_SellItems`). `tradersEFTUI = false` vuelve a las ventanas antiguas. |
| `efg_pmc` | Creador de PMC en 5 pasos (`efgPMCCreator`: bando, apariencia, atributos, rol, identidad) sobre el modelo extendido (bodygroups Head/Body/Legs) y accesorios estéticos con bonemerge (`cl_cosmetic.lua`, netvar `efgCosmetic`). Datos en `sh_creation.lua` (`PMC.tops/legs/cosmetics/presets/roles`, `PMC.BuildKit`); validación en `CanPlayerCreateCharacter` + `PMC.ValidateCreation` (`sv_creation.lua`): nombre único, un PMC por cuenta, atributos (`attributes/`, `efgCreation = true`, 10 puntos) que se convierten en niveles de habilidad, y equipo del rol en `OnCharacterCreated`. Voces de EFT (`ix.efg.pmc.voiceLines`) y lobby con F4 (`efgLobby`). |
| `efg_profile` | Estadísticas del PMC (`efgProfile`: raids por bando, rachas, bajas, salud, combate, botín, XP por tipo, horas) y la pestaña PERSONAJE del TAB (`efgxCharacterPage`, copia de OVERALL de EFT: VGUI a la izquierda y DHTML a la derecha). Escucha `EFGHealthEvent`, `EFGXPGained`, `EFGRaidAbandoned` y `EFGRaidEnded`. |
| `efg_ui` | Kit visual estilo EFT: paleta y utilidades `ix.efgui` (`DrawPanel`, `DrawHeader`, `DrawCell`, `StyleFrame`, `StyleButton`, `GetItemColor`), fuentes `efgui.*` en Bender y `resource.AddFile` de todo `content/`. |
| `efg_invhtml` | Pestaña INVENTARIO del TAB en DHTML (`efgxInventoryPage`): equipo, táctico y alijo 10xN con CSS Grid y arrastre a mano sobre los nets de Helix (`ixInventoryMove`, `ixEquipToSlot`, `ixUnequipSlot`). `efgInvHTML = false` vuelve a la rejilla VGUI. |
| `efg_testcycle` | Registro del ciclo de raid (despliegue, extracción, muerte, MIA, abandono, alijo, XP, seguro) con hora en `data/efg/ciclo/<fecha>.txt` y `/EFGLogCiclo`. `/EFGTestCiclo [todo\|extract\|death\|mia\|abandon]` (superadmin) lleva un bot con equipo y alijo en memoria por las funciones reales de `efg_raids` y da PASS/FAIL por paso. Configs `efgCycleLog`, `efgCycleLogFile`, `efgCycleStepDelay`, `efgCycleTestItem`. |
| `efg_invgrid` | Pestaña EQUIPO del TAB en VGUI (`efgxInventoryEFT`, config `efgInvEFT`): equipo, táctico, alijo con scroll y acceso rápido. Objetos como `DButton` hijos de la rejilla (`efgxInvGrid`), arrastre propio con encaje (`math.Round` sobre la esquina), R gira mientras arrastras (net `ixEFGRotateMove` de `efg_invrules`) y menú contextual (`DMenu` restilizado). Usa los helpers de `efg_invhtml` (`Move`, `Signature`, `RunFunction`). |
| `ix_invkey` | Inventario con TAB al estilo EFT. Ranuras de casco, chaleco, mochila y contenedor seguro en el inventario de equipo (16x8, `ix.GetEquipSlotKind`); ranuras de arma (principal, funda, vaina) que muestran el arma equipada de cada categoría. |

Las texturas propias están en `content/materials/efgui/` (se generan con `tools/gen_efgui.py` y PIL; no dependen del addon Metro UI) y la fuente Bender en `content/resource/fonts/`. Bender no tiene el signo ₽: los precios se escriben en RUB.

Las mochilas nuevas van en `plugins/metrobags/items/metrobags/`: un plugin solo puede usar bases de plugins que carguen antes (orden alfabético).

## Interfaz: reglas comunes

- **Un solo menú**: el TAB (`ixMetroInventory`) es el contenedor de todas las pantallas del jugador (inventario, salud, personaje, comerciantes, tareas, escondite, raid, mercadillo y ajustes). Para abrir una pestaña desde otro plugin: `ix.gui.invKeyStartTab = "<id>"` y crear el TAB.
- **Fuente única**: Bender (`"MBender"` en `surface.CreateFont`, `var(--efg-font)` en CSS). No usar otras familias.
- **Paleta única**: `ix.efgui.color` en VGUI y las variables `--efg-*` de `efg_ui/cl_css.lua` en DHTML. `tools/recolor_eft.py` pasa tonos sepia de Metro a la paleta EFT.
- **DHTML = Chromium 86** (CEF de GMod): nada de `inset:`, `aspect-ratio`, `:is()`, `:where()`, `:has()`, `Array.at()`, `structuredClone`. El drag and drop de HTML5 no es fiable: arrastre a mano con mousedown/mousemove/mouseup.
- **Cliente de Helix**: los objetos no tienen `gridX`/`gridY` en el cliente; la posición es la celda de `inv.slots` donde están guardados.
- Plugins retirados de Metro (en `_retirados/plugins`): ANIM_INV, TABANIM, community_missions, tablon_encargos, generadores, new_wepselect.

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
PLUGIN.author = "Metro RP By Cono y Manperra"
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
2. **Strings**: comillas dobles `"texto"`; comillas simples solo para casos especiales.
3. **Comparaciones**: `==` y `!=` (GLua acepta `!=` como `~=`).
4. **Paréntesis en condiciones**: `if (condicion) then` — siempre incluir paréntesis.
5. **No comentar código obvio**; comentar solo lógica no trivial.
6. **Constantes de facciones/clases** (`FACTION_X`, `CLASS_X`) siempre al final del archivo.
7. **Usar `item` (instancia) y no `ITEM` (plantilla)** dentro de callbacks de ítems.
8. **Localización**: preferir claves `L("clave")` en lugar de strings hardcodeadas en el cliente.

---

## Seguridad GLua

- Siempre verificar `IsValid(entidad)` antes de llamar métodos en entidades.
- Siempre verificar `client:GetCharacter()` antes de llamar sus métodos — puede devolver `nil`.
- Nunca usar `table.contains` (no existe en GLua) → usar `table.HasValue`.
- Los timers por jugador deben eliminarse en `PlayerDisconnected`.
- No llamar `GetCharacter()` dentro de `PlayerInitialSpawn` — el personaje aún no está cargado.

---

## Fallos comunes (gotchas verificados)

Errores reales encontrados en este proyecto. Revisar siempre antes de dar por bueno un plugin con entidades o interfaces.

### Orden de carga de un plugin (Helix)
Al cargar un plugin, Helix ejecuta en este orden: `languages/` → `libs/` → `factions/` → `items/` → `plugins/` → **`derma/`** → **`entities/`** → y **al final** `sh_plugin.lua`. El plugin NO se registra en `ix.plugin.list` hasta **después** de `sh_plugin.lua`.

- **`ix.plugin.Get("mi_plugin")` devuelve `nil` en el scope superior de `derma/` y `entities/`** (se ejecutan antes del registro). Consecuencia: capturar `local PLUGIN = ix.plugin.Get(...)` ahí guarda `nil` para siempre y cualquier uso posterior (ej. `net.Start(PLUGIN.netX)`) crashea **silenciosamente** → la UI nunca abre.
  - **Derma:** envolver todo el archivo en `timer.Simple(0, function() local PLUGIN = ix.plugin.Get("...") ... end)`.
  - **Entidades:** obtener el plugin **en runtime dentro del método** (ej. al inicio de `ENT:Use`), nunca en el scope del archivo.
- Pon fuentes/config que el derma necesite en `libs/` (cargan antes).
- Helix **ya auto-incluye `derma/`**; no hace falta `ix.util.IncludeDir(".../derma")` en `cl_plugin.lua` (es redundante).
- La estructura de entidades es `entities/entities/<clase>/{init,cl_init,shared}.lua` (doble `entities/` a propósito).

### Paneles (VGUI / derma)
- **Los paneles hijos se recortan (clip) a los límites del padre por defecto.** Posicionar un hijo fuera del padre (ej. `panel:SetPos(0, parent:GetTall())`) lo deja invisible. Para mostrar un sub-panel, colócalo **dentro** del área visible del padre y usa `MoveToFront()`; si necesita salirse, usa `panel:NoClipping(true)`.
- `ix.plugin.Get("metroui"):GetFontInternal(id)` devuelve el nombre de fuente del plugin **metroui** (ej. `"Metro UI.Button"`). Las UIs del schema dependen de metroui — comprobar `if (not PLUGIN_UI) then return end`.
- `LerpColor`, `SScale`, `VScale`, `SScaleMin` son globales definidas por **metroui** (en `if CLIENT`), no de GMod.
- Toda lógica de panel debe ir tras `vgui.Register(...)`; un error en el cuerpo del archivo derma antes del register impide registrar la clase y `vgui.Create` devolverá `nil`.

### Persistencia (PermaProps, workshop `220336312`)
- PermaProps **sí guarda** `Material` (`GetMaterial`), `SubMat` (`GetSubMaterial`), `Color`, `Skin`, `BodyG` en su snapshot, pero **solo en el momento de guardar**.
- Si cambias el material **después** de permapropear, hay que **actualizar** el snapshot: apuntar con la PermaProps tool y pulsar **R (Reload/Update)** → ejecuta `UPDATE` en SQL.
- Materiales **client-side** (PAC3, proxies) NO se guardan (`GetMaterial` server-side los ignora). Para esos casos, usar los hooks `PermaProps.OnEntitySaved` (devuelve tabla extra a guardar) y `PermaProps.OnEntityCreated(ent, data)` (restaurar).

---

## Reglas específicas por tipo de archivo

### Facciones (`schema/factions/**/*.lua`)

- La constante `FACTION_X` se asigna **al final** del archivo, después de todos los campos.
- `FACTION.isDefault = true` solo para `FACTION_CIVIL` (única facción por defecto).
- `FACTION.weapons = {"ohandsswep"}` en todas las facciones sin armas de inicio.
- Si la facción tiene ítems iniciales → implementar `FACTION:OnCharacterCreated(client, character)`.
- Si la facción tiene rangos → usar `FACTION.Ranks` y `FACTION:OnRankChanged(client, old, new)`.
- Descripciones en **español**, tono coherente con el lore de Metro 2033.

### Ítems (`schema/items/**/*.lua`)

- Dentro de **cualquier callback** (`OnRun`, `OnEquip`, etc.) usar siempre `item` (instancia), **nunca** `ITEM`.
- `return true` en `OnRun` elimina el ítem del inventario; `return false` lo conserva.
- `ITEM.noBusiness = true` si el ítem no debe aparecer en tiendas.
- Acceder al jugador con `item.player` (no `ITEM.player`).
- Proteger valores vitales: `client:SetHealth(math.min(client:Health() + 20, client:GetMaxHealth()))`.
- Categorías comunes: `"Consumibles"`, `"Equipamiento"`, `"Medicamentos"`, `"Recursos"`, `"Armas"`.

### Plugins (`plugins/**/*.lua`)

- Usar `PLUGIN:NombreHook(...)` para hooks del framework (no `Schema:`).
- `PLUGIN.author = "Metro RP By Cono y Manperra"` en todos los plugins.
- Incluir sub-archivos con `ix.util.Include("cl_plugin.lua")` y `ix.util.Include("sv_plugin.lua")`.
- **Comandos en archivo shared**: definir `ix.command.Add` siempre en un archivo `sh_` (ej. `sh_commands.lua`) para que aparezcan en el autocompletado del chat del cliente. Nunca definir comandos solo en `sv_plugin.lua`.
- Net strings: declarar con `util.AddNetworkString("Nombre")` en `sv_plugin.lua` antes de usarlas.
- Timers por jugador: limpiar en `PLUGIN:PlayerDisconnected(client)`.
- No hardcodear strings visibles al jugador; usar `client:NotifyLocalized("clave")`.
- Lógica exclusiva de servidor en `sv_plugin.lua`; lógica de cliente en `cl_plugin.lua`.

### Hook del framework vs hook de GMod nativo
```lua
-- Framework Helix (en PLUGIN o Schema)
function PLUGIN:CharacterLoaded(character) end

-- GMod nativo (con hook.Add)
hook.Add("PlayerSpawn", "MiPlugin_Spawn", function(client) end)
```

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

---

## Comandos y agentes disponibles

Usa `/` para invocar los comandos personalizados del proyecto:

| Comando              | Descripción                                      |
|----------------------|--------------------------------------------------|
| `/nueva-faccion`     | Crear una nueva facción completa                 |
| `/nuevo-item`        | Crear un nuevo ítem para el inventario           |
| `/nuevo-plugin`      | Crear un plugin completo                         |
| `/debug-glua`        | Diagnosticar y corregir errores GLua             |
| `/revisar-codigo`    | Revisar código antes de publicar al servidor     |
| `/localizar-strings` | Gestionar cadenas de idioma (`sh_english.lua`)   |

Sub-agentes especializados disponibles vía Agent tool:

| Agente           | Uso                                              |
|------------------|--------------------------------------------------|
| `glua-reviewer`  | Revisión de código con alta señal/ruido          |
| `content-writer` | Redacción de lore, descripciones y mensajes      |
| `metrorp-dev`    | Desarrollo general del schema y plugins          |
