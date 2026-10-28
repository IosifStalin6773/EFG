# Plugin Helix: Sistema de Pasaportes y Control de Frontera (ES)

Sistema de documentación estilo **Papers, Please** para Metro RP 2033:

- **Impresora de Pasaportes** (`ix_passport_printer`) → editor para imprimir tu pasaporte con foto (cara del modelo), datos y sello.
- **Ítem Pasaporte** con funciones **Ver**, **Ver Multi-Página** y **Mostrar** (apuntas a un jugador cercano y se le abre).
- Documentos adicionales: permiso de entrada, pase de trabajo, tarjeta de identidad, ID diplomático, permiso de tránsito, boleto de acceso y documentos de vacunas.
- **Mesa de Inspección** (`ix_inspection_desk`) → estación de control de frontera donde el inspector coloca documentos, los compara y **aprueba/deniega**.
- **Contenedor de Documentos** (`ix_confiscation_box`) → para confiscar documentos.

---

## Firma automática por facción

El sellado en la mesa es **automático según la facción del inspector** (no se eligen sellos a mano):

| Facción (uniqueID)      | Sello de aprobación     |
|-------------------------|-------------------------|
| `polis`                 | `metro/stamp/polis.png` |
| `hanza`                 | `metro/stamp/hanza.png` |
| `linearoja`             | `metro/stamp/redline.png` |
| `cuartoreich`           | `metro/stamp/reich.png` |
| `staff` / admin         | `metro/stamp/aprobado.png` |

- **Solo esas facciones de control (+ Staff/admin) pueden aprobar/denegar.** Para el resto, los botones de sellado salen deshabilitados y el servidor rechaza cualquier intento.
- **Denegar** aplica `metro/stamp/denegado.png`.
- La configuración está en `libs/sh_config.lua` (`InspectorStamps`, `StaffStamp`, `DeniedStamp`, `FactionNations`).

---

## Reglas "Papers, Please" (boletines por día)

En `libs/sh_rules.lua` se definen **boletines por día** (`PLUGIN.Bulletins`): naciones admitidas/vetadas, documentos obligatorios, validez de sellos, coincidencia de nombre, ciudad emisora válida, caducidades y duración máxima del permiso.

- La mesa muestra el **boletín del día** y una **sugerencia de veredicto** (APROBAR/DENEGAR) con los motivos, validando los documentos colocados.
- Si el inspector decide **en contra** del boletín, recibe una **citación** y una **multa en Balas** (`rules.fines` o `PLUGIN.CitationFine`). Si no tiene saldo, solo se le amonesta.
- Cambiar el día vigente (admin): comando **`/FronteraDia <n>`**. Se persiste y se sincroniza a todos los clientes.

> Modelo RP: la mesa valida los documentos que el inspector tiene en su inventario (los que el viajero le ha entregado / lleva consigo).

---

## Orden de carga (importante)

Helix incluye automáticamente `libs/` **antes** que `derma/`, y ambos **antes** que `sh_plugin.lua`. Por eso:

- La **configuración** (`libs/sh_config.lua`), las **fuentes** (`libs/cl_fonts.lua`), las **reglas** (`libs/sh_rules.lua`) y la **lógica de servidor** (`libs/sv_inspection.lua`) viven en `libs/`, de modo que ya existen cuando se cargan los paneles de `derma/`.
- **No** vuelvas a incluir `derma/`, `libs/`, `items/` ni `entities/` a mano en `sh_plugin.lua`: Helix lo hace solo.

(Mover las fuentes a `libs/` es lo que corrige el error `'ixPassportFont' isn't a valid font`.)

---

## Assets requeridos (en `materials/`)

- Plantilla: la indicada en `PLUGIN.PassportTemplate` (`metro/Pasaporte_Metro.png`).
- Sellos en `materials/metro/stamp/`: `polis.png`, `hanza.png`, `redline.png`, `reich.png`, `aprobado.png`, `denegado.png` y los de estación (`alliance`, `bylvar`, `terra_nova`, `cult`, `factory`, `kitau`, `kyzna`, `laboratory`, `nnig`, `trotskyists`, `vdnh`).

> Las rutas de `Material()` **no** incluyen el prefijo `materials/` (es lo normal en GMod).

---

## Instalación

1. Coloca la carpeta `passport` dentro de `plugins/` del schema.
2. Asegúrate de tener los assets anteriores.
3. Reinicia el servidor o usa `ix_reloadplugins`.
4. Spawnea `ix_passport_printer`, `ix_inspection_desk` y (opcional) `ix_confiscation_box`.

## Créditos

- Sistema de Pasaportes — Metro RP By Cono y Manperra.
