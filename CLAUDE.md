# EFG: Escape from Gmod — Instrucciones para Claude

## Descripción del proyecto

**EFG (Escape from Gmod)** es un schema de extracción al estilo *Escape from Tarkov* para Garry's Mod, construido sobre el framework **[Helix](https://github.com/nebulouscloud/helix)**. Mantenido por **Metro RP By Cono y Manperra** (Navarro, Mancera, xMeeKo). Nació del schema de rol *Metro RP 2033* y se ha reconstruido entero alrededor del ciclo de EFT: preparas a tu PMC en el escondite, entras en una raid, sobrevives, saqueas y extraes (o lo pierdes todo).

**EFG es una conversión total de Metro RP 2033, no una adaptación.** Se conserva el esqueleto de Helix, las convenciones de código y algunos plugins genéricos; el lore, la economía, las facciones, la progresión, la interfaz y el ciclo de juego son de Escape from Tarkov. Todo lo que no encaja con EFT se retira, se sustituye o se reescribe. Lo heredado de Metro que sobrevive (carpeta del gamemode, ID de la moneda) es **legacy acotado y documentado**, no diseño de EFG.

- **Lenguaje del código**: GLua (Lua 5.1 de Garry's Mod) sobre la API `ix.*` de Helix.
- **Idioma del contenido**: español.
- **Moneda**: rublos (RUB), más dólares (USD) y euros (EUR). El objeto interno de dinero conserva el ID `bala` por herencia de Metro (ver *Legacy de Metro*).
- **Bandos**: USEC y BEAR (PMC), Scav (Scav run) y Staff.
- **Framework**: Helix (`ix.*`).
- **Estado**: casi todo programado, **sin probar en partida**. Los valores marcados con `[VERIFICAR]` en la configuración son aproximaciones a la wiki de EFT pendientes de revisar.

---

## Legacy de Metro (explícito y acotado)

Lo único de Metro RP 2033 que sobrevive. **No es diseño de EFG; es deuda técnica documentada.**

| Elemento | Estado | Motivo | Tarea pendiente |
|---|---|---|---|
| Carpeta `metrorp/` y `metrorp.txt` | Se mantiene | Compatibilidad con el descriptor, `tools/compilar.bat` y `+gamemode metrorp` en producción. | Renombrar a `efg/` y `efg.txt`; afecta a rutas, docs, bat y arranque del servidor. |
| ID de ítem `bala` (dinero) | Se mantiene | Cambiarlo a `rub` requiere migración de BD (inventarios, stock de comerciantes, ofertas de mercadillo). | Migración de BD y renombrar el ID. |
| Plugin `metroui` | Se mantiene | Provee `GetFontInternal`, `LerpColor`, `SScale`, `VScale`, `SScaleMin` y fuentes base usadas por las UIs del schema. | Sustituir las dependencias por `efg_ui` y retirarlo. |
| Plugins genéricos (`adminchat`, `puertas`, `legs`, `observer_enhanced`...) | Se mantienen | No dependen del lore de Metro. | Ninguna. |
| `_retirados/plugins/` | No se carga | ANIM_INV, TABANIM, community_missions, tablon_encargos, generadores, new_wepselect, `ix_cwsupport`, HUD de Metro, cartas, pasaportes, temperatura... | No reactivar sin comprobar que no rompe el ciclo de EFT. |
| `_retirados/factions/` | No se carga | Las 9 facciones de Metro (Civil, Polis, Hanza, Línea Roja, Cuarto Reich, Bandido, Ranger, Sindicato, Staff). | Ninguna. |

**Regla**: ningún archivo nuevo debe referirse a Metro, a sus facciones, a sus estaciones ni a "balas como munición pre-guerra". Si un texto, config o ítem menciona Metro, es un bug de conversión.

---

## Estructura de carpetas

La carpeta del gamemode **tiene que llamarse `metrorp`** (así se llama `metrorp.txt`), aunque el proyecto se llame EFG. El contenido propio vive en `content/`, que GMod monta solo desde la carpeta del gamemode.

metrorp/ # carpeta del gamemode (legacy, ver arriba)
├── gamemode/ # punto de entrada (cl_init.lua, init.lua)
├── schema/ # lógica principal del schema
│ ├── attributes/ # atributos de personaje (sh_.lua)
│ ├── factions/ # usec, bear, scav, staff (sh_.lua)
│ ├── items/ # definiciones de ítems base (sh_*.lua)
│ ├── languages/ # strings localizados (sh_english.lua, etc.)
│ ├── libs/ # librerías del schema (auto-incluidas; cargan antes que items)
│ ├── meta/ # extensiones de meta-tablas (personaje, jugador)
│ ├── cl_schema.lua
│ ├── sv_schema.lua
│ ├── sh_schema.lua # includes compartidos
│ ├── cl_hooks.lua
│ ├── sh_hooks.lua
│ └── sv_hooks.lua
├── plugins/ # todos los sistemas (uno por carpeta)
│ └── mi_plugin/
│ ├── sh_plugin.lua # punto de entrada
│ ├── cl_plugin.lua
│ └── sv_plugin.lua
├── content/ # contenido propio que se manda a los clientes
│ ├── materials/ # efg/ (HUD, salud, comerciantes, medicinas), efgui/ (UI), eftwiki/ (iconos)
│ ├── models/ # PMC y Scav modulares, equipo, viewmodels de medicinas
│ ├── sound/ # efg/ (UI, salud, voces) y weapons/eft
│ ├── resource/ # fuente Bender
│ └── data_static/ # eft_items.json (datos de objetos de EFT)
├── tools/ # scripts de desarrollo
├── _retirados/ # plugins y facciones de Metro que ya no se cargan
├── metrorp.txt # descriptor del gamemode (legacy)
├── COMANDOS.md # chuleta de comandos y controles
└── CLAUDE.md # este archivo
text


Cada plugin va en `plugins/mi_plugin/` con `sh_plugin.lua` (punto de entrada), `cl_plugin.lua` y `sv_plugin.lua`. Las mochilas nuevas van en `plugins/metrobags/items/metrobags/`: un plugin solo puede usar bases de plugins que carguen antes (orden alfabético).

---

## Convenciones de nomenclatura de archivos

| Prefijo | Contexto    | Dónde se ejecuta       |
|---------|-------------|------------------------|
| `sh_`   | Shared      | Cliente **y** servidor |
| `cl_`   | Client-only | Solo cliente           |
| `sv_`   | Server-only | Solo servidor          |

`ix.util.Include` gestiona automáticamente `AddCSLuaFile` según el prefijo.

---

## Bandos / facciones

| Constante        | Nombre  | Notas |
|------------------|---------|-------|
| `FACTION_USEC`   | USEC    | Bando PMC elegible al crear el personaje (mercenario occidental). |
| `FACTION_BEAR`   | BEAR    | Bando PMC elegible al crear el personaje (exmilitar ruso). |
| `FACTION_SCAV`   | Scav    | Bando de las Scav run (`/RaidScav`); no es PMC. |
| `FACTION_STAFF`  | Staff   | Administración. |

El bando de un PMC se elige en el creador (`efg_pmc`, `efgPMCCreator`), no con `isDefault`. Un PMC por cuenta y nombre único (validado en `CanPlayerCreateCharacter` + `PMC.ValidateCreation`). El equipo inicial lo pone el rol (Asaltante, Tirador, Médico) en `OnCharacterCreated` vía `PMC.BuildKit`. Si algún flujo de Helix necesita un `isDefault` (p. ej. `PlayerFirstCreatedCharacter` sin creador), debe apuntar a USEC o BEAR, **nunca** a una facción de Metro.

---

## Plugins de EFG

Agrupados como en el README. Cada plugin tiene su carpeta en `plugins/`.

### Raid y mapas
| Plugin | Qué hace |
|---|---|
| `efg_raids` | Ciclo de raid: despliegue desde el escondite, temporizador, extracciones (siempre, aleatoria, de pago, sin mochila, interruptor), MIA, Run Through, XP/nivel del PMC, grupos y Scav run (`sv_scav.lua`). Interfaz de extracciones de la tecla O en `cl_extracts.lua`. |
| `efg_maps` | Datos de las 10 localizaciones de EFT (Aduanas, Fábrica, Bosque, Costa, Intercambiador, Reserva, Faro, Calles de Tarkov, Zona cero, Laboratorio): duración, jefes y jugadores. Reloj acelerado con día y noche, clima, llaves y puertas cerradas con llave. |
| `efg_ai` | Zonas de IA (VJ Base) que generan oleadas mientras hay jugadores cerca: Scavs, francotiradores, PMC, Raiders, Rogues, cultistas y jefes (Reshala, Killa, Tagilla, Shturman, Glukhar, Kaban, Kollontay, Zryachiy, Goons, Partisan...). |
| `efg_karma` | Karma Scav (reputación con Fence): baja al matar Scavs siendo Scav, sube al extraer y cambia la espera y la hostilidad de la IA. |
| `efg_menus` | Pantallas de flujo: menú de entrada, selección de raid, despliegue con controles e inspección de objetos. |
| `efg_server` | Wipe, modo PvE/PvP, cola para buscar grupo, anticheat de velocidad y de distancia de saqueo, descarga del contenido y de la colección, y autodiagnóstico. |
| `efg_guard` | Anticheat de red: limita los mensajes por jugador y expulsa a quien abusa. |
| `efg_testcycle` | Registro del ciclo de raid (despliegue, extracción, muerte, MIA, abandono, alijo, XP, seguro) con hora en `data/efg/ciclo/<fecha>.txt`. `/EFGTestCiclo [todo\|extract\|death\|mia\|abandon]` lleva un bot por las funciones reales de `efg_raids` y da PASS/FAIL por paso. |

### Salud y estado
| Plugin | Qué hace |
|---|---|
| `efg_health` | Salud por partes como EFT (cabeza 35, tórax 85, estómago 70, brazos 60, piernas 65: 440 en total), sangrados leves y graves, fracturas, dolor, extremidades destruidas y daño repartido. Botiquines, vendas, torniquetes, férulas, cirugía y estimulantes (`items/efgmed`) con animación en primera persona (SWEP `efg_med`). Protección de chalecos y cascos en `ScalePlayerDamage`. Pestaña SALUD con silueta, arrastre de medicinas a cada parte y movimiento con inercia (`cl_movement.lua`). |
| `efg_physio` | Fisiología al estilo KAT encima de `efg_health`: 6 L de sangre y tensión, shock hipovolémico II-IV, SpO2, neumotórax abierto y a tensión, vía aérea, inconsciencia (ragdoll de Helix), parada cardiaca con RCP, daño cerebral por hipoxia y grupos sanguíneos (transfusión incompatible = reacción hemolítica). Material de soporte vital (`items/efgphysio`) usable en uno mismo o en un compañero. Los brazos dañados alargan el uso de objetos y las recargas. |
| `efg_status` | Hidratación y energía de EFT (sustituye a `needs`), deshidratación, agotamiento, conmoción, temblores, visión túnel y fractura de pierna. |
| `efg_effects` | Efectos temporales: estimulantes, herida fresca, fatiga, intoxicación, radiación y alcohol. |
| `anims_meds` | Comidas y bebidas de la colección como objetos de Helix con sonido, animación y efectos. |

### Armas y combate
| Plugin | Qué hace |
|---|---|
| `efg_arc9` | Registra como objeto de Helix cada arma ARC9 de EFT instalada (`arc9_eft_*`, `arc9_wtt_*`) con tamaño, peso, categoría y precio. |
| `efg_ballistics` | Munición de EFT por calibre como objetos apilables (`ammo_<calibre>_<bala>`), elección de munición por arma, fórmula de penetración y desgaste de blindaje de EFT, cascos con zonas y rebotes. |
| `efg_mags` | Cargadores como objetos: se llenan bala a bala y la recarga cambia el cargador entero. |
| `efg_mods` | Accesorios de arma como objetos que se instalan en las ranuras y cambian ergonomía, retroceso y peso. |
| `efg_weapons` | Desgaste por disparo, sobrecalentamiento, fallos y encasquillamientos, reparación con kit y efecto de los brazos heridos al disparar. |
| `efg_inspect` | Ventana de inspección en DHTML y pantalla de modding de ARC9 al estilo EFT: árbol de ranuras, piezas compatibles y estadísticas en vivo. |
| `arc9_support` | Soporte de accesorios y armas de ARC9 en el inventario de Helix. |
| `wepraised` | Armas siempre levantadas. |

### Equipo e inventario
| Plugin | Qué hace |
|---|---|
| `ix_invkey` | El TAB: ranuras de casco, chaleco, mochila y contenedor seguro (inventario de equipo 16x8, `ix.GetEquipSlotKind`), ranuras de arma (principal, funda, vaina), bolsillos y todas las pestañas. |
| `efg_invgrid` | Pestaña EQUIPO en VGUI (`efgxInventoryEFT`): rejillas con encaje, giro con R al arrastrar, alijo con scroll, acceso rápido y menú contextual. Se activa con `efgInvEFT`. |
| `efg_invhtml` | Pestaña de inventario en DHTML (`efgxInventoryPage`) con CSS Grid y arrastre propio. Se activa con `efgInvHTML`. |
| `efg_invrules` | Rotación de objetos, qué cabe en cada contenedor, objetos encontrados en raid (FIR), examinar y tiempo de búsqueda de contenedores y cuerpos. |
| `efg_gear` | Chalecos y cascos por clase, placas, mochilas, contenedores seguros, auriculares, gafas, cubrecaras, brazaletes y chalecos tácticos con rejilla. `libs/sh_armor.lua` define `ix.efg.armor.Setup` (va en libs/ porque Helix carga libs antes que los ítems). |
| `efg_outfits` | PMC modulares (cabeza, chaqueta y pantalón con `/Atuendo`), modelo de Scav y equipo visible sobre el jugador y los cadáveres. |
| `efg_icons` | Iconos 2D de inventario (`ITEM.iconMaterial`) con vuelta al modelo 3D, y rareza de los objetos. |
| `efg_eftdata` | Base de datos de objetos de EFT sacada de la wiki (nombre, tipo, peso, tamaño, estadísticas) con sus iconos en `materials/eftwiki/icons`. |
| `efg_quickbar` | Barra de acceso rápido 1-5 con las texturas del selector de Tarkov. |
| `efg_radial` | Menú radial con Z. |
| `efg_insurance` | Seguro: lo asegurado que nadie se lleva vuelve al alijo tras un tiempo. |
| `strongbox` | Alijo personal (10x30, crece con el módulo Alijo). `/Alijo` lo abre. |
| `metrobags` | Bases de mochilas (las nuevas van en `plugins/metrobags/items/metrobags/`). |
| `weight` | Peso de los objetos. |
| `loot_on_death` | Todo cae al cadáver salvo lo marcado con `ITEM.noLoot`. |
| `loot` | Botín por zonas, presets de props y niveles (congelado: lo sustituye `efg_loot`). |
| `efg_loot` | Núcleo del loot: tablas de datos (`sh_loot_tables.lua`), `ix.efg.loot.WeightByPrice`, `ix.efg.loot.Roll(tabla, opts)` y objetos de botín de EFT. Todo el loot sale de tablas, nunca de `if`. Carga antes que `efg_loot_ai` y `efg_loot_ui`; lee `efg_ui`, `efg_raids` e `ix_invkey` solo en tiempo de ejecución. |

### PMC, progresión y perfil
| Plugin | Qué hace |
|---|---|
| `efg_pmc` | Creador de PMC en 5 pasos (`efgPMCCreator`), accesorios estéticos con bonemerge (`cl_cosmetic.lua`, netvar `efgCosmetic`), validación en el servidor (`sv_creation.lua`), voces de EFT y frases rápidas, lobby con F4 (`efgLobby`). Datos en `sh_creation.lua` (`PMC.tops/legs/cosmetics/presets/roles`, `PMC.BuildKit`). |
| `efg_profile` | Estadísticas del PMC (raids por bando, rachas, bajas, salud, combate, botín, XP por tipo, horas) y la pestaña PERSONAJE del TAB (`efgxCharacterPage`, copia de OVERALL de EFT: VGUI a la izquierda y DHTML a la derecha). Escucha `EFGHealthEvent`, `EFGXPGained`, `EFGRaidAbandoned` y `EFGRaidEnded`. |
| `efg_progression` | Curva de nivel de EFT (79 niveles) y XP por examinar, saquear, curar y tiros a la cabeza. |
| `habilidades` | Habilidades (perks) que suben con el uso; sustituye a los atributos de inicio de Helix. |

### Economía y comerciantes
| Plugin | Qué hace |
|---|---|
| `traders` | Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman y Jaeger con lealtad 1 a 4 (`ix.traders.GetEffectiveRep` limita la rep por nivel de PMC). Stock inicial en `sh_eft_stock.lua`. Pantalla de EFT en DHTML (`cl_eft.lua` + `cl_eft_html.lua`, panel `efgxTrader`): diálogo con retrato (o vídeo en bucle `materials/efg/traders/<clave>.webm` si existe), compra y venta por objetos (`traders_SellItems`). `tradersEFTUI = false` vuelve a las ventanas antiguas. |
| `efg_economy` | Dólares y euros (cambio en Peacekeeper y Skier), reparación en Prapor y Mechanic, chapas (dogtags) y surtido de EFT. |
| `efg_flea` | Mercadillo entre jugadores desde nivel 15, con comisión, duración de ofertas y FIR obligatorio. |
| `efg_quests` | Tareas iniciales de los comerciantes basadas en las de EFT. |
| `efg_tasks` | Pestaña TAREAS como la de EFT. |
| `missions` | Motor de misiones por pasos (explorar, eliminar, buscar, entregar), editables en partida. |
| `efg_messages` | Mensajes de comerciantes (seguro, mercadillo, tareas), manual de objetos con precios y pasos que suenan según el material. |
| `intercambio` | Intercambio seguro de objetos entre jugadores. |
| `trader_logs` | Trazabilidad de lo vendido por comerciantes y detector de duplicados. |
| `money_items`, `economia_monitor` | Dinero como objeto físico y desglose de la masa monetaria. |

### Escondite
| Plugin | Qué hace |
|---|---|
| `efg_hideout` | Módulos principales: Alijo, Generador, Banco de trabajo, Estación médica, Lavabo, Unidad de nutrición, Zona de descanso y Centro de inteligencia. Se mejoran con rublos y objetos y desbloquean recetas. Sustituye a los oficios de Metro: el oficio de una receta es el módulo y `tierRequired` su nivel. |
| `efg_hideout_extra` | Resto de módulos de EFT: Seguridad, Calefacción, Iluminación, Ventilación, Recolector de agua, Filtrado de aire, Panel solar, Destilería, Granja de bitcoin, Scav Case, Galería de tiro, Biblioteca, Gimnasio, Armero de pared y Salón de la fama. Combustible del generador. |
| `efg_production` | Fabricación con tiempo: los materiales se gastan al empezar y el resultado llega al alijo. |
| `metrocrafting` | Mesas de fabricación del escondite colocables por admins. |

### Interfaz
| Plugin | Qué hace |
|---|---|
| `efg_ui` | Kit visual: paleta `ix.efgui.color`, utilidades (`DrawPanel`, `DrawHeader`, `DrawCell`, `StyleFrame`, `StyleButton`, `GetItemColor`), fuentes `efgui.*` en Bender, CSS común `--efg-*` para DHTML (`cl_css.lua`) y `resource.AddFile` de `content/`. |
| `efg_hud` | HUD de EFT (estado por zonas, postura, resistencia, cargador, avisos, cursor), necesidades, barra de acción y etiquetas. |
| `fix_hud_arc.lua` | Corrige `ix.util.PrecacheArc` y protege `ix.hud.DrawAll`. |

### Administración
| Plugin | Qué hace |
|---|---|
| `efg_admin` | Comandos de prueba: dinero, nivel, XP, lealtad, completar tareas y tiempo de raid. |

### Otros plugins activos (heredados o genéricos)
`adminchat`, `ambient_music`, `antibhop`, `area_visualizer`, `better_armor` (máscara de gas), `bodygroupmanager`, `cleaner`, `contextmenu` (bloquea C y Q salvo flag `z`), `disable_zoom`, `extracommands`, `flashlightitem`, `helix_menu`, `help_comandos` (`/comandos`), `hidevoicepanels`, `legs`, `metroui`, `needs`, `npc_custom`, `npc_obstacle_jump`, `npc_presets`, `npc_stepheight`, `observer_enhanced`, `persistent_corpses`, `puertas`, `puertas_brecheables`, `ranks`, `sh_adverts`, `simpleradio`, `spawnmenu_itemtab`, `thirdperson`, `tposefixer`, `vigilancia`, `vision_nocturna`, `vmanip_port`, `voicerevamped`.

**Retirados** (en `_retirados/`, no se cargan): ANIM_INV, TABANIM, community_missions, tablon_encargos, generadores, new_wepselect, `ix_cwsupport`, HUD de Metro, cartas, pasaportes, temperatura y las facciones de Metro.

---

## Imagen de novedades en cada commit (obligatorio)

Cada commit que se sube a GitHub lleva su imagen de novedades al estilo del roadmap de EFT (tarjetas con lo que cambia y su relevancia):

1. Escribe `docs/novedades/json/<fecha>-<tema>.json` con `titulo` y `tarjetas` (`area`, `relevancia` = `critica`/`alta`/`media`/`baja`, `cambios` como viñetas cortas en español, `nota` opcional). Formato completo en la cabecera de `tools/novedades.py`.
2. `python tools/novedades.py docs/novedades/json/<archivo>.json` escribe `docs/novedades/<fecha>-<slug>.png` y la añade arriba en `docs/novedades/README.md`. Imprime la ruta.
3. Mete el JSON, el PNG y el README en **el mismo commit** y termina el mensaje con `Novedades: docs/novedades/<archivo>.png`.
4. En el cuerpo del PR, incrusta la imagen: `![novedades](https://github.com/IosifStalin6773/EFG/blob/<rama>/docs/novedades/<archivo>.png?raw=true)`.

Relevancia: **crítica** = rompe o arregla algo que bloquea jugar; **alta** = sistema o mecánica nueva visible; **media** = mejora o ajuste de algo existente; **baja** = documentación, herramientas, limpieza. Sin logos de EFT/BSG: la marca es EFG.

---

## Interfaz: reglas comunes

- **Un solo menú**: el TAB (`ixMetroInventory`) es el contenedor de todas las pantallas del jugador (GENERAL, EQUIPO, SALUD, HABILIDADES, MAPA, TAREAS, LOGROS, COMERCIANTES, ESCONDITE, MERCADILLO, AJUSTES). Para abrir una pestaña desde otro plugin: `ix.gui.invKeyStartTab = "<id>"` y crear el TAB (ids: `char`, `inv`, `health`, `skills`, `raid`, `tasks`, `achievements`, `traders`, `hideout`, `flea`, `settings`). El menú base de Helix sigue disponible para admins con `/OpenHelixMenu`.
- **Fuente única**: Bender (`"MBender"` en `surface.CreateFont`, `var(--efg-font)` en CSS). No usar otras familias.
- **Paleta única**: `ix.efgui.color` en VGUI y las variables `--efg-*` de `efg_ui/cl_css.lua` en DHTML. `tools/recolor_eft.py` pasa tonos sepia de Metro a la paleta EFT.
- **DHTML = Chromium 86** (CEF de GMod): nada de `inset:`, `aspect-ratio`, `:is()`, `:where()`, `:has()`, `Array.at()`, `structuredClone`. El drag and drop de HTML5 no es fiable: arrastre a mano con mousedown/mousemove/mouseup.
- **Bender no tiene el signo ₽**: los precios se escriben en **RUB**.
- **Cliente de Helix**: los objetos no tienen `gridX`/`gridY` en el cliente; la posición es la celda de `inv.slots` donde están guardados.
- **Texturas propias**: en `content/materials/efgui/`, generadas con `tools/gen_efgui.py` y PIL. **No dependen del addon Metro UI.**

---

## Patrones de la API de Helix

### Facciones (`schema/factions/sh_*.lua`)
```lua
FACTION.name = "USEC"
FACTION.description = "Mercenario occidental."
FACTION.color = Color(r, g, b)
FACTION.pay = 0                         -- EFG no usa pay de Metro
FACTION.models = { "models/..." }
FACTION.isGloballyRecognized = false

FACTION_USEC = FACTION.index             -- Siempre al final

-- Opcional: equipo inicial al crear personaje
function FACTION:OnCharacterCreated(client, character)
	local inventory = character:GetInventory()
	inventory:Add("nombre_item", cantidad)
end

Clases (schema/factions/sh_*.lua o archivo propio)
lua

CLASS.name = "Nombre de Clase"
CLASS.description = "Descripción."
CLASS.faction = FACTION_MI_BANDO
CLASS.models = { "models/..." }
CLASS.color = Color(r, g, b)

CLASS_MI_BANDO_CLASE = CLASS.index

Ítems (schema/items/sh_*.lua)
lua

ITEM.name = "Nombre"
ITEM.model = Model("models/...")
ITEM.description = "Descripción del ítem."
ITEM.category = "Consumibles"   -- o "Equipamiento", "Medicamentos", "Recursos", "Armas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true
-- ITEM.price = 5               -- si está en tienda
-- ITEM.noLoot = true           -- no cae al cadáver (loot_on_death)

ITEM.functions.Usar = {
	OnRun = function(item)
		local client = item.player
		-- Usar "item" (instancia), no "ITEM" (plantilla)
		return true  -- true = elimina el ítem del inventario tras usarlo
	end
}

Atributos (schema/attributes/sh_*.lua)
lua

ATTRIBUTE.name = "Nombre Atributo"
ATTRIBUTE.description = "Descripción."
ATTRIBUTE.noStartBonus = true

Comandos (ix.command.Add) — siempre en archivo sh_
lua

ix.command.Add("NombreComando", {
	arguments = { ix.type.player, ix.type.number },
	description = "@clave_lenguaje",
	adminOnly = true,
	OnRun = function(self, client, ...)
		-- lógica
	end
})

Plugins (plugins/mi_plugin/sh_plugin.lua)
lua

PLUGIN.name = "Nombre del Plugin"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Qué hace este plugin."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

Hooks
lua

-- Schema hooks: function Schema:NombreHook(...)
-- Plugin hooks: function PLUGIN:NombreHook(...)
-- Hook de GMod nativo: hook.Add("NombreHook", "identificador", function(...) end)

Variables de personaje
lua

ix.char.RegisterVar("miVariable", {
	field = "mi_variable",
	fieldType = ix.type.number,
	default = 0
})
-- Acceso: character:GetMiVariable() / character:SetMiVariable(valor)

Config (ix.config.Add)
lua

ix.config.Add("efgMiConfig", 1, "Descripción en español. [VERIFICAR]", nil, {
	data = { min = 0, max = 10 },
	category = "raid"   -- "raid", "mapa", "salud", "armas", "inventario", "economia", "escondite", "karma", "servidor"
})

    Los valores pendientes de contrastar con la wiki de EFT se marcan con [VERIFICAR] en la descripción.

    Todo se cambia en partida desde /OpenHelixMenu → Configuración o con ix.config.Set.

    Cualquier config de Metro que sobreviva en ix.config debe retirarse o renombrarse con prefijo efg.

Reglas de estilo de código

    Indentación: tabulaciones (\t), no espacios.

    Strings: comillas dobles "texto"; comillas simples solo para casos especiales.

    Comparaciones: == y != (GLua acepta != como ~=).

    Paréntesis en condiciones: if (condicion) then — siempre incluir paréntesis.

    No comentar código obvio; comentar solo lógica no trivial.

    Constantes de facciones/clases (FACTION_X, CLASS_X) siempre al final del archivo.

    Usar item (instancia) y no ITEM (plantilla) dentro de callbacks de ítems.

    Localización: preferir claves L("clave") en lugar de strings hardcodeadas en el cliente. En el servidor, client:NotifyLocalized("clave").

    Sin referencias a Metro: ningún texto, comentario o config nuevo debe mencionar estaciones, facciones de Metro o "balas pre-guerra".

Seguridad GLua

    Siempre verificar IsValid(entidad) antes de llamar métodos en entidades.

    Siempre verificar client:GetCharacter() antes de llamar sus métodos — puede devolver nil.

    Nunca usar table.contains (no existe en GLua) → usar table.HasValue.

    Los timers por jugador deben eliminarse en PlayerDisconnected.

    No llamar GetCharacter() dentro de PlayerInitialSpawn — el personaje aún no está cargado.

Fallos comunes (gotchas verificados)

Errores reales encontrados en este proyecto. Revisar siempre antes de dar por bueno un plugin con entidades o interfaces.
Orden de carga de un plugin (Helix)

Al cargar un plugin, Helix ejecuta en este orden: languages/ → libs/ → factions/ → items/ → plugins/ → derma/ → entities/ → y al final sh_plugin.lua. El plugin NO se registra en ix.plugin.list hasta después de sh_plugin.lua.

    ix.plugin.Get("mi_plugin") devuelve nil en el scope superior de derma/ y entities/ (se ejecutan antes del registro). Consecuencia: capturar local PLUGIN = ix.plugin.Get(...) ahí guarda nil para siempre y cualquier uso posterior (ej. net.Start(PLUGIN.netX)) crashea silenciosamente → la UI nunca abre.

        Derma: envolver todo el archivo en timer.Simple(0, function() local PLUGIN = ix.plugin.Get("...") ... end).

        Entidades: obtener el plugin en runtime dentro del método (ej. al inicio de ENT:Use), nunca en el scope del archivo.

    Pon fuentes/config que el derma necesite en libs/ (cargan antes).

    Helix ya auto-incluye derma/; no hace falta ix.util.IncludeDir(".../derma") en cl_plugin.lua (es redundante).

    La estructura de entidades es entities/entities/<clase>/{init,cl_init,shared}.lua (doble entities/ a propósito).

Orden de los hooks entre plugins

    Helix guarda los hooks de plugin en HOOKS_CACHE[nombre][PLUGIN] y los recorre con pairs: el orden entre plugins NO es alfabético y gana el primer valor no nulo. Ningún hook con return (PlayerUse, CanTransferItem, ShouldSpawnPlayerCorpse...) puede depender de qué plugin corre antes. Para secuenciar, usar timer.Simple(0) o una marca en la entidad que el otro plugin respete.

Paneles (VGUI / derma)

    Los paneles hijos se recortan (clip) a los límites del padre por defecto. Posicionar un hijo fuera del padre (ej. panel:SetPos(0, parent:GetTall())) lo deja invisible. Para mostrar un sub-panel, colócalo dentro del área visible del padre y usa MoveToFront(); si necesita salirse, usa panel:NoClipping(true).

    ix.plugin.Get("metroui"):GetFontInternal(id) devuelve el nombre de fuente del plugin metroui (ej. "Metro UI.Button"). Las UIs del schema dependen de metroui — comprobar if (not PLUGIN_UI) then return end.

    LerpColor, SScale, VScale, SScaleMin son globales definidas por metroui (en if CLIENT), no de GMod.

    Toda lógica de panel debe ir tras vgui.Register(...); un error en el cuerpo del archivo derma antes del register impide registrar la clase y vgui.Create devolverá nil.

Persistencia (PermaProps, workshop 220336312)

    PermaProps sí guarda Material (GetMaterial), SubMat (GetSubMaterial), Color, Skin, BodyG en su snapshot, pero solo en el momento de guardar.

    Si cambias el material después de permapropear, hay que actualizar el snapshot: apuntar con la PermaProps tool y pulsar R (Reload/Update) → ejecuta UPDATE en SQL.

    Materiales client-side (PAC3, proxies) NO se guardan (GetMaterial server-side los ignora). Para esos casos, usar los hooks PermaProps.OnEntitySaved (devuelve tabla extra a guardar) y PermaProps.OnEntityCreated(ent, data) (restaurar).

Reglas específicas por tipo de archivo
Facciones (schema/factions/**/*.lua)

    La constante FACTION_X se asigna al final del archivo, después de todos los campos.

    En EFG los bandos de PMC (USEC, BEAR) y Scav no se eligen con isDefault; la elección es del creador de PMC. FACTION.isDefault = true solo si algún flujo de Helix lo exige, y entonces apunta a USEC o BEAR, nunca a una facción de Metro.

    Equipo inicial: FACTION:OnCharacterCreated(client, character) o, para PMC, el kit del rol (PMC.BuildKit).

    Descripciones en español, tono coherente con el lore de Tarkov.

Ítems (schema/items/**/*.lua)

    Dentro de cualquier callback (OnRun, OnEquip, etc.) usar siempre item (instancia), nunca ITEM.

    return true en OnRun elimina el ítem del inventario; return false lo conserva.

    ITEM.noBusiness = true si el ítem no debe aparecer en tiendas.

    ITEM.noLoot = true si no debe caer al cadáver (loot_on_death).

    Acceder al jugador con item.player (no ITEM.player).

    Proteger valores vitales: client:SetHealth(math.min(client:Health() + 20, client:GetMaxHealth())).

    Categorías comunes: "Consumibles", "Equipamiento", "Medicamentos", "Recursos", "Armas".

    Las mochilas nuevas van en plugins/metrobags/items/metrobags/ y solo pueden heredar de bases de plugins que carguen antes (orden alfabético).

Plugins (plugins/**/*.lua)

    Usar PLUGIN:NombreHook(...) para hooks del framework (no Schema:).

    PLUGIN.author = "Metro RP By Cono y Manperra" en todos los plugins.

    Incluir sub-archivos con ix.util.Include("cl_plugin.lua") y ix.util.Include("sv_plugin.lua").

    Comandos en archivo shared: definir ix.command.Add siempre en un archivo sh_ (ej. sh_commands.lua) para que aparezcan en el autocompletado del chat del cliente. Nunca definir comandos solo en sv_plugin.lua.

    Net strings: declarar con util.AddNetworkString("Nombre") en sv_plugin.lua antes de usarlas.

    Timers por jugador: limpiar en PLUGIN:PlayerDisconnected(client).

    No hardcodear strings visibles al jugador; usar client:NotifyLocalized("clave").

    Lógica exclusiva de servidor en sv_plugin.lua; lógica de cliente en cl_plugin.lua.

Hook del framework vs hook de GMod nativo
lua

-- Framework Helix (en PLUGIN o Schema)
function PLUGIN:CharacterLoaded(character) end

-- GMod nativo (con hook.Add)
hook.Add("PlayerSpawn", "MiPlugin_Spawn", function(client) end)

Contexto del lore (Escape from Tarkov)

El juego transcurre en la región de Tarkov (Rusia) tras el colapso de la ciudad por la guerra corporativa entre TerraGroup y las fuerzas del gobierno, que llevó al cierre de las fronteras y a la intervención de dos compañías militares privadas:

    USEC (United Security): PMC contratada por TerraGroup para proteger sus intereses. Bando jugable.

    BEAR (Battle Encounter Assault Regiment): PMC rusa, exmilitar, enviada a investigar las actividades de TerraGroup. Bando jugable.

    Scavs: saqueadores locales sin afiliación, divididos en bandas con jefes (Reshala, Killa, Tagilla, Shturman, Glukhar, Kaban, Kollontay, Zryachiy, Goons, Partisan...).

    Raiders, Rogues, Cultistas: facciones de IA hostiles (Reserva, Costa, Faro, etc.).

    Comerciantes: Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman, Jaeger. La lealtad (LL) va de 1 a 4 y la limita el nivel del PMC.

    Escondite (Hideout): base segura del PMC, con módulos mejorables (Alijo, Generador, Banco de trabajo, Estación médica, Zona de descanso, Centro de inteligencia, Scav Case, Granja de bitcoin...).

    Raid: incursión en un mapa (Aduanas, Fábrica, Bosque, Costa, Intercambiador, Reserva, Faro, Calles de Tarkov, Zona cero, Laboratorio) con tiempo limitado y varias extracciones.

    Extracción: hay extracciones fijas (siempre), aleatorias, de pago, sin mochila y de interruptor. Si no extraes a tiempo → MIA y pierdes lo no asegurado.

    Scav run: entras como Scav con equipo aleatorio sin arriesgar al PMC. Tiene espera entre partidas y depende del karma con Fence.

    Moneda: rublos (RUB), dólares (USD) y euros (EUR). El objeto interno de dinero conserva el ID bala por herencia de Metro (ver Legacy de Metro); de cara al jugador son rublos. El símbolo ₽ no existe en Bender, así que los precios se escriben en RUB.

    Wipe: reinicio periódico de personajes (efgWipeID, efgWipeMoney, /EFGWipe CONFIRMAR).

Herramientas de desarrollo
Script	Para qué
tools/compilar.bat	Copia el schema y Helix a gamemodes y empaqueta content/ en un .gma
tools/glua_check.py	Chequeo de sintaxis GLua sin GMod (traduce !=, &&, //... y compila con LuaJIT vía lupa): python3 tools/glua_check.py plugins schema
tools/gen_efgui.py	Genera las texturas de content/materials/efgui/ con PIL
tools/recolor_eft.py	Pasa tonos sepia de Metro a la paleta de EFT
tools/mdlinfo.py	Vuelca secuencias, eventos y skins de un .mdl
tools/cargadores/	Genera los cargadores de efg_mags desde la wiki de EFT
tools/novedades.py	Genera la imagen de novedades del commit (ver arriba)
Comandos y agentes disponibles

Usa / para invocar los comandos personalizados del proyecto:
Comando	Descripción
/nueva-faccion	Crear una nueva facción completa
/nuevo-item	Crear un nuevo ítem para el inventario
/nuevo-plugin	Crear un plugin completo
/debug-glua	Diagnosticar y corregir errores GLua
/revisar-codigo	Revisar código antes de publicar al servidor
/localizar-strings	Gestionar cadenas de idioma (sh_english.lua)

Sub-agentes especializados disponibles vía Agent tool:
Agente	Uso
glua-reviewer	Revisión de código con alta señal/ruido
content-writer	Redacción de lore, descripciones y mensajes
metrorp-dev	Desarrollo general del schema y plugins de EFG
text


---

## Resumen de lo que incluye este `CLAUDE.md`

- **Descripción del proyecto** como conversión total, con el estado "sin probar en partida" y la marca `[VERIFICAR]`.
- **Sección "Legacy de Metro"** explícita: qué sobrevive, por qué y qué tarea pendiente tiene (carpeta, `bala`, `metroui`, plugins genéricos, `_retirados/`).
- **Estructura de carpetas** con `content/`, `_retirados/`, `tools/` y la nota de que la carpeta del gamemode sigue siendo `metrorp`.
- **Bandos** USEC/BEAR/Scav/Staff y la regla de que no hay facción por defecto (o USEC/BEAR si un flujo de Helix lo exige).
- **Inventario completo de plugins** agrupado como en el README: raid, salud, armas, inventario, PMC/progresión, economía, escondite, interfaz, administración, otros activos y retirados.
- **Regla obligatoria de novedades** por commit, con JSON, PNG, README y enlace al PR.
- **Reglas de interfaz**: un solo TAB, Bender, paleta `ix.efgui.color`/`--efg-*`, Chromium 86, RUB, posición por `inv.slots`.
- **Patrones de la API de Helix**: facciones, clases, ítems, atributos, comandos, plugins, hooks, variables de personaje y configs con prefijo `efg`.
- **Reglas de estilo**, **seguridad GLua** y **gotchas verificados** (orden de carga, `ix.plugin.Get` en `derma/`/`entities/`, clipping, PermaProps, metroui).
- **Reglas por tipo de archivo** (facciones, ítems, plugins) y la regla de comandos en `sh_`.
- **Lore de Tarkov**: USEC/BEAR, Scavs, jefes, comerciantes, escondite, raid, extracción, MIA, Scav run, karma, moneda, wipe.
- **Herramientas** y **comandos/agentes** del proyecto.
