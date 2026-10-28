-- items/consumables/sh_cigarette.lua
ITEM.name = "Cigarrillo"
ITEM.description = "Un cigarrillo de la Zona. Ayuda a calmar los nervios."
ITEM.model = "models/weapons/stalker/cigarette/w_cigarettestandalone.mdl"
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 150
ITEM.restoreSaturation = -100
ITEM.restoreSatiety = -100

ITEM.maxStack = 5
ITEM.useSound = "ambient/voices/cough1.wav"
ITEM.consumeTime = 18

local WEAPON_CLASS = "weapon_stalker2_cigarette"
local AMMO_TYPE = "stalker_cig_consumable_ammo" -- "" si no usas ammo

----------------------------------------------------------------
-- 1) Canal net + Hook cliente para BLOQUEAR CLICK DERECHO
----------------------------------------------------------------
if SERVER then
    util.AddNetworkString("ix_cigarette_start")
end

if CLIENT then
    -- Hook que bloquea el clic derecho mientras la flag esté activa
    hook.Add("StartCommand", "ix_block_rclick_when_consuming", function(ply, cmd)
        -- Si se quiere, también puedes bloquear IN_ATTACK normal con cmd:RemoveKey(IN_ATTACK)
        if ply:GetNetVar("ix_consuming_cigarette", false) then
            cmd:RemoveKey(IN_ATTACK2)
        end
    end)

    net.Receive("ix_cigarette_start", function()
        local duration = net.ReadFloat()
        local expectedClass = net.ReadString()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) or wep:GetClass() ~= expectedClass then return end

            -- Intentar funciones del SWEP si existen
            if wep.StartSmokeSequence then
                wep:StartSmokeSequence()
            elseif wep.StartConsumeSequence then
                wep:StartConsumeSequence()
            elseif wep.InitializeConsumable then
                wep:InitializeConsumable()
            else
                -- Fallback: simular un click primario breve
                LocalPlayer():ConCommand("+attack")
                timer.Simple(0.05, function()
                    LocalPlayer():ConCommand("-attack")
                end)
            end
        end)
    end)
end

local function AddReturnItems(item, char)
    if not item.returnItems then return end
    if istable(item.returnItems) then
        for _, v in ipairs(item.returnItems) do
            char:GetInventory():Add(v)
        end
    else
        char:GetInventory():Add(item.returnItems)
    end
end

local function Cleanup(ply, weaponClass, ammoType, item)
    if not IsValid(ply) then return end
    if SERVER then
        -- Quitar el SWEP temporal
        if IsValid(ply:GetWeapon(weaponClass)) then
            ply:StripWeapon(weaponClass)
        end
        -- Quitar ammo token si aplica
        if ammoType and ammoType ~= "" then
            local left = ply:GetAmmoCount(ammoType)
            if left > 0 then ply:RemoveAmmo(left, ammoType) end
        end
        -- IMPORTANTE: Desbloquear clic derecho
        ply:SetNetVar("ix_consuming_cigarette", false)
    end

    -- Volver al arma anterior
    local prevClass = item and item.GetData and item:GetData("prevWepClass")
    if isstring(prevClass) and prevClass ~= "" then
        local prevW = ply:GetWeapon(prevClass)
        if IsValid(prevW) then
            ply:SelectWeapon(prevClass)
        end
    end
end

local function TakeOneFromStack(item)
    local count = item:GetData("stack", 1)
    if count > 1 then
        item:SetData("stack", count - 1)
        return false -- mantener el item (quedan más)
    end
    return true -- borrar el item (era el último)
end

ITEM.functions.Smoke = {
    name = "Fumar",
    tip = "useTip",
    icon = "icon16/add.png",

    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then
            if CLIENT then client = LocalPlayer() end
        end
        if not IsValid(client) or not client:Alive() then return false end
        if item:GetData("consuming", false) then return false end
        return true
    end,

    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end
        if item:GetData("consuming", false) then return false end
        item:SetData("consuming", true)

        -- Guarda arma previa
        local prev = ply:GetActiveWeapon()
        if IsValid(prev) then
            item:SetData("prevWepClass", prev:GetClass())
        end

        -- Sonido
        if item.useSound then
            if istable(item.useSound) then
                ix.util.EmitQueuedSounds(ply, item.useSound, 0, 0.1, 70, 100)
            else
                ply:EmitSound(item.useSound, 65)
            end
        end

        local duration = tonumber(item.consumeTime) or 3.2

        -- Ammo token opcional
        if SERVER and AMMO_TYPE ~= "" then
            ply:GiveAmmo(1, AMMO_TYPE, true)
        end

        -- Dar y seleccionar SWEP temporal
        if not IsValid(ply:GetWeapon(WEAPON_CLASS)) then
            ply:Give(WEAPON_CLASS)
        end
        ply:SelectWeapon(WEAPON_CLASS)

        -- === Marcar "consumiendo" y bloquear clic derecho ===
        if SERVER then
            ply:SetNetVar("ix_consuming_cigarette", true)

            -- Disparar animación en cliente
            net.Start("ix_cigarette_start")
                net.WriteFloat(duration)
                net.WriteString(WEAPON_CLASS)
            net.Send(ply)
        end

        -- (Opcional) feedback de acción en pantalla
        -- Si usas Helix SetAction, puedes añadir:
        -- ply:SetAction("Fumando...", duration)

        -- Fin de consumo: limpiar y stack
        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            if not item or not item.GetData then return end

            Cleanup(ply, WEAPON_CLASS, AMMO_TYPE, item)
            item:SetData("consuming", false)

            if SERVER then
                local keep = not TakeOneFromStack(item)
                if not keep then
                    local char = ply:GetCharacter()
                    if char then AddReturnItems(item, char) end
                    return true -- borrar item base
                else
                    return false -- conservar item con stack-1
                end
            end
        end)

        -- Fallback por si algo se interrumpe (también desbloquea clic derecho)
        timer.Simple(duration + 1.0, function()
            if not item or not item.SetData then return end
            if item:GetData("consuming", false) then
                item:SetData("consuming", false)
                Cleanup(ply, WEAPON_CLASS, AMMO_TYPE, item)
            end
        end)

        return false
    end
}