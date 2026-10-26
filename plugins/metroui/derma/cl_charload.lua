local PANEL = {}
local PLUGIN = PLUGIN

local textures = {
    bg = ix.util.GetMaterial('efgui/backgrounds/load.jpg', 'noclamp smooth'),
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

local t_color = Color(96-10, 68-10, 48-10)
local gray_clr = Color(122, 122, 122)
function PANEL:Init()
    if IsValid(ix.gui.metroCharLoad) then
        ix.gui.metroCharLoad:Remove()
    end
    ix.gui.metroCharLoad = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    self.postscriptum = self:Add('DLabel')
    self.postscriptum:SetSize( SScale(220), SScale(50) )
    self.postscriptum:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(220)*.06, ScrH() - SScale(55))
    self.postscriptum:SetText(PLUGIN.PostScriptum:upper())
    self.postscriptum:SetFont(PLUGIN:GetFontInternal('PostScriptum'))
    self.postscriptum:SetTextColor(gray_clr)
    self.postscriptum:SetContentAlignment(5)
    self.postscriptum:SetSelectable(false)
    self.postscriptum:SetMouseInputEnabled(false)
    
    self.back = self:Add('DButton')
    self.back:SetSize( SScale(75), SScale(20) )
    self.back:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(190)*.435, ScrH() - SScale(83))
    self.back:SetText(('Volver'):upper())
    self.back:SetFont(PLUGIN:GetFontInternal('Button'))
    self.back.Paint = hoverSounds
    self.back.Think = function(me)
        if me:IsHovered() then
            me:SetTextColor(Color(154, 136, 102))
        else
            me:SetTextColor(color_white)
        end
    end
    self.back.DoClick = function()
        surface.PlaySound('tls/click.wav')
        self.model_view:Remove()
        local _pnl = vgui.Create('ixCharMenu')
        self:DoModal()
        self:AlphaTo(0, .3, 0, function()
            self:Remove()
        end)
    end

    self.model_box = self:Add('EditablePanel')
    self.model_box:SetSize(SScale(300), ScrH())
    self.model_box:SetPos(50, 0)
    self.model_box.Paint = nil

    self.model_view = self.model_box:Add('ixModelPanel')
    self.model_view:Dock(FILL)
	-- self.model_view:SetModel('models/error.mdl')
	self.model_view:SetFOV(55)
	self.model_view.PaintModel = self.model_view.Paint

	function self.model_view:LayoutEntity()
		local entity = self.Entity
		if (not IsValid(entity)) then return end
		if (not self._idleSet) then
			local seq = entity:LookupSequence("idle_all_01")
			if (seq <= 0) then seq = entity:LookupSequence("idle_unarmed") end
			if (seq <= 0) then seq = entity:SelectWeightedSequence(ACT_IDLE) end
			if (seq > 0) then
				entity:ResetSequence(seq)
				self._idleSet = true
			else
				for _, v in ipairs(entity:GetSequenceList()) do
					if (v:lower():find("idle") and v != "idlenoise") then
						entity:ResetSequence(v)
						self._idleSet = true
						break
					end
				end
			end
		end
		entity:SetIK(false)
		self:RunAnimation()
	end

    self.buttons = self:Add('DScrollPanel')
    self.buttons:SetSize( SScale(210), SScale(25) * 6.5 )
    self.buttons:SetPos((ScrW() - SScale(680/2.8) * 1.2) + SScale(210)*.077, SScale(97))

    for _, charId in ipairs(ix.characters) do
        local char = ix.char.loaded[charId]
        if not char then continue end
        local btn = self.buttons:Add('DButton')
        btn:SetText(char:GetName())
        btn:Dock(TOP)
        btn:DockMargin(5, 5, 5, 5)
        btn:DockPadding(5, 5, 5, 5)
        btn:SetTall(SScale(25))
        btn:SetFont(PLUGIN:GetFontInternal('Button2'))
        btn:SetContentAlignment(4)
        btn.Paint = function(me)
        	if me:GetDisabled() then return end
            if me.b_loading then return end
            if me:IsHovered() then
                if not me.hovered then
                    me.hovered = true
                    surface.PlaySound('tls/hover.wav')

                    if IsValid(self.model_view) then
                        self.model_view:SetModel( char:GetModel() )
                        self.model_view._idleSet = false
                        self.model_view:SetDirectionalLight(BOX_TOP, Color(0, 0, 0))
                        self.model_view:SetDirectionalLight(BOX_FRONT, Color(0, 0, 0))
                        do
                            local lkBone = self.model_view.Entity:LookupBone('ValveBiped.Bip01_Head1')
                            if lkBone then
                                self.mdl_eyepos = self.model_view.Entity:GetBonePosition(lkBone)
                                    self.mdl_eyepos:Add(Vector(0, 0, 2))
                                    self.model_view:SetLookAt(self.mdl_eyepos)
                                    self.model_view:SetCamPos(self.mdl_eyepos-Vector(-27, -8, 4))
                                self.model_view.Entity:SetEyeTarget(self.mdl_eyepos-Vector(-27, -8, 4))
                            end
                        end
                        do
                            local skin = char:GetChosenSkin()
                            if skin then
                                self.model_view.Entity:SetSkin(skin)
                            end

                            local bodygroups = pon.decode(char:GetChosenBodygroups())
                            if istable(bodygroups) then
                                for bId, bValue in pairs(bodygroups) do
                                    self.model_view.Entity:SetBodygroup(bId, bValue)
                                end
                            end
                        end
                    end
                end
            else
                me.hovered = false
            end
        end
        btn.Think = function(me)
            if me.b_loading then return end
            if me:IsHovered() then
                me:SetTextColor(Color(154, 136, 102))
            else
                me:SetTextColor(color_white)
            end
        end
        btn.DoClick = function()
            surface.PlaySound('tls/click.wav')
            vgui.Create('metroModal'):Setup('SELECCIONAR PERSONAJE', ('¿Cargar a %s?'):format(char:GetName()), nil, function()
                self.b_loading = true
                local _pnl = vgui.Create('metroCharCreationDim')
                _pnl.text = 'Cargando personaje...'
                self.model_box:Remove()
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
        
                    net.Start('ixCharacterChoose')
                        net.WriteUInt(char:GetID(), 32)
                    net.SendToServer()

                    timer.Remove('ixCharacterCreateTimeout')
                    timer.Create('ixCharacterLoaded', 1, 1, function()
                        if not IsValid(_pnl) then return end
                        _pnl:AlphaTo(0, .3, 0, function()
                            _pnl:Remove()
                        end)
                    end)
                end)
            end)
        end
        btn.DoRightClick = function()
            surface.PlaySound('tls/click.wav')
            vgui.Create('metroModal'):Setup('ELIMINAR PERSONAJE', ('¿Eliminar a %s?'):format(char:GetName()), nil, function()
                local _pnl = vgui.Create('metroCharCreationDim')
                _pnl.text = 'Eliminando personaje...'
                self.model_box:Remove()
                self:DoModal()
                self:AlphaTo(0, .3, 0, function()
                    self:Remove()
        
                    net.Start('ixCharacterDelete')
                        net.WriteUInt(char:GetID(), 32)
                    net.SendToServer()

                    timer.Remove('ixCharacterCreateTimeout')
                    timer.Create('ixCharacterLoaded', 1, 1, function()
                        if not IsValid(_pnl) then return end
                        local __pnl = vgui.Create('metroCharLoad')
                        _pnl:DoModal()
                        _pnl:AlphaTo(0, .3, 0, function()
                            _pnl:Remove()
                        end)
                    end)
                end)
            end)
        end
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(0, 0, 0)
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(textures.bg)
    surface.DrawTexturedRect(0, 0, w, h)

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
        text = ('Selector de PJ'):upper(),
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

function PANEL:PaintOver(w, h)
    --- @field dynamic smoke
    surface.SetDrawColor(73 + 111, 68 + 111, 65 + 111, 200)
    surface.SetMaterial(textures.smoke1)
    DrawTexturedRectRotatedPoint(
        -(SScale(900) / 32 / 2),
        ScrH() + SScale(900) / 4,
        SScale(900),
        SScale(900),
        (CurTime() % 360) * 5,
        SScale(800) / 32,
        SScale(800) / 32
    )
end

vgui.Register('metroCharLoad', PANEL, 'EditablePanel')