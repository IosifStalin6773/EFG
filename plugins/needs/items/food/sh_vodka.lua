
ITEM.name = "Vodka"
ITEM.weight = 0.5
ITEM.description = "Una botella de vodka."
ITEM.model = "models/lostsignalproject/items/consumable/vodka_nemiroff.mdl"
ITEM.category = "Bebidas"
ITEM.width = 1
ITEM.height = 2

ITEM.useSound = "items/medshot4.wav"

-- Total por botella completa (se reparte entre usos)
ITEM.restoreSaturation = 15
ITEM.restoreSatiety = 15

-- multiuso
ITEM.RemainingDefault = 4

-- si quieres devolver algo al terminar (ej: botella vacía)
ITEM.returnItems = {}

-- duración aproximada de la anim (ajústala si tu vodka dura más/menos)
ITEM.consumeTime = 4.0

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

        -- sonido item
        if istable(item.useSound) then
            ix.util.EmitQueuedSounds(ply, item.useSound, 0, 0.1, 70, 100)
        else
            ply:EmitSound(item.useSound, 70)
        end

        local class = "weapon_stalker2_vodka"
        local ammoType = "vodka"
        local duration = tonumber(item.consumeTime) or 4.0

        -- ammo token opcional
        if SERVER then
            ply:GiveAmmo(1, ammoType, true)
        end

        -- dar arma + seleccionar
        if not IsValid(ply:GetWeapon(class)) then
            ply:Give(class)
        end
        ply:SelectWeapon(class)

        ply:SetAction("Bebiendo...", duration)

        -- ✅ FIN: aquí limpiamos SIEMPRE y borramos si se agotó
        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            if not item or not item.GetData then return end

            -- aplicar needs (por uso)
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

                if (ix.drogas) then
                    ix.drogas.Apply(ply, "alcohol")
                end
            end

            -- bajar remaining al final
            local cur = item:GetData("remaining", item.RemainingDefault or 1) - 1
            item:SetData("remaining", cur)

            -- quitar arma temporal + limpiar ammo token
            if SERVER then
                if IsValid(ply:GetWeapon(class)) then
                    ply:StripWeapon(class)
                end

                local left = ply:GetAmmoCount(ammoType)
                if left > 0 then
                    ply:RemoveAmmo(left, ammoType)
                end
            end

            -- volver a arma previa
            local prevClass = item:GetData("prevWepClass")
            if isstring(prevClass) and prevClass ~= "" then
                local prevW = ply:GetWeapon(prevClass)
                if IsValid(prevW) then
                    ply:SelectWeapon(prevClass)
                end
            end

            item:SetData("consuming", false)

            -- borrar item si se agotó
            if cur <= 0 and SERVER then
                local char = ply:GetCharacter()
                if char then
                    AddReturnItems(item, char)
                end
                item:Remove()
            end
        end)

        timer.Simple(duration + 1.0, function()
            if not item or not item.SetData then return end
            if item:GetData("consuming", false) then
                item:SetData("consuming", false)
                if IsValid(ply) and SERVER then
                    if IsValid(ply:GetWeapon(class)) then
                        ply:StripWeapon(class)
                    end
                    local left = ply:GetAmmoCount(ammoType)
                    if left > 0 then
                        ply:RemoveAmmo(left, ammoType)
                    end
                end
            end
        end)

        return false
    end
}
