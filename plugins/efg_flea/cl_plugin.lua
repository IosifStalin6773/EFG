-- ─── Mercadillo como el de EFT ───────────────────────────────────────────────
-- Pestaña MERCADILLO del TAB: arriba OFERTAS / MIS OFERTAS, buscador, orden y
-- AÑADIR OFERTA; a la izquierda las categorías y en el centro las ofertas con
-- icono, vendedor, precio en rublos, caducidad y botón COMPRAR. Añadir oferta
-- abre una ventana con tu inventario en rejilla y el precio.

local PLUGIN = PLUGIN

PLUGIN.clientListings = PLUGIN.clientListings or {}

local function formatTime(seconds)
	seconds = math.max(0, seconds or 0)
	return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function rub(n)
	return string.Comma(math.floor(tonumber(n) or 0)) .. " ₽"
end

local function referencePrice(uniqueID)
	if (ix.traders and ix.traders.GetGlobalPrice) then
		return ix.traders.GetGlobalPrice(uniqueID) or 0
	end

	local item = ix.item.list[uniqueID]
	return item and item.price or 0
end

local function canUseLocally()
	local client = LocalPlayer()
	local character = client:GetCharacter()
	if (!character) then return false, "Sin personaje." end
	if (client.InRaid and client:InRaid()) then return false, "No puedes usar el mercadillo durante una raid." end

	local required = ix.config.Get("efgFleaLevel", 15)
	local level = character.GetEFGLevel and character:GetEFGLevel() or 1

	if (level < required) then
		return false, ("El mercadillo se desbloquea al nivel %d (tú: nivel %d)."):format(required, level)
	end

	return true
end

