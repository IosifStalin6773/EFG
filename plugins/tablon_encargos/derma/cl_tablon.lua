timer.Simple(0, function()
	local PLUGIN = ix.plugin.Get("tablon_encargos")
	local PLUGIN_UI = ix.plugin.Get("metroui")
	if (not PLUGIN_UI) then return end

	-- ════════════════════════════════════════════════════════════════
	--  HELPERS
	-- ════════════════════════════════════════════════════════════════

	local COLOR_BG = Color(22, 22, 22, 220)
	local COLOR_PANEL = Color(33, 33, 33, 220)
	local COLOR_BORDER = Color(66, 66, 66, 88)
	local COLOR_ACCENT = Color(180, 140, 60)
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
		if (IsValid(ix.gui.metroTablon)) then
			ix.gui.metroTablon:Remove()
		end
		ix.gui.metroTablon = self

		surface.PlaySound("interface/inv_belt.mp3")

		self:SetSize(ScrW(), ScrH())
		self:MakePopup()
		self:SetAlpha(0)
		self:AlphaTo(255, 0.3)
		self:SetPos(0, 0)

		self.orders = {}
		self.pickups = {}
		self.mySteamID = LocalPlayer():SteamID64()
		self.showingCreate = false

		-- Cerrar botón
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
		local pw = SScale(380)
		local ph = SScale(320)
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
		self.header:SetTall(SScale(32))
		self.header.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 22)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 44)
			surface.DrawRect(0, h - 1, w, 1)
		end

		self.titleLabel = self.header:Add("DLabel")
		self.titleLabel:SetFont(PLUGIN_UI:GetFontInternal("Button2"))
		self.titleLabel:SetText("TABLON DE ENCARGOS")
		self.titleLabel:SetTextColor(COLOR_ACCENT)
		self.titleLabel:SizeToContents()
		self.titleLabel:SetPos(SScale(10), SScale(6))

		self.btnCreate = MakeButton(self.header, "NUEVO ENCARGO", COLOR_GREEN, function()
			self:ToggleCreatePanel()
		end)
		self.btnCreate:SetSize(SScale(90), SScale(20))
		self.btnCreate:SetPos(self.mainPanel:GetWide() - SScale(100), SScale(6))

		-- Contenido
		self.content = self.mainPanel:Add("EditablePanel")
		self.content:Dock(FILL)
		self.content:DockMargin(SScale(8), SScale(8), SScale(8), SScale(8))

		-- Banner de pickups
		self.pickupBanner = self.content:Add("EditablePanel")
		self.pickupBanner:Dock(TOP)
		self.pickupBanner:SetTall(0)
		self.pickupBanner:DockMargin(0, 0, 0, SScale(4))

		-- Scroll de encargos
		self.orderScroll = self.content:Add("DScrollPanel")
		self.orderScroll:Dock(FILL)
		self.orderScroll.Paint = nil
		local sbar = self.orderScroll:GetVBar()
		sbar:SetWide(SScale(3))
		sbar.Paint = function(_, w, h)
			surface.SetDrawColor(33, 33, 33, 100)
			surface.DrawRect(0, 0, w, h)
		end
		sbar.btnGrip.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 100)
			surface.DrawRect(0, 0, w, h)
		end
		sbar.btnUp.Paint = function() end
		sbar.btnDown.Paint = function() end

		-- Panel de crear encargo (oculto)
		self.createPanel = self.mainPanel:Add("EditablePanel")
		self.createPanel:SetSize(self.mainPanel:GetWide(), 0)
		self.createPanel:SetPos(0, self.mainPanel:GetTall())
		self.createPanel:SetVisible(false)
		self.createPanel.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		-- Hint cerrar
		self.closeHint = self:Add("EditablePanel")
		self.closeHint:SetSize(SScale(300), SScale(30))
		self.closeHint:SetPos(ScrW() / 2 - SScale(150), ScrH())
		self.closeHint.Paint = function(_, w, h)
			draw.Text({
				text = "PRESIONA 'ESPACIO' PARA CERRAR",
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

	function PANEL:SetData(orders, pickups)
		self.orders = orders or {}
		self.pickups = pickups or {}
		self:PopulateOrders()
		self:UpdatePickupBanner()
	end

	-- ════════════════════════════════════════════════════════════════
	--  BANNER DE RECOGIDAS
	-- ════════════════════════════════════════════════════════════════

	function PANEL:UpdatePickupBanner()
		if (#self.pickups == 0) then
			self.pickupBanner:SetTall(0)
			return
		end

		self.pickupBanner:SetTall(SScale(30))
		self.pickupBanner:Clear()

		self.pickupBanner.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 16)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 44)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local label = self.pickupBanner:Add("DLabel")
		label:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		label:SetText(("  Tienes %i entrega(s) pendiente(s)"):format(#self.pickups))
		label:SetTextColor(COLOR_GREEN)
		label:Dock(FILL)
		label:SetContentAlignment(4)

		local pickBtn = MakeButton(self.pickupBanner, "RECOGER", COLOR_GREEN, function()
			net.Start(PLUGIN.netPickup)
			net.SendToServer()
		end)
		pickBtn:Dock(RIGHT)
		pickBtn:SetWide(SScale(60))
		pickBtn:DockMargin(SScale(4), SScale(3), SScale(3), SScale(3))
	end

	-- ════════════════════════════════════════════════════════════════
	--  LISTA DE ENCARGOS
	-- ════════════════════════════════════════════════════════════════

	function PANEL:PopulateOrders()
		self.orderScroll:Clear()

		if (#self.orders == 0) then
			local empty = self.orderScroll:Add("DLabel")
			empty:Dock(TOP)
			empty:SetTall(SScale(40))
			empty:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
			empty:SetText("No hay encargos publicados.")
			empty:SetTextColor(COLOR_DIM)
			empty:SetContentAlignment(5)
			return
		end

		for _, order in ipairs(self.orders) do
			local row = self.orderScroll:Add("EditablePanel")
			row:Dock(TOP)
			row:SetTall(SScale(46))
			row:DockMargin(0, 0, 0, SScale(4))

			local isMine = order.posterSteamID == self.mySteamID

			row.Paint = function(_, w, h)
				local bgAlpha = row:IsChildHovered() and 44 or 22
				surface.SetDrawColor(66, 66, 66, bgAlpha)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(COLOR_BORDER)
				surface.DrawOutlinedRect(0, 0, w, h, 1)

				if (isMine) then
					surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 33)
					surface.DrawRect(0, 0, 3, h)
				end
			end

			local info = row:Add("EditablePanel")
			info:Dock(FILL)
			info:DockMargin(SScale(8), SScale(4), 0, SScale(4))
			info:SetMouseInputEnabled(false)
			info.Paint = function(_, w, h)
				draw.SimpleText(
					("%ix %s"):format(order.quantity, order.itemName),
					PLUGIN_UI:GetFontInternal("CharFields"),
					0, SScale(2),
					color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
				)

				draw.SimpleText(
					("%i RUB"):format(order.reward),
					PLUGIN_UI:GetFontInternal("PostScriptum"),
					0, SScale(16),
					COLOR_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
				)

				local posterText = isMine and "Tu encargo" or ("Por: " .. order.posterName)
				draw.SimpleText(
					posterText,
					PLUGIN_UI:GetFontInternal("PostScriptum"),
					0, SScale(28),
					COLOR_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
				)
			end

			local actions = row:Add("EditablePanel")
			actions:Dock(RIGHT)
			actions:SetWide(SScale(70))
			actions:DockMargin(0, SScale(4), SScale(6), SScale(4))

			if (isMine) then
				local cancelBtn = MakeButton(actions, "CANCELAR", COLOR_RED, function()
					net.Start(PLUGIN.netCancel)
						net.WriteUInt(order.id, 32)
					net.SendToServer()
				end)
				cancelBtn:Dock(FILL)
			else
				local fulfillBtn = MakeButton(actions, "CUMPLIR", COLOR_GREEN, function()
					self:ShowConfirmFulfill(order)
				end)
				fulfillBtn:Dock(FILL)
			end
		end
	end

	-- ════════════════════════════════════════════════════════════════
	--  CONFIRMAR CUMPLIMIENTO
	-- ════════════════════════════════════════════════════════════════

	function PANEL:ShowConfirmFulfill(order)
		local overlay = vgui.Create("EditablePanel")
		overlay:SetSize(ScrW(), ScrH())
		overlay:SetPos(0, 0)
		overlay:MakePopup()
		overlay:SetAlpha(0)
		overlay:AlphaTo(255, 0.2)
		overlay.Paint = function(_, w, h)
			ix.util.DrawBlur(overlay, 5)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local dw, dh = SScale(260), SScale(120)
		local dialog = overlay:Add("EditablePanel")
		dialog:SetSize(dw, dh)
		dialog:SetPos(ScrW() / 2 - dw / 2, ScrH() / 2 - dh / 2)
		dialog.Paint = function(_, w, h)
			ix.util.DrawBlur(dialog, 5)
			surface.SetDrawColor(COLOR_PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b, 44)
			surface.DrawOutlinedRect(0, 0, w, h, 2)

			draw.SimpleText(
				"CUMPLIR ENCARGO",
				PLUGIN_UI:GetFontInternal("Button2"),
				w / 2, SScale(16),
				COLOR_GREEN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)
			draw.SimpleText(
				("Entregaras %ix %s"):format(order.quantity, order.itemName),
				PLUGIN_UI:GetFontInternal("CharFields"),
				w / 2, SScale(38),
				color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)

			draw.SimpleText(
				("Recibirás %i RUB"):format(order.reward),
				PLUGIN_UI:GetFontInternal("PostScriptum"),
				w / 2, SScale(56),
				COLOR_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)
			draw.SimpleText(
				"Los ítems se retiraran de tu inventario.",
				PLUGIN_UI:GetFontInternal("PostScriptum"),
				w / 2, SScale(70),
				COLOR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)
		end

		local btnConfirm = MakeButton(dialog, "ENTREGAR", COLOR_GREEN, function()
			net.Start(PLUGIN.netFulfill)
				net.WriteUInt(order.id, 32)
			net.SendToServer()
			overlay:Remove()
		end)
		btnConfirm:SetSize(SScale(110), SScale(28))
		btnConfirm:SetPos(SScale(10), SScale(84))

		local btnCancel = MakeButton(dialog, "VOLVER", COLOR_TEXT, function()
			overlay:AlphaTo(0, 0.2, 0, function()
				overlay:Remove()
			end)
		end)
		btnCancel:SetSize(SScale(110), SScale(28))
		btnCancel:SetPos(SScale(140), SScale(84))
	end

	-- ════════════════════════════════════════════════════════════════
	--  PANEL DE CREAR ENCARGO
	-- ════════════════════════════════════════════════════════════════

	function PANEL:ToggleCreatePanel()
		if (self.showingCreate) then
			self.showingCreate = false
			self.createPanel:SetVisible(false)
			self.createPanel:SetTall(0)
			self.btnCreate:SetText("NUEVO ENCARGO")
			return
		end

		self.showingCreate = true
		self.btnCreate:SetText("VOLVER")

		self.createPanel:Clear()
		self.createPanel:SetVisible(true)
		self.createPanel:SetSize(self.mainPanel:GetWide(), self.mainPanel:GetTall() - self.header:GetTall())
		self.createPanel:SetPos(0, self.header:GetTall())
		self.createPanel:MoveToFront()

		-- Selector de ítem (todos los ítems del juego)
		local itemRow = self.createPanel:Add("EditablePanel")
		itemRow:Dock(TOP)
		itemRow:SetTall(SScale(26))
		itemRow:DockMargin(SScale(10), SScale(10), SScale(10), 0)

		local itemLabel = itemRow:Add("DLabel")
		itemLabel:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		itemLabel:SetText("Item:")
		itemLabel:SetTextColor(COLOR_TEXT)
		itemLabel:Dock(LEFT)
		itemLabel:SetWide(SScale(60))

		self.itemCombo = itemRow:Add("DComboBox")
		self.itemCombo:Dock(FILL)
		self.itemCombo:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		self.itemCombo:SetTextColor(color_white)
		self.itemCombo:SetValue("Seleccionar item...")
		self.itemCombo.Paint = function(_, w, h)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local allItems = ix.encargos.GetAllItems()
		local sorted = {}
		for _, info in pairs(allItems) do
			table.insert(sorted, info)
		end
		table.sort(sorted, function(a, b) return a.name < b.name end)

		for _, info in ipairs(sorted) do
			self.itemCombo:AddChoice(info.name, info.id)
		end

		-- Cantidad
		local qtyRow = self.createPanel:Add("EditablePanel")
		qtyRow:Dock(TOP)
		qtyRow:SetTall(SScale(26))
		qtyRow:DockMargin(SScale(10), SScale(4), SScale(10), 0)

		local qtyLabel = qtyRow:Add("DLabel")
		qtyLabel:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		qtyLabel:SetText("Cantidad:")
		qtyLabel:SetTextColor(COLOR_TEXT)
		qtyLabel:Dock(LEFT)
		qtyLabel:SetWide(SScale(60))

		self.qtyEntry = qtyRow:Add("DTextEntry")
		self.qtyEntry:Dock(FILL)
		self.qtyEntry:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		self.qtyEntry:SetTextColor(color_white)
		self.qtyEntry:SetNumeric(true)
		self.qtyEntry:SetValue("1")
		self.qtyEntry.Paint = function(me, w, h)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			me:DrawTextEntryText(color_white, COLOR_ACCENT, color_white)
		end

		-- Recompensa
		local rewRow = self.createPanel:Add("EditablePanel")
		rewRow:Dock(TOP)
		rewRow:SetTall(SScale(26))
		rewRow:DockMargin(SScale(10), SScale(4), SScale(10), 0)

		local rewLabel = rewRow:Add("DLabel")
		rewLabel:SetFont(PLUGIN_UI:GetFontInternal("CharFields"))
		rewLabel:SetText("Balas:")
		rewLabel:SetTextColor(COLOR_TEXT)
		rewLabel:Dock(LEFT)
		rewLabel:SetWide(SScale(60))

		self.rewEntry = rewRow:Add("DTextEntry")
		self.rewEntry:Dock(FILL)
		self.rewEntry:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		self.rewEntry:SetTextColor(color_white)
		self.rewEntry:SetNumeric(true)
		self.rewEntry:SetValue("50")
		self.rewEntry.Paint = function(me, w, h)
			surface.SetDrawColor(22, 22, 22, 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COLOR_BORDER)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			me:DrawTextEntryText(color_white, COLOR_ACCENT, color_white)
		end

		-- Nota de tasa (la paga quien publica, sobre la recompensa introducida)
		local taxNote = self.createPanel:Add("DLabel")
		taxNote:Dock(TOP)
		taxNote:SetTall(SScale(12))
		taxNote:DockMargin(SScale(70), 0, SScale(10), 0)
		taxNote:SetFont(PLUGIN_UI:GetFontInternal("PostScriptum"))
		taxNote:SetTextColor(COLOR_DIM)

		local taxPct = math.floor(ix.encargos.config.taxRate * 100)
		local function UpdateTaxNote()
			local reward = math.max(math.floor(tonumber(self.rewEntry:GetValue()) or 0), 0)
			local tax = math.floor(reward * ix.encargos.config.taxRate)
			taxNote:SetText(("Pagarás %i RUB en total (%i de recompensa + %i%% de tasa: %i)."):format(reward + tax, reward, taxPct, tax))
		end

		self.rewEntry.OnChange = UpdateTaxNote
		UpdateTaxNote()

		-- Botón publicar
		local pubRow = self.createPanel:Add("EditablePanel")
		pubRow:Dock(TOP)
		pubRow:SetTall(SScale(24))
		pubRow:DockMargin(SScale(10), SScale(4), SScale(10), SScale(8))

		MakeButton(pubRow, "PUBLICAR ENCARGO", COLOR_ACCENT, function()
			local _, itemID = self.itemCombo:GetSelected()
			if (not itemID) then
				LocalPlayer():Notify("Selecciona un item.")
				return
			end

			local qty = tonumber(self.qtyEntry:GetValue()) or 0
			qty = math.max(math.floor(qty), 1)

			local reward = tonumber(self.rewEntry:GetValue()) or 0
			reward = math.floor(reward)

			if (reward < ix.encargos.config.minReward) then
				LocalPlayer():Notify(("La recompensa minima es %i RUB."):format(ix.encargos.config.minReward))
				return
			end

			if (reward > ix.encargos.config.maxReward) then
				LocalPlayer():Notify(("La recompensa maxima es %i RUB."):format(ix.encargos.config.maxReward))
				return
			end

			net.Start(PLUGIN.netCreate)
				net.WriteString(itemID)
				net.WriteUInt(qty, 16)
				net.WriteUInt(reward, 32)
			net.SendToServer()

			self:ToggleCreatePanel()
		end):Dock(FILL)
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
		if (keyCode == KEY_SPACE) then
			self:Remove()
		end
	end

	function PANEL:Remove()
		net.Start(PLUGIN.netClose)
		net.SendToServer()

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

	vgui.Register("metroTablonEncargos", PANEL, "EditablePanel")
end)
