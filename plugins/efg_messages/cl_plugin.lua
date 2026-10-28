local PLUGIN = PLUGIN

local function S(v) return ix.efgui and ix.efgui.Scale and ix.efgui.Scale(v) or v end

local function styleFrame(frame, title)
	if (ix.efgui and ix.efgui.StyleFrame) then
		ix.efgui.StyleFrame(frame, title)
	else
		frame:SetTitle(title)
	end

	if (ix.efgui and ix.efgui.RegisterEsc) then ix.efgui.RegisterEsc(frame) end
end

local function textColor(dim)
	local c = ix.efgui and ix.efgui.color
	return c and (dim and c.textDim or c.text) or (dim and Color(150, 150, 150) or color_white)
end

-- ─── Mensajes ───────────────────────────────────────────────────────────────
net.Receive("ixEFGMessageNew", function()
	local from, text = net.ReadString(), net.ReadString()
	surface.PlaySound("buttons/button9.wav")
	chat.AddText(Color(227, 114, 45), "[" .. from .. "] ", color_white, text)
end)

net.Receive("ixEFGMessagesOpen", function()
	local character = LocalPlayer():GetCharacter()
	if (!character) then return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 80, S(820)), math.min(ScrH() - 80, S(560)))
	frame:Center()
	frame:MakePopup()
	styleFrame(frame, "MENSAJES")

	local list = frame:Add("DScrollPanel")
	list:Dock(FILL)

	local messages = character:GetData("efgMessages", {})

	if (#messages == 0) then
		local empty = list:Add("DLabel")
		empty:Dock(TOP)
		empty:SetText("No tienes mensajes.")
		empty:SetTextColor(textColor(true))
	end

	for _, m in ipairs(messages) do
		local row = list:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, 4)
		row:SetTall(S(54))
		row.Paint = function(_, w, h)
			surface.SetDrawColor(28, 30, 27, 235)
			surface.DrawRect(0, 0, w, h)
			draw.SimpleText(m.from or "?", "ixSmallBoldFont", 10, 8, Color(227, 114, 45))
			draw.SimpleText(os.date("%d/%m %H:%M", m.time or 0), "ixSmallFont", w - 10, 8, textColor(true), TEXT_ALIGN_RIGHT)
			draw.SimpleText(m.text or "", "ixSmallFont", 10, h - 22, textColor())
		end
	end
end)

-- ─── Manual (Handbook) ──────────────────────────────────────────────────────
local function priceOf(item)
	return (ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(item.uniqueID)) or item.price or 0
end

net.Receive("ixEFGHandbookOpen", function()
	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 80, S(1100)), math.min(ScrH() - 80, S(700)))
	frame:Center()
	frame:MakePopup()
	styleFrame(frame, "MANUAL")

	local search = frame:Add("DTextEntry")
	search:Dock(TOP)
	search:SetPlaceholderText("Buscar…")
	search:DockMargin(0, 0, 0, 6)

	local tree = frame:Add("DTree")
	tree:Dock(LEFT)
	tree:SetWide(S(300))

	local detail = frame:Add("DPanel")
	detail:Dock(FILL)
	detail:DockMargin(6, 0, 0, 0)

	local model = detail:Add("DModelPanel")
	model:Dock(TOP)
	model:SetTall(S(220))

	local info = detail:Add("RichText")
	info:Dock(FILL)

	local function show(item)
		model:SetModel(item.model or "models/props_junk/cardboard_box004a.mdl")

		local entity = model:GetEntity()

		if (IsValid(entity)) then
			local mins, maxs = entity:GetRenderBounds()
			local size = math.max((maxs - mins):Length(), 8)
			model:SetCamPos(Vector(size, size, size * 0.6))
			model:SetLookAt((mins + maxs) / 2)
		end

		info:SetText("")
		info:InsertColorChange(227, 114, 45, 255)
		info:AppendText(item.name .. "\n\n")
		info:InsertColorChange(200, 198, 180, 255)
		info:AppendText(("Precio: %s RUB\nTamaño: %dx%d\nCategoría: %s\n\n"):format(string.Comma(priceOf(item)),
			item.width or 1, item.height or 1, item.category or "-"))
		info:AppendText(item.description or "")
	end

	local function build(filter)
		tree:Clear()
		filter = filter and filter:lower() or ""

		local byCategory = {}

		for _, item in pairs(ix.item.list) do
			if (!item.isBase and !item.noBusiness and isstring(item.name)
				and (filter == "" or item.name:lower():find(filter, 1, true))) then
				local cat = item.category or "Otros"
				byCategory[cat] = byCategory[cat] or {}
				table.insert(byCategory[cat], item)
			end
		end

		for cat, items in SortedPairs(byCategory) do
			local node = tree:AddNode(cat .. " (" .. #items .. ")", "icon16/folder.png")

			table.sort(items, function(a, b) return a.name < b.name end)

			for _, item in ipairs(items) do
				local leaf = node:AddNode(item.name, "icon16/brick.png")
				leaf.DoClick = function() show(item) end
			end

			if (filter != "") then node:SetExpanded(true) end
		end
	end

	search.OnChange = function(self) build(self:GetValue()) end
	build()
end)
