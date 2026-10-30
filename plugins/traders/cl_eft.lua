-- Pantalla de comerciante de EFT (DHTML): diálogo con el retrato del
-- comerciante, compra con la rejilla de su surtido y venta arrastrando tus
-- objetos a la mesa. Se apoya en los mismos nets de siempre (traders_OpenDialogue,
-- traders_OpenTrade, traders_Purchase) y en traders_SellItems para vender por
-- objetos concretos. Con tradersEFTUI apagado vuelven las ventanas antiguas.

local PLUGIN = PLUGIN
local ASSET = "asset://garrysmod/"

ix.config.Add("tradersEFTUI", true, "Pantalla de comerciante al estilo de EFT (diálogo, compra y venta en una sola ventana).", nil, {
	category = "Traders"
})

ix.traders.eft = ix.traders.eft or {}
local EFT = ix.traders.eft

local ROMAN = {"I", "II", "III", "IV"}

-- retrato del comerciante: vídeo en bucle si existe materials/efg/traders/<clave>.webm,
-- si no la imagen de efgui/traders
local function portraitOf(key)
	local video = "materials/efg/traders/" .. key .. ".webm"
	if (file.Exists(video, "GAME")) then return {video = ASSET .. video} end

	for _, path in ipairs({"materials/efg/traders/" .. key .. ".png", "materials/efgui/traders/" .. key .. ".png"}) do
		if (file.Exists(path, "GAME")) then return {image = ASSET .. path} end
	end

	return {}
end

local function repInfo(rep)
	local level = ix.traders.GetRepLevel(rep)
	local index = 1

	for i, entry in ipairs(ix.traders.repLevels) do
		if (entry == level) then index = i end
	end

	return {ll = ROMAN[index] or "I", index = index, name = level.name, rep = rep, discount = level.discount or 0,
		sellBonus = level.sellBonus or 0}
end

local function itemCategory(itemTable)
	if (itemTable.isWeapon or itemTable.isARC9) then return "weapon" end
	if (itemTable.isMagazine or itemTable.isAmmo) then return "ammo" end
	if (itemTable.isEFGMod) then return "mod" end
	if (ix.GetEquipSlotKind and ix.GetEquipSlotKind(itemTable)) then return "gear" end

	local cat = string.lower(itemTable.category or "")
	if (cat:find("medic")) then return "med" end
	if (cat:find("consum") or cat:find("comida") or cat:find("provis")) then return "food" end

	return "other"
end

local function iconOf(itemTable)
	local path = ix.efg.icons and ix.efg.icons.Resolve(itemTable)
	return path and (ASSET .. "materials/" .. path) or nil
end

-- precio unitario que se cobra ahora (escasez + descuento por lealtad), como el servidor
local function unitBuyPrice(slot, remaining, discount)
	local scarcity = ix.traders.GetStockPriceMultiplier(remaining, slot.maxQty)
	return math.max(1, math.floor(slot.price * scarcity * (1 - discount / 100)))
end

-- lo que pagaría el comerciante por un objeto (aprox.: misma fórmula que traders_SellItems)
local function sellEstimate(state, item)
	if (!state.buyWhitelist[item.uniqueID] or item:GetData("equip")) then return false end

	local slot
	for _, s in ipairs(state.traderInv or {}) do
		if (s.itemID == item.uniqueID) then slot = s break end
	end

	local base = ix.traders.GetEffectiveBuyPrice(slot and slot.buyPrice, item.uniqueID)
	if (base <= 0) then base = 1 end

	local info = repInfo(state.rep or 0)
	local oversupply = slot and ix.traders.GetSellToTraderMultiplier(slot.qty, slot.maxQty) or 1
	local unit = math.max(1, math.floor(base * (1 + info.sellBonus / 100) * oversupply))
	local amount = item:GetData("Amount", 1)

	if (amount > 1) then return unit * amount end
	return math.max(1, math.floor(unit * ix.traders.GetConditionFactor(item.uniqueID, item.data)))
end

