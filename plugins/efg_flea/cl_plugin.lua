local PLUGIN = PLUGIN

local function formatTime(seconds)
	return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function buildPanel(listings)
	local previousTab

	if (IsValid(ix.gui.efgFlea)) then
		previousTab = ix.gui.efgFlea.activeTab
		ix.gui.efgFlea:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 40, 900), math.min(ScrH() - 40, 620))
	frame:Center()
	frame:SetTitle("Mercadillo")
	frame:MakePopup()
	frame:DockPadding(8, ix.efgui.Scale(30) + 6, 8, 8)
	ix.efgui.StyleFrame(frame, "MERCADILLO")
	ix.gui.efgFlea = frame

	local sheet = frame:Add("DPropertySheet")
	sheet:Dock(FILL)

	-- ── Ofertas ─────────────────────────────────────────────────────────────
	local browse = vgui.Create("DPanel", sheet)
	browse.Paint = nil

	local search = browse:Add("DTextEntry")
	search:Dock(TOP)
	search:SetPlaceholderText("Buscar objeto...")

	local list = browse:Add("DListView")
	list:Dock(FILL)
	list:DockMargin(0, 4, 0, 4)
	list:SetMultiSelect(false)
	list:AddColumn("Objeto")
	list:AddColumn("Categoría"):SetFixedWidth(130)
	list:AddColumn("Precio (RUB)"):SetFixedWidth(110)
	list:AddColumn("Vendedor"):SetFixedWidth(150)
	list:AddColumn("Caduca en"):SetFixedWidth(80)

	local function fill()
		list:Clear()
		local filter = search:GetValue():lower()

		for _, listing in ipairs(listings) do
			if (!listing.mine and (filter == "" or listing.name:lower():find(filter, 1, true))) then
				local line = list:AddLine(listing.name, listing.category, string.Comma(listing.price), listing.sellerName, formatTime(listing.remaining))
				line.listing = listing
				line:SetSortValue(3, listing.price)
			end
		end

		list:SortByColumn(3)
	end

	search.OnChange = fill
	fill()

	local buy = browse:Add("DButton")
	buy:Dock(BOTTOM)
	buy:SetTall(28)
	buy:SetText("Comprar oferta seleccionada")
	ix.efgui.StyleButton(buy)
	buy.DoClick = function()
		local _, line = list:GetSelectedLine()
		if (!IsValid(line)) then return end

		Derma_Query(("¿Comprar %s por %s RUB?"):format(line.listing.name, string.Comma(line.listing.price)), "Mercadillo",
			"Comprar", function()
				net.Start("ixEFGFleaBuy")
					net.WriteUInt(line.listing.id, 32)
				net.SendToServer()
			end, "Cancelar")
	end

	sheet:AddSheet("Ofertas", browse, "icon16/cart.png")

	-- ── Vender ──────────────────────────────────────────────────────────────
	local sell = vgui.Create("DPanel", sheet)
	sell.Paint = nil

	local myList = sell:Add("DListView")
	myList:Dock(TOP)
	myList:SetTall(150)
	myList:SetMultiSelect(false)
	myList:AddColumn("Mis ofertas")
	myList:AddColumn("Precio (RUB)"):SetFixedWidth(110)
	myList:AddColumn("Caduca en"):SetFixedWidth(80)

	for _, listing in ipairs(listings) do
		if (listing.mine) then
			myList:AddLine(listing.name, string.Comma(listing.price), formatTime(listing.remaining)).listing = listing
		end
	end

	myList.OnRowRightClick = function(_, _, line)
		local menu = DermaMenu()
		menu:AddOption("Retirar oferta", function()
			net.Start("ixEFGFleaCancel")
				net.WriteUInt(line.listing.id, 32)
			net.SendToServer()
		end)
		menu:Open()
	end

	local hint = sell:Add("DLabel")
	hint:Dock(TOP)
	hint:DockMargin(0, 4, 0, 4)
	hint:SetText(("Clic derecho en una oferta para retirarla. Comisión al publicar: %d%%."):format(ix.config.Get("efgFleaFee", 5)))
	hint:SizeToContents()

	local itemList = sell:Add("DListView")
	itemList:Dock(FILL)
	itemList:SetMultiSelect(false)
	itemList:AddColumn("Tu inventario")
	itemList:AddColumn("Precio de comerciante (RUB)"):SetFixedWidth(170)

	local character = LocalPlayer():GetCharacter()
	local inventory = character and character:GetInventory()

	if (inventory) then
		for _, item in pairs(inventory:GetItems(true)) do
			if (!item:GetData("equip") and ix.efg.flea.CanList(item)) then
				local reference = ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(item.uniqueID) or (item.price or 0)
				itemList:AddLine(item:GetName(), string.Comma(reference)).item = item
			end
		end
	end

	local bottom = sell:Add("DPanel")
	bottom:Dock(BOTTOM)
	bottom:SetTall(28)
	bottom.Paint = nil

	local price = bottom:Add("DNumberWang")
	price:Dock(LEFT)
	price:SetWide(140)
	price:SetMinMax(1, 99999999)
	price:SetDecimals(0)
	price:SetValue(1000)

	itemList.OnRowSelected = function(_, _, line)
		local reference = ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(line.item.uniqueID) or 0
		if (reference > 0) then price:SetValue(reference) end
	end

	local publish = bottom:Add("DButton")
	publish:Dock(FILL)
	publish:DockMargin(4, 0, 0, 0)
	publish:SetText("Poner a la venta")
	ix.efgui.StyleButton(publish)
	publish.DoClick = function()
		local _, line = itemList:GetSelectedLine()
		if (!IsValid(line)) then return end

		net.Start("ixEFGFleaSell")
			net.WriteUInt(line.item.id, 32)
			net.WriteUInt(math.Clamp(math.floor(price:GetValue()), 1, 99999999), 32)
		net.SendToServer()
	end

	sheet:AddSheet("Vender", sell, "icon16/money.png")

	if (previousTab) then
		sheet:SwitchToName(previousTab)
	end

	sheet.OnActiveTabChanged = function(_, _, new)
		frame.activeTab = new:GetText()
	end
end

net.Receive("ixEFGFleaState", function()
	buildPanel(net.ReadTable())
end)
