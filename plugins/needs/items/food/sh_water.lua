ITEM.name = "Agua"
ITEM.weight = 0.5
ITEM.description = "Una botella con agua filtrada, es segura para beber."
ITEM.model = "models/illusion/eftcontainers/waterbottle.mdl"
ITEM.category = "Bebidas"
ITEM.width = 1
ITEM.height = 2

ITEM.useSound = "items/medshot4.wav"

-- Total que quieres recuperar por botella completa.
ITEM.restoreSaturation = 55
ITEM.restoreSatiety = 0

-- Si quieres devolver algo al acabarse (ej: botella vacía)
ITEM.returnItems = {}

-- Sistema base 'foods' (multiuso)
ITEM.RemainingDefault = 4

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

ITEM.functions.Consume = {
    name = "Beber",
    tip = "useTip",
    icon = "icon16/drink.png",

    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then
            if CLIENT then client = LocalPlayer() end
        end
        if not IsValid(client) then return false end

        if item:GetData("drinking", false) then return false end
        local remaining = item:GetData("remaining", item.RemainingDefault or 1)
        return remaining > 0
    end,

    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end

        local remaining = item:GetData("remaining", item.RemainingDefault or 1)
        if remaining <= 0 then
            if ply.Notify then ply:Notify("Está vacío.") end
            return false
        end

        if item:GetData("drinking", false) then return false end
        item:SetData("drinking", true)

        -- Reproducir sonido de uso del item (opcional)
        if istable(item.useSound) then
            ix.util.EmitQueuedSounds(ply, item.useSound, 0, 0.1, 70, 100)
        else
            ply:EmitSound(item.useSound, 70)
        end

        -- Hook temporal: cuando el SWEP marque el 'momento de beber', aplicamos efectos y restamos remaining
        local hookName = "ixWaterDrink_" .. (ply.SteamID64 and ply:SteamID64() or ply:EntIndex()) .. "_" .. tostring(item.id or CurTime())

        hook.Add("Stalker2Water_DrinkMoment", hookName, function(p, wep)
            if p ~= ply then return end

            -- Limpieza preventiva
            hook.Remove("Stalker2Water_DrinkMoment", hookName)

            if not item or not item.GetData then return end

            -- Aplica necesidades en servidor
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
                end
            end

            local cur = item:GetData("remaining", item.RemainingDefault or 1)
            cur = cur - 1
            item:SetData("remaining", cur)
            item:SetData("drinking", false)

            if cur <= 0 then
                if SERVER then
                    local char = ply:GetCharacter()
                    if char then
                        AddReturnItems(item, char)
                    end
                    item:Remove()
                end
            end
        end)

        -- Fallback: si por lo que sea no llega el hook (SWEP roto), desbloquea a los ~3s
        timer.Simple(3.5, function()
            if not item or not item.SetData then return end
            if item:GetData("drinking", false) then
                item:SetData("drinking", false)
                hook.Remove("Stalker2Water_DrinkMoment", hookName)
            end
        end)

        -- Dar arma y seleccionar (el SWEP se anima al Deploy)
        local class = "weapon_stalker2_water"

        if SERVER then
            ply:GiveAmmo(1, "water", true)
        end

        if not IsValid(ply:GetWeapon(class)) then
            ply:Give(class)
        end
        ply:SelectWeapon(class)

        -- Acción HUD (cosmético)
        ply:SetAction("Bebiendo...", 2.0)

        return false
    end
}
