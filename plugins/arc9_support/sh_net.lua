
local PLUGIN = PLUGIN

if SERVER then
    util.AddNetworkString("ixARC9UpdatePreset")
    util.AddNetworkString("ixARC9SendPreset")

    net.Receive("ixARC9UpdatePreset", function(length, client)
        local id = net.ReadUInt(32)
        local character = client:GetCharacter()

        if (character and character:GetID() == id) then
            local weapon = ents.GetByIndex(net.ReadUInt(32))
            local preset = net.ReadString()

            -- solo el arma del propio jugador, y el preset limpio (CleanPreset)
            if IsValid(weapon) and weapon:GetOwner() == client and weapon.ixItem then
                if weapon.ixItem.SetPreset then
                    weapon.ixItem:SetPreset(preset)
                else
                    weapon.ixItem:SetData("preset", ix.arc9.CleanPreset(preset))
                end
            end
        end
    end)
else
    -- custom implementation of arc9_sendpreset in case it ever changes in an update
    net.Receive("ixARC9SendPreset", function(len)
        local weapon = net.ReadEntity()
        local preset = net.ReadString()
        
        if IsValid(weapon) and weapon.ARC9 then
            weapon:LoadPresetFromTable(weapon:ImportPresetCode(preset), true)
        end
    end)
end