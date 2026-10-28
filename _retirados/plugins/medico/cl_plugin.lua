local PLUGIN = PLUGIN

-- La visualización de las heridas se integra en la barra de vida del plugin "hud"
-- (la salud va en rojo y la capacidad perdida en azul oscuro). Aquí vive el menú
-- de conversación del NPC médico de guardia, al estilo del diálogo de los traders.

ix.medico = ix.medico or {}

-- ============================================================
--  FUENTES Y COLORES
-- ============================================================

local function RegistrarFuentes()
	surface.CreateFont("MetroMedico_Big",   { font = "Capture Smallz", size = SScale(15), weight = 500, antialias = true })
	surface.CreateFont("MetroMedico_Btn",   { font = "Capture Smallz", size = SScale(10), weight = 500, antialias = true })
	surface.CreateFont("MetroMedico_Field", { font = "Capture Smallz", size = SScale(8),  weight = 500, antialias = true })
	surface.CreateFont("MetroMedico_Small", { font = "Capture Smallz", size = SScale(8),  weight = 500, antialias = true })
end
RegistrarFuentes()
hook.Add("OnScreenSizeChanged", "MetroMedico_Fuentes", RegistrarFuentes)

local COLOR_ACCENT = Color(60, 150, 110)   -- verde médico
local PAD = 8

-- ============================================================
--  HELPERS DE DIBUJO
-- ============================================================

local function paintDarkEntry(self, w, h)
	ix.util.DrawBlur(self, 3)
	surface.SetDrawColor(44, 44, 44, 220)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(88, 88, 88, 160)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	self:DrawTextEntryText(Color(220, 220, 220), Color(66, 120, 200, 180), Color(220, 220, 220))
end

local function makeMetroBtn(parent, text, r, g, b, cb)
	local btn = parent:Add("DButton")
	btn:SetText(text)
	btn:SetFont("MetroMedico_Field")
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
--  MODAL DE ADMINISTRACIÓN: MODELO Y ANIMACIÓN
-- ============================================================

local APP_MODELS = {
	{label = "Ciudadano 07",  model = "models/Humans/Group01/male_07.mdl"},
	{label = "Ciudadano 02",  model = "models/Humans/Group01/male_02.mdl"},
	{label = "Médico HL2",    model = "models/Humans/Group01/male_09.mdl"},
	{label = "Civil",         model = "models/magma/civilian/intro_civ.mdl"},
	{label = "Survivor 14",   model = "models/magma/civilian/survivor14_redux.mdl"},
	{label = "Survivor 3",    model = "models/magma/civilian/survivor3_redux.mdl"},
	{label = "Survivor 5",    model = "models/magma/civilian/survivor5_redux.mdl"},
	{label = "Survivor 8",    model = "models/magma/civilian/survivor8_redux.mdl"},
}

local APP_ANIMS = {
	{label = "Por defecto",   seq = ""},
	{label = "Idle 01",       seq = "idle_all_01"},
	{label = "Idle 02",       seq = "idle_all_02"},
	{label = "Cruzar brazos", seq = "idle_crossarms_01"},
	{label = "Saludar",       seq = "wave"},
	{label = "Señalar",       seq = "point"},
	{label = "Asentir",       seq = "nod_yes"},
	{label = "Hablar",        seq = "talk"},
}

