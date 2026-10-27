local PLUGIN = PLUGIN
local PANEL = {}

local textures = {
    bg = ix.util.GetMaterial('efgui/backgrounds/creation.jpg', 'noclamp smooth'),
    smoke1 = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth'),
    card = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
    menu = ix.util.GetMaterial('efgui/creation/ui_pausemenu_back_002.png', 'noclamp smooth')
}

local buffer = {
    name             = '',
    description      = '',
    model            = '',
    oficio           = 'usec',
    faction          = PLUGIN.defaultFaction,
    chosenSkin       = 0,
    chosenBodygroups = {}
}

local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
	local c = math.cos( math.rad(rot) )
	local s = math.sin( math.rad(rot) )

	local newx = y0 * s - x0 * c
	local newy = y0 * c + x0 * s

	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
end

local function GetModelEyePos(entity)
	local boneIndex = entity:LookupBone('ValveBiped.Bip01_Head1')
	if (boneIndex != nil and boneIndex != -1) then
		local pos = entity:GetBonePosition(boneIndex)
		return pos
	end
	return entity:GetPos() + Vector(0, 0, 60)
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

local t_color = Color(96-10, 68-10, 48-10)
function PANEL:Init()
    if IsValid(ix.gui.MetroCharacterCreation) then
        ix.gui.MetroCharacterCreation:Remove()
    end
    ix.gui.MetroCharacterCreation = self
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()

    self.payload = buffer
    self.payload.faction = PLUGIN.defaultFaction
    self.payload.chosenSkin = 0
    self.payload.chosenBodygroups = {}
    buffer.chosenSkin = {}
    buffer.chosenSkin = 0
    buffer.oficio = 'usec'

    self.menu = self:Add('EditablePanel')
    self.menu:SetSize( ScrH(), ScrH() )
    self.menu:SetPos(0, 0)
    self.menu.Paint = function(_, w, h)
        surface.SetDrawColor(color_white)
        surface.SetMaterial(textures.menu)
        surface.DrawTexturedRect(0, 0, w, h)
    end

    self.name = self:Add('EditablePanel')
    self.name:SetSize( SScale(225), SScale(15) )
    self.name:SetPos(SScale(53), SScale(90))
    self.name.Paint = function(_, w, h)
        surface.SetDrawColor(t_color)
        surface.DrawRect(0, h - 2, w, 2)
    end

    self.name_label = self.name:Add('DLabel')
    self.name_label:Dock(LEFT)
    self.name_label:SetText('NOMBRE')
    self.name_label:SetFont(PLUGIN:GetFontInternal('Button'))
    self.name_label:SizeToContents()
    self.name_label:SetContentAlignment(2)
    self.name_label:SetTextColor(t_color)

    self.name_input = self:Add('DTextEntry')
    self.name_input:SetSize( SScale(225), SScale(15) )
    self.name_input:SetPos(SScale(53), SScale(105))
    self.name_input:SetFont(PLUGIN:GetFontInternal('CharFields'))
    self.name_input:SetPaintBackground(false)
    self.name_input:SetTabbingDisabled(true)
    self.name_input:SetTextColor(t_color)
    self.name_input:SetEnterAllowed(false)
    self.name_input:SetDrawLanguageIDAtLeft(false)
    self.name_input:SetPlaceholderText('Inserte el nombre de su personaje')
    self.name_input:SetValue( buffer.name )
    self.name_input:SetUpdateOnType(true)
    self.name_input.OnValueChange = function(_, str)
        buffer.name = str
        self.payload.name = str
    end

    self.desc = self:Add('EditablePanel')
    self.desc:SetSize( SScale(225), SScale(15) )
    self.desc:SetPos(SScale(53), SScale(120))
    self.desc.Paint = function(_, w, h)
        surface.SetDrawColor(t_color)
        surface.DrawRect(0, h - 2, w, 2)
    end

    self.desc_label = self.desc:Add('DLabel')
    self.desc_label:Dock(LEFT)
    self.desc_label:SetText('DESCRIPCIÓN')
    self.desc_label:SetFont(PLUGIN:GetFontInternal('Button'))
    self.desc_label:SizeToContents()
    self.desc_label:SetContentAlignment(2)
    self.desc_label:SetTextColor(t_color)

    self.desc_input = self:Add('DTextEntry')
    self.desc_input:SetSize( SScale(225), SScale(15) )
    self.desc_input:SetPos(SScale(53), SScale(135))
    self.desc_input:SetFont(PLUGIN:GetFontInternal('CharFields'))
    self.desc_input:SetPaintBackground(false)
    self.desc_input:SetTabbingDisabled(true)
    self.desc_input:SetTextColor(t_color)
    self.desc_input:SetEnterAllowed(false)
    self.desc_input:SetDrawLanguageIDAtLeft(false)
    self.desc_input:SetPlaceholderText('Descripción de su personaje')
    self.desc_input:SetValue( buffer.description )
    self.desc_input:SetUpdateOnType(true)
    self.desc_input.OnValueChange = function(_, str)
        buffer.description = str
        self.payload.description = str
    end

	self.oficio = self:Add('EditablePanel')
	self.oficio:SetSize(SScale(225), SScale(15))
	self.oficio:SetPos(SScale(53), SScale(155))
	self.oficio.Paint = function(_, w, h)
		surface.SetDrawColor(t_color)
		surface.DrawRect(0, h - 2, w, 2)
	end

	self.oficio_label = self.oficio:Add('DLabel')
	self.oficio_label:Dock(LEFT)
	self.oficio_label:SetText('BANDO')
	self.oficio_label:SetFont(PLUGIN:GetFontInternal('Button'))
	self.oficio_label:SizeToContents()
	self.oficio_label:SetContentAlignment(2)
	self.oficio_label:SetTextColor(t_color)

	-- EFG: en vez de oficio se elige bando de PMC (USEC o BEAR)
	local OFICIOS = {
		{id = "usec", nombre = "USEC", color = Color(60, 100, 160)},
		{id = "bear", nombre = "BEAR", color = Color(160, 60, 50)},
	}

	self.oficio_list_box = self:Add('EditablePanel')
	self.oficio_list_box:SetSize(SScale(225), SScaleMin(44))
	self.oficio_list_box:SetPos(SScale(53), SScale(173))
	self.oficio_list_box.Paint = function() end

	do
		local gap = 2
		local btnW = math.floor((SScale(225) - gap * (#OFICIOS - 1)) / #OFICIOS)
		local btnH = SScaleMin(44)

		local currentFaction = ix.faction.indices[self.payload.faction or PLUGIN.defaultFaction]
		buffer.oficio = currentFaction and currentFaction.uniqueID or OFICIOS[1].id
		self.payload.oficio = buffer.oficio

		for i, oficio in ipairs(OFICIOS) do
			local btn = self.oficio_list_box:Add('DButton')
			btn:SetSize(btnW, btnH)
			btn:SetPos((btnW + gap) * (i - 1), 0)
			btn:SetText('')
			btn.outline_lerp = 0
			btn.title_pos_y = btn:GetTall() / 2
			btn.Paint = function(me, w, h)
				surface.SetDrawColor(ColorAlpha(oficio.color, 88))
				surface.DrawRect(0, 0, w, h)

				if (oficio.id == self.payload.oficio) then
					me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 8)
					me.title_pos_y = Lerp(math.ease.InOutCirc(0.2), me.title_pos_y, SScale(7))
					surface.SetDrawColor(ColorAlpha(oficio.color, 200))
					surface.DrawRect(0, 0, w, h)
				else
					me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 2)
					me.title_pos_y = Lerp(math.ease.InOutCirc(0.2), me.title_pos_y, h / 2)
				end

				surface.SetDrawColor(t_color)
				surface.DrawOutlinedRect(0, 0, w, h, me.outline_lerp)

				draw.Text({
					text = oficio.nombre,
					font = PLUGIN:GetFontInternal('Button'),
					pos = {w / 2 + 1.5, me.title_pos_y + 1.5},
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_CENTER,
					color = color_black
				})
				draw.Text({
					text = oficio.nombre,
					font = PLUGIN:GetFontInternal('Button'),
					pos = {w / 2, me.title_pos_y},
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_CENTER,
					color = color_white
				})
			end
			btn.DoClick = function()
				if (oficio.id == self.payload.oficio) then return end
				buffer.oficio = oficio.id
				self.payload.oficio = oficio.id

				local faction = ix.faction.teams[oficio.id]
				if (faction) then
					buffer.faction = faction.index
					self.payload.faction = faction.index
					buffer.model = 1
					self.payload.chosenSkin = 0
					self.payload.chosenBodygroups = {}
					self:BuildModelList()
					self:AppendModelOptions()
				end

				surface.PlaySound('efg/ui/click.wav')
			end
		end
	end

    self.left = self:Add('DButton')
    self.left:SetSize(SScale(50), SScale(12))
    self.left:SetPos(SScale(50), SScale(52))
    self.left:SetText('< ATRAS')
    self.left:SetFont(PLUGIN:GetFontInternal('Button'))
    self.left:SetTextColor(t_color)
    self.left.Paint = function() end
    self.left:SetExpensiveShadow(1, color_black)
    self.left.DoClick = function()
        surface.PlaySound('efg/ui/click.wav')
        local _pnl = vgui.Create('ixCharMenu')
        self.model_box:Remove()
        self:DoModal()
        self:AlphaTo(0, .3, 0, function()
            self:Remove()
        end)
    end

    self.right = self:Add('DButton')
    self.right:SetSize(SScale(65), SScale(12))
    self.right:SetPos(SScale(225+53)-SScale(55), SScale(52))
    self.right:SetText('SIGUIENTE >')
    self.right:SetFont(PLUGIN:GetFontInternal('Button'))
    self.right:SetTextColor(t_color)
    self.right.Paint = function() end
    self.right:SetExpensiveShadow(1, color_black)
    self.right.DoClick = function()
        surface.PlaySound('efg/ui/click.wav')
        self.model_box:Remove()

        local _pnl = vgui.Create('metroStationChoose')
        _pnl:SetPayload(self.payload)
        self:DoModal()
        self:AlphaTo(0, .3, 0, function()
            self:Remove()
        end)
    end

    self.model_box = self:Add('EditablePanel')
    self.model_box:SetSize(SScale(300), ScrH())
    self.model_box:SetPos(ScrW() - SScale(325), 0)
    self.model_box.Paint = function(_, w, h)
        -- surface.SetDrawColor(255, 255, 255)
        -- surface.DrawRect(0, 0, w, h)
    end

    self.model_view = self.model_box:Add('ixModelPanel')
    self.model_view:Dock(FILL)
	self.model_view:SetModel('models/error.mdl')
	self.model_view:SetFOV(55)
	self.model_view.PaintModel = self.model_view.Paint

    -- lista de modelos de la facción elegida (se rehace al cambiar USEC/BEAR)
    function self:BuildModelList()
    if (IsValid(self.model_list_box)) then self.model_list_box:Remove() end

    self.model_list_box = self:Add('DHorizontalScroller')
    self.model_list_box:SetSize( SScale(225), SScaleMin(44) )
    self.model_list_box:SetPos(SScale(53), SScale(210))
    self.model_list_box:SetOverlap(-4)
    function self.model_list_box.btnLeft:Paint(w, h) end
    function self.model_list_box.btnRight:Paint(w, h) end

    do
        local faction_models = ix.faction.Get(self.payload.faction or PLUGIN.defaultFaction)
        faction_models = faction_models.models
        if istable(faction_models) then
            -- Guardamos el índice numérico en lugar del string
            local modelIndex = type(buffer.model) == "number" and buffer.model or 1
            self.payload.model = modelIndex
            self.model_view:SetModel(faction_models[modelIndex])
            self.mdl_eyepos = GetModelEyePos(self.model_view.Entity)
            self.mdl_eyepos:Add(Vector(0, 0, 2))
            self.model_view:SetLookAt(self.mdl_eyepos)
            self.model_view:SetCamPos(self.mdl_eyepos - Vector(-8, -20, 4))
            self.model_view.Entity:SetEyeTarget(self.mdl_eyepos - Vector(-8, -20, 4))

            for index, mdl in ipairs(faction_models) do
                local btn = self.model_list_box:Add('SpawnIcon')
                btn:SetSize(self.model_list_box:GetTall(), self.model_list_box:GetTall())
                btn:SetModel(mdl)
                btn.DoClick = function()
                    if mdl == self.model_view:GetModel() then
                        return
                    end

                    -- Asignar el índice en lugar del string
                    buffer.model = index
                    self.payload.model = index
                    self.model_view:SetModel(mdl)

                    buffer.chosenSkin = {}
                    buffer.chosenSkin = 0
                    self.payload.chosenSkin = 0
                    self.payload.chosenBodygroups = {}

                    self:AppendModelOptions()

                    self.mdl_eyepos = GetModelEyePos(self.model_view.Entity)
                    self.mdl_eyepos:Add(Vector(0, 0, 2))
                    self.model_view:SetLookAt(self.mdl_eyepos)
                    self.model_view:SetCamPos(self.mdl_eyepos - Vector(-8, -20, 4))
                    self.model_view.Entity:SetEyeTarget(self.mdl_eyepos - Vector(-8, -20, 4))

                    surface.PlaySound('efg/ui/click.wav')
                end
                btn.outline_lerp = 0
                btn.Paint = function(me, w, h)
                    surface.SetDrawColor(0, 0, 0, 88)
                    surface.DrawRect(0, 0, w, h)

                    if IsValid(self.model_view) && isfunction(self.model_view.GetModel) then
                        if mdl == self.model_view:GetModel() then
                            surface.SetDrawColor(33, 166, 33, 166)
                            surface.DrawRect(0, 0, w, h)
                            me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 6)
                        else
                            me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 4)
                        end
                    end
                end
                btn.PaintOver = function(me, w, h)
                    surface.SetDrawColor(t_color)
                    surface.DrawOutlinedRect(0, 0, w, h, me.outline_lerp)
                end
                self.model_list_box:AddPanel(btn)
            end
        end
    end
    end

    self:BuildModelList()
    self:AppendModelOptions()

    self.attributes_list_box = self:Add('EditablePanel')
    self.attributes_list_box:SetSize( SScale(225), SScale(50) )
    self.attributes_list_box:SetPos(SScale(53), SScale(245))
    self.attributes_list_box.Paint = function(_, w, h)
    end

    do
        local maximum = hook.Run('GetDefaultAttributePoints', LocalPlayer(), payload) || 10
        local payload = self.payload
        if maximum >= 1 then
            local attributes = self.attributes_list_box:Add('DPanel')
            attributes:Dock(TOP)

            local y
            local total = 0

            payload.attributes = {}

            local totalBar = attributes:Add('ixAttributeBar')
            totalBar:SetMax(maximum)
            totalBar:SetValue(maximum)
            totalBar:Dock(TOP)
            totalBar:DockMargin(2, 2, 2, 2)
            totalBar:SetText(L('attribPointsLeft'))
            totalBar:SetReadOnly(true)
            totalBar:SetColor(Color(20, 120, 20, 255))

            y = totalBar:GetTall() + 4

            for k, v in SortedPairsByMemberValue(ix.attributes.list, 'name') do
                payload.attributes[k] = 0

                local bar = attributes:Add('ixAttributeBar')
                bar:SetMax(maximum)
                bar:Dock(TOP)
                bar:DockMargin(2, 2, 2, 2)
                bar:SetText(L(v.name))
                bar.OnChanged = function(this, difference)
                    if (total + difference) > maximum then
                        return false
                    end

                    total = total + difference
                    payload.attributes[k] = payload.attributes[k] + difference

                    totalBar:SetValue(totalBar.value - difference)
                end

                if v.noStartBonus then
                    bar:SetReadOnly()
                end

                y = y + bar:GetTall() + 4
            end

            attributes:SetTall(y)
        end
    end

    self.attributes_list_box:SizeToContents()

