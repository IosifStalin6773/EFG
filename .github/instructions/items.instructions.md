---
applyTo: "schema/items/**/*.lua"
---

## Ítems — EFG (Escape from Gmod)

Estos archivos definen ítems del inventario Helix. Convenciones específicas:

- Dentro de **cualquier callback** (`OnRun`, `OnEquip`, etc.) usar siempre `item` (instancia), **nunca** `ITEM` (plantilla global).
- `return true` en `OnRun` elimina el ítem del inventario; `return false` lo conserva.
- `ITEM.noBusiness = true` si el ítem no debe aparecer en tiendas.
- `ITEM.price` solo si el ítem es comprable; eliminarlo si se define `noBusiness`.
- Acceder al jugador con `item.player` (no `ITEM.player`).
- Proteger los valores vitales con `math.min`/`math.max`:
  ```lua
  client:SetHealth(math.min(client:Health() + 20, client:GetMaxHealth()))
  ```
- Nombres e ítems en **español**; categorías pueden ser en español también.
- Categorías comunes: `"Consumibles"`, `"Equipamiento"`, `"Medicamentos"`, `"Recursos"`, `"Armas"`.

### Estructura mínima
```lua
ITEM.name = "Nombre"
ITEM.model = Model("models/...")
ITEM.description = "Descripción."
ITEM.category = "Consumibles"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true

ITEM.functions.Usar = {
    OnRun = function(item)
        local client = item.player
        return true
    end
}
```