local function AbrirApariencia(ent)
	if (!IsValid(ent)) then return end
	if (IsValid(ix.medico.appModal)) then ix.medico.appModal:Remove() end

	local sw, sh = ScrW(), ScrH()
	local SP, SG = SScale(8), SScale(5)
	local SBTN   = SScale(16)

	local AW = SScale(360)
	local AH = SScale(290)

	local aMdl  = ent:GetNetVar("npcModel") or ent:GetModel()
	local aAnim = ent:GetNetVar("npcAnim") or ""

	local aModal = vgui.Create("DFrame")
	ix.medico.appModal = aModal
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
		surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 180)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 100)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("Apariencia del Médico", "MetroMedico_Btn",
			SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	-- Layout: lista izquierda + preview derecha
	local LIST_W = SScale(120)
	local PREV_W = AW - LIST_W - SP * 3
	local TOP_Y  = SScale(28)
	local ANIM_H = SScale(18)
	local PREV_H = AH - TOP_Y - SP * 2 - ANIM_H - SG - SBTN - SG
	local PREV_X = SP * 2 + LIST_W

	-- Preview 3D
	local mdlPanel = aModal:Add("DModelPanel")
	mdlPanel:SetPos(PREV_X, TOP_Y)
	mdlPanel:SetSize(PREV_W, PREV_H)
	mdlPanel:SetModel(aMdl)
	mdlPanel:SetFOV(35)
	mdlPanel:SetLookAt(Vector(0, 0, 50))
	mdlPanel:SetCamPos(Vector(120, 0, 50))
	mdlPanel:SetAmbientLight(Color(40, 160, 120))
	mdlPanel:SetDirectionalLight(BOX_FRONT, Color(255, 200, 160))
	mdlPanel.LayoutEntity = function(self, e)
		if (aAnim != "") then
			local seq = e:LookupSequence(aAnim)
			if (seq and seq > 0 and not self._animApplied) then
				e:ResetSequence(seq)
				e:SetPlaybackRate(1)
				self._animApplied = true
			end
			e:FrameAdvance()
		end
	end
	mdlPanel.PaintOver = function(self, w, h)
		surface.SetDrawColor(66, 66, 66, 44)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local function refreshPreview()
		mdlPanel:SetModel(aMdl)
		mdlPanel._animApplied = false
	end

	-- Lista de modelos preset
	local CUSTOM_H   = SScale(14)
	local listHeight = PREV_H - CUSTOM_H - SG
	local modelScroll = aModal:Add("DScrollPanel")
	modelScroll:SetPos(SP, TOP_Y)
	modelScroll:SetSize(LIST_W, listHeight)
	modelScroll:GetVBar():SetWide(SScale(4))

	for _, entry in ipairs(APP_MODELS) do
		local mdl  = entry.model
		local mRow = modelScroll:Add("DPanel")
		mRow:Dock(TOP)
		mRow:DockMargin(0, 0, 0, SScale(1))
		mRow:SetTall(SScale(13))
		mRow:SetCursor("hand")
		mRow.Paint = function(me, w, h)
			local isSel = (aMdl == mdl)
			surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
			surface.DrawRect(0, 0, w, h)
			if (isSel) then
				surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 180)
				surface.DrawRect(0, 0, SScale(3), h)
			end
			surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(entry.label, "MetroMedico_Small",
				SScale(8), h / 2, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		mRow.OnMousePressed = function(me, mc)
			if (mc != MOUSE_LEFT) then return end
			aMdl = mdl
			refreshPreview()
		end
	end

	-- Campo de ruta de modelo personalizado
	local customY = TOP_Y + listHeight + SG
	local CBTN_W  = CUSTOM_H

	local customEntry = aModal:Add("DTextEntry")
	customEntry:SetPos(SP, customY)
	customEntry:SetSize(LIST_W - CBTN_W - SScale(2), CUSTOM_H)
	customEntry:SetFont("MetroMedico_Small")
	customEntry:SetPlaceholderText("models/ruta/modelo.mdl")
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
	lblAnim:SetFont("MetroMedico_Field")
	lblAnim:SetTextColor(Color(150, 150, 150))
	lblAnim:SetContentAlignment(4)

	local animCombo = aModal:Add("DComboBox")
	animCombo:SetPos(SP + SScale(84), ANIM_Y)
	animCombo:SetSize(AW - SP * 2 - SScale(84), ANIM_H)
	animCombo:SetFont("MetroMedico_Field")
	for _, a in ipairs(APP_ANIMS) do
		animCombo:AddChoice(a.label, a.seq)
	end
	for i, a in ipairs(APP_ANIMS) do
		if (a.seq == aAnim) then animCombo:ChooseOptionID(i); break end
	end
	animCombo.OnSelect = function(_, _, _, data)
		aAnim = data
		mdlPanel._animApplied = false
	end

	-- Botones Guardar / Cancelar
	local BTN_Y = ANIM_Y + ANIM_H + SG
	local BW1 = math.floor((AW - SP * 3) * 2 / 3)
	local BW2 = AW - SP * 3 - BW1

	makeMetroBtn(aModal, "Guardar", 30, 120, 30, function()
		net.Start("medico_npc_AdminSave")
			net.WriteEntity(ent)
			net.WriteString(aMdl or "")
			net.WriteString(aAnim or "")
		net.SendToServer()
		aModal:Remove()
	end):SetBounds(SP, BTN_Y, BW1, SBTN)

	makeMetroBtn(aModal, "Cancelar", 120, 30, 30, function()
		aModal:Remove()
	end):SetBounds(SP + BW1 + SP, BTN_Y, BW2, SBTN)
end

-- ============================================================
--  DIÁLOGO DEL NPC MÉDICO DE GUARDIA (estilo trader)
-- ============================================================

net.Receive("medico_npc_OpenDialogue", function()
	local ent           = net.ReadEntity()
	local money         = net.ReadUInt(32)
	local heridas       = net.ReadUInt(8)
	local medicoNearby  = net.ReadBool()
	local precioCurar   = net.ReadUInt(16)
	local precioHeridas = net.ReadUInt(16)

	if (!IsValid(ent)) then return end
	if (IsValid(ix.medico.frameTop)) then ix.medico.frameTop:Remove() end
	if (IsValid(ix.medico.frameBot)) then ix.medico.frameBot:Remove() end

	local fc     = COLOR_ACCENT
	local sw, sh = ScrW(), ScrH()

	local W        = SScale(300)
	local HEADER_H = SScale(38)
	local SPEECH_H = SScale(62)
	local SEP_H    = SScale(1)
	local OPT_ROW  = SScale(18)

	-- Envía una acción de pago al servidor.
	local function EnviarAccion(action)
		if (!IsValid(ent)) then return end
		net.Start("medico_npc_Action")
			net.WriteEntity(ent)
			net.WriteString(action)
		net.SendToServer()
	end

	-- Estado del typewriter
	local typeTarget = ""
	local typeStart  = 0
	local typeDone   = false
	local typeShown  = ""
	local CHARS_SEC  = 40
	local speechLbl  = nil

	-- ── Cierre unificado de ambos frames ──────────────────────
	local frameTop, frameBot
	local _closing = false
	local function closeAll()
		if (_closing) then return end
		_closing = true
		if (IsValid(frameTop)) then frameTop:Remove() end
		if (IsValid(frameBot)) then frameBot:Remove() end
	end

	-- ── Frame superior: nombre e info ─────────────────────────
	frameTop = vgui.Create("EditablePanel")
	frameTop:SetSize(W, HEADER_H)
	frameTop:SetPos(sw / 2 - W / 2, 0)
	frameTop:SetAlpha(0); frameTop:AlphaTo(255, 0.25); frameTop:MakePopup()
	ix.medico.frameTop = frameTop

	frameTop.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 66)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	frameTop.Think = nil

	local lblName = frameTop:Add("DLabel")
	lblName:SetPos(PAD, SScale(4))
	lblName:SetSize(W - PAD * 2, SScale(18))
	lblName:SetText("Médico de Guardia")
	lblName:SetFont("MetroMedico_Btn")
	lblName:SetTextColor(Color(225, 225, 225))

	local lblInfo = frameTop:Add("DLabel")
	lblInfo:SetPos(PAD, SScale(22))
	lblInfo:SetSize(W - PAD * 2, SScale(16))
	lblInfo:SetText("Enfermería  •  Heridas: " .. heridas .. "%  •  " .. money .. " Balas")
	lblInfo:SetFont("MetroMedico_Small")
	lblInfo:SetTextColor(Color(150, 175, 160))

	-- ── Frame inferior: conversación y opciones ───────────────
	local BOT_OPTS_H = OPT_ROW * 4 + SScale(6)
	local BOT_H      = SPEECH_H + SScale(8) + BOT_OPTS_H + SScale(10)

	frameBot = vgui.Create("EditablePanel")
	frameBot:SetSize(W, BOT_H)
	frameBot:SetPos(sw / 2 - W / 2, sh - BOT_H - SScale(6))
	frameBot:SetAlpha(0); frameBot:AlphaTo(255, 0.25); frameBot:MakePopup()
	ix.medico.frameBot = frameBot

	frameBot.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(fc.r, fc.g, fc.b, 70)
		surface.DrawRect(PAD, SPEECH_H + SScale(3), w - PAD * 2, SEP_H)
		surface.SetDrawColor(66, 66, 66, 66)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	frameBot.Think = nil

	-- ── Área de texto del NPC (typewriter) ────────────────────
	local speechArea = frameBot:Add("DPanel")
	speechArea:SetPos(PAD, SScale(4))
	speechArea:SetSize(W - PAD * 2, SPEECH_H - SScale(8))
	speechArea:SetCursor("hand")

	speechArea.Paint = function(self, w, h)
		surface.SetDrawColor(18, 18, 18, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 45)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if (!typeDone) then
			draw.SimpleText("clic para saltar ▶", "MetroMedico_Small",
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
	speechLbl:SetFont("MetroMedico_Field")
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

	-- ── Lista de opciones ─────────────────────────────────────
	local optScroll = frameBot:Add("DScrollPanel")
	optScroll:SetPos(PAD, SPEECH_H + SScale(8))
	optScroll:SetSize(W - PAD * 2, BOT_OPTS_H)

	local vbar = optScroll:GetVBar()
	vbar:SetWide(SScale(3))
	vbar.Paint         = function(_, w, h) surface.SetDrawColor(33, 33, 33, 200); surface.DrawRect(0, 0, w, h) end
	vbar.btnUp.Paint   = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 200); surface.DrawRect(0, 0, w, h) end

	local optRows = {}
	local showPage

	local function buildOptions(options)
		for _, r in ipairs(optRows) do if (IsValid(r)) then r:Remove() end end
		optRows = {}

		for _, opt in ipairs(options) do
			local row      = optScroll:Add("DPanel")
			local optText  = opt.text
			local optAct   = opt.action
			local optNext  = opt.nextPage
			local disabled = opt.disabled
			local note     = opt.note

			row:Dock(TOP)
			row:DockMargin(0, 0, 0, SScale(2))
			row:SetTall(OPT_ROW)
			row:SetCursor(disabled and "no" or "hand")
			row:SetMouseInputEnabled(true)

			row.Paint = function(me, w, h)
				if (!disabled and me:IsHovered()) then
					surface.SetDrawColor(fc.r, fc.g, fc.b, 18)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(fc.r, fc.g, fc.b, 130)
					surface.DrawRect(0, 0, SScale(2), h)
				end

				local col = disabled and Color(110, 110, 110)
					or (me:IsHovered()
						and Color(math.min(fc.r + 80, 255), math.min(fc.g + 80, 255), math.min(fc.b + 80, 255))
						or  Color(165, 165, 165))
				local prefix = (!disabled and me:IsHovered()) and "> " or "  "
				draw.SimpleText(prefix .. optText, "MetroMedico_Field",
					SScale(10), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				if (note) then
					draw.SimpleText(note, "MetroMedico_Small",
						w - SScale(6), h / 2, Color(110, 110, 110), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
			end

			if (!disabled) then
				row.OnMousePressed = function()
					if (optAct == "heal") then
						EnviarAccion("heal"); closeAll()
					elseif (optAct == "treat") then
						EnviarAccion("treat"); closeAll()
					elseif (optAct == "appearance") then
						closeAll(); AbrirApariencia(ent)
					elseif (optAct == "close") then
						closeAll()
					elseif (optNext) then
						showPage(optNext)
					end
				end
			end

			optRows[#optRows + 1] = row
		end
	end

	-- ── Páginas del árbol de diálogo ──────────────────────────
	local function pageInicio()
		local opts = {
			{text = "Hablar con él.", nextPage = "hablar"},
		}

		-- Curar: bloqueado si hay médico cerca o no llegan las Balas.
		local curarNota
		if (medicoNearby) then
			curarNota = "(hay un médico de servicio)"
		elseif (money < precioCurar) then
			curarNota = "(Balas insuficientes)"
		end
		opts[#opts + 1] = {
			text = "Curarme  —  " .. precioCurar .. " Balas",
			action = "heal", disabled = curarNota != nil, note = curarNota,
		}

		-- Tratar: bloqueado si hay médico cerca, sin heridas o sin Balas.
		local tratarNota
		if (medicoNearby) then
			tratarNota = "(hay un médico de servicio)"
		elseif (heridas <= 0) then
			tratarNota = "(sin heridas)"
		elseif (money < precioHeridas) then
			tratarNota = "(Balas insuficientes)"
		end
		opts[#opts + 1] = {
			text = "Tratar mis heridas  —  " .. precioHeridas .. " Balas",
			action = "treat", disabled = tratarNota != nil, note = tratarNota,
		}

		if (LocalPlayer():IsAdmin()) then
			opts[#opts + 1] = {text = "[ADMIN] Editar apariencia", action = "appearance"}
		end

		opts[#opts + 1] = {text = "Marcharse.", action = "close"}
		return opts
	end

	local PAGES = {
		inicio = {
			text = "Bienvenido a la enfermería. ¿Necesitas que te atienda?",
			build = pageInicio,
		},
		hablar = {
			text = "Llevo años remendando supervivientes en estos túneles. " ..
				"Mientras haya filtros y vendas, nadie se me muere en la camilla. " ..
				"Si encuentras a un médico de verdad ahí fuera, hazle caso antes que a mí.",
			options = {
				{text = "← Volver.",   nextPage = "inicio"},
				{text = "Marcharse.",  action = "close"},
			},
		},
	}

	showPage = function(key)
		local page = PAGES[key]
		if (!page) then return end

		typeTarget = page.text
		typeStart  = CurTime()
		typeDone   = false
		typeShown  = ""
		if (IsValid(speechLbl)) then speechLbl:SetText("") end

		buildOptions(page.build and page.build() or page.options)
	end

	showPage("inicio")
end)
