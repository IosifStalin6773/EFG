---
applyTo: "schema/factions/**/*.lua"
---

## Facciones — EFG (Escape from Gmod)

Estos archivos definen facciones del schema Helix. Convenciones específicas:

- La constante `FACTION_X` se asigna **al final** del archivo, después de todos los campos.
- `FACTION.isDefault = true` solo para la facción `FACTION_CIVIL` (única facción por defecto).
- `FACTION.weapons = {"ohandsswep"}` en todas las facciones que no tengan armas de inicio.
- Si la facción tiene ítems iniciales, implementar `FACTION:OnCharacterCreated(client, character)`.
- Si la facción tiene rangos, usar `FACTION.Ranks` y `FACTION:OnRankChanged(client, old, new)`.
- Descripciones en **español**, tono coherente con el lore de Metro 2033.

### Facciones existentes (no duplicar constantes)
`FACTION_CIVIL`, `FACTION_POLIS`, `FACTION_HANZA`, `FACTION_LINEAROJA`, `FACTION_CUARTOREICH`, `FACTION_BANDIT`, `FACTION_RANGER`, `FACTION_SINDICATO`, `FACTION_STAFF`

### Estructura mínima
```lua
FACTION.name = "Nombre"
FACTION.description = "Descripción en español."
FACTION.color = Color(r, g, b)
FACTION.pay = 0
FACTION.models = { "models/..." }
FACTION.isDefault = false
FACTION.isGloballyRecognized = false

FACTION_X = FACTION.index
```
