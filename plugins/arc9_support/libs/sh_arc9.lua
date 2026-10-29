
local PLUGIN = PLUGIN

ix.arc9 = {}
ix.arc9.attachments = {}
ix.arc9.grenades = {}
ix.arc9.freeAttachments = {}

if SERVER then
    -- set up a weapon's attachments on equip, based on it's default value or data
    function ix.arc9.InitWeapon(client, weapon, item)
        if !IsValid(client) or !IsValid(weapon) or !item then return end

        -- ARC9 llena el cargador al crear el arma y otra vez en el primer
        -- PostModify (AlreadyGaveAmmo); se vacía aquí y se pone el del ítem después
        if !item.isGrenade then
            weapon:SetClip1(0)
            weapon.AlreadyGaveAmmo = true
        end

        -- balas extra de cargador por accesorios (efg_mods, magBonus)
        local bonus = 0

        for _, uniqueID in pairs(item:GetData("efgMods", {})) do
            local mod = ix.item.list[uniqueID]
            bonus = bonus + (mod and mod.magBonus or 0)
        end

        weapon:SetNW2Int("efgMagBonus", bonus)

        -- efg_mags: cargador puesto y su capacidad
        hook.Run("EFG_ARC9InitWeapon", client, weapon, item)

        ix.arc9.SendPreset(client, weapon, item:GetPreset(), true)
    end

    -- pone las balas guardadas en el ítem; va un tick después del PostModify
    -- para que su comprobación de cambio de cargador no las pise
    local function restoreClip(weapon)
        timer.Simple(0, function()
            if !IsValid(weapon) or !weapon.ixItem then return end

            if weapon.ixItem.isGrenade then
                weapon:SetClip1(1)
                return
            end

            weapon:SetClip1(weapon.ixItem:GetData("ammo", 0))

            if weapon.SetRequestReload then
                weapon:SetRequestReload(false)
            end
        end)
    end

    -- replacement for ARC9.SendPreset()
    function ix.arc9.SendPreset(client, weapon, preset, setAmmo)
        if !IsValid(client) or !client:IsPlayer() or !IsValid(weapon) then
            return
        end

        if !isstring(preset) then -- no preset found, so we just need to set the ammo
            if setAmmo then
                -- recalcula el tamaño del cargador (accesorios de efg_mods)
                if weapon.PostModify then
                    weapon:PostModify()
                    weapon:CallOnClient("InvalidateCache")
                end

                restoreClip(weapon)
            end

            return
        end

        if IsValid(weapon) then
            if !ix.config.Get("freeAttachments(ARC9)", false) or !GetConVar("arc9_free_atts"):GetBool() then
                local atts = ARC9.GetAttsFromPreset("[ix]"..preset) -- expects a preset name to be trimmed, so just give it a fake one
                if !atts then return end

                ix.arc9.GiveAttsFromList(client, atts)
            end

            -- clear all original attachments so they dont get added as items/AttInv entries when we apply the preset
            weapon.Attachments = baseclass.Get(weapon:GetClass()).Attachments
            for slot, slottbl in ipairs(weapon.Attachments) do
                slottbl.Installed = nil
                slottbl.SubAttachments = nil
            end

            weapon:SetNoPresets(true)

            -- on proper servers, we need to wait until the weapon is valid on the client. this is also how its done in the base, surprisingly. i kinda hate it
            timer.Simple(0.1, function()
                net.Start("ixARC9SendPreset")
                    net.WriteEntity(weapon)
                    net.WriteString(preset)
                net.Send(client)

                weapon:PostModify()

                if setAmmo then
                    restoreClip(weapon)
                end
            end)
        end
    end

    -- replacement for ARC9.GiveAttsFromList() that will never give the player items, only add to their AttInv
    function ix.arc9.GiveAttsFromList(client, tbl)
        local take = false

        for i, k in pairs(tbl) do
            ARC9:PlayerGiveAtt(client, k, 1, true)
            take = true
        end

        if take then ARC9:PlayerSendAttInv(client) end
    end
