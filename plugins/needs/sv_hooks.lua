
local PLUGIN = PLUGIN

function PLUGIN:CharacterVarChanged(character, key, oldValue, value)
    local client = character:GetPlayer()
    if (client and IsValid(client)) then
        if (key == "saturation") then
            client:SetLocalVar("saturation", value)
        end

        if (key == "satiety") then
            client:SetLocalVar("satiety", value)
        end
    end
end

function PLUGIN:PlayerLoadedCharacter(client, character, _)
    if (!IsValid(client) or !client:IsPlayer() or !character) then return end
    if (character:GetSaturation()) then
        local clampedSaturation = math.Round(math.Clamp(character:GetSaturation(), 0, 100))
        client:SetLocalVar("saturation", clampedSaturation)
    end
    if (character:GetSatiety()) then
        local clampedSatiety = math.Round(math.Clamp(character:GetSatiety(), 0, 100))
        client:SetLocalVar("satiety", clampedSatiety)
    end

    local uniqueID = client:AccountID()
    if timer.Exists("ixPrimaryNeeds." .. uniqueID) then timer.Remove("ixPrimaryNeeds." .. uniqueID) end
    if ( hook.Run("EnableNeedsForCharacter", client, character) == false ) then return end
    self:CreateNeedsTimer(client, character)
end

PLUGIN.hungerSounds = {
    [1] = 'npc/barnacle/barnacle_digesting1.wav',
    [2] = 'npc/barnacle/barnacle_digesting2.wav'
}

function PLUGIN:CreateNeedsTimer(client, character)
    local uniqueID = client:AccountID()
    local needsDelay = ix.config.Get("primaryNeedsDelay", 120)
    timer.Create("ixPrimaryNeeds." .. uniqueID, needsDelay, 0, function()
        if !IsValid(client) then return end
        if !character then return end
        if ( hook.Run("EnableNeedsForCharacter", client, character) == false ) then return end

        -- El hambre/sed bajan solo por tiempo: ritmo plano por intervalo,
        -- sin influencia del peso del inventario ni del movimiento.
        local saturationConsume = ix.config.Get("saturationConsume", 3)
        local satietyConsume = ix.config.Get("satietyConsume", 2)

        -- Superviviente: reduce el desgaste de hambre/sed.
        local needsMult = hook.Run("AdjustNeedsConsume", client, character) or 1

        -- Nutrido: comer algo cocinado reduce el desgaste durante un tiempo.
        if (ix.needs.IsBuffActive(client, "nutrido")) then
            needsMult = needsMult * ix.config.Get("nutridoConsumeMult", 0.5)
        end

        saturationConsume = math.Round(saturationConsume * needsMult)
        satietyConsume = math.Round(satietyConsume * needsMult)

        if (character:GetSatiety() <= 10) then
            client:EmitSound( self.hungerSounds[math.random(#self.hungerSounds)] )
        end

        if (character:GetSatiety() <= 0 and character:GetSaturation() <= 0) then
            -- SetHealth no mata al llegar a 0 (solo TakeDamage/Kill lo hacen), por eso
            -- la vida seguía bajando en negativo. Al llegar a 0 o menos, matar.
            local newHealth = client:Health() - 2

            if (newHealth <= 0) then
                client:Kill()
            else
                client:SetHealth(newHealth)
            end
        end

        character:DowngradeSaturation(saturationConsume)
        character:DowngradeSatiety(satietyConsume)
    end)
end

function PLUGIN:EnableNeedsForCharacter(client, character)
    local bStatus = false
    local factionTable = ix.faction.indices[character:GetFaction()] or {}

    if (factionTable and factionTable.includeNeeds) then
        bStatus = true
    end

    return bStatus
end

function PLUGIN:DoPlayerDeath(client, _, __)
    local char = client:GetCharacter()
    if ( IsValid(client) and char ) then
        local defaultSaturation = ix.char.vars["saturation"].default or 60
        local defaultSatiety = ix.char.vars["satiety"].default or 60
        char:SetSaturation(defaultSaturation)
        char:SetSatiety(defaultSatiety)
    end

    client:SetNetVar("nutridoEnd", 0)
    client:SetNetVar("intoxicadoEnd", 0)
    client.ixIntoxicadoActive = nil
end

function PLUGIN:PlayerDisconnected(client)
    local uniqueID = client:AccountID()
    if timer.Exists("ixPrimaryNeeds." .. uniqueID) then
        timer.Remove("ixPrimaryNeeds." .. uniqueID)
    end

    client.ixIntoxicadoActive = nil
end
