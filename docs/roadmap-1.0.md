# EFG 1.0: roadmap de lanzamiento

Estado a **1 de noviembre de 2026**, sacado de `main` (`efd30e5`, tras fusionar #87 y #89) y de las issues abiertas del repo. Sustituye como guía de lanzamiento a `docs/roadmap/` (F0-F4 hacia el gameplay de EFT); las issues #8-#31 siguen vivas y aquí se reordenan dentro de las fases de 1.0.

**Objetivo de 1.0**: un servidor público de 24-32 jugadores en `EFG_Mapa_v0_1` que aguanta un wipe completo (semanas) sin errores de Lua, sin pérdida de datos de personaje ni alijo, con el ciclo escondite → raid → extracción → venta → mejora cerrado y equilibrado, y que un jugador nuevo instala desde la colección del Workshop sin pasos manuales.

---

## 1. Auditoría del estado actual

### Cifras del repo

| Métrica | Valor |
|---|---|
| Archivos `.lua` (sin `_retirados/`) | 637, unas 92.600 líneas |
| Plugins cargados | 86 carpetas o archivos, 46 de ellos `efg_*` |
| Sintaxis (`tools/glua_check.py plugins schema`) | 635 archivos, 0 errores |
| `util.AddNetworkString` / `net.Receive` | 166 / 190 |
| `net.WriteTable` | 26 usos |
| Hooks `Think`/`Tick` | 46 (16 `hook.Add("Think")` en cliente) |
| `HUDPaint` | 36 |
| `ents.FindIn*` / `player.GetAll()` | 48 |
| `timer.Create` | 46 |
| `SetNetVar` / `SetLocalVar` | 104 |
| Paneles DHTML | 18 archivos |
| Valores `[VERIFICAR]` | 23 en código (la issue #31 hablaba de 55) |
| Archivos con el signo `₽` (Bender no lo tiene) | 6 |
| Archivos cliente de más de 60 KB | `traders/cl_plugin.lua` 111 KB, `ix_invkey/cl_plugin.lua` 104 KB, `loot/cl_plugin.lua` 70 KB |
| CI (`.github/workflows`) | No existe |
| Issues `roadmap` abiertas | 26 (#8-#31, #65, #67) |
| PRs abiertos | 0 |

### Implementado

| Área | Estado | Probado en juego |
|---|---|---|
| Ciclo de raid (`efg_raids`): despliegue, temporizador, 5 tipos de extracción, MIA, Run Through, grupos, Scav run | Código completo | Solo con `/EFGTestCiclo` (bot), no con jugadores |
| Mapas y reloj (`efg_maps`): 10 localizaciones como datos, clima, llaves | Datos | No: solo existe `EFG_Mapa_v0_1`, sin raid montada (#9) |
| IA (`efg_ai`, `efg_loot_ai`) | Código completo | No: VJ Base fuera de la colección (#8), clases de jefe supuestas |
| Salud por partes + fisiología KAT (`efg_health`, `efg_physio`, `efg_status`, `efg_effects`) | Completo | Sí (31 oct) |
| Armas: ARC9, balística, cargadores, mods, desgaste, inspección | Completo | Parcial |
| Inventario: TAB, rejillas, chalecos con bolsillos, acceso rápido, FIR, alijo | Completo, **dos UIs en paralelo** (`efg_invgrid` VGUI y `efg_invhtml` DHTML, #10) | Sí |
| Loot de contenedores y cadáveres (`efg_loot`, `efg_loot_ai`, `efg_loot_ui`, fases 0-4) | Completo | Parcial |
| Economía: 8 comerciantes LL1-4, USD/EUR, mercadillo, seguro, tareas (10 iniciales) | Completo, sin trueques (#18) ni árbol de tareas (#17) | Parcial |
| Escondite: módulos, producción con tiempo | Completo | Parcial |
| PMC: creador de 5 pasos, perfil, progresión de 79 niveles, habilidades | Completo | Sí |
| UI: kit `efg_ui`, HUD, menús, pantalla de carga, menú de GMod | Completo | Sí |
| Servidor: wipe, PvE/PvP, cola, anticheat de velocidad y saqueo, `efg_guard` (límite de red por jugador) | Código | No bajo carga |
| Gamemode renombrado a `escapefromgmod` con migración de BD (`sv_rename.lua`) | Fusionado (#87-#89) | **No**: la migración de `ix_characters.schema` y `data/helix/` no se ha probado sobre una BD real |

### Lo que un proyecto de este calibre necesita y aún falta

| Necesidad | Situación |
|---|---|
| **Una partida real de 2-4 jugadores de principio a fin** | No ha ocurrido. Todo el resto depende de esto (#11). |
| **Contenido jugable mínimo** | Un mapa sin spawns, extracciones, zonas de IA ni loot colocados. |
| **Sistemas duplicados** | `loot` (congelado) y `efg_loot`; `needs` y `efg_status`; `efg_invgrid` y `efg_invhtml`; `mesa_crafteo` y `efg_production`. Doble coste de CPU, doble superficie de bugs y hooks con `return` que compiten. |
| **Presupuesto de red y CPU** | Sin medir. 26 `net.WriteTable`, 104 netvars, 46 Think/Tick y 48 búsquedas de entidades sin perfilar. |
| **Validación de `net.Receive`** | `efg_guard` limita el ritmo, pero no hay un patrón común de validación (personaje, distancia, estado de raid, propiedad del objeto). |
| **Persistencia segura** | Sin copias de seguridad automáticas de la BD ni prueba de reinicio con jugadores dentro de raid. |
| **Deuda legacy** | `menu_ui` sigue siendo dependencia de las UIs; `npc_presets`, `npc_stepheight` y `flashlightitem` aún hablan de Metro 2033; `₽` en 6 archivos. |
| **QA y automatización** | Sin CI. Hay chequeo de sintaxis y `/EFGTestCiclo`, pero no se ejecutan solos. |
| **Balance** | 23 `[VERIFICAR]`, precios sin referencia (#22), un único árbol de tareas inicial. |
| **Release** | Sin `.gma` del gamemode publicado, sin página del Workshop, sin guía de servidor, sin versión ni changelog por release. |

---

## 2. Fases de desarrollo

Línea temporal orientativa (semanas desde hoy, para un desarrollador con Claude). Cada fase tiene una **puerta**: no se empieza la siguiente sin cumplir el DoD de la anterior, salvo las tareas marcadas *en paralelo*.

```
Nov 2026         Dic 2026            Ene 2027          Feb 2027          Mar 2027
|-- F0 Núcleo --|-- F1 Red y rend. --|-- F2 Contenido y balance --------|
                |-- F3 UI/UX (en paralelo desde F1) ----------|
                                                         |-- F4 Beta cerrada --|-- RC --|-- 1.0
```

| Fase | Semanas | Hito | Salida |
|---|---|---|---|
| F0 Núcleo y estabilización | 1-3 | Primer ciclo completo con jugadores | `0.1.0-alpha` |
| F1 Red y rendimiento | 4-6 | 16 jugadores a 66 tick sin tirones | `0.2.0-alpha` |
| F2 Contenido y balance | 6-12 | Un wipe de 2 semanas jugable | `0.5.0-beta` |
| F3 UI/UX | 5-11 (paralelo) | Un solo camino de UI, sin legacy | incluida en `0.5.0` |
| F4 Release y despliegue | 12-16 | Beta cerrada, RC, Workshop | `1.0.0` |

### F0. Núcleo y estabilización

**Objetivos**
- Cerrar un ciclo real (crear PMC → escondite → raid → saquear → extraer o morir → vender → mejorar) con 2-4 jugadores en `EFG_Mapa_v0_1`.
- Un solo sistema por responsabilidad.
- Consola de servidor y cliente sin errores en todo el ciclo.

**Tareas técnicas**
1. **Probar la migración del renombrado** en una copia de la BD real: arrancar `+gamemode escapefromgmod`, comprobar que `ix_characters.schema` y `data/helix/` pasan y que los alijos (`strongbox`) y el seguro conservan los objetos. Guardar el dump previo.
2. **VJ Base en la colección y clases reales** (#8): `/IAClases` en el servidor, sustituir los nombres de jefe supuestos de `efg_ai` por los reales, una tabla de clases en datos (no en `if`).
3. **Montar la raid en el mapa** (#9): spawns PMC/Scav, 4-6 extracciones de los 5 tipos, zonas de IA, contenedores de loot. Todo en `data/` persistente o en un archivo de datos por mapa versionado en el repo (`plugins/efg_maps/maps/<mapa>.lua`), no solo en la BD, para que sobreviva a un wipe.
4. **Un solo inventario del TAB** (#10): quedarse con `efg_invgrid` (VGUI, ya probado); mover `efg_invhtml` a `_retirados/` y quitar el config `efgInvHTML`.
5. **Retirar duplicados**: congelar y desactivar `loot` (lo sustituye `efg_loot`), `needs` (lo sustituye `efg_status`) y decidir `mesa_crafteo` frente a `efg_production`. Cada retirada en su PR con búsqueda de referencias cruzadas (`grep` del nombre del plugin, sus netvars y sus hooks).
6. **Auditoría de hooks con `return`** (`PlayerUse`, `CanTransferItem`, `PlayerCanPickupItem`, `ShouldSpawnPlayerCorpse`, `PlayerLoadout`, `EntityTakeDamage`, `ScalePlayerDamage`): listar qué plugins devuelven valor en cada uno. Si dos plugins devuelven, unificar en uno o encadenar con una marca en la entidad (ver gotcha de `HOOKS_CACHE`).
7. **Partida de prueba del ciclo** (#11) tres veces, con `efg_testcycle` registrando. Cada error de consola se convierte en issue con etiqueta `bug`.
8. **Quitar `₽`** de los 6 archivos (`efg_inspect`, `efg_tasks/cl_html.lua`, `menu_ui/derma/cl_mainmenu.lua`, `efg_menus`, `efg_admin`, `efg_raids/cl_plugin.lua`) y poner `RUB`.

**Definition of Done**
- [ ] 3 partidas seguidas de 2-4 jugadores sin un solo error Lua en consola de servidor ni de cliente (`lua_error` vacío, log de `efg_testcycle` con todos los pasos PASS).
- [ ] Migración probada sobre una copia de la BD real sin pérdida de personajes ni alijos.
- [ ] `loot`, `needs`, `efg_invhtml` (y el perdedor de crafteo) fuera de `plugins/`.
- [ ] Tabla de hooks con `return` documentada en `docs/hooks.md`, sin conflictos abiertos.
- [ ] Issues #8, #9, #10 y #11 cerradas. Tag `v0.1.0-alpha`.

### F1. Red y rendimiento

**Objetivos**
- Presupuesto medido y respetado: 16 jugadores (objetivo 1.0: 24-32) más IA activa sin bajar de 66 tick en el servidor y sin tirones de FPS por Lua en el cliente.
- Ningún `net.Receive` confía en el cliente.

**Tareas técnicas**
1. **Medir antes de optimizar**: FProfiler (o `debug.sethook` con contador) en servidor y cliente durante una raid de 16 bots + IA. Tabla de los 20 hooks más caros en `docs/rendimiento.md`.
2. **Think/Tick del cliente** (16 `hook.Add("Think")`): pasar los que leen teclas (`ixEFGInventoryKey`, `NVG_KeyPress`, `VoiceRevamped_CommaKey`, `ThirdPerson_KeyToggle`) a `PlayerButtonDown` o a `ix.efg.binds`; los que actualizan modelos (`efgOutfits`, `efgPMCCosmetics`) a intervalos de 0,2-1 s o a eventos (`OnCharacterVarChanged`, netvar cambiada).
3. **Búsquedas de entidades** (48 `ents.FindIn*`/`player.GetAll()`): sacar de Think las que se pueden cachear; en servidor, una sola pasada por tick compartida (lista de jugadores en raid mantenida por `efg_raids`) en vez de que cada plugin recorra todos.
4. **`net.WriteTable`** (26): sustituir por escritura tipada (`WriteUInt`, `WriteString`, `WriteFloat`) en los mensajes frecuentes; en los grandes (inventario del cadáver, stock de comerciante, mercadillo) usar `util.TableToJSON` + `util.Compress` y `net.WriteData`, con trozos de menos de 60 KB.
5. **Netvars** (104): auditar cuáles se mandan a todos (`SetNetVar`) y deberían ser locales (`SetLocalVar`): salud por partes, fisiología, estado y peso solo los necesita el dueño y, en parte, su grupo. Los monitores de `efg_physio` (`efgVitals`) pasar a petición.
6. **Validación de red común**: una función `ix.efg.net.Guard(client, opts)` en `efg_guard` (personaje cargado, vivo, en raid o no, distancia máxima a la entidad, propiedad del inventario, cooldown por mensaje). Aplicarla en los 190 `net.Receive`, empezando por los que mueven objetos o dinero (`efgLootWinMove`, `traders_SellItems`, mercadillo, intercambio, producción).
7. **Inventario y saqueo**: sincronizar deltas de inventario en vez de inventarios enteros; la ventana de saqueo ya manda el inventario al acabar la búsqueda, extender el patrón a alijo y comerciantes.
8. **Paneles DHTML** (18): un solo `DHTML` vivo por pantalla, destruirlo al cerrar el TAB, no recrear en cada cambio de pestaña. Medir memoria del CEF tras 20 aperturas.
9. **Archivos cliente enormes** (`traders/cl_plugin.lua` 111 KB, `ix_invkey/cl_plugin.lua` 104 KB, `loot/cl_plugin.lua` 70 KB): partir por responsabilidad. Cada `AddCSLuaFile` cuenta para el tiempo de conexión y el límite de la tabla de strings de Lua del cliente.
10. **Persistencia**: guardar inventarios y estadísticas en lotes (cada N s y al salir de raid) y no en cada cambio; `PlayerDisconnected` y `ShutDown` hacen un guardado final.

**Definition of Done**
- [ ] Prueba de 16 jugadores (o bots con `/EFGTestCiclo`) + IA durante 30 min: tick del servidor ≥ 60 de media y sin picos por encima de 50 ms en `net_graph`/`sv_stats`.
- [ ] Ningún hook de cliente por encima de 0,3 ms de media en el perfil; ninguno de servidor por encima de 1 ms.
- [ ] Todos los `net.Receive` que mueven objetos, dinero o XP pasan por `ix.efg.net.Guard`; prueba manual con un cliente que manda mensajes falsos (Lua en `lua_run_cl`) sin conseguir duplicar ni robar.
- [ ] `net.WriteTable` solo en mensajes de menos de una vez por segundo.
- [ ] `docs/rendimiento.md` con la medición antes y después. Tag `v0.2.0-alpha`.

### F2. Contenido y balance

**Objetivos**
- Contenido para un wipe de 2-4 semanas: progresión de nivel 1 a ~40, comerciantes hasta LL4, escondite mejorable entero.
- Economía estable: el dinero total no se dispara ni se hunde a lo largo del wipe.

**Tareas técnicas**
1. **Combate pendiente de F1 del roadmap anterior**: granadas (#12), cuerpo a cuerpo (#13), tumbarse e inclinarse (#14), oclusión de sonido (#15), retroceso y ergonomía (#16).
2. **Árbol de tareas completo** (#17) y **trueques** (#18): primero el esquema de datos, después los datos que pase oscar (regla del proyecto: no inventar datos de EFT).
3. **Balance de economía** con `economia_monitor` y `trader_logs`: masa monetaria por jugador y día, objetos más vendidos, rublos por raid. Ajustar precios de venta, costes de seguro y del mercadillo (#22).
4. **Los 23 `[VERIFICAR]`** (#31): revisar contra la wiki con los valores que dé oscar, marcar cada uno como verificado o como decisión propia de EFG.
5. **Tablas de loot por zona** en `efg_loot/sh_loot_tables.lua`: valor esperado por contenedor y por raid, comparado con el coste del equipo medio.
6. **Escondite**: círculo sectario y muro (#19), maestría y presets (#20), habilidades y Kappa (#21).
7. **Extracciones especiales** (#23) en el mapa de 1.0. Tránsitos (#24) y Seversk (#25) **fuera de 1.0** salvo que el mapa esté listo: un segundo mapa a medias es peor que uno pulido.
8. **Optimización del mapa** (#26): areaportals, `prop_static`, `vrad` final. Objetivo: 60 FPS en un PC medio en el punto más cargado.
9. **Wipe real** (#29): procedimiento probado (`/EFGWipe CONFIRMAR`), copia previa, qué se conserva (cosméticos, nombre).

**Definition of Done**
- [ ] Un PMC nuevo llega a nivel 15 (mercadillo) en 8-12 h de juego y a LL3 con todos los comerciantes en un wipe de prueba de 2 semanas.
- [ ] La masa monetaria por jugador activo crece menos de un 20 % por semana tras la primera (medido con `economia_monitor`).
- [ ] 0 `[VERIFICAR]` sin decidir.
- [ ] Issues #12-#23, #26 y #29 cerradas o movidas explícitamente a post-1.0. Tag `v0.5.0-beta`.

### F3. UI/UX (en paralelo desde F1)

**Objetivos**
- Una sola identidad visual (Bender + `ix.efgui.color`/`--efg-*`) en todas las pantallas, sin dependencias de `menu_ui`.
- Ningún flujo exige comandos de chat a un jugador normal.

**Tareas técnicas**
1. **Retirar `menu_ui`**: mover `GetFontInternal`, `LerpColor`, `SScale`, `VScale`, `SScaleMin` y las fuentes a `efg_ui` con alias temporales; cambiar los usos; quitar el plugin.
2. **Restos de Metro**: comentarios y configs de `npc_presets`, `npc_stepheight` (`npcEFGOpenDoors` habla de "base Metro"), `flashlightitem`, sonidos `musikmetro/` en `npc_presets/cl_plugin.lua`. Revisar `mesa_crafteo/recipe/sh_blueprints_*.lua`.
3. **Localización**: pasar los textos fijos del cliente a `L("clave")` (regla de CLAUDE.md) en los archivos de UI grandes; una sola tabla de idioma por plugin.
4. **Accesibilidad de la UI**: escalado probado en 1280x720, 1920x1080 y 2560x1440; tooltips en todos los botones con icono; teclas en AJUSTES (`ix.efg.binds`) para todo lo que hoy depende de tecla fija (O extracciones, Z radial, TAB).
5. **Primera sesión del jugador**: creador → escondite con un aviso guiado (qué hacer, a quién vender) → primera raid. Pantalla de fin de raid con resumen claro (ya existe, pulir).
6. **Fondo propio en la pantalla de carga** (#65) y medicinas con arma propia (#67).
7. **Errores de UI visibles**: cualquier `vgui.Create` que devuelve `nil` o DHTML que falla se registra en log con plugin y panel, nunca un TAB en blanco.

**Definition of Done**
- [ ] `menu_ui` fuera de `plugins/`; `grep -ri metro plugins schema` solo devuelve palabras españolas (kilómetro, parámetro, pulsioxímetro).
- [ ] Un jugador que no conoce el modo completa su primera raid sin preguntar y sin escribir comandos (prueba con 2 personas nuevas).
- [ ] Capturas de las 11 pestañas del TAB en las 3 resoluciones sin solapes ni textos cortados.

### F4. Release y despliegue

**Objetivos**
- Instalación de servidor y cliente reproducible.
- Beta cerrada con jugadores externos, candidata a 1.0 y lanzamiento.

**Tareas técnicas**
1. **CI en GitHub Actions**: `glua_check.py` (instalando `lupa`) y un linter (`glualint`) en cada PR; comprobación de que no aparece `₽`, `table.contains` ni referencias al schema anterior. Bloquea la fusión si falla.
2. **Versionado**: `ix.efg.version` en el schema, mostrado en el menú y en `/EFGDiagnostico`; tags semánticos (`vX.Y.Z`); `CHANGELOG.md` generado de las imágenes de novedades.
3. **Empaquetado**: `tools/compilar.bat` produce el `.gma` de `content/` y el gamemode; se publica en el Workshop como addon de contenido + el gamemode (o un solo addon con la carpeta `gamemodes/escapefromgmod`). Revisar que no se publica nada con derechos de terceros sin permiso (texturas, sonidos y modelos extraídos de EFT).
4. **Colección del Workshop**: fijar la lista exacta de dependencias (Helix, ARC9 y packs EFT, VJ Base, PAC3 si se usa) y comprobar `resource.AddWorkshop` para todos. `/EFGDiagnostico` comprueba al arrancar que cada dependencia está montada y avisa si no.
5. **Guía de servidor** (`docs/servidor.md`): `server.cfg` recomendado (tickrate, `sv_maxrate`, `net_maxfilesize`), MySQL (mysqloo) frente a SQLite, copias de seguridad diarias de la BD y de `data/efg/`, reinicio programado.
6. **Beta cerrada** (2-3 semanas, 10-20 jugadores): canal de reporte, plantilla de issue `bug` con log, hotfix semanal.
7. **Release candidate**: congelación de funciones; solo arreglos `critica` y `alta`.
8. **Lanzamiento**: wipe inicial, anuncio, plan de hotfix de las primeras 72 h.

**Definition of Done (1.0)**
- [ ] CI verde en `main`; la fusión exige CI verde.
- [ ] Un servidor limpio se monta siguiendo solo `docs/servidor.md` en menos de 30 min.
- [ ] Beta cerrada de 2 semanas sin pérdida de datos ni crash del servidor; 0 bugs `critica` abiertos, ≤ 5 `alta` con arreglo previsto.
- [ ] 24 jugadores simultáneos con IA durante 1 h con el presupuesto de F1.
- [ ] Copia de seguridad y restauración probadas una vez.
- [ ] Tag `v1.0.0`, publicación en Workshop, imagen de novedades de la versión.

---

## 3. Gestión de riesgos

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | **Nunca se ha jugado el ciclo con personas.** 92.000 líneas probadas por partes; los fallos de integración aparecerán todos juntos. | Alta | Crítico | F0 antes que nada. Ninguna función nueva hasta cerrar #11. `efg_testcycle` en cada partida; cada error de consola es una issue. |
| R2 | **Orden de hooks entre plugins.** Helix recorre `HOOKS_CACHE` con `pairs`: con dos plugins devolviendo valor en `CanTransferItem`, `PlayerUse` o `ScalePlayerDamage`, el resultado cambia entre arranques. | Alta | Alto | Inventario de hooks con `return` (`docs/hooks.md`). Un dueño por hook; el resto escucha hooks propios (`EFGLootOpen`, `EFGHealthEvent`) que emite el dueño. Daño: `efg_health` y `efg_ballistics` en una sola cadena (balística calcula, salud aplica). |
| R3 | **Coste de Lua en el cliente.** 16 Think, 36 HUDPaint, 18 DHTML; la CPU del cliente en GMod es un solo hilo para Lua y render de VGUI. | Media | Alto | Perfil en F1; pasar a eventos; cachear materiales y fuentes; `HUDPaint` sin `surface.CreateFont`, `Material()` ni concatenaciones por frame; DHTML solo con el TAB abierto. |
| R4 | **Sincronización de inventario y duplicados.** Mover objetos entre cadáver, chaleco, alijo, comerciante e intercambio con latencia; un doble clic puede duplicar. | Media | Crítico | El servidor es la única autoridad (ya lo es en `efgLootWinMove`); bloqueo por inventario durante la transacción; `trader_logs` como detector de duplicados con alerta a staff; prueba con latencia simulada (`net_fakelag 200`, `net_fakeloss 5`). |
| R5 | **Exploits de red.** 190 `net.Receive` sin validación común; `efg_guard` solo limita el ritmo. | Media | Crítico | `ix.efg.net.Guard` en F1; revisar primero los que tocan dinero y objetos; nunca aceptar del cliente IDs de inventario ajeno ni cantidades sin comprobar. |
| R6 | **Dependencias externas** (Helix, ARC9 y packs EFT, VJ Base, PAC3, mapas propios). Una actualización del Workshop rompe el modo sin cambiar el repo. | Alta | Alto | Fijar versión de Helix en el repo; `/EFGDiagnostico` comprueba al arrancar las funciones que usamos (`ARC9`, `VJ`, `pac`); envoltorios (`efg_arc9`) para que solo un plugin hable con cada addon; plan B si un addon desaparece del Workshop (copia local con permiso del autor). |
| R7 | **Derechos de autor** del contenido extraído de EFT (iconos de la wiki, texturas de HUD, sonidos, modelos). El Workshop retira addons por DMCA. | Media | Crítico | Inventario de `content/` con origen de cada carpeta antes de publicar; sustituir lo que no tenga licencia clara; separar el contenido arriesgado en un addon aparte para no perder el gamemode si lo retiran. |
| R8 | **Persistencia y migraciones.** El renombrado, el cambio `bala` → `rublos` y los wipes tocan la BD. Un fallo pierde personajes. | Media | Crítico | Copia antes de cada arranque con migración; migraciones idempotentes y registradas (tabla de versión de esquema); prueba de restauración en F4. |
| R9 | **Límites del motor.** Tabla de strings de red (4096), 8192 edicts, `net` de 64 KB por mensaje, 255 netvars por entidad con NW2, mapa grande con muchos props. | Media | Alto | Contar `util.AddNetworkString` (166 hoy) y entidades en raid; loot como objetos de inventario, no como entidades sueltas; limpiar cadáveres (`persistent_corpses`) con límite; areaportals (#26). |
| R10 | **IA VJ Base** cara en CPU y con navmesh/nodegraph del mapa. | Alta | Alto | Límite de IA viva por zona y global (config); IA solo activa con jugadores cerca (ya lo hace `efg_ai`); nodegraph generado y versionado para el mapa de 1.0. |
| R11 | **Alcance.** 26 issues abiertas y 10 mapas en datos; tentación de seguir añadiendo. | Alta | Medio | 1.0 es un mapa y el ciclo completo. Todo lo demás lleva el milestone `post-1.0`. Congelación de funciones en RC. |
| R12 | **Un solo desarrollador y pruebas manuales** en el PC de oscar. | Alta | Medio | CI en F4 (adelantable); `/EFGTestCiclo` ampliado a más pasos; servidor de pruebas dedicado para no depender de la sesión local. |

---

## 4. Siguientes pasos inmediatos

Por orden, para hoy y esta semana:

1. **Probar el renombrado sobre la BD real.** Copiar el gamemode a `gamemodes\escapefromgmod`, guardar una copia de `sv.db` (o del dump de MySQL) y de `data/helix/`, arrancar con `+gamemode escapefromgmod` y entrar con el PMC de siempre: tiene que estar con su alijo. Si falla, se vuelve a la copia. Es lo único que hoy puede perder datos.
2. **Añadir VJ Base a la colección y ejecutar `/IAClases`** (#8). Pasar la lista de clases para fijar los jefes en `efg_ai`. Desbloquea la IA y, con ella, el loot de cadáveres de `efg_loot_ai`.
3. **Decidir el inventario del TAB y retirar duplicados** (#10): quedarse con `efg_invgrid` y retirar `efg_invhtml`, `loot` y `needs` en un solo PR de limpieza. Reduce a la mitad la superficie de bugs antes de la primera partida.
4. **Montar la raid en `EFG_Mapa_v0_1`** (#9): spawns, 4-6 extracciones y 3-4 zonas de IA y loot, guardados en un archivo de datos del mapa en el repo. Antes hay que terminar el VRAD del mapa en el PC de oscar.
5. **Primera partida de 2-4 jugadores** (#11) con `efg_testcycle` grabando, y convertir cada error en issue `bug` del milestone F0.

El cambio de `₽` a `RUB` en 6 archivos es pequeño y se puede meter en el PR de limpieza del paso 3.
