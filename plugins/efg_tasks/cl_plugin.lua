-- ─── Pestaña TAREAS del TAB (como la de EFT) ─────────────────────────────────
-- Arriba los comerciantes con su lealtad (filtran la lista), a la izquierda
-- la lista de tareas con su estado y a la derecha la ficha: retrato del
-- comerciante, descripción, objetivos y recompensas, con los botones de
-- aceptar, entregar objetos, cobrar y abandonar.

local PLUGIN = PLUGIN

PLUGIN.traders = PLUGIN.traders or {}
PLUGIN.tasks = PLUGIN.tasks or {}

net.Receive("ixEFGTasksData", function()
	PLUGIN.traders = net.ReadTable()
	PLUGIN.tasks = net.ReadTable()

	if (IsValid(ix.gui.efgTasks)) then
		ix.gui.efgTasks:Refresh()
	end
end)

function PLUGIN:Request()
	net.Start("ixEFGTasksRequest")
	net.SendToServer()
end

local function action(name, missionID)
	net.Start("ixEFGTasksAction")
		net.WriteString(name)
		net.WriteString(missionID or "")
	net.SendToServer()
end

-- LL1-3 con barras y LL4 con la corona, como en EFT
local loyaltyIcons = {"loyalty_one", "loyalty_two", "loyalty_three", "loyalty_king_new"}

local function uiMat(name)
	return ix.efgui.Mat("efg/ui/" .. name .. ".png", "smooth")
end

local function traderMat(key)
	return ix.efgui.Mat("efgui/traders/" .. key .. ".png", "smooth mips")
end

local function traderName(key)
	return ix.traders and ix.traders.names and ix.traders.names[key] or key
end

PLUGIN.status = {
	available = {"DISPONIBLE", "accent"},
	active    = {"EN CURSO", "yellow"},
	ready     = {"LISTA PARA ENTREGAR", "green"},
	done      = {"COMPLETADA", "textDim"},
	cooldown  = {"EN ESPERA", "textDim"},
	locked    = {"BLOQUEADA", "red"},
}

local statusOrder = {ready = 1, active = 2, available = 3, locked = 4, cooldown = 5, done = 6}

local function drawLoyalty(ll, x, y, h)
	local mat = uiMat(loyaltyIcons[math.Clamp(ll or 1, 1, 4)])
	if (!mat) then return end

	local w = h * mat:Width() / math.max(mat:Height(), 1)
	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(x - w, y, w, h)
end

-- retrato con el fondo a rayas de EFT y el marco del comerciante
local function drawPortrait(key, x, y, size, selected, hovered)
	local UI = ix.efgui
	local c = UI.color

	surface.SetDrawColor(18, 20, 20, 255)
	surface.DrawRect(x, y, size, size)

	local stripes = uiMat("image_diagonal_trader")
	if (stripes) then
		surface.SetMaterial(stripes)
		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawTexturedRectUV(x, y, size, size, 0, 0, size / 64, size / 64)
	end

	local mat = traderMat(key)
	if (mat) then
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(x + 2, y + 2, size - 4, size - 4)
	end

	surface.SetDrawColor(selected and c.accent or (hovered and c.lineHi or c.line))
	surface.DrawOutlinedRect(x, y, size, size, selected and 2 or 1)
end

