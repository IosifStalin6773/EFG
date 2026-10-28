---
name: nuevo-plugin
description: >
  Crea un plugin completo y autocontenido para Metro RP 2033 en la carpeta plugins/.
  Úsame cuando el usuario pida crear o añadir un nuevo plugin al schema.
---

## Objetivo
Crear la carpeta `plugins/<nombre>/` con todos los archivos necesarios para un plugin funcional de Helix.

## Proceso

1. **Recopila los datos necesarios** (pregunta si no se han proporcionado):
   - Nombre del plugin
   - Descripción funcional
   - ¿Tiene lógica de cliente?
   - ¿Tiene lógica de servidor?
   - ¿Registra comandos de chat?
   - ¿Registra variables de personaje?
   - ¿Añade hooks?
   - ¿Necesita cadenas de idioma propias?
   - ¿Depende de otras facciones o plugins?

2. **Lee** `plugins/ranks/sh_plugin.lua` como referencia de estructura antes de generar.

3. **Genera** los archivos:

### `plugins/<nombre>/sh_plugin.lua`
```lua
PLUGIN.name = "Nombre del Plugin"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Descripción del plugin."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

-- Variables de personaje (si las hay)
ix.char.RegisterVar("miVar", {
	field = "mi_var",
	fieldType = ix.type.number,
	default = 0
})

-- Comandos (si los hay)
ix.command.Add("MiComando", {
	arguments = { ix.type.player },
	description = "@cmdMiComando",
	OnRun = function(self, client, target)
		-- lógica
	end
})
```

### `plugins/<nombre>/sv_plugin.lua`
```lua
-- Net strings (declarar aquí, antes de usarlas)
-- util.AddNetworkString("MiPlugin_Evento")

function PLUGIN:PlayerSpawn(client)
	-- lógica de servidor
end
```

### `plugins/<nombre>/cl_plugin.lua`
```lua
function PLUGIN:HUDPaint()
	-- lógica de cliente
end
```

### `plugins/<nombre>/languages/sh_english.lua` (si tiene cadenas propias)
```lua
LANGUAGE = {
	cmdMiComando = "Descripción del comando."
}
```

## Reglas de generación

- Carpeta: `plugins/<nombre_en_minusculas>/`
- Usar `PLUGIN:` para hooks (no `Schema:`)
- Net strings: declarar con `util.AddNetworkString` en `sv_plugin.lua` antes de `net.Start`
- Timers por jugador → limpiar en `PLUGIN:PlayerDisconnected(client)`
- No hardcodear strings visibles al jugador
- No mezclar lógica de servidor en `cl_plugin.lua`
- Indentación con **tabulaciones**

## Patrones comunes incluidos si aplica

### Timer periódico global
```lua
timer.Create("MiPlugin_Tick", 30, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client) and client:GetCharacter()) then
			-- lógica
		end
	end
end)
```

### Timer por jugador (con limpieza)
```lua
-- En sv_plugin.lua
function PLUGIN:PlayerInitialSpawn(client)
	timer.Create("MiPlugin_" .. client:SteamID(), 5, 0, function()
		if (!IsValid(client)) then return end
		-- lógica
	end)
end

function PLUGIN:PlayerDisconnected(client)
	timer.Remove("MiPlugin_" .. client:SteamID())
end
```

## Aviso post-generación

Al terminar, recordar al usuario:
- Helix auto-incluye `plugins/` — no hace falta include manual en `sh_schema.lua`
- Si el plugin usa net messages, verificar que `util.AddNetworkString` está en el lado servidor
- Comprobar que no hay conflicto de nombre con plugins existentes en `plugins/`
