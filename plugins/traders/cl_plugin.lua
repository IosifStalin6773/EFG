-- ============================================================
--  traders  |  cl_plugin.lua  (CLIENT)
--  UI rediseñada al estilo MetroUI (ix_invkey / metrocrafting)
-- ============================================================

if (not CLIENT) then return end

-- ── Polyfill SetBounds ────────────────────────────────────────────────────────
local _PNL = FindMetaTable("Panel")
if (_PNL and not _PNL.SetBounds) then
	_PNL.SetBounds = function(self, x, y, w, h)
		self:SetPos(x, y); self:SetSize(w, h); return self
	end
end

-- ── Texturas MetroUI ──────────────────────────────────────────────────────────
local textures = {
	menu3 = ix.util.GetMaterial("efgui/spawnmenu/Menu/3.jpg"),
	menu2 = ix.util.GetMaterial("efgui/spawnmenu/Menu/2.png"),
	menu1 = ix.util.GetMaterial("efgui/spawnmenu/Menu/1.png"),
	card  = ix.util.GetMaterial("efgui/mainmenu_card.png", "noclamp smooth"),
}

-- ── Iconos de facción ─────────────────────────────────────────────────────────
local TRADER_FACTION_ICONS = {
	prapor      = ix.util.GetMaterial("efgui/traders/prapor.png",       "noclamp smooth"),
	therapist   = ix.util.GetMaterial("efgui/traders/therapist.png",     "noclamp smooth"),
	fence       = ix.util.GetMaterial("efgui/traders/fence.png",       "noclamp smooth"),
	skier       = ix.util.GetMaterial("efgui/traders/skier.png",     "noclamp smooth"),
	peacekeeper = ix.util.GetMaterial("efgui/traders/peacekeeper.png",       "noclamp smooth"),
	mechanic    = ix.util.GetMaterial("efgui/traders/mechanic.png",     "noclamp smooth"),
	ragman      = ix.util.GetMaterial("efgui/traders/ragman.png",   "noclamp smooth"),
	jaeger      = ix.util.GetMaterial("efgui/traders/jaeger.png",     "noclamp smooth"),
	staff       = ix.util.GetMaterial("efgui/traders/staff.png", "noclamp smooth"),
}

-- ── Fuentes ───────────────────────────────────────────────────────────────────
local function registerFonts()
	surface.CreateFont("Metro UI.Button", {
		font = "MBender", extended = true,
		size = SScale(10), weight = 500, antialias = true,
	})
	surface.CreateFont("Metro UI.CharFields", {
		font = "MBender", extended = true,
		size = SScale(8), weight = 500, antialias = true,
	})
	surface.CreateFont("Metro UI.Button2", {
		font = "MBender", extended = true,
		size = SScale(15), weight = 500, antialias = true,
	})
	surface.CreateFont("ixSmallFont", {
		font = "MBender", extended = true,
		size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "traders.Fonts", registerFonts)

-- ── Colores por facción ───────────────────────────────────────────────────────
local FACTION_COLORS = {
	prapor      = Color(170, 60, 50),
	therapist   = Color(200, 80, 120),
	fence       = Color(120, 120, 120),
	skier       = Color(232, 131, 58),
	peacekeeper = Color(112, 128, 130),
	mechanic    = Color(90, 170, 90),
	ragman      = Color(150, 90, 200),
	jaeger      = Color(50, 140, 80),
	staff       = Color(220, 220, 60),
}
local FACTION_NAMES = {
	prapor = "Prapor", therapist = "Therapist", fence = "Fence", skier = "Skier",
	peacekeeper = "Peacekeeper", mechanic = "Mechanic", ragman = "Ragman", jaeger = "Jaeger",
	staff = "Staff",
}
local FACTION_ORDER = {"prapor", "therapist", "fence", "skier", "peacekeeper", "mechanic", "ragman", "jaeger", "staff"}
local function getFactionColor(k) return FACTION_COLORS[k] or Color(180, 180, 180) end

-- ── Constantes de layout ──────────────────────────────────────────────────────
local PAD    = 8
local GAP    = 6
local SEC_H  = 20
local ROW_H  = 58
local REPBAR = 6
-- Las constantes responsivas de filas (S_PRICE_W, S_BTN_W2, etc.) se declaran
-- como locals dentro de buildTradeContent usando SScale() para ser responsivas.

-- ── Helpers de dibujo ─────────────────────────────────────────────────────────
-- Pizarra: cabeceras y paneles con el kit de efg_ui (chaflán y tokens)
local function drawSectionHdr(w, h, text)
	ix.efgui.DrawHeader(0, 0, w, h, text)
end

local function paintPanel(me, w, h)
	ix.util.DrawBlur(me, 5)
	ix.efgui.DrawPanel(0, 0, w, h, 215)
end

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

local function paintFloatingFrame(self, w, h, fc, factionKey)
	ix.util.DrawBlur(self, 5)
	ix.efgui.DrawPanel(0, 0, w, h, 235)
	surface.SetDrawColor(fc.r, fc.g, fc.b, 220)
	surface.DrawRect(0, 0, w * 0.6, 2)
	local icon = factionKey and TRADER_FACTION_ICONS[factionKey]
	if (icon) then
		surface.SetDrawColor(255, 255, 255, 180)
		surface.SetMaterial(icon)
		surface.DrawTexturedRect(w - SScale(16) - PAD, PAD, SScale(16), SScale(16))
	end
end

-- Reestiliza un DNumSlider (el de "Cantidad" en los modales de comprar/vender)
-- con el mismo look oscuro + acento de color que el resto de la UI de traders,
-- en vez del control gris por defecto de GMod.
local function styleSlider(slider, accent)
	accent = accent or ix.efgui.color.accent

	if (IsValid(slider.Label)) then
		slider.Label:SetFont("Metro UI.CharFields")
		slider.Label:SetTextColor(Color(200, 200, 200))
	end

	if (IsValid(slider.TextArea)) then
		slider.TextArea:SetFont("Metro UI.CharFields")
		slider.TextArea:SetPaintBackground(false)
		slider.TextArea.Paint = function(self, w, h)
			self:DrawTextEntryText(Color(222, 224, 212), Color(accent.r, accent.g, accent.b, 150), Color(222, 224, 212))
		end
	end

	if (IsValid(slider.Slider)) then
		local track = slider.Slider

		-- Groove oscura con relleno de progreso hasta la posición del knob,
		-- igual que las barras del resto de la UI.
		track.Paint = function(self, w, h)
			local trackH = 4
			local y = h / 2 - trackH / 2
			local frac = self:GetSlideX() or 0

			surface.SetDrawColor(20, 20, 16, 220)
			surface.DrawRect(0, y, w, trackH)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 210)
			surface.DrawRect(0, y, w * frac, trackH)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 90)
			surface.DrawOutlinedRect(0, y, w, trackH, 1)
		end

		-- El knob es un campo directo (self.Knob), no un getter: Slider no expone GetKnob().
		local knob = track.Knob
		if (IsValid(knob)) then
			knob.Paint = function(self, w, h)
				local kw, kh = 6, h - 1 -- barra vertical estrecha, centrada en el botón de 15x15
				surface.SetDrawColor(10, 10, 8, 255)
				surface.DrawRect(w / 2 - kw / 2, h / 2 - kh / 2, kw, kh)
				surface.SetDrawColor(accent)
				surface.DrawOutlinedRect(w / 2 - kw / 2, h / 2 - kh / 2, kw, kh, 1)
			end
		end
	end
end

-- Declaración adelantada: openItemPreview llama a openBuyModal, que se define más
-- abajo. Sin esto, la referencia resolvería a un global nil y crashearía al pulsar
-- "Comprar" desde el preview con un slot de cantidad > 1.
local openBuyModal

-- ── Preview modal de ítem ─────────────────────────────────────────────────────
local function openItemPreview(slot, s)
	-- Cerrar preview anterior si existe
	if (IsValid(ix.traders._previewFrame)) then
		ix.traders._previewFrame:Remove()
	end

	local itemData  = ix.item.list[slot.itemID]
	if (not itemData) then return end

	local repLevel  = ix.traders.GetRepLevel(s.rep)
	local discount  = repLevel.discount
	local locked    = (s.rep < (slot.minRep or 0))
	local noStock   = (slot.qty <= 0)
	local scarcityMult = ix.traders.GetStockPriceMultiplier(slot.qty, slot.maxQty)
	local basePrice = slot.price * scarcityMult
	local dispPrice = locked and math.max(1, math.floor(basePrice)) or math.max(1, math.floor(basePrice * (1 - discount / 100)))
	local condPct   = slot.condPct or 100
	local usedPrice = (condPct < 100 and not locked) and math.max(1, math.floor(dispPrice * condPct / 100)) or nil

	local fk = s.factionKey
	local fc = getFactionColor(fk)
	local sw, sh = ScrW(), ScrH()
	local PW = SScale(280)
	local PH = SScale(340)
	-- Reservar espacio para las líneas opcionales de estado/precio dañado
	if (slot.condition and slot.condition != "") then PH = PH + SScale(16) end
	if (usedPrice) then PH = PH + SScale(18) end

	local frame = vgui.Create("EditablePanel")
	frame:SetSize(PW, PH)
	frame:SetPos(sw / 2 - PW / 2, sh / 2 - PH / 2)
	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.2)
	frame:MakePopup()
	frame._removing = false
	frame.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(33, 33, 33, 230)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, 3)
		surface.SetDrawColor(66, 66, 66, 88)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end

	local function closePreview()
		if (frame._removing) then return end
		frame._removing = true
		frame:AlphaTo(0, 0.2, 0, function()
			if (IsValid(frame)) then frame:Remove() end
		end)
	end

	-- Modelo 3D del ítem
	local modelH = SScale(120)
	local mdl = frame:Add("DModelPanel")
	mdl:SetPos(SScale(6), SScale(10))
	mdl:SetSize(PW - SScale(12), modelH)
	mdl:SetModel(itemData.model or "models/error.mdl")
	mdl:SetCamPos(Vector(30, 30, 20))
	mdl:SetLookAt(Vector(0, 0, 5))
	mdl.LayoutEntity = function() end   -- sin rotación automática

	local infoY = SScale(10) + modelH + SScale(6)

	-- Nombre
	local lName = frame:Add("DLabel")
	lName:SetPos(SScale(8), infoY)
	lName:SetSize(PW - SScale(16), SScale(18))
	lName:SetText(itemData.name or slot.itemID)
	lName:SetFont("Metro UI.Button")
	lName:SetTextColor(Color(230, 230, 230))
	infoY = infoY + SScale(20)

	-- Categoría
	local lCat = frame:Add("DLabel")
	lCat:SetPos(SScale(8), infoY)
	lCat:SetSize(PW - SScale(16), SScale(14))
	lCat:SetText(itemData.category or "Sin categoría")
	lCat:SetFont("ixSmallFont")
	lCat:SetTextColor(Color(175, 177, 148))
	infoY = infoY + SScale(18)

	-- Etiqueta playerStock
	if (slot.playerStock) then
		local lPS = frame:Add("DLabel")
		lPS:SetPos(SScale(8), infoY)
		lPS:SetSize(PW - SScale(16), SScale(12))
		lPS:SetText("Vendido por jugador")
		lPS:SetFont("ixSmallFont")
		lPS:SetTextColor(Color(220, 140, 60))
		infoY = infoY + SScale(16)
	end

	-- Estado del próximo objeto a comprar (munición, usos… preservados de la venta)
	if (slot.condition and slot.condition != "") then
		local lCond = frame:Add("DLabel")
		lCond:SetPos(SScale(8), infoY)
		lCond:SetSize(PW - SScale(16), SScale(12))
		local usedTxt = "Estado: " .. slot.condition
		if ((slot.usedCount or 0) > 1) then
			usedTxt = usedTxt .. "  (" .. slot.usedCount .. " usadas)"
		end
		lCond:SetText(usedTxt)
		lCond:SetFont("ixSmallFont")
		lCond:SetTextColor(Color(120, 200, 120))
		infoY = infoY + SScale(16)
	end

	-- Descripción con wrap
	local descH = SScale(48)
	local lDesc = frame:Add("DLabel")
	lDesc:SetPos(SScale(8), infoY)
	lDesc:SetSize(PW - SScale(16), descH)
	lDesc:SetText(itemData.description or "Sin descripción.")
	lDesc:SetFont("ixSmallFont")
	lDesc:SetTextColor(Color(160, 160, 160))
	lDesc:SetWrap(true)
	infoY = infoY + descH + SScale(6)

	-- Stock
	local lStock = frame:Add("DLabel")
	lStock:SetPos(SScale(8), infoY)
	lStock:SetSize(PW - SScale(16), SScale(13))
	lStock:SetText("Stock: " .. slot.qty .. " / " .. slot.maxQty)
	lStock:SetFont("ixSmallFont")
	lStock:SetTextColor(Color(120, 120, 120))
	infoY = infoY + SScale(16)

	-- Precio
	local priceText = dispPrice .. " RUB"
	if (discount > 0 and not locked) then
		priceText = priceText .. "  (−" .. discount .. "%)"
	end
	local lPrice = frame:Add("DLabel")
	lPrice:SetPos(SScale(8), infoY)
	lPrice:SetSize(PW - SScale(16), SScale(16))
	lPrice:SetText(priceText)
	lPrice:SetFont("Metro UI.CharFields")
	lPrice:SetTextColor((discount > 0 and not locked) and Color(80, 200, 80) or Color(197, 199, 179))
	infoY = infoY + SScale(22)

	-- Precio reducido de la próxima unidad por estar dañada (durabilidad < 100%)
	if (usedPrice) then
		local lUsed = frame:Add("DLabel")
		lUsed:SetPos(SScale(8), infoY)
		lUsed:SetSize(PW - SScale(16), SScale(14))
		lUsed:SetText("Esta unidad: " .. usedPrice .. " RUB  (" .. condPct .. "%)")
		lUsed:SetFont("ixSmallFont")
		lUsed:SetTextColor(Color(120, 200, 120))
		infoY = infoY + SScale(18)
	end

	-- Botones
	local btnH   = SScale(28)
	local btnGap = SScale(4)

	if (not locked and not noStock) then
		-- Botón Comprar
		makeMetroBtn(frame, "Comprar", 66, 166, 66, function()
			if (slot.qty > 1) then
				openBuyModal(s, slot, itemData.name or slot.itemID, dispPrice)
			else
				net.Start("traders_Purchase")
					net.WriteEntity(s.ent)
					net.WriteString(slot.itemID)
					net.WriteUInt(1, 8)
				net.SendToServer()
			end
			closePreview()
		end):SetBounds(SScale(8), infoY, PW - SScale(16), btnH)
		infoY = infoY + btnH + btnGap
	elseif (noStock) then
		local lNS = frame:Add("DLabel")
		lNS:SetPos(SScale(8), infoY)
		lNS:SetSize(PW - SScale(16), btnH)
		lNS:SetText("Sin stock")
		lNS:SetFont("ixSmallFont")
		lNS:SetTextColor(Color(130, 130, 130))
		lNS:SetContentAlignment(5)
		infoY = infoY + btnH + btnGap
	end

	-- Botón Cerrar
	makeMetroBtn(frame, "Cerrar", 130, 30, 30, closePreview)
		:SetBounds(SScale(8), infoY, PW - SScale(16), btnH)

	ix.traders._previewFrame = frame
