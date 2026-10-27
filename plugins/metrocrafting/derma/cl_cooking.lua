timer.Simple(0, function()
    local PLUGIN = ix.plugin.Get('metrocrafting') -- for some reason PLUGIN doesnt work w.i.p
    local PLUGIN_UI = ix.plugin.Get('metroui')
    if not PLUGIN_UI then error('metroui plugin missing!') return end

    local PANEL = {}

    local function GetResultQty(result)
        if (not result) then return "" end
        local min, max = 0, 0
        for _, amt in pairs(result) do
            if (type(amt) == "table") then
                min = min + math.min(unpack(amt))
                max = max + math.max(unpack(amt))
            else
                min = min + amt
                max = max + amt
            end
        end
        if (min <= 1 and max <= 1) then
            return ""
        end
        if (min == max) then
            return " x" .. min
        end
        return " x" .. min .. "-" .. max
    end

    DEFINE_BASECLASS('EditablePanel')

    function PANEL:Init()
        if IsValid(ix.gui.metroCrafting) then
            ix.gui.metroCrafting:Remove()
        end
        ix.gui.metroCrafting = self

        surface.PlaySound('interface/inv_belt.mp3')

        self:SetSize(ScrW(), ScrH())
        self:MakePopup()
        self:SetAlpha(0)
        self:AlphaTo(255, .3)
        self:SetPos(0, 0)

        self.closeBtn = self:Add('DButton')
        self.closeBtn:SetFont(PLUGIN_UI:GetFontInternal('CharFields'))
        self.closeBtn:SetText('CERRAR X')
        self.closeBtn:SetTextColor(Color(200, 200, 200))
        self.closeBtn:SizeToContents()
        self.closeBtn:SetPos(ScrW() - self.closeBtn:GetWide() - SScale(6), -self.closeBtn:GetTall())
        self.closeBtn.Paint = nil
        self.closeBtn.cColor = Color(200, 200, 200)
        self.closeBtn.pPos = -self.closeBtn:GetTall()
        self.closeBtn.Think = function(me)
            if me:IsHovered() then
                me.cColor = LerpColor(
                    math.ease.InOutCirc(0.1),
                    me.cColor,
                    Color(255, 66, 66)
                )
            else
                me.cColor = LerpColor(
                    math.ease.InOutCirc(0.1),
                    me.cColor,
                    Color(200, 200, 200)
                )
            end
    
            me:SetTextColor( me.cColor )
        end
        self.closeBtn.DoClick = function()
            surface.PlaySound('efg/ui/click.wav')
            self:Remove()
        end
        self.closeBtn:CreateAnimation(.3, {
            index = 1,
            target = {pPos = SScale(22)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetY(panel.pPos)
            end
        })

        self.close = self:Add('EditablePanel')
        self.close:SetSize(SScale(300), SScale(40))
        self.close:SetPos(ScrW()/2 - SScale(300)/2, ScrH())
        self.close.Paint = function(_, w, h)
            draw.Text({
                text = 'PRESIONA \'ESPACIO\' PARA CERRAR',
                font = PLUGIN_UI:GetFontInternal('PostScriptum'),
                pos = {w/2, h - SScale(20/2)},
                xalign = TEXT_ALIGN_CENTER,
                yalign = TEXT_ALIGN_CENTER,
                color = Color(255, 255, 255, 33)
            })
        end
        self.close.pPos = ScrH()
        self.close:CreateAnimation(.8, {
            index = 1,
            target = {pPos = ScrH() - SScale(37)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetY(panel.pPos)
            end
        })

        self.w_card_x = ScrW()

        self.categories = self:Add('DHorizontalScroller')
        self.categories:SetSize(SScale(620), SScale(85/5) + SScale(5))
        self.categories:SetPos(ScrW(), SScale(4) - SScale(5/2))
        self.categories.Paint = function(_, w, h)
            surface.SetDrawColor(22, 22, 22, 166)
            surface.DrawRect(0, 0, w, h)
        end
        self.categories:SetOverlap(-4)
        self.categories.pPos = ScrW()
        self.categories:CreateAnimation(.8, {
            index = 2,
            target = {pPos = ScrW() - SScale(620)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetX(panel.pPos)
            end
        })

        for _, v in ipairs(ix.recipe:GetCategories()) do
            local btn = self.categories:Add('DButton')
            btn:SetText('')
            btn:SetSize(self.categories:GetTall() - SScale(5), self.categories:GetTall() - SScale(5))
            btn.pColors = {
                Color(66, 66, 66, 11),
                Color(66, 66, 66, 44),
                Color(255, 255, 255, 88)
            }
            btn.Paint = function(me, w, h)
                ix.util.DrawBlur(me, 5)

                surface.SetDrawColor(me.pColors[1])
                surface.DrawRect(0, 0, w, h)

                surface.SetDrawColor(me.pColors[2])
                surface.DrawOutlinedRect(0, 0, w, h, 2)
    
                surface.SetDrawColor(me.pColors[3])
                local iconPath = PLUGIN.categoriesIcons[v] or 'efgui/icons/craft/guns.png'
                surface.SetMaterial(ix.util.GetMaterial(iconPath, 'noclamp smooth'))
                surface.DrawTexturedRect(SScale(10)/2, SScale(10)/2, w - SScale(10), h - SScale(10))
    
                surface.SetDrawColor(me.pColors[3])
                surface.SetMaterial(ix.util.GetMaterial('efgui/icons/corner.png', 'noclamp smooth'))
                surface.DrawTexturedRect(2 + SScale(5), 2 + SScale(5), w - 4 - SScale(5), h - 4 - SScale(5))
            end
            btn.DoClick = function()
                if self.category == v then return end
                surface.PlaySound('efg/ui/click.wav')
                self.category = v
                self:Append(v)
            end
            btn.Think = function(me)
                if me:IsHovered() || self.category == v then
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(166, 166, 166, 22) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(166, 166, 166, 88) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 166) )
                else
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(66, 66, 66, 11) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(66, 66, 66, 44) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 88) )
                end
            end
            self.categories:AddPanel(btn)
        end

        self.category = ''
    end

    function PANEL:PerformLayout(w, h)
        if IsValid(self.closeBtn) then
            self.closeBtn:SetX(w - self.closeBtn:GetWide() - SScale(6))
        end

        if IsValid(self.close) then
            self.close:SetX(w/2 - self.close:GetWide()/2)
        end

        if IsValid(self.categories) then
            self.categories:SetX(w - self.categories:GetWide())
        end
    end

    function PANEL:Append(categoryName)
        local blueprints = ix.recipe:GetCategoriesWithItems()[categoryName]
        if not blueprints then return end

        if IsValid(self.blueprints) then self.blueprints:Remove() end
        if IsValid(self.overview) then self.overview:Remove() end
        if IsValid(self.ingredients) then self.ingredients:Remove() end

        self.blueprints = self:Add('DScrollPanel')
        self.blueprints:SetSize(SScale(125), SScale(250))
        self.blueprints:SetPos(-SScale(200), self:GetTall()/2 - SScale(250)/2)
        self.blueprints.Paint = function(_, w, h)
            surface.SetDrawColor(66, 66, 66, 233)
            surface.DrawRect(0, 0, w, 1)
        end
        self.blueprints.pPos = -SScale(200)
        self.blueprints:CreateAnimation(.8, {
            index = 2,
            target = {pPos = SScale(20)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetX(panel.pPos)
            end
        })

        self.selected_blueprint_over = nil
        self.selected_blueprint = nil

        for _, v in ipairs(blueprints) do
            if v.hidden then continue end
            if (v.oficio and ix.oficios) then
				local char = LocalPlayer():GetCharacter()
				if (not char or not ix.oficios.CanCraft(char, v.oficio, v.tierRequired or 1)) then continue end
			end
            local canCraftThis = ix.recipe:CanCookRecipe(v, LocalPlayer())
            local pnl = self.blueprints:Add('EditablePanel')
            pnl:Dock(TOP)
            pnl:SetTall(SScale(25))
            pnl:DockMargin(2, 2, 2, 0)

            local btn = pnl:Add('DButton')
            btn:Dock(FILL)
            btn:SetText('')
            btn.DoClick = function()
                if self.selected_blueprint == v then return end
                surface.PlaySound('efg/ui/click.wav')
                self.selected_blueprint = v

                if IsValid(self.tools) then
                    local text = ''
                    if v.tools && istable(v.tools) then
                        for _, v in ipairs(v.tools) do
                            local toolData = ix.item.list[v]
                            local toolName = toolData && toolData.name || v
                            text = text .. (text ~= '' && '\n' || '') .. '• ' .. toolName
                        end
                    end
                    self.tools:SetText(text)
                end

                if IsValid(self.ingredients_raw) then
                    self.ingredients_raw:SetText('')
                    if v.ingredients && istable(v.ingredients) then
                        local char = LocalPlayer():GetCharacter()
                        local inventory = char and char:GetInventory()
                        local first = true
                        for ingredient, amount in pairs(v.ingredients) do
                            local itemData = ix.item.list[ingredient]
                            local itemName = itemData && itemData.name || ingredient
                            local have = 0
                            if inventory then
                                for _, invItem in pairs(inventory:GetItems()) do
                                    if invItem.uniqueID == ingredient then
                                        have = have + invItem:GetData("Amount", 1)
                                    end
                                end
                            end
                            if not first then
                                self.ingredients_raw:InsertColorChange(200, 200, 200, 255)
                                self.ingredients_raw:AppendText('\n')
                            end
                            first = false
                            if have >= amount then
                                self.ingredients_raw:InsertColorChange(66, 200, 66, 255)
                            else
                                self.ingredients_raw:InsertColorChange(200, 66, 66, 255)
                            end
                            self.ingredients_raw:AppendText('• ' .. have .. '/' .. amount .. ' ' .. itemName)
                        end
                    end
                end

                if IsValid(self.description_raw) then
                    self.description_raw:SetText('')
                    self.description_raw:InsertColorChange(154, 136, 102, 255)
                    self.description_raw:AppendText(v.name:upper() .. GetResultQty(v.result) .. '\n')
                    self.description_raw:InsertColorChange(255, 255, 255, 255)
                    self.description_raw:AppendText(v.description || 'Este objeto no tiene descripcion.')
                end

                if IsValid(self.model_view) then
                    self.model_view:SetModel(v.model)
                    self.model_view:GetEntity():SetSkin(v.skin)
                end

                if IsValid(self.craft) then
                    self.craft:SetDisabled(false)

                    local canCraft, reason = ix.recipe:CanCookRecipe(v, LocalPlayer())
                    if canCraft then
                        local maxQty = ix.recipe:MaxCookable(v, LocalPlayer())
                        if (IsValid(self.qty_panel)) then
                            if (maxQty > 1) then
                                self.craftMaxQty = maxQty
                                self.craftQty = 1
                                self.qtyLabel:SetText('1')
                                self.qty_panel:SetVisible(true)
                            else
                                self.craftQty = 1
                                self.qty_panel:SetVisible(false)
                            end
                        end

                        self.craft.Paint = function(_, w, h)
                            surface.SetDrawColor(66, 166, 66, 11/2)
                            surface.DrawRect(0, 0, w, h)

                            surface.SetDrawColor(66, 166, 66, 22)
                            surface.DrawOutlinedRect(0, 0, w, h, 2)
                        end

                        self.craft:SetTextColor(Color(66, 166, 66))

                        self.craft.DoClick = function()
                            if v.craftSound then
                                surface.PlaySound(v.craftSound)
                            else
                                surface.PlaySound('efg/ui/click.wav')
                            end

                            net.Start(PLUGIN.netNameRecipe, true)
                                net.WriteString(v.uniqueID)
                                net.WriteUInt(self.craftQty, 8)
                            net.SendToServer()

                            self:Remove()
                        end
                    else
                        if (IsValid(self.qty_panel)) then
                            self.craftQty = 1
                            self.qty_panel:SetVisible(false)
                        end

                        self.craft.Paint = function(_, w, h)
                            surface.SetDrawColor(166, 66, 66, 11/2)
                            surface.DrawRect(0, 0, w, h)

                            surface.SetDrawColor(166, 66, 66, 22)
                            surface.DrawOutlinedRect(0, 0, w, h, 2)
                        end

                        self.craft:SetTextColor(Color(166, 66, 66))
                        self.craft.DoClick = function()
                            surface.PlaySound('efg/ui/click.wav')
                            LocalPlayer():Notify(reason)
                        end
                    end
                end
            end
            btn.Paint = nil
            btn.Think = function(me)
                if me:IsHovered() && self.selected_blueprint ~= v then
                    self.selected_blueprint_over = v
                elseif not me:IsHovered() && self.selected_blueprint_over == v then
                    self.selected_blueprint_over = nil
                end
            end

            local icon = btn:Add('EditablePanel')
            icon:Dock(LEFT)
            icon:DockMargin(2, 2, 0, 2)
            icon:SetText('')
            icon:SetWide(SScale(24))
            icon:SetMouseInputEnabled(false)
            icon.pColors = {
                Color(66, 66, 66, 11),
                Color(66, 66, 66, 44),
                Color(255, 255, 255, 88)
            }
            icon.Paint = function(me, w, h)
                ix.util.DrawBlur(me, 5)

                surface.SetDrawColor(me.pColors[1])
                surface.DrawRect(0, 0, w, h)
    
                surface.SetDrawColor(me.pColors[2])
                surface.DrawOutlinedRect(0, 0, w, h, 2)

                surface.SetDrawColor(me.pColors[3])
                surface.SetMaterial(ix.util.GetMaterial(v.icon || 'efgui/icons/clay.png', 'noclamp smooth'))
                surface.DrawTexturedRect(SScale(10)/2, SScale(10)/2, w - SScale(10), h - SScale(10))
    
                surface.SetDrawColor(me.pColors[3])
                surface.SetMaterial(ix.util.GetMaterial('efgui/icons/corner.png', 'noclamp smooth'))
                surface.DrawTexturedRect(2 + SScale(5), 2 + SScale(5), w - 4 - SScale(5), h - 4 - SScale(5))
            end
            icon.Think = function(me)
                if btn:IsHovered() || self.selected_blueprint_over == v || self.selected_blueprint == v then
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(166, 166, 166, 22) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(166, 166, 166, 88) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 166) )
                else
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(66, 66, 66, 11) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(66, 66, 66, 44) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 88) )
                end
            end

            local notice = btn:Add('DLabel')
            notice:Dock(FILL)
            notice:DockMargin(5, 2, 2, 2)
            notice:SetContentAlignment(5)
            notice:SetFont(PLUGIN_UI:GetFontInternal('CharFields'))
            notice:SetText(v.name .. GetResultQty(v.result))
            notice.pColors = {
                Color(66, 66, 66, 11),
                Color(66, 66, 66, 44),
                Color(255, 255, 255, 88)
            }
            notice.Think = function(me)
                if btn:IsHovered() || self.selected_blueprint_over == v || self.selected_blueprint == v then
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(166, 166, 166, 22) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(166, 166, 166, 88) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 166) )
                else
                    me.pColors[1] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[1], Color(66, 66, 66, 11) )
                    me.pColors[2] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[2], Color(66, 66, 66, 44) )
                    me.pColors[3] = LerpColor( math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 88) )
                end
                if canCraftThis then
                    me:SetTextColor(Color(100, 220, 100))
                else
                    me:SetTextColor(Color(200, 200, 200))
                end
            end
            notice.Paint = function(me, w, h)
                ix.util.DrawBlur(me, 5)

                surface.SetDrawColor(me.pColors[1])
                surface.DrawRect(0, 0, w, h)
    
                surface.SetDrawColor(me.pColors[2])
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
        end

        self.overview = self:Add('EditablePanel')
        self.overview:SetSize(SScale(300), SScale(265))
        self.overview:SetPos(self:GetWide()/2 - SScale(300)/2, self:GetTall())
        self.overview.Paint = function(me, w, h)
            ix.util.DrawBlur(me, 5)

            surface.SetDrawColor(66, 66, 66, 11)
            surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(66, 66, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        self.overview.pPos = self:GetTall()
        self.overview:CreateAnimation(.8, {
            index = 3,
            target = {pPos = self:GetTall()/2 - SScale(300)/2 + SScale(25)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetY(panel.pPos)
            end
        })

        self.model_view_pnl = self.overview:Add('EditablePanel')
        self.model_view_pnl:Dock(FILL)
        self.model_view_pnl:DockMargin(SScale(10), SScale(10), SScale(10), SScale(3))

        self.model_view = self.model_view_pnl:Add('ixModelPanel')
        self.model_view:SetSize(SScale(163), SScale(162))
        self.model_view:SetX(SScale(58.5))
        self.model_view:SetFOV(45)
        self.model_view.PaintModel = self.model_view.Paint
        self.model_view:SetLookAt(Vector(0, 0, 5))
        self.model_view:SetCamPos(Vector(60, 35, 50))
        self.model_view:SetAmbientLight(Color(112, 128, 130, 255))
        self.model_view:SetDirectionalLight(BOX_FRONT, Color(154, 136, 102))
        self.model_view.PaintOver = function(_, w, h)
            surface.SetDrawColor(66, 66, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end

        self.craft = self.model_view_pnl:Add('DButton')
        self.craft:Dock(RIGHT)
        self.craft:SetWide(SScale(56))
        self.craft:SetText('COCINAR')
        self.craft:SetFont(PLUGIN_UI:GetFontInternal('Button'))
        self.craft:SetDisabled(true)
        self.craft.Paint = function(_, w, h)
            surface.SetDrawColor(66, 166, 66, 11/2)
            surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(66, 166, 66, 22)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end

        self.dismantle = self.model_view_pnl:Add('DButton')
        self.dismantle:Dock(LEFT)
        self.dismantle:SetWide(SScale(56))
        self.dismantle:SetText('DESMONTAR')
        self.dismantle:SetFont(PLUGIN_UI:GetFontInternal('Button'))
        self.dismantle:SetDisabled(true)
        self.dismantle.Paint = function(_, w, h)
            surface.SetDrawColor(166, 66, 66, 11/2)
            surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(166, 66, 66, 22)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end

        self.description = self.overview:Add('EditablePanel')
        self.description:Dock(BOTTOM)
        self.description:DockMargin(SScale(10), 0, SScale(10), SScale(10))
        self.description:SetTall(SScale(80))
        self.description.Paint = function(_, w, h)
            -- surface.SetDrawColor(66, 66, 66, 11)
            -- surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(66, 66, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end

        self.description_raw = self.description:Add('RichText')
        self.description_raw:Dock(FILL)
        self.description_raw:DockMargin(SScale(3), SScale(3), SScale(3), SScale(3))
        self.description_raw:SetContentAlignment(7)
        self.description_raw:InsertColorChange(255, 255, 255, 255)
        self.description_raw:SetVerticalScrollbarEnabled(true)
        self.description_raw:SetMouseInputEnabled(false)
        self.description_raw:SetSelectable(false)
        self.description_raw.PerformLayout = function(me)
            me:SetFontInternal(PLUGIN_UI:GetFontInternal('PostScriptum'))
        end

        self.craftQty = 1
        self.craftMaxQty = 1

        self.qty_panel = self.overview:Add('EditablePanel')
        self.qty_panel:Dock(BOTTOM)
        self.qty_panel:DockMargin(SScale(10), SScale(3), SScale(10), 0)
        self.qty_panel:SetTall(SScale(22))
        self.qty_panel:SetVisible(false)

        local qtyTitle = self.qty_panel:Add('DLabel')
        qtyTitle:Dock(LEFT)
        qtyTitle:SetWide(SScale(55))
        qtyTitle:SetText('Cantidad:')
        qtyTitle:SetFont(PLUGIN_UI:GetFontInternal('PostScriptum'))
        qtyTitle:SetTextColor(Color(200, 200, 200))
        qtyTitle:SetContentAlignment(5)

        local qtyMinus = self.qty_panel:Add('DButton')
        qtyMinus:Dock(LEFT)
        qtyMinus:SetWide(SScale(22))
        qtyMinus:SetText('-')
        qtyMinus:SetFont(PLUGIN_UI:GetFontInternal('Button'))
        qtyMinus:SetTextColor(Color(200, 200, 200))
        qtyMinus.Paint = function(me, w, h)
            surface.SetDrawColor(166, 66, 66, me:IsHovered() and 44 or 22)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(166, 66, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        qtyMinus.DoClick = function()
            self.craftQty = math.max(1, self.craftQty - 1)
            self.qtyLabel:SetText(tostring(self.craftQty))
            surface.PlaySound('efg/ui/click.wav')
        end

        self.qtyLabel = self.qty_panel:Add('DLabel')
        self.qtyLabel:Dock(LEFT)
        self.qtyLabel:SetWide(SScale(30))
        self.qtyLabel:SetText('1')
        self.qtyLabel:SetFont(PLUGIN_UI:GetFontInternal('CharFields'))
        self.qtyLabel:SetTextColor(Color(255, 255, 255))
        self.qtyLabel:SetContentAlignment(5)

        local qtyPlus = self.qty_panel:Add('DButton')
        qtyPlus:Dock(LEFT)
        qtyPlus:SetWide(SScale(22))
        qtyPlus:SetText('+')
        qtyPlus:SetFont(PLUGIN_UI:GetFontInternal('Button'))
        qtyPlus:SetTextColor(Color(200, 200, 200))
        qtyPlus.Paint = function(me, w, h)
            surface.SetDrawColor(66, 166, 66, me:IsHovered() and 44 or 22)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(66, 166, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        qtyPlus.DoClick = function()
            self.craftQty = math.min(self.craftMaxQty, self.craftQty + 1)
            self.qtyLabel:SetText(tostring(self.craftQty))
            surface.PlaySound('efg/ui/click.wav')
        end

        local qtyMax = self.qty_panel:Add('DButton')
        qtyMax:Dock(LEFT)
        qtyMax:DockMargin(SScale(3), 0, 0, 0)
        qtyMax:SetWide(SScale(35))
        qtyMax:SetText('MAX')
        qtyMax:SetFont(PLUGIN_UI:GetFontInternal('PostScriptum'))
        qtyMax:SetTextColor(Color(200, 200, 200))
        qtyMax.Paint = function(me, w, h)
            surface.SetDrawColor(112, 128, 130, me:IsHovered() and 44 or 22)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(112, 128, 130, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        qtyMax.DoClick = function()
            self.craftQty = self.craftMaxQty
            self.qtyLabel:SetText(tostring(self.craftQty))
            surface.PlaySound('efg/ui/click.wav')
        end

        self.ingredients = self:Add('EditablePanel')
        self.ingredients:SetSize(SScale(150), SScale(265))
        self.ingredients:SetPos(self:GetWide(), self:GetTall()/2 - SScale(300)/2 + SScale(25))
        self.ingredients.Paint = function(me, w, h)
            ix.util.DrawBlur(me, 5)

            surface.SetDrawColor(66, 66, 66, 11)
            surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(66, 66, 66, 44)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        self.ingredients.pPos = self:GetWide()
        self.ingredients:CreateAnimation(.8, {
            index = 4,
            target = {pPos = self:GetWide()/2 - SScale(150)/2 + SScale(235)},
            easing = 'outQuint',
            Think = function(animation, panel)
                panel:SetX(panel.pPos)
            end
        })

        self.tools_title = self.ingredients:Add('EditablePanel')
        self.tools_title:Dock(TOP)
        self.tools_title:SetTall(SScale(18))
        self.tools_title:DockMargin(SScale(10), SScale(10), SScale(10), SScale(3))
        self.tools_title:SetMouseInputEnabled(false)
        self.tools_title.Paint = function(_, w, h)
            surface.SetDrawColor(66, 66, 66, 233)
            surface.DrawRect(0, h - 1, w, 1)
            draw.SimpleText('Herramientas', PLUGIN_UI:GetFontInternal('CharFields'), w/2, h/2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        self.tools = self.ingredients:Add('RichText')
        self.tools:Dock(TOP)
        self.tools:DockMargin(SScale(12), 0, SScale(12), SScale(3))
        self.tools:SetTall(SScale(110))
        self.tools:SetContentAlignment(7)
        self.tools:InsertColorChange(255, 255, 255, 255)
        self.tools:SetVerticalScrollbarEnabled(true)
        self.tools:SetMouseInputEnabled(false)
        self.tools:SetSelectable(false)
        self.tools.PerformLayout = function(me)
            me:SetFontInternal(PLUGIN_UI:GetFontInternal('PostScriptum'))
        end

        self.ingredients_title = self.ingredients:Add('EditablePanel')
        self.ingredients_title:Dock(TOP)
        self.ingredients_title:SetTall(SScale(18))
        self.ingredients_title:DockMargin(SScale(10), SScale(0), SScale(10), SScale(3))
        self.ingredients_title:SetMouseInputEnabled(false)
        self.ingredients_title.Paint = function(_, w, h)
            surface.SetDrawColor(66, 66, 66, 233)
            surface.DrawRect(0, h - 1, w, 1)
            draw.SimpleText('Materiales', PLUGIN_UI:GetFontInternal('CharFields'), w/2, h/2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        self.ingredients_raw = self.ingredients:Add('RichText')
        self.ingredients_raw:Dock(TOP)
        self.ingredients_raw:DockMargin(SScale(12), 0, SScale(12), SScale(10))
        self.ingredients_raw:SetTall(SScale(110))
        self.ingredients_raw:SetContentAlignment(7)
        self.ingredients_raw:InsertColorChange(255, 255, 255, 255)
        self.ingredients_raw:SetVerticalScrollbarEnabled(true)
        self.ingredients_raw:SetMouseInputEnabled(false)
        self.ingredients_raw:SetSelectable(false)
        self.ingredients_raw.PerformLayout = function(me)
            me:SetFontInternal(PLUGIN_UI:GetFontInternal('PostScriptum'))
        end
    end

    function PANEL:Paint(w, h)
        ix.util.DrawBlur(self, 5)

        surface.SetDrawColor(255, 255, 255, 166)
        surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/3.jpg'))
        surface.DrawTexturedRect(0, 0, w, h)

        surface.SetDrawColor(255, 255, 255, 99)
        surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/1.png'))
        surface.DrawTexturedRect(0, 0, SScale(1046/3), SScale(39/3))

        surface.SetDrawColor(255, 255, 255, 99)
        surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/2.png'))
        surface.DrawTexturedRect(0, 0, SScale(1098/3), SScale(936/3))    

        --- @field warn text
        if self.category == '' then
            draw.Text({
                text = 'Elige una categoria para ver las recetas disponibles',
                font = PLUGIN_UI:GetFontInternal('Button'),
                pos = {ScrW() / 2, ScrH() / 2},
                xalign = TEXT_ALIGN_CENTER,
                yalign = TEXT_ALIGN_CENTER,
                color = color_white
            })    
        end

        draw.Text({
            text = self.category:upper(),
            font = PLUGIN_UI:GetFontInternal('Button2'),
            pos = {self.blueprints && self.blueprints:GetX() || SScale(20), SScale(40)},
            xalign = TEXT_ALIGN_LEFT,
            yalign = TEXT_ALIGN_TOP,
            color = color_white
        })

        surface.SetDrawColor(22, 22, 22, 166)
        surface.DrawRect(0, 0, w, h)
    end

    function PANEL:PaintOver(w, h)
        self.w_card_x = Lerp(math.ease.InOutCirc(.2), self.w_card_x, w - SScale(886/5))
        surface.SetDrawColor(154, 136, 102, 255)
        surface.SetMaterial(ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'))
        surface.DrawTexturedRect(self.w_card_x, SScale(4), SScale(886/5), SScale(85/5))

        draw.Text({
            text = 'COCINA',
            font = PLUGIN_UI:GetFontInternal('Button2'),
            pos = {self.w_card_x + SScale(40), SScale(5)},
            xalign = TEXT_ALIGN_LEFT,
            yalign = TEXT_ALIGN_TOP,
            color = color_white
        })
    end

    function PANEL:OnKeyCodePressed(keyCode)
        if keyCode == KEY_SPACE then
            self:Remove()
        end
    end

    function PANEL:Remove()
        if IsValid(self.model_view) then
            self.model_view:Remove()
        end

        self:AlphaTo(0, .3, 0, function()
            BaseClass.Remove(self)
        end)
    end

    vgui.Register('metroCooking', PANEL, 'EditablePanel')
end)