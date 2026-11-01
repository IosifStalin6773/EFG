local PLUGIN = PLUGIN
local PANEL = {}
DEFINE_BASECLASS('EditablePanel')

local textures = {
  mainmenu       = ix.util.GetMaterial('efgui/mainmenu.png', 'noclamp smooth'),
  gradient_radial= ix.util.GetMaterial('helix/gui/radial-gradient.png', 'noclamp smooth'),
  card           = ix.util.GetMaterial('efgui/mainmenu_card.png', 'noclamp smooth'),
  logo           = ix.util.GetMaterial('efgui/logo32028.png', 'noclamp smooth'),
  smoke1         = ix.util.GetMaterial('efgui/smoke2.png', 'noclamp smooth')
}

local function DrawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
  local c = math.cos(math.rad(rot))
  local s = math.sin(math.rad(rot))
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

local currentPage = 'inv'

function PANEL:Init()
  if IsValid(ix.gui.efgNewMenu) then
    ix.gui.efgNewMenu:Remove()
  end

  ix.gui.efgNewMenu = self
  self:SetSize(ScrW(), ScrH())
  self:SetPos(0, 0)
  self:MakePopup()
  self:SetAlpha(0)
  self:AlphaTo(255, .3)

  self.close = self:Add('DButton')
  self.close:SetFont(PLUGIN:GetFontInternal('CharFields'))
  self.close:SetText('CERRAR X')
  self.close:SetTextColor(Color(200, 200, 200))
  self.close:SizeToContents()
  self.close:SetPos(ScrW() - self.close:GetWide() - SScale(6), -self.close:GetTall())
  self.close.Paint = nil
  self.close.cColor = Color(200, 200, 200)
  self.close.pPos = -self.close:GetTall()
  self.close.Think = function(me)
    if me:IsHovered() then
      me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, Color(255, 66, 66))
    else
      me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, Color(200, 200, 200))
    end
    me:SetTextColor(me.cColor)
  end
  self.close.DoClick = function()
    surface.PlaySound('efg/ui/click.wav')
    self:Remove()
  end
  self.close:CreateAnimation(.3, {
    index = 1,
    target = { pPos = SScale(22) },
    easing = 'outQuint',
    Think = function(animation, panel)
      panel:SetY(panel.pPos)
    end
  })

  self.characters = self:Add('DButton')
  self.characters:SetFont(PLUGIN:GetFontInternal('CharFields'))
  self.characters:SetText('PERSONAJES')
  self.characters:SetTextColor(Color(200, 200, 200))
  self.characters:SizeToContents()
  self.characters:SetPos(ScrW() - self.characters:GetWide() - SScale(40), -self.characters:GetTall())
  self.characters.Paint = nil
  self.characters.cColor = Color(200, 200, 200)
  self.characters.pPos = -self.characters:GetTall()
  self.characters.Think = function(me)
    if me:IsHovered() then
      me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, Color(255, 66, 66))
    else
      me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, Color(200, 200, 200))
    end
    me:SetTextColor(me.cColor)
  end
  self.characters.DoClick = function()
    surface.PlaySound('efg/ui/click.wav')
    self:Remove()
    vgui.Create('ixCharMenu')
  end
  self.characters:CreateAnimation(.3, {
    index = 1,
    target = { pPos = SScale(22) },
    easing = 'outQuint',
    Think = function(animation, panel)
      panel:SetY(panel.pPos)
    end
  })

  self.btn_list = self:Add('DScrollPanel')
  self.btn_list:SetSize(SScale(54/2), ScrH() - SScale(54))
  self.btn_list:SetPos(ScrW(), SScale(64)/2)
  self.btn_list.pPos = ScrW()
  self.btn_list:SetZPos(1000)
  self.btn_list:CreateAnimation(.3, {
    index = 2,
    target = { pPos = ScrW() - self.btn_list:GetWide() - SScale(5) },
    easing = 'outQuint',
    Think = function(animation, panel)
      panel:SetX(panel.pPos)
    end
  })

  self.prime_panel = self:Add('EditablePanel')
  self.prime_panel:SetSize(SScale(340), ScrH() - SScale(64))
  self.prime_panel:SetPos(ScrW(), SScale(64)/2)
  self.prime_panel.Paint = function(_, w, h) end
  self.prime_panel:SetZPos(999)
  self.prime_panel.pPos = ScrW()
  self.prime_panel:CreateAnimation(.3, {
    index = 4,
    target = { pPos = ScrW() - SScale(330) - SScale(64/1.5) },
    easing = 'outQuint',
    Think = function(animation, panel)
      panel:SetX(panel.pPos)
    end
  })

  self.panel = self.prime_panel:Add('EditablePanel')
  self.panel:Dock(FILL)
  self.panel:DockPadding(5, 5, 5, 5)
  self.panel:DockMargin(5, 5, 5, 5)

  self.model_view = self:Add('ixModelPanel')
  self.model_view:SetSize(SScale(200), SScale(320))
  self.model_view:SetPos(0, ScrH() - SScale(320))
  self.model_view:SetModel('models/error.mdl')
  self.model_view:SetFOV(25)
  self.model_view.PaintModel = self.model_view.Paint
  self.model_view:SetModel(LocalPlayer():GetModel())
  self.model_view:SetLookAt(Vector(0, 0, 55))
  self.model_view:SetCamPos(Vector(60, 35, 50))
  self.model_view:SetAmbientLight(Color(112, 128, 130, 255))
  self.model_view:SetDirectionalLight(BOX_FRONT, Color(145, 148, 108))
  self.model_view:GetEntity():SetSkin(LocalPlayer():GetSkin())
  for _, bodygroup in ipairs(LocalPlayer():GetBodyGroups()) do
    self.model_view.Entity:SetBodygroup(bodygroup.id, LocalPlayer():GetBodygroup(bodygroup.id))
  end
  local _boneIndex = self.model_view.Entity:LookupBone('ValveBiped.Bip01_Head1')
  if (_boneIndex != nil and _boneIndex != -1) then
  	self.mdl_eyepos = self.model_view.Entity:GetBonePosition(_boneIndex)
  else
  	self.mdl_eyepos = self.model_view.Entity:GetPos() + Vector(0, 0, 60)
  end
  self.mdl_eyepos:Add(Vector(0, 0, 2))
  self.model_view.Entity:SetEyeTarget(self.mdl_eyepos - Vector(-8, -20, 4))

  function self.model_view:LayoutEntity()
    local entity = self.Entity
    if (not IsValid(entity)) then return end
    if (not self._idleSet) then
      local seq = entity:LookupSequence('idle_all_01')
      if (seq <= 0) then seq = entity:LookupSequence('idle_unarmed') end
      if (seq <= 0) then seq = entity:SelectWeightedSequence(ACT_IDLE) end
      if (seq > 0) then
        entity:ResetSequence(seq)
        self._idleSet = true
      else
        for _, v in ipairs(entity:GetSequenceList()) do
          if (v:lower():find('idle') and v != 'idlenoise') then
            entity:ResetSequence(v)
            self._idleSet = true
            break
          end
        end
      end
    end
    local scrW, scrH = ScrW(), ScrH()
    local xRatio  = gui.MouseX() / scrW
    local yRatio  = gui.MouseY() / scrH
    local x       = self:LocalToScreen(self:GetWide() / 2)
    local xRatio2 = x / scrW
    entity:SetPoseParameter('head_pitch', yRatio * 90 - 30)
    entity:SetPoseParameter('head_yaw',   (xRatio - xRatio2) * 90 - 5)
    entity:SetAngles(Angle(0, 45, 0))
    entity:SetIK(false)
    self:RunAnimation()
  end

  self.w_card_x = ScrW()
  self.tabs = {}
  hook.Run('CreateMenuButtons', self.tabs) -- puede introducir funciones además de tablas
  -- Normalización de pestañas función -> tabla
  for _menu, v in pairs(self.tabs) do
    if type(v) == "function" then
      local wrapped = {
        Create = v,
        icon = "efgui/icons/default.png",
        name = tostring(_menu)
      }
      self.tabs[_menu] = wrapped
      v = wrapped
    end

    if not v.icon then continue end

    local btn = self.btn_list:Add('DButton')
    if _menu == 'settings' or _menu == 'config' then
      btn:SetY(self.btn_list:GetTall() - SScale(30))
      btn:SetWide(SScale(22.8))
      btn:SetX(5)
      if _menu == 'config' then
        btn:SetY(self.btn_list:GetTall() - SScale(55))
      end
    else
      btn:Dock(TOP)
      btn:DockMargin(SScale(2), SScale(2), SScale(2), SScale(1/4))
    end

    btn:SetTall(SScale(23))
    btn:SetText('')
    btn.pColors = {
      Color(66, 66, 66, 11),
      Color(66, 66, 66, 44),
      Color(255, 255, 255, 88)
    }
    btn.Paint = function(me, w, h)
      surface.SetDrawColor(me.pColors[1])
      surface.DrawRect(0, 0, w, h)
      surface.SetDrawColor(me.pColors[2])
      surface.DrawOutlinedRect(0, 0, w, h, 2)
      surface.SetDrawColor(me.pColors[3])
      surface.SetMaterial(ix.util.GetMaterial(v.icon, 'noclamp smooth'))
      surface.DrawTexturedRect(SScale(10)/2, SScale(10)/2, w - SScale(10), h - SScale(10))
      surface.SetDrawColor(me.pColors[3])
      surface.SetMaterial(ix.util.GetMaterial('efgui/icons/corner.png', 'noclamp smooth'))
      surface.DrawTexturedRect(2 + SScale(15), 2 + SScale(15), w - 4 - SScale(15), h - 4 - SScale(15))
    end

    btn.DoClick = function()
      if currentPage == _menu then return end
      currentPage = _menu
      if self._panel then
        self._panel:Remove()
      end

      if _menu == 'inv' then
        surface.PlaySound('interface/inv_belt.mp3')
      else
        if IsValid(ix.gui.inv1) then
          ix.gui.inv1:Remove()
        end
        CloseDermaMenus()
        surface.PlaySound('efg/ui/click.wav')
      end

      self._panel = v:Create(self.panel)

      self.prime_panel.pPos = ScrW()
      self.prime_panel:CreateAnimation(.3, {
        index = 4,
        target = { pPos = ScrW() - SScale(330) - SScale(64/1.5) },
        easing = 'outQuint',
        Think = function(animation, panel)
          panel:SetX(panel.pPos)
        end
      })
    end

    btn.Think = function(me)
      if me:IsHovered() or currentPage == _menu then
        me.pColors[1] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[1], Color(166, 166, 166, 22))
        me.pColors[2] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[2], Color(166, 166, 166, 88))
        me.pColors[3] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 166))
      else
        me.pColors[1] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[1], Color(66, 66, 66, 11))
        me.pColors[2] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[2], Color(66, 66, 66, 44))
        me.pColors[3] = LerpColor(math.ease.InOutCirc(0.3), me.pColors[3], Color(255, 255, 255, 88))
      end
    end

    self.btn_list:AddItem(btn)
  end

  timer.Simple(0, function() -- skip 1 frame
    if (not IsValid(self) or not IsValid(self.panel)) then return end
    local tabdef = self.tabs[currentPage]
    if (not tabdef) then return end
    if type(tabdef) == "function" then
      tabdef = { Create = tabdef, icon = "efgui/icons/default.png", name = tostring(currentPage) }
      self.tabs[currentPage] = tabdef
    end
    self._panel = tabdef:Create(self.panel)
    if currentPage == 'inv' then
      surface.PlaySound('interface/inv_belt.mp3')
    end
  end)
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB then
    self:Remove()
  end
