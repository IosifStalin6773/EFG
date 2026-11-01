---
applyTo: "**/*.lua"
---

Este repositorio usa **GLua** (Lua 5.1 con extensiones de Garry's Mod) sobre el framework **Helix**.

## Estilo obligatorio

- Indentación con **tabulaciones**, nunca espacios.
- Strings entre comillas dobles: `"texto"`.
- Paréntesis en condiciones: `if (condicion) then`, `while (condicion) do`.
- Variables siempre con `local` salvo constantes de facción/clase (`FACTION_X`, `CLASS_X`).
- Solo comentar lógica no trivial. No comentar lo obvio.

## Seguridad GLua

- Siempre verificar `IsValid(entidad)` antes de llamar métodos en entidades.
- Siempre verificar `client:GetCharacter()` antes de llamar sus métodos — puede ser `nil`.
- Nunca usar `table.contains` (no existe en GLua) → usar `table.HasValue`.
- Los timers por jugador deben eliminarse en `PlayerDisconnected`.

## Contexto del servidor

- Archivos `cl_*.lua` → solo cliente. Archivos `sv_*.lua` → solo servidor. Archivos `sh_*.lua` → ambos.
- `ix.util.Include` gestiona `AddCSLuaFile` automáticamente según el prefijo del archivo.
- La moneda son Rublos: `ix.currency.singular = "Rublo"`, `ix.currency.plural = "Rublos"`.