-- ─── Datos para la página ────────────────────────────────────────────────────
function EFT.BuildPayload(panel)
	local state = panel.state
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local info = repInfo(state.rep or 0)

	local payload = {
		key = state.factionKey,
		name = state.traderName,
		portrait = portraitOf(state.factionKey),
		rep = info,
		money = character:GetMoney(),
		admin = client:IsAdmin(),
		tab = panel.tab or "dialog",
		dialog = panel.dialogView,
		hasTrade = state.traderInv != nil,
		stock = {},
		message = panel.message
	}

	for i, slot in ipairs(state.traderInv or {}) do
		local itemTable = ix.item.list[slot.itemID]

		if (itemTable and slot.qty > 0) then
			local unit = math.max(1, math.floor(unitBuyPrice(slot, slot.qty, info.discount) * (slot.condPct or 100) / 100))
			local locked = (state.rep or 0) < (slot.minRep or 0)

			payload.stock[#payload.stock + 1] = {
				i = i,
				uid = slot.itemID,
				name = itemTable.name,
				icon = iconOf(itemTable),
				w = itemTable.width or 1,
				h = itemTable.height or 1,
				qty = slot.qty,
				maxQty = slot.maxQty,
				price = unit,
				cat = itemCategory(itemTable),
				locked = locked,
				ll = locked and repInfo(slot.minRep or 0).ll or nil,
				used = slot.usedCount > 0 and slot.condition or nil,
				cond = slot.condPct,
				desc = (itemTable.description or ""):sub(1, 260),
				weight = tonumber(itemTable.weight) or 0
			}
		end
	end

	-- tus objetos (bolsillos, equipo puesto y alijo) con lo que pagaría por cada uno
	if (ix.efg.invhtml and ix.efg.invhtml.BuildPayload) then
		local inv = ix.efg.invhtml.BuildPayload({stashID = panel.stashID})
		payload.grids, payload.stash, payload.stashMsg = inv.grids, inv.stash, inv.stashMsg

		local function mark(grid)
			for _, entry in ipairs(grid and grid.items or {}) do
				local item = ix.item.instances[entry.id]
				entry.sell = item and state.traderInv and sellEstimate(state, item) or false
			end
		end

		for _, grid in ipairs(payload.grids) do mark(grid) end
		mark(payload.stash)
	end

	return payload
end

function EFT.Signature(panel)
	local character = LocalPlayer():GetCharacter()
	if (!character) then return "" end

	local inv = ix.efg.invhtml and ix.efg.invhtml.Signature and ix.efg.invhtml.Signature(panel) or ""
	return inv .. "|" .. character:GetMoney() .. "|" .. tostring(panel.stateVersion or 0)
end