end

-- generates attachment items automatically
function ix.arc9.GenerateAttachments()
    if ix.arc9.attachmentsGenerated then return end

    for attID, attTable in pairs(ARC9.Attachments) do
        -- EFT: cargadores y munición van por efg_mags y efg_ballistics; en ARC9
        -- son libres (solo cambian el aspecto) y no se crean como objetos
        local attType = ix.arc9.GetAttType(attID, attTable)

        local id = string.lower(attID)

        if (attType == "magazine" and (string.find(id, "mag_", 1, true) or string.find(id, "drum", 1, true)))
            or (attType == "ammo" and string.find(id, "ammo", 1, true)) then
            ix.arc9.MakeFreeAttachment(attID)
        end

        if !ix.arc9.IsFreeAttachment(attID) and !attTable.AdminOnly and !ARC9.Blacklist[attID] then
            if !ix.arc9.attachments[attID] and !(attTable.InvAtt and ix.arc9.attachments[attTable.InvAtt]) then
                local ITEM = ix.item.Register(attID, "base_arc9_attachments", false, nil, true)
                ITEM.name = attTable.PrintName
                ITEM.description = attTable.Description or "An attachment, used to modify weapons."
                ITEM.isGenerated = true

                if attTable.DropMagazineModel then
                    ITEM.model = attTable.DropMagazineModel
                else
                    ITEM.model = "models/items/arc9/att_cardboard_box.mdl"
                end
                
                if attTable.InvAtt then
                    ITEM.att = attTable.InvAtt
                else
                    ITEM.att = attID
                end

                -- tamaño y peso de Tarkov según el tipo de pieza (EFT_Stats)
                local attType = ix.arc9.GetAttType(attID, attTable)
                local eft = ix.arc9.GetEFTAttStats(attID, attTable)
                ITEM.width, ITEM.height = ix.arc9.GetAttSize(attType)
                ITEM.weight = eft.weight or 0.1
                ITEM.eftType = attType
                ITEM.category = "Accesorios"

                ix.arc9.attachments[ITEM.att] = attID
            end
        end
    end

    ix.arc9.attachmentsGenerated = true
end

