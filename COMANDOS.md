# Escape from Gmod (EFG): comandos y controles

Estos son los comandos que existen de verdad en el esquema. Se escriben en el chat con `/`. Los marcados como **admin** solo los pueden usar administradores.

## Controles

| Tecla | Qué hace |
|---|---|
| TAB | Inventario y todos los menús: Inventario, Salud, Personaje, Comerciantes, Tareas, Escondite, Raid, Mercadillo y Ajustes |
| Z (mantener) | Menú radial: cargador, modo de disparo, extracciones, salud, medicinas, inventario y atuendo |
| O | Una vez muestra el tiempo de raid; dos veces, la lista de extracciones |
| ALT + T | Comprobar el cargador |
| ALT + B | Comprobar el modo de disparo |
| 1-5 | Acceso rápido (se asigna en el TAB) |

## Jugador

| Comando | Qué hace |
|---|---|
| `/Lobby` | Abre el TAB en la pestaña de raid |
| `/Raid` | Despliega a tu PMC en una raid (y a tu grupo si eres el líder) |
| `/RaidScav` | Entra como Scav con equipo aleatorio; tu PMC no arriesga nada |
| `/Extracciones` | Tiempo que queda y tus extracciones (igual que la tecla O) |
| `/Nivel` | Tu nivel, experiencia y estadísticas de raids |
| `/GrupoInvitar <jugador>` · `/GrupoAceptar` · `/GrupoSalir` | Grupo de raid |
| `/Escondite` | Mejoras del escondite |
| `/Alijo` | Abre tu alijo |
| `/Mercadillo` | Mercadillo entre jugadores |
| `/Atuendo` | Cabeza, chaqueta y pantalón del PMC (fuera de raid) |
| `/Voz <1-2>` · `/Frase <frase>` | Voz del PMC y frases rápidas |
| `/estadoMision` · `/abandonarMision` | Tarea activa (también desde la pestaña TAREAS) |
| `/Habilidades` | Tus habilidades |
| `/Intercambiar` | Intercambio con el jugador al que miras |
| `/Karma` | Tu karma Scav (reputación con Fence) |
| `/Municion` | Datos de la munición del arma que llevas |
| `/Hora` | Hora de la raid, la otra hora (+12 h) y el clima |
| `/Cambio usd\|eur <cantidad> [vender]` | Compra o vende dólares (Peacekeeper) o euros (Skier), junto al comerciante |
| `/Generador [repostar]` | Combustible del generador (repostar gasta una gasolina) |
| `/Bitcoin [gpu\|recoger]` | Granja de bitcoin |
| `/ScavCase [2500\|15000\|95000]` | Envía al Scav Case |
| `/Mensajes` | Mensajes de seguro, mercadillo y tareas |
| `/Manual` | Manual de objetos con precios |
| `/BuscarGrupo` | Entra o sale de la cola para formar grupo |

En el inventario: **R** sobre un objeto lo gira, **Ctrl+clic** lo mueve al otro inventario abierto, **Alt+clic** lo equipa o quita y **doble clic** abre contenedores, usa o examina. Clic derecho en un objeto: **Asegurar** con Prapor o Therapist (fuera de raid), **Reparar en comerciante** (Prapor o Mechanic, junto a ellos) y, en las armas, **Reparar (kit de armas)**, **Cambiar munición** y **Descargar**. Lo encontrado en raid sale como **?** hasta **Examinarlo**.

Con el arma averiada (fallo de disparo, encasquillamiento, fallo de alimentación o doble alimentación) se pulsa **recargar** para arreglarla.

## Admin: pruebas (nuevos)

| Comando | Qué hace |
|---|---|
| `/EFGDarDinero <jugador> <rublos>` | Da rublos (negativo para quitar) |
| `/EFGNivel <jugador> <1-79>` | Pone al PMC en ese nivel |
| `/EFGDarXP <jugador> <xp>` | Da experiencia |
| `/EFGLealtad <jugador> <comerciante> <0-1000>` | Fija la reputación. LL2 = 200, LL3 = 500, LL4 = 800, y además hace falta el nivel de PMC de cada LL (15, 26 y 36). El comerciante vale por clave (`prapor`) o por nombre (`Intendente`) |
| `/EFGCompletarTarea <jugador>` | Completa su tarea activa con la primera recompensa |
| `/EFGTiempoRaid <jugador> <minutos>` | Cambia los minutos de raid que le quedan |
| `/RaidForceEnd <jugador>` | Lo saca de la raid sin perder el equipo |

## Admin: preparar el mapa

