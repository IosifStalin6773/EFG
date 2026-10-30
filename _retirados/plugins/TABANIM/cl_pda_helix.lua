-- schema/plugins/stalker2_pda_helix/cl_pda_helix.lua

-- Cliente pide al servidor equipar/retirar PDA.
-- Añadimos un segundo booleano "noAnim" para retiros instantáneos en 'inventory'.
local function PDA_NetSend(wantEquip, noAnim)
  net.Start("PDA_Helix_SetState")
  net.WriteBool(wantEquip) -- true = equip; false = retirar
  net.WriteBool(noAnim or false) -- true = retirar sin animación/sonido (solo para 'inventory')
  net.SendToServer()
end

local function IsMenuOpen()
  return IsValid(ix and ix.gui and ix.gui.menu)
end

local function GetActiveTabName()
  local menu = ix and ix.gui and ix.gui.menu
  if not IsValid(menu) or not menu.GetActiveTab then return nil end
  -- Devuelve el subpanelName (p.ej. "inv")
  return menu:GetActiveTab()
end

-- Guardamos el estado previo para enviar net messages solo cuando hay transición.
local prev = {
  open = false,
  tab  = nil
}

hook.Add("Think", "PDA_Helix_TrackMenuTabs", function()
  local nowOpen = IsMenuOpen()
  local nowTab  = nowOpen and GetActiveTabName() or nil

  -- Caso 1: Menú recién abierto
  if nowOpen and not prev.open then
    if nowTab ~= "inventory" then
      -- Abrimos en un tab distinto a inventory => equip con animación
      PDA_NetSend(true, false)
    else
      -- Abrimos directo en inventory => no equipar (y no hay nada que “holsterear”)
      PDA_NetSend(false, true) -- noAnim=true por si acaso el jugador venía con PDA
    end
  end

  -- Caso 2: Cambio de tab con menú abierto
  if nowOpen and prev.open and nowTab ~= prev.tab then
    if nowTab == "inventory" then
      -- Entramos en inventory => retirar SIN animación (requisito del usuario)
      PDA_NetSend(false, true)
    else
      -- Entramos a cualquier otro tab => equipar CON animación
      PDA_NetSend(true, false)
    end
  end

  -- Caso 3: Menú se cierra
  if not nowOpen and prev.open then
    -- Al cerrar el menú, retiramos CON animación (comportamiento anterior)
    PDA_NetSend(false, false)
  end

  prev.open = nowOpen
  prev.tab  = nowTab
end)