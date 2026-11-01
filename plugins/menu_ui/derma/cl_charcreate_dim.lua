local PLUGIN = PLUGIN
local PANEL = {}
local textures = {
    bg = ix.util.GetMaterial('efgui/backgrounds/creation.jpg', 'noclamp smooth'),
    smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'),
}

local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
	local c = math.cos( math.rad(rot) )
	local s = math.sin( math.rad(rot) )

	local newx = y0 * s - x0 * c
	local newy = y0 * c + x0 * s

	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
end

function PANEL:Init()
    if IsValid(ix.gui.efgCharCreationDim) then
        ix.gui.efgCharCreationDim:Remove()
    end
    ix.gui.efgCharCreationDim = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    self.menu = self:Add('EditablePanel')
    self.menu:SetSize( ScrW(), ScrH() )
    self.menu:SetPos(0, 0)
    self.menu.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0)
        surface.DrawRect(0, 0, w, h)
    end
    self.menu:SetAlpha(0)
    self.menu:AlphaTo(166, .3, 0)

    self.text = 'Creando personaje...'
    self.over_menu = self.menu:Add('EditablePanel')
    self.over_menu:Dock(FILL)
    self.over_menu.Paint = function(_, w, h)
        draw.Text({
            text = self.text,
            font = PLUGIN:GetFontInternal('Title'),
            pos = {w/2, h/2},
            xalign = TEXT_ALIGN_CENTER,
            yalign = TEXT_ALIGN_CENTER,
            color = color_white
        })
    end

	timer.Create('ixCharacterCreateTimeout', 10, 1, function()
		if IsValid(self) then
			self.text = '¡Ha ocurrido un error!'
            surface.PlaySound('tls/warn.wav')
            timer.Simple(2, function()
                if not IsValid(self) then return end
                local _pnl = vgui.Create('ixCharMenu')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
                end)
            end)
		end
	end)

	net.Receive('ixCharacterAuthed', function()
		timer.Remove('ixCharacterCreateTimeout')
		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}

		for _ = 1, indices do
			charList[#charList + 1] = net.ReadUInt(32)
		end

		ix.characters = charList

        if not IsValid(self) then return end

		if LocalPlayer():GetCharacter() then
            self.text = L('charCreated')
            surface.PlaySound('tls/warn.wav')

            timer.Simple(2, function()
                if not IsValid(self) then return end
                local _pnl = vgui.Create('ixCharMenu')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
                end)
            end)
		elseif id then
            self.text = L('charCreated')
            surface.PlaySound('tls/warn.wav')

            timer.Simple(2, function()
                if not IsValid(self) then return end
                local _pnl = vgui.Create('ixCharMenu')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
                end)
            end)
		else
            timer.Simple(2, function()
                if not IsValid(self) then return end
                local _pnl = vgui.Create('ixCharMenu')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
                end)
            end)
		end
	end)

	net.Receive('ixCharacterAuthFailed', function()
		timer.Remove('ixCharacterCreateTimeout')

		local fault = net.ReadString()
		local args = net.ReadTable()

        self.text = L(fault, unpack(args))
        surface.PlaySound('tls/warn.wav')
        timer.Simple(2, function()
            if not IsValid(self) then return end
            local _pnl = vgui.Create('ixCharMenu')
            self:DoModal()
            self:AlphaTo(0, .3, 0, function()
                self:Remove()
            end)
        end)
	end)

    net.Receive('ixCharacterLoadFailure', function()
        local message = net.ReadString()

        if isstring(message) and message:sub(1, 1) == '@' then
            message = L(message:sub(2))
        end

        message = message ~= '' and message or L('unknownError')

        if IsValid(self) then
            self.text = message
            surface.PlaySound('tls/warn.wav')
            timer.Simple(2, function()
                if not IsValid(self) then return end
                local _pnl = vgui.Create('ixCharMenu')
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
                end)
            end)
        end
    end)
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
        ScrW(),
        ScrH() + SScale(900) / 4,
        SScale(900),
        SScale(900),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )
end

vgui.Register('efgCharCreationDim', PANEL, 'EditablePanel')