| Comando | Qué hace |
|---|---|
| `/RaidSetEscondite` | Fija el escondite (zona segura y reaparición) donde estás |
| `/RaidAddSpawn` | Añade un punto de aparición de raid |
| `/RaidAddExtract <nombre> <tipo> [radio] [bando] [coste]` | Añade una extracción. Tipo: siempre, aleatoria, pago, sin_mochila, interruptor. Bando: todos, pmc, scav |
| `/RaidAddSwitch <nombre>` | Pone un interruptor donde miras. Abre la extracción de tipo interruptor con el mismo nombre (E para usarlo) |
| `/RaidRemoveNearest` · `/RaidList` | Borra el punto más cercano o lista los del mapa |
| `/IAZonaAdd <tipo>` · `/IAZonaBorrar` · `/IALimpiar` | Zonas de IA: scav, francotirador, pmc, jefe, sanitar, killa, tagilla, shturman, glukhar, kaban, kollontay, zryachiy, goons, partisan, raider, rogue, cultist (de noche) |
| `/IAClases [texto]` | Lista las clases de NPC instaladas (para corregir nombres de jefes) |
| `/PuertaLlave [llave]` · `/Llaves` | Cierra la puerta que miras con una llave de EFT (sin llave la abre) y lista las llaves |
| `/EFGCalibre <clase> [calibre]` | Muestra o fija el calibre de un arma (p. ej. `545x39`) |
| `/HoraFijar <0-23>` · `/Clima <despejado\|nublado\|niebla\|lluvia>` | Reloj y clima |
| `/EFGDiagnostico` | Comprueba addons, datos del mapa, NPC que faltan y puertas |
| `/EFGWipe CONFIRMAR` | **Superadmin.** Wipe: cada personaje empieza de cero al entrar |
| `/LootAdmin` · `/LootAreaCreate` · `/LootMostrar` | Botín del mapa |
| `/TraderSpawn <clave>` · `/TraderAdmin` · `/TraderPrices` | Comerciantes (claves: prapor, therapist, fence, skier, peacekeeper, mechanic, ragman, jaeger) |
| `/MisionAdmin` | Crear y editar tareas (salen en la pestaña TAREAS) |
| `/ColocarMesaArmas` · `/ColocarMesaQuimica` · `/ColocarCocina` · `/ColocarBancoReciclaje` | Módulos del escondite |

## Configuración (menú de Helix, categoría EFG)

`efgRaidMinutes` (duración de la raid, 35 por defecto), `efgScavCooldown` (espera entre Scav runs, 20 min) y `efgFleaLevel` (nivel para el mercadillo, 15).

Nuevas categorías (fases 1-7): **EFG Estados** (hidratación, energía, conmoción, pierna rota), **EFG Armas** (desgaste y encasquillamientos), **EFG Karma**, **EFG Seguro** y, en **EFG**, `efgFleaRequireFIR`, `efgCraftMinutes`, `efgSwitchMinutes`, `efgRunThroughXP`, `efgNetLimit` y `efgNetKick`. Los valores marcados **[VERIFICAR]** hay que contrastarlos con la wiki de EFT.

Hoja de ruta (roadmap H0-H11), categorías nuevas: **EFG Balística** (`efgBallisticsEFT`, `efgRicochet`), **EFG Armas** (`efgHeatPerShot`, `efgHeatCooling`, `efgRepairKitDegrade`), **EFG Inventario** (`efgExamineEnabled`, `efgSearchBase`, `efgSearchPerItem`), **EFG Mapas** (`efgTimeScale`, `efgDayNight`, `efgWeather`), **EFG Economía** (`efgUSDRate`, `efgEURRate`, `efgExchangeSellRatio`), **EFG Mercadillo** (`efgFleaFeeEFT`), **EFG Progresión** (`efgEFTLevelCurve`), **EFG Escondite** (`efgFuelPerHour`, `efgBitcoinHours`, `efgScavCaseMinutes`), **EFG Sonido** (`efgFootstepLoudness`) y **EFG Servidor** (`efgPvE`, `efgWipeID`, `efgWipeMoney`, `efgAntiSpeed`, `efgLootDistance`).

## Servidor

- `tools/compilar.bat`: copia schema y Helix a `gamemodes` y empaqueta `content/` en `_build/efg_content.gma` con gmad.
- `python tools/glua_check.py plugins`: comprueba la sintaxis de todo el Lua sin abrir GMod (necesita `pip install lupa`).
- Base de datos para el servidor público: en `helix.yml` del servidor pon `database: adapter: "mysqloo"` con host, usuario, contraseña y base de datos, e instala el módulo mysqloo en `garrysmod/lua/bin`.
- El contenido propio (`materials/efg`, `sound/efg`, `models/efg`, `resource/fonts`) se manda a los clientes solo (efg_server). Para el Workshop, `host_workshop_collection 3224545557` en el arranque del servidor.

## Opciones de cliente (consola)

`efg_inercia 0/1` (inercia al moverse), `efg_accesorapido_siempre 0/1` (barra de acceso rápido siempre visible) y `efg_radial_tecla` (tecla del menú radial).

## Pruebas del ciclo (efg_testcycle)

- `/EFGTestCiclo [todo|extract|death|mia|abandon]` (superadmin): un bot recorre el ciclo de raid y la consola muestra PASS/FAIL por paso.
- `/EFGLogCiclo [jugador] [n]` (admin): últimos eventos del ciclo en la consola. También en `data/efg/ciclo/<fecha>.txt`.
