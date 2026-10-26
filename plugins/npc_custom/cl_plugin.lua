if (not CLIENT) then return end

-- ── Polyfill SetBounds ───────────────────────────────────────────────────────
local _PNL = FindMetaTable("Panel")
if (_PNL and not _PNL.SetBounds) then
	_PNL.SetBounds = function(self, x, y, w, h)
		self:SetPos(x, y); self:SetSize(w, h); return self
	end
end

-- ── Texturas MetroUI ─────────────────────────────────────────────────────────
local textures = {
	menu3 = ix.util.GetMaterial("efgui/spawnmenu/Menu/3.jpg"),
	menu2 = ix.util.GetMaterial("efgui/spawnmenu/Menu/2.png"),
	menu1 = ix.util.GetMaterial("efgui/spawnmenu/Menu/1.png"),
	card  = ix.util.GetMaterial("efgui/mainmenu_card.png", "noclamp smooth"),
}

-- ── Fuentes ──────────────────────────────────────────────────────────────────
local function registerFonts()
	surface.CreateFont("NPC_UI.Button", {
		font = "Bender", extended = false,
		size = SScale(10), weight = 500, antialias = true,
	})
	surface.CreateFont("NPC_UI.Fields", {
		font = "Bender", extended = false,
		size = SScale(8), weight = 500, antialias = true,
	})
	surface.CreateFont("NPC_UI.Small", {
		font = "Bender", extended = false,
		size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "npc_custom.Fonts", registerFonts)

-- ── Constantes ───────────────────────────────────────────────────────────────
local PAD = 8
local NPC_COLOR = Color(220, 180, 100)

-- ── Helpers de dibujo ────────────────────────────────────────────────────────
local function paintDarkEntry(self, w, h)
	ix.util.DrawBlur(self, 3)
	surface.SetDrawColor(44, 44, 44, 220)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(88, 88, 88, 160)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	self:DrawTextEntryText(Color(220, 220, 220), Color(112, 128, 130, 180), Color(220, 220, 220))
end

local function makeMetroBtn(parent, text, r, g, b, cb)
	local btn = parent:Add("DButton")
	btn:SetText(text)
	btn:SetFont("NPC_UI.Fields")
	btn:SetTextColor(Color(math.min(r + 120, 255), math.min(g + 120, 255), math.min(b + 120, 255)))
	btn.Paint = function(s, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 22 or 11)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 66 or 22)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end
	btn.DoClick = cb or function() end
	return btn
end

-- ============================================================
--  Diálogo del NPC (typewriter + opciones)
-- ============================================================

ix.npcs._dialogueFrame = nil
ix.npcs._dialogueBotFrame = nil

