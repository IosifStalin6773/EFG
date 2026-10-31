# EFG: Escape from Gmod — Instrucciones para Claude

## Descripción del proyecto

**EFG (Escape from Gmod)** es un schema de extracción al estilo *Escape from Tarkov* para Garry's Mod, construido sobre el framework **[Helix](https://github.com/nebulouscloud/helix)**. Mantenido por **Metro RP By Cono y Manperra** (Navarro, Mancera, xMeeKo). Nació del schema de rol *Metro RP 2033* y se ha reconstruido entero alrededor del ciclo de EFT: preparas a tu PMC en el escondite, entras en una raid, sobrevives, saqueas y extraes (o lo pierdes todo).

- **Lenguaje**: GLua (Lua 5.1 de Garry's Mod) sobre la API `ix.*` de Helix.
- **Idioma del juego**: español.
- **Moneda**: rublos (el objeto interno sigue llamándose `bala`), más dólares y euros.
- **Bandos**: USEC y BEAR (PMC), Scav (Scav run) y Staff.
- **Framework**: Helix (`ix.*`).

---

## Estructura de carpetas

La carpeta del gamemode **tiene que llamarse `metrorp`** (así se llama `metrorp.txt`), aunque el proyecto se llame EFG. El contenido propio vive en `content/`, que GMod monta solo desde la carpeta del gamemode.

metrorp/ # carpeta del gamemode
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
├── content/ # contenido propio que se manda a los clientes
│ ├── materials/ # efg/, efgui/, eftwiki/
│ ├── models/
│ ├── sound/
│ ├── resource/ # fuente Bender
│ └── data_static/ # eft_items.json
├── tools/ # scripts de desarrollo
├── _retirados/ # plugins y facciones de Metro que ya no se cargan
├── metrorp.txt # descriptor del gamemode (carpeta "metrorp")
├── COMANDOS.md
└── CLAUDE.md
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

El bando de un PMC se elige en el creador (`efg_pmc`, `efgPMCCreator`), no con `isDefault`. Un PMC por cuenta y nombre único (validado en `CanPlayerCreateCharacter` + `PMC.ValidateCreation`). El equipo inicial lo pone el rol (Asaltante, Tirador, Médico) en `OnCharacterCreated` vía `PMC.BuildKit`.

---

## Plugins principales de EFG

Agrupados como en el README. Cada plugin tiene su carpeta en `plugins/`.

### Raid y mapas
`efg_raids` (ciclo de raid, extracciones, MIA, Run Through, XP/nivel, grupos, Scav run), `efg_maps` (10 localizaciones, reloj acelerado, clima, llaves, puertas con llave), `efg_ai` (zonas VJ Base: Scavs, PMC, jefes), `efg_karma` (karma Scav con Fence), `efg_menus` (pantallas de flujo), `efg_server` (wipe, PvE/PvP, cola de grupo, anticheat de velocidad y saqueo, descarga de contenido y colección, autodiagnóstico), `efg_guard` (anticheat de red), `efg_testcycle` (registro y test del ciclo de raid).

### Salud y estado
`efg_health` (440 en partes, sangrados, fracturas, dolor, chalecos/cascos en `ScalePlayerDamage`, botiquines y SWEP `efg_med`), `efg_physio` (sangre, tensión, SpO2, neumotórax, vía aérea, inconsciencia, parada, grupos sanguíneos; `/RCP`), `efg_status` (hidratación y energía), `efg_effects` (estimulantes, fatiga, radiación, alcohol), `anims_meds` (comidas y bebidas).

### Armas y combate
`efg_arc9` (registra cada arma ARC9 de EFT como ítem), `efg_ballistics` (munición por calibre, penetración y blindaje de EFT, rebotes), `efg_mags` (cargadores como objetos), `efg_mods` (accesorios por ranura), `efg_weapons` (desgaste, encasquillamientos, reparación), `efg_inspect` (inspección y modding ARC9 estilo EFT), `arc9_support`, `wepraised`.

### Equipo e inventario
`ix_invkey` (TAB, ranuras de casco/chaleco/mochila/contenedor seguro, armas, pestañas), `efg_invgrid` (pestaña EQUIPO en VGUI, `efgInvEFT`), `efg_invhtml` (inventario DHTML, `efgInvHTML`), `efg_invrules` (rotación, FIR, examinar, tiempo de búsqueda), `efg_gear` (chalecos, cascos, placas, mochilas, contenedores seguros, tácticos; `libs/sh_armor.lua` define `ix.efg.armor.Setup`), `efg_outfits` (PMC modulares, `/Atuendo`), `efg_icons` (iconos 2D y rareza), `efg_eftdata` (base de datos de EFT), `efg_quickbar` (1-5), `efg_radial` (menú Z), `efg_insurance` (seguro), `strongbox` (alijo 10x30), `metrobags` (bases de mochilas), `weight`, `loot_on_death`, `loot` (botín por zonas).

### PMC, progresión y perfil
`efg_pmc` (creador de PMC en 5 pasos, cosméticos, voces, `efgLobby`), `efg_profile` (estadísticas + pestañas GENERAL / HABILIDADES / LOGROS), `efg_progression` (curva de 79 niveles de EFT y XP), `habilidades` (perks que suben con el uso).

### Economía y comerciantes
`traders` (Prapor, Therapist, Fence, Skier, Peacekeeper, Mechanic, Ragman, Jaeger; LL 1-4 limitada por nivel de PMC; stock y reposición; pantalla EFT `efgxTrader`; `tradersEFTUI = false` vuelve a las ventanas antiguas), `efg_economy` (USD/EUR, reparación, dogtags), `efg_flea` (mercadillo desde nivel 15), `efg_quests`, `efg_tasks`, `missions`, `efg_messages`, `intercambio`, `trader_logs`, `money_items`, `economia_monitor`.

### Escondite
`efg_hideout` (módulos principales; sustituye a los oficios: el oficio de una receta es el módulo y `tierRequired` su nivel), `efg_hideout_extra` (resto de módulos de EFT), `efg_production` (fabricación con tiempo), `metrocrafting` (mesas colocables).

### Interfaz
`efg_ui` (paleta `ix.efgui.color`, utilidades, fuentes `efgui.*` en Bender, CSS común `--efg-*`, `resource.AddFile` de `content/`), `efg_hud` (HUD de EFT, cursor, barra de acción, etiquetas), `fix_hud_arc.lua`.

### Administración
`efg_admin` (dinero, nivel, XP, lealtad, tareas, tiempo de raid).

**Otros plugins activos** (heredados de Metro o genéricos): `adminchat`, `ambient_music`, `antibhop`, `area_visualizer`, `better_armor`, `bodygroupmanager`, `cleaner`, `contextmenu`, `disable_zoom`, `extracommands`, `flashlightitem`, `helix_menu`, `help_comandos`, `hidevoicepanels`, `legs`, `metroui`, `needs`, `npc_custom`, `npc_obstacle_jump`, `npc_presets`, `npc_stepheight`, `observer_enhanced`, `persistent_corpses`, `puertas`, `puertas_brecheables`, `ranks`, `sh_adverts`, `simpleradio`, `spawnmenu_itemtab`, `thirdperson`, `tposefixer`, `vigilancia`, `vision_nocturna`, `vmanip_port`, `voicerevamped`.

**Retirados** (en `_retirados/`, no se cargan): ANIM_INV, TABANIM, community_missions, tablon_encargos, generadores, new_wepselect, ix_cwsupport, HUD de Metro, cartas, pasaportes, temperatura y las facciones de Metro.

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
- **Bender no tiene el signo ₽**: los precios se escriben en RUB.
- **Cliente de Helix**: los objetos no tienen `gridX`/`gridY` en el cliente; la posición es la celda de `inv.slots` donde están guardados.

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

Reglas de estilo de código

    Indentación: tabulaciones (\t), no espacios.

    Strings: comillas dobles "texto"; comillas simples solo para casos especiales.

    Comparaciones: == y != (GLua acepta != como ~=).

    Paréntesis en condiciones: if (condicion) then — siempre incluir paréntesis.

    No comentar código obvio; comentar solo lógica no trivial.

    Constantes de facciones/clases (FACTION_X, CLASS_X) siempre al final del archivo.

    Usar item (instancia) y no ITEM (plantilla) dentro de callbacks de ítems.

    Localización: preferir claves L("clave") en lugar de strings hardcodeadas en el cliente.

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

    En EFG los bandos de PMC (USEC, BEAR) y Scav no se eligen con isDefault; la elección es del creador de PMC. FACTION.isDefault = true solo si alguna facción debe ser la inicial del schema.

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

Config (ix.config.Add)
lua

ix.config.Add("efgMiConfig", 1, "Descripción en español.", nil, {
	data = { min = 0, max = 10 },
	category = "raid"   -- "raid", "mapa", "salud", "armas", "inventario", "economia", "escondite", "karma", "servidor"
})

    Los valores pendientes de contrastar con la wiki de EFT se marcan con [VERIFICAR] en la descripción.

    Todo se cambia en partida desde /OpenHelixMenu → Configuración o con ix.config.Set.

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

    Moneda: rublos (RUB), dólares (USD) y euros (EUR). El objeto interno de dinero sigue llamándose bala por herencia de Metro; el símbolo ₽ no existe en Bender, así que los precios se escriben en RUB.

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

## Notas sobre la adaptación

- **Carpeta `metrorp`**: aunque el proyecto se llama EFG, la carpeta del gamemode debe seguir llamándose `metrorp` porque `metrorp.txt` es el descriptor. Lo he mantenido explícito para evitar confusiones.
- **Moneda**: el objeto interno de dinero sigue llamándose `bala` por herencia de Metro, pero de cara al jugador son rublos (RUB). Lo he dejado claro.
- **Facciones**: he quitado las 9 facciones de Metro y he puesto las de EFG (USEC, BEAR, Scav, Staff). No he inventado cuál es "default"; lo dejo como nota.
- **Plugins**: he sustituido la tabla de plugins de Metro por la lista del README de EFG, agrupada igual que allí.
- **Gotchas y reglas técnicas**: intactos (orden de carga, clipping, PermaProps, DHTML Chromium 86, seguridad GLua, estilo).
- **Novedades**: la regla obligatoria de la imagen por commit se mantiene tal cual, porque sigue siendo un requisito del repo.
- **Lore**: reemplazado el lore de Metro 2033 por el de Tarkov (USEC/BEAR, scavs, jefes, comerciantes, escondite, raid, extracción, wipe).
