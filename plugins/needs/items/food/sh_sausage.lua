ITEM.name = "Salchicha"
ITEM.weight = 0.2
ITEM.description = "Una salchicha hecha con carne seca, común y acompañada de algo de pan hace una buena ración."
ITEM.model = "models/lostsignalproject/items/consumable/sausage.mdl"
ITEM.category = "Comestibles"

ITEM.useSound = "items/medshot4.wav"

-- Total por objeto completo (se reparte entre usos)
ITEM.restoreSaturation = 5
ITEM.restoreSatiety = 45

-- Multi-uso (remaining)
ITEM.RemainingDefault = 3

-- Duración aproximada de la animación (ajústala si tu anim dura más/menos)
ITEM.consumeTime = 3.2

-- Items devueltos al terminar (ej: envase vacío). Déjalo vacío si no quieres.
ITEM.returnItems = {}

function ITEM:OnInstanced(invID, x, y, item)
    if item then
        item:SetData("remaining", item.RemainingDefault or 1)
    end
end

if CLIENT then
    function ITEM:PopulateTooltip(tooltip)
        local panel = tooltip:AddRowAfter("name", "remaining")
        panel:SetText("Restante: " .. self:GetData("remaining", self.RemainingDefault or 1))
        panel:SizeToContents()
    end
end

-- Devuelve la vida máxima real teniendo en cuenta las heridas acumuladas.
-- Usa el plugin medico si está disponible; cae a GetMaxHealth() si no.
local function GetVidaMaxima(client)
    local char = IsValid(client) and client:GetCharacter()
    local medicoPlugin = ix.plugin.Get("medico")
    if (medicoPlugin and char) then
        return medicoPlugin:CalcularVidaMaxima(char:GetHeridas() or 0)
    end
    return client:GetMaxHealth()
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

    -- retirar arma temporal + limpiar ammo token
    if SERVER then
        if IsValid(ply:GetWeapon(weaponClass)) then
            ply:StripWeapon(weaponClass)
        end
        if ammoType and ammoType ~= "" then
            local left = ply:GetAmmoCount(ammoType)
            if left > 0 then ply:RemoveAmmo(left, ammoType) end
        end
    end

    -- volver al arma anterior
    local prevClass = item and item.GetData and item:GetData("prevWepClass")
    if isstring(prevClass) and prevClass ~= "" then
        local prevW = ply:GetWeapon(prevClass)
        if IsValid(prevW) then
            ply:SelectWeapon(prevClass)
        end
    end
end

ITEM.functions.Consume = {
    name = "Comer",
    tip = "useTip",
    icon = "icon16/food.png",

    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then
            if CLIENT then client = LocalPlayer() end
        end
        if not IsValid(client) then return false end

        if item:GetData("consuming", false) then return false end
        return item:GetData("remaining", item.RemainingDefault or 1) > 0
    end,

    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end

        local remaining = item:GetData("remaining", item.RemainingDefault or 1)
        if remaining <= 0 then
            if ply.Notify then ply:Notify("Está vacío.") end
            return false
        end

        if item:GetData("consuming", false) then return false end
        item:SetData("consuming", true)

        -- guardar arma previa
        local prev = ply:GetActiveWeapon()
        if IsValid(prev) then
            item:SetData("prevWepClass", prev:GetClass())
        end

        -- sonido del item
        if istable(item.useSound) then
            ix.util.EmitQueuedSounds(ply, item.useSound, 0, 0.1, 70, 100)
        else
            ply:EmitSound(item.useSound, 70)
        end

        local weaponClass = "weapon_stalker2_sausage"
        local ammoType = "sausage"
        local duration = tonumber(item.consumeTime) or 3.2

        -- ammo token opcional
        if SERVER then
            ply:GiveAmmo(1, ammoType, true)
        end

        -- dar arma y seleccionar
        if not IsValid(ply:GetWeapon(weaponClass)) then
            ply:Give(weaponClass)
        end
        ply:SelectWeapon(weaponClass)

        ply:SetAction("Comer...", duration)

        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            if not item or not item.GetData then return end

            -- aplicar needs al final
            if SERVER then
                local char = ply:GetCharacter()
                if char then
                    local maxUses = item.RemainingDefault or 1
                    if item.restoreSaturation then
                        char:RestoreSaturation(item.restoreSaturation / maxUses)
                    end
                    if item.restoreSatiety then
                        char:RestoreSatiety(item.restoreSatiety / maxUses)
                    end

                    if (ix.temperatura) then
                        ix.temperatura.Calentar(ply, 4)
                    end
                end
                ply:SetHealth(math.min(ply:Health() + 5, GetVidaMaxima(ply)))
            end

            -- decrementar remaining al final
            local cur = item:GetData("remaining", item.RemainingDefault or 1) - 1
            item:SetData("remaining", cur)

            -- cleanup siempre
            Cleanup(ply, weaponClass, ammoType, item)

            item:SetData("consuming", false)

            -- borrar item si se agotó
            if SERVER and cur <= 0 then
                local char = ply:GetCharacter()
                if char then
                    AddReturnItems(item, char)
                end
                item:Remove()
            end
        end)

        -- fallback por si algo se corta
        timer.Simple(duration + 1.0, function()
            if not item or not item.SetData then return end
            if item:GetData("consuming", false) then
                item:SetData("consuming", false)
                Cleanup(ply, "weapon_stalker2_sausage", "sausage", item)
            end
        end)

        return false
    end
}
