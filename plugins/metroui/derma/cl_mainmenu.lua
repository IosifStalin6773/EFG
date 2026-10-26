local PLUGIN = PLUGIN
local PANEL = {}

local textures = {
    bg = ix.util.GetMaterial('efgui/backgrounds/mainmenu.jpg', 'noclamp smooth'),
    smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'),
    mainmenu = ix.util.GetMaterial('efgui/mainmenu.png', 'noclamp smooth'),
    card = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
    logo = ix.util.GetMaterial('efgui/logo32028.png', 'noclamp smooth'),
    gradient_radial = ix.util.GetMaterial('helix/gui/radial-gradient.png', 'noclamp smooth')
}

local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
	local c = math.cos( math.rad(rot) )
	local s = math.sin( math.rad(rot) )

	local newx = y0 * s - x0 * c
	local newy = y0 * c + x0 * s

	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
end

local function hoverSounds(this)
	if this:GetDisabled() then return end
	if this:IsHovered() then
		if not this.hovered then
			this.hovered = true
			surface.PlaySound('tls/hover.wav')
		end
	else
		this.hovered = false
	end
end

local gray_clr = Color(122, 122, 122)
function PANEL:Init()
    if IsValid(ix.gui.loading) then
		ix.gui.loading:Remove()
	end
    if IsValid(ix.gui.MetroSpawnMenu) then
        ix.gui.MetroSpawnMenu:Remove()
    end
    ix.gui.MetroSpawnMenu = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    timer.Simple(1, function()
        if not isfunction(LocalPlayer) or not IsValid(LocalPlayer()) then return end
        if IsValid(PLUGIN.ambientMusic) and PLUGIN.ambientMusic:GetState() == GMOD_CHANNEL_PLAYING then return end
        -- Si el personaje ya cargó antes de que el timer dispare, no arrancar música
        if isfunction(LocalPlayer().GetCharacter) and LocalPlayer():GetCharacter() then return end

        sound.PlayFile("sound/" .. PLUGIN.menuMusic, "noblock", function(station)
            if not IsValid(station) then return end
            -- Guard de condición de carrera: sound.PlayFile es async; el personaje
            -- pudo haber cargado entre el timer y este callback
            if IsValid(LocalPlayer()) and isfunction(LocalPlayer().GetCharacter) and LocalPlayer():GetCharacter() then
                station:Stop()
                return
            end
            PLUGIN.ambientMusic = station
            station:EnableLooping(true)
            station:SetVolume(0)
            station:Play()
            local steps = 20
            timer.Create("MetroUI_MusicFadeIn", 0.05, steps, function()
                if not IsValid(station) then return end
                station:SetVolume(math.min(station:GetVolume() + (3 / steps), 3))
            end)
        end)
    end)

    self.postscriptum = self:Add('DLabel')
    self.postscriptum:SetSize( SScale(220), SScale(50) )
    self.postscriptum:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(220)*.06, ScrH() - SScale(55))
    self.postscriptum:SetText(PLUGIN.PostScriptum:upper())
    self.postscriptum:SetFont(PLUGIN:GetFontInternal('PostScriptum'))
    self.postscriptum:SetTextColor(gray_clr)
    self.postscriptum:SetContentAlignment(5)
    self.postscriptum:SetSelectable(false)
    self.postscriptum:SetMouseInputEnabled(false)

    self.disconnect = self:Add('DButton')
    self.disconnect:SetSize( SScale(75), SScale(20) )
    self.disconnect:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(190)*.435, ScrH() - SScale(83))
    self.disconnect:SetText(('Desconectarse'):upper())
    self.disconnect:SetFont(PLUGIN:GetFontInternal('Button'))
    self.disconnect.Paint = hoverSounds
    self.disconnect.Think = function(me)
        if me:IsHovered() then
            me:SetTextColor(Color(154, 136, 102))
        else
            me:SetTextColor(color_white)
        end
    end
    self.disconnect.DoClick = function()
        surface.PlaySound('tls/click.wav')
        vgui.Create('metroModal'):Setup('¿ESTÁS SEGURO?', 'No olvides terminar el RP antes de salir.', nil, function()
            RunConsoleCommand('disconnect')
        end)
    end

    if isfunction(LocalPlayer().GetCharacter) && LocalPlayer():GetCharacter() then
        self.disconnect:SetText(('Volver'):upper())
        self.disconnect.DoClick = function()
            PLUGIN:FadeOutMusic(1)

            surface.PlaySound('tls/click.wav')
            self:AlphaTo(0, .3, 0, function()
                self:Remove()
            end)
        end
    end

    self.buttons = self:Add('DScrollPanel')
    self.buttons:SetSize( SScale(210), SScale(25) * 6.5 )
    self.buttons:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(210)*.077, SScale(97))

    for _, v in SortedPairsByMemberValue(PLUGIN.MainMenuButtons, 'weight', false) do
        if isfunction(v.filter) && v.filter() == false then continue end
        local btn = self.buttons:Add('DButton')
        btn:SetText(v.name:upper())
        btn:Dock(TOP)
        btn:DockMargin(5, 5, 5, 5)
        btn:DockPadding(5, 5, 5, 5)
        btn:SetTall(SScale(25))
        btn:SetFont(PLUGIN:GetFontInternal('Button2'))
        btn:SetContentAlignment(4)
        btn.Paint = hoverSounds
        btn.Think = function(me)
            if me:IsHovered() then
                me:SetTextColor(Color(154, 136, 102))
            else
                me:SetTextColor(color_white)
            end
        end
        btn.DoClick = function()
            surface.PlaySound('tls/click.wav')

            if isfunction(v.callback) then
                v.callback(self)
            end
        end
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(0, 0, 0)
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(textures.bg)
    surface.DrawTexturedRect(0, 0, w, h)

    --- @field dynamic smoke
    surface.SetDrawColor(73 + 111, 68 + 111, 65 + 111, 200)
    surface.SetMaterial(textures.smoke1)
    DrawTexturedRectRotatedPoint(
        -- ScrW() - SScale(440) / 2.6,
        -- ScrH() + SScale(440) / 4,
        -- SScale(440),
        -- SScale(440),
        -- (CurTime() % 360) * 3,
        -- SScale(440) / 16,
        -- SScale(440) / 16
        -(SScale(900) / 32 / 2),
        ScrH() + SScale(900) / 4,
        SScale(900),
        SScale(900),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )

    --- @field mainmenu background
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(textures.mainmenu)
    surface.DrawTexturedRect(ScrW() - SScale(680/2.8) * 1.2, 0, SScale(680/2.8), SScale(1024/2.8))

    --- @field background darkness
    surface.SetDrawColor(0, 0, 0, 11)
    surface.DrawRect(ScrW() - SScale(680/2.8) * 1.2, 0, SScale(680/2.8) - SScale(2), SScale(1024/2.8))

    --- @field title & logo background radial gradient
    surface.SetDrawColor(99, 99, 99, 22)
    surface.SetMaterial(textures.gradient_radial)
    surface.DrawTexturedRect((ScrW() - SScale(680/2.8) * 1.2) - SScale(29), -SScale(700/2)/2, SScale(600/2), SScale(650/2))

    --- @field title background
    surface.SetDrawColor(154, 136, 102, 255)
    surface.SetMaterial(textures.card)
    surface.DrawTexturedRect(ScrW() - SScale(886/3.3 * 1.176), SScale(85/1.43), SScale(886/3.337), SScale(85/3.5))

    --- @field title text
    draw.Text({
        text = PLUGIN.TitleText:upper(),
        font = PLUGIN:GetFontInternal('Title'),
        pos = {(ScrW() - SScale(680/2.8) * 1.25) + SScale(132), SScale(71)},
        xalign = TEXT_ALIGN_CENTER,
        yalign = TEXT_ALIGN_CENTER,
        color = color_white
    })

    --- @field logo
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(textures.logo)
    surface.DrawTexturedRect((ScrW() - SScale(680/2.8) * 1.25) + SScale(680/2.8) / 3, SScale(10), SScale(463/4.5), SScale(173/4.5))
end

vgui.Register('ixCharMenu', PANEL, 'EditablePanel')