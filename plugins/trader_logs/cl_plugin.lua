-- ============================================================
--  trader_logs  |  cl_plugin.lua  (CLIENT)
--  Panel de administración con la trazabilidad de los ítems
--  vendidos por los traders. Estética de los menús de admin.
-- ============================================================

local COL_ACCENT  = Color(175, 177, 148)     -- ámbar Metro
local COL_RED     = Color(220, 70, 70)      -- duplicados / alertas
local COL_GREEN   = Color(80, 180, 90)
local COL_TEXT    = Color(215, 215, 215)
local COL_DIM     = Color(160, 160, 160)
local COL_FAINT   = Color(120, 120, 120)

-- ── Helpers de dibujo (mismos patrones que el panel de traders) ────────────────
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
	btn:SetFont("Metro UI.CharFields")
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

local function paintFloatingFrame(self, w, h, accent)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(33, 33, 33, 230)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(accent.r, accent.g, accent.b, 200)
	surface.DrawRect(0, 0, w, 3)
	surface.SetDrawColor(66, 66, 66, 88)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function fmtTime(t)
	if (not t or t == 0) then return "—" end
	return os.date("%d/%m/%y %H:%M", t)
end

-- Texto del poseedor actual (resumen para la fila de la lista)
local function holderSummary(entry)
	local holders = entry.holders or {}
	if (#holders == 0) then return "No cargado / offline", COL_FAINT end
	if (#holders == 1) then
		local h = holders[1]
		return h.name or "?", (h.online and COL_GREEN or COL_TEXT)
	end
	return "DUPLICADO (" .. #holders .. ")", COL_RED
end

-- ============================================================
--  Modal de detalle de un ítem registrado
-- ============================================================
local function openDetail(entry)
	if (IsValid(ix.traderlogs._detail)) then ix.traderlogs._detail:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W  = math.min(SScale(420), sw - SScale(40))
	local H  = math.min(SScale(440), sh - SScale(40))
	local SP = SScale(8)

	local accent = entry.dupe and COL_RED or COL_ACCENT

	local modal = vgui.Create("DFrame")
	ix.traderlogs._detail = modal
	modal:SetSize(W, H); modal:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	modal:SetTitle(""); modal:SetDraggable(true)
	modal:ShowCloseButton(false); modal:MakePopup(); modal:SetDeleteOnClose(true)
	modal.Paint = function(s, w, h) paintFloatingFrame(s, w, h, accent) end

	local title = modal:Add("DLabel")
	title:SetPos(SP, SP); title:SetSize(W - SScale(20), SScale(20))
	title:SetText(entry.itemName .. "  [" .. entry.serial .. "]")
	title:SetFont("Metro UI.Button"); title:SetTextColor(COL_TEXT)

	local subtitle = modal:Add("DLabel")
	subtitle:SetPos(SP, SScale(28)); subtitle:SetSize(W - SScale(20), SScale(14))
	subtitle:SetFont("ixSmallFont")
	if (entry.dupe) then
		subtitle:SetText("⚠ OBJETO DUPLICADO — " .. #entry.holders .. " instancias activas")
		subtitle:SetTextColor(COL_RED)
	elseif (entry.deleted) then
		subtitle:SetText("Eliminado por admin: " .. (entry.deletedBy or "?"))
		subtitle:SetTextColor(COL_FAINT)
	else
		subtitle:SetText("Comprado en: " .. (entry.traderName or "?") .. "  ·  " .. (entry.price or 0) .. " Balas")
		subtitle:SetTextColor(COL_ACCENT)
	end

	local scroll = modal:Add("DScrollPanel")
	scroll:SetPos(SP, SScale(46)); scroll:SetSize(W - SP * 2, H - SScale(46) - SScale(20) - SP)
	scroll:GetVBar():SetWide(SScale(4))

	local function addSection(text, col)
		local p = scroll:Add("DPanel")
		p:Dock(TOP); p:DockMargin(0, SScale(5), 0, SScale(2)); p:SetTall(SScale(14))
		p.Paint = function(_, w, h)
			surface.SetDrawColor(66, 66, 66, 200); surface.DrawRect(0, h - 1, w, 1)
			draw.SimpleText(text, "Metro UI.CharFields", SScale(2), h / 2 - 1,
				col or COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local function addLine(text, col, sub)
		local p = scroll:Add("DPanel")
		p:Dock(TOP); p:DockMargin(0, 0, 0, SScale(2)); p:SetTall(sub and SScale(20) or SScale(13))
		p.Paint = function(_, w, h)
			surface.SetDrawColor(66, 66, 66, 14); surface.DrawRect(0, 0, w, h)
			draw.SimpleText(text, "ixSmallFont", SScale(4), sub and SScale(2) or h / 2,
				col or COL_TEXT, TEXT_ALIGN_LEFT, sub and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
			if (sub) then
				draw.SimpleText(sub, "ixSmallFont", SScale(8), SScale(11),
					COL_FAINT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
		end
	end

	-- Comprador original
	addSection("COMPRADOR ORIGINAL")
	local b = entry.buyer or {}
	addLine((b.name or "?") .. "   " .. (b.steamID or ""), COL_TEXT, fmtTime(entry.boughtAt))

	-- Cadena de traspasos
	addSection("CADENA DE TRASPASOS")
	if (#(entry.history or {}) == 0) then
		addLine("Sin traspasos registrados (sigue con el comprador).", COL_FAINT)
	else
		for i, h in ipairs(entry.history) do
			local label = i .. ". " .. (h.name or "?")
			if (h.kind and h.kind != "personaje") then label = label .. "  [" .. h.kind .. "]" end
			addLine(label .. "   " .. (h.steamID or ""), COL_TEXT, fmtTime(h.at))
		end
	end

	-- Poseedores actuales (cargados ahora mismo)
	addSection("POSEEDOR(ES) ACTUAL(ES)")
	if (#(entry.holders or {}) == 0) then
		addLine("Ninguna instancia cargada (offline o eliminado).", COL_FAINT)
	else
		for _, h in ipairs(entry.holders) do
			local col = entry.dupe and COL_RED or (h.online and COL_GREEN or COL_TEXT)
			local tag = h.online and " · ONLINE" or ""
			addLine((h.name or "?") .. "   " .. (h.steamID or "?") .. tag, col, "ítem #" .. (h.itemDBID or "?"))
		end
	end

	if (entry.dupe) then
		addSection("ALERTA DE DUPLICADO", COL_RED)
		addLine("Propietario antes del dupeo: " .. (b.name or "?"), COL_RED)
		local who = {}
		for _, h in ipairs(entry.holders) do who[#who + 1] = h.name or "?" end
		addLine("Lo tienen ahora: " .. table.concat(who, ", "), COL_RED)
	end

	-- Botones inferiores
	local BY = H - SScale(20) - SP
	local delBtn = makeMetroBtn(modal, "Eliminar objeto del juego", 150, 40, 40, function()
		Derma_Query(
			"¿Eliminar TODAS las instancias cargadas de este objeto?\nSerial: " .. entry.serial,
			"Confirmar borrado",
			"Eliminar", function()
				net.Start("traderlogs_Delete")
					net.WriteString(entry.serial)
				net.SendToServer()
				if (IsValid(modal)) then modal:Remove() end
			end,
			"Cancelar", function() end
		)
	end)
	delBtn:SetPos(SP, BY); delBtn:SetSize((W - SP * 3) / 2, SScale(16))

	local closeBtn = makeMetroBtn(modal, "Cerrar", 60, 60, 60, function() modal:Remove() end)
	closeBtn:SetPos(SP + (W - SP * 3) / 2 + SP, BY); closeBtn:SetSize((W - SP * 3) / 2, SScale(16))
end

-- ============================================================
--  Panel principal: lista de ítems registrados
-- ============================================================
local function openPanel(entries)
	if (IsValid(ix.traderlogs._frame)) then ix.traderlogs._frame:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W  = math.min(SScale(760), sw - SScale(40))
	local H  = math.min(SScale(520), sh - SScale(40))
	local SP = SScale(8)

	local frame = vgui.Create("DFrame")
	ix.traderlogs._frame = frame
	frame:SetSize(W, H); frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetTitle(""); frame:SetDraggable(true)
	frame:ShowCloseButton(false); frame:MakePopup(); frame:SetDeleteOnClose(true)
	frame.Paint = function(s, w, h) paintFloatingFrame(s, w, h, COL_ACCENT) end
	frame.OnRemove = function()
		if (IsValid(ix.traderlogs._detail)) then ix.traderlogs._detail:Remove() end
	end

	local title = frame:Add("DLabel")
	title:SetPos(SP, SP); title:SetSize(W - SScale(120), SScale(20))
	title:SetText("Trazabilidad de Traders"); title:SetFont("Metro UI.Button")
	title:SetTextColor(COL_TEXT)

	local closeX = makeMetroBtn(frame, "X", 120, 30, 30, function() frame:Remove() end)
	closeX:SetPos(W - SScale(28), SP); closeX:SetSize(SScale(20), SScale(16))

	-- Contador de duplicados
	local dupeCount = 0
	for _, e in ipairs(entries) do if (e.dupe) then dupeCount = dupeCount + 1 end end

	local stats = frame:Add("DLabel")
	stats:SetPos(SP, SScale(30)); stats:SetSize(W - SP * 2, SScale(12))
	stats:SetFont("ixSmallFont")
	stats:SetText(#entries .. " ítems registrados   ·   " .. dupeCount .. " duplicado(s) detectado(s)")
	stats:SetTextColor(dupeCount > 0 and COL_RED or COL_DIM)

	-- Estado de filtros
	local filterDupes   = false
	local filterDeleted = false

	-- Buscador
	local search = frame:Add("DTextEntry")
	search:SetPos(SP, SScale(44)); search:SetSize(W - SP * 2, SScale(16))
	search:SetFont("Metro UI.CharFields"); search.Paint = paintDarkEntry
	search:SetUpdateOnType(true)
	search:SetPlaceholderText("Buscar por nombre de ítem, jugador, SteamID, serial...")

	-- Botones de filtro
	local FBTN_H = SScale(16)
	local FBTN_Y = SScale(63)

	local function makeFilterToggle(parent, text, x, w2, r, g, b, getter, setter)
		local btn = parent:Add("DButton")
		btn:SetPos(x, FBTN_Y); btn:SetSize(w2, FBTN_H)
		btn:SetText(""); btn:SetFont("ixSmallFont")
		btn.Paint = function(s, w, h)
			local on = getter()
			surface.SetDrawColor(r, g, b, on and 50 or (s:IsHovered() and 18 or 8))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(r, g, b, on and 180 or (s:IsHovered() and 60 or 30))
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(text, "ixSmallFont", w / 2, h / 2,
				on and Color(math.min(r + 100, 255), math.min(g + 100, 255), math.min(b + 100, 255))
				or Color(140, 140, 140),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function()
			setter(not getter())
			frame.rebuild(search:GetValue())
		end
		return btn
	end

	makeFilterToggle(frame, "Solo duplicados", SP, SScale(100), 220, 50, 50,
		function() return filterDupes end,
		function(v) filterDupes = v end)

	makeFilterToggle(frame, "Eliminados", SP + SScale(104), SScale(80), 100, 100, 100,
		function() return filterDeleted end,
		function(v) filterDeleted = v end)

	-- Cabecera de columnas
	local LSTW   = W - SP * 2
	local C_ITEM = math.floor(LSTW * 0.30)
	local C_BUY  = math.floor(LSTW * 0.24)
	local C_HOLD = math.floor(LSTW * 0.24)
	local C_DATE = LSTW - C_ITEM - C_BUY - C_HOLD

	local hdr = frame:Add("DPanel")
	hdr:SetPos(SP, SScale(82)); hdr:SetSize(LSTW, SScale(16))
	hdr.Paint = function(_, w, h)
		surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 120); surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("Ítem [serial]", "ixSmallFont", SScale(4), h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Comprador",     "ixSmallFont", C_ITEM, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Poseedor actual","ixSmallFont", C_ITEM + C_BUY, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Compra",         "ixSmallFont", C_ITEM + C_BUY + C_HOLD, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:SetPos(SP, SScale(98)); scroll:SetSize(LSTW, H - SScale(98) - SP)
	scroll:GetVBar():SetWide(SScale(4))

	local function rebuild(filter)
		scroll:Clear()
		filter = (filter or ""):lower()

		for _, entry in ipairs(entries) do
			-- Filtros de toggle
			if (filterDupes and not entry.dupe) then continue end
			if (filterDeleted and not entry.deleted) then continue end

			-- Construir texto buscable: ítem, serial, comprador, poseedores, historial, steamIDs
			local hName = select(1, holderSummary(entry))
			local parts = {
				entry.itemName or "", entry.serial or "", entry.uniqueID or "",
				entry.buyer and entry.buyer.name or "",
				entry.buyer and entry.buyer.steamID or "",
				hName,
			}
			for _, h in ipairs(entry.holders or {}) do
				parts[#parts + 1] = h.name or ""
				parts[#parts + 1] = h.steamID or ""
			end
			for _, h in ipairs(entry.history or {}) do
				parts[#parts + 1] = h.name or ""
				parts[#parts + 1] = h.steamID or ""
			end
			local hay = table.concat(parts, " "):lower()
			if (filter != "" and not hay:find(filter, 1, true)) then continue end

			local row = scroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 0, 0, SScale(2)); row:SetTall(SScale(24))
			row:SetCursor("hand")

			row.Paint = function(me, w, h)
				surface.SetDrawColor(66, 66, 66, me:IsHovered() and 26 or 11)
				surface.DrawRect(0, 0, w, h)
				if (entry.dupe) then
					surface.SetDrawColor(220, 50, 50, 30); surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(220, 50, 50, 220); surface.DrawRect(0, 0, SScale(3), h)
				elseif (entry.deleted) then
					surface.SetDrawColor(80, 80, 80, 160); surface.DrawRect(0, 0, SScale(3), h)
				end
				surface.SetDrawColor(66, 66, 66, me:IsHovered() and 66 or 33)
				surface.DrawOutlinedRect(0, 0, w, h, 1)

				local nameCol = entry.dupe and COL_RED or COL_TEXT
				draw.SimpleText(entry.itemName, "ixSmallFont", SScale(4), SScale(5), nameCol, 0, 0)
				draw.SimpleText("[" .. entry.serial .. "]", "ixSmallFont", SScale(4), SScale(14), COL_FAINT, 0, 0)

				draw.SimpleText(entry.buyer and entry.buyer.name or "?", "ixSmallFont",
					C_ITEM, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)

				local hText, hCol = holderSummary(entry)
				draw.SimpleText(hText, "ixSmallFont", C_ITEM + C_BUY, h / 2, hCol, 0, TEXT_ALIGN_CENTER)

				draw.SimpleText(fmtTime(entry.boughtAt), "ixSmallFont",
					C_ITEM + C_BUY + C_HOLD, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
			end

			row.OnMousePressed = function(_, mc)
				if (mc == MOUSE_LEFT) then openDetail(entry) end
			end
		end
	end

	frame.rebuild = rebuild
	search.OnValueChange = function(_, v) rebuild(v) end
	rebuild("")
end

-- ============================================================
--  Recepción del payload del servidor
-- ============================================================
net.Receive("traderlogs_Open", function()
	local len  = net.ReadUInt(32)
	local data = net.ReadData(len)
	local json = util.Decompress(data)
	if (not json) then return end

	local entries = util.JSONToTable(json) or {}
	openPanel(entries)
end)

-- ============================================================
--  DUPE SCANNER — panel general de objetos duplicados
-- ============================================================

local REASON_LABELS = {
	multi_inv   = "EN MÚLTIPLES INVENTARIOS",
	serial_dupe = "SERIAL DUPLICADO",
	ghost       = "ÍTEM FANTASMA",
}
local REASON_COLORS = {
	multi_inv   = Color(220, 50, 50),
	serial_dupe = Color(220, 130, 40),
	ghost       = Color(180, 80, 200),
}

local function openDupeDetail(entry)
	if (IsValid(ix.traderlogs._dupeDetail)) then ix.traderlogs._dupeDetail:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W  = math.min(SScale(400), sw - SScale(40))
	local H  = math.min(SScale(380), sh - SScale(40))
	local SP = SScale(8)
	local reasonCol = REASON_COLORS[entry.reason] or COL_RED

	local modal = vgui.Create("DFrame")
	ix.traderlogs._dupeDetail = modal
	modal:SetSize(W, H); modal:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	modal:SetTitle(""); modal:SetDraggable(true)
	modal:ShowCloseButton(false); modal:MakePopup(); modal:SetDeleteOnClose(true)
	modal.Paint = function(s, w, h) paintFloatingFrame(s, w, h, reasonCol) end

	local title = modal:Add("DLabel")
	title:SetPos(SP, SP); title:SetSize(W - SScale(20), SScale(20))
	title:SetText(entry.itemName .. "  #" .. (entry.itemID or "?"))
	title:SetFont("Metro UI.Button"); title:SetTextColor(COL_TEXT)

	local subtitle = modal:Add("DLabel")
	subtitle:SetPos(SP, SScale(28)); subtitle:SetSize(W - SScale(20), SScale(14))
	subtitle:SetFont("ixSmallFont")
	if (entry.resolved) then
		subtitle:SetText("RESUELTO por " .. (entry.resolvedBy or "?"))
		subtitle:SetTextColor(COL_GREEN)
	elseif (entry.live) then
		subtitle:SetText(REASON_LABELS[entry.reason] or entry.reason)
		subtitle:SetTextColor(reasonCol)
	else
		subtitle:SetText((REASON_LABELS[entry.reason] or entry.reason) .. "  (histórico)")
		subtitle:SetTextColor(COL_FAINT)
	end

	local infoLine = modal:Add("DLabel")
	infoLine:SetPos(SP, SScale(42)); infoLine:SetSize(W - SScale(20), SScale(12))
	infoLine:SetFont("ixSmallFont")
	infoLine:SetTextColor(COL_FAINT)
	local extra = entry.category or ""
	if (entry.serial) then extra = extra .. "  ·  Serial: " .. entry.serial end
	if (entry.claimedPos) then extra = extra .. "  ·  Pos: " .. entry.claimedPos end
	if (entry.detectedAt and entry.detectedAt > 0) then extra = extra .. "  ·  " .. fmtTime(entry.detectedAt) end
	infoLine:SetText(extra)

	local scroll = modal:Add("DScrollPanel")
	scroll:SetPos(SP, SScale(58)); scroll:SetSize(W - SP * 2, H - SScale(58) - SScale(22) - SP)
	scroll:GetVBar():SetWide(SScale(4))

	-- Sección de poseedores
	local secHdr = scroll:Add("DPanel")
	secHdr:Dock(TOP); secHdr:DockMargin(0, SScale(2), 0, SScale(2)); secHdr:SetTall(SScale(14))
	secHdr.Paint = function(_, w, h)
		surface.SetDrawColor(66, 66, 66, 200); surface.DrawRect(0, h - 1, w, 1)
		draw.SimpleText("POSEEDORES (" .. #entry.holders .. ")", "Metro UI.CharFields",
			SScale(2), h / 2 - 1, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	for _, h in ipairs(entry.holders or {}) do
		local row = scroll:Add("DPanel")
		row:Dock(TOP); row:DockMargin(0, 0, 0, SScale(2)); row:SetTall(SScale(20))
		local holderRef = h
		row.Paint = function(_, w, rh)
			surface.SetDrawColor(66, 66, 66, 14); surface.DrawRect(0, 0, w, rh)
			surface.SetDrawColor(reasonCol.r, reasonCol.g, reasonCol.b, 60)
			surface.DrawRect(0, 0, SScale(3), rh)

			local onTag = holderRef.online and " · ONLINE" or ""
			draw.SimpleText((holderRef.name or "?") .. "   " .. (holderRef.steamID or "?") .. onTag,
				"ixSmallFont", SScale(8), SScale(2), COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local invTag = holderRef.invID and ("Inv #" .. holderRef.invID) or (holderRef.itemDBID and ("Item #" .. holderRef.itemDBID) or "")
			draw.SimpleText(invTag, "ixSmallFont", SScale(8), SScale(11), COL_FAINT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- Botón de borrar por instancia (solo multi_inv y serial_dupe con itemDBID)
		if (holderRef.itemDBID) then
			local del = row:Add("DButton")
			del:Dock(RIGHT); del:DockMargin(SScale(2), SScale(2), SScale(2), SScale(2))
			del:SetWide(SScale(46))
			del:SetText("Eliminar"); del:SetFont("ixSmallFont")
			del:SetTextColor(Color(220, 140, 140))
			del.Paint = function(s, w2, h2)
				surface.SetDrawColor(150, 40, 40, s:IsHovered() and 40 or 14)
				surface.DrawRect(0, 0, w2, h2)
				surface.SetDrawColor(150, 40, 40, s:IsHovered() and 100 or 40)
				surface.DrawOutlinedRect(0, 0, w2, h2, 1)
			end
			del.DoClick = function()
				Derma_Query(
					"¿Eliminar ítem #" .. holderRef.itemDBID .. "?",
					"Confirmar borrado",
					"Eliminar", function()
						net.Start("dupescanner_Delete")
							net.WriteUInt(holderRef.itemDBID, 32)
						net.SendToServer()
						if (IsValid(modal)) then modal:Remove() end
					end,
					"Cancelar", function() end
				)
			end
		end
	end

	-- Botón general de eliminar (por item.id principal)
	local BY = H - SScale(22) - SP
	local delAll = makeMetroBtn(modal, "Eliminar ítem #" .. (entry.itemID or "?"), 150, 40, 40, function()
		Derma_Query(
			"¿Eliminar el ítem #" .. (entry.itemID or "?") .. " del servidor?",
			"Confirmar borrado",
			"Eliminar", function()
				net.Start("dupescanner_Delete")
					net.WriteUInt(entry.itemID or 0, 32)
				net.SendToServer()
				if (IsValid(modal)) then modal:Remove() end
			end,
			"Cancelar", function() end
		)
	end)
	delAll:SetPos(SP, BY); delAll:SetSize((W - SP * 3) / 2, SScale(16))

	local closeBtn = makeMetroBtn(modal, "Cerrar", 60, 60, 60, function() modal:Remove() end)
	closeBtn:SetPos(SP + (W - SP * 3) / 2 + SP, BY); closeBtn:SetSize((W - SP * 3) / 2, SScale(16))
end

local function openDupePanel(dupes)
	if (IsValid(ix.traderlogs._dupeFrame)) then ix.traderlogs._dupeFrame:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W  = math.min(SScale(700), sw - SScale(40))
	local H  = math.min(SScale(460), sh - SScale(40))
	local SP = SScale(8)

	local frame = vgui.Create("DFrame")
	ix.traderlogs._dupeFrame = frame
	frame:SetSize(W, H); frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetTitle(""); frame:SetDraggable(true)
	frame:ShowCloseButton(false); frame:MakePopup(); frame:SetDeleteOnClose(true)
	frame.Paint = function(s, w, h) paintFloatingFrame(s, w, h, COL_RED) end
	frame.OnRemove = function()
		if (IsValid(ix.traderlogs._dupeDetail)) then ix.traderlogs._dupeDetail:Remove() end
	end

	local title = frame:Add("DLabel")
	title:SetPos(SP, SP); title:SetSize(W - SScale(120), SScale(20))
	title:SetText("Dupe Scanner — Objetos Duplicados"); title:SetFont("Metro UI.Button")
	title:SetTextColor(COL_TEXT)

	local closeX = makeMetroBtn(frame, "X", 120, 30, 30, function() frame:Remove() end)
	closeX:SetPos(W - SScale(28), SP); closeX:SetSize(SScale(20), SScale(16))

	-- Contadores
	local liveCount, resolvedCount, histCount = 0, 0, 0
	for _, e in ipairs(dupes) do
		if (e.resolved) then resolvedCount = resolvedCount + 1
		elseif (e.live) then liveCount = liveCount + 1
		else histCount = histCount + 1
		end
	end

	local stats = frame:Add("DLabel")
	stats:SetPos(SP, SScale(30)); stats:SetSize(W - SP * 2, SScale(12))
	stats:SetFont("ixSmallFont")
	if (liveCount == 0 and histCount == 0 and resolvedCount == 0) then
		stats:SetText("No se han detectado objetos duplicados. Todo limpio.")
		stats:SetTextColor(COL_GREEN)
	else
		stats:SetText(liveCount .. " activo(s)   ·   " .. histCount .. " histórico(s)   ·   " .. resolvedCount .. " resuelto(s)")
		stats:SetTextColor(liveCount > 0 and COL_RED or COL_DIM)
	end

	-- Estado de filtros
	local filterLive     = false
	local filterResolved = false

	-- Buscador
	local search = frame:Add("DTextEntry")
	search:SetPos(SP, SScale(44)); search:SetSize(W - SP * 2, SScale(16))
	search:SetFont("Metro UI.CharFields"); search.Paint = paintDarkEntry
	search:SetUpdateOnType(true)
	search:SetPlaceholderText("Buscar por nombre, jugador, serial, tipo...")

	-- Toggles de filtro
	local FBTN_H = SScale(16)
	local FBTN_Y = SScale(63)

	local function makeToggle(parent, text, x, w2, r, g, b, getter, setter)
		local btn = parent:Add("DButton")
		btn:SetPos(x, FBTN_Y); btn:SetSize(w2, FBTN_H)
		btn:SetText(""); btn:SetFont("ixSmallFont")
		btn.Paint = function(s, w, h)
			local on = getter()
			surface.SetDrawColor(r, g, b, on and 50 or (s:IsHovered() and 18 or 8))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(r, g, b, on and 180 or (s:IsHovered() and 60 or 30))
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(text, "ixSmallFont", w / 2, h / 2,
				on and Color(math.min(r + 100, 255), math.min(g + 100, 255), math.min(b + 100, 255))
				or Color(140, 140, 140),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function()
			setter(not getter())
			frame.rebuild(search:GetValue())
		end
		return btn
	end

	makeToggle(frame, "Solo activos", SP, SScale(86), 220, 50, 50,
		function() return filterLive end,
		function(v) filterLive = v end)

	makeToggle(frame, "Resueltos", SP + SScale(90), SScale(76), 80, 180, 90,
		function() return filterResolved end,
		function(v) filterResolved = v end)

	-- Cabecera
	local LSTW   = W - SP * 2
	local C_NAME = math.floor(LSTW * 0.28)
	local C_TYPE = math.floor(LSTW * 0.24)
	local C_HOLD = math.floor(LSTW * 0.22)
	local C_STAT = math.floor(LSTW * 0.14)
	local C_CNT  = LSTW - C_NAME - C_TYPE - C_HOLD - C_STAT

	local hdr = frame:Add("DPanel")
	hdr:SetPos(SP, SScale(82)); hdr:SetSize(LSTW, SScale(16))
	hdr.Paint = function(_, w, h)
		surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 120); surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("Ítem [#ID]",   "ixSmallFont", SScale(4), h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Tipo",         "ixSmallFont", C_NAME, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Poseedor(es)", "ixSmallFont", C_NAME + C_TYPE, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Estado",       "ixSmallFont", C_NAME + C_TYPE + C_HOLD, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
		draw.SimpleText("Copias",       "ixSmallFont", C_NAME + C_TYPE + C_HOLD + C_STAT, h / 2, COL_DIM, 0, TEXT_ALIGN_CENTER)
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:SetPos(SP, SScale(98)); scroll:SetSize(LSTW, H - SScale(98) - SP)
	scroll:GetVBar():SetWide(SScale(4))

	local function rebuild(filter)
		scroll:Clear()
		filter = (filter or ""):lower()

		for _, entry in ipairs(dupes) do
			-- Filtros de toggle
			if (filterLive and not entry.live) then continue end
			if (filterResolved and not entry.resolved) then continue end

			local holderNames = {}
			for _, h in ipairs(entry.holders or {}) do holderNames[#holderNames + 1] = h.name or "?" end
			local holdersText = table.concat(holderNames, ", ")

			local hay = (entry.itemName .. " " .. (entry.uniqueID or "") .. " " ..
				(entry.serial or "") .. " " .. holdersText .. " " .. (entry.reason or "")):lower()
			-- Incluir SteamIDs en la búsqueda
			for _, h in ipairs(entry.holders or {}) do
				hay = hay .. " " .. (h.steamID or "")
			end
			hay = hay:lower()
			if (filter != "" and not hay:find(filter, 1, true)) then continue end

			local reasonCol = REASON_COLORS[entry.reason] or COL_RED
			local statusText, statusCol
			if (entry.resolved) then
				statusText = "Resuelto"
				statusCol  = COL_GREEN
			elseif (entry.live) then
				statusText = "ACTIVO"
				statusCol  = COL_RED
			else
				statusText = "Histórico"
				statusCol  = COL_FAINT
			end

			local row = scroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 0, 0, SScale(2)); row:SetTall(SScale(24))
			row:SetCursor("hand")

			row.Paint = function(me, w, h)
				local bgAlpha = entry.resolved and 8 or (entry.live and 20 or 10)
				surface.SetDrawColor(reasonCol.r, reasonCol.g, reasonCol.b, bgAlpha)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(reasonCol.r, reasonCol.g, reasonCol.b, entry.live and 220 or 80)
				surface.DrawRect(0, 0, SScale(3), h)
				if (me:IsHovered()) then
					surface.SetDrawColor(255, 255, 255, 8); surface.DrawRect(0, 0, w, h)
				end
				surface.SetDrawColor(66, 66, 66, me:IsHovered() and 66 or 33)
				surface.DrawOutlinedRect(0, 0, w, h, 1)

				local nameCol = entry.live and COL_RED or (entry.resolved and COL_DIM or COL_TEXT)
				draw.SimpleText(entry.itemName, "ixSmallFont", SScale(4), SScale(5), nameCol, 0, 0)
				draw.SimpleText("#" .. (entry.itemID or "?"), "ixSmallFont", SScale(4), SScale(14), COL_FAINT, 0, 0)

				draw.SimpleText(REASON_LABELS[entry.reason] or entry.reason, "ixSmallFont",
					C_NAME, h / 2, entry.live and reasonCol or COL_FAINT, 0, TEXT_ALIGN_CENTER)

				local hText = holdersText
				if (#holderNames > 2) then hText = holderNames[1] .. " + " .. (#holderNames - 1) .. " más" end
				draw.SimpleText(hText, "ixSmallFont", C_NAME + C_TYPE, h / 2, COL_TEXT, 0, TEXT_ALIGN_CENTER)

				draw.SimpleText(statusText, "ixSmallFont",
					C_NAME + C_TYPE + C_HOLD, h / 2, statusCol, 0, TEXT_ALIGN_CENTER)

				draw.SimpleText(tostring(entry.count or "?"), "ixSmallFont",
					C_NAME + C_TYPE + C_HOLD + C_STAT, h / 2, entry.live and COL_RED or COL_FAINT, 0, TEXT_ALIGN_CENTER)
			end

			row.OnMousePressed = function(_, mc)
				if (mc == MOUSE_LEFT) then openDupeDetail(entry) end
			end
		end
	end

	frame.rebuild = rebuild
	search.OnValueChange = function(_, v) rebuild(v) end
	rebuild("")
end

net.Receive("dupescanner_Open", function()
	local len  = net.ReadUInt(32)
	local data = net.ReadData(len)
	local json = util.Decompress(data)
	if (not json) then return end

	local dupes = util.JSONToTable(json) or {}
	openDupePanel(dupes)
end)