end

function PANEL:Remove()
  --- @anims
  self.close:MoveTo(ScrW() - self.close:GetWide() - SScale(6), -self.close:GetTall(), .3)
  self.model_view:Remove()
  self:AlphaTo(0, .3, 0, function()
    BaseClass.Remove(self)
  end)
end

function PANEL:Paint(w, h)
  ix.util.DrawBlur(self, 5)
  surface.SetDrawColor(color_white)
  surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/3.jpg'))
  surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

  surface.SetDrawColor(color_white)
  surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/1.png'))
  surface.DrawTexturedRect(0, 0, SScale(1046/3), SScale(39/3))

  surface.SetDrawColor(color_white)
  surface.SetMaterial(ix.util.GetMaterial('efgui/spawnmenu/Menu/2.png'))
  surface.DrawTexturedRect(0, 0, SScale(1098/3), SScale(936/3))

  draw.Text({
    text = LocalPlayer():Name(),
    font = PLUGIN:GetFontInternal('Button'),
    pos = { SScale(35), SScale(15) },
    xalign = TEXT_ALIGN_LEFT,
    yalign = TEXT_ALIGN_TOP,
    color = color_white
  })

  draw.Text({
    text = LocalPlayer():GetCharacter():GetChosenFaction(),
    font = PLUGIN:GetFontInternal('CharFields'),
    pos = { SScale(35), SScale(24) },
    xalign = TEXT_ALIGN_LEFT,
    yalign = TEXT_ALIGN_TOP,
    color = Color(166, 166, 166)
  })

  do
    local img = PLUGIN.spawns[LocalPlayer():GetCharacter():GetChosenFactionId()]
    if img then
      img = img.icon
      surface.SetDrawColor(color_white)
      surface.SetMaterial(img)
      surface.DrawTexturedRect(SScale(15), SScale(15), SScale(64/4), SScale(64/4))
    end
  end

  surface.SetDrawColor(22, 22, 22, 166)
  surface.DrawRect(0, 0, w, h)
