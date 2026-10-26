
ITEM.name = "Pan"
ITEM.weight = 0.3
ITEM.description = "Un trozo de pan."
ITEM.model = "models/weapons/sweps/stalker2/bread/w_item_bread.mdl"

ITEM.restoreSaturation = 5
ITEM.restoreSatiety = 35

ITEM.RemainingDefault = 4

ITEM.category = "Comestibles"
ITEM.useSound = "items/medshot4.wav"

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

local function BeginConsume(item, ply, weaponClass, actionText)
    if not IsValid(ply) then return false end

    local remaining = item:GetData("remaining", item.RemainingDefault or 1)
    if remaining <= 0 then
        if ply.Notify then ply:Notify("Está vacío.") end
        return false
    end

    if item:GetData("consuming", false) then return false end
    item:SetData("consuming", true)

    if istable(item.useSound) then
        ix.util.EmitQueuedSounds(ply, item.useSound, 0, 0.1, 70, 100)
    else
        ply:EmitSound(item.useSound, 70)
    end

    -- Hook temporal: se dispara desde el SWEP en el momento del consumo
    local hookName = "ixSt2Consume_" .. (ply.SteamID64 and ply:SteamID64() or ply:EntIndex()) .. "_" .. tostring(item.id or CurTime())

    hook.Add("Stalker2Consumable_Moment", hookName, function(p, wep, kind)
        if p ~= ply then return end
        if kind ~= item._st2Kind then return end

        hook.Remove("Stalker2Consumable_Moment", hookName)
        if not item or not item.GetData then return end

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

        local cur = item:GetData("remaining", item.RemainingDefault or 1) - 1
        item:SetData("remaining", cur)
        item:SetData("consuming", false)

        if cur <= 0 and SERVER then
            local char = ply:GetCharacter()
            if char then AddReturnItems(item, char) end
            item:Remove()
        end
    end)

    -- Fallback unlock
    timer.Simple(4.0, function()
        if not item or not item.SetData then return end
        if item:GetData("consuming", false) then
            item:SetData("consuming", false)
            hook.Remove("Stalker2Consumable_Moment", hookName)
        end
    end)

    if SERVER then
        -- ammo token (opcional)
        if item._st2Ammo then ply:GiveAmmo(1, item._st2Ammo, true) end
    end

    if not IsValid(ply:GetWeapon(weaponClass)) then
        ply:Give(weaponClass)
    end
    ply:SelectWeapon(weaponClass)

    ply:SetAction(actionText, 2.5)
    return false
end
ITEM._st2Kind = "bread"
ITEM._st2Ammo = "bread"

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
        return BeginConsume(item, item.player, "weapon_stalker2_bread", "Comiendo...")
    end
}