-- celda con el icono del objeto, como las de la rejilla del inventario
local function drawItemCell(item, x, y, w, h)
	local UI = ix.efgui
	UI.DrawCell(x, y, w, h, "normal", true)

	if (!item) then return end

	if (!ix.efg.icons.Draw(item, x + 3, y + 3, w - 6, h - 6)) then
		draw.SimpleText(string.upper(string.sub(item.name or "?", 1, 3)), "efgx.Header", x + w / 2, y + h / 2, UI.color.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (UI.DrawRarity and item.rarity) then
		UI.DrawRarity(x, y, w, h, item.rarity)
	end
end

net.Receive("ixEFGFleaState", function()
	PLUGIN.clientListings = net.ReadTable()

	if (IsValid(ix.gui.efgFlea)) then
		ix.gui.efgFlea:SetListings(PLUGIN.clientListings)
		return
	end

	-- /Mercadillo fuera del TAB: abrir el TAB en la pestaña del mercadillo
	if (IsValid(ix.gui.metroInventory)) then
		ix.gui.metroInventory:SwitchTab("flea")
	elseif (vgui.GetControlTable("ixMetroInventory")) then
		ix.gui.invKeyStartTab = "flea"
		ix.gui.metroInventory = vgui.Create("ixMetroInventory")
	end
end)

-- ════════════════════════════════════════════════════════════════════════════
local PANEL = {}

function PANEL:Init()
	ix.gui.efgFlea = self

	self.mode = "browse"
	self.category = nil
	self.search = ""
	self.sort = "price"
	self.listings = PLUGIN.clientListings or {}

	local ok, why = canUseLocally()
	self.locked = !ok and why

	if (ok) then
		net.Start("ixEFGFleaRequest")
		net.SendToServer()
	end
end

function PANEL:OnRemove()
	if (ix.gui.efgFlea == self) then ix.gui.efgFlea = nil end
	if (IsValid(self.addWindow)) then self.addWindow:Remove() end
end

function PANEL:SetListings(listings)
	self.listings = listings or {}
	self:Rebuild()
end

function PANEL:PerformLayout(w, h)
	if (self.builtW == w and self.builtH == h) then return end
	self.builtW, self.builtH = w, h
	self:Rebuild()
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(10, 12, 12, 200)
	surface.DrawRect(0, 0, w, h)

	if (self.locked) then
		local c = ix.efgui.color
		draw.SimpleText("MERCADILLO BLOQUEADO", "efgx.Display", w / 2, h / 2 - ix.efgui.Scale(20), c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(self.locked, "efgx.Body", w / 2, h / 2 + ix.efgui.Scale(20), c.text2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function PANEL:Filtered()
	local out = {}
	local query = string.lower(self.search or "")

	for _, listing in ipairs(self.listings) do
		if (self.mode == "browse" and listing.mine) then continue end
		if (self.mode == "mine" and !listing.mine) then continue end
		if (self.category and listing.category != self.category) then continue end
		if (query != "" and !string.lower(listing.name or ""):find(query, 1, true)) then continue end

		out[#out + 1] = listing
	end

	local sort = self.sort
	table.sort(out, function(a, b)
		if (sort == "priceDesc") then return a.price > b.price end
		if (sort == "name") then return tostring(a.name) < tostring(b.name) end
		if (sort == "expires") then return a.remaining < b.remaining end
		return a.price < b.price
	end)

	return out
end

function PANEL:Rebuild()
	self:Clear()
	if (self.locked) then return end

	local w, h = self:GetSize()
	if (w < 50 or h < 50) then return end

	local UI = ix.efgui
	local S = UI.Scale
	local c = UI.color
	local character = LocalPlayer():GetCharacter()

	-- ── barra superior ────────────────────────────────────────────────
	local barH = S(44)
	local bar = self:Add("DPanel")
	bar:SetPos(0, 0)
	bar:SetSize(w, barH)
	bar.Paint = function(_, pw, ph)
		surface.SetDrawColor(14, 16, 16, 240)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(c.line)
		surface.DrawRect(0, ph - 1, pw, 1)

		if (character) then
			draw.SimpleText(rub(character:GetMoney()), "efgx.Num", pw - S(12), ph / 2, c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local x = S(8)
	for _, m in ipairs({{"browse", "OFERTAS"}, {"mine", "MIS OFERTAS"}}) do
		local b = bar:Add("DButton")
		b:SetPos(x, S(7))
		b:SetSize(S(150), barH - S(14))
		b:SetText(m[2])
		UI.StyleButton(b, "efgx.Header")
		b.efgActive = self.mode == m[1]
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self.mode = m[1]
			self:Rebuild()
		end
		x = x + S(156)
	end

	local search = bar:Add("DTextEntry")
	search:SetPos(x + S(10), S(8))
	search:SetSize(S(300), barH - S(16))
	search:SetFont("efgx.Body")
	search:SetPlaceholderText("Buscar objeto…")
	search:SetValue(self.search or "")
	search:SetUpdateOnType(true)
	search.Paint = function(this, pw, ph)
		surface.SetDrawColor(8, 9, 9, 255)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(this:HasFocus() and c.accent or c.line)
		surface.DrawOutlinedRect(0, 0, pw, ph)
		this:DrawTextEntryText(c.text, c.accent, c.text)

		if (this:GetValue() == "" and !this:HasFocus()) then
			draw.SimpleText("Buscar objeto…", "efgx.Body", S(6), ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	search.OnValueChange = function(_, value)
		self.search = value
		self:FillRows()
	end
	self.searchEntry = search

	local sort = bar:Add("DComboBox")
	sort:SetPos(x + S(320), S(8))
	sort:SetSize(S(190), barH - S(16))
	sort:SetFont("efgx.Small")
	sort:SetTextColor(c.text)
	sort.Paint = function(_, pw, ph)
		surface.SetDrawColor(8, 9, 9, 255)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(c.line)
		surface.DrawOutlinedRect(0, 0, pw, ph)
	end
	local sorts = {{"price", "Precio: menor primero"}, {"priceDesc", "Precio: mayor primero"}, {"name", "Nombre"}, {"expires", "Caduca antes"}}
	for _, opt in ipairs(sorts) do sort:AddChoice(opt[2], opt[1], opt[1] == self.sort) end
	sort.OnSelect = function(_, _, _, value)
		self.sort = value
		self:FillRows()
	end

	local add = bar:Add("DButton")
	add:SetSize(S(190), barH - S(14))
	add:SetPos(w - S(190) - S(170), S(7))
	add:SetText("AÑADIR OFERTA")
	UI.StyleButton(add, "efgx.Header", "primary")
	add.DoClick = function()
		surface.PlaySound("efg/ui/click.wav")
		self:OpenAddOffer()
	end

	-- ── categorías ────────────────────────────────────────────────────
	local top = barH + S(8)
	local catW = S(250)
	local cats = vgui.Create("DScrollPanel", self)
	cats:SetPos(0, top)
	cats:SetSize(catW, h - top)
	cats.Paint = function(_, pw, ph) UI.DrawPanel(0, 0, pw, ph, 235, 0) end

	local counts, order, total = {}, {}, 0
	for _, listing in ipairs(self.listings) do
		if ((self.mode == "browse") == !listing.mine) then
			if (!counts[listing.category]) then order[#order + 1] = listing.category end
			counts[listing.category] = (counts[listing.category] or 0) + 1
			total = total + 1
		end
	end
	table.sort(order)

	local function catRow(label, key, count)
		local b = cats:Add("DButton")
		b:Dock(TOP)
		b:SetTall(S(32))
		b:SetText("")
		b.Paint = function(this, pw, ph)
			local sel = self.category == key
			if (sel) then
				surface.SetDrawColor(46, 44, 36, 245)
				surface.DrawRect(0, 0, pw, ph)
				surface.SetDrawColor(c.accent)
				surface.DrawRect(0, 0, S(3), ph)
			elseif (this:IsHovered()) then
				surface.SetDrawColor(c.select)
				surface.DrawRect(0, 0, pw, ph)
			end

			-- icono de categoría EFT (ix.efg.utils.categories)
			local utils = ix.efg and ix.efg.utils
			local tx = S(14)
			if (utils and utils.DrawUI(utils.categories[key or ""], S(10), S(6), S(30), ph - S(12), sel and c.text or c.textDim)) then
				tx = S(46)
			end

			draw.SimpleText(label, "efgx.Body", tx, ph / 2, sel and c.text or c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(count, "efgx.Num", pw - S(12), ph / 2, c.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			self.category = key
			self:Rebuild()
		end
	end

	catRow("Todas las ofertas", nil, total)
	for _, cat in ipairs(order) do catRow(cat, cat, counts[cat]) end

	-- ── ofertas ───────────────────────────────────────────────────────
	local lx = catW + S(8)
	local listW = w - lx

	local head = self:Add("DPanel")
	head:SetPos(lx, top)
	head:SetSize(listW, S(26))
	self.cols = {name = S(84), seller = listW * 0.42, price = listW * 0.66, expires = listW * 0.80}
	head.Paint = function(_, pw, ph)
		surface.SetDrawColor(c.bg2)
		surface.DrawRect(0, 0, pw, ph)
		local cols = self.cols
		draw.SimpleText("OBJETO", "efgx.Label", cols.name, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(self.mode == "mine" and "" or "VENDEDOR", "efgx.Label", cols.seller, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("PRECIO", "efgx.Label", cols.price, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("CADUCA EN", "efgx.Label", cols.expires, ph / 2, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local rows = self:Add("DScrollPanel")
	rows:SetPos(lx, top + S(28))
	rows:SetSize(listW, h - top - S(28))
	self.rows = rows

	self:FillRows()
end

function PANEL:FillRows()
	if (!IsValid(self.rows)) then return end
	self.rows:Clear()

	local UI = ix.efgui
	local S = UI.Scale
	local c = UI.color
	local cols = self.cols
	local list = self:Filtered()

	if (#list == 0) then
		local l = self.rows:Add("DLabel")
		l:Dock(TOP)
		l:DockMargin(S(12), S(14), 0, 0)
		l:SetFont("efgx.Body")
		l:SetTextColor(c.textDim)
		l:SetText(self.mode == "mine"
			and ("No tienes ofertas publicadas. Pulsa AÑADIR OFERTA (máximo %d)."):format(ix.config.Get("efgFleaMaxOffers", 5))
			or "No hay ofertas con estos filtros.")
		l:SizeToContents()
		return
	end

	for _, listing in ipairs(list) do
		local item = ix.item.list[listing.itemID]
		local ref = referencePrice(listing.itemID)

		local row = self.rows:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, S(2))
		row:SetTall(S(72))
		row.Paint = function(this, pw, ph)
			local hovered = this:IsHovered() or this:IsChildHovered()
			surface.SetDrawColor(hovered and Color(30, 32, 32, 245) or Color(20, 22, 22, 235))
			surface.DrawRect(0, 0, pw, ph)
			surface.SetDrawColor(c.line)
			surface.DrawRect(0, ph - 1, pw, 1)

			drawItemCell(item, S(8), S(6), S(64), ph - S(12))

			draw.SimpleText(listing.name or "?", "efgx.Header", cols.name, ph / 2 - S(2), c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(string.upper(listing.category or ""), "efgx.Label", cols.name, ph / 2 + S(4), c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			if (!listing.mine) then
				draw.SimpleText(listing.sellerName or "?", "efgx.Body", cols.seller, ph / 2, c.info, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(rub(listing.price), "efgx.Header", cols.price, ph / 2 - S(2), c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			if (ref > 0) then
				local diff = listing.price / ref
				local col = diff <= 1 and c.green or (diff <= 1.5 and c.text2 or c.red)
				draw.SimpleText(("Comerciante: %s"):format(rub(ref)), "efgx.Label", cols.price, ph / 2 + S(4), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end

			draw.SimpleText(formatTime(listing.remaining), "efgx.Num", cols.expires, ph / 2, c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local btn = row:Add("DButton")
		btn:Dock(RIGHT)
		btn:DockMargin(0, S(18), S(10), S(18))
		btn:SetWide(S(130))

		if (listing.mine) then
			btn:SetText("RETIRAR")
			UI.StyleButton(btn, "efgx.Header")
			btn.DoClick = function()
				surface.PlaySound("efg/ui/click.wav")
				net.Start("ixEFGFleaCancel")
					net.WriteUInt(listing.id, 32)
				net.SendToServer()
			end
		else
			local character = LocalPlayer():GetCharacter()
			btn:SetText("COMPRAR")
			UI.StyleButton(btn, "efgx.Header", "primary")
			btn:SetEnabled(character and character:GetMoney() >= listing.price)
			btn.DoClick = function()
				surface.PlaySound("efg/ui/click.wav")
				Derma_Query(("¿Comprar %s por %s?"):format(listing.name, rub(listing.price)), "Mercadillo", "Comprar", function()
					net.Start("ixEFGFleaBuy")
						net.WriteUInt(listing.id, 32)
					net.SendToServer()
				end, "Cancelar")
			end
		end
	end
end

-- ─── Añadir oferta ───────────────────────────────────────────────────────────
function PANEL:OpenAddOffer()
	if (IsValid(self.addWindow)) then self.addWindow:Remove() end

	local UI = ix.efgui
	local S = UI.Scale
	local c = UI.color
	local character = LocalPlayer():GetCharacter()
	local inventory = character and character:GetInventory()
	if (!inventory) then return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - S(80), S(1000)), math.min(ScrH() - S(80), S(640)))
	frame:Center()
	frame:MakePopup()
	frame:DockPadding(S(10), S(40), S(10), S(10))
	UI.StyleFrame(frame, "AÑADIR OFERTA")
	self.addWindow = frame

	local selected
	local fee = ix.config.Get("efgFleaFee", 5)

	-- derecha: objeto elegido y precio
	local side = frame:Add("DPanel")
	side:Dock(RIGHT)
	side:SetWide(S(330))
	side:DockMargin(S(10), 0, 0, 0)
	side:DockPadding(S(14), S(14), S(14), S(14))
	side.Paint = function(_, pw, ph)
		UI.DrawPanel(0, 0, pw, ph, 235)

		if (!selected) then
			draw.SimpleText("Elige un objeto de tu inventario.", "efgx.Body", pw / 2, S(90), c.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		drawItemCell(selected, S(14), S(14), S(128), S(128))
		draw.SimpleText(selected:GetName(), "efgx.Header", S(156), S(20), c.text)
		draw.SimpleText(string.upper(selected.category or "Otros"), "efgx.Label", S(156), S(46), c.textDim)

		local ref = referencePrice(selected.uniqueID)
		draw.SimpleText("PRECIO DE COMERCIANTE", "efgx.Label", S(156), S(80), c.textDim)
		draw.SimpleText(ref > 0 and rub(ref) or "—", "efgx.Num", S(156), S(96), c.text2)
	end

	local priceLabel = side:Add("DLabel")
	priceLabel:Dock(TOP)
	priceLabel:DockMargin(0, S(150), 0, S(4))
	priceLabel:SetFont("efgx.Label")
	priceLabel:SetTextColor(c.textDim)
	priceLabel:SetText("PEDIR (RUBLOS)")

	local price = side:Add("DTextEntry")
	price:Dock(TOP)
	price:SetTall(S(36))
	price:SetFont("efgx.Num")
	price:SetNumeric(true)
	price:SetValue("1000")
	price.Paint = function(this, pw, ph)
		surface.SetDrawColor(8, 9, 9, 255)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(this:HasFocus() and c.accent or c.line)
		surface.DrawOutlinedRect(0, 0, pw, ph)
		this:DrawTextEntryText(c.text, c.accent, c.text)
	end

	local info = side:Add("DPanel")
	info:Dock(TOP)
	info:DockMargin(0, S(10), 0, 0)
	info:SetTall(S(90))
	info.Paint = function(_, pw, ph)
		local value = tonumber(price:GetValue()) or 0
		local cost = selected and ix.efg.flea.Fee(selected, value) or 0
		local money = character:GetMoney()

		draw.SimpleText("COMISIÓN", "efgx.Label", 0, S(4), c.textDim)
		draw.SimpleText(rub(cost), "efgx.Num", pw, S(4), money >= cost and c.text or c.red, TEXT_ALIGN_RIGHT)
		draw.SimpleText("RECIBIRÁS", "efgx.Label", 0, S(30), c.textDim)
		draw.SimpleText(rub(value), "efgx.Num", pw, S(30), c.green, TEXT_ALIGN_RIGHT)
		draw.SimpleText("DURACIÓN", "efgx.Label", 0, S(56), c.textDim)
		draw.SimpleText(ix.config.Get("efgFleaHours", 24) .. " h", "efgx.Num", pw, S(56), c.text2, TEXT_ALIGN_RIGHT)
	end

	local publish = side:Add("DButton")
	publish:Dock(BOTTOM)
	publish:SetTall(S(44))
	publish:SetText("PONER A LA VENTA")
	UI.StyleButton(publish, "efgx.Header", "primary")
	publish.Think = function(this)
		local value = tonumber(price:GetValue()) or 0
		this:SetEnabled(selected != nil and value >= 1 and character:GetMoney() >= ix.efg.flea.Fee(selected, value))
	end
	publish.DoClick = function()
		if (!selected) then return end
		surface.PlaySound("efg/ui/click.wav")

		net.Start("ixEFGFleaSell")
			net.WriteUInt(selected.id, 32)
			net.WriteUInt(math.Clamp(math.floor(tonumber(price:GetValue()) or 1), 1, 99999999), 32)
		net.SendToServer()

		frame:Remove()
	end

	-- izquierda: inventario en rejilla
	local grid = frame:Add("DScrollPanel")
	grid:Dock(FILL)
	grid.Paint = function(_, pw, ph) UI.DrawPanel(0, 0, pw, ph, 235, 0) end

	local layout = grid:Add("DIconLayout")
	layout:Dock(TOP)
	layout:DockMargin(S(8), S(8), S(8), S(8))
	layout:SetSpaceX(S(4))
	layout:SetSpaceY(S(4))

	local items = {}
	for _, item in pairs(inventory:GetItems(true)) do
		if (!item:GetData("equip") and ix.efg.flea.CanList(item)) then
			items[#items + 1] = item
		end
	end
	table.sort(items, function(a, b) return tostring(a:GetName()) < tostring(b:GetName()) end)

	if (#items == 0) then
		local l = layout:Add("DLabel")
		l:SetFont("efgx.Body")
		l:SetTextColor(c.textDim)
		l:SetText("No tienes nada que se pueda vender (lo equipado no cuenta).")
		l:SizeToContents()
	end

	for _, item in ipairs(items) do
		local cell = layout:Add("DButton")
		cell:SetSize(S(84), S(84))
		cell:SetText("")
		cell:SetTooltip(item:GetName())
		cell.Paint = function(this, pw, ph)
			drawItemCell(item, 0, 0, pw, ph)

			if (selected == item) then
				surface.SetDrawColor(c.accent)
				surface.DrawOutlinedRect(0, 0, pw, ph, 2)
			elseif (this:IsHovered()) then
				surface.SetDrawColor(c.lineHi)
				surface.DrawOutlinedRect(0, 0, pw, ph, 1)
			end

			draw.SimpleText(item:GetName(), "efgx.Label", S(4), ph - S(3), c.text2, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
		cell.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")
			selected = item

			local ref = referencePrice(item.uniqueID)
			if (ref > 0) then price:SetValue(tostring(ref)) end
		end
	end
end

vgui.Register("efgxFlea", PANEL, "DPanel")
