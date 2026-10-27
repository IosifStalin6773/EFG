-- local PLUGIN = PLUGIN
-- local PANEL = {}
-- DEFINE_BASECLASS('EditablePanel')
-- local textures = {
--     mainmenu = ix.util.GetMaterial('efgui/mainmenu.png', 'noclamp smooth'),
--     gradient_radial = ix.util.GetMaterial('helix/gui/radial-gradient.png', 'noclamp smooth'),
--     card = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
--     logo = ix.util.GetMaterial('efgui/logo3.png', 'noclamp smooth'),
--     smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth')
-- }

-- local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
-- 	local c = math.cos( math.rad(rot) )
-- 	local s = math.sin( math.rad(rot) )

-- 	local newx = y0 * s - x0 * c
-- 	local newy = y0 * c + x0 * s

-- 	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
-- end

-- local function hoverSounds(this)
-- 	if this:GetDisabled() then return end
-- 	if this:IsHovered() then
-- 		if not this.hovered then
-- 			this.hovered = true
-- 			surface.PlaySound('efg/ui/hover.wav')
-- 		end
-- 	else
-- 		this.hovered = false
-- 	end
-- end

-- local gray_clr = Color(122, 122, 122)
-- local t_color = Color(96-10, 68-10, 48-10)
-- function PANEL:Init()
--     if IsValid(ix.gui.metroNewMenu) then
--         ix.gui.metroNewMenu:Remove()
--     end

--     ix.gui.metroNewMenu = self
--     self:SetSize(ScrW(), ScrH())
--     self:SetPos(0, 0)
--     self:MakePopup()

--     self:SetAlpha(0)
--     self:AlphaTo(255, .3)

--     self.characters = self:Add('DButton')
--     self.characters:SetSize( SScale(75), SScale(20) )
--     self.characters:SetPos(SScale(30) + SScale(190)*.435, ScrH() - SScale(83))
--     self.characters:SetText(('Main Menu'):upper())
--     self.characters:SetFont(PLUGIN:GetFontInternal('Button'))
--     self.characters.Paint = hoverSounds
--     self.characters.Think = function(me)
--         if me:IsHovered() then
--             me:SetTextColor(Color(154, 136, 102))
--         else
--             me:SetTextColor(color_white)
--         end
--     end
--     self.characters.DoClick = function()
--         surface.PlaySound('efg/ui/click.wav')
--         self:Remove()
--         vgui.Create('ixCharMenu')
--     end

--     self.postscriptum = self:Add('DLabel')
--     self.postscriptum:SetSize( SScale(220), SScale(50) )
--     self.postscriptum:SetPos(SScale(30) + SScale(220)*.06, ScrH() - SScale(55))
--     self.postscriptum:SetText(PLUGIN.PostScriptum:upper())
--     self.postscriptum:SetFont(PLUGIN:GetFontInternal('PostScriptum'))
--     self.postscriptum:SetTextColor(gray_clr)
--     self.postscriptum:SetContentAlignment(5)
--     self.postscriptum:SetSelectable(false)
--     self.postscriptum:SetMouseInputEnabled(false)

--     self.inventory = self:Add('DScrollPanel')
--     self.inventory:SetSize(SScale(680/2.8) - SScale(10), SScale(183))
--     self.inventory:SetPos(SScale(30) + SScale(5), SScale(87))
--     self.inventory.Paint = function(_, w, h)
--         surface.SetDrawColor(t_color)
--         surface.SetMaterial(ix.util.GetMaterial('gui/gradient'))
--         surface.DrawTexturedRect(0, 0, w, h)
--     end

--     do
--         local canvas = self.inventory:Add('DTileLayout')
--         local canvasLayout = canvas.PerformLayout
--         canvas.PerformLayout = nil
--         canvas:SetBorder(0)
--         canvas:SetSpaceX(2)
--         canvas:SetSpaceY(2)
--         canvas:Dock(FILL)

--         ix.gui.menuInventoryContainer = canvas

--         local panel = canvas:Add('ixInventory')
--         panel:SetPos(0, 0)
--         panel:SetDraggable(false)
--         panel:SetSizable(false)
--         panel:SetTitle(nil)
--         panel.bNoBackgroundBlur = true
--         panel.childPanels = {}
--         panel.Paint = nil

--         local inventory = LocalPlayer():GetCharacter():GetInventory()

--         if inventory then
--             panel:SetInventory(inventory)
--         end

--         ix.gui.inv1 = panel

--         -- if ix.option.Get('openBags', true) then
--         --     for _, v in pairs(inventory:GetItems()) do
--         --         if not v.isBag then
--         --             continue
--         --         end

--         --         v.functions.View.OnClick(v)
--         --     end
--         -- end

