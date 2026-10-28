
-- sh_plugin.lua (fragmento)
local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Meds"
PLUGIN.author      = "e71523 (adaptado)"
PLUGIN.description = "Meds de la colección convertidos a ítems de Helix con sonidos, animaciones y efectos persistentes."

PLUGIN.ActionDuration = 10.0
PLUGIN.TransparentUse = true

if SERVER then
    game.AddAmmoType({ name = "afak" })
    game.AddAmmoType({ name = "ibuprofen" })
    game.AddAmmoType({ name = "injectoradrenaline" })
    game.AddAmmoType({ name = "morphine" })
    game.AddAmmoType({ name = "augmentin" })
end

PLUGIN.Meds = {
    afak = { swepClass = "weapon_eft_afak", ammoType = "afak", startFunc = "StartBandageSequence", maxHeal = 30 },
    ibuprofen = { swepClass = "weapon_eft_ibuprofen", ammoType = "ibuprofen", startFunc = "StartPillsSequence", maxHeal = 0 },
    adrenaline = { swepClass = "weapon_eft_injectoradrenaline", ammoType = "injectoradrenaline", startFunc = "StartInjectorSequence", maxHeal = 0 },
    morphine  = { swepClass = "weapon_eft_injectormorphine", ammoType = "morphine", startFunc = "StartInjectorSequence", maxHeal = 0 },
    augmentin = { swepClass = "weapon_eft_augmentin", ammoType = "augmentin", startFunc = "StartPillsSequence", maxHeal = 0 }
}

-- ===== Publica helpers/config en un namespace global =====
ix.eftMeds = ix.eftMeds or {}

function ix.eftMeds.Get(id)
    -- devuelve tabla config del med o nil
    return PLUGIN.Meds[id]
end

function ix.eftMeds.PlaySequence(ply, sndNames, step)
    step = step or 0.45
    if not IsValid(ply) then return 0 end
    local t = 0
    for _, name in ipairs(sndNames or {}) do
        timer.Simple(t, function()
            if IsValid(ply) then
                ply:EmitSound(name, 65, math.random(95, 105), 1, CHAN_AUTO)
            end
        end)
        t = t + step
    end
    return t
end

-- ¿Está instalado el contenido (modelo de vista) de este SWEP? Sin el addon de
-- animaciones el medicamento funciona igual, solo con la barra de acción.
function ix.eftMeds.HasAnimation(swepClass)
    local stored = weapons.GetStored(swepClass)
    local model = stored and stored.ViewModel
    return isstring(model) and model ~= "" and file.Exists(model, "GAME")
end

-- Modelo del objeto: el del addon si está instalado, si no uno genérico de HL2
function ix.eftMeds.Model(path, fallback)
    return file.Exists(path, "GAME") and path or (fallback or "models/healthvial.mdl")
end

function ix.eftMeds.GiveAndSelectMedWep(ply, swepClass, item)
    if not IsValid(ply) or not isstring(swepClass) or swepClass == "" then return end
    if not ix.eftMeds.HasAnimation(swepClass) then return end
    local wep = ply:GetWeapon(swepClass)
    if not IsValid(wep) then wep = ply:Give(swepClass) end
    local prev = ply:GetActiveWeapon()
    if IsValid(prev) and prev:GetClass() ~= swepClass and item and item.SetData then
        item:SetData("prevWepClass", prev:GetClass())
    end
    ply:SelectWeapon(swepClass)
    return wep
end

function ix.eftMeds.CleanupMedUse(ply, swepClass, ammoType, item)
    if not IsValid(ply) then return end
    if SERVER then
        local cur = ply:GetWeapon(swepClass)
        if IsValid(cur) then ply:StripWeapon(swepClass) end
        if isstring(ammoType) and ammoType ~= "" then
            local left = ply:GetAmmoCount(ammoType)
            if left > 0 then ply:RemoveAmmo(left, ammoType) end
        end
    end
    if PLUGIN.TransparentUse and item and item.GetData then
        local prevClass = item:GetData("prevWepClass")
        if isstring(prevClass) and prevClass ~= "" then
            local prevW = ply:GetWeapon(prevClass)
            if IsValid(prevW) then ply:SelectWeapon(prevClass) end
        end
    end
end

function ix.eftMeds.StartMedSequence(wep, funcName, duration)
    if IsValid(wep) and isstring(funcName) and wep[funcName] ~= nil then
        local f = wep[funcName]
        if isfunction(f) then
            if duration ~= nil then f(wep, duration) else f(wep) end
        end
    end
end

-- (Opcional) feedback por red
if SERVER then
    util.AddNetworkString("ixEFTMedFeedback")
    hook.Add("EFT_MedApplied", "ixEFT_Hook_MedApplied", function(ply, itemUniqueID, data)
        if IsValid(ply) then
            net.Start("ixEFTMedFeedback")
            net.WriteString(itemUniqueID or "")
            net.WriteTable(data or {})
            net.Send(ply)
        end
    end)
end

-- SWEPs (no incluyas ítems aquí). Las medicinas de EFT están ahora en
-- efg_health (sh_medanim.lua y sh_medweapon.lua); las antiguas, en _retirados/anims_meds_eft.
ix.util.Include("sh_stalker2_consumables.lua")

ix.util.Include("weapons/sh_weapon_stalker2_water.lua")
ix.util.Include("weapons/sh_weapon_stalker2_bread.lua")
ix.util.Include("weapons/sh_weapon_stalker2_canned.lua")
ix.util.Include("weapons/sh_weapon_stalker2_vodka.lua")
ix.util.Include("weapons/sh_weapon_stalker2_energy.lua")
ix.util.Include("weapons/sh_weapon_stalker2_milk.lua")
ix.util.Include("weapons/sh_weapon_stalker2_sausage.lua")
