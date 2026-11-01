---
name: revisar-codigo
description: >
  Revisa código GLua del schema EFG (Escape from Gmod) buscando bugs, problemas de seguridad
  y violaciones de las convenciones del proyecto. Úsame antes de publicar cambios al servidor.
allowed-tools: read
---

## Objetivo
Realizar una revisión de código de alta señal/ruido en archivos Lua de EFG (Escape from Gmod). Solo reportar problemas que **realmente importen**.

## Proceso

1. **Leer** el archivo o fragmento a revisar con la herramienta `read`.
2. **Analizar** siguiendo la checklist por prioridades.
3. **Reportar** solo hallazgos con impacto real.

## Checklist de revisión

### 🔴 Crítico (bloquean o crashean el servidor)

- [ ] ¿Se verifica `IsValid()` antes de usar entidades?
- [ ] ¿Se verifica `client:GetCharacter()` antes de llamar sus métodos?
- [ ] ¿Todas las net strings tienen `util.AddNetworkString` declarado?
- [ ] ¿Se usa `item` (instancia) y no `ITEM` (plantilla) dentro de callbacks de ítems?
- [ ] ¿Los hooks están en el archivo correcto según su prefijo (`cl_`/`sv_`/`sh_`)?
- [ ] ¿Se usa `table.HasValue` en lugar de `table.contains` (que no existe en GLua)?
- [ ] ¿Los timers por jugador se limpian en `PlayerDisconnected`?
- [ ] ¿No hay llamadas a `GetCharacter()` dentro de `PlayerInitialSpawn` (aún no cargado)?

### 🟡 Importante (bugs en runtime)

- [ ] ¿Todas las variables locales tienen `local`?
- [ ] ¿Las constantes `FACTION_X` y `CLASS_X` están al final del archivo?
- [ ] ¿Las strings visibles al jugador usan `L()` o `NotifyLocalized`?
- [ ] ¿Los `math.min`/`math.max` protegen los valores vitales (vida, etc.)?
- [ ] ¿Se usa `ipairs` para tablas secuenciales y `pairs` para tablas de clave-valor?

### 🔵 Convenciones (calidad del código)

- [ ] ¿La indentación es con tabulaciones (no espacios)?
- [ ] ¿Las condiciones tienen paréntesis: `if (condicion) then`?
- [ ] ¿Las descripciones de facciones e ítems están en español?

## Formato de cada hallazgo

```
[NIVEL] Línea N: descripción del problema
  Actual:     `código problemático`
  Corrección: `código corregido`
  Motivo: explicación de una línea
```

## Regla de oro

Si el código funciona correctamente, es seguro y sigue las convenciones esenciales del proyecto, responder:

```
✅ Sin problemas encontrados. El código está listo para publicar.
```

No comentar sobre preferencias de nombres, orden de campos, o cualquier cosa que no afecte al funcionamiento o mantenibilidad del código.