end

function PANEL:AppendModelOptions()
	if IsValid(self.bodygroups) then
		self.bodygroups:Remove()
	end

	if IsValid(self.bodygroups_body) then
		self.bodygroups_body:Remove()
	end

	local entity = self.model_view.Entity
	local modelPath = self.model_view:GetModel()
	local options = PLUGIN.modelOptions[modelPath]

	local skinList = {}
	local bgList = {}

	if (options) then
		if (istable(options.skins)) then
			skinList = options.skins
		end
		if (istable(options.bodygroups)) then
			bgList = options.bodygroups
		end
	else
		local skinCount = entity:SkinCount()
		if (skinCount > 1) then
			for i = 0, skinCount - 1 do
				skinList[#skinList + 1] = i
			end
		end

		for _, bg in pairs(entity:GetBodyGroups()) do
			if (bg.id != 0 and bg.num > 1) then
				local vals = {}
				for i = 0, bg.num - 1 do
					vals[#vals + 1] = i
				end
				bgList[bg.id] = vals
			end
		end
	end

	if (#skinList == 0 and table.Count(bgList) == 0) then return end

	self.bodygroups = self:Add('EditablePanel')
	self.bodygroups:SetSize(SScale(175), SScale(100))
	self.bodygroups:SetPos(ScrW() - SScale(175) - 10, ScrH() - SScale(100) - 10)
	self.bodygroups.Paint = function(_, w, h)
		surface.SetDrawColor(154, 136, 102)
		surface.SetMaterial(ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, w, SScale(85/5))

		draw.Text({
			text = 'OPCIONES DE MODELO',
			font = PLUGIN:GetFontInternal('Button'),
			pos = {w/2 + SScale(10), SScale(18/2)},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
			color = color_white
		})
	end

	self.bodygroups_body = self.bodygroups:Add('DScrollPanel')
	self.bodygroups_body:Dock(FILL)
	self.bodygroups_body:DockMargin(SScale(16.5), SScale(17), 0, 0)
	self.bodygroups_body.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 166)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(color_white)
		surface.SetMaterial(ix.util.GetMaterial('efgui/mainmenu2.png', 'noclamp smooth'))
		surface.DrawTexturedRect(0, 0, SScale(348/2.2), SScale(512/2.2))
	end

	if (#skinList > 0) then
		local title = self.bodygroups_body:Add('DLabel')
		title:SetFont(PLUGIN:GetFontInternal('CharFields'))
		title:SetContentAlignment(5)
		title:Dock(TOP)
		title:DockPadding(5, 5, 5, 5)
		title:DockMargin(5, 5, 5, 5)
		title:SetText('Apariencias')
		title:SizeToContents()

		local scroll = self.bodygroups_body:Add('DHorizontalScroller')
		scroll:Dock(TOP)
		scroll:DockMargin(5, 5, 5, 5)
		scroll:DockPadding(5, 5, 5, 5)
		scroll:SetTall(SScale(12))
		scroll:SetOverlap(-4)
		scroll.btnLeft.Paint = nil
		scroll.btnRight.Paint = nil

		for _, skin in ipairs(skinList) do
			local btn = scroll:Add('DButton')
			btn:SetSize(SScale(12), SScale(12))
			btn:SetText(skin)
			btn:SetFont(PLUGIN:GetFontInternal('Button'))
			btn.outline_lerp = 0
			btn.DoClick = function()
				buffer['chosenSkin'] = skin
				self.model_view.Entity:SetSkin(skin)
				surface.PlaySound('efg/ui/click.wav')
			end
			btn.Paint = function(me, w, h)
				surface.SetDrawColor(0, 0, 0, 88)
				surface.DrawRect(0, 0, w, h)

				if (buffer['chosenSkin'] == skin) then
					surface.SetDrawColor(33, 166, 33, 166)
					surface.DrawRect(0, 0, w, h)
					me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 6)
				else
					me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 4)
				end
			end
			btn.PaintOver = function(me, w, h)
				surface.SetDrawColor(t_color)
				surface.DrawOutlinedRect(0, 0, w, h, me.outline_lerp)
			end
			scroll:AddPanel(btn)
			scroll:SizeToContents()
		end
	end

	if (table.Count(bgList) > 0) then
		local title = self.bodygroups_body:Add('DLabel')
		title:SetFont(PLUGIN:GetFontInternal('CharFields'))
		title:SetContentAlignment(5)
		title:Dock(TOP)
		title:DockPadding(5, 5, 5, 5)
		title:DockMargin(5, 5, 5, 5)
		title:SetText('Grupos')
		title:SizeToContents()

		for bodygroupId, bodygroupOptions in SortedPairs(bgList) do
			local prime = self.bodygroups_body:Add('EditablePanel')
			prime:Dock(TOP)
			prime:DockPadding(5, 5, 5, 5)
			prime:DockMargin(5, 5, 5, 5)
			prime:SetTall(SScale(15))
			prime.Paint = function(_, w, h)
				surface.SetDrawColor(t_color)
				surface.SetMaterial(ix.util.GetMaterial('gui/gradient'))
				surface.DrawTexturedRect(0, 0, w, h)
			end

			local text = prime:Add('DLabel')
			text:Dock(LEFT)
			text:DockPadding(5, 5, 5, 5)
			text:DockMargin(5, 5, 5, 5)
			text:SetFont(PLUGIN:GetFontInternal('Button'))
			text:SetText(entity:GetBodygroupName(bodygroupId))
			text:SizeToContents()

			local scroll = prime:Add('DHorizontalScroller')
			scroll:Dock(FILL)
			scroll:SetOverlap(-4)
			scroll.btnLeft.Paint = nil
			scroll.btnRight.Paint = nil

			for _, bodygroupOption in ipairs(bodygroupOptions) do
				local btn = scroll:Add('DButton')
				btn:SetSize(SScale(12), SScale(12))
				btn:SetText(bodygroupOption)
				btn:SetFont(PLUGIN:GetFontInternal('CharFields'))
				btn.outline_lerp = 0
				btn.DoClick = function()
					buffer.chosenBodygroups[bodygroupId] = bodygroupOption
					self.model_view.Entity:SetBodygroup(bodygroupId, bodygroupOption)
					surface.PlaySound('efg/ui/click.wav')
				end
				btn.Paint = function(me, w, h)
					surface.SetDrawColor(0, 0, 0, 88)
					surface.DrawRect(0, 0, w, h)

					if (buffer.chosenBodygroups[bodygroupId] == bodygroupOption || (not buffer.chosenBodygroups[bodygroupId] and bodygroupOption == 0)) then
						surface.SetDrawColor(33, 166, 33, 166)
						surface.DrawRect(0, 0, w, h)
						me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 6)
					else
						me.outline_lerp = Lerp(math.ease.InOutCirc(0.2), me.outline_lerp, 4)
					end
				end
				btn.PaintOver = function(me, w, h)
					surface.SetDrawColor(t_color)
					surface.DrawOutlinedRect(0, 0, w, h, me.outline_lerp)
				end
				scroll:AddPanel(btn)
			end
		end
	end
end

function PANEL:SetPayload(payload)
    self.payload = payload
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

vgui.Register('metroCharacterCreation', PANEL, 'EditablePanel')