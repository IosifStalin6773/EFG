-- gamemodes/helix/plugins/stalker2_bpa/cl_bpa.lua
if not CLIENT then return end

local NET = "network_backpack_changestatus"

local shuttingDown = false
hook.Add("ShutDown", "bpa_ShutDown", function() shuttingDown = true end)

-- El servidor nos pide cerrar el inventario al usar un consumible/medicina, para
-- que la mochila se suelte y se vea la animación del ítem.
net.Receive("ixBPAForceCloseInv", function()
    if (IsValid(ix.gui.metroInventory)) then
        ix.gui.metroInventory:Remove()
    end
end)

local function SendBackpackState(isOpen, playSound)
    -- al desconectar el panel se destruye y ya no hay canal con el servidor
    if shuttingDown or not IsValid(LocalPlayer()) then return end

    net.Start(NET)
        net.WriteBool(isOpen)
    net.SendToServer()

    if playSound then
        surface.PlaySound(isOpen and "Stalker2.BpaOpen" or "Stalker2.BpaClose")
    end
end

local function SetInventoryOpenFlag(b)
    LocalPlayer()._bpaInventoryOpen = b or nil
end

-- ix_invkey abre un panel standalone (ix.gui.metroInventory), no pasa por el
-- sistema de menú de Helix, así que vigilamos directamente esa variable.
local wasInvOpen = false
hook.Add("Think", "bpa_InventoryPanel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local isInvOpen = IsValid(ix.gui.metroInventory)
    if isInvOpen == wasInvOpen then return end
    wasInvOpen = isInvOpen

    if isInvOpen then
        SetInventoryOpenFlag(true)
        SendBackpackState(true, true)
    else
        if ply._bpaInventoryOpen then
            SetInventoryOpenFlag(false)
            if not ply._bpaStorageOpen then
                SendBackpackState(false, true)
            end
        end
    end
end)

-- Abre/cierra la mochila al lootear un cuerpo o cualquier storage (ixStorageView).
local wasStorageOpen = false

hook.Add("Think", "bpa_StorageLoot", function()
    local ply = LocalPlayer()
    if (not IsValid(ply)) then return end

    local isStorageOpen = IsValid(ix.gui.openedStorage)
    if (isStorageOpen == wasStorageOpen) then return end
    wasStorageOpen = isStorageOpen

    if (isStorageOpen) then
        if (not ply._bpaInventoryOpen) then
            ply._bpaStorageOpen = true
            SendBackpackState(true, true)
        end
    else
        if (ply._bpaStorageOpen) then
            ply._bpaStorageOpen = nil
            if (not ply._bpaInventoryOpen) then
                SendBackpackState(false, true)
            end
        end
    end
end)

-- Gesto "revisando inventario": se reproduce hasta el punto en el que el
-- jugador echa la mano al bolsillo/mochila y se queda congelado ahí
-- mientras la NW var "ixAnimInvOpen" siga activa. Al cerrar, se limpia.
local INV_GESTURE_ACT = ACT_GMOD_GESTURE_ITEM_PLACE
local INV_GESTURE_FREEZE_CYCLE = 0.4 -- Punto del ciclo (0-1) donde se congela; ajustar a ojo

local invGesture = {}

hook.Add("Think", "bpa_InventoryGestureLoop", function()
    for _, target in ipairs(player.GetAll()) do
        local isOpen = IsValid(target) and target:Alive() and target:GetNWBool("ixAnimInvOpen", false)
        local state = invGesture[target]

        if (isOpen) then
            if (not state) then
                target:AnimRestartGesture(GESTURE_SLOT_VCD, INV_GESTURE_ACT, false)

                local sequence = target:SelectWeightedSequence(INV_GESTURE_ACT)
                local duration = (sequence > 0) and target:SequenceDuration(sequence) or 1

                invGesture[target] = {
                    freezeAt = CurTime() + duration * INV_GESTURE_FREEZE_CYCLE,
                    frozen = false
                }
            elseif (not state.frozen and CurTime() >= state.freezeAt) then
                target:SetLayerCycle(GESTURE_SLOT_VCD, INV_GESTURE_FREEZE_CYCLE)
                target:SetLayerPlaybackRate(GESTURE_SLOT_VCD, 0)
                state.frozen = true
            end
        elseif (state) then
            invGesture[target] = nil
            target:AnimResetGestureSlot(GESTURE_SLOT_VCD)
        end
    end
end)