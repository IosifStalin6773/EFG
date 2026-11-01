local PANEL = {}

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
    if IsValid(ix.gui.efg_modal) then
        ix.gui.efg_modal:Remove()
    end
    ix.gui.efg_modal = self

    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:DoModal()

    self:SetAlpha(0)
    self:AlphaTo(255, .3)

    self.box = self:Add('EditablePanel')
    self.box:SetSize(SScaleMin(544/3), SScaleMin(214/3))
    self.box:SetPos((ScrW() * .5) - SScaleMin(544/3)/2, (ScrH() * .5) - SScaleMin(214/3)/2)
    self.box.Paint = function(_, w, h)
        surface.SetDrawColor(10, 10, 10, 255 * 0.75)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(255, 255, 255, 255 * 0.2)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.Text({
            text = self.title,
            font = 'tls.Modal.Title',
            pos = {SScaleMin(32/3), SScaleMin(32/3)},
            color = color_white
        })

        draw.Text({
            text = self.text,
            font = 'tls.Modal.Desc',
            pos = {SScaleMin(32/3), SScaleMin(82/3)},
            color = color_white
        })

        surface.SetDrawColor(255, 255, 255, 255 * 0.2)
        surface.SetMaterial(ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'))
        surface.DrawTexturedRect(w - (w/2) - 1, 1, w / 2, SScale(5))
    end

    self.cancel = self.box:Add('DButton')
    self.cancel:SetSize(SScaleMin(96/3), SScaleMin(46/3))
    self.cancel:SetPos(SScaleMin(340/3), SScaleMin(136/3))
    self.cancel:SetText('')
    self.cancel.DoClick = function()
        if self.cancelCallback then
            self.cancelCallback()
        end
        self:Remove()
        surface.PlaySound('efg/ui/click.wav')
    end
	self.cancel.color_rect = 0
	self.cancel.color_outline = 0
	self.cancel.text_color = 255 * 0.5
	self.cancel.Paint = function(me, w, h)
        hoverSounds(me)

		if me:IsHovered() then
			me.color_rect = Lerp(math.ease.InOutCirc(0.2), me.color_rect, 66)
			me.color_outline = Lerp(math.ease.InOutCirc(0.2), me.color_outline, 255 * 0.5)
			me.text_color = Lerp(math.ease.InOutCirc(0.2), me.text_color, 255)
		else
			me.color_rect = Lerp(math.ease.InOutCirc(0.2), me.color_rect, 0)
			me.color_outline = Lerp(math.ease.InOutCirc(0.2), me.color_outline, 255 * 0)
			me.text_color = Lerp(math.ease.InOutCirc(0.2), me.text_color, 255 * 0.5)
		end

		surface.SetFont('tls.Modal.Desc')
		surface.SetTextColor(255, 255, 255, me.text_color)
		surface.SetTextPos(SScaleMin(18/3), SScaleMin(12/3))
		surface.DrawText('Cancelar')

		surface.SetDrawColor(66, 66, 66, me.color_rect)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(255, 255, 255, me.color_outline)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

    self.ok = self.box:Add('DButton')
    self.ok:SetSize(SScaleMin(68/3), SScaleMin(46/3))
    self.ok:SetPos(SScaleMin(444/3), SScaleMin(136/3))
    self.ok:SetText('')
    self.ok.DoClick = function()
        if self.okCallback then
            self.okCallback()
        end
        self:Remove()
        surface.PlaySound('efg/ui/click.wav')
    end
    self.ok.color_rect = 66
	self.ok.color_outline = 255 * 0.2
	self.ok.text_color = 255
    self.ok.transition = Color(255, 255, 255)
	self.ok.Paint = function(me, w, h)
        hoverSounds(me)

        if me:IsHovered() then
            me.transition = LerpColor(math.ease.InOutCirc(0.2), me.transition, Color(219, 57, 61))
			me.color_outline = Lerp(math.ease.InOutCirc(0.2), me.color_outline, 255 * 0.5)
        else
            me.transition = LerpColor(math.ease.InOutCirc(0.2), me.transition, Color(255, 255, 255))
			me.color_outline = Lerp(math.ease.InOutCirc(0.2), me.color_outline, 255 * 0.2)
        end

		surface.SetFont('tls.Modal.Desc')
		surface.SetTextColor( ColorAlpha(me.transition, me.text_color) )
		surface.SetTextPos(SScaleMin(22/3), SScaleMin(12/3))
		surface.DrawText('Ok')

		surface.SetDrawColor(11, 11, 11, me.color_rect)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor( ColorAlpha(me.transition, me.color_outline) )
		surface.DrawOutlinedRect(0, 0, w, h, 1)

        surface.SetDrawColor( ColorAlpha(me.transition, me.color_outline) )
        surface.DrawRect(1, 1, 5, h - 2)

        surface.SetDrawColor( ColorAlpha(me.transition, me.color_outline) )
        surface.DrawRect(w - 6, 1, 5, h - 2)
	end
end

function PANEL:Setup(title, text, cancelCallback, okCallback)
    self.title = title || ''
    self.text = text || ''
    self.cancelCallback = cancelCallback
    self.okCallback = okCallback
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(0, 0, 0, 255 * 0.75)
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(255, 0, 0, 200)
    surface.SetMaterial(ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'))
    DrawTexturedRectRotatedPoint(
        -(SScale(900) / 32 / 2),
        ScrH() + SScale(900) / 4,
        SScale(900),
        SScale(900),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )

    ix.util.DrawBlur(self, 5)
end

DEFINE_BASECLASS('EditablePanel')

function PANEL:Remove()
    self:AlphaTo(0, .3, 0, function()
        BaseClass.Remove(self)
    end)
end

vgui.Register('efgModal', PANEL, 'EditablePanel')