end

function PANEL:PaintOver(w, h)
  self.w_card_x = Lerp(math.ease.InOutCirc(.2), self.w_card_x, ScrW() - SScale(886/5))
  surface.SetDrawColor(145, 148, 108, 255)
  surface.SetMaterial(textures.card)
  surface.DrawTexturedRect(self.w_card_x, SScale(4), SScale(886/5), SScale(85/5))

  local titleText = (function()
    local entry = self.tabs[currentPage]
    local nm = (type(entry) == "table" and entry.name) or tostring(currentPage) or "Unnamed"
    return nm:upper()
  end)()

  draw.Text({
    text = titleText,
    font = PLUGIN:GetFontInternal('Button2'),
    pos = { self.w_card_x + SScale(40), SScale(5) },
    xalign = TEXT_ALIGN_LEFT,
    yalign = TEXT_ALIGN_TOP,
    color = color_white
  })

  if IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels then
    for i = 1, #ix.gui.inv1.childPanels do
      local panel = ix.gui.inv1.childPanels[i]
      if IsValid(panel) then
        panel:PaintManual()
      end
    end
  end
end

vgui.Register('efgNewMenu', PANEL, 'EditablePanel')

do
  local GM = GM or GAMEMODE
  function GM:ScoreboardShow()
    if LocalPlayer():GetCharacter() then
      vgui.Create('efgNewMenu')
    end
  end
  function GM:ScoreboardHide()
  end
end