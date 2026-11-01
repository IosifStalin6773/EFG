local PANEL = {}
local PLUGIN = PLUGIN

local textures = {
    smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'),
    card = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
    menu = ix.util.GetMaterial('efgui/creation/ui_pausemenu_back_002.png', 'noclamp smooth'),
    gradient = ix.util.GetMaterial('helix/gui/radial-gradient.png', 'noclamp smooth'),
    bottom_concern = ix.util.GetMaterial('efgui/spawnmenu/ui_astra_ex1.jpg', 'noclamp smooth'),

    --- @field spawnmenu
    spawnmenu = ix.util.GetMaterial('efgui/spawnmenu/ui_spawn.jpg', 'noclamp smooth'),
    redline = ix.util.GetMaterial('efgui/spawnmenu/RedLine/RedLine.jpg', 'noclamp smooth'),
    rangers = ix.util.GetMaterial('efgui/spawnmenu/Rangers/Ranger.jpg', 'noclamp smooth'),
    hanza = ix.util.GetMaterial('efgui/spawnmenu/Hanza/Hanza.jpg', 'noclamp smooth'),
    reich = ix.util.GetMaterial('efgui/spawnmenu/4Reich/4Reich.jpg', 'noclamp smooth')
}

local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
	local c = math.cos( math.rad(rot) )
	local s = math.sin( math.rad(rot) )

	local newx = y0 * s - x0 * c
	local newy = y0 * c + x0 * s

	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
end

function PANEL:Init()
    if IsValid(ix.gui.efgStationChoose) then
        ix.gui.efgStationChoose:Remove()
    end
    ix.gui.efgStationChoose = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    self.payload = {}
    self.faction_image = ix.util.GetMaterial('efgui/spawnmenu/void.jpg', 'noclamp smooth')
    self.faction_smoke_clr = Color(73 + 111, 68 + 111, 65 + 111, 200)
    self.spawn_desc = 'Elige tu punto de inicio.'
    self.spawn_name = ''

    self.desc = self:Add('DLabel')
    self.desc:SetSize(SScale(200), SScale(50))
    self.desc:SetPos(SScale(10), SScale(45))
    self.desc:SetFont(PLUGIN:GetFontInternal('CharFieldsInk'))
    self.desc:SetWrap(true)
    self.desc:SetContentAlignment(7)
    self.desc:SetText(self.spawn_desc)

    self.left = self:Add('DButton')
    self.left:SetSize(SScale(50), SScale(12))
    self.left:SetPos(5, ScrH() - SScale(12) - 5)
    self.left:SetText('< ATRÁS')
    self.left:SetFont(PLUGIN:GetFontInternal('Button'))
    self.left:SetTextColor(color_white)
    self.left.Paint = function(_, w, h)
        surface.SetDrawColor(color_black)
        surface.DrawRect(0, 0, w, h)
    end
    self.left:SetExpensiveShadow(1, color_black)
    self.left.DoClick = function()
        surface.PlaySound('efg/ui/click.wav')
        local _pnl = vgui.Create('efgCharacterCreation')
        _pnl:SetPayload(self.payload)
        self:DoModal()
        self:AlphaTo(0, .3, 0, function()
            self:Remove()
        end)
    end

    for index, spawn in ipairs(PLUGIN.spawns) do
        local btn = self:Add('DButton')
        btn:SetSize(SScale(156/5), SScale(156/5))
        btn:SetPos(unpack(spawn.screen_pos))
        btn:SetText('')
        btn.alpha = 0
        btn.Paint = function(me, w, h)
            if me:GetDisabled() then return end

            if me:IsHovered() then
                if not me.hovered then
                    me.hovered = true
                    surface.PlaySound('efg/ui/hover.wav')
                    self.faction_image = spawn.img
                    self.spawn_name = spawn.name
                    self.desc:SetText(spawn.desc)
                end
                me.alpha = Lerp(math.ease.InOutCirc(0.2), me.alpha, 255)
                self.faction_smoke_clr = LerpColor(math.ease.InOutCirc(0.2), self.faction_smoke_clr, spawn.color)
            else
                me.alpha = Lerp(math.ease.InOutCirc(0.2), me.alpha, 0)
                me.hovered = false
            end

            local gradColor = spawn.disabled and Color(100, 100, 100, me.alpha) or Color(245, 96, 66, me.alpha)
            surface.SetDrawColor(gradColor)
            surface.SetMaterial(textures.gradient)
            surface.DrawTexturedRect(0, 0, w, h)

            local iconColor = spawn.disabled and Color(160, 160, 160, 180) or color_white
            surface.SetDrawColor(iconColor)
            surface.SetMaterial(spawn.icon)
            surface.DrawTexturedRect((w - (w/1.3))/2, (h - (h/1.3))/2, w / 1.3, h / 1.3)

            if spawn.disabled then
                surface.SetDrawColor(0, 0, 0, 140)
                surface.DrawRect(0, 0, w, h)
                draw.Text({
                    text = "X",
                    font = PLUGIN:GetFontInternal('Button'),
                    pos = {w / 2, h / 2},
                    xalign = TEXT_ALIGN_CENTER,
                    yalign = TEXT_ALIGN_CENTER,
                    color = Color(200, 60, 60, 220)
                })
            end
        end
        btn.DoClick = function()
            surface.PlaySound('efg/ui/click.wav')
            if spawn.disabled then
                self.desc:SetText(spawn.desc)
                return
            end
            self.payload.spawnPoint = index
            vgui.Create('efgModal'):Setup('PUNTO DE INICIO', ('¿Seguro que quieres elegir el punto %s?'):format(spawn.name), nil, function()
                local _pnl = vgui.Create('efgCharCreationDim')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    net.Start('ixCharacterCreate')
                        net.WriteUInt(table.Count(self.payload), 8)
                        for k, v in pairs(self.payload) do
                            net.WriteString(k)
                            net.WriteType(v)
                        end
                    net.SendToServer()
                    self:Remove()
                end)
            end)
        end
    end
