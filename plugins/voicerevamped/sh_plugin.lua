PLUGIN.name = "Voice Chat Revamped"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.desc = "A plugin that revamps voice chat: voice distance and 3D world icons."
ix.util.Include("sv_plugin.lua")

ix.command.Add("voicemode", {
    description = "Changes the range at which people can hear your voice.",
    OnRun = function(self, client)
        netstream.Start(client, "ixVoiceMenu")
    end
})

-- Voice Modes
ixVoice = ixVoice or {}

ixVoice.Ranges = {
    {
        name = "Susurrando",
        icon = "efgui/icons/hud_voice3.png",
        range = 150
    },
    {
        name = "Hablando",
        icon = "efgui/icons/hud_voice1.png",
        range = 350
    },
    {
        name = "Gritando",
        icon = "efgui/icons/hud_voice2.png",
        range = 700
    }
}

local voiceDistance = 422500

if SERVER then
    for i, v in pairs(ixVoice.Ranges) do
        resource.AddFile("materials/" .. v.icon)
    end

    function PLUGIN:PlayerCanHearPlayersVoice(listener, speaker)
        local allowVoice = ix.config.Get("allowVoice")
        if IsValid(listener.ixRagdoll) then return false, false end
        if listener == speaker then return false, false end
        if not allowVoice then return false, false end
        local oldrange = voiceDistance

        if speaker:GetNetVar("voiceRange") then
            local rangeEntry = ixVoice.Ranges[speaker:GetNetVar("voiceRange", 2)]
            if not rangeEntry then return false, false end
            oldrange = rangeEntry.range * rangeEntry.range
        end

        if listener:GetPos():DistToSqr(speaker:GetPos()) > oldrange then return false, false end

        -- segundo valor = voz espacial (3D): con esto activado el motor atenúa el
        -- volumen según la distancia dentro del radio, en vez de sonar siempre al
        -- mismo volumen y cortarse de golpe al salir del radio.
        return true, true
    end
end

if SERVER then
    netstream.Hook("ChangeMode", function(client, mode)
        if type(mode) != "number" then return end
        mode = math.Clamp(math.floor(mode), 1, #ixVoice.Ranges)
        client:SetNetVar("voiceRange", mode)
    end)
end

netstream.Hook("ixVoiceMenu", function(client)
    local menu = DermaMenu()

    menu:AddOption("Change voice mode to Whispering range.", function()
        netstream.Start("ChangeMode", 1)
        LocalPlayer():Notify("You have changed your voice mode to Whispering!")
    end)

    menu:AddOption("Change voice mode to Talking range.", function()
        netstream.Start("ChangeMode", 2)
        LocalPlayer():Notify("You have changed your voice mode to Talking!")
    end)

    menu:AddOption("Change voice mode to Yelling range.", function()
        netstream.Start("ChangeMode", 3)
        LocalPlayer():Notify("You have changed your voice mode to Yelling!")
    end)

    menu:Open()
    menu:MakePopup()
    menu:Center()
end)

if CLIENT then
    for i, v in pairs(ixVoice.Ranges) do
        ixVoice.Ranges[i].icon = Material(v.icon, "noclamp smooth")
    end

    local COLOR_VOICE_BG  = Color(15, 15, 15, 215)
    local COLOR_VOICE_FG  = Color(255, 255, 255, 220)
    local COLOR_VOICE_DIM = Color(255, 255, 255, 80)

    local VOICE_W   = 145
    local VOICE_H   = 38
    local VOICE_GAP = 8

    local lastKeyPress  = 0
    local lastModeChange = -10
    local SHOW_DURATION  = 2.5

    hook.Add("Think", "VoiceRevamped_CommaKey", function()
        if not input.IsKeyDown(KEY_COMMA) then return end
        local now = CurTime()
        if (now - lastKeyPress) < 0.4 then return end
        lastKeyPress = now

        local client = LocalPlayer()
        if not IsValid(client) or not client:GetCharacter() then return end

        local current  = client:GetNetVar("voiceRange", 2)
        local nextMode = (current % #ixVoice.Ranges) + 1
        netstream.Start("ChangeMode", nextMode)
        lastModeChange = now
    end)

    function PLUGIN:HUDPaint()
        if not ix.config.Get("allowVoice", false) then return end
        local client = LocalPlayer()
        if not IsValid(client) or not client:Alive() then return end
        if not client:GetCharacter() then return end
        local speaking = client:IsSpeaking()
        if not speaking and (CurTime() - lastModeChange) > SHOW_DURATION then return end

        local rangeIdx  = client:GetNetVar("voiceRange", 2)
        local rangeData = ixVoice.Ranges[rangeIdx]
        if not rangeData then return end

        local scrW = ScrW()
        local scrH = ScrH()

        local panX = scrW - 310 - VOICE_W - VOICE_GAP
        local panY = scrH - VOICE_H - 10

        draw.RoundedBox(4, panX, panY, VOICE_W, VOICE_H, COLOR_VOICE_BG)

        local textCol   = speaking and COLOR_VOICE_FG or COLOR_VOICE_DIM
        local iconAlpha = speaking and 220 or 80

        local iconSize = 24
        local pad      = 7

        surface.SetDrawColor(255, 255, 255, iconAlpha)
        surface.SetMaterial(rangeData.icon)
        surface.DrawTexturedRect(panX + pad, panY + (VOICE_H - iconSize) * 0.5, iconSize, iconSize)

        draw.SimpleText(rangeData.name, "efgx.Label", panX + pad + iconSize + 6, panY + VOICE_H * 0.5, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    function PLUGIN:PostDrawTranslucentRenderables()
        for _, ply in ipairs(player.GetAll()) do
            if ply == LocalPlayer() or (GetViewEntity() == LocalPlayer()) then continue end
            if not ply:Alive() then continue end
            if not ix.config.Get("allowVoice", false) then return end
            if IsValid(ix.gui.menu) then return end
            if not ply:IsSpeaking() then continue end

            local voice_mat = ixVoice.Ranges[ply:GetNetVar("voiceRange", 2)].icon
            local pos = ply:GetPos() + Vector(0, 0, ply:GetModelRadius() + 10)
            local attachment = ply:LookupBone("ValveBiped.Bip01_Head1")

            if attachment then
                pos = ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Head1")) + Vector(0, 0, 12)
            end

            local distance = LocalPlayer():GetPos():Distance(ply:GetPos())
            local plyrange = ixVoice.Ranges[ply:GetNetVar("voiceRange", 2)].range

            if distance <= plyrange then
                render.SetMaterial(voice_mat)
                local computed_color = render.ComputeLighting(ply:GetPos(), Vector(0, 0, 1))
                local max = math.max(computed_color.x, computed_color.y, computed_color.z)
                local color_var = math.Clamp(max * 255 * 1.11, 0, 255)
                render.DrawSprite(pos, 8, 8, Color(color_var, color_var, color_var, 255))
            end
        end
    end
end