net.Receive("npc_OpenDialogue", function()
	local npcEnt       = net.ReadEntity()
	local npcName      = net.ReadString()
	local dialoguesJSON = net.ReadString()

	if (not IsValid(npcEnt)) then return end

	local dialogues = util.JSONToTable(dialoguesJSON)
	if (not dialogues or not dialogues.root) then return end

	if (IsValid(ix.npcs._dialogueFrame))    then ix.npcs._dialogueFrame:Remove() end
	if (IsValid(ix.npcs._dialogueBotFrame)) then ix.npcs._dialogueBotFrame:Remove() end

	local fc     = NPC_COLOR
	local sw, sh = ScrW(), ScrH()

	local W        = SScale(300)
	local HEADER_H = SScale(28)
	local SPEECH_H = SScale(62)
	local SEP_H    = SScale(1)
	local OPT_ROW  = SScale(18)
	local OPTS_Y   = HEADER_H + SPEECH_H + SScale(8)
	local H        = OPTS_Y + OPT_ROW * 3 + SScale(10)
	local OPTS_H   = H - OPTS_Y - SScale(6)

	local typeTarget = ""
	local typeStart  = 0
	local typeDone   = false
	local typeShown  = ""
	local CHARS_SEC  = 40
	local speechLbl  = nil

	local frameTop, frameBot
	local _closing = false
	local function closeAll()
		if (_closing) then return end
		_closing = true
		if (IsValid(frameTop)) then frameTop:Remove() end
		if (IsValid(frameBot)) then frameBot:Remove() end
	end

	-- ── Frame superior: nombre del NPC ───────────────────────────────────────
	frameTop = vgui.Create("EditablePanel")
	frameTop:SetSize(W, HEADER_H)
	frameTop:SetPos(sw / 2 - W / 2, 0)
	frameTop:SetAlpha(0); frameTop:AlphaTo(255, 0.25); frameTop:MakePopup()
	ix.npcs._dialogueFrame = frameTop

	frameTop.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 66)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local lblName = frameTop:Add("DLabel")
	lblName:SetPos(PAD, SScale(4))
	lblName:SetSize(W - PAD * 2, SScale(18))
	lblName:SetText(npcName)
	lblName:SetFont("NPC_UI.Button")
	lblName:SetTextColor(Color(225, 225, 225))

	-- ── Frame inferior: conversación y opciones ──────────────────────────────
	local BOT_SPEECH_H = SPEECH_H
	local BOT_OPTS_H   = OPT_ROW * 3 + SScale(6)
	local BOT_H        = BOT_SPEECH_H + SScale(8) + BOT_OPTS_H + SScale(10)

	frameBot = vgui.Create("EditablePanel")
	frameBot:SetSize(W, BOT_H)
	frameBot:SetPos(sw / 2 - W / 2, sh - BOT_H - SScale(6))
	frameBot:SetAlpha(0); frameBot:AlphaTo(255, 0.25); frameBot:MakePopup()
	ix.npcs._dialogueBotFrame = frameBot

	frameBot.OnKeyCodePressed = function(self, key)
		if (key == KEY_ESCAPE) then
			closeAll()
			gui.HideGameUI()
		end
	end

	frameBot.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(fc.r, fc.g, fc.b, 70)
		surface.DrawRect(PAD, BOT_SPEECH_H + SScale(3), w - PAD * 2, SEP_H)
		surface.SetDrawColor(66, 66, 66, 66)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	-- ── Área de texto del NPC con efecto typewriter ──────────────────────────
	local speechArea = frameBot:Add("DPanel")
	speechArea:SetPos(PAD, SScale(4))
	speechArea:SetSize(W - PAD * 2, BOT_SPEECH_H - SScale(8))
	speechArea:SetCursor("hand")

	speechArea.Paint = function(self, w, h)
		surface.SetDrawColor(18, 18, 18, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 45)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if (not typeDone) then
			draw.SimpleText("clic para saltar >", "NPC_UI.Small",
				w - SScale(5), h - SScale(5),
				Color(70, 70, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	speechArea.OnMousePressed = function()
		typeDone  = true
		typeShown = typeTarget
		if (IsValid(speechLbl)) then speechLbl:SetText(typeTarget) end
	end

	speechLbl = speechArea:Add("DLabel")
	speechLbl:SetPos(SScale(7), SScale(7))
	speechLbl:SetSize(speechArea:GetWide() - SScale(14), speechArea:GetTall() - SScale(14))
	speechLbl:SetFont("NPC_UI.Fields")
	speechLbl:SetTextColor(Color(185, 185, 185))
	speechLbl:SetWrap(true)
	speechLbl:SetText("")

	speechLbl.Think = function(self)
		if (typeDone) then return end
		local n   = math.min(math.floor((CurTime() - typeStart) * CHARS_SEC), #typeTarget)
		local cur = string.sub(typeTarget, 1, n)
		if (cur != typeShown) then
			typeShown = cur
			self:SetText(cur)
		end
		if (n >= #typeTarget) then typeDone = true end
	end

	-- ── Lista de opciones de respuesta ───────────────────────────────────────
	local optScroll = frameBot:Add("DScrollPanel")
	optScroll:SetPos(PAD, BOT_SPEECH_H + SScale(8))
	optScroll:SetSize(W - PAD * 2, BOT_OPTS_H)

	local vbar = optScroll:GetVBar()
	vbar:SetWide(SScale(3))
	vbar.Paint         = function(_, w, h) surface.SetDrawColor(33, 33, 33, 200); surface.DrawRect(0, 0, w, h) end
	vbar.btnUp.Paint   = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 200); surface.DrawRect(0, 0, w, h) end

	local optRows = {}

	local function showPage(pageKey)
		local page = dialogues[pageKey]
		if (not page) then return end

		typeTarget = page.text or ""
		typeStart  = CurTime()
		typeDone   = false
		typeShown  = ""
		if (IsValid(speechLbl)) then speechLbl:SetText("") end

		for _, r in ipairs(optRows) do if (IsValid(r)) then r:Remove() end end
		optRows = {}

		local options = page.options or {}

		for _, opt in ipairs(options) do
			local row      = optScroll:Add("DPanel")
			local optLabel = opt.label or ""
			local optAct   = opt.action
			local optNext  = opt.nextPage

			row:Dock(TOP)
			row:DockMargin(0, 0, 0, SScale(2))
			row:SetTall(OPT_ROW)
			row:SetCursor("hand")
			row:SetMouseInputEnabled(true)

			row.Paint = function(me, w, h)
				if (me:IsHovered()) then
					surface.SetDrawColor(fc.r, fc.g, fc.b, 18)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(fc.r, fc.g, fc.b, 130)
					surface.DrawRect(0, 0, SScale(2), h)
				end
				local col = me:IsHovered()
					and Color(math.min(fc.r + 80, 255), math.min(fc.g + 80, 255), math.min(fc.b + 80, 255))
					or  Color(165, 165, 165)
				local prefix = me:IsHovered() and "> " or "  "
				draw.SimpleText(prefix .. optLabel, "NPC_UI.Fields",
					SScale(10), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			row.OnMousePressed = function()
				if (optAct == "close") then
					closeAll()
				elseif (optAct == "admin") then
					closeAll()
					net.Start("npc_AdminOpen")
						net.WriteEntity(npcEnt)
					net.SendToServer()
				elseif (optNext) then
					showPage(optNext)
				end
			end

			table.insert(optRows, row)
		end
	end

	-- Inyectar opción de admin si el jugador es administrador
	if (LocalPlayer():IsAdmin()) then
		if (not dialogues.root.options) then dialogues.root.options = {} end
		table.insert(dialogues.root.options, {
			label = "[ADMIN] Configurar NPC", action = "admin"
		})
	end

	showPage("root")
end)

-- ============================================================
--  Panel de Administración del NPC
-- ============================================================

ix.npcs._adminFrame = nil

net.Receive("npc_AdminOpen", function()
	local npcEnt       = net.ReadEntity()
	local npcName      = net.ReadString()
	local npcDesc      = net.ReadString()
	local npcModel     = net.ReadString()
	local npcAnim      = net.ReadString()
	local bgCount      = net.ReadUInt(8)
	local recvBodygroups = {}
	for i = 1, bgCount do
		local id  = net.ReadUInt(8)
		local val = net.ReadUInt(8)
		recvBodygroups[id] = val
	end
	local dialoguesJSON = net.ReadString()
	local recvDialogues = util.JSONToTable(dialoguesJSON) or {
		root = {text = "Hola, viajero.", options = {{label = "Adiós.", action = "close"}}}
	}

	if (not IsValid(npcEnt)) then return end
	if (IsValid(ix.npcs._adminFrame)) then ix.npcs._adminFrame:Remove() end

	local fc     = NPC_COLOR
	local sw, sh = ScrW(), ScrH()

	local workName       = npcName
	local workDesc       = npcDesc
	local selectedModel  = npcModel
	local selectedAnim   = npcAnim
	local selectedBodygroups = table.Copy(recvBodygroups)
	local workDialogues  = table.Copy(recvDialogues)
	local selectedPageKey = "root"

	local SP   = SScale(8)
	local SG   = SScale(5)
	local SBTN = SScale(14)

	local W = math.min(SScale(720), sw - SScale(40))
	local H = math.min(SScale(500), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H)
	frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:ShowCloseButton(false)
	frame:MakePopup()
	frame:SetDeleteOnClose(true)
	frame.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(33, 33, 33, 230)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, 3)
		surface.SetDrawColor(66, 66, 66, 88)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end
	ix.npcs._adminFrame = frame

	frame.OnRemove = function()
		if (ix.npcs._adminFrame == frame) then ix.npcs._adminFrame = nil end
		if (IsValid(ix.npcs._adminAppModal)) then ix.npcs._adminAppModal:Remove() end
		ix.npcs._adminAppModal = nil
	end

	-- ── Título ───────────────────────────────────────────────────────────────
	local lblTitle = frame:Add("DLabel")
	lblTitle:SetPos(SP, SP)
	lblTitle:SetSize(W - SScale(40), SScale(20))
	lblTitle:SetText("Admin — NPC")
	lblTitle:SetFont("NPC_UI.Button")
	lblTitle:SetTextColor(Color(220, 220, 220))

	local sep = frame:Add("DPanel")
	sep:SetPos(SP, SScale(30))
	sep:SetSize(W - SP * 2, 1)
	sep.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 88); surface.DrawRect(0, 0, w, h) end

	-- ── Nombre ───────────────────────────────────────────────────────────────
	local lblName = frame:Add("DLabel")
	lblName:SetPos(SP, SScale(36))
	lblName:SetSize(SScale(80), SScale(10))
	lblName:SetText("Nombre:")
	lblName:SetFont("NPC_UI.Fields")
	lblName:SetTextColor(Color(160, 160, 160))

	local nameEntry = frame:Add("DTextEntry")
	nameEntry:SetPos(SP + SScale(84), SScale(34))
	nameEntry:SetSize(W - SP * 2 - SScale(84), SScale(18))
	nameEntry:SetFont("NPC_UI.Fields")
	nameEntry:SetPlaceholderText("Nombre del NPC")
	nameEntry:SetText(workName)
	nameEntry.Paint = paintDarkEntry

	-- ── Descripción ──────────────────────────────────────────────────────────
	local lblDesc = frame:Add("DLabel")
	lblDesc:SetPos(SP, SScale(58))
	lblDesc:SetSize(SScale(80), SScale(10))
	lblDesc:SetText("Descripción:")
	lblDesc:SetFont("NPC_UI.Fields")
	lblDesc:SetTextColor(Color(160, 160, 160))

	local descEntry = frame:Add("DTextEntry")
	descEntry:SetPos(SP + SScale(84), SScale(56))
	descEntry:SetSize(W - SP * 2 - SScale(84), SScale(18))
	descEntry:SetFont("NPC_UI.Fields")
	descEntry:SetPlaceholderText("Descripción visible al acercarse")
	descEntry:SetText(workDesc)
	descEntry.Paint = paintDarkEntry

	-- ── Editor de diálogos ───────────────────────────────────────────────────
	local DIAL_Y   = SScale(82)
	local DIAL_H   = H - DIAL_Y - SG - SBTN - SP
	local PAGE_W   = SScale(160)
	local EDIT_X   = SP + PAGE_W + SG
	local EDIT_W   = W - SP * 2 - PAGE_W - SG

	local lblDialTitle = frame:Add("DLabel")
	lblDialTitle:SetPos(SP, DIAL_Y - SScale(12))
	lblDialTitle:SetSize(W - SP * 2, SScale(10))
	lblDialTitle:SetText("Editor de diálogos:")
	lblDialTitle:SetFont("NPC_UI.Small")
	lblDialTitle:SetTextColor(Color(160, 160, 160))

	-- ── Lista de páginas (izquierda) ─────────────────────────────────────────
	local pageScroll = frame:Add("DScrollPanel")
	pageScroll:SetPos(SP, DIAL_Y)
	pageScroll:SetSize(PAGE_W, DIAL_H)
	pageScroll:GetVBar():SetWide(SScale(4))
	pageScroll.Paint = function(self, w, h)
		surface.SetDrawColor(22, 22, 22, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 44)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	-- ── Panel de edición de página (derecha) ─────────────────────────────────
	local editPanel = frame:Add("DPanel")
	editPanel:SetPos(EDIT_X, DIAL_Y)
	editPanel:SetSize(EDIT_W, DIAL_H)
	editPanel.Paint = function(self, w, h)
		surface.SetDrawColor(22, 22, 22, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 44)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local refreshPages, refreshPageEditor

	-- ── Refresco del editor de página seleccionada ───────────────────────────
	refreshPageEditor = function()
		editPanel:Clear()

		local page = workDialogues[selectedPageKey]
		if (not page) then
			local lbl = editPanel:Add("DLabel")
			lbl:Dock(FILL)
			lbl:SetText("Selecciona una página.")
			lbl:SetFont("NPC_UI.Fields")
			lbl:SetTextColor(Color(120, 120, 120))
			lbl:SetContentAlignment(5)
			return
		end

		local eSP = SScale(6)

		-- ID de la página
		local lblPageID = editPanel:Add("DLabel")
		lblPageID:SetPos(eSP, eSP)
		lblPageID:SetSize(EDIT_W - eSP * 2, SScale(10))
		lblPageID:SetText("Página: " .. selectedPageKey)
		lblPageID:SetFont("NPC_UI.Button")
		lblPageID:SetTextColor(Color(200, 180, 100))

		-- Texto del NPC
		local lblText = editPanel:Add("DLabel")
		lblText:SetPos(eSP, SScale(22))
		lblText:SetSize(SScale(80), SScale(10))
		lblText:SetText("Texto NPC:")
		lblText:SetFont("NPC_UI.Small")
		lblText:SetTextColor(Color(150, 150, 150))

		local textEntry = editPanel:Add("DTextEntry")
		textEntry:SetPos(eSP, SScale(34))
		textEntry:SetSize(EDIT_W - eSP * 2, SScale(36))
		textEntry:SetFont("NPC_UI.Fields")
		textEntry:SetText(page.text or "")
		textEntry:SetMultiline(true)
		textEntry.Paint = paintDarkEntry
		textEntry.OnChange = function(self)
			page.text = self:GetValue()
		end

		-- Opciones
		local lblOpts = editPanel:Add("DLabel")
		lblOpts:SetPos(eSP, SScale(76))
		lblOpts:SetSize(SScale(100), SScale(10))
		lblOpts:SetText("Opciones de respuesta:")
		lblOpts:SetFont("NPC_UI.Small")
		lblOpts:SetTextColor(Color(150, 150, 150))

		local OPT_LIST_Y = SScale(88)
		local OPT_BTN_H  = SScale(14)
		local OPT_LIST_H = DIAL_H - OPT_LIST_Y - OPT_BTN_H - SG * 2 - eSP

		local optScroll = editPanel:Add("DScrollPanel")
		optScroll:SetPos(eSP, OPT_LIST_Y)
		optScroll:SetSize(EDIT_W - eSP * 2, OPT_LIST_H)
		optScroll:GetVBar():SetWide(SScale(4))

		local ROW_W = EDIT_W - eSP * 2 - SScale(4)
		local function refreshOptList()
			optScroll:Clear()
			page.options = page.options or {}

			for i, opt in ipairs(page.options) do
				local row = optScroll:Add("DPanel")
				row:Dock(TOP)
				row:DockMargin(0, 0, 0, SScale(2))
				row:SetTall(SScale(36))
				row.Paint = function(me, w, h)
					surface.SetDrawColor(33, 33, 33, 200)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(66, 66, 66, 44)
					surface.DrawOutlinedRect(0, 0, w, h, 1)
				end

				local iSP = SScale(4)
				local LBL_W = SScale(48)
				local BTN_W = SScale(18)
				local BTNS_W = BTN_W * 3 + SScale(2) * 2
				local ENTRY_W = ROW_W - iSP * 2 - LBL_W - BTNS_W - SScale(6)
				local BTNS_X = ROW_W - iSP - BTNS_W

				local lblLbl = row:Add("DLabel")
				lblLbl:SetPos(iSP, SScale(1))
				lblLbl:SetSize(LBL_W, SScale(10))
				lblLbl:SetText("Texto:")
				lblLbl:SetFont("NPC_UI.Small")
				lblLbl:SetTextColor(Color(130, 130, 130))

				local labelEntry = row:Add("DTextEntry")
				labelEntry:SetPos(iSP + LBL_W, 0)
				labelEntry:SetSize(ENTRY_W, SScale(16))
				labelEntry:SetFont("NPC_UI.Fields")
				labelEntry:SetText(opt.label or "")
				labelEntry.Paint = paintDarkEntry
				labelEntry.OnChange = function(self) opt.label = self:GetValue() end

				local lblDest = row:Add("DLabel")
				lblDest:SetPos(iSP, SScale(19))
				lblDest:SetSize(LBL_W, SScale(10))
				lblDest:SetText("Destino:")
				lblDest:SetFont("NPC_UI.Small")
				lblDest:SetTextColor(Color(130, 130, 130))

				local destCombo = row:Add("DComboBox")
				destCombo:SetPos(iSP + LBL_W, SScale(18))
				destCombo:SetSize(ENTRY_W, SScale(16))
				destCombo:SetFont("NPC_UI.Fields")
				destCombo:SetSortItems(false)

				local currentVal = opt.nextPage or opt.action or "close"
				local selectID = nil

				local closeID = destCombo:AddChoice("X  Cerrar diálogo", "close")
				if (currentVal == "close") then selectID = closeID end

				local sortedPages = {}
				for k, _ in pairs(workDialogues) do
					if (k != selectedPageKey) then
						table.insert(sortedPages, k)
					end
				end
				table.sort(sortedPages, function(a, b)
					if (a == "root") then return true end
					if (b == "root") then return false end
					return a < b
				end)

				for _, pk in ipairs(sortedPages) do
					local pageText = workDialogues[pk].text or ""
					local preview = string.sub(pageText, 1, 20)
					if (#pageText > 20) then preview = preview .. "..." end
					local choiceID = destCombo:AddChoice(">  " .. pk .. "  (" .. preview .. ")", pk)
					if (currentVal == pk) then selectID = choiceID end
				end

				if (selectID) then
					destCombo:ChooseOptionID(selectID)
				end

				destCombo.OnSelect = function(self, index, value, data)
					if (data == "close") then
						opt.action = "close"
						opt.nextPage = nil
					else
						opt.nextPage = data
						opt.action = nil
					end
				end

				local upBtn = makeMetroBtn(row, "^", 66, 100, 166, function()
					if (i > 1) then
						page.options[i], page.options[i - 1] = page.options[i - 1], page.options[i]
						refreshOptList()
					end
				end)
				upBtn:SetPos(BTNS_X, SScale(2))
				upBtn:SetSize(BTN_W, SScale(14))

				local downBtn = makeMetroBtn(row, "v", 66, 100, 166, function()
					if (i < #page.options) then
						page.options[i], page.options[i + 1] = page.options[i + 1], page.options[i]
						refreshOptList()
					end
				end)
				downBtn:SetPos(BTNS_X, SScale(19))
				downBtn:SetSize(BTN_W, SScale(14))

				local delBtn = makeMetroBtn(row, "X", 150, 30, 30, function()
					table.remove(page.options, i)
					refreshOptList()
				end)
				delBtn:SetPos(BTNS_X + BTN_W + SScale(2), SScale(6))
				delBtn:SetSize(BTN_W * 2 + SScale(2), SScale(24))
			end
		end
		refreshOptList()

		-- Botón añadir opción
		local addOptBtn = makeMetroBtn(editPanel, "+ Añadir opción", 30, 100, 30, function()
			page.options = page.options or {}
			table.insert(page.options, {label = "Nueva opción", action = "close"})
			refreshOptList()
		end)
		addOptBtn:SetPos(eSP, OPT_LIST_Y + OPT_LIST_H + SG)
		addOptBtn:SetSize(EDIT_W - eSP * 2, OPT_BTN_H)
	end

	-- ── Refresco de la lista de páginas ──────────────────────────────────────
	refreshPages = function()
		pageScroll:Clear()

		local sorted = {}
		for k, _ in pairs(workDialogues) do
			table.insert(sorted, k)
		end
		table.sort(sorted, function(a, b)
			if (a == "root") then return true end
			if (b == "root") then return false end
			return a < b
		end)

		for _, pageKey in ipairs(sorted) do
			local page = workDialogues[pageKey]
			local row  = pageScroll:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(SScale(2), SScale(2), SScale(2), 0)
			row:SetTall(SScale(26))
			row:SetCursor("hand")

			row.Paint = function(me, w, h)
				local isSel = (selectedPageKey == pageKey)
				surface.SetDrawColor(44, 44, 44, isSel and 60 or (me:IsHovered() and 30 or 15))
				surface.DrawRect(0, 0, w, h)
				if (isSel) then
					surface.SetDrawColor(fc.r, fc.g, fc.b, 180)
					surface.DrawRect(0, 0, SScale(3), h)
				end
				surface.SetDrawColor(66, 66, 66, isSel and 120 or (me:IsHovered() and 60 or 30))
				surface.DrawOutlinedRect(0, 0, w, h, 1)

				local nameCol = pageKey == "root" and Color(220, 180, 100) or Color(200, 200, 200)
				draw.SimpleText(pageKey, "NPC_UI.Fields",
					SScale(8), SScale(2), nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				local preview = string.sub(page.text or "", 1, 30)
				if (#(page.text or "") > 30) then preview = preview .. "..." end
				draw.SimpleText(preview, "NPC_UI.Small",
					SScale(8), SScale(14), Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end

			row.OnMousePressed = function(me, mc)
				if (mc != MOUSE_LEFT) then return end
				selectedPageKey = pageKey
				refreshPages()
				refreshPageEditor()
			end
		end

		-- Botón añadir página
		local addPageRow = pageScroll:Add("DPanel")
		addPageRow:Dock(TOP)
		addPageRow:DockMargin(SScale(2), SScale(4), SScale(2), 0)
		addPageRow:SetTall(SScale(16))

		local addPageBtn = makeMetroBtn(addPageRow, "+ Página", 30, 100, 30, function()
			local newKey
			repeat
				newKey = "pagina_" .. math.random(100, 999)
			until (not workDialogues[newKey])
			workDialogues[newKey] = {
				text = "Texto del NPC...",
				options = {{label = "← Volver", nextPage = "root"}}
			}
			selectedPageKey = newKey
			refreshPages()
			refreshPageEditor()
		end)
		addPageBtn:Dock(FILL)

		-- Botón eliminar página (no se puede eliminar root)
		if (selectedPageKey != "root") then
			local delPageRow = pageScroll:Add("DPanel")
			delPageRow:Dock(TOP)
			delPageRow:DockMargin(SScale(2), SScale(2), SScale(2), 0)
			delPageRow:SetTall(SScale(16))

			local delPageBtn = makeMetroBtn(delPageRow, "- Eliminar página", 130, 30, 30, function()
				if (selectedPageKey == "root") then return end
				workDialogues[selectedPageKey] = nil
				selectedPageKey = "root"
				refreshPages()
				refreshPageEditor()
			end)
			delPageBtn:Dock(FILL)
		end
	end

	refreshPages()
	refreshPageEditor()

	-- ── Botones inferiores ───────────────────────────────────────────────────
	local BTN_Y = H - SP - SBTN
	local BAPP  = SScale(88)
	local BSAVE = SScale(96)
	local BCLS  = SScale(82)

	-- ── Botón Apariencia ─────────────────────────────────────────────────────
	makeMetroBtn(frame, "Apariencia", 66, 66, 140, function()
		local MODELS = {
			{label = "Civil",       model = "models/magma/civilian/intro_civ.mdl"},
			{label = "Survivor 14", model = "models/magma/civilian/survivor14_redux.mdl"},
			{label = "Gordo",       model = "models/magma/civilian/intro_fat.mdl"},
			{label = "Survivor 3",  model = "models/magma/civilian/survivor3_redux.mdl"},
			{label = "Bandido Max", model = "models/magma/civilian/max_bandit.mdl"},
			{label = "Bandido 6",   model = "models/magma/bandits/bandit6_redux.mdl"},
			{label = "Survivor 5",  model = "models/magma/civilian/survivor5_redux.mdl"},
			{label = "Survivor 8",  model = "models/magma/civilian/survivor8_redux.mdl"},
			{label = "Survivor 12", model = "models/magma/civilian/survivor12_redux.mdl"},
			{label = "Survivor 15", model = "models/magma/civilian/survivor15_redux.mdl"},
		}
		local ANIMS = {
			{label = "Por defecto",     seq = ""},
			{label = "Idle 01",         seq = "idle_all_01"},
			{label = "Idle 02",         seq = "idle_all_02"},
			{label = "Cruzar brazos",   seq = "idle_crossarms_01"},
			{label = "Saludar",         seq = "wave"},
			{label = "Señalar",         seq = "point"},
			{label = "Asentir",         seq = "nod_yes"},
			{label = "Negar",           seq = "nod_no"},
			{label = "Hablar",          seq = "talk"},
			{label = "Aclamar",         seq = "cheer"},
		}

		local AW = SScale(360)
		local AH = SScale(340)
		local aMdl  = selectedModel
		local aAnim = selectedAnim
		local aBodygroups = table.Copy(selectedBodygroups)

		if (IsValid(ix.npcs._adminAppModal)) then ix.npcs._adminAppModal:Remove() end
		local aModal = vgui.Create("DFrame")
		ix.npcs._adminAppModal = aModal
		aModal:SetSize(AW, AH)
		aModal:SetPos(sw / 2 - AW / 2, sh / 2 - AH / 2)
		aModal:SetTitle("")
		aModal:SetDraggable(true)
		aModal:ShowCloseButton(false)
		aModal:MakePopup()
		aModal:SetDeleteOnClose(true)
		aModal.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 66, 140, 140)
			surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 100)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText("Apariencia del NPC", "NPC_UI.Button",
				SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local LIST_W  = SScale(120)
		local PREV_W  = AW - LIST_W - SP * 3
		local TOP_Y   = SScale(28)
		local ANIM_H  = SScale(18)
		local BG_H    = SScale(60)
		local PREV_H  = AH - TOP_Y - SP * 2 - ANIM_H - BG_H - SBTN - SG * 3
		local PREV_X  = SP * 2 + LIST_W

		-- Preview 3D
		local mdlPanel = aModal:Add("DModelPanel")
		mdlPanel:SetPos(PREV_X, TOP_Y)
		mdlPanel:SetSize(PREV_W, PREV_H)
		mdlPanel:SetModel(aMdl)
		mdlPanel:SetFOV(35)
		mdlPanel:SetLookAt(Vector(0, 0, 50))
		mdlPanel:SetCamPos(Vector(120, 0, 50))
		mdlPanel:SetAmbientLight(Color(112, 128, 130))
		mdlPanel:SetDirectionalLight(BOX_FRONT, Color(154, 136, 102))
		mdlPanel.LayoutEntity = function(self, ent)
			if (aAnim != "") then
				local seq = ent:LookupSequence(aAnim)
				if (seq and seq > 0 and not self._animApplied) then
					ent:ResetSequence(seq)
					ent:SetPlaybackRate(1)
					self._animApplied = true
				end
				ent:FrameAdvance()
			end
		end
		mdlPanel.PaintOver = function(self, w, h)
			surface.SetDrawColor(66, 66, 66, 44)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local refreshBodygroups

		local function refreshPreview()
			mdlPanel:SetModel(aMdl)
			mdlPanel._animApplied = false
			if (refreshBodygroups) then refreshBodygroups() end
		end

		-- Lista de modelos
		local CUSTOM_H   = SScale(14)
		local listHeight = PREV_H - CUSTOM_H - SG
		local modelScroll = aModal:Add("DScrollPanel")
		modelScroll:SetPos(SP, TOP_Y)
		modelScroll:SetSize(LIST_W, listHeight)
		modelScroll:GetVBar():SetWide(SScale(4))

		for _, entry in ipairs(MODELS) do
			local mdl  = entry.model
			local mRow = modelScroll:Add("DPanel")
			mRow:Dock(TOP)
			mRow:DockMargin(0, 0, 0, SScale(1))
			mRow:SetTall(SScale(13))
			mRow:SetCursor("hand")
			mRow.Paint = function(me, w, h)
				local isSel = (aMdl == mdl)
				ix.util.DrawBlur(me, 5)
				surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
				surface.DrawRect(0, 0, w, h)
				if (isSel) then
					surface.SetDrawColor(112, 128, 130, 180)
					surface.DrawRect(0, 0, SScale(3), h)
				end
				surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(entry.label, "NPC_UI.Small",
					SScale(8), h / 2, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			mRow.OnMousePressed = function(me, mc)
				if (mc != MOUSE_LEFT) then return end
				aMdl = mdl
				refreshPreview()
			end
		end

		-- Campo de ruta de modelo personalizado
		local customY  = TOP_Y + listHeight + SG
		local CBTN_W   = CUSTOM_H

		local customEntry = aModal:Add("DTextEntry")
		customEntry:SetPos(SP, customY)
		customEntry:SetSize(LIST_W - CBTN_W - SScale(2), CUSTOM_H)
		customEntry:SetFont("NPC_UI.Small")
		customEntry:SetPlaceholderText("models/path/model.mdl")
		customEntry.Paint = paintDarkEntry

		local customBtn = makeMetroBtn(aModal, "+", 66, 100, 166, function()
			local mdl = customEntry:GetValue()
			if (mdl != "" and string.match(mdl, "%.mdl$")) then
				aMdl = mdl
				refreshPreview()
			end
		end)
		customBtn:SetPos(SP + LIST_W - CBTN_W, customY)
		customBtn:SetSize(CBTN_W, CUSTOM_H)

		-- Selector de animación
		local ANIM_Y = TOP_Y + PREV_H + SG

		local lblAnim = aModal:Add("DLabel")
		lblAnim:SetPos(SP, ANIM_Y)
		lblAnim:SetSize(SScale(80), ANIM_H)
		lblAnim:SetText("Animación:")
		lblAnim:SetFont("NPC_UI.Fields")
		lblAnim:SetTextColor(Color(150, 150, 150))
		lblAnim:SetContentAlignment(4)

		local animCombo = aModal:Add("DComboBox")
		animCombo:SetPos(SP + SScale(84), ANIM_Y)
		animCombo:SetSize(AW - SP * 2 - SScale(84), ANIM_H)
		animCombo:SetFont("NPC_UI.Fields")
		for _, a in ipairs(ANIMS) do
			animCombo:AddChoice(a.label, a.seq)
		end
		for i, a in ipairs(ANIMS) do
			if (a.seq == aAnim) then animCombo:ChooseOptionID(i); break end
		end
		animCombo.OnSelect = function(_, _, _, data)
			aAnim = data
			mdlPanel._animApplied = false
		end

		-- Selector de bodygroups
		local BG_Y = ANIM_Y + ANIM_H + SG

		local lblBg = aModal:Add("DLabel")
		lblBg:SetPos(SP, BG_Y)
		lblBg:SetSize(AW - SP * 2, SScale(14))
		lblBg:SetText("Bodygroups:")
		lblBg:SetFont("NPC_UI.Fields")
		lblBg:SetTextColor(Color(150, 150, 150))

		local bgScroll = aModal:Add("DScrollPanel")
		bgScroll:SetPos(SP, BG_Y + SScale(14))
		bgScroll:SetSize(AW - SP * 2, BG_H - SScale(14))
		bgScroll:GetVBar():SetWide(SScale(4))

		refreshBodygroups = function()
			bgScroll:Clear()

			local ent = mdlPanel.Entity
			if (not IsValid(ent)) then return end

			for _, bg in ipairs(ent:GetBodyGroups()) do
				if (bg.id != 0 and bg.num > 1) then
					local cur = math.Clamp(aBodygroups[bg.id] or 0, 0, bg.num - 1)
					aBodygroups[bg.id] = cur
					ent:SetBodygroup(bg.id, cur)

					local row = bgScroll:Add("DPanel")
					row:Dock(TOP)
					row:DockMargin(0, 0, 0, SScale(1))
					row:SetTall(SScale(14))
					row.Paint = function(me, w, h)
						surface.SetDrawColor(66, 66, 66, me:IsHovered() and 22 or 11)
						surface.DrawRect(0, 0, w, h)
					end

					local lbl = row:Add("DLabel")
					lbl:Dock(LEFT)
					lbl:DockMargin(SScale(4), 0, 0, 0)
					lbl:SetWide(SScale(160))
					lbl:SetFont("NPC_UI.Small")
					lbl:SetTextColor(Color(190, 190, 190))
					lbl:SetContentAlignment(4)
					lbl:SetText((bg.name or ("Grupo " .. bg.id)):gsub("^%l", string.upper))

					local valLbl = row:Add("DLabel")
					valLbl:Dock(RIGHT)
					valLbl:SetWide(SScale(24))
					valLbl:SetFont("NPC_UI.Small")
					valLbl:SetTextColor(Color(220, 220, 220))
					valLbl:SetContentAlignment(5)
					valLbl:SetText(tostring(aBodygroups[bg.id]))

					local btnNext = makeMetroBtn(row, ">", 66, 100, 166, function()
						local val = aBodygroups[bg.id]
						if (val < bg.num - 1) then
							val = val + 1
							aBodygroups[bg.id] = val
							valLbl:SetText(tostring(val))
							ent:SetBodygroup(bg.id, val)
						end
					end)
					btnNext:Dock(RIGHT)
					btnNext:SetWide(SScale(16))

					local btnPrev = makeMetroBtn(row, "<", 66, 100, 166, function()
						local val = aBodygroups[bg.id]
						if (val > 0) then
							val = val - 1
							aBodygroups[bg.id] = val
							valLbl:SetText(tostring(val))
							ent:SetBodygroup(bg.id, val)
						end
					end)
					btnPrev:Dock(RIGHT)
					btnPrev:SetWide(SScale(16))
				end
			end
		end
		refreshBodygroups()

		local BTN_Y_A = BG_Y + BG_H + SG
		local BW1 = math.floor((AW - SP * 3) * 2 / 3)
		local BW2 = AW - SP * 3 - BW1

		makeMetroBtn(aModal, "Confirmar", 66, 166, 66, function()
			selectedModel = aMdl
			selectedAnim  = aAnim

			local cleanBg = {}
			if (IsValid(mdlPanel.Entity)) then
				for _, bg in ipairs(mdlPanel.Entity:GetBodyGroups()) do
					if (bg.id != 0 and bg.num > 1) then
						cleanBg[bg.id] = aBodygroups[bg.id] or 0
					end
				end
			end
			selectedBodygroups = cleanBg

			aModal:Remove()
		end):SetBounds(SP, BTN_Y_A, BW1, SBTN)

		makeMetroBtn(aModal, "Cancelar", 120, 30, 30, function()
			aModal:Remove()
		end):SetBounds(SP + BW1 + SP, BTN_Y_A, BW2, SBTN)
	end):SetBounds(SP, BTN_Y, BAPP, SBTN)

	-- ── Guardar ──────────────────────────────────────────────────────────────
	makeMetroBtn(frame, "+ Guardar", 30, 120, 30, function()
		local dialoguesJSON = util.TableToJSON(workDialogues)
		if (#dialoguesJSON > 60000) then
			chat.AddText(Color(255, 80, 80), "[Admin] Error: los diálogos son demasiado grandes para guardar.")
			return
		end

		net.Start("npc_AdminSave")
			net.WriteEntity(npcEnt)
			net.WriteString(nameEntry:GetValue())
			net.WriteString(descEntry:GetValue())
			net.WriteString(selectedModel or "")
			net.WriteString(selectedAnim or "")

			local bgList = {}
			for id, val in pairs(selectedBodygroups) do
				table.insert(bgList, {id = id, val = val})
			end
			net.WriteUInt(#bgList, 8)
			for _, bg in ipairs(bgList) do
				net.WriteUInt(bg.id, 8)
				net.WriteUInt(bg.val, 8)
			end

			net.WriteString(dialoguesJSON)
		net.SendToServer()

		chat.AddText(Color(80, 200, 80), "[Admin] NPC guardado.")
		frame:Remove()
	end):SetBounds(W - SP - BCLS - SG - BSAVE, BTN_Y, BSAVE, SBTN)

	-- ── Cerrar ───────────────────────────────────────────────────────────────
	makeMetroBtn(frame, "Cerrar", 120, 30, 30, function()
		frame:Remove()
	end):SetBounds(W - SP - BCLS, BTN_Y, BCLS, SBTN)
end)