-- generates weapon items automatically
function ix.arc9.GenerateWeapons()
    if ix.arc9.weaponsGenerated then return end

    for _, v in ipairs(weapons.GetList()) do
        if v.PrintName and weapons.IsBasedOn(v.ClassName, "arc9_base") and !string.find(v.ClassName, "base") then
            local ITEM = ix.item.Register(v.ClassName, "base_arc9_weapons", false, nil, true)
            ITEM.name = v.PrintName
            ITEM.description = v.Description or nil
            ITEM.class = v.ClassName
            ITEM.isGenerated = true

            local class
            if v.Class then
                class = v.Class:lower():gsub("%s+", "")
            end

            -- i tried my best to update these for consistency, but most of ARC9's definitions are arbitrary. this WILL produce bad results somewhere.
            if v.Throwable or (class and string.find(class, "grenade") and !string.find(class, "launch")) then
                ITEM.weaponCategory = "Throwable"
                ITEM.width = 1
                ITEM.height = 1
                ITEM.isGrenade = true
                ITEM.model = v.WorldModel or "models/weapons/w_eq_fraggrenade.mdl"

                ix.arc9.grenades[v.ClassName] = true
            elseif (v.NotAWeapon) then
                ITEM.width = 1
                ITEM.height = 1
                ITEM.model = v.WorldModel or "models/weapons/w_defuser.mdl"
            elseif v.PrimaryBash or v.HoldType == "melee" or v.HoldType == "melee2" or v.HoldType == "knife" or v.HoldType == "fist" or (class and string.find(class, "melee")) then
                ITEM.weaponCategory = "Melee"
                ITEM.width = 1
                ITEM.height = 2
                ITEM.model = v.WorldModel or "models/weapons/w_knife_ct.mdl"
            elseif v.HoldType == "pistol" or v.HoldType == "revolver" or (class and (string.find(class, "pistol") or string.find(class, "revolver"))) then
                ITEM.weaponCategory = "Secondary"
                ITEM.width = 2
                ITEM.height = 2
                if class and string.find(class, "revolver") then
                    ITEM.model = v.WorldModel or "models/weapons/w_357.mdl"
                else
                    ITEM.model = v.WorldModel or "models/weapons/w_pist_elite_single.mdl"
                end
            else
                ITEM.weaponCategory = "Primary"
                ITEM.model = v.WorldModel or "models/weapons/w_rif_m4a1.mdl" -- most weapons use an invisible css world model with bonemerged attachments, so this probably wont look right
                ITEM.width = 3
                ITEM.height = 2

                -- this is largely cosmetic but i think it helps
                if class then
                    if string.find(class, "shotgun") then
                        ITEM.model = v.WorldModel or "models/weapons/w_shot_m3super90.mdl"
                        ITEM.width = 3
                        ITEM.height = 2
                    elseif string.find(class, "sniper") or string.find(class, "marksman") then
                        ITEM.model = v.WorldModel or "models/weapons/w_snip_scout.mdl"
                        ITEM.width = 4
                        ITEM.height = 2
                    elseif string.find(class, "smg") or string.find(class, "submachine") then
                        ITEM.model = v.WorldModel or "models/weapons/w_smg_ump45.mdl"
                        ITEM.width = 3
                        ITEM.height = 2
                    elseif string.find(class, "lmg") or string.find(class, "machinegun") or string.find(class, "hmg") then
                        ITEM.model = v.WorldModel or "models/weapons/w_mach_m249para.mdl"
                        ITEM.width = 4
                        ITEM.height = 2
                    end
                end
            end

            -- tamaño real de Tarkov (pistola 2x1, subfusil 3x2, fusil 4x2,
            -- tirador 5x2...) y categoría en minúsculas para efg_inspect
            if !ITEM.isGrenade and !v.NotAWeapon then
                ITEM.width, ITEM.height = ix.arc9.GetWeaponSize(v, class)
            end
            ITEM.weaponCategory = string.lower(ITEM.weaponCategory or "primary")
            ITEM.weight = ITEM.weight or ix.arc9.GetWeaponWeight(ITEM.width, ITEM.height)
        end
    end

    ix.arc9.weaponsGenerated = true
end

function ix.arc9.SetAlwaysRaised()
    local raised = ix.config.Get("alwaysRaised(ARC9)", false)

    if raised then
        for _, v in ipairs(weapons.GetList()) do
            local class = v.ClassName
            if weapons.IsBasedOn(class, "arc9_base") and !string.find(class, "base") and !ALWAYS_RAISED[class] then
                ALWAYS_RAISED[class] = true
            end
        end
    else
        for _, v in ipairs(weapons.GetList()) do
            local class = v.ClassName
            if weapons.IsBasedOn(class, "arc9_base") and !string.find(class, "base") and ALWAYS_RAISED[class] then
                ALWAYS_RAISED[class] = nil
            end
        end
    end
end

-- returns the item id for the passed attachment id
function ix.arc9.GetItemForAttachment(att)
    return ix.arc9.attachments[att]
end

function ix.arc9.IsFreeAttachment(att)
    local atttbl = ARC9.GetAttTable(att)
    return ix.arc9.freeAttachments[att] or (atttbl and atttbl.Free)
end

function ix.arc9.MakeFreeAttachment(att)
    ix.arc9.freeAttachments[att] = true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EFT: tamaños, bonus/malus de accesorios y recálculo de stats
-- ═══════════════════════════════════════════════════════════════════════════

