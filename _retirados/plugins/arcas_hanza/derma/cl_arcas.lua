timer.Simple(0, function()
	local PLUGIN = ix.plugin.Get("arcas_hanza")
	local PLUGIN_UI = ix.plugin.Get("metroui")
	if (not PLUGIN_UI) then return end

	-- ════════════════════════════════════════════════════════════════
	--  HELPERS
	-- ════════════════════════════════════════════════════════════════

	local COLOR_BG = Color(22, 22, 22, 220)
	local COLOR_PANEL = Color(33, 33, 33, 220)
	local COLOR_BORDER = Color(66, 66, 66, 88)
	local COLOR_ACCENT = Color(244, 105, 5) -- color de facción de Hanza
	local COLOR_GREEN = Color(66, 166, 66)
	local COLOR_RED = Color(200, 66, 66)
	local COLOR_TEXT = Color(200, 200, 200)
	local COLOR_DIM = Color(120, 120, 120)

	local function MakeButton(parent, text, color, callback)
		local btn = parent:Add("DButton")
		btn:SetText(text)
		btn:SetFont(PLUGIN_UI:GetFontInternal("Button"))
		btn:SetTextColor(color)
		btn.Paint = function(_, w, h)
			local alpha = btn:IsHovered() and 33 or 16
			surface.SetDrawColor(color.r, color.g, color.b, alpha)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(color.r, color.g, color.b, 44)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		btn.DoClick = function()
			surface.PlaySound("tls/click.wav")
			if (callback) then callback() end
		end
		return btn
	end

	-- ════════════════════════════════════════════════════════════════
	--  PANEL PRINCIPAL
	-- ════════════════════════════════════════════════════════════════

	local PANEL = {}
	DEFINE_BASECLASS("EditablePanel")

	function PANEL:Init()
		if (IsValid(ix.gui.arcasHanza)) then
			ix.gui.arcasHanza:Remove()
		end
		ix.gui.arcasHanza = self

		surface.PlaySound("interface/inv_belt.mp3")

		self:SetSize(ScrW(), ScrH())
		self:MakePopup()
		self:SetAlpha(0)
		self:AlphaTo(255, 0.3)
		self:SetPos(0, 0)

		self.ent = nil
		self.balance = 0

		-- Botón cerrar
		self.closeBtn = self:Add("DButton")
		self.closeBtn:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		self.closeBtn:SetText("CERRAR X")
		self.closeBtn:SetTextColor(COLOR_TEXT)
		self.closeBtn:SizeToContents()
		self.closeBtn:SetPos(ScrW() - self.closeBtn:GetWide() - SScale(6), -self.closeBtn:GetTall())
		self.closeBtn.Paint = nil
		self.closeBtn.cColor = Color(200, 200, 200)
		self.closeBtn.Think = function(me)
			if (me:IsHovered()) then
				me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, COLOR_RED)
			else
				me.cColor = LerpColor(math.ease.InOutCirc(0.1), me.cColor, COLOR_TEXT)
			end
			me:SetTextColor(me.cColor)
		end
		self.closeBtn.DoClick = function()
			surface.PlaySound("tls/click.wav")
			self:Remove()
		end
		self.closeBtn.pPos = -self.closeBtn:GetTall()
		self.closeBtn:CreateAnimation(0.3, {
			index = 1,
			target = {pPos = SScale(22)},
			easing = "outQuint",
			Think = function(_, panel) panel:SetY(panel.pPos) end,
		})

		-- Panel central
		local pw = SScale(150)
		local ph = SScale(128)
		self.mainPanel = self:Add("EditablePanel")
		self.mainPanel:SetSize(pw, ph)
		self.mainPanel:SetPos(ScrW() / 2 - pw / 2, ScrH())
		self.mainPanel.Paint = function(_, w, h)
			ix.util.DrawBlur(self.mainPanel, 5)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end
		self.mainPanel.pPos = ScrH()
		self.mainPanel:CreateAnimation(0.6, {
			index = 2,
			target = {pPos = ScrH() / 2 - ph / 2},
			easing = "outQuint",
			Think = function(_, panel) panel:SetY(panel.pPos) end,
		})

		-- Cabecera
		self.header = self.mainPanel:Add("EditablePanel")
		self.header:Dock(TOP)
		self.header:SetTall(SScale(24))
		self.header.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 22)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 44)
			surface.DrawRect(0, h - 1, w, 1)
		end

		self.titleLabel = self.header:Add("DLabel")
		self.titleLabel:SetFont(PLUGIN_UI:GetFontInternal("Button2"))
		self.titleLabel:SetText("ARCAS DE HANZA")
		self.titleLabel:SetTextColor(COLOR_ACCENT)
		self.titleLabel:SizeToContents()
		self.titleLabel:SetPos(SScale(10), SScale(6))

		-- Contenido
		self.content = self.mainPanel:Add("EditablePanel")
		self.content:Dock(FILL)
		self.content:DockMargin(SScale(6), SScale(6), SScale(6), SScale(6))

		-- Saldo actual
		self.balanceLabel = self.content:Add("DLabel")
		self.balanceLabel:Dock(TOP)
		self.balanceLabel:SetTall(SScale(22))
		self.balanceLabel:SetFont(PLUGIN_UI:GetFontInternal("Button2"))
		self.balanceLabel:SetTextColor(COLOR_TEXT)
		self.balanceLabel:SetContentAlignment(5)
		self.balanceLabel:SetText("0 Balas")

		-- Fila de retiro
		local rowWithdraw = self.content:Add("EditablePanel")
		rowWithdraw:Dock(TOP)
		rowWithdraw:SetTall(SScale(20))
		rowWithdraw:DockMargin(0, SScale(6), 0, 0)

		self.amountEntry = rowWithdraw:Add("DTextEntry")
		self.amountEntry:Dock(FILL)
		self.amountEntry:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		self.amountEntry:SetTextColor(color_white)
		self.amountEntry:SetNumeric(true)
		self.amountEntry:SetPlaceholderText("Cantidad a retirar...")
		self.amountEntry.Paint = function(me, w, h)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			me:DrawTextEntryText(color_white, COLOR_ACCENT, color_white)
		end

		self.allBtn = rowWithdraw:Add("DButton")
		self.allBtn:Dock(RIGHT)
		self.allBtn:DockMargin(SScale(4), 0, 0, 0)
		self.allBtn:SetWide(SScale(36))
		self.allBtn:SetText("TODO")
		self.allBtn:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		self.allBtn:SetTextColor(COLOR_DIM)
		self.allBtn.Paint = function(_, w, h)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		self.allBtn.DoClick = function()
			surface.PlaySound("tls/click.wav")
			self.amountEntry:SetValue(tostring(self.balance))
			self:UpdateFeeNote()
		end

		-- Nota de merma (se calcula en vivo mientras se escribe la cantidad)
		self.feeNote = self.content:Add("DLabel")
		self.feeNote:Dock(TOP)
		self.feeNote:SetTall(SScale(12))
		self.feeNote:DockMargin(0, SScale(2), 0, 0)
		self.feeNote:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		self.feeNote:SetTextColor(COLOR_DIM)

		local feePct = math.floor(ix.arcas.withdrawFeeRate * 100)
		function self:UpdateFeeNote()
			local amount = math.max(math.floor(tonumber(self.amountEntry:GetValue()) or 0), 0)
			local fee = math.floor(amount * ix.arcas.withdrawFeeRate)
			self.feeNote:SetText(("Recibirás %i Balas (%i%% de merma: %i)."):format(amount - fee, feePct, fee))
		end

		self.amountEntry.OnChange = function() self:UpdateFeeNote() end
		self:UpdateFeeNote()

		-- Botón retirar
		local rowConfirm = self.content:Add("EditablePanel")
		rowConfirm:Dock(TOP)
		rowConfirm:SetTall(SScale(20))
		rowConfirm:DockMargin(0, SScale(4), 0, 0)

		MakeButton(rowConfirm, "RETIRAR", COLOR_ACCENT, function()
			local amount = math.floor(tonumber(self.amountEntry:GetValue()) or 0)
			if (amount <= 0) then
				LocalPlayer():Notify("Introduce una cantidad válida.")
				return
			end

			if (not IsValid(self.ent)) then return end

			net.Start(PLUGIN.netWithdraw)
				net.WriteEntity(self.ent)
				net.WriteUInt(amount, 32)
			net.SendToServer()

			self.amountEntry:SetValue("")
			self:UpdateFeeNote()
		end):Dock(FILL)

		-- Hint cerrar
		self.closeHint = self:Add("EditablePanel")
		self.closeHint:SetSize(SScale(300), SScale(30))
		self.closeHint:SetPos(ScrW() / 2 - SScale(150), ScrH())
		self.closeHint.Paint = function(_, w, h)
			draw.Text({
				text = "PRESIONA 'ESPACIO' O 'ESC' PARA CERRAR",
				font = PLUGIN_UI:GetFontInternal("PostScriptum"),
				pos = {w / 2, h / 2},
				xalign = TEXT_ALIGN_CENTER,
				yalign = TEXT_ALIGN_CENTER,
				color = Color(255, 255, 255, 33),
			})
		end
		self.closeHint.pPos = ScrH()
		self.closeHint:CreateAnimation(0.8, {
			index = 1,
			target = {pPos = ScrH() - SScale(30)},
			easing = "outQuint",
			Think = function(_, panel) panel:SetY(panel.pPos) end,
		})
	end

	function PANEL:SetData(ent, balance)
		self.ent = ent
		self.balance = balance or 0
		self.balanceLabel:SetText(string.Comma(self.balance) .. " Balas")
	end

	-- ════════════════════════════════════════════════════════════════
	--  PAINT / REMOVE
	-- ════════════════════════════════════════════════════════════════

	function PANEL:Paint(w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(COLOR_BG)
		surface.DrawRect(0, 0, w, h)
	end

	function PANEL:OnKeyCodePressed(keyCode)
		if (keyCode == KEY_SPACE or keyCode == KEY_ESCAPE) then
			self:Remove()
		end
	end

	function PANEL:Remove()
		self:AlphaTo(0, 0.3, 0, function()
			BaseClass.Remove(self)
		end)
	end

	function PANEL:PerformLayout(w, h)
		if (IsValid(self.closeBtn)) then
			self.closeBtn:SetX(w - self.closeBtn:GetWide() - SScale(6))
		end
		if (IsValid(self.closeHint)) then
			self.closeHint:SetX(w / 2 - self.closeHint:GetWide() / 2)
		end
	end

	vgui.Register("metroArcasHanza", PANEL, "EditablePanel")

	-- OnKeyCodePressed(KEY_ESCAPE) por sí solo no basta: ESC abre el menú de
	-- pausa de GMod por encima igualmente. Bloquearlo mientras el panel esté
	-- abierto es lo que de verdad hace que "ESC" solo cierre este panel.
	hook.Add("OnPauseMenuShow", "metroArcasHanza_BlockPauseMenu", function()
		if (IsValid(ix.gui.arcasHanza)) then
			ix.gui.arcasHanza:Remove()
			return true
		end
	end)
end)
