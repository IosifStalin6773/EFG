
-- Here is where all of your clientside hooks should go.

-- La descripción del personaje debe verse SIEMPRE, aunque no reconozcas a quien
-- tienes delante: el reconocimiento solo debe afectar al NOMBRE mostrado. El
-- plugin core "recognition" (gamemodes/helix/plugins/recognition.lua) sustituye
-- también la descripción por un texto de "no reconocido" mientras tanto.
--
-- No basta con añadir otro hook GetCharacterDescription que devuelva nil: el
-- hook.Call de Helix (core/libs/sh_plugin.lua) se detiene en el PRIMER
-- resultado no-nil recorriendo HOOKS_CACHE, y el de "recognition" se registró
-- antes que cualquier plugin del schema, así que siempre ganaría él primero.
-- Hay que quitar directamente su entrada de la caché de hooks.
do
	local recognitionPlugin = ix.plugin.Get("recognition")
	local cache = recognitionPlugin and HOOKS_CACHE and HOOKS_CACHE["GetCharacterDescription"]

	print(("[DBG cl_hooks] recognitionPlugin=%s HOOKS_CACHE=%s cache=%s tenia_entrada=%s"):format(
		tostring(recognitionPlugin), tostring(HOOKS_CACHE), tostring(cache),
		tostring(cache and cache[recognitionPlugin] != nil)))

	if (cache) then
		cache[recognitionPlugin] = nil
	end

	print(("[DBG cl_hooks] tras quitar: cache[recognitionPlugin]=%s"):format(
		tostring(cache and cache[recognitionPlugin])))
end

-- TAB abre ixMetroInventory (ix_invkey). Se bloquea metroNewMenu aquí.
-- metroNewMenu se abre con el comando openMetroMenu (plugins/ix_invkey/cl_plugin.lua).
function Schema:ScoreboardShow()
	return false
end

function Schema:ScoreboardHide()
	return false
end

function Schema:CharacterLoaded(character)
	self:ExampleFunction("@serverWelcome", character:GetName())
end

-- Dispara ChatboxPositionChanged con la posición real del chatbox de Helix.
-- SetupPosition (ixChatbox) posiciona el panel pero nunca llama este hook,
-- por lo que ixArea (area plugin) se quedaría con el tamaño del chatbox nativo
-- de GMod y las entradas aparecerían fuera de lugar o invisible.
-- El schema carga después de los plugins de framework, así que self.panel
-- en el area plugin ya existe cuando este hook se ejecuta.
function Schema:ChatboxCreated()
	timer.Simple(0, function()
		local chatPlugin = ix.plugin.Get("chatbox")
		if (not chatPlugin or not IsValid(chatPlugin.panel)) then return end
		local x, y = chatPlugin.panel:GetPos()
		local w, h = chatPlugin.panel:GetSize()
		hook.Run("ChatboxPositionChanged", x, y, w, h)
	end)
end

-- Suprime mensajes de bienvenida de VJ Base en el chat.
function Schema:ChatText(index, name, text, type)
	if (string.find(text, "VJ Base") or string.find(name, "VJ Base")) then
		return true
	end
end

-- Suprime el HUD nativo de Helix por completo.
-- El HUD personalizado lo dibuja plugins/hud/cl_plugin.lua.
function Schema:HUDPaintBackground()
end

-- Suprime el HUDPaint base de Helix (arma, munición, indicadores).
-- Los PLUGIN:HUDPaint() de los plugins siguen activos a través del sistema de hooks.
function Schema:HUDPaint()
end

-- Suprime el historial de pickups de GMod (no inmersivo).
function Schema:HUDDrawPickupHistory()
end

-- Suprime el HUD de munición del motor de GMod (independiente de HUDShouldNotDraw).
-- Debe devolver true para que el motor no lo dibuje.
function Schema:HUDDrawAmmoHUD()
	return true
end

-- Suprime el menú del juego en la propia llamada del motor.
-- Si la consola está abierta (administradores), no se interviene.
hook.Add("GameMenuOpen", "MetroRP_DisableEscMenu", function()
	if (gui.IsConsoleVisible()) then return end
	gui.HideGameUI()
end)

