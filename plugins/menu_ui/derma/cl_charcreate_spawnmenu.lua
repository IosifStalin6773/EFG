local PLUGIN = PLUGIN
local PANEL = {}

local textures = {
    bg = ix.util.GetMaterial('efgui/backgrounds/creation.jpg', 'noclamp smooth'),
    smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'),
    card = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
    menu = ix.util.GetMaterial('efgui/creation/ui_pausemenu_back_002.png', 'noclamp smooth')
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
			surface.PlaySound('efg/ui/hover.wav')
		end
	else
		this.hovered = false
	end
end

function PANEL:Init()
    if IsValid(ix.gui.EFGCharacterCreation) then
        ix.gui.EFGCharacterCreation:Remove()
    end
    ix.gui.EFGCharacterCreation = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    self.menu = self:Add('EditablePanel')
    self.menu:SetSize( ScrH(), ScrH() )
    self.menu:SetPos(0, 0)
    self.menu.Paint = function(_, w, h)
        surface.SetDrawColor(color_white)
        surface.SetMaterial(textures.menu)
        surface.DrawTexturedRect(0, 0, w, h)
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
        ScrW(),
        ScrH() + SScale(900) / 4,
        SScale(900),
        SScale(900),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )
end

vgui.Register('efgCharacterCreationSpawnmenu', PANEL, 'EditablePanel')