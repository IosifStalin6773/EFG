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

En el inventario: **R** sobre un objeto lo gira. Clic derecho en un objeto: **Asegurar** (fuera de raid) y, en las armas, **Reparar (kit de armas)**.

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
| `/IAZonaAdd <tipo>` · `/IAZonaBorrar` · `/IALimpiar` | Zonas de IA: scav, francotirador, pmc, jefe, sanitar |
| `/LootAdmin` · `/LootAreaCreate` · `/LootMostrar` | Botín del mapa |
| `/TraderSpawn <clave>` · `/TraderAdmin` · `/TraderPrices` | Comerciantes (claves: prapor, therapist, fence, skier, peacekeeper, mechanic, ragman, jaeger) |
| `/MisionAdmin` | Crear y editar tareas (salen en la pestaña TAREAS) |
| `/ColocarMesaArmas` · `/ColocarMesaQuimica` · `/ColocarCocina` · `/ColocarBancoReciclaje` | Módulos del escondite |

## Configuración (menú de Helix, categoría EFG)

`efgRaidMinutes` (duración de la raid, 35 por defecto), `efgScavCooldown` (espera entre Scav runs, 20 min) y `efgFleaLevel` (nivel para el mercadillo, 15).

Nuevas categorías (fases 1-7): **EFG Estados** (hidratación, energía, conmoción, pierna rota), **EFG Armas** (desgaste y encasquillamientos), **EFG Karma**, **EFG Seguro** y, en **EFG**, `efgFleaRequireFIR`, `efgCraftMinutes`, `efgSwitchMinutes`, `efgRunThroughXP`, `efgNetLimit` y `efgNetKick`. Los valores marcados **[VERIFICAR]** hay que contrastarlos con la wiki de EFT.

## Opciones de cliente (consola)

`efg_inercia 0/1` (inercia al moverse), `efg_accesorapido_siempre 0/1` (barra de acceso rápido siempre visible) y `efg_radial_tecla` (tecla del menú radial).