--         canvas.PerformLayout = canvasLayout
--         canvas:Layout()
--     end

--     self.model_box = self:Add('EditablePanel')
--     self.model_box:SetSize(SScale(300), ScrH())
--     self.model_box:SetPos(ScrW() - SScale(300), 0)

--     self.model_view = self.model_box:Add('ixModelPanel')
--     self.model_view:Dock(FILL)
-- 	self.model_view:SetModel('models/error.mdl')
-- 	self.model_view:SetFOV(55)
-- 	self.model_view.PaintModel = self.model_view.Paint

--     self.model_view:SetModel( LocalPlayer():GetCharacter():GetModel() )
--     self.mdl_eyepos = self.model_view.Entity:GetBonePosition(self.model_view.Entity:LookupBone('ValveBiped.Bip01_Head1'))
--         self.mdl_eyepos:Add(Vector(0, 0, 2))
--         self.model_view:SetLookAt(self.mdl_eyepos)
--         self.model_view:SetCamPos(self.mdl_eyepos-Vector(-8, -20, 4))
--     self.model_view.Entity:SetEyeTarget(self.mdl_eyepos-Vector(-8, -20, 4))

--     for _, bodygroup in ipairs( LocalPlayer():GetBodyGroups() ) do
--         self.model_view.Entity:SetBodygroup(bodygroup.id, LocalPlayer():GetBodygroup(bodygroup.id))
--     end
--     self.model_view.Entity:SetSkin(LocalPlayer():GetSkin())
-- end

-- function PANEL:OnKeyCodePressed(key)
-- 	if key == KEY_TAB then
-- 		self:Remove()
-- 	end
-- end

-- function PANEL:Remove()
--     if IsValid(self.model_box) then
--         self.model_box:Remove()
--     end

--     self:AlphaTo(0, .3, 0, function()
--         BaseClass.Remove(self)
--     end)
-- end

-- function PANEL:Paint(w, h)
--     ix.util.DrawBlur(self, 5)
--     surface.SetDrawColor(22, 22, 22, 166)
--     surface.DrawRect(0, 0, w, h)

--     --- @field dynamic smoke
--     surface.SetDrawColor(73 + 111, 68 + 111, 65 + 111, 22)
--     surface.SetMaterial(textures.smoke1)
--     DrawTexturedRectRotatedPoint(
--         ScrW(),
--         ScrH() + SScale(900) / 4,
--         SScale(900),
--         SScale(900),
--         (CurTime() % 360) * 2,
--         SScale(800) / 32,
--         SScale(800) / 32
--     )

--     --- @field mainmenu texture
--     surface.SetDrawColor(255, 255, 255, 255)
--     surface.SetMaterial(textures.mainmenu)
--     surface.DrawTexturedRect(SScale(30), 0, SScale(680/2.8), SScale(1024/2.8))

--     --- @field background darkness
--     surface.SetDrawColor(0, 0, 0, 11)
--     surface.DrawRect(SScale(30), 0, SScale(680/2.8) - SScale(2), SScale(1024/2.8))

--     --- @field title & logo background radial gradient
--     surface.SetDrawColor(99, 99, 99, 22)
--     surface.SetMaterial(textures.gradient_radial)
--     surface.DrawTexturedRect(SScale(30) - SScale(29), -SScale(700/2)/2, SScale(600/2), SScale(650/2))

--     --- @field title background
--     surface.SetDrawColor(154, 136, 102, 255)
--     surface.SetMaterial(textures.card)
--     surface.DrawTexturedRect(SScale(12/2.1), SScale(85/1.43), SScale(886/3.337), SScale(85/3.5))

--     --- @field title text
--     draw.Text({
--         text = LocalPlayer():GetCharacter():GetName():utf8sub(1, 22),
--         font = PLUGIN:GetFontInternal('Title'),
--         pos = {SScale(20) + SScale(132), SScale(71)},
--         xalign = TEXT_ALIGN_CENTER,
--         yalign = TEXT_ALIGN_CENTER,
--         color = color_white
--     })

--     --- @field logo
--     surface.SetDrawColor(255, 255, 255, 255)
--     surface.SetMaterial(textures.logo)
--     surface.DrawTexturedRect(SScale(18) + SScale(680/2.8) / 3, SScale(10), SScale(463/4.5), SScale(173/4.5))
-- end

-- vgui.Register('metroNewMenu', PANEL, 'EditablePanel')

-- do
--     local GM = GM || GAMEMODE
--     function GM:ScoreboardShow()
--         if LocalPlayer():GetCharacter() then
--             vgui.Create('metroNewMenu')
--         end
--     end
    
--     function GM:ScoreboardHide()
--     end
-- end