local function money(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return s .. " ₽"
end

local PANEL = {}

function PANEL:Init()
	ix.gui.efgTasks = self

	self.filterTrader = nil
	self.filterStatus = "all"
	self.selected = nil

	PLUGIN:Request()
	self:Refresh()
end

function PANEL:OnRemove()
	if (ix.gui.efgTasks == self) then ix.gui.efgTasks = nil end
end

function PANEL:Paint(w, h)
	local c = ix.efgui.color

	surface.SetDrawColor(10, 12, 12, 200)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:PerformLayout(w, h)
	if (self.laidOutW == w and self.laidOutH == h) then return end
	self.laidOutW, self.laidOutH = w, h
	self:Refresh()
end

function PANEL:Visible()
	local list = {}

	for _, task in ipairs(PLUGIN.tasks) do
		if (self.filterTrader and task.trader != self.filterTrader) then continue end

		local st = task.status
		if (self.filterStatus == "active" and st != "active" and st != "ready") then continue end
		if (self.filterStatus == "available" and st != "available") then continue end
		if (self.filterStatus == "done" and st != "done" and st != "cooldown") then continue end

		list[#list + 1] = task
	end

	table.sort(list, function(a, b)
		local oa, ob = statusOrder[a.status] or 9, statusOrder[b.status] or 9
		if (oa != ob) then return oa < ob end
		if (a.trader != b.trader) then return a.trader < b.trader end
		return tostring(a.name) < tostring(b.name)
	end)

	return list
end

function PANEL:Refresh()
	self:Clear()

	local w, h = self:GetSize()
	if (w < 50 or h < 50) then return end

	local UI = ix.efgui
	local S = UI.Scale
	local c = UI.color

	-- ── fila de comerciantes ──────────────────────────────────────────
	local stripH = S(118)
	local strip = self:Add("DPanel")
	strip:SetPos(0, 0)
	strip:SetSize(w, stripH)
	strip.Paint = function(_, pw, ph)
		surface.SetDrawColor(14, 16, 16, 235)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(c.line)
		surface.DrawRect(0, ph - 1, pw, 1)
	end

	local entries = {{key = nil}}
	for _, t in ipairs(PLUGIN.traders) do entries[#entries + 1] = t end

	local cardW, gap = S(92), S(8)
	local x = (w - (#entries * (cardW + gap) - gap)) / 2

	for _, t in ipairs(entries) do
		local key = t.key
		local b = strip:Add("DButton")
		b:SetText("")
		b:SetPos(x, S(8))
		b:SetSize(cardW, stripH - S(16))
		b.Paint = function(this, bw, bh)
			local sel = self.filterTrader == key
			local size = math.min(bw, bh - S(20))
			local px = (bw - size) / 2

			if (key) then
				drawPortrait(key, px, 0, size, sel, this:IsHovered())
				drawLoyalty(t.ll, px + size - S(3), size - S(19), S(16))

				-- tareas listas para cobrar con este comerciante
				for _, task in ipairs(PLUGIN.tasks) do
					if (task.trader == key and task.status == "ready") then
						local alert = uiMat("dialog_icons_askforquest")
						if (alert) then
							surface.SetMaterial(alert)
							surface.SetDrawColor(255, 255, 255)
							surface.DrawTexturedRect(px + S(3), S(3), S(20), S(20))
						end
						break
					end
				end
			else
				surface.SetDrawColor(18, 20, 20, 255)
				surface.DrawRect(px, 0, size, size)
				surface.SetDrawColor(sel and c.accent or (this:IsHovered() and c.lineHi or c.line))
				surface.DrawOutlinedRect(px, 0, size, size, sel and 2 or 1)
				draw.SimpleText("TODOS", "efgx.Header", bw / 2, size / 2, sel and c.accent or c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(key and string.upper(traderName(key)) or "COMERCIANTES", "efgx.Label", bw / 2, bh - S(2),
				sel and c.accent or c.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self.filterTrader = key
			self.selected = nil
			self:Refresh()
		end

		x = x + cardW + gap
	end

	-- ── lista ─────────────────────────────────────────────────────────
	local top = stripH + S(10)
	local listW = math.floor(w * 0.44)
	local listH = h - top

	local list = self:Add("DPanel")
	list:SetPos(0, top)
	list:SetSize(listW, listH)
	list.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
	end

	-- filtros por estado
	local filters = {{"all", "TODAS"}, {"active", "EN CURSO"}, {"available", "DISPONIBLES"}, {"done", "COMPLETADAS"}}
	local fw = (listW - S(16) - S(4) * (#filters - 1)) / #filters

	for i, f in ipairs(filters) do
		local b = list:Add("DButton")
		b:SetPos(S(8) + (i - 1) * (fw + S(4)), S(8))
		b:SetSize(fw, S(28))
		b:SetText(f[2])
		UI.StyleButton(b, "efgx.Small")
		b.efgActive = self.filterStatus == f[1]
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self.filterStatus = f[1]
			self.selected = nil
			self:Refresh()
		end
	end

	local colTrader, colName = S(10), S(62)
	local colType, colStatus = listW - S(250), listW - S(10)
	local headY = S(44)

	local head = list:Add("DPanel")
	head:SetPos(0, headY)
	head:SetSize(listW, S(24))
	head.Paint = function(_, pw, ph)
		surface.SetDrawColor(c.bg2)
		surface.DrawRect(0, 0, pw, ph)
		draw.SimpleText("COMERCIANTE", "efgx.Label", colTrader, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("TAREA", "efgx.Label", colName + S(10), ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("TIPO", "efgx.Label", colType, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ESTADO", "efgx.Label", colStatus, ph / 2, c.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local scroll = list:Add("DScrollPanel")
	scroll:SetPos(0, headY + S(26))
	scroll:SetSize(listW, listH - headY - S(26) - S(4))

	local visible = self:Visible()

	if (!self.selected and visible[1]) then
		self.selected = visible[1].id
	end

	local selectedTask
	for _, task in ipairs(PLUGIN.tasks) do
		if (task.id == self.selected) then selectedTask = task end
	end

	if (#visible == 0) then
		local empty = scroll:Add("DLabel")
		empty:Dock(TOP)
		empty:DockMargin(S(12), S(14), S(12), 0)
		empty:SetFont("efgx.Body")
		empty:SetTextColor(c.textDim)
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
		empty:SetText(#PLUGIN.tasks == 0
			and "No hay tareas. Los comerciantes aún no tienen encargos (un admin los crea con /MisionAdmin)."
			or "No hay tareas con este filtro.")
	end

	for _, task in ipairs(visible) do
		local row = scroll:Add("DButton")
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(S(46))
		row:DockMargin(0, 0, 0, 1)
		row.Paint = function(this, pw, ph)
			local sel = self.selected == task.id
			surface.SetDrawColor(sel and Color(46, 44, 36, 245) or (this:IsHovered() and Color(30, 32, 32, 245) or Color(20, 22, 22, 235)))
			surface.DrawRect(0, 0, pw, ph)

			if (sel) then
				surface.SetDrawColor(c.accent)
				surface.DrawRect(0, 0, S(3), ph)
			end

			drawPortrait(task.trader, colTrader, S(4), ph - S(8), false, false)

			local st = PLUGIN.status[task.status] or PLUGIN.status.available
			local nameCol = (task.status == "done" or task.status == "cooldown") and c.textDim or c.text

			draw.SimpleText(task.name, "efgx.Header", colName + S(10), ph / 2 - S(1), nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(string.upper(traderName(task.trader)), "efgx.Label", colName + S(10), ph / 2 + S(2), c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local kind = task.daily and "DIARIA" or (task.repeatMode == "once" and "HISTORIA" or "REPETIBLE")
			draw.SimpleText(kind, "efgx.Small", colType, ph / 2, task.daily and c.info or c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(st[1], "efgx.Small", colStatus, ph / 2, c[st[2]] or c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			if (task.status == "done") then
				local mark = uiMat("checkmark")
				if (mark) then
					surface.SetMaterial(mark)
					surface.SetDrawColor(c.textDim)
					surface.DrawTexturedRect(colType - S(24), ph / 2 - S(6), S(14), S(12))
				end
			end
		end
		row.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self.selected = task.id
			self:Refresh()
		end
	end

	-- ── ficha ─────────────────────────────────────────────────────────
	local dx = listW + S(10)
	local detail = self:Add("DPanel")
	detail:SetPos(dx, top)
	detail:SetSize(w - dx, listH)
	detail.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)
	end

	if (selectedTask) then
		self:BuildDetail(detail, selectedTask)
	else
		local l = detail:Add("DLabel")
		l:SetPos(S(20), S(20))
		l:SetFont("efgx.Body")
		l:SetTextColor(c.textDim)
		l:SetText("Elige una tarea de la lista.")
		l:SizeToContents()
	end
end

function PANEL:BuildDetail(detail, task)
	local UI = ix.efgui
	local S = UI.Scale
	local c = UI.color
	local dw, dh = detail:GetSize()

	local trader
	for _, t in ipairs(PLUGIN.traders) do
		if (t.key == task.trader) then trader = t end
	end

	local st = PLUGIN.status[task.status] or PLUGIN.status.available

	-- cabecera: retrato grande, nombre de la tarea y del comerciante
	local portrait = S(150)
	local header = detail:Add("DPanel")
	header:SetPos(S(14), S(14))
	header:SetSize(dw - S(28), portrait)
	header.Paint = function(_, pw, ph)
		drawPortrait(task.trader, 0, 0, portrait, false, false)

		if (trader) then
			drawLoyalty(trader.ll, portrait - S(4), portrait - S(22), S(18))
		end

		local tx = portrait + S(18)
		draw.SimpleText(string.upper(task.name), "efgx.Title", tx, S(4), c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.upper(traderName(task.trader)), "efgx.Header", tx, S(38), c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (trader) then
			draw.SimpleText(("LEALTAD %d  ·  REPUTACIÓN %d"):format(trader.ll, trader.rep), "efgx.Small", tx, S(62), c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		surface.SetFont("efgx.Header")
		local sw = surface.GetTextSize(st[1]) + S(20)
		local col = c[st[2]] or c.text
		surface.SetDrawColor(col.r, col.g, col.b, 40)
		surface.DrawRect(tx, ph - S(34), sw, S(28))
		surface.SetDrawColor(col)
		surface.DrawOutlinedRect(tx, ph - S(34), sw, S(28))
		draw.SimpleText(st[1], "efgx.Header", tx + sw / 2, ph - S(20), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (task.reason and task.status != "available") then
			local warn = uiMat("trader_red_warning")
			local rx = tx + sw + S(12)

			if (warn and task.status == "locked") then
				surface.SetMaterial(warn)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(rx, ph - S(31), S(24), S(21))
				rx = rx + S(30)
			end

			draw.SimpleText(task.reason, "efgx.Small", rx, ph - S(20), task.status == "locked" and c.red or c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local buttonsH = S(56)
	local scroll = detail:Add("DScrollPanel")
	scroll:SetPos(S(14), S(14) + portrait + S(12))
	scroll:SetSize(dw - S(28), dh - portrait - S(38) - buttonsH)

	local function section(title)
		local p = scroll:Add("DPanel")
		p:Dock(TOP)
		p:DockMargin(0, S(10), 0, S(6))
		p:SetTall(S(26))
		p.Paint = function(_, pw, ph)
			surface.SetDrawColor(c.bg2)
			surface.DrawRect(0, 0, pw, ph)
			surface.SetDrawColor(c.accent)
			surface.DrawRect(0, 0, S(3), ph)
			draw.SimpleText(title, "efgx.Header", S(12), ph / 2, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- descripción
	section("DESCRIPCIÓN")
	local desc = scroll:Add("DLabel")
	desc:Dock(TOP)
	desc:DockMargin(S(12), 0, S(12), 0)
	desc:SetFont("efgx.Body")
	desc:SetTextColor(c.text2)
	desc:SetWrap(true)
	desc:SetAutoStretchVertical(true)
	desc:SetText(task.description != "" and task.description or "El comerciante no ha dado más detalles.")

	-- objetivos
	section("OBJETIVOS")
	for _, step in ipairs(task.steps) do
		local row = scroll:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(S(12), 0, S(12), S(4))

		local lbl = row:Add("DLabel")
		lbl:SetFont("efgx.Body")
		lbl:SetWrap(true)
		lbl:SetAutoStretchVertical(true)
		lbl:SetTextColor(step.done and c.textDim or (step.current and c.text or c.text2))
		lbl:SetText(step.text .. ((step.current and step.objective != step.text) and ("\n" .. step.objective) or ""))

		row.PerformLayout = function(this, pw)
			lbl:SetPos(S(30), S(4))
			lbl:SetWide(pw - S(30) - (step.current and S(70) or 0))
		end
		-- la etiqueta crece al ajustar el texto: la fila la sigue
		row.Think = function(this)
			local want = math.max(S(30), lbl:GetTall() + S(8))
			if (this:GetTall() != want) then this:SetTall(want) end
		end
		row.Paint = function(_, pw, ph)
			if (step.current) then
				surface.SetDrawColor(232, 197, 71, 14)
				surface.DrawRect(0, 0, pw, ph)
			end

			local box = uiMat("checkbox")
			if (box) then
				surface.SetMaterial(box)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(S(4), S(6), S(20), S(21))
			end

			if (step.done) then
				local mark = uiMat("checkmark")
				if (mark) then
					surface.SetMaterial(mark)
					surface.SetDrawColor(c.green)
					surface.DrawTexturedRect(S(7), S(10), S(14), S(12))
				end
			end

			if (step.current and (step.percent or 0) > 0) then
				draw.SimpleText(step.percent .. "%", "efgx.Num", pw - S(8), S(16), c.yellow, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	-- recompensas (si hay varias opciones se elige al cobrar)
	section(#task.rewards > 1 and "RECOMPENSAS (ELIGES UNA AL ENTREGAR)" or "RECOMPENSAS")

	if (#task.rewards == 0) then
		local none = scroll:Add("DLabel")
		none:Dock(TOP)
		none:DockMargin(S(12), 0, 0, 0)
		none:SetFont("efgx.Body")
		none:SetTextColor(c.textDim)
		none:SetText("Sin recompensa.")
	end

	for i, reward in ipairs(task.rewards) do
		local cells = {}
		local xp = math.floor((reward.balas or 0) / 20) + (reward.rep or 0) * 20

		if ((reward.balas or 0) > 0) then cells[#cells + 1] = {text = money(reward.balas), sub = "RUBLOS"} end
		if (xp > 0) then cells[#cells + 1] = {text = "+" .. xp, sub = "EXPERIENCIA"} end
		if ((reward.rep or 0) > 0) then cells[#cells + 1] = {text = "+" .. reward.rep, sub = "REPUTACIÓN", loyalty = true} end

		for _, entry in ipairs(reward.items or {}) do
			local item = ix.item.list[entry.id]
			if (item) then cells[#cells + 1] = {item = item, qty = entry.qty or 1} end
		end

		local row = scroll:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(S(12), 0, S(12), S(6))
		row:SetTall(S(76))
		row.Paint = function(_, pw, ph)
			local x = 0

			if (#task.rewards > 1) then
				draw.SimpleText(i, "efgx.Title", S(10), ph / 2, c.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				x = S(26)
			end

			local cw = S(118)
			for _, cell in ipairs(cells) do
				surface.SetDrawColor(c.cell)
				surface.DrawRect(x, 0, cw, ph)
				surface.SetDrawColor(c.line)
				surface.DrawOutlinedRect(x, 0, cw, ph)

				if (cell.item) then
					if (!ix.efg.icons.Draw(cell.item, x + S(8), S(6), cw - S(16), ph - S(26))) then
						draw.SimpleText(cell.item.name or "?", "efgx.Small", x + cw / 2, ph / 2 - S(8), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end

					draw.SimpleText(cell.item.name or "", "efgx.Label", x + S(6), ph - S(4), c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					if (cell.qty > 1) then
						draw.SimpleText("x" .. cell.qty, "efgx.Num", x + cw - S(6), S(4), c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
					end
				else
					if (cell.loyalty and trader) then
						drawLoyalty(trader.ll, x + cw - S(6), S(6), S(14))
					end

					draw.SimpleText(cell.text, "efgx.Header", x + cw / 2, ph / 2 - S(6), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(cell.sub, "efgx.Label", x + cw / 2, ph - S(6), c.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end

				x = x + cw + S(4)
			end
		end
	end

	-- botones
	local bar = detail:Add("DPanel")
	bar:SetPos(0, dh - buttonsH)
	bar:SetSize(dw, buttonsH)
	bar.Paint = function(_, pw, ph)
		surface.SetDrawColor(c.line)
		surface.DrawRect(S(14), 0, pw - S(28), 1)
	end

	local buttons = {}
	local inRaid = LocalPlayer().InRaid and LocalPlayer():InRaid()

	if (task.status == "available") then
		buttons[#buttons + 1] = {"ACEPTAR", "accept", true}
	elseif (task.status == "ready") then
		buttons[#buttons + 1] = {"COMPLETAR", "turnin", true}
	elseif (task.status == "active") then
		for _, step in ipairs(task.steps) do
			if (step.current and step.deliver) then
				buttons[#buttons + 1] = {"ENTREGAR OBJETOS", "deliver", true}
			end
		end
	end

	if (task.status == "active" or task.status == "ready") then
		buttons[#buttons + 1] = {"ABANDONAR", "abandon"}
	end

	local bx = dw - S(14)
	for i = #buttons, 1, -1 do
		local def = buttons[i]
		local b = bar:Add("DButton")
		b:SetSize(S(200), buttonsH - S(18))
		bx = bx - S(200)
		b:SetPos(bx, S(10))
		bx = bx - S(8)
		b:SetText(def[1])
		UI.StyleButton(b, "efgx.Header", def[3] and "primary" or nil)
		b:SetEnabled(!inRaid)
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")

			if (def[2] == "abandon") then
				Derma_Query("Se perderá el progreso de la tarea.", "Abandonar tarea", "Abandonar", function()
					action("abandon", task.id)
				end, "Cancelar")
				return
			end

			action(def[2], task.id)
		end
	end

	if (inRaid) then
		local l = bar:Add("DLabel")
		l:SetPos(S(14), S(10))
		l:SetSize(dw - S(28) - S(420), buttonsH - S(18))
		l:SetFont("efgx.Small")
		l:SetTextColor(c.red)
		l:SetText("Durante la raid solo puedes consultar tus tareas.")
	end
end

vgui.Register("efgxTasks", PANEL, "DPanel")
