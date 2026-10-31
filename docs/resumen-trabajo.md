# Resumen del trabajo de EFG (31 oct 2026)

Estado sacado de GitHub (`IosifStalin6773/EFG`) y de los hilos del proyecto el 31 de octubre de 2026 a las 09:10. **Nada de lo que aparece aquí se ha probado todavía en una partida real**: todo está escrito, revisado en código y, en muchos casos, copiado a `gamemodes\metrorp` en tu PC.

## Cifras

| | |
|---|---|
| PRs fusionados en `main` | 15 (#1-#6, #49, #52, #54, #56, #58, #59, #61, #64, #71) |
| PRs abiertos esperando tu fusión | 7 (#51, #62, #66, #68, #69, #72, #74) |
| Issues del roadmap abiertos | 34 (F0-F4 #7-#31 y nuevos #50, #65, #67, #73, #75-#80) |
| Issues cerradas | 24 (16 de historial `hecho` #32-#47 y 8 de trabajo reciente) |
| Plugins `efg_*` en el repo | 43 |
| Valores marcados `[VERIFICAR]` | 56 en 33 archivos |

## Por áreas

### Inventario y chalecos
- **Hecho y fusionado:** TAB único (`ix_invkey`), inventario VGUI `efg_invgrid` y el HTML `efg_invhtml`, cargadores como objetos (`efg_mags`), contenedores seguros y armaduras (`efg_gear`).
- **Borrador:** PR #74 (issue #73). La rejilla del chaleco no se creaba porque dependía de `ITEM:OnEquip`, que nunca se llamaba; ahora se crea bien y los bolsillos van separados (`ITEM.efgPockets`, datos de 9 chalecos que diste tú).
- **Sin probar en juego:** todo lo anterior.
- **Espera decisión tuya:** issue #10, elegir un solo inventario del TAB (la recomendación es `efg_invgrid`). En el chaleco A18 tu tabla decía 25 huecos y los bolsillos suman 24.

### Acceso rápido y selector del HUD
- **Borrador:** PR #74 (issues #75 y #80). Teclas 1-3 para el arma de pistolera, bandolera y espalda; 4-8 acceso rápido (solo objetos de bolsillos o chaleco); 9-0 physgun y toolgun para staff. Selector nuevo del HUD con las diez casillas en tres grupos.
- **Sin probar en juego:** sí. Ya está copiado a tu `gamemodes\metrorp`.

### Equipo visible (PAC3)
- **Borrador:** PR #74 (issue #76). `efg_outfits/sh_pac.lua` genera las piezas de PAC3 por ranura y las sincroniza cada segundo.
- **Sin probar en juego:** sí. Los desplazamientos de cada pieza son aproximados; hay que ajustarlos en el editor de PAC.
- **Ojo:** PAC3 está en tu `addons\pac3`, no en la colección del Workshop, y los `pac.lua`/`pacflag.lua` solo están en tu PC, no en el repo.

### Alijo
- **Borrador:** PR #74 (issue #77). El alijo solo se abre dentro del escondite y fuera de raid (`ix.strongbox.CanAccess`, netvar `efgStashOK`).
- **Sin probar en juego:** sí.

### Mercadillo
- **Hecho y fusionado:** `efg_flea` (entre jugadores desde nivel 15).
- **Borrador:** PR #74 (issue #78). Mercado simulado con precios entre 0,7 y 1,6 veces el del comerciante. Prohibidos los que aprobaste: llaves, objetos de tarea, dinero, contenedores seguros y objetos sin precio.
- **Pendiente:** issue #22, precios de referencia.

### Ajustes y teclas
- **Borrador:** PR #74 (issue #79). Teclas configurables (`ix.efg.binds`) y pestaña AJUSTES con JUEGO, CONTROLES y VOZ.
- **Sin probar en juego:** sí.
- **No hecho:** inclinarse y tumbarse (issue #14).

### Médico
- **Hecho y fusionado:** salud por partes `efg_health`, fisiología KAT `efg_physio`, pestaña SALUD, auditoría con arreglos (PR #52, sangrado que la regeneración tapaba), animaciones de EFT Medical Items (PR #54) y primera persona durante la animación (#58, #59).
- **Abierto sin fusionar:** PR #62 (crear `SWEP.Primary` antes de usarlo en `efg_med`) y PR #68 en borrador (cada medicina con su propia arma, como la comida; issue #67).
- **Sin probar en juego:** todo. Prueba rápida: `/EFGFisiologia leve` o `grave`.
- **Espera decisión tuya:** fusionar #62 y #68. Hay que revisar que no se pisen, porque los dos tocan `efg_med`.

### Puertas
- **Hecho y fusionado:** PR #56, `efg_doors` (entreabrir, patear, cerradura que salta a tiros, mirilla y cerrojo, con el cursor de `efg_hud`).
- **Sin probar en juego:** sí.

### Menús, logos y pantalla de carga
- **Hecho y fusionado:** portada y logo de EFG en el menú de GMod (PR #64) y logo, icono e insignias de facciones (PR #71).
- **Abierto sin fusionar:** PR #69 (estilo EFG para el menú principal de GMod con `tools/parche_menu_gmod.py`), PR #66 (pantalla de carga y carga local más rápida, issue #65) y PR #72 (insignias de USEC y BEAR más elaboradas).
- **Espera decisión tuya:** ver la preview v2 de USEC y BEAR (`/mnt/project-files/efg/preview_bear_usec_v2.png`) y decir si te convence para preparar el zip con las cuatro insignias. Fusionar #66 y #69.

### Autoría y moneda
- **Borrador:** PR #51 (issue #50). Autor "EFG Project" y dinero en rublos. Ya está copiado a tu PC (137 archivos) y el dinero guardado como balas se convierte solo.
- **Espera decisión tuya:** fusionar #51 y borrar a mano `schema\items\sh_bala.lua.retirado` en tu PC.

### Mapa
- **Hecho:** `EFG_Mapa_v0_1` (Asheville + escondite 14000 unidades por debajo; Seversk fuera por límites de VBSP). VBSP y VVIS finales salieron bien.
- **Bloqueado en tu PC:** VRAD falló por el modelo `props_junk/garbage256_composite002a` (su `.mdl` y su `.vvd` vienen de copias distintas). Tienes que ejecutar `compilar.py --sin-contenido --arreglar`, luego `--solo-contenido` y luego `--final --desde-vrad --sin-contenido` (unos 30 min).
- **Después:** probarlo en el juego y convertir los 5 props borrados a `prop_physics`. Montar la raid en él es la issue #9.

### Roadmap
- **Hecho:** issues #7-#31 en hitos F0-F4, historial #32-#47 cerrado, Proyecto 4 añadiendo issues solo.
- **F0 (bloquea el resto), todo abierto:** #7 primer arranque y consola limpia, #8 VJ Base y clases de IA, #9 raid en el mapa, #10 un solo inventario, #11 partida de prueba del ciclo completo.
- **F1-F4 abiertos:** granadas, cuerpo a cuerpo, tumbarse e inclinarse, oclusión de sonido, balística, árbol de tareas, trueques, círculo sectario, maestría, habilidades y Kappa, extracciones especiales, tránsitos, Seversk, contenedores, modo offline, wipes y retirar plugins de Metro.
- **Desfase a corregir:** las issues #48, #53, #55, #57, #60, #63 y #70 están cerradas, pero #73 y #75-#80 siguen abiertas hasta que se fusione el PR #74.

## Pendientes conocidos

- **Símbolo ₽:** sigue en 7 archivos de `main` (9 apariciones): `efg_flea/cl_plugin.lua`, `metroui/derma/cl_mainmenu.lua`, `efg_inspect/cl_plugin.lua`, `efg_tasks/cl_html.lua`, `efg_menus/cl_plugin.lua`, `efg_admin/sh_plugin.lua` y `efg_raids/cl_plugin.lua` (3). Bender no tiene ese glifo; hay que cambiarlo por RUB.
- **Inclinarse y tumbarse:** sin hacer (issue #14).
- **VJ Base:** sigue sin estar en la colección del Workshop; sin él no hay IA (issue #8). Los nombres de clase de los jefes son suposiciones; se comprueban con `/IAClases`.
- **`[VERIFICAR]`:** 56 valores por revisar contra la wiki de EFT (issue #31).
- **Cambios solo en tu PC:** autor "EFG Project", las guardas `ix.efg.SendContent()` y el dinero "rublos" están en tu copia; el PR #51 los sube al repo.

## Lo que te toca a ti, en orden

1. Fusionar los PRs abiertos: #51, #74, #62 y #68 (revisa que no choquen), #66, #69 y #72.
2. Ejecutar los tres pasos de `compilar.py` para terminar el mapa.
3. Añadir VJ Base a la colección.
4. Arrancar el servidor y pasar la consola limpia (issue #7), luego `/EFGTestCiclo todo`.
5. Decir si te convencen las insignias de USEC y BEAR y qué inventario del TAB se queda.