-- ─── Diálogo ─────────────────────────────────────────────────────────────────
local function pickRandom(list, fallback)
	if (!list or #list == 0) then return fallback end
	return list[math.random(#list)]
end

local function greetingFor(key, rep)
	for _, entry in ipairs(ix.traders.greetings and ix.traders.greetings[key] or {}) do
		if (rep >= entry.min) then return entry.text end
	end

	return "Hola. ¿En qué puedo ayudarte?"
end

-- mismo árbol que el diálogo antiguo; TraderDialogueOptions sigue funcionando
function EFT.BuildDialogue(state)
	local key = state.factionKey

	local pages = {
		root = {
			text = greetingFor(key, state.rep or 0),
			options = {
				{text = "Quiero ver lo que tienes.", action = "trade"},
				{text = "¿Tienes algún encargo para mí?", action = "missions"},
				{text = "¿Cómo van los negocios por aquí?", nextPage = "smalltalk"},
				{text = "¿Qué se cuenta por la zona?", nextPage = "news"},
				{text = "Cuéntame más sobre ti.", nextPage = "lore"},
				{text = "Hasta luego.", action = "close"},
			},
		},
		smalltalk = {
			text = pickRandom(ix.traders.smalltalk and ix.traders.smalltalk[key], "La zona sigue igual de jodida."),
			options = {{text = "¿Y qué más hay de nuevo?", nextPage = "news"}, {text = "Volver.", nextPage = "root"}},
		},
		news = {
			text = pickRandom(ix.traders.news, "Sin novedades que contar."),
			options = {{text = "Gracias por la información.", nextPage = "root"}, {text = "Hasta luego.", action = "close"}},
		},
		lore = {
			text = ix.traders.lore[key] or "No tengo nada que contar hoy.",
			options = {{text = "¿Y el negocio te va bien con todo eso?", nextPage = "smalltalk"}, {text = "Volver.", nextPage = "root"}},
		},
	}

	if (state.missionReady) then
		table.insert(pages.root.options, 1, {text = "Tengo el encargo completado: " .. state.missionName, action = "turnin"})
	end

	if (state.deliverReady) then
		table.insert(pages.root.options, 1, {text = "Tengo " .. state.deliverItemName .. " para la misión.", action = "deliverStep"})
	end

	if (LocalPlayer():IsAdmin() and ix.missions and ix.missions.OpenAdmin) then
		table.insert(pages.root.options, #pages.root.options, {text = "[ADMIN] Gestionar misiones", action = "missionAdmin"})
	end

	hook.Run("TraderDialogueOptions", pages, state.ent, key)

	return pages
end

-- ─── Panel ───────────────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgTrader)) then ix.gui.efgTrader:Remove() end
	ix.gui.efgTrader = self
	ix.efgui.RegisterEsc(self)

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:SetSizable(false)
	self:DockPadding(0, 0, 0, 0)
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.15)

	self.tab = "dialog"
	self.stateVersion = 0

	local html = self:Add("DHTML")
	html:Dock(FILL)
	html:SetAllowLua(false)
	self.html = html

	html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	html:AddFunction("efg", "close", function() self:Close() end)
	html:AddFunction("efg", "tab", function(tab) self:SetTab(tab) end)
	html:AddFunction("efg", "option", function(index) self:ChooseOption(tonumber(index)) end)
	html:AddFunction("efg", "typed", function() self.dialogTyped = true end)

	html:AddFunction("efg", "buy", function(index, qty)
		local slot = self.state.traderInv and self.state.traderInv[tonumber(index) or 0]
		qty = math.Clamp(math.floor(tonumber(qty) or 1), 1, 255)
		if (!slot or !IsValid(self.state.ent)) then return end

		net.Start("traders_Purchase")
			net.WriteEntity(self.state.ent)
			net.WriteString(slot.itemID)
			net.WriteUInt(qty, 8)
		net.SendToServer()
	end)

	html:AddFunction("efg", "sell", function(ids)
		if (!istable(ids) or !IsValid(self.state.ent)) then return end

		local list = {}
		for _, id in ipairs(ids) do
			id = tonumber(id)
			if (id and ix.item.instances[id] and #list < 100) then list[#list + 1] = id end
		end

		if (#list == 0) then return end

		net.Start("traders_SellItems")
			net.WriteEntity(self.state.ent)
			net.WriteUInt(#list, 8)
			for _, id in ipairs(list) do net.WriteUInt(id, 32) end
		net.SendToServer()
	end)

	html:AddFunction("efg", "inspect", function(id)
		local item = ix.item.instances[tonumber(id) or 0]
		if (item and ix.efg.inspect and ix.efg.inspect.Open) then ix.efg.inspect.Open(item) end
	end)

	html:AddFunction("efg", "admin", function()
		if (!LocalPlayer():IsAdmin() or !IsValid(self.state.ent)) then return end
		local ent = self.state.ent
		self:Close()

		net.Start("traders_DialogueAction")
			net.WriteEntity(ent)
			net.WriteString("admin")
		net.SendToServer()
	end)

	html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	html:SetHTML(ix.efgui.InjectCSS(PLUGIN.traderHTML))

	-- alijo para vender desde él (fuera de raid)
	local client = LocalPlayer()
	if (!(client.InRaid and client:InRaid())) then
		net.Start("ixEFGStashTab")
			net.WriteBool(true)
		net.SendToServer()
		self.stashRequested = true
	end
end

function PANEL:SetState(state)
	self.state = state
	self.stateVersion = (self.stateVersion or 0) + 1

	if (!self.pages or state.dialogReset) then
		self.pages = EFT.BuildDialogue(state)
		self:ShowPage("root", true)
	end

	self:Push()
end

function PANEL:SetStash(invID)
	self.stashID = invID
	self.stateVersion = (self.stateVersion or 0) + 1
end

function PANEL:SetTab(tab)
	if (tab != "dialog" and tab != "buy" and tab != "sell") then return end

	self.tab = tab

	-- primera vez en compra/venta: se pide el surtido
	if (tab != "dialog" and !self.state.traderInv) then
		self:RequestTrade()
	end

	self:Push()
end

function PANEL:RequestTrade()
	if (!IsValid(self.state.ent)) then return end

	net.Start("traders_DialogueAction")
		net.WriteEntity(self.state.ent)
		net.WriteString("trade")
	net.SendToServer()
end

function PANEL:ShowPage(key, silent)
	local page = self.pages and self.pages[key]
	if (!page) then return end

	self.pageKey = key
	self.dialogView = {text = page.text, options = {}, seq = (self.dialogView and self.dialogView.seq or 0) + 1}

	for i, option in ipairs(page.options) do
		self.dialogView.options[i] = option.text
	end

	if (!silent) then self:Push() end
end

function PANEL:ChooseOption(index)
	local page = self.pages and self.pages[self.pageKey]
	local option = page and page.options[index or 0]
	if (!option) then return end

	local ent = self.state.ent
	local action = option.action

	if (action == "trade") then
		self:SetTab("buy")
	elseif (action == "close") then
		self:Close()
	elseif (action == "missions") then
		self:Close()
		if (ix.missions and ix.missions.RequestList) then ix.missions.RequestList(ent) end
	elseif (action == "turnin" or action == "deliverStep") then
		self:Close()
		net.Start(action == "turnin" and "missions_TurnIn" or "missions_Deliver")
			net.WriteEntity(ent)
		net.SendToServer()
	elseif (action == "missionAdmin") then
		self:Close()
		if (ix.missions and ix.missions.OpenAdmin) then ix.missions.OpenAdmin(ent) end
	elseif (action and hook.Run("TraderDialogueAction", action, ent, function() self:Close() end) == true) then
		return
	elseif (option.nextPage) then
		self:ShowPage(option.nextPage)
	end
end

function PANEL:ShowMessage(ok, text)
	self.message = {ok = ok, text = text, seq = (self.message and self.message.seq or 0) + 1}
	self:Push()
end

function PANEL:Push()
	if (!self.ready or !self.state or !LocalPlayer():GetCharacter()) then return end

	self.sig = EFT.Signature(self)
	self.html:RunJavascript("render(" .. util.TableToJSON(EFT.BuildPayload(self)) .. ")")
end

function PANEL:Think()
	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.25

	local client = LocalPlayer()
	if (!client:GetCharacter() or !self.state or !IsValid(self.state.ent)) then self:Close() return end
	-- abierta junto al NPC: se cierra al alejarse (desde el lobby no hay distancia)
	if (!self.remote and client:GetPos():Distance(self.state.ent:GetPos()) > 250) then self:Close() return end

	if (EFT.Signature(self) != self.sig) then self:Push() end
end

function PANEL:Paint(w, h)
	ix.util.DrawBlur(self, 4)
	surface.SetDrawColor(0, 0, 0, 210)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:Close()
	if (self.closing) then return end
	self.closing = true

	CloseDermaMenus()
	self:AlphaTo(0, 0.1, 0, function() if (IsValid(self)) then self:Remove() end end)
end

function PANEL:OnRemove()
	if (ix.gui.efgTrader == self) then ix.gui.efgTrader = nil end

	if (self.stashRequested and !IsValid(ix.gui.efgInvHTML)) then
		net.Start("ixEFGStashTab")
			net.WriteBool(false)
		net.SendToServer()
	end
end

vgui.Register("efgxTrader", PANEL, "DFrame")

-- ─── Nets: se envuelven los receptores de cl_plugin ──────────────────────────
local function useEFT()
	return ix.config.Get("tradersEFTUI", true) and PLUGIN.traderHTML != nil
end

local function wrap(name, handler)
	local previous = net.Receivers[string.lower(name)]

	net.Receive(name, function(length)
		if (!useEFT()) then
			if (previous) then previous(length) end
			return
		end

		handler(length)
	end)
end

wrap("traders_OpenDialogue", function()
	local state = {
		ent = net.ReadEntity(),
		factionKey = net.ReadString(),
		traderName = net.ReadString(),
		rep = net.ReadUInt(10),
		money = net.ReadUInt(32),
		missionReady = net.ReadBool(),
		missionName = net.ReadString(),
		deliverReady = net.ReadBool(),
		deliverItemName = net.ReadString(),
		dialogReset = true
	}

	if (!IsValid(state.ent)) then return end

	ix.traders._state = state

	local panel = vgui.Create("efgxTrader")
	-- desde el menú de comerciantes el NPC puede estar lejos: no se cierra por distancia
	panel.remote = LocalPlayer():GetPos():Distance(state.ent:GetPos()) > 200
	panel:SetState(state)
	surface.PlaySound("efg/ui/click.wav")
end)

wrap("traders_OpenTrade", function()
	local ent = net.ReadEntity()
	local count = net.ReadUInt(8)
	local stock = {}

	for i = 1, count do
		stock[i] = {
			itemID = net.ReadString(),
			qty = net.ReadUInt(8),
			maxQty = net.ReadUInt(8),
			price = net.ReadUInt(32),
			buyPrice = net.ReadUInt(32),
			minRep = net.ReadUInt(10),
			playerStock = net.ReadBool(),
			usedCount = net.ReadUInt(8),
			condition = net.ReadString(),
			condPct = net.ReadUInt(7),
		}
	end

	local money = net.ReadUInt(32)
	local rep = net.ReadUInt(10)
	net.ReadUInt(8)

	local whitelist = {}
	for _ = 1, net.ReadUInt(8) do whitelist[net.ReadString()] = true end

	if (!IsValid(ent)) then return end

	local panel = ix.gui.efgTrader
	local state = IsValid(panel) and panel.state and panel.state.ent == ent and panel.state or {
		ent = ent,
		factionKey = ent:GetNetVar("factionKey", "prapor"),
		traderName = ent:GetNetVar("traderName", "Comerciante"),
		dialogReset = true
	}

	state.traderInv, state.money, state.rep, state.buyWhitelist = stock, money, rep, whitelist
	ix.traders._state = state

	-- abierto desde el lobby (sin pasar por el diálogo): directo a comprar
	if (!IsValid(panel)) then
		panel = vgui.Create("efgxTrader")
		panel.tab = "buy"
		panel.remote = LocalPlayer():GetPos():Distance(ent:GetPos()) > 200
	elseif (panel.tab == "dialog") then
		panel.tab = "buy"
	end

	panel:SetState(state)
	state.dialogReset = nil
end)

local function onResult(withRep)
	local ok = net.ReadBool()
	local text = net.ReadString()
	local rep = withRep and net.ReadUInt(10) or 0

	if (rep > 0) then text = text .. ("  +%d de reputación."):format(rep) end

	local panel = ix.gui.efgTrader

	if (IsValid(panel)) then
		panel:ShowMessage(ok, text)
		surface.PlaySound(ok and "efg/ui/click.wav" or "buttons/button10.wav")
		if (ok) then panel:RequestTrade() end
	else
		chat.AddText(ok and Color(143, 179, 74) or Color(184, 50, 42), "[Comerciante] ", color_white, text)
	end
end

wrap("traders_PurchaseResult", function() onResult(false) end)
wrap("traders_SellResult", function() onResult(true) end)