-- PreRender se ejecuta antes de que GMod dibuje el frame: si el game UI está visible
-- en este punto, lo ocultamos antes de que se renderice (cero frames visibles).
-- Se respeta la consola nativa para que los administradores puedan usarla.
hook.Add("PreRender", "MetroRP_HideMenuPreRender", function()
	if (gui.IsGameUIVisible() and not gui.IsConsoleVisible()) then
		gui.HideGameUI()
	end
end)

-- Intercepta ESC: cierra la interfaz abierta con mayor prioridad y suprime el menú del juego.
-- Se detecta el flanco de subida de la tecla para no repetir el cierre mientras se mantiene.
-- gui.IsGameUIVisible() es el fallback por si GameMenuOpen no es suficientemente rápido.
do
	local _escDown = false

	hook.Add("Think", "MetroRP_ESC_CloseUI", function()
		-- Suprimir el menú siempre que esté visible, respetando la consola nativa
		if (gui.IsGameUIVisible() and not gui.IsConsoleVisible()) then
			gui.HideGameUI()
		end

		local esc = input.IsKeyDown(KEY_ESCAPE)

		if (not esc) then
			_escDown = false
			return
		end

		-- Suprimir en cada flanco de subida aunque no haya panel abierto
		if (not _escDown) then
			gui.HideGameUI()
		end

		if (_escDown) then return end
		_escDown = true

		-- Médico: modal de citas
		if (ix.medico and IsValid(ix.medico.appModal)) then
			ix.medico.appModal:Remove()
			gui.HideGameUI()
			return
		end

		-- Médico: diálogo NPC (dos frames)
		if (ix.medico and (IsValid(ix.medico.frameTop) or IsValid(ix.medico.frameBot))) then
			if (IsValid(ix.medico.frameTop)) then ix.medico.frameTop:Remove() end
			if (IsValid(ix.medico.frameBot)) then ix.medico.frameBot:Remove() end
			gui.HideGameUI()
			return
		end

		-- Crafting / Cocina
		if (IsValid(ix.gui.metroCrafting)) then
			ix.gui.metroCrafting:Remove()
			gui.HideGameUI()
			return
		end

		-- Trader
		if (ix.traders and IsValid(ix.traders._tradeFrame)) then
			ix.traders._tradeFrame:Remove()
			gui.HideGameUI()
			return
		end

		-- Storage abierto (contenedor / baúl). El botón "Cerrar" del panel manda
		-- "ixStorageClose" antes de destruirse (core/derma/cl_storage.lua); si aquí
		-- solo hacemos :Remove() sin avisar al servidor, el jugador se queda como
		-- receptor fantasma para siempre y el storage marca "Alguien ya está usando
		-- esto" en cualquier intento futuro de abrirlo (mismo bug ya visto y
		-- documentado en plugins/strongbox).
		if (IsValid(ix.gui.openedStorage)) then
			net.Start("ixStorageClose")
			net.SendToServer()
			ix.gui.openedStorage:Remove()
			gui.HideGameUI()
			return
		end

		-- Inventario principal
		if (IsValid(ix.gui.metroInventory)) then
			ix.gui.metroInventory:Remove()
			gui.HideGameUI()
			return
		end

		-- Menú principal (TAB)
		if (IsValid(ix.gui.metroNewMenu)) then
			ix.gui.metroNewMenu:Remove()
			gui.HideGameUI()
			return
		end

		-- Minijuego: descuartizar
		if (IsValid(ix.gui.butcherMinigame)) then
			ix.gui.butcherMinigame:Finish()
			gui.HideGameUI()
			return
		end

		-- Minijuego: recolección
		if (IsValid(ix.gui.harvestMinigame)) then
			ix.gui.harvestMinigame:Finish()
			gui.HideGameUI()
			return
		end

		-- Mesa de inspección de documentos
		if (IsValid(g_InspectionDesk)) then
			g_InspectionDesk:Close()
			gui.HideGameUI()
			return
		end
	end)
end