end

-- Precio total progresivo de comprar "qty" unidades de un slot: la escasez
-- (ver ix.traders.GetStockPriceMultiplier) se recalcula unidad a unidad según
-- el stock que iría quedando, igual que hace ahora el servidor al cobrar —
-- antes se multiplicaba el precio de la primera unidad por la cantidad, así
-- que comprar 10 de golpe salía al mismo precio por unidad que comprar 1.
local function ComputeProgressiveBuyTotal(slot, qty, discount)
	local total = 0
	local remaining = slot.qty
	for i = 1, qty do
		local scarcityMult = ix.traders.GetStockPriceMultiplier(remaining, slot.maxQty)
		total = total + math.max(1, math.floor(slot.price * scarcityMult * (1 - discount / 100)))
		remaining = remaining - 1
	end
	return total
end

-- ── Modal de compra con slider de cantidad ───────────────────────────────────
function openBuyModal(s, slot, itemName, dispPrice)
	if (IsValid(ix.traders._buyModal)) then
		ix.traders._buyModal:Remove()
	end

	local discount = ix.traders.GetRepLevel(s.rep).discount
	local maxBuy = math.min(slot.qty, 255)
	local hasCond = (slot.condition and slot.condition != "")
	local sw, sh = ScrW(), ScrH()
	local SP = SScale(8)
	local MW = SScale(240)
	local MH = hasCond and SScale(140) or SScale(120)

	local modal = vgui.Create("DFrame")
	ix.traders._buyModal = modal
	modal:SetSize(MW, MH)
	modal:SetPos(sw / 2 - MW / 2, sh / 2 - MH / 2)
	modal:SetTitle("")
	modal:SetDraggable(true)
	modal:ShowCloseButton(false)
	modal:MakePopup()
	modal:SetDeleteOnClose(true)
	modal.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 166, 66, 160); surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("Comprar " .. itemName, "Metro UI.Button",
			SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local slider = modal:Add("DNumSlider")
	slider:SetPos(SP, SScale(28))
	slider:SetSize(MW - SP * 2, SScale(28))
	slider:SetText("Cantidad")
	slider:SetMin(1)
	slider:SetMax(maxBuy)
	slider:SetDecimals(0)
	slider:SetValue(1)
	styleSlider(slider, Color(66, 166, 66))

	local totalLabel = modal:Add("DLabel")
	totalLabel:SetPos(SP, SScale(58))
	totalLabel:SetSize(MW - SP * 2, SScale(14))
	totalLabel:SetFont("Metro UI.CharFields")
	totalLabel:SetTextColor(Color(197, 199, 179))
	totalLabel:SetText("Total: " .. ComputeProgressiveBuyTotal(slot, 1, discount) .. " RUB")

	slider.OnValueChanged = function(_, val)
		local qty = math.Clamp(math.floor(val or 1), 1, maxBuy)
		if (IsValid(totalLabel)) then
			totalLabel:SetText("Total: " .. ComputeProgressiveBuyTotal(slot, qty, discount) .. " RUB")
		end
	end

	-- Aviso del estado de las unidades usadas (las primeras en venderse, FIFO)
	if (hasCond) then
		local condLabel = modal:Add("DLabel")
		condLabel:SetPos(SP, SScale(74))
		condLabel:SetSize(MW - SP * 2, SScale(14))
		condLabel:SetFont("ixSmallFont")
		condLabel:SetTextColor(Color(120, 200, 120))
		local condTxt = "Próxima: " .. slot.condition
		if ((slot.usedCount or 0) > 1) then
			condTxt = condTxt .. "  (" .. slot.usedCount .. " usadas)"
		end
		condLabel:SetText(condTxt)
	end

	local btnW = (MW - SP * 2 - SScale(6)) / 2
	local btnY = hasCond and SScale(100) or SScale(80)

	makeMetroBtn(modal, "Comprar", 66, 166, 66, function()
		local qty = math.Clamp(math.floor(slider:GetValue() or 1), 1, maxBuy)
		net.Start("traders_Purchase")
			net.WriteEntity(s.ent); net.WriteString(slot.itemID); net.WriteUInt(qty, 8)
		net.SendToServer()
		modal:Remove()
	end):SetBounds(SP, btnY, btnW, SScale(28))

	makeMetroBtn(modal, "Cancelar", 120, 30, 30, function()
		modal:Remove()
	end):SetBounds(SP + btnW + SScale(6), btnY, btnW, SScale(28))
end

-- ── Modal de venta con slider de cantidad ─────────────────────────────────────
local function openSellModal(s, uid, itemName, maxSell, unitPrice)
	if (IsValid(ix.traders._sellModal)) then
		ix.traders._sellModal:Remove()
	end

	unitPrice = unitPrice or 1

	local sw, sh = ScrW(), ScrH()
	local SP = SScale(8)
	local MW = SScale(240)
	local MH = SScale(120)

	local modal = vgui.Create("DFrame")
	ix.traders._sellModal = modal
	modal:SetSize(MW, MH)
	modal:SetPos(sw / 2 - MW / 2, sh / 2 - MH / 2)
	modal:SetTitle("")
	modal:SetDraggable(true)
	modal:ShowCloseButton(false)
	modal:MakePopup()
	modal:SetDeleteOnClose(true)
	modal.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(166, 100, 30, 160); surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("Vender " .. itemName, "Metro UI.Button",
			SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local slider = modal:Add("DNumSlider")
	slider:SetPos(SP, SScale(28))
	slider:SetSize(MW - SP * 2, SScale(28))
	slider:SetText("Cantidad")
	slider:SetMin(1)
	slider:SetMax(maxSell)
	slider:SetDecimals(0)
	slider:SetValue(maxSell)
	styleSlider(slider, Color(166, 100, 30))

	-- Total en vivo por la cantidad seleccionada (mismo precio unitario, ya
	-- rebajado por sobreoferta, que calculó la fila de la lista de venta).
	local totalLabel = modal:Add("DLabel")
	totalLabel:SetPos(SP, SScale(58))
	totalLabel:SetSize(MW - SP * 2, SScale(14))
	totalLabel:SetFont("Metro UI.CharFields")
	totalLabel:SetTextColor(Color(197, 199, 179))
	totalLabel:SetText("Total: " .. (unitPrice * maxSell) .. " RUB")

	slider.OnValueChanged = function(_, val)
		local qty = math.Clamp(math.floor(val or 1), 1, maxSell)
		if (IsValid(totalLabel)) then
			totalLabel:SetText("Total: " .. (unitPrice * qty) .. " RUB")
		end
	end

	local btnW = (MW - SP * 2 - SScale(6)) / 2
	local btnY = SScale(84)

	makeMetroBtn(modal, "Vender", 66, 166, 66, function()
		local qty = math.Clamp(math.floor(slider:GetValue() or 1), 1, maxSell)
		net.Start("traders_Sell")
			net.WriteEntity(s.ent); net.WriteString(uid); net.WriteUInt(qty, 8)
		net.SendToServer()
		modal:Remove()
	end):SetBounds(SP, btnY, btnW, SScale(28))

	makeMetroBtn(modal, "Cancelar", 120, 30, 30, function()
		modal:Remove()
	end):SetBounds(SP + btnW + SScale(6), btnY, btnW, SScale(28))
end

-- ── Estado compartido ─────────────────────────────────────────────────────────
ix.traders._state = ix.traders._state or {}

local function requestRefresh()
	local s = ix.traders._state
	if (s and IsValid(s.ent)) then
		net.Start("traders_DialogueAction")
			net.WriteEntity(s.ent)
			net.WriteString("trade")
		net.SendToServer()
	end
end

-- ============================================================
--  DIÁLOGO INICIAL  —  Sistema de conversación interactivo
-- ============================================================

-- Devuelve el saludo apropiado según facción y reputación del jugador
local function getTraderGreeting(fk, rep)
	local list = ix.traders.greetings and ix.traders.greetings[fk]
	if (not list) then return "Hola. ¿En qué puedo ayudarte?" end
	for _, entry in ipairs(list) do
		if (rep >= entry.min) then return entry.text end
	end
	return list[#list].text
end

-- Devuelve un elemento aleatorio de una tabla o un fallback si está vacía
local function pickRandom(t, fallback)
	if (not t or #t == 0) then return fallback or "" end
	return t[math.random(1, #t)]
end

net.Receive("traders_OpenDialogue", function()
	local traderEnt    = net.ReadEntity()
	local factionKey   = net.ReadString()
	local traderName   = net.ReadString()
	local rep          = net.ReadUInt(10)
	local money        = net.ReadUInt(32)
	local missionReady = net.ReadBool()
	local missionName  = net.ReadString()
	local deliverReady    = net.ReadBool()
	local deliverItemName = net.ReadString()

	if (not IsValid(traderEnt)) then return end
	if (IsValid(ix.traders._dialogueFrame))    then ix.traders._dialogueFrame:Remove() end
	if (IsValid(ix.traders._dialogueBotFrame)) then ix.traders._dialogueBotFrame:Remove() end

	local fc       = getFactionColor(factionKey)
	local repLevel = ix.traders.GetRepLevel(rep)
	local sw, sh   = ScrW(), ScrH()

	-- Dimensiones del panel (todo en SScale para ser responsivo)
	local W        = SScale(300)
	local HEADER_H = SScale(38)
	local SPEECH_H = SScale(62)
	local SEP_H    = SScale(1)
	local OPT_ROW  = SScale(11)
	local OPTS_Y   = HEADER_H + SPEECH_H + SScale(8)
	local H        = OPTS_Y + OPT_ROW * 7 + SScale(10)
	local OPTS_H   = H - OPTS_Y - SScale(6)

	-- Estado del typewriter (closure compartida entre Think y showPage)
	local typeTarget = ""
	local typeStart  = 0
	local typeDone   = false
	local typeShown  = ""
	local CHARS_SEC  = 40
	local speechLbl  = nil

	-- Textos aleatorios fijados al abrir el diálogo (consistentes en toda la sesión)
	local loreTxt  = ix.traders.lore[factionKey] or "No tengo nada que contar hoy."
	local talkTxt  = pickRandom(ix.traders.smalltalk and ix.traders.smalltalk[factionKey], "La zona sigue igual de jodida.")
	local newsTxt  = pickRandom(ix.traders.news, "Sin novedades que contar.")
	local greeting = getTraderGreeting(factionKey, rep)

	-- Árbol de páginas de diálogo
	local pages = {
		root = {
			text    = greeting,
			options = {
				{text = "¿Tienes algún encargo para mí?",       action   = "missions"},
				{text = "Quiero ver lo que tienes.",             action   = "trade"},
				{text = "¿Cómo van los negocios por aquí?",     nextPage = "smalltalk"},
				{text = "¿Qué se cuenta por la zona?",           nextPage = "news"},
				{text = "Cuéntame más sobre ti.",               nextPage = "lore"},
				{text = "Hasta luego.",                         action   = "close"},
			},
		},
		smalltalk = {
			text    = talkTxt,
			options = {
				{text = "¿Y qué más hay de nuevo?", nextPage = "news"},
				{text = "← Volver.",                nextPage = "root"},
			},
		},
		news = {
			text    = newsTxt,
			options = {
				{text = "Gracias por la información.", nextPage = "root"},
				{text = "Hasta luego.",               action   = "close"},
			},
		},
		lore = {
			text    = loreTxt,
			options = {
				{text = "¿Y el negocio te va bien con todo eso?", nextPage = "smalltalk"},
				{text = "← Volver.",                              nextPage = "root"},
			},
		},
	}

	-- Opción de entrega — el servidor ya verificó que la misión es de esta facción
	if (missionReady) then
		table.insert(pages.root.options, 1, {
			text   = "Tengo el encargo completado: " .. missionName,
			action = "turnin",
		})
	end

	-- Paso de entrega listo (aunque la misión no esté terminada del todo):
	-- entrega directa desde el diálogo en vez de tener que abrir el Tablón
	-- de misiones. Si al entregar se completa el último paso, el propio
	-- servidor (missions_Deliver → AdvanceStep) ya cierra la misión sola.
	if (deliverReady) then
		table.insert(pages.root.options, 1, {
			text   = "Tengo " .. deliverItemName .. " para la misión.",
			action = "deliverStep",
		})
	end

	-- Opción exclusiva de administradores: gestionar misiones desde el trader
	if (LocalPlayer():IsAdmin() and ix.missions and ix.missions.OpenAdmin) then
		table.insert(pages.root.options, #pages.root.options, {
			text = "[ADMIN] Gestionar misiones", action = "missionAdmin"
		})
	end

	-- Hook para que otros plugins añadan opciones al diálogo del trader
	hook.Run("TraderDialogueOptions", pages, traderEnt, factionKey)

	-- ── Cierre unificado de ambos frames ─────────────────────────────────────────
	local frameTop, frameBot
	local _closing = false
	local function closeAll()
		if (_closing) then return end
		_closing = true
		if (IsValid(frameTop)) then frameTop:Remove() end
		if (IsValid(frameBot)) then frameBot:Remove() end
	end

	-- ── Frame superior: nombre, reputación y rublos ────────────────────────────────
	frameTop = vgui.Create("EditablePanel")
	frameTop:SetSize(W, HEADER_H)
	frameTop:SetPos(sw / 2 - W / 2, 0)
	frameTop:SetAlpha(0); frameTop:AlphaTo(255, 0.25); frameTop:MakePopup()
	ix.traders._dialogueFrame    = frameTop

	frameTop.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		local icon = TRADER_FACTION_ICONS[factionKey]
		if (icon) then
			surface.SetDrawColor(255, 255, 255, 150)
			surface.SetMaterial(icon)
			surface.DrawTexturedRect(w - SScale(18) - PAD, PAD + SScale(2), SScale(16), SScale(16))
		end
		surface.SetDrawColor(66, 66, 66, 66)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local lblName = frameTop:Add("DLabel")
	lblName:SetPos(PAD, SScale(4))
	lblName:SetSize(W - SScale(26) - PAD * 2, SScale(18))
	lblName:SetText(traderName)
	lblName:SetFont("Metro UI.Button")
	lblName:SetTextColor(Color(225, 225, 225))

	local lblRepInfo = frameTop:Add("DLabel")
	lblRepInfo:SetPos(PAD, SScale(22))
	lblRepInfo:SetSize(W - SScale(26) - PAD * 2, SScale(16))
	lblRepInfo:SetText(repLevel.name .. "  •  " .. rep .. " / 1000  •  " .. money .. " RUB")
	lblRepInfo:SetFont("ixSmallFont")
	lblRepInfo:SetTextColor(repLevel.color)

	-- ── Frame inferior: conversación y opciones ───────────────────────────────────
	local BOT_SPEECH_H = SPEECH_H
	local BOT_OPTS_H   = OPT_ROW * 7 + SScale(6)
	local BOT_H        = BOT_SPEECH_H + SScale(8) + BOT_OPTS_H + SScale(10)

	frameBot = vgui.Create("EditablePanel")
	frameBot:SetSize(W, BOT_H)
	frameBot:SetPos(sw / 2 - W / 2, sh - BOT_H - SScale(6))
	frameBot:SetAlpha(0); frameBot:AlphaTo(255, 0.25); frameBot:MakePopup()
	ix.traders._dialogueBotFrame = frameBot

	frameBot.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(28, 28, 28, 242)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		-- Separador speech / opciones
		surface.SetDrawColor(fc.r, fc.g, fc.b, 70)
		surface.DrawRect(PAD, BOT_SPEECH_H + SScale(3), w - PAD * 2, SEP_H)
	end

	-- ── Área de texto del NPC con efecto typewriter ───────────────────────────────
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
			draw.SimpleText("clic para saltar >", "ixSmallFont",
				w - SScale(5), h - SScale(5),
				Color(70, 70, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	speechArea.OnMousePressed = function()
		typeDone   = true
		typeShown  = typeTarget
		if (IsValid(speechLbl)) then speechLbl:SetText(typeTarget) end
	end

	speechLbl = speechArea:Add("DLabel")
	speechLbl:SetPos(SScale(7), SScale(7))
	speechLbl:SetSize(speechArea:GetWide() - SScale(14), speechArea:GetTall() - SScale(14))
	speechLbl:SetFont("Metro UI.CharFields")
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

	-- ── Lista de opciones de respuesta ────────────────────────────────────────────
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

	-- Cambia la página activa del árbol de diálogo
	local function showPage(pageKey)
		local page = pages[pageKey]
		if (not page) then return end

		-- Lanzar typewriter
		typeTarget = page.text
		typeStart  = CurTime()
		typeDone   = false
		typeShown  = ""
		if (IsValid(speechLbl)) then speechLbl:SetText("") end

		-- Eliminar opciones anteriores
		for _, r in ipairs(optRows) do if (IsValid(r)) then r:Remove() end end
		optRows = {}

		for _, opt in ipairs(page.options) do
			local row     = optScroll:Add("DPanel")
			local optText = opt.text
			local optAct  = opt.action
			local optNext = opt.nextPage

			row:Dock(TOP)
			row:DockMargin(0, 0, 0, 0)
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
				draw.SimpleText(prefix .. optText, "Metro UI.CharFields",
					SScale(10), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			row.OnMousePressed = function()
				if (optAct == "trade") then
					closeAll()
					net.Start("traders_DialogueAction")
						net.WriteEntity(traderEnt)
						net.WriteString("trade")
					net.SendToServer()
				elseif (optAct == "missions") then
					closeAll()
					if (ix.missions and ix.missions.RequestList) then
						ix.missions.RequestList(traderEnt)
					end
				elseif (optAct == "turnin") then
					closeAll()
					net.Start("missions_TurnIn")
						net.WriteEntity(traderEnt)
					net.SendToServer()
				elseif (optAct == "deliverStep") then
					closeAll()
					net.Start("missions_Deliver")
						net.WriteEntity(traderEnt)
					net.SendToServer()
				elseif (optAct == "missionAdmin") then
					closeAll()
					if (ix.missions and ix.missions.OpenAdmin) then
						ix.missions.OpenAdmin(traderEnt)
					end
				elseif (optAct == "close") then
					closeAll()
				elseif (hook.Run("TraderDialogueAction", optAct, traderEnt, closeAll) == true) then
					-- Acción gestionada por un plugin externo via hook
				elseif (optNext) then
					showPage(optNext)
				end
			end

			table.insert(optRows, row)
		end

		-- Redimensionar frameBot al número real de opciones
		local newOptsH = OPT_ROW * #page.options
		local newBotH  = BOT_SPEECH_H + SScale(8) + newOptsH + SScale(10)
		if (IsValid(optScroll)) then
			optScroll:SetSize(W - PAD * 2, newOptsH)
		end
		if (IsValid(frameBot)) then
			frameBot:SetSize(W, newBotH)
			frameBot:SetPos(sw / 2 - W / 2, sh - newBotH - SScale(6))
		end
	end

	showPage("root")
end)

-- ============================================================
--  PANEL DE LORE
-- ============================================================

net.Receive("traders_OpenLore", function()
	local traderEnt = net.ReadEntity()
	local loreText  = net.ReadString()

	if (not IsValid(traderEnt)) then return end
	if (IsValid(ix.traders._loreFrame)) then ix.traders._loreFrame:Remove() end

	local fk     = traderEnt:GetNetVar("factionKey", "prapor")
	local name   = traderEnt:GetNetVar("traderName", "Comerciante")
	local fc     = getFactionColor(fk)
	local sw, sh = ScrW(), ScrH()
	local W, H   = 460, 240

	local frame = vgui.Create("EditablePanel")
	frame:SetSize(W, H); frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetAlpha(0); frame:AlphaTo(255, 0.25); frame:MakePopup()
	frame.Paint = function(self, w, h) paintFloatingFrame(self, w, h, fc, fk) end
	ix.traders._loreFrame = frame

	local lbl = frame:Add("DLabel")
	lbl:SetPos(PAD, PAD); lbl:SetSize(W - SScale(20) - PAD * 2, 20)
	lbl:SetText(name .. " dice..."); lbl:SetFont("Metro UI.Button")
	lbl:SetTextColor(Color(220, 220, 220))

	local sep = frame:Add("DPanel")
	sep:SetPos(PAD, PAD + 24); sep:SetSize(W - PAD * 2, 1)
	sep.Paint = function(_, w, h) surface.SetDrawColor(ix.efgui.color.line); surface.DrawRect(0, 0, w, h) end

	local txt = frame:Add("DLabel")
	txt:SetPos(PAD, PAD + 32); txt:SetSize(W - PAD * 2, H - PAD * 2 - 32 - 44)
	txt:SetText("\"" .. loreText .. "\""); txt:SetFont("Metro UI.CharFields")
	txt:SetTextColor(Color(185, 185, 185)); txt:SetWrap(true)

	makeMetroBtn(frame, "CLOSE X", 166, 66, 66, function() frame:Remove() end)
		:SetBounds(W - 110 - PAD, H - 36 - PAD, 110, 32)
end)

-- ============================================================
--  PANEL DE COMERCIO — contenido dinámico
-- ============================================================

local function buildTradeContent(frame, s)
	for _, v in ipairs(frame._dynamic or {}) do
		if (IsValid(v)) then v:Remove() end
	end
	frame._dynamic = {}
	local function reg(w) table.insert(frame._dynamic, w) end

	local repLevel = ix.traders.GetRepLevel(s.rep)
	local discount = repLevel.discount
	local sw, sh   = ScrW(), ScrH()

	-- ── Constantes responsivas (todo SScale) ──────────────────────────────────
	local SP    = SScale(6)    -- padding
	local SG    = SScale(4)    -- gap
	local SS    = SScale(20)   -- section header height
	local SR    = SScale(28)   -- row height
	local SRP   = SScale(5)    -- rep bar height
	local SVBAR = SScale(4)    -- scrollbar width
	-- Columnas de filas
	local S_BTN_W   = SScale(78)   -- botón Comprar / Vender
	local S_BTN_RM  = SScale(4)    -- margen derecho del botón
	local S_PRICE_W = SScale(72)   -- etiqueta precio
	local S_PAD     = SScale(6)    -- padding izquierdo de fila
	local S_GAP     = SScale(4)    -- gap entre secciones
	-- Altura de texto dentro de PerformLayout
	local SLH  = SScale(13)   -- label name height
	local SSH  = SScale(11)   -- label small height (stock, rep)
	local SNY  = SScale(2)    -- y del nombre
	local SSY  = SScale(15)   -- y del texto secundario (stock, rep)

	local TOP_H   = SScale(68)
	local BOT_H   = SScale(50)
	local PANEL_H = sh - TOP_H - BOT_H
	local avW     = sw - SScale(40)
	local COL_W   = math.floor((avW - SG) / 2)
	local LEFT_X  = SScale(20)
	local RIGHT_X = LEFT_X + COL_W + SG

	-- ── Info superior ─────────────────────────────────────────────────────────
	local lblTrader = frame:Add("DLabel")
	lblTrader:SetPos(LEFT_X, SScale(10)); lblTrader:SetSize(avW * 0.5, SScale(22))
	lblTrader:SetText(s.traderName); lblTrader:SetFont("Metro UI.Button")
	lblTrader:SetTextColor(Color(230, 230, 230))
	reg(lblTrader)

	local lblRep = frame:Add("DLabel")
	lblRep:SetPos(LEFT_X, SScale(34)); lblRep:SetSize(avW * 0.55, SScale(18))
	lblRep:SetText(repLevel.name .. "   " .. s.rep .. " / 1000")
	lblRep:SetFont("Metro UI.CharFields"); lblRep:SetTextColor(repLevel.color)
	reg(lblRep)

	local lblMoney = frame:Add("DLabel")
	lblMoney:SetPos(LEFT_X + avW * 0.55, SScale(34)); lblMoney:SetSize(avW * 0.45, SScale(18))
	lblMoney:SetText(s.money .. " RUB")
	lblMoney:SetFont("efgx.Num"); lblMoney:SetTextColor(ix.efgui.color.text)
	lblMoney:SetContentAlignment(6)
	reg(lblMoney)

	local repBar = frame:Add("DPanel")
	repBar:SetPos(LEFT_X, TOP_H - SRP - SScale(4)); repBar:SetSize(avW, SRP)
	repBar.Paint = function(_, w, h)
		-- medidor segmentado de reputación (un tramo por cada 100 puntos)
		ix.efgui.DrawMeter(0, 0, w, h, math.Clamp(s.rep / 1000, 0, 1), 10, repLevel.color)
	end
	reg(repBar)

	-- ── Helper: crea panel de columna con header y scroll ─────────────────────
	local function makeColumn(posX, label)
		local pnl = frame:Add("DPanel")
		pnl:SetPos(posX, TOP_H); pnl:SetSize(COL_W, PANEL_H)
		pnl.Paint = paintPanel; reg(pnl)

		local hdr = pnl:Add("DPanel")
		hdr:SetBounds(0, 0, COL_W, SS + SG)
		hdr.Paint = function(_, w, h) drawSectionHdr(w, h, label) end

		local scroll = pnl:Add("DScrollPanel")
		scroll:SetPos(SP, SS + SG * 2)
		scroll:SetSize(COL_W - SP * 2, PANEL_H - SS - SG * 3)
		scroll:GetVBar():SetWide(SVBAR)
		return scroll
	end

	-- ── Panel izquierdo: tienda ───────────────────────────────────────────────
	local scrollL = makeColumn(LEFT_X, "Tienda  —  " .. s.traderName)

	for _, slot in ipairs(s.traderInv) do
		local slotRef   = slot
		local itemData  = ix.item.list[slot.itemID]
		local itemName  = itemData and itemData.name or slot.itemID
		local locked    = (s.rep < (slot.minRep or 0))
		local scarcityMult = ix.traders.GetStockPriceMultiplier(slot.qty, slot.maxQty)
		local basePrice = slot.price * scarcityMult
		local dispPrice = locked and math.max(1, math.floor(basePrice)) or math.max(1, math.floor(basePrice * (1 - discount / 100)))
		local noStock   = (slot.qty <= 0)
		-- Precio de la próxima unidad si está dañada (durabilidad < 100%): más barata
		local condPct   = slot.condPct or 100
		local usedPrice = (condPct < 100 and not locked) and math.max(1, math.floor(dispPrice * condPct / 100)) or nil

		local row = scrollL:Add("DPanel")
		row:Dock(TOP); row:DockMargin(0, 0, 0, SG); row:SetTall(SR)
		row:SetCursor("hand")
		row.Paint = function(me, w, h)
			ix.util.DrawBlur(me, 5)
			surface.SetDrawColor(66, 66, 66, me:IsHovered() and 22 or 11)
			surface.DrawRect(0, 0, w, h)
			if (locked) then surface.SetDrawColor(110, 20, 20, 22); surface.DrawRect(0, 0, w, h) end
			if (slotRef.playerStock) then
				surface.SetDrawColor(220, 120, 30, 80)
				surface.DrawRect(0, 0, SScale(3), h)
			end
			surface.SetDrawColor(66, 66, 66, me:IsHovered() and 88 or 44)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		local lName = row:Add("DLabel")
		lName:SetFont("Metro UI.CharFields")
		lName:SetText((locked and "[R] " or "") .. itemName)
		lName:SetTextColor(locked and Color(100, 100, 100) or Color(210, 210, 210))

		local lStock = row:Add("DLabel")
		lStock:SetFont("ixSmallFont"); lStock:SetTextColor(Color(130, 130, 130))
		-- Añadir "• jugador" al texto de stock si es playerStock (sin widget extra)
		local stockTxt = "Stock: " .. slot.qty .. " / " .. slot.maxQty
		if (slot.playerStock) then stockTxt = stockTxt .. "  • jugador" end
		if (slot.condition and slot.condition != "") then stockTxt = stockTxt .. "  • " .. slot.condition end
		lStock:SetText(stockTxt)

		local lPrice = row:Add("DLabel")
		lPrice:SetFont("Metro UI.CharFields")
		lPrice:SetText((usedPrice or dispPrice) .. " B")
		lPrice:SetTextColor(usedPrice and Color(120, 200, 120)
			or ((discount > 0 and not locked) and Color(80, 200, 80) or Color(197, 199, 179)))
		lPrice:SetContentAlignment(6)

		local lRep = nil
		if (slot.minRep and slot.minRep > 0) then
			lRep = row:Add("DLabel")
			lRep:SetFont("ixSmallFont")
			lRep:SetText("Rep: " .. slot.minRep)
			lRep:SetTextColor(locked and Color(200, 80, 80) or Color(130, 130, 130))
			lRep:SetContentAlignment(6)
		end

		local actionWidget = nil
		if (not locked and not noStock) then
			actionWidget = makeMetroBtn(row, "Comprar", 66, 166, 66, function()
				if (slotRef.qty > 1) then
					openBuyModal(s, slotRef, itemName, dispPrice)
				else
					net.Start("traders_Purchase")
						net.WriteEntity(s.ent); net.WriteString(slot.itemID); net.WriteUInt(1, 8)
					net.SendToServer()
				end
			end)
		elseif (noStock) then
			actionWidget = row:Add("DLabel")
			actionWidget:SetFont("ixSmallFont"); actionWidget:SetText("Sin stock")
			actionWidget:SetTextColor(Color(130, 130, 130)); actionWidget:SetContentAlignment(5)
		end

		row.PerformLayout = function(me, w, h)
			local btnX   = w - S_BTN_RM - S_BTN_W
			local priceX = btnX - S_GAP - S_PRICE_W
			local nameW  = priceX - S_PAD - S_GAP

			lName:SetPos(S_PAD, SNY);   lName:SetSize(math.max(nameW, SScale(20)), SLH)
			lStock:SetPos(S_PAD, SSY);  lStock:SetSize(math.max(nameW, SScale(20)), SSH)
			lPrice:SetPos(priceX, SNY); lPrice:SetSize(S_PRICE_W, SLH)

			if (IsValid(lRep)) then
				lRep:SetPos(priceX, SSY); lRep:SetSize(S_PRICE_W, SSH)
			end
			if (IsValid(actionWidget)) then
				actionWidget:SetBounds(btnX, (h - SScale(26)) / 2, S_BTN_W, SScale(26))
			end
		end

		row.OnMousePressed = function(me, mc)
			if (mc == MOUSE_LEFT) then openItemPreview(slotRef, s) end
		end
	end

	-- ── Panel derecho: inventario del jugador ─────────────────────────────────
	local scrollR = makeColumn(RIGHT_X, "Tu inventario — Vender")

	local bwl = s.buyWhitelist or {}
	local hasBuyItems = (table.Count(bwl) > 0)

	if (not hasBuyItems) then
		local lNoBuy = scrollR:Add("DLabel")
		lNoBuy:Dock(TOP); lNoBuy:DockMargin(0, SScale(20), 0, 0); lNoBuy:SetTall(SScale(20))
		lNoBuy:SetText("Este comerciante no compra artículos.")
		lNoBuy:SetFont("ixSmallFont"); lNoBuy:SetTextColor(Color(130, 130, 130))
		lNoBuy:SetContentAlignment(5)
	end

	local char = LocalPlayer():GetCharacter()
	if (char and hasBuyItems) then
		local inv = char:GetInventory()
		if (inv) then
			-- Agrupar ítems del jugador por uniqueID para mostrar el total que posee.
			-- condSum acumula el factor de condición por unidad (durabilidad) para
			-- estimar una oferta de venta coherente con lo que pagará el servidor.
			local grouped = {}
			local condSum = {}
			local order   = {}
			for _, it in pairs(inv:GetItems()) do
				local uid      = it.uniqueID
				local itemData = ix.item.list[uid]
				-- Las instancias equipadas (arma, uniforme, mochila…) no se pueden
				-- vender puestas (ver traders_Sell en sv_plugin.lua), y las podridas
				-- (comida perecedera) tampoco — así que ni siquiera cuentan para la
				-- lista de venta.
				local isSpoiled = it.isPerishable and it:GetData("spoiled", false)
				if (itemData and not itemData.noBusiness and bwl[uid] and not it:GetData("equip") and not isSpoiled) then
					if (not grouped[uid]) then
						grouped[uid] = 0
						condSum[uid] = 0
						table.insert(order, uid)
					end
					-- Sumar "Amount" para contemplar ítems apilados (recursos, rublos, etc.)
					local amount = it:GetData("Amount", 1)
					grouped[uid] = grouped[uid] + amount
					condSum[uid] = condSum[uid] + ix.traders.GetConditionFactor(uid, it.data) * amount
				end
			end

			local repLevel  = ix.traders.GetRepLevel(s.rep)
			local sellBonus = repLevel.sellBonus or 0

			for _, uid in ipairs(order) do
				local count    = grouped[uid]
				local itemData = ix.item.list[uid]
				local slotBuyPrice, slotQty, slotMaxQty = nil, 0, 0
				for _, slot in ipairs(s.traderInv) do
					if (slot.itemID == uid) then
						slotBuyPrice = slot.buyPrice
						slotQty      = slot.qty
						slotMaxQty   = slot.maxQty
						break
					end
				end
				local baseBuyPrice = ix.traders.GetEffectiveBuyPrice(slotBuyPrice, uid)
				if (baseBuyPrice <= 0) then
					for _, slot in ipairs(s.traderInv) do
						if (slot.itemID == uid and slot.price > 0) then
							baseBuyPrice = math.max(1, math.floor(slot.price * 0.5))
							break
						end
					end
				end
				if (baseBuyPrice <= 0) then baseBuyPrice = 1 end
				-- Sobreoferta: si el trader ya tiene mucho stock de este ítem, paga
				-- menos por unidad (mismo cálculo que hará el servidor al vender).
				local oversupplyMult = ix.traders.GetSellToTraderMultiplier(slotQty, slotMaxQty)
				local unitSell  = math.max(1, math.floor(baseBuyPrice * (1 + sellBonus / 100) * oversupplyMult))
				-- Oferta media por unidad según la condición de lo que posee el jugador
				local avgFactor = (count > 0) and (condSum[uid] / count) or 1
				local sellPrice = math.max(1, math.floor(unitSell * avgFactor))
				local damaged   = (avgFactor < 0.999)

				local row = scrollR:Add("DPanel")
				row:Dock(TOP); row:DockMargin(0, 0, 0, SG); row:SetTall(SR)
				row.Paint = function(me, w, h)
					ix.util.DrawBlur(me, 5)
					surface.SetDrawColor(66, 66, 66, me:IsHovered() and 22 or 11)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(66, 66, 66, me:IsHovered() and 88 or 44)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end

				local lName = row:Add("DLabel")
				lName:SetFont("Metro UI.CharFields"); lName:SetTextColor(Color(210, 210, 210))
				lName:SetText((itemData.name or uid) .. (count > 1 and ("  x" .. count) or ""))

				local sellColor = damaged and Color(145, 148, 108)
					or ((sellBonus > 0) and Color(80, 200, 80) or Color(197, 199, 179))
				local lOffer = row:Add("DLabel")
				lOffer:SetFont("Metro UI.CharFields"); lOffer:SetTextColor(sellColor)
				lOffer:SetText((damaged and "~" or "") .. sellPrice .. " B"); lOffer:SetContentAlignment(5)

				-- Si tiene más de uno, al vender se abre un modal con un slider de cantidad
				local maxSell = math.min(count, 255)
				local itemName = itemData.name or uid

				local sellBtn = makeMetroBtn(row, "Vender", 166, 100, 30, function()
					if (maxSell > 1) then
						openSellModal(s, uid, itemName, maxSell, sellPrice)
					else
						net.Start("traders_Sell")
							net.WriteEntity(s.ent); net.WriteString(uid); net.WriteUInt(1, 8)
						net.SendToServer()
					end
				end)

				row.PerformLayout = function(me, w, h)
					local btnX   = w - S_BTN_RM - S_BTN_W
					local offerX = btnX - S_GAP - S_PRICE_W
					local nameW  = offerX - S_PAD - S_GAP

					lName:SetPos(S_PAD, SNY); lName:SetSize(math.max(nameW, SScale(20)), SLH)
					lOffer:SetPos(offerX, 0); lOffer:SetSize(S_PRICE_W, h)
					sellBtn:SetBounds(btnX, (h - SScale(26)) / 2, S_BTN_W, SScale(26))
				end
			end
		end
	end
end

-- ============================================================
--  PANEL DE COMERCIO — clase VGUI (pantalla completa MetroUI)
-- ============================================================

local TRADE_PANEL = {}
DEFINE_BASECLASS("Panel")

function TRADE_PANEL:Init()
	local s      = ix.traders._state
	local sw, sh = ScrW(), ScrH()

	self:SetPos(0, 0); self:SetSize(sw, sh)
	self:SetMouseInputEnabled(true)
	self:SetAlpha(0); self:AlphaTo(255, 0.25)
	self._dynamic = {}
	self._cardX   = sw

	-- CLOSE X animado
	self.closeBtn = self:Add("DButton")
	self.closeBtn:SetFont("Metro UI.CharFields")
	self.closeBtn:SetText("CLOSE X")
	self.closeBtn:SetTextColor(Color(200, 200, 200))
	self.closeBtn:SizeToContents()
	self.closeBtn.pY = -self.closeBtn:GetTall()
	self.closeBtn:SetPos(sw - self.closeBtn:GetWide() - SScale(6), self.closeBtn.pY)
	self.closeBtn.Paint = nil
	self.closeBtn.Think = function(me)
		me:SetTextColor(me:IsHovered() and Color(255, 66, 66) or Color(200, 200, 200))
		me:SetY(me.pY)
	end
	self.closeBtn:CreateAnimation(0.3, {
		index = 1, target = {pY = SScale(22)}, easing = "outQuint",
		Think = function(_, p) p:SetY(p.pY) end,
	})
	local selfRef = self
	self.closeBtn.DoClick = function() selfRef:Remove() end

	-- Hint SPACE
	self.closeHint = self:Add("EditablePanel")
	self.closeHint:SetSize(SScale(300), SScale(40))
	self.closeHint:SetPos(sw / 2 - SScale(150), sh)
	self.closeHint.pPos = sh
	self.closeHint.Paint = function(_, w, h)
		draw.Text({
			text = "PRESIONA \'ESPACIO\' PARA CERRAR", font = "ixSmallFont",
			pos = {w / 2, h / 2}, xalign = TEXT_ALIGN_CENTER, yalign = TEXT_ALIGN_CENTER,
			color = Color(255, 255, 255, 33),
		})
	end
	self.closeHint:CreateAnimation(0.8, {
		index = 1, target = {pPos = sh - SScale(37)}, easing = "outQuint",
		Think = function(_, p) p:SetY(p.pPos) end,
	})

	local botY = sh - SScale(42)
	makeMetroBtn(self, "↺ Refrescar", 66, 66, 66, requestRefresh)
		:SetBounds(SScale(20), botY, SScale(120), SScale(28))

	if (LocalPlayer():IsAdmin()) then
		makeMetroBtn(self, "Admin", 66, 66, 166, function()
			net.Start("traders_DialogueAction")
				net.WriteEntity(s.ent); net.WriteString("admin")
			net.SendToServer()
		end):SetBounds(SScale(148), botY, SScale(80), SScale(28))
	end

	self:MakePopup()
	buildTradeContent(self, s)
end

function TRADE_PANEL:Paint(w, h)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(color_white)
	surface.SetMaterial(textures.menu3); surface.DrawTexturedRect(0, 0, w, h)
	surface.SetDrawColor(color_white)
	surface.SetMaterial(textures.menu1); surface.DrawTexturedRect(0, 0, SScale(1046/3), SScale(39/3))
	surface.SetDrawColor(color_white)
	surface.SetMaterial(textures.menu2); surface.DrawTexturedRect(0, 0, SScale(1098/3), SScale(936/3))
	local bg0 = ix.efgui.color.bg0
	surface.SetDrawColor(bg0.r, bg0.g, bg0.b, 190); surface.DrawRect(0, 0, w, h)
end

function TRADE_PANEL:PaintOver(w, h)
	self._cardX = Lerp(math.ease.InOutCirc(0.2), self._cardX or w, w - SScale(886/5))
	surface.SetDrawColor(ix.efgui.color.accent)
	surface.SetMaterial(textures.card)
	surface.DrawTexturedRect(self._cardX, SScale(4), SScale(886/5), SScale(85/5))
	draw.Text({
		text = "COMERCIO", font = "Metro UI.Button2",
		pos = {self._cardX + SScale(40), SScale(5)},
		xalign = TEXT_ALIGN_LEFT, yalign = TEXT_ALIGN_TOP, color = color_white,
	})
end


function TRADE_PANEL:OnKeyCodePressed(keyCode)
	if (keyCode == KEY_SPACE or keyCode == KEY_ESCAPE) then self:Remove() end
end

function TRADE_PANEL:Remove()
	if (self._removing) then return end
	self._removing = true
	self:AlphaTo(0, 0.2, 0, function()
		if (IsValid(self)) then BaseClass.Remove(self) end
	end)
end

function TRADE_PANEL:OnRemove()
	if (ix.traders._tradeFrame == self) then ix.traders._tradeFrame = nil end
	-- Cerrar todos los paneles hijos al cerrar el trader principal
	if (IsValid(ix.traders._previewFrame))  then ix.traders._previewFrame:Remove() end
	if (IsValid(ix.traders._adminFrame))    then ix.traders._adminFrame:Remove() end
	if (IsValid(ix.traders._sellModal))     then ix.traders._sellModal:Remove() end
	if (IsValid(ix.traders._buyModal))      then ix.traders._buyModal:Remove() end
end

vgui.Register("ixTradePanel", TRADE_PANEL, "Panel")

-- ── Receptor OpenTrade ────────────────────────────────────────────────────────

net.Receive("traders_OpenTrade", function()
	local traderEnt = net.ReadEntity()
	local itemCount = net.ReadUInt(8)
	local traderInv = {}
	for i = 1, itemCount do
		traderInv[i] = {
			itemID      = net.ReadString(),
			qty         = net.ReadUInt(8),
			maxQty      = net.ReadUInt(8),
			price       = net.ReadUInt(32),
			buyPrice    = net.ReadUInt(32),
			minRep      = net.ReadUInt(10),
			playerStock = net.ReadBool(),
			usedCount   = net.ReadUInt(8),
			condition   = net.ReadString(),
			condPct     = net.ReadUInt(7),
		}
	end
	local money    = net.ReadUInt(32)
	local rep      = net.ReadUInt(10)
	net.ReadUInt(8) -- maxSlots (unused in trade UI)
	local bwlCount = net.ReadUInt(8)
	local buyWhitelist = {}
	for i = 1, bwlCount do
		buyWhitelist[net.ReadString()] = true
	end

	if (not IsValid(traderEnt)) then return end

	ix.traders._state = {
		ent          = traderEnt,
		factionKey   = traderEnt:GetNetVar("factionKey", "prapor"),
		traderName   = traderEnt:GetNetVar("traderName", "Comerciante"),
		traderInv    = traderInv, money = money, rep = rep,
		buyWhitelist = buyWhitelist,
	}

	if (IsValid(ix.traders._tradeFrame)) then
		buildTradeContent(ix.traders._tradeFrame, ix.traders._state); return
	end

	ix.traders._tradeFrame = vgui.Create("ixTradePanel")
end)

-- ============================================================
--  RESULTADOS DE COMPRA / VENTA
-- ============================================================

net.Receive("traders_PurchaseResult", function()
	local success = net.ReadBool(); local msg = net.ReadString()
	chat.AddText(success and Color(80, 200, 80) or Color(220, 70, 70), "[Trader] ", Color(200, 200, 200), msg)
	if (success) then requestRefresh() end
end)

net.Receive("traders_SellResult", function()
	local success = net.ReadBool(); local msg = net.ReadString(); local repGained = net.ReadUInt(10)
	chat.AddText(success and Color(80, 200, 80) or Color(220, 70, 70), "[Trader] ", Color(200, 200, 200), msg)
	if (success) then
		if (repGained > 0) then
			chat.AddText(ix.efgui.color.text, "[Trader] ", Color(200, 200, 200), "+" .. repGained .. " pts de reputación.")
		end
		requestRefresh()
	end
end)

-- ============================================================
--  PANEL DE ADMINISTRACIÓN  (todo en SScale — sin píxeles fijos)
-- ============================================================

net.Receive("traders_AdminOpen", function()
	local traderEnt  = net.ReadEntity()
	local slotCount  = net.ReadUInt(8)
	local adminInv   = {}
	for i = 1, slotCount do
		adminInv[i] = {
			itemID = net.ReadString(), qty = net.ReadUInt(8),
			maxQty = net.ReadUInt(8),  price = net.ReadUInt(32),
			buyPrice = net.ReadUInt(32), minRep = net.ReadUInt(10),
		}
	end
	local maxSlots   = net.ReadUInt(8)
	local customName = net.ReadString()
	local customLore = net.ReadString()
	local facCount   = net.ReadUInt(8)
	local recvAllowedFac = {}
	for i = 1, facCount do recvAllowedFac[#recvAllowedFac + 1] = net.ReadString() end
	local bwlCount = net.ReadUInt(8)
	local recvBuyWhitelist = {}
	for i = 1, bwlCount do recvBuyWhitelist[#recvBuyWhitelist + 1] = net.ReadString() end

	if (not IsValid(traderEnt)) then return end
	if (IsValid(ix.traders._adminFrame)) then ix.traders._adminFrame:Remove() end

	local fk     = traderEnt:GetNetVar("factionKey", "prapor")
	local name   = traderEnt:GetNetVar("traderName", "Comerciante")
	local fc     = getFactionColor(fk)
	local sw, sh = ScrW(), ScrH()

	local workInv          = table.Copy(adminInv)
	local workMaxSlots     = maxSlots
	local workAllowedFac   = table.Copy(recvAllowedFac)
	local workBuyWhitelist = table.Copy(recvBuyWhitelist)
	local selectedRow      = nil

	-- Estado de apariencia (modelo, animación y bodygroups)
	local selectedModel = traderEnt:GetNetVar("traderModel") or traderEnt:GetModel()
	local selectedAnim  = traderEnt:GetNetVar("traderAnim")  or ""

	local selectedBodygroups = {}
	for _, bg in ipairs(traderEnt:GetBodyGroups()) do
		if (bg.id != 0) then
			selectedBodygroups[bg.id] = traderEnt:GetBodygroup(bg.id)
		end
	end

	-- ── Constantes responsive (SScale = vh de GMod) ───────────────────────────
	local SP    = SScale(8)    -- padding
	local SG    = SScale(5)    -- gap
	local SHDR  = SScale(22)   -- alto cabecera lista
	local SROW  = SScale(20)   -- alto fila
	local SBTN  = SScale(14)   -- alto botón
	local SFLD  = SScale(22)   -- alto campo de texto

	local W = math.min(SScale(720), sw - SScale(40))
	local H = math.min(SScale(500), sh - SScale(40))

	local LSTW   = W - SP * 2
	local LIST_Y = SScale(168)
	-- Dos filas de botones: la de arriba solo para "Vaciar stock" (acción poco
	-- frecuente y ancha), así no compite por sitio con el resto en pantallas
	-- estrechas (se solapaban cuando compartían fila).
	local LIST_H = H - LIST_Y - SG - SBTN - SG - SBTN - SP
	local WIPE_Y = LIST_Y + LIST_H + SG
	local BTN_Y  = WIPE_Y + SBTN + SG

	-- Columnas de stats (SScale) — offsets acumulativos
	local SCANT  = SScale(58)
	local SMAX   = SScale(58)
	local SPRICE = SScale(84)
	local SBUYP  = SScale(72)
	local SREP   = SScale(60)
	local STAT_W = SCANT + SMAX + SPRICE + SBUYP + SREP
	local NAME_CW = LSTW - STAT_W
	local SC = {cant=0, max=SCANT, price=SCANT+SMAX, buy=SCANT+SMAX+SPRICE, rep=SCANT+SMAX+SPRICE+SBUYP}
	local SW = {cant=SCANT, max=SMAX, price=SPRICE, buy=SBUYP, rep=SREP}

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetTitle(""); frame:SetDraggable(true)
	frame:ShowCloseButton(false); frame:MakePopup(); frame:SetDeleteOnClose(true)
	frame.Paint = function(self, w, h) paintFloatingFrame(self, w, h, fc, fk) end
	ix.traders._adminFrame = frame

	-- Al cerrar el admin, cierra también todos sus sub-paneles
	frame.OnRemove = function()
		if (ix.traders._adminFrame == frame) then ix.traders._adminFrame = nil end
		for _, key in ipairs({"_adminEditModal", "_adminAppModal", "_adminAddPopup", "_adminBuyPopup", "_adminWipeModal"}) do
			if (IsValid(ix.traders[key])) then ix.traders[key]:Remove() end
			ix.traders[key] = nil
		end
	end

	local lblTitle = frame:Add("DLabel")
	lblTitle:SetPos(SP, SP); lblTitle:SetSize(W - SScale(40), SScale(20))
	lblTitle:SetText("Admin — " .. name); lblTitle:SetFont("Metro UI.Button")
	lblTitle:SetTextColor(Color(220, 220, 220))

	local sep = frame:Add("DPanel")
	sep:SetPos(SP, SScale(30)); sep:SetSize(W - SP * 2, 1)
	sep.Paint = function(_, w, h) surface.SetDrawColor(ix.efgui.color.line); surface.DrawRect(0, 0, w, h) end

	local lblSlots = frame:Add("DLabel")
	lblSlots:SetPos(SP, SScale(36)); lblSlots:SetSize(SScale(120), SScale(18))
	lblSlots:SetText("Slots máximos:"); lblSlots:SetFont("Metro UI.CharFields")
	lblSlots:SetTextColor(Color(160, 160, 160))

	local slotsEntry = frame:Add("DTextEntry")
	slotsEntry:SetPos(SScale(136), SScale(34)); slotsEntry:SetSize(SScale(56), SScale(22))
	slotsEntry:SetText(tostring(workMaxSlots)); slotsEntry:SetFont("Metro UI.CharFields")
	slotsEntry.Paint = paintDarkEntry
	slotsEntry.OnChange = function(self)
		local n = tonumber(self:GetValue())
		if (n) then workMaxSlots = math.Clamp(math.floor(n), 1, 100) end
	end

	-- ── Nombre individual del trader ──────────────────────────────────────────
	local lblCustomName = frame:Add("DLabel")
	lblCustomName:SetPos(SP, SScale(60))
	lblCustomName:SetSize(SScale(80), SScale(10))
	lblCustomName:SetText("Nombre:")
	lblCustomName:SetFont("Metro UI.CharFields")
	lblCustomName:SetTextColor(Color(160, 160, 160))

	local nameEntry = frame:Add("DTextEntry")
	nameEntry:SetPos(SP + SScale(84), SScale(58))
	nameEntry:SetSize(W - SP * 2 - SScale(84), SScale(18))
	nameEntry:SetFont("Metro UI.CharFields")
	nameEntry:SetPlaceholderText("Nombre único del trader (vacío = nombre de facción)")
	nameEntry:SetText(customName)
	nameEntry.Paint = paintDarkEntry

	-- ── Lore individual del trader ────────────────────────────────────────────
	local lblCustomLore = frame:Add("DLabel")
	lblCustomLore:SetPos(SP, SScale(82))
	lblCustomLore:SetSize(SScale(80), SScale(10))
	lblCustomLore:SetText("Lore:")
	lblCustomLore:SetFont("Metro UI.CharFields")
	lblCustomLore:SetTextColor(Color(160, 160, 160))

	local loreEntry = frame:Add("DTextEntry")
	loreEntry:SetPos(SP + SScale(84), SScale(80))
	loreEntry:SetSize(W - SP * 2 - SScale(84), SScale(18))
	loreEntry:SetFont("Metro UI.CharFields")
	loreEntry:SetPlaceholderText("Trasfondo/descripción del trader (vacío = lore de facción)")
	loreEntry:SetText(customLore)
	loreEntry.Paint = paintDarkEntry

	-- ── Restricción de facciones del jugador ──────────────────────────────────
	local lblFacTitle = frame:Add("DLabel")
	lblFacTitle:SetPos(SP, SScale(102))
	lblFacTitle:SetSize(W - SP * 2, SScale(10))
	lblFacTitle:SetText("Facciones con acceso (vacío = todas):")
	lblFacTitle:SetFont("ixSmallFont")
	lblFacTitle:SetTextColor(Color(160, 160, 160))

	local FAC_BTN_W  = SScale(80)
	local FAC_BTN_H  = SScale(20)
	local FAC_BTN_SP = SScale(2)
	local facRows    = math.ceil(#FACTION_ORDER / 5)
	local facWrap    = frame:Add("DIconLayout")
	facWrap:SetPos(SP, SScale(114))
	facWrap:SetSize(W - SP * 2, facRows * (FAC_BTN_H + FAC_BTN_SP) + FAC_BTN_SP)
	facWrap:SetSpaceX(FAC_BTN_SP); facWrap:SetSpaceY(FAC_BTN_SP)

	local facToggles = {}
	for _, fk in ipairs(FACTION_ORDER) do
		local fname = FACTION_NAMES[fk] or fk
		local fc    = FACTION_COLORS[fk] or Color(150, 150, 150)
		local tog   = facWrap:Add("DButton")
		tog:SetSize(FAC_BTN_W, FAC_BTN_H)
		tog:SetText("")
		tog.on  = table.HasValue(workAllowedFac, fk)
		tog.fk  = fk
		tog.Paint = function(s, w, h)
			surface.SetDrawColor(fc.r, fc.g, fc.b, s.on and 70 or 14)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(fc.r, fc.g, fc.b, s.on and 180 or 50)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(fname, "ixSmallFont",
				w / 2, h / 2,
				s.on and Color(220, 220, 220) or Color(120, 120, 120),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		tog.DoClick = function(s)
			s.on = !s.on
			if (s.on) then
				if (!table.HasValue(workAllowedFac, fk)) then table.insert(workAllowedFac, fk) end
			else
				table.RemoveByValue(workAllowedFac, fk)
			end
		end
		facToggles[fk] = tog
	end

	-- ── Cabecera de la lista ──────────────────────────────────────────────────
	local listHdr = frame:Add("DPanel")
	listHdr:SetPos(SP, LIST_Y); listHdr:SetSize(LSTW, SHDR)
	listHdr.Paint = function(_, w, h)
		ix.util.DrawBlur(listHdr, 3)
		surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(66, 66, 66, 120); surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("Ítem / Categoría", "ixSmallFont",
			SP, h / 2, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local function hcol(key, lbl)
			draw.SimpleText(lbl, "ixSmallFont",
				NAME_CW + SC[key] + SW[key] / 2, h / 2,
				Color(170, 170, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		hcol("cant",  "Cant.")
		hcol("max",   "Máx")
		hcol("price", "Venta")
		hcol("buy",   "Compra")
		hcol("rep",   "Rep Mín")
	end

	-- ── Lista con scroll ──────────────────────────────────────────────────────
	local adminScroll = frame:Add("DScrollPanel")
	adminScroll:SetPos(SP, LIST_Y + SHDR)
	adminScroll:SetSize(LSTW, LIST_H - SHDR)
	adminScroll:GetVBar():SetWide(SScale(4))

	-- ── Modal de edición (todo SScale) ──────────────────────────────────────────
	local function openEditModal(idx, slot)
		local MW    = SScale(240)
		local MLBL  = SScale(10)
		local MFLD  = SScale(16)
		local MTITL = SScale(28)
		local MH    = MTITL + (MLBL + SG + MFLD + SG) * 3 + SG + SBTN * 2 + SG + SP

		local itemData = ix.item.list[slot.itemID]
		local itemName = itemData and itemData.name or slot.itemID
		local category = itemData and (itemData.category or "Sin categoría") or "???"

		if (IsValid(ix.traders._adminEditModal)) then ix.traders._adminEditModal:Remove() end
		local modal = vgui.Create("DFrame")
		ix.traders._adminEditModal = modal
		modal:SetSize(MW, MH); modal:SetPos(sw / 2 - MW / 2, sh / 2 - MH / 2)
		modal:SetTitle(""); modal:SetDraggable(true)
		modal:ShowCloseButton(false); modal:MakePopup(); modal:SetDeleteOnClose(true)
		modal.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 166, 66, 140); surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText(itemName, "Metro UI.Button",
				SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(category, "ixSmallFont",
				SP, SP + SScale(22), Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local FW   = math.floor((MW - SP * 3) / 2)
		local C2X  = SP + FW + SP
		local R1Y  = MTITL
		local R2Y  = R1Y + MLBL + SG + MFLD + SG
		local R3Y  = R2Y + MLBL + SG + MFLD + SG
		local MBTY = R3Y + MLBL + SG + MFLD + SG

		local function mkField(label, x, y, val)
			local l = modal:Add("DLabel")
			l:SetPos(x, y); l:SetSize(FW, MLBL); l:SetText(label)
			l:SetFont("Metro UI.CharFields"); l:SetTextColor(Color(150, 150, 150))
			local e = modal:Add("DTextEntry")
			e:SetPos(x, y + MLBL + SG); e:SetSize(FW, MFLD)
			e:SetFont("Metro UI.CharFields"); e:SetText(tostring(val))
			e.Paint = paintDarkEntry
			return e
		end

		local fQty      = mkField("Cantidad",          SP,  R1Y, slot.qty)
		local fMaxQty   = mkField("Máx. Cantidad",     C2X, R1Y, slot.maxQty)
		local fPrice    = mkField("Precio Venta",      SP,  R2Y, slot.price)
		local fMinRep   = mkField("Reputación mínima", C2X, R2Y, slot.minRep or 0)
		local fBuyPrice = mkField("Precio Compra",     SP,  R3Y, slot.buyPrice or 0)

		local lBuyInfo = modal:Add("DLabel")
		lBuyInfo:SetPos(C2X, R3Y + MLBL + SG); lBuyInfo:SetSize(FW, MFLD)
		lBuyInfo:SetText("0 = usa el precio\nde compra global")
		lBuyInfo:SetFont("ixSmallFont"); lBuyInfo:SetTextColor(Color(140, 140, 140))
		lBuyInfo:SetWrap(true)

		makeMetroBtn(modal, "Aplicar cambios", 66, 166, 66, function()
			slot.qty      = math.Clamp(tonumber(fQty:GetValue())    or slot.qty,    0, 255)
			slot.maxQty   = math.Clamp(tonumber(fMaxQty:GetValue()) or slot.maxQty, 0, 255)
			slot.price    = math.Clamp(tonumber(fPrice:GetValue())  or slot.price,  0, 99999999)
			slot.buyPrice = math.Clamp(tonumber(fBuyPrice:GetValue()) or (slot.buyPrice or 0), 0, 99999999)
			slot.minRep   = math.Clamp(tonumber(fMinRep:GetValue()) or (slot.minRep or 0), 0, 1000)
			if (IsValid(modal)) then modal:Remove() end
			if (IsValid(frame) and frame.refreshList) then frame.refreshList() end
		end):SetBounds(SP, MBTY, MW - SP * 2, SBTN)

		makeMetroBtn(modal, "Cancelar", 120, 30, 30, function()
			modal:Remove()
		end):SetBounds(SP, MBTY + SBTN + SG, MW - SP * 2, SBTN)
	end

	-- ── Refresco de la lista ──────────────────────────────────────────────────
	local function refreshAdminList()
		adminScroll:Clear()
		selectedRow = nil

		for i, slot in ipairs(workInv) do
			local itemData = ix.item.list[slot.itemID]
			local itemName = itemData and itemData.name or ("??? — " .. slot.itemID)
			local category = itemData and (itemData.category or "Sin categoría") or "???"

			local row = adminScroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 0, 0, SScale(2)); row:SetTall(SROW)
			row:SetCursor("hand"); row._idx = i

			row.Paint = function(me, w, h)
				local isSel = (selectedRow == me)
				ix.util.DrawBlur(me, 5)
				surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
				surface.DrawRect(0, 0, w, h)
				if (isSel) then
					surface.SetDrawColor(66, 166, 66, 200)
					surface.DrawRect(0, 0, SScale(3), h)
				end
				surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				surface.SetDrawColor(44, 44, 44, 60)
				surface.DrawRect(NAME_CW, 0, w - NAME_CW, h)
			end

			local lName = row:Add("DLabel")
			lName:SetPos(SScale(4), SScale(1)); lName:SetSize(NAME_CW - SScale(8), SScale(10))
			lName:SetText(itemName); lName:SetFont("Metro UI.CharFields")
			lName:SetTextColor(Color(215, 215, 215)); lName:SetMouseInputEnabled(false)

			local lCat = row:Add("DLabel")
			lCat:SetPos(SScale(4), SScale(11)); lCat:SetSize(NAME_CW - SScale(8), SScale(9))
			lCat:SetText(category); lCat:SetFont("ixSmallFont")
			lCat:SetTextColor(Color(175, 177, 148)); lCat:SetMouseInputEnabled(false)

			local function statCol(key, val, col)
				local l = row:Add("DLabel")
				l:SetPos(NAME_CW + SC[key], 0); l:SetSize(SW[key], SROW)
				l:SetText(tostring(val)); l:SetFont("Metro UI.CharFields")
				l:SetTextColor(col or Color(200, 200, 200))
				l:SetContentAlignment(5); l:SetMouseInputEnabled(false)
			end
			statCol("cant",  slot.qty,           Color(210, 210, 210))
			statCol("max",   slot.maxQty,        Color(210, 210, 210))
			statCol("price", slot.price .. " B", Color(197, 199, 179))
			local effBuy = ix.traders.GetEffectiveBuyPrice(slot.buyPrice, slot.itemID)
			local buyIsCustom = slot.buyPrice and slot.buyPrice > 0
			statCol("buy", effBuy > 0 and (effBuy .. " B" .. (buyIsCustom and " *" or "")) or "50%",
				buyIsCustom and Color(120, 210, 120) or Color(145, 148, 108))
			statCol("rep",   slot.minRep or 0,   Color(180, 130, 130))

			local slotRef = slot
			local rowRef  = row
			row.OnMousePressed = function(me, mc)
				if (mc != MOUSE_LEFT) then return end
				selectedRow = rowRef
				openEditModal(i, slotRef)
			end
		end
	end

	frame.refreshList = refreshAdminList
	refreshAdminList()

	-- ── Botones inferiores (SScale) ───────────────────────────────────────────
	local BADD  = SScale(116)
	local BDEL  = SScale(90)
	local BBUY  = SScale(90)
	local BWIPE = SScale(108)
	local BSAVE = SScale(96)
	local BCLS  = SScale(82)

	makeMetroBtn(frame, "+ Añadir ítem", 30, 100, 30, function()
		if (#workInv >= workMaxSlots) then
			chat.AddText(Color(220, 70, 70), "[Admin] Trader lleno."); return
		end

		-- Popup dimensionado en SScale
		local PW        = SScale(280)
		local PSEARCH_H = SScale(16)
		local PSEARCH_Y = SScale(20)
		local PROW_H    = SScale(22)   -- espacio para categoría + nombre
		local PLIST_H   = SScale(130)
		local PLIST_Y   = PSEARCH_Y + PSEARCH_H + SG
		local PFH       = math.floor((PW - SP * 3) / 2)
		local PLBL_H    = SScale(11)
		local PENT_H    = SScale(16)
		local PSEP_Y    = PLIST_Y + PLIST_H + SG
		local PLBL_Y1   = PSEP_Y + 1 + SG
		local PENT_Y1   = PLBL_Y1 + PLBL_H + SG
		local PLBL_Y2   = PENT_Y1 + PENT_H + SG
		local PENT_Y2   = PLBL_Y2 + PLBL_H + SG
		local PLBL_Y3   = PENT_Y2 + PENT_H + SG
		local PENT_Y3   = PLBL_Y3 + PLBL_H + SG
		local PBTN_Y    = PENT_Y3 + PENT_H + SG
		local PH        = PBTN_Y + SBTN + SP

		if (IsValid(ix.traders._adminAddPopup)) then ix.traders._adminAddPopup:Remove() end
		local pop = vgui.Create("DFrame")
		ix.traders._adminAddPopup = pop
		pop:SetSize(PW, PH); pop:SetPos(sw / 2 - PW / 2, sh / 2 - PH / 2)
		pop:SetTitle(""); pop:SetDraggable(true)
		pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
		pop.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 166, 66, 120); surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 88); surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText("Añadir ítem al trader", "Metro UI.Button",
				SP, SP, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local searchBox = pop:Add("DTextEntry")
		searchBox:SetPos(SP, PSEARCH_Y); searchBox:SetSize(PW - SP * 2, PSEARCH_H)
		searchBox:SetFont("Metro UI.CharFields")
		searchBox.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 3)
			surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 1)
			self:DrawTextEntryText(Color(220, 220, 220), Color(112, 128, 130, 180), Color(220, 220, 220))
			if (self:GetValue() == "") then
				draw.SimpleText("Buscar por categoría o nombre...", "ixSmallFont",
					SScale(4), h/2, Color(100, 100, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local itemScroll = pop:Add("DScrollPanel")
		itemScroll:SetPos(SP, PLIST_Y); itemScroll:SetSize(PW - SP * 2, PLIST_H)
		itemScroll:GetVBar():SetWide(SScale(4))

		local selectedItemID = {value = nil}
		local ePr -- forward declaration: se crea más abajo, pero buildItemList ya necesita rellenarlo

		local function buildItemList(filter)
			itemScroll:Clear()
			local sorted = {}
			for uid, data in pairs(ix.item.list) do
				local cat   = data.category or "Sin categoría"
				local label = cat .. " — " .. (data.name or uid)
				local filt  = filter and filter:lower() or ""
				if (filt == "" or label:lower():find(filt, 1, true)) then
					table.insert(sorted, {uid=uid, cat=cat, name=data.name or uid})
				end
			end
			table.sort(sorted, function(a, b) return (a.cat..a.name) < (b.cat..b.name) end)

			for _, entry in ipairs(sorted) do
				local uid  = entry.uid
				local eRow = itemScroll:Add("DPanel")
				eRow:Dock(TOP); eRow:DockMargin(0, 0, 0, SScale(1)); eRow:SetTall(PROW_H)
				eRow:SetCursor("hand")
				eRow.Paint = function(me, w, h)
					local isSel = (selectedItemID.value == uid)
					ix.util.DrawBlur(me, 5)
					surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
					surface.DrawRect(0, 0, w, h)
					if (isSel) then surface.SetDrawColor(66, 166, 66, 160); surface.DrawRect(0, 0, SScale(3), h) end
					surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
					surface.DrawOutlinedRect(0, 0, w, h, 1)
				end
				-- Categoría (línea pequeña arriba)
				local lCat2 = eRow:Add("DLabel")
				lCat2:SetPos(SScale(6), SScale(1)); lCat2:SetSize(PW - SP * 2 - SScale(12), SScale(9))
				lCat2:SetText(entry.cat); lCat2:SetFont("ixSmallFont")
				lCat2:SetTextColor(Color(175, 177, 148)); lCat2:SetMouseInputEnabled(false)
				-- Nombre (línea principal debajo)
				local lName2 = eRow:Add("DLabel")
				lName2:SetPos(SScale(6), SScale(10)); lName2:SetSize(PW - SP * 2 - SScale(12), SScale(12))
				lName2:SetText(entry.name); lName2:SetFont("Metro UI.CharFields")
				lName2:SetTextColor(Color(210, 210, 210)); lName2:SetMouseInputEnabled(false)
				eRow.OnMousePressed = function(me, mc)
					if (mc == MOUSE_LEFT) then
						selectedItemID.value = uid
						-- Precargar el precio de venta estándar del ítem al seleccionarlo,
						-- para que "el global" sea el punto de partida por defecto.
						if (IsValid(ePr)) then
							ePr:SetText(tostring(ix.traders.GetGlobalPrice(uid)))
						end
					end
				end
			end
		end
		buildItemList(nil)
		searchBox.OnChange = function(self) buildItemList(self:GetValue()) end

		-- Separador y 4 campos: cantidad / máx / precio / rep mínima
		local popSep = pop:Add("DPanel")
		popSep:SetPos(SP, PSEP_Y); popSep:SetSize(PW - SP * 2, 1)
		popSep.Paint = function(_, w, h) surface.SetDrawColor(ix.efgui.color.line); surface.DrawRect(0, 0, w, h) end

		local function mkFld(lbl, x, lblY, entY, val)
			local l = pop:Add("DLabel")
			l:SetPos(x, lblY); l:SetSize(PFH, PLBL_H); l:SetText(lbl)
			l:SetFont("ixSmallFont"); l:SetTextColor(Color(150, 150, 150))
			local e = pop:Add("DTextEntry")
			e:SetPos(x, entY); e:SetSize(PFH, PENT_H)
			e:SetFont("Metro UI.CharFields"); e:SetText(tostring(val))
			e.Paint = paintDarkEntry
			return e
		end

		local eQt  = mkFld("Cantidad:",       SP,           PLBL_Y1, PENT_Y1, 1)
		local eMx  = mkFld("Máx. Cantidad:",  SP * 2 + PFH, PLBL_Y1, PENT_Y1, 1)
		ePr        = mkFld("Precio Venta:",   SP,           PLBL_Y2, PENT_Y2, 10)
		local eRep = mkFld("Rep Mínima:",     SP * 2 + PFH, PLBL_Y2, PENT_Y2, 0)

		local PBW1 = math.floor((PW - SP * 3) * 2 / 3)
		local PBW2 = PW - SP * 3 - PBW1

		makeMetroBtn(pop, "Añadir al trader", 30, 140, 30, function()
			if (not selectedItemID.value) then
				chat.AddText(Color(220, 70, 70), "[Admin] Selecciona un ítem de la lista."); return
			end
			local qty    = math.max(1,   math.floor(tonumber(eQt:GetValue())  or 1))
			local maxQty = math.max(qty, math.floor(tonumber(eMx:GetValue())  or qty))
			local pr     = math.max(0,   math.floor(tonumber(ePr:GetValue())  or 10))
			local rep    = math.Clamp(   math.floor(tonumber(eRep:GetValue()) or 0), 0, 1000)
			table.insert(workInv, {itemID=selectedItemID.value, qty=qty, maxQty=maxQty, price=pr, buyPrice=0, minRep=rep})
			refreshAdminList(); pop:Remove()
		end):SetBounds(SP, PBTN_Y, PBW1, SBTN)

		makeMetroBtn(pop, "Cancelar", 120, 30, 30, function()
			pop:Remove()
		end):SetBounds(SP + PBW1 + SP, PBTN_Y, PBW2, SBTN)
	end):SetBounds(SP, BTN_Y, BADD, SBTN)

	makeMetroBtn(frame, "Eliminar", 130, 30, 30, function()
		if (not selectedRow) then
			chat.AddText(Color(220, 70, 70), "[Admin] Selecciona un ítem primero."); return
		end
		local idx = selectedRow._idx
		if (workInv[idx]) then table.remove(workInv, idx) end
		refreshAdminList()
	end):SetBounds(SP + BADD + SG, BTN_Y, BDEL, SBTN)

	-- ── Botón Compras (whitelist de ítems que el trader compra) ───────────────
	makeMetroBtn(frame, "Compras", 66, 140, 66, function()
		local PW        = SScale(280)
		local PSEARCH_H = SScale(16)
		local PSEARCH_Y = SScale(20)
		local PROW_H    = SScale(16)
		local PLIST_H   = SScale(240)
		local PLIST_Y   = PSEARCH_Y + PSEARCH_H + SG
		local PLBL_Y    = PLIST_Y + PLIST_H + SG
		local PBTN_Y    = PLBL_Y + SScale(14) + SG
		local PH        = PBTN_Y + SBTN + SP

		if (IsValid(ix.traders._adminBuyPopup)) then ix.traders._adminBuyPopup:Remove() end
		local pop = vgui.Create("DFrame")
		ix.traders._adminBuyPopup = pop
		pop:SetSize(PW, PH); pop:SetPos(sw / 2 - PW / 2, sh / 2 - PH / 2)
		pop:SetTitle(""); pop:SetDraggable(true)
		pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
		pop.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 166, 66, 120); surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 88); surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText("Items que el trader compra", "Metro UI.Button",
				SP, SP, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local selected = {}
		for _, uid in ipairs(workBuyWhitelist) do selected[uid] = true end

		local searchBox = pop:Add("DTextEntry")
		searchBox:SetPos(SP, PSEARCH_Y); searchBox:SetSize(PW - SP * 2, PSEARCH_H)
		searchBox:SetFont("Metro UI.CharFields")
		searchBox.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 3)
			surface.SetDrawColor(44, 44, 44, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 1)
			self:DrawTextEntryText(Color(220, 220, 220), Color(112, 128, 130, 180), Color(220, 220, 220))
			if (self:GetValue() == "") then
				draw.SimpleText("Buscar por categoría o nombre...", "ixSmallFont",
					SScale(4), h / 2, Color(100, 100, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local itemScroll = pop:Add("DScrollPanel")
		itemScroll:SetPos(SP, PLIST_Y); itemScroll:SetSize(PW - SP * 2, PLIST_H)
		itemScroll:GetVBar():SetWide(SScale(4))

		local countLabel = pop:Add("DLabel")
		countLabel:SetPos(SP, PLBL_Y); countLabel:SetSize(PW - SP * 2, SScale(14))
		countLabel:SetFont("ixSmallFont"); countLabel:SetTextColor(Color(160, 160, 160))

		local function updateCount()
			local n = table.Count(selected)
			countLabel:SetText(n .. " item" .. (n != 1 and "s" or "") .. " seleccionado" .. (n != 1 and "s" or ""))
		end
		updateCount()

		local function buildBuyList(filter)
			itemScroll:Clear()
			local sorted = {}
			for uid, data in pairs(ix.item.list) do
				if (not data.noBusiness) then
					local cat   = data.category or "Sin categoría"
					local filt  = filter and filter:lower() or ""
					local label = cat .. " " .. (data.name or uid)
					if (filt == "" or label:lower():find(filt, 1, true)) then
						table.insert(sorted, {uid = uid, cat = cat, name = data.name or uid})
					end
				end
			end
			table.sort(sorted, function(a, b)
				if (a.cat == b.cat) then return a.name < b.name end
				return a.cat < b.cat
			end)

			local lastCat = nil
			for _, entry in ipairs(sorted) do
				local uid = entry.uid

				if (entry.cat != lastCat) then
					lastCat = entry.cat
					local catRow = itemScroll:Add("DPanel")
					catRow:Dock(TOP); catRow:DockMargin(0, SScale(2), 0, 0); catRow:SetTall(SScale(12))
					catRow.Paint = function(_, w, h)
						surface.SetDrawColor(175, 177, 148, 30)
						surface.DrawRect(0, 0, w, h)
						draw.SimpleText(entry.cat, "ixSmallFont", SScale(6), h / 2,
							Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end
				end

				local eRow = itemScroll:Add("DPanel")
				eRow:Dock(TOP); eRow:DockMargin(0, 0, 0, SScale(1)); eRow:SetTall(PROW_H)
				eRow:SetCursor("hand")
				eRow.Paint = function(me, w, h)
					local isSel = selected[uid]
					ix.util.DrawBlur(me, 5)
					surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
					surface.DrawRect(0, 0, w, h)
					if (isSel) then
						surface.SetDrawColor(66, 166, 66, 160)
						surface.DrawRect(0, 0, SScale(3), h)
					end
					surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
					surface.DrawOutlinedRect(0, 0, w, h, 1)
				end

				local lName = eRow:Add("DLabel")
				lName:SetPos(SScale(8), 0); lName:SetSize(PW - SP * 2 - SScale(16), PROW_H)
				lName:SetText(entry.name); lName:SetFont("Metro UI.CharFields")
				lName:SetTextColor(Color(210, 210, 210)); lName:SetMouseInputEnabled(false)

				eRow.OnMousePressed = function(me, mc)
					if (mc == MOUSE_LEFT) then
						selected[uid] = not selected[uid] or nil
						updateCount()
					end
				end
			end
		end
		buildBuyList(nil)
		searchBox.OnChange = function(self) buildBuyList(self:GetValue()) end

		local PBW1 = math.floor((PW - SP * 3) * 2 / 3)
		local PBW2 = PW - SP * 3 - PBW1

		makeMetroBtn(pop, "+ Guardar", 30, 140, 30, function()
			workBuyWhitelist = {}
			for uid, _ in pairs(selected) do
				table.insert(workBuyWhitelist, uid)
			end
			pop:Remove()
		end):SetBounds(SP, PBTN_Y, PBW1, SBTN)

		makeMetroBtn(pop, "Cancelar", 120, 30, 30, function()
			pop:Remove()
		end):SetBounds(SP + PBW1 + SP, PBTN_Y, PBW2, SBTN)
	end):SetBounds(SP + BADD + SG + BDEL + SG, BTN_Y, BBUY, SBTN)

	-- ── Botón Vaciar stock de jugadores (acción global, TODOS los traders) ────
	local wipeBtn = makeMetroBtn(frame, "Vaciar stock", 180, 90, 40, function()
		local CW, CH = SScale(300), SScale(120)

		if (IsValid(ix.traders._adminWipeModal)) then ix.traders._adminWipeModal:Remove() end
		local cModal = vgui.Create("DFrame")
		ix.traders._adminWipeModal = cModal
		cModal:SetSize(CW, CH); cModal:SetPos(sw / 2 - CW / 2, sh / 2 - CH / 2)
		cModal:SetTitle(""); cModal:SetDraggable(true)
		cModal:ShowCloseButton(false); cModal:MakePopup(); cModal:SetDeleteOnClose(true)
		cModal.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(180, 90, 40, 160); surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		local msg = cModal:Add("DLabel")
		msg:SetPos(SP, SP + SScale(6)); msg:SetSize(CW - SP * 2, SScale(60))
		msg:SetText("Esto eliminará TODOS los ítems vendidos por jugadores en TODOS los traders del mapa. Esta acción no se puede deshacer. ¿Continuar?")
		msg:SetWrap(true); msg:SetAutoStretchVertical(true)
		msg:SetFont("Metro UI.CharFields"); msg:SetTextColor(Color(220, 220, 220))

		local CBTN_Y = CH - SBTN - SP
		local CBW    = (CW - SP * 3) / 2

		makeMetroBtn(cModal, "Sí, vaciar", 180, 60, 60, function()
			net.Start("traders_WipePlayerStock")
			net.SendToServer()
			cModal:Remove()
		end):SetBounds(SP, CBTN_Y, CBW, SBTN)

		makeMetroBtn(cModal, "Cancelar", 90, 90, 90, function()
			cModal:Remove()
		end):SetBounds(SP * 2 + CBW, CBTN_Y, CBW, SBTN)
	end)
	wipeBtn:SetTooltip("Elimina TODOS los ítems vendidos por jugadores en TODOS los traders del mapa")
	wipeBtn:SetBounds(SP, WIPE_Y, BWIPE, SBTN)

	-- ── Botón Apariencia ──────────────────────────────────────────────────────
	local BAPP = SScale(88)
	makeMetroBtn(frame, "Apariencia", 66, 66, 140, function()
		-- Listas de modelos y animaciones
		local MODELS = {
			{label = "Scav",        model = "models/eft/scavs/scav_extended_pm.mdl"},
			{label = "BEAR",        model = "models/eft/pmcs/bear_extended_pm.mdl"},
			{label = "USEC",        model = "models/eft/pmcs/usec_extended_pm.mdl"},
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
		-- Mismas 9 animaciones de siempre. "seq" ya no es un nombre exacto (esos
		-- nombres de HL2/CS no existen en estos modelos custom, por eso solo
		-- "Idle 01" funcionaba); son palabras clave que se buscan dentro de las
		-- secuencias REALES del modelo (ver refreshAnimCombo, más abajo).
		local ANIMS = {
			{label = "Por defecto",     keys = nil},
			{label = "Idle 01",         keys = {"idle_all_01", "idle01", "idle_01"}},
			{label = "Idle 02",         keys = {"idle_all_02", "idle02", "idle_02"}},
			{label = "Cruzar brazos",   keys = {"crossarm", "cross_arm", "armscrossed"}},
			{label = "Saludar",         keys = {"wave", "salud"}},
			{label = "Señalar",         keys = {"point", "señal"}},
			{label = "Asentir",         keys = {"nod_yes", "nodyes", "asentir"}},
			{label = "Negar",           keys = {"nod_no", "nodno", "negar"}},
			{label = "Hablar",          keys = {"talk", "speak", "hablar"}},
			{label = "Aclamar",         keys = {"cheer", "aclamar"}},
			{label = "Sentado",         keys = {"sit", "sentado"}},
			{label = "Fumar",           keys = {"smoke", "fumar"}},
			{label = "Encoger hombros", keys = {"shrug", "encoger"}},
			{label = "Reír",            keys = {"laugh", "reir", "reír"}},
			{label = "Rascarse",        keys = {"scratch", "rascar"}},
			{label = "Mirar alrededor", keys = {"lookaround", "look_around", "idle_look"}},
		}

		local AW = SScale(360)
		local AH = SScale(340)
		local aMdl  = selectedModel
		local aAnim = selectedAnim
		local aBodygroups = table.Copy(selectedBodygroups)

		if (IsValid(ix.traders._adminAppModal)) then ix.traders._adminAppModal:Remove() end
		local aModal = vgui.Create("DFrame")
		ix.traders._adminAppModal = aModal
		aModal:SetSize(AW, AH); aModal:SetPos(sw / 2 - AW / 2, sh / 2 - AH / 2)
		aModal:SetTitle(""); aModal:SetDraggable(true)
		aModal:ShowCloseButton(false); aModal:MakePopup(); aModal:SetDeleteOnClose(true)
		aModal.Paint = function(self, w, h)
			ix.util.DrawBlur(self, 5)
			surface.SetDrawColor(33, 33, 33, 240); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 66, 140, 140); surface.DrawRect(0, 0, w, SScale(3))
			surface.SetDrawColor(66, 66, 66, 100); surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText("Apariencia del Trader", "Metro UI.Button",
				SP, SP, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- Layout: lista izquierda + preview derecha
		local LIST_W  = SScale(120)
		local PREV_W  = AW - LIST_W - SP * 3
		local TOP_Y   = SScale(28)
		local ANIM_H  = SScale(18)
		local BG_H    = SScale(60)
		local PREV_H  = AH - TOP_Y - SP * 2 - ANIM_H - BG_H - SBTN - SG * 3
		local PREV_X  = SP * 2 + LIST_W

		-- Preview 3D
		local mdlPanel = aModal:Add("DModelPanel")
		mdlPanel:SetPos(PREV_X, TOP_Y); mdlPanel:SetSize(PREV_W, PREV_H)
		mdlPanel:SetModel(aMdl); mdlPanel:SetFOV(35)
		mdlPanel:SetLookAt(Vector(0, 0, 50)); mdlPanel:SetCamPos(Vector(120, 0, 50))
		mdlPanel:SetAmbientLight(Color(112, 128, 130)); mdlPanel:SetDirectionalLight(BOX_FRONT, Color(145, 148, 108))
		mdlPanel.LayoutEntity = function(self, ent)
			if (aAnim != "") then
				local seq = ent:LookupSequence(aAnim)
				if (seq and seq > 0 and not self._animApplied) then
					ent:ResetSequence(seq); ent:SetPlaybackRate(1)
					self._animApplied = true
				end
				ent:FrameAdvance()
			end
		end
		mdlPanel.PaintOver = function(self, w, h)
			surface.SetDrawColor(66, 66, 66, 44); surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local refreshBodygroups -- forward declaration (definida más abajo)
		local refreshAnimCombo  -- forward declaration (definida más abajo)
		local animCombo         -- forward declaration (definida más abajo)

		local function refreshPreview()
			mdlPanel:SetModel(aMdl)
			mdlPanel._animApplied = false
			if (refreshBodygroups) then refreshBodygroups() end
			if (refreshAnimCombo) then refreshAnimCombo() end
		end

		-- Lista de modelos (deja espacio para el campo de ruta personalizada abajo)
		local CUSTOM_H   = SScale(14)
		local listHeight = PREV_H - CUSTOM_H - SG
		local modelScroll = aModal:Add("DScrollPanel")
		modelScroll:SetPos(SP, TOP_Y); modelScroll:SetSize(LIST_W, listHeight)
		modelScroll:GetVBar():SetWide(SScale(4))

		for _, entry in ipairs(MODELS) do
			local mdl   = entry.model
			local mRow  = modelScroll:Add("DPanel")
			mRow:Dock(TOP); mRow:DockMargin(0, 0, 0, SScale(1)); mRow:SetTall(SScale(13))
			mRow:SetCursor("hand")
			mRow.Paint = function(me, w, h)
				local isSel = (aMdl == mdl)
				ix.util.DrawBlur(me, 5)
				surface.SetDrawColor(66, 66, 66, isSel and 44 or (me:IsHovered() and 22 or 11))
				surface.DrawRect(0, 0, w, h)
				if (isSel) then surface.SetDrawColor(112, 128, 130, 180); surface.DrawRect(0, 0, SScale(3), h) end
				surface.SetDrawColor(66, 66, 66, isSel and 166 or (me:IsHovered() and 66 or 44))
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(entry.label, "ixSmallFont",
					SScale(8), h / 2, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			mRow.OnMousePressed = function(me, mc)
				if (mc != MOUSE_LEFT) then return end
				aMdl = mdl
				refreshPreview()
			end
		end

		-- Campo de ruta de modelo personalizado (debajo de la lista de presets)
		local customY = TOP_Y + listHeight + SG
		local CBTN_W  = CUSTOM_H   -- botón cuadrado

		local customEntry = aModal:Add("DTextEntry")
		customEntry:SetPos(SP, customY)
		customEntry:SetSize(LIST_W - CBTN_W - SScale(2), CUSTOM_H)
		customEntry:SetFont("ixSmallFont")
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
		lblAnim:SetPos(SP, ANIM_Y); lblAnim:SetSize(SScale(80), ANIM_H)
		lblAnim:SetText("Animación:"); lblAnim:SetFont("Metro UI.CharFields")
		lblAnim:SetTextColor(Color(150, 150, 150)); lblAnim:SetContentAlignment(4)

		animCombo = aModal:Add("DComboBox")
		animCombo:SetPos(SP + SScale(84), ANIM_Y); animCombo:SetSize(AW - SP * 2 - SScale(84), ANIM_H)
		animCombo:SetFont("Metro UI.CharFields")
		animCombo.OnSelect = function(_, _, _, data)
			aAnim = data
			mdlPanel._animApplied = false
		end

		-- Para cada animación de la lista de arriba, busca en las secuencias REALES
		-- del modelo actualmente previsualizado (GetSequenceList) una que contenga
		-- alguna de sus palabras clave, y usa ESE nombre real como "seq". Si el
		-- modelo no tiene nada que coincida, esa opción no se añade al combo.
		refreshAnimCombo = function()
			animCombo:Clear()

			local ent = mdlPanel.Entity
			local sequences = (IsValid(ent) and ent:GetSequenceList()) or {}

			local function findSequence(keys)
				for _, key in ipairs(keys) do
					for _, seqName in ipairs(sequences) do
						if (seqName and seqName:lower():find(key, 1, true)) then
							return seqName
						end
					end
				end
				return nil
			end

			-- DComboBox no expone un método para contar/leer sus choices ya
			-- añadidos, así que llevamos la cuenta nosotros mismos en paralelo.
			local added = {}
			for _, a in ipairs(ANIMS) do
				if (not a.keys) then
					animCombo:AddChoice(a.label, "")
					added[#added + 1] = ""
				else
					local seq = findSequence(a.keys)
					if (seq) then
						animCombo:AddChoice(a.label, seq)
						added[#added + 1] = seq
					end
				end
			end

			-- Reseleccionar la animación actual si sigue disponible en este modelo
			local found = false
			for i, seq in ipairs(added) do
				if (seq == aAnim) then
					animCombo:ChooseOptionID(i)
					found = true
					break
				end
			end
			if (not found) then
				animCombo:ChooseOptionID(1)
				aAnim = ""
			end
		end
		refreshAnimCombo()

		-- Selector de bodygroups (depende del modelo elegido)
		local BG_Y = ANIM_Y + ANIM_H + SG

		local lblBg = aModal:Add("DLabel")
		lblBg:SetPos(SP, BG_Y); lblBg:SetSize(AW - SP * 2, SScale(14))
		lblBg:SetText("Bodygroups:"); lblBg:SetFont("Metro UI.CharFields")
		lblBg:SetTextColor(Color(150, 150, 150))

		local bgScroll = aModal:Add("DScrollPanel")
		bgScroll:SetPos(SP, BG_Y + SScale(14)); bgScroll:SetSize(AW - SP * 2, BG_H - SScale(14))
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
					row:Dock(TOP); row:DockMargin(0, 0, 0, SScale(1)); row:SetTall(SScale(14))
					row.Paint = function(me, w, h)
						surface.SetDrawColor(66, 66, 66, me:IsHovered() and 22 or 11)
						surface.DrawRect(0, 0, w, h)
					end

					local lbl = row:Add("DLabel")
					lbl:Dock(LEFT); lbl:DockMargin(SScale(4), 0, 0, 0); lbl:SetWide(SScale(160))
					lbl:SetFont("ixSmallFont"); lbl:SetTextColor(Color(190, 190, 190))
					lbl:SetContentAlignment(4)
					lbl:SetText((bg.name or ("Grupo " .. bg.id)):gsub("^%l", string.upper))

					local valLbl = row:Add("DLabel")
					valLbl:Dock(RIGHT); valLbl:SetWide(SScale(24))
					valLbl:SetFont("ixSmallFont"); valLbl:SetTextColor(Color(220, 220, 220))
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
					btnNext:Dock(RIGHT); btnNext:SetWide(SScale(16))

					local btnPrev = makeMetroBtn(row, "<", 66, 100, 166, function()
						local val = aBodygroups[bg.id]
						if (val > 0) then
							val = val - 1
							aBodygroups[bg.id] = val
							valLbl:SetText(tostring(val))
							ent:SetBodygroup(bg.id, val)
						end
					end)
					btnPrev:Dock(RIGHT); btnPrev:SetWide(SScale(16))
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

			-- Sólo conservar bodygroups válidos para el modelo final elegido
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
	end):SetBounds(W - SP - BCLS - SG - BSAVE - SG - BAPP, BTN_Y, BAPP, SBTN)

	makeMetroBtn(frame, "+ Guardar", 30, 120, 30, function()
		net.Start("traders_AdminSave")
			net.WriteEntity(traderEnt)
			-- Sólo enviar ítems no-playerStock (el servidor re-añade los playerStock)
			local adminItems = {}
			for _, slot in ipairs(workInv) do
				if (not slot.playerStock) then table.insert(adminItems, slot) end
			end
			net.WriteUInt(#adminItems, 8)
			for _, slot in ipairs(adminItems) do
				net.WriteString(slot.itemID)
				net.WriteUInt(math.Clamp(slot.qty,    0, 255),   8)
				net.WriteUInt(math.Clamp(slot.maxQty, 0, 255),   8)
				net.WriteUInt(math.Clamp(slot.price, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.buyPrice or 0, 0, 4294967295), 32)
				net.WriteUInt(math.Clamp(slot.minRep or 0, 0, 1000), 10)
			end
			net.WriteUInt(math.Clamp(workMaxSlots, 1, 255), 8)
			net.WriteString(selectedModel or "")
			net.WriteString(selectedAnim  or "")
			net.WriteString(nameEntry:GetValue())
			net.WriteString(loreEntry:GetValue())
			net.WriteUInt(#workAllowedFac, 8)
			for _, fk in ipairs(workAllowedFac) do net.WriteString(fk) end
			local bgList = {}
			for id, val in pairs(selectedBodygroups) do
				table.insert(bgList, {id = id, val = val})
			end
			net.WriteUInt(#bgList, 8)
			for _, bg in ipairs(bgList) do
				net.WriteUInt(bg.id,  8)
				net.WriteUInt(bg.val, 8)
			end
			net.WriteUInt(#workBuyWhitelist, 8)
			for _, bwlID in ipairs(workBuyWhitelist) do
				net.WriteString(bwlID)
			end
		net.SendToServer()
		chat.AddText(Color(80, 200, 80), "[Admin] Cambios guardados.")
		frame:Remove()
	end):SetBounds(W - SP - BCLS - SG - BSAVE, BTN_Y, BSAVE, SBTN)

	makeMetroBtn(frame, "Cerrar", 120, 30, 30, function()
		frame:Remove()
	end):SetBounds(W - SP - BCLS, BTN_Y, BCLS, SBTN)
end)

net.Receive("traders_WipePlayerStockResult", function()
	local removed = net.ReadUInt(16)
	chat.AddText(Color(80, 200, 80), "[Admin] Se han eliminado " .. removed .. " ítems de stock vendido por jugadores en todos los traders.")
end)

-- ============================================================
--  EDITOR DE PRECIOS GLOBALES
-- ============================================================

net.Receive("traders_PricesOpen", function()
	local openEditor = net.ReadBool()
	local sellLen    = net.ReadUInt(32)
	local sellJson   = net.ReadData(sellLen)
	local buyLen     = net.ReadUInt(32)
	local buyJson    = net.ReadData(buyLen)

	local savedSell = util.JSONToTable(sellJson) or {}
	local savedBuy  = util.JSONToTable(buyJson) or {}

	-- Siempre sincronizar las tablas globales del cliente
	ix.traders.globalPrices    = savedSell
	ix.traders.globalBuyPrices = savedBuy

	if (!openEditor) then return end

	if (IsValid(ix.traders._pricesFrame)) then ix.traders._pricesFrame:Remove() end

	local sw, sh = ScrW(), ScrH()
	local SP   = SScale(8)
	local SG   = SScale(4)
	local SHDR = SScale(22)
	local SROW = SScale(22)
	local SBTN = SScale(16)
	local MAX_RATIO = ix.traders.MAX_BUY_RATIO or 0.65

	local W = math.min(SScale(680), sw - SScale(40))
	local H = math.min(SScale(480), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H)
	frame:SetPos(sw / 2 - W / 2, sh / 2 - H / 2)
	frame:SetTitle(""); frame:SetDraggable(true)
	frame:ShowCloseButton(false); frame:MakePopup(); frame:SetDeleteOnClose(true)
	frame.Paint = function(self, w, h)
		ix.util.DrawBlur(self, 5)
		surface.SetDrawColor(33, 33, 33, 240)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(197, 199, 179, 200)
		surface.DrawRect(0, 0, w, SScale(3))
		surface.SetDrawColor(66, 66, 66, 88)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end
	ix.traders._pricesFrame = frame

	local lblTitle = frame:Add("DLabel")
	lblTitle:SetPos(SP, SP); lblTitle:SetSize(W - SScale(40), SScale(20))
	lblTitle:SetText("Editor de Precios Globales")
	lblTitle:SetFont("Metro UI.Button"); lblTitle:SetTextColor(Color(220, 220, 220))

	local lblInfo = frame:Add("DLabel")
	lblInfo:SetPos(SP, SScale(28)); lblInfo:SetSize(W - SP * 2, SScale(12))
	lblInfo:SetText("Compra: 0 = auto 50%. Max seguro = 65% de Venta. Items sin precio = no se venden.")
	lblInfo:SetFont("ixSmallFont"); lblInfo:SetTextColor(Color(140, 140, 140))

	local sep = frame:Add("DPanel")
	sep:SetPos(SP, SScale(42)); sep:SetSize(W - SP * 2, 1)
	sep.Paint = function(_, w, h) surface.SetDrawColor(ix.efgui.color.line); surface.DrawRect(0, 0, w, h) end

	local searchBar = frame:Add("DTextEntry")
	searchBar:SetPos(SP, SScale(48)); searchBar:SetSize(W - SP * 2, SScale(20))
	searchBar:SetFont("Metro UI.CharFields"); searchBar:SetPlaceholderText("Buscar por nombre o ID...")
	searchBar.Paint = paintDarkEntry

	-- Recopilar items
	local allItems = {}
	for uid, itemData in pairs(ix.item.list) do
		if (not itemData.noBusiness) then
			table.insert(allItems, {
				uid  = uid,
				name = itemData.name or uid,
				cat  = itemData.category or "Sin categoria",
			})
		end
	end
	table.sort(allItems, function(a, b)
		if (a.cat == b.cat) then return a.name < b.name end
		return a.cat < b.cat
	end)

	-- Copias de trabajo
	local workSell = {}
	local workBuy  = {}
	for _, entry in ipairs(allItems) do
		local uid = entry.uid
		local gs  = savedSell[uid]
		local ip  = ix.item.list[uid] and ix.item.list[uid].price
		workSell[uid] = gs or ip or 0
		workBuy[uid]  = savedBuy[uid] or 0
	end

	-- Layout
	local LIST_Y = SScale(74)
	local LIST_H = H - LIST_Y - SG - SBTN - SP - SScale(4)
	local BTN_Y  = LIST_Y + LIST_H + SG
	local INNER  = W - SP * 2

	local listPanel = frame:Add("DPanel")
	listPanel:SetPos(SP, LIST_Y); listPanel:SetSize(INNER, LIST_H)
	listPanel.Paint = paintPanel

	-- Columnas
	local COL_NAME  = math.floor(INNER * 0.30)
	local COL_ID    = math.floor(INNER * 0.18)
	local COL_SELL  = math.floor(INNER * 0.14)
	local COL_BUY   = math.floor(INNER * 0.14)
	local COL_MAX   = math.floor(INNER * 0.12)
	local COL_EFF   = INNER - COL_NAME - COL_ID - COL_SELL - COL_BUY - COL_MAX

	-- Header
	local hdr = listPanel:Add("DPanel")
	hdr:SetPos(0, 0); hdr:SetSize(INNER, SHDR)
	hdr.Paint = function(_, w, h) drawSectionHdr(w, h, "") end

	local function addHdr(text, x, cw, col)
		local l = hdr:Add("DLabel")
		l:SetPos(x, 0); l:SetSize(cw, SHDR)
		l:SetText(text); l:SetFont("Metro UI.CharFields")
		l:SetTextColor(col or Color(180, 180, 180)); l:SetContentAlignment(5)
	end
	addHdr("Item",    SScale(4), COL_NAME, Color(180, 180, 180))
	addHdr("ID",      COL_NAME,  COL_ID,   Color(130, 130, 130))
	addHdr("Venta",   COL_NAME + COL_ID, COL_SELL, Color(197, 199, 179))
	addHdr("Compra",  COL_NAME + COL_ID + COL_SELL, COL_BUY, Color(145, 148, 108))
	addHdr("Max",     COL_NAME + COL_ID + COL_SELL + COL_BUY, COL_MAX, Color(200, 80, 80))
	addHdr("Paga",    COL_NAME + COL_ID + COL_SELL + COL_BUY + COL_MAX, COL_EFF, Color(80, 200, 80))

	-- Scroll
	local scroll = listPanel:Add("DScrollPanel")
	scroll:SetPos(0, SHDR + SG); scroll:SetSize(INNER, LIST_H - SHDR - SG)
	local vbar = scroll:GetVBar()
	vbar:SetWide(SScale(4))
	vbar.Paint         = function(_, w, h) surface.SetDrawColor(33, 33, 33, 200); surface.DrawRect(0, 0, w, h) end
	vbar.btnUp.Paint   = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 200); surface.DrawRect(0, 0, w, h) end

	local itemRows = {}

	local function buildList(filter)
		scroll:Clear()
		itemRows = {}
		local filterLow = filter and string.lower(filter) or ""

		local lastCat = nil
		for _, entry in ipairs(allItems) do
			if (filterLow != "" and not string.find(string.lower(entry.name), filterLow, 1, true)
				and not string.find(string.lower(entry.uid), filterLow, 1, true)
				and not string.find(string.lower(entry.cat), filterLow, 1, true)) then
				continue
			end

			if (entry.cat != lastCat) then
				lastCat = entry.cat
				local catRow = scroll:Add("DPanel")
				catRow:Dock(TOP); catRow:DockMargin(0, SScale(2), 0, 0); catRow:SetTall(SScale(14))
				catRow.Paint = function(_, w, h)
					surface.SetDrawColor(175, 177, 148, 30)
					surface.DrawRect(0, 0, w, h)
					draw.SimpleText(entry.cat, "ixSmallFont", SScale(6), h / 2,
						Color(175, 177, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end

			local uid = entry.uid
			local row = scroll:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 0, 0, 1); row:SetTall(SROW)
			row.Paint = function(me, w, h)
				surface.SetDrawColor(44, 44, 44, me:IsHovered() and 180 or 120)
				surface.DrawRect(0, 0, w, h)
			end

			-- Nombre
			local lName = row:Add("DLabel")
			lName:SetPos(SScale(4), 0); lName:SetSize(COL_NAME - SScale(8), SROW)
			lName:SetText(entry.name); lName:SetFont("Metro UI.CharFields")
			lName:SetTextColor(Color(210, 210, 210))

			-- ID
			local lID = row:Add("DLabel")
			lID:SetPos(COL_NAME, 0); lID:SetSize(COL_ID - SScale(4), SROW)
			lID:SetText(uid); lID:SetFont("ixSmallFont")
			lID:SetTextColor(Color(110, 110, 110))

			-- Campo Venta (editable)
			local sellEntry = row:Add("DTextEntry")
			sellEntry:SetPos(COL_NAME + COL_ID, SScale(2))
			sellEntry:SetSize(COL_SELL - SScale(4), SROW - SScale(4))
			sellEntry:SetFont("Metro UI.CharFields")
			sellEntry:SetText(tostring(workSell[uid] or 0))
			sellEntry.Paint = paintDarkEntry
			sellEntry:SetNumeric(true)

			-- Campo Compra (editable, 0 = auto 50%)
			local buyEntry = row:Add("DTextEntry")
			buyEntry:SetPos(COL_NAME + COL_ID + COL_SELL, SScale(2))
			buyEntry:SetSize(COL_BUY - SScale(4), SROW - SScale(4))
			buyEntry:SetFont("Metro UI.CharFields")
			buyEntry:SetText(tostring(workBuy[uid] or 0))
			buyEntry.Paint = paintDarkEntry
			buyEntry:SetNumeric(true)

			-- Max (65% de venta, read-only)
			local lMax = row:Add("DLabel")
			lMax:SetPos(COL_NAME + COL_ID + COL_SELL + COL_BUY, 0)
			lMax:SetSize(COL_MAX, SROW)
			lMax:SetFont("ixSmallFont"); lMax:SetContentAlignment(5)

			-- Paga (precio efectivo, read-only)
			local lEff = row:Add("DLabel")
			lEff:SetPos(COL_NAME + COL_ID + COL_SELL + COL_BUY + COL_MAX, 0)
			lEff:SetSize(COL_EFF, SROW)
			lEff:SetFont("Metro UI.CharFields"); lEff:SetContentAlignment(5)

			local function updateLabels()
				local sv = math.max(0, math.floor(tonumber(sellEntry:GetValue()) or 0))
				local bv = math.max(0, math.floor(tonumber(buyEntry:GetValue()) or 0))
				workSell[uid] = sv
				workBuy[uid]  = bv

				local maxBuy = math.floor(sv * MAX_RATIO)
				lMax:SetText(sv > 0 and tostring(maxBuy) or "-")
				lMax:SetTextColor(Color(200, 80, 80))

				local effective
				if (bv > 0 and sv > 0) then
					effective = math.Clamp(bv, 1, math.max(1, maxBuy))
				elseif (sv > 0) then
					effective = math.max(1, math.floor(sv * 0.5))
				else
					effective = 0
				end

				lEff:SetText(effective > 0 and (effective .. " B") or "-")
				local overCap = (bv > 0 and bv > maxBuy and sv > 0)
				lEff:SetTextColor(overCap and Color(220, 80, 80) or Color(80, 200, 80))
			end
			updateLabels()
			sellEntry.OnChange = function() updateLabels() end
			buyEntry.OnChange  = function() updateLabels() end

			table.insert(itemRows, {uid = uid, sellEntry = sellEntry, buyEntry = buyEntry})
		end
	end

	buildList(nil)
	searchBar.OnChange = function(self) buildList(self:GetValue()) end

	-- Contador
	local lblCount = frame:Add("DLabel")
	lblCount:SetPos(SP, BTN_Y); lblCount:SetSize(W * 0.5, SBTN)
	lblCount:SetText(#allItems .. " items registrados")
	lblCount:SetFont("ixSmallFont"); lblCount:SetTextColor(Color(120, 120, 120))

	-- Botones
	local BSAVE = SScale(120)
	local BCLS  = SScale(80)

	makeMetroBtn(frame, "Guardar Precios", 66, 166, 66, function()
		for _, r in ipairs(itemRows) do
			if (IsValid(r.sellEntry)) then
				workSell[r.uid] = math.max(0, math.floor(tonumber(r.sellEntry:GetValue()) or 0))
			end
			if (IsValid(r.buyEntry)) then
				workBuy[r.uid] = math.max(0, math.floor(tonumber(r.buyEntry:GetValue()) or 0))
			end
		end

		local sendSell = {}
		local sendBuy  = {}
		for uid, price in pairs(workSell) do
			if (price > 0) then sendSell[uid] = price end
		end
		for uid, price in pairs(workBuy) do
			if (price > 0) then sendBuy[uid] = price end
		end

		local sellJson = util.TableToJSON(sendSell)
		local buyJson  = util.TableToJSON(sendBuy)
		net.Start("traders_PricesSave")
			net.WriteUInt(#sellJson, 32)
			net.WriteData(sellJson, #sellJson)
			net.WriteUInt(#buyJson, 32)
			net.WriteData(buyJson, #buyJson)
		net.SendToServer()

		chat.AddText(Color(80, 200, 80), "[Precios] Guardando precios...")
		frame:Remove()
	end):SetBounds(W - SP - BCLS - SG - BSAVE, BTN_Y, BSAVE, SBTN)

	makeMetroBtn(frame, "Cerrar", 120, 30, 30, function()
		frame:Remove()
	end):SetBounds(W - SP - BCLS, BTN_Y, BCLS, SBTN)
end)