-- Bonus/malus de EFT por tipo de pieza. recoil y accuracy en % (negativo =
-- mejor), ergo en puntos, weight en kg. Una entrada con el ID exacto del
-- accesorio de ARC9 tiene prioridad sobre la del tipo.
ix.arc9.EFT_Stats = ix.arc9.EFT_Stats or {
    -- bocachas
    muzzle_brake = {recoil = -5,  ergo = -2,  weight = 0.10},
    compensator  = {recoil = -4,  ergo = -1,  weight = 0.09},
    flash_hider  = {recoil = -2,  ergo = -1,  weight = 0.07},
    suppressor   = {recoil = -8,  ergo = -12, weight = 0.50, accuracy = -2},
    muzzle       = {recoil = -3,  ergo = -1,  weight = 0.08},
    -- miras
    scope        = {ergo = -4,  weight = 0.45},
    sight        = {ergo = -1,  weight = 0.15},
    mount        = {ergo = -1,  weight = 0.06},
    -- cuerpo
    barrel       = {recoil = -2,  ergo = -3,  weight = 0.60, accuracy = -10},
    handguard    = {recoil = -2,  ergo = 3,   weight = 0.25},
    foregrip     = {recoil = -3,  ergo = 4,   weight = 0.08},
    pistol_grip  = {recoil = -1,  ergo = 3,   weight = 0.06},
    stock        = {recoil = -12, ergo = 6,   weight = 0.30},
    buffer       = {recoil = -3,  ergo = 1,   weight = 0.10},
    gas_block    = {recoil = -1,  ergo = 0,   weight = 0.05},
    receiver     = {recoil = -1,  ergo = 0,   weight = 0.20},
    charging     = {ergo = 1,     weight = 0.02},
    -- otros
    magazine     = {ergo = -3,  weight = 0.25},
    tactical     = {ergo = -1,  weight = 0.10},
    bipod        = {recoil = -6,  ergo = -4,  weight = 0.30},
    ammo         = {},
    other        = {weight = 0.05},
}

-- tipo por palabras clave del ID, la categoría y la carpeta del accesorio.
-- El orden importa: "muzzle_brake" antes que "muzzle", "scope" antes que "sight"...
ix.arc9.EFT_TypePatterns = ix.arc9.EFT_TypePatterns or {
    {"suppressor", {"suppress", "silenc", "_pbs", "tgp", "_sup", "_can"}},
    {"muzzle_brake", {"brake", "_mb", "dtk"}},
    {"compensator", {"compens", "_comp"}},
    {"flash_hider", {"flash", "hider", "_fh"}},
    {"muzzle", {"muzzle", "thread"}},
    {"scope", {"scope", "optic_", "pso", "x4", "x6", "acog", "magnif"}},
    {"sight", {"sight", "reflex", "holo", "red_dot", "reddot", "collim", "ironsight", "optic"}},
    {"mount", {"mount", "rail", "_rings"}},
    {"barrel", {"barrel"}},
    {"handguard", {"handguard", "_hg", "foreend"}},
    {"foregrip", {"foregrip", "_fg", "vertgrip", "afg"}},
    {"pistol_grip", {"pistolgrip", "pistol_grip", "_pg", "grip"}},
    {"stock", {"stock", "butt"}},
    {"buffer", {"buffer", "tube"}},
    {"gas_block", {"gasblock", "gas_block", "gas"}},
    {"receiver", {"receiver", "dustcover", "dust_cover", "upper", "lower"}},
    {"charging", {"charging", "chandle"}},
    {"magazine", {"mag", "drum", "clip"}},
    {"tactical", {"tactical", "laser", "light", "peq", "lam"}},
    {"bipod", {"bipod"}},
    {"ammo", {"ammo", "round", "bullet"}},
}

-- tamaño en la rejilla (ancho, alto) por tipo, como en Tarkov
ix.arc9.EFT_AttSizes = ix.arc9.EFT_AttSizes or {
    suppressor = {2, 1}, barrel = {2, 1}, handguard = {2, 1}, stock = {2, 1}, scope = {2, 1},
    receiver = {2, 1}, bipod = {2, 1}, magazine = {1, 2},
}