end

function PANEL:SetPayload(payload)
    self.payload = payload
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(color_black)
    surface.DrawRect(0, 0, w, h)

    --- @field faction image
    if self.faction_image then
        surface.SetDrawColor(color_white)
        surface.SetMaterial(self.faction_image)
        surface.DrawTexturedRect(ScrW() - SScale(1068/3), 0, SScale(1068/3), SScale(1079/3))
    end

    surface.SetDrawColor(color_white)
    surface.SetMaterial(textures.spawnmenu)
    surface.DrawTexturedRect(0, 0, w, h)

    -- surface.SetDrawColor(255, 255, 255, 66)
    -- surface.SetMaterial(textures.bottom_concern)
    -- surface.DrawTexturedRect(0, 0, w, h)

    --- @field dynamic smoke
    surface.SetDrawColor(ColorAlpha(self.faction_smoke_clr, 100))
    surface.SetMaterial(textures.smoke1)
    DrawTexturedRectRotatedPoint(
        ScrW() - SScale(170),
        ScrH() + SScale(750/2) / 4,
        SScale(900/2),
        SScale(900/2),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )

    --- @field title text
    draw.Text({
        text = self.spawn_name,
        font = PLUGIN:GetFontInternal('Title'),
        pos = {SScale(100), SScale(14)},
        xalign = TEXT_ALIGN_CENTER,
        yalign = TEXT_ALIGN_TOP,
        color = color_white
    })

    -- --- @field desc text
    -- draw.Text({
    --     text = self.spawn_desc,
    --     font = PLUGIN:GetFontInternal('CharFieldsInk'),
    --     pos = {SScale(10), SScale(45)},
    --     xalign = TEXT_ALIGN_LEFT,
    --     yalign = TEXT_ALIGN_TOP,
    --     color = color_white
    -- })
end

vgui.Register('efgStationChoose', PANEL, 'EditablePanel')