local function attText(attID, atttbl)
    local parts = {string.lower(attID or "")}

    if atttbl then
        local cat = atttbl.Category
        if istable(cat) then
            for _, c in ipairs(cat) do parts[#parts + 1] = string.lower(tostring(c)) end
        elseif cat then
            parts[#parts + 1] = string.lower(tostring(cat))
        end

        if atttbl.Folder then parts[#parts + 1] = string.lower(tostring(atttbl.Folder)) end
    end

    return table.concat(parts, " ")
end

function ix.arc9.GetAttType(attID, atttbl)
    atttbl = atttbl or (ARC9 and ARC9.GetAttTable(attID))
    local text = attText(attID, atttbl)

    for _, entry in ipairs(ix.arc9.EFT_TypePatterns) do
        for _, key in ipairs(entry[2]) do
            if string.find(text, key, 1, true) then return entry[1] end
        end
    end

    return "other"
end

function ix.arc9.GetEFTAttStats(attID, atttbl)
    local stats = ix.arc9.EFT_Stats
    return stats[attID] or stats[ix.arc9.GetAttType(attID, atttbl)] or stats.other
end

function ix.arc9.GetAttSize(attType)
    local size = ix.arc9.EFT_AttSizes[attType]
    if size then return size[1], size[2] end
    return 1, 1
end

-- tamaño de un arma de ARC9 según su clase/holdtype
function ix.arc9.GetWeaponSize(swep, class)
    class = class or string.lower(tostring(swep.Class or ""))
    local id = string.lower(swep.ClassName or "")
    local text = class .. " " .. id .. " " .. string.lower(tostring(swep.HoldType or ""))

    if string.find(text, "pistol") or string.find(text, "revolver") then return 2, 1 end
    if string.find(text, "smg") or string.find(text, "submachine") or string.find(text, "pdw") then return 3, 2 end
    if string.find(text, "sniper") or string.find(text, "bolt") or string.find(text, "marksman") or string.find(text, "dmr") then return 5, 2 end
    if string.find(text, "lmg") or string.find(text, "machinegun") then return 5, 2 end
    if string.find(text, "shotgun") then return 4, 2 end
    if string.find(text, "carbine") then return 4, 2 end

    return 4, 2
end

function ix.arc9.GetWeaponWeight(w, h)
    return math.Round(0.4 + w * h * 0.38, 1)
end

-- preset de ARC9 limpio: sin "[nombre]" delante, comillas, saltos de línea
-- ni caracteres de control que rompan el JSON de la UI
function ix.arc9.CleanPreset(preset)
    if !isstring(preset) then return nil end

    preset = string.Trim(preset)
    preset = string.gsub(preset, "^%[[^%]]*%]", "")
    -- fuera: caracteres de control, comillas y barras invertidas (lo único
    -- que puede romper un JSON); el resto del código de ARC9 se deja igual
    preset = string.gsub(preset, "[%c\"\\]", "")

    if preset == "" or #preset > 16384 then return nil end
    return preset
end

-- lista de accesorios de un preset (sin necesitar el arma)
function ix.arc9.GetPresetAtts(preset)
    preset = ix.arc9.CleanPreset(preset)
    if !preset or !ARC9 or !ARC9.GetAttsFromPreset then return {} end

    local ok, atts = pcall(ARC9.GetAttsFromPreset, "[ix]" .. preset)
    return (ok and istable(atts)) and atts or {}
end

-- stats EFT de un arma con una lista de accesorios (IDs de ARC9)
function ix.arc9.CalcEFTStats(item, attList)
    local INS = ix.efg and ix.efg.inspect
    local base = INS and INS.BaseStats(item) or {ergo = 50, recoilV = 150, recoilH = 300, accuracy = 3, weight = item.weight or 3}
    local ergo, recoil, accuracy, weight = 0, 0, 0, 0

    for _, att in pairs(attList or {}) do
        if isstring(att) and att != "" then
            local st = ix.arc9.GetEFTAttStats(att)
            ergo = ergo + (st.ergo or 0)
            recoil = recoil + (st.recoil or 0)
            accuracy = accuracy + (st.accuracy or 0)
            weight = weight + (st.weight or 0)
        end
    end

    local recoilMult = math.max(0.2, 1 + recoil / 100)
    local accMult = math.max(0.2, 1 + accuracy / 100)

    return {
        ergo = math.Clamp(math.Round(base.ergo + ergo), 0, 100),
        recoilV = math.Round(base.recoilV * recoilMult),
        recoilH = math.Round(base.recoilH * recoilMult),
        accuracy = math.Round(base.accuracy * accMult, 2),
        weight = math.Round(base.weight + weight, 3),
    }
end

-- accesorios instalados ahora mismo en un arma de ARC9
function ix.arc9.GetInstalledAtts(weapon)
    local out = {}
    if !IsValid(weapon) or !weapon.GetSubSlotList then return out end

    for _, slot in ipairs(weapon:GetSubSlotList()) do
        if isstring(slot.Installed) and slot.Installed != "" then out[#out + 1] = slot.Installed end
    end

    return out
end

-- busca el ítem de Helix de un arma de ARC9 (en el cliente no hay ixItem)
function ix.arc9.GetWeaponItem(client, weapon)
    if !IsValid(weapon) then return end
    if weapon.ixItem then return weapon.ixItem end

    local character = IsValid(client) and client:GetCharacter()
    local inventory = character and character:GetInventory()
    if !inventory then return end

    for item, _ in inventory:Iter() do
        if item.class == weapon:GetClass() and item:GetData("equip") then return item end
    end
end

-- ¿se usa la ventana de EFG en vez del menú de ARC9?
function ix.arc9.UseEFTInspect()
    return ix.config.Get("eftInspectUI(ARC9)", true) and ix.efg and ix.efg.inspect != nil
end

-- Recalcula ergonomía, retroceso, precisión y peso EFT con los accesorios
-- montados. Se guarda en weapon.EFTStats y, en el servidor, en el dato
-- "efgStats" del ítem (lo lee la ventana de inspección).
function UpdateEFTStats(weapon)
    if !IsValid(weapon) or !weapon.ARC9 then return end

    local client = weapon:GetOwner()
    local item = ix.arc9.GetWeaponItem(client, weapon) or {weaponCategory = "primary", weight = 3}
    local stats = ix.arc9.CalcEFTStats(item, ix.arc9.GetInstalledAtts(weapon))

    weapon.EFTStats = stats

    if SERVER and weapon.ixItem and weapon.ixItem.SetData then
        weapon.ixItem:SetData("efgStats", stats)
    end

    hook.Run("EFGWeaponStatsUpdated", weapon, stats)
    return stats
end

if SERVER then
    util.AddNetworkString("ixEFGArc9Inspect")

    -- abre la ventana DHTML de inspección/modding del arma (banco o tecla de
    -- personalizar de ARC9). El arma queda en modo personalizar en el servidor
    -- para que ARC9 acepte los cambios de accesorios que mande el cliente.
    function ix.arc9.OpenEFTInspect(client, weapon)
        if !IsValid(client) or !IsValid(weapon) or !weapon.ARC9 then return false end

        local item = weapon.ixItem or ix.arc9.GetWeaponItem(client, weapon)
        if !item then return false end

        if !weapon:GetCustomize() then
            weapon:SetCustomize(true)
            weapon:SetShouldHoldType()
            weapon:SetInSights(false)
        end

        UpdateEFTStats(weapon)

        net.Start("ixEFGArc9Inspect")
            net.WriteUInt(item:GetID(), 32)
            net.WriteEntity(weapon)
        net.Send(client)

        return true
    end
else
    net.Receive("ixEFGArc9Inspect", function()
        local item = ix.item.instances[net.ReadUInt(32)]
        local weapon = net.ReadEntity()

        if item and ix.efg and ix.efg.inspect and ix.efg.inspect.Open then
            ix.efg.inspect.Open(item, IsValid(weapon) and weapon or nil)
        end
    end)
end
