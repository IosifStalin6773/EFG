-- Inventario de EFT en un DFrame con DHTML. Lua manda el estado con
-- render(json) y la página llama a efg.move, efg.equip, efg.unequip,
-- efg.wequip, efg.wunequip, efg.menu, efg.inspect, efg.close y efg.click.

local PLUGIN = PLUGIN
local INV = ix.efg.invhtml

local ASSET = "asset://garrysmod/materials/"

local EQUIP_KINDS = {"headset", "helmet", "facecover", "eyewear", "armband", "armor", "rig", "backpack", "secure"}
local CONTAINERS = {rig = true, backpack = true, secure = true}

local function itemName(item)
	return (item.GetName and item:GetName()) or item.name or "?"
end

local function iconOf(item)
	local path = ix.efg.icons and ix.efg.icons.Resolve(item)
	return path and (ASSET .. path) or nil
end

local function catOf(item)
	if (item.isWeapon or item.isARC9) then return "weapon" end
	if (item.isMagazine) then return "mag" end
	if (item.isAmmo) then return "ammo" end
	if (item.isEFGMod) then return "mod" end
	if (ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)) then return "gear" end

	local cat = string.lower(item.category or "")
	if (cat:find("medic")) then return "med" end
	if (cat:find("consum") or cat:find("comida") or cat:find("provis")) then return "food" end
	if (cat:find("llave") or cat:find("key")) then return "key" end

	return "other"
end

local function countOf(item)
	if (item.isMagazine and item.GetRounds) then
		return item:GetRounds() .. "/" .. (item.capacity or 0)
	end

	if (item.isAmmo) then
		return tostring(item:GetData("rounds", item.ammoAmount or 0))
	end

	local qty = item:GetData("quantity")
	return (qty and qty > 1) and tostring(qty) or nil
end

local function shortName(name)
	local short = name:gsub("%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return utf8.len(short) and utf8.len(short) > 14 and (short:sub(1, utf8.offset(short, 13) - 1) .. "…") or short
end

local function describe(item)
	local text = item.GetDescription and item:GetDescription() or item.description or ""
	text = tostring(text):gsub("<[^>]+>", "")

	return #text > 260 and (text:sub(1, 257) .. "...") or text
end

-- en el cliente Helix no rellena gridX/gridY: la posición es la celda de
-- inv.slots donde está guardado el objeto (solo la esquina superior izquierda)
local function posOf(item)
	local inv = ix.item.inventories[item.invID or 0]
	if (!inv) then return nil end

	for x, column in pairs(inv.slots) do
		for y, other in pairs(column) do
			if (other == item or (istable(other) and other.id == item.id)) then
				return x, y
			end
		end
	end
end

-- ¿cabe el objeto en (x, y)? comprobando solapes con los rectángulos de los demás
local function fits(inv, item, x, y)
	local w, h = inv:GetSize()
	if (x < 1 or y < 1 or x + item.width - 1 > w or y + item.height - 1 > h) then return false end
	if (ix.efg.rig and !ix.efg.rig.Fits(inv, x, y, item.width, item.height)) then return false end

	for ox, column in pairs(inv.slots) do
		for oy, other in pairs(column) do
			if (istable(other) and other.id != item.id and x < ox + (other.width or 1) and x + item.width > ox
				and y < oy + (other.height or 1) and y + item.height > oy) then
				return false
			end
		end
	end

	return true
end

INV.HOTBAR_SLOTS = 5

-- la misma regla que comprueba el servidor (ix_invkey)
function INV.CanHotbar(item)
	return ix.hotbar != nil and ix.hotbar.CanAssign(item)
end

local function serialize(item)
	local px, py = posOf(item)

	local name = itemName(item)

	return {
		id = item:GetID(),
		uid = item.uniqueID,
		name = name,
		short = shortName(name),
		icon = iconOf(item),
		x = px or 1,
		y = py or 1,
		w = item.width or 1,
		h = item.height or 1,
		weight = tonumber(item.weight) or 0,
		price = tonumber(item.price) or 0,
		cat = catOf(item),
		count = countOf(item),
		desc = describe(item),
		kind = ix.GetEquipSlotKind and ix.GetEquipSlotKind(item) or nil,
		wcat = item.isWeapon and (item.weaponCategory or "primary") or nil,
		hk = INV.CanHotbar(item) or nil,
		eq = item:GetData("equip") and true or nil
	}
end

INV.Serialize = serialize

local function innerInv(item)
	local id = item and item:GetData("id")
	local inv = id and ix.item.inventories[id]

	return (inv and inv.slots) and inv or nil
end

local function gridOf(key, title, inv, holder)
	local w, h = inv:GetSize()
	local items = {}

	for _, item in pairs(inv:GetItems(true)) do
		if (item.invID == inv:GetID()) then
			items[#items + 1] = serialize(item)
		end
	end

	return {
		key = key, title = title, inv = inv:GetID(), w = w, h = h, items = items,
		holder = holder and serialize(holder) or nil
	}
end

function INV.GetEquipped(character)
	local equip = {}
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

	for _, item in pairs(eqInv and eqInv:GetItems(true) or {}) do
		local kind = ix.GetEquipSlotKind(item)
		if (kind and !equip[kind]) then equip[kind] = item end
	end

	return equip, eqInv
end

function INV.GetWeapons(character)
	local out = {}

	for _, item in pairs(character:GetInventory():GetItems(true)) do
		if (item.isWeapon and item:GetData("equip")) then
			local slot = item:GetData("efgSlot") or item.weaponCategory or "primary"
			if (!out[slot]) then out[slot] = item end
		end
	end

	return out
end

function INV.BuildPayload(panel)
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local inv = character:GetInventory()
	local equip, eqInv = INV.GetEquipped(character)
	local weaponsEq = INV.GetWeapons(character)

	local payload = {
		name = character:GetName(),
		money = character:GetMoney(),
		weight = {math.Round(character:GetData("carry", 0), 1), ix.config.Get("maxWeight", 30)},
		raid = client.InRaid and client:InRaid() or false,
		equip = {}, weapons = {}, grids = {},
		equipInv = eqInv and eqInv:GetID() or 0,
		mainInv = inv:GetID()
	}

	-- salud total desde efg_health (efgHP: {{hp, flags}, ...})
	local hp, hpMax = client:Health(), client:GetMaxHealth()
	local parts = client:GetNetVar("efgHP")

	if (istable(parts) and ix.efg.health) then
		hp = 0
		for _, part in ipairs(parts) do hp = hp + (tonumber(part[1]) or 0) end
		hpMax = ix.efg.health.total
	end

	payload.hp = {math.Round(hp), hpMax}

	for _, kind in ipairs(EQUIP_KINDS) do
		payload.equip[kind] = equip[kind] and serialize(equip[kind]) or false
	end

	payload.hotbar = {}
	local hotbar = ix.hotbar and ix.hotbar.Get(character) or {}

	for i = 1, INV.HOTBAR_SLOTS do
		local item = hotbar[i] and ix.item.instances[hotbar[i]]
		payload.hotbar[i] = item and serialize(item) or false
	end

	for _, slot in ipairs({"primary", "primary2", "secondary", "melee"}) do
		payload.weapons[slot] = weaponsEq[slot] and serialize(weaponsEq[slot]) or false
	end

	-- columna táctica: chaleco táctico, bolsillos, mochila y contenedor seguro
	local rigInv = innerInv(equip.rig)
	local bagInv = innerInv(equip.backpack)
	local secInv = innerInv(equip.secure)

	payload.grids[#payload.grids + 1] = rigInv and gridOf("rig", "Chaleco táctico", rigInv, equip.rig)
		or {key = "rig", title = "Chaleco táctico", empty = true}
	payload.grids[#payload.grids + 1] = gridOf("pockets", "Bolsillos", inv)
	payload.grids[#payload.grids + 1] = bagInv and gridOf("backpack", "Mochila", bagInv, equip.backpack)
		or {key = "backpack", title = "Mochila", empty = true}
	payload.grids[#payload.grids + 1] = secInv and gridOf("secure", "Contenedor seguro", secInv, equip.secure)
		or {key = "secure", title = "Contenedor seguro", empty = true}

	local stash = panel.stashID and ix.item.inventories[panel.stashID]

	if (stash) then
		payload.stash = gridOf("stash", "Alijo", stash)
	else
		payload.stashMsg = payload.raid and "El alijo no está disponible durante la raid."
			or (client:GetNetVar("efgStashOK", true) == false and "El alijo solo está disponible en el escondite.")
			or "Cargando el alijo…"
	end

	return payload
end

-- firma barata del estado para saber cuándo volver a mandar render()
function INV.Signature(panel)
	local client = LocalPlayer()
	local character = client:GetCharacter()
	if (!character) then return "" end

	local parts = {character:GetMoney(), character:GetData("carry", 0), panel.stashID or 0, client:Health(),
		ix.hotbar and util.TableToJSON(ix.hotbar.Get(character)) or ""}
	local function addInv(inv)
		if (!inv) then return end
		parts[#parts + 1] = "#" .. inv:GetID()

		for _, item in pairs(inv:GetItems(true)) do
			local px, py = posOf(item)
			parts[#parts + 1] = ("%d:%d:%d:%d:%dx%d:%s:%s:%s"):format(item:GetID(), item.invID or 0, px or 0, py or 0, item.width or 1, item.height or 1,
				item:GetData("equip") and 1 or 0, countOf(item) or "", item:GetData("id") or "")
		end
	end

	addInv(character:GetInventory())
	addInv(ix.GetEquipInventory and ix.GetEquipInventory(character))
	addInv(panel.stashID and ix.item.inventories[panel.stashID])

	local hp = client:GetNetVar("efgHP")
	if (istable(hp)) then parts[#parts + 1] = util.TableToJSON(hp) end

	return table.concat(parts, "|")
end

-- ─── Movimientos (mismos nets que ix.inventory) ──────────────────────────────
function INV.Move(item, invID, x, y)
	local old = ix.item.inventories[item.invID]
	local new = ix.item.inventories[invID]
	if (!old or !new) then return false end

	local oldX, oldY = posOf(item)
	if (!oldX or !fits(new, item, x, y)) then return false end

	if (old != new) then
		if (hook.Run("CanTransferItem", item, old, new) == false) then return false end
		if (item.CanTransfer and item:CanTransfer(old, new) == false) then return false end
	end

	net.Start("ixInventoryMove")
		net.WriteUInt(oldX, 6)
		net.WriteUInt(oldY, 6)
		net.WriteUInt(x, 6)
		net.WriteUInt(y, 6)
		net.WriteUInt(old:GetID(), 32)
		net.WriteUInt(new:GetID(), 32)
	net.SendToServer()

	-- en el mismo inventario el servidor no contesta al que mueve: se aplica aquí
	if (old == new) then
		if (old.slots[oldX]) then old.slots[oldX][oldY] = nil end
		new.slots[x] = new.slots[x] or {}
		new.slots[x][y] = item
		item.gridX, item.gridY = x, y
	end

	return true
end

local function action(item, key, data)
	net.Start("ixInventoryAction")
		net.WriteString(key)
		net.WriteUInt(item:GetID(), 32)
		net.WriteUInt(item.invID or 0, 32)
		net.WriteTable(data or {})
	net.SendToServer()
end

local function canRun(item, fn)
	if (!fn.OnCanRun) then return true end

	item.player = LocalPlayer()
	local ok, result = pcall(fn.OnCanRun, item)
	item.player = nil

	return ok and result != false
end

local function runFunction(item, key, data)
	local fn = item.functions and item.functions[key]
	if (!fn) then return end

	if (fn.OnClick) then
		item.player = LocalPlayer()
		local ok, result = pcall(fn.OnClick, item, data)
		item.player = nil

		if (!ok) then ErrorNoHalt("[EFG] " .. tostring(result) .. "\n") return end
		if (result == false) then return end
	end

	action(item, key, data)
end

INV.RunFunction = runFunction
INV.CanRun = canRun

function INV.OpenMenu(item)
	local menu = DermaMenu()

	if (ix.efg.inspect and ix.efg.inspect.Open) then
		menu:AddOption("Inspeccionar", function() ix.efg.inspect.Open(item) end):SetImage("icon16/magnifier.png")
		menu:AddSpacer()
	end

	for key, fn in SortedPairs(item.functions or {}) do
		if (key != "combine" and canRun(item, fn)) then
			local name = fn.name or key
			name = isstring(name) and L(name) or tostring(name)

			if (fn.isMulti) then
				item.player = LocalPlayer()
				local ok, options = pcall(fn.multiOptions or function() return {} end, item, LocalPlayer())
				item.player = nil

				local sub, parent = menu:AddSubMenu(name)
				if (fn.icon) then parent:SetImage(fn.icon) end

				for _, option in ipairs(ok and istable(options) and options or {}) do
					sub:AddOption(option.name or "?", function() runFunction(item, key, option.data) end)
				end
			else
				local option = menu:AddOption(name, function() runFunction(item, key) end)
				if (fn.icon) then option:SetImage(fn.icon) end
			end
		end
	end

	menu:Open()
end

-- ─── Página (DHTML) ─────────────────────────────────────────────────────────
-- Se usa dentro de la pestaña INVENTARIO del TAB (ix_invkey) o suelta en un
-- DFrame (efg_inventario). page.OnRequestClose cierra lo que la contenga.
local PAGE = {}

function PAGE:Init()
	ix.gui.efgInvHTML = self

	self.html = self:Add("DHTML")
	self.html:Dock(FILL)
	self.html:SetAllowLua(false)

	local function byID(id)
		return ix.item.instances[tonumber(id) or 0]
	end

	local html = self.html

	html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	html:AddFunction("efg", "close", function() self:RequestClose() end)

	html:AddFunction("efg", "move", function(id, invID, x, y)
		local item = byID(id)
		invID, x, y = tonumber(invID), tonumber(x), tonumber(y)
		if (!item or !invID or !x or !y) then return end

		local ok = INV.Move(item, invID, x, y)
		surface.PlaySound(ok and "efg/ui/click.wav" or "buttons/button10.wav")
		self.sig = nil
	end)

	html:AddFunction("efg", "equip", function(id)
		local item = byID(id)
		if (!item) then return end

		net.Start("ixEquipToSlot")
			net.WriteUInt(item:GetID(), 32)
		net.SendToServer()
	end)

	-- de una ranura de equipo a una rejilla: la ropa pasa por ixUnequipSlot
	-- (quita el atuendo); el resto se mueve tal cual a la celda
	html:AddFunction("efg", "unequip", function(id, invID, x, y)
		local item = byID(id)
		if (!item) then return end

		if (item.outfitCategory or !tonumber(invID) or !INV.Move(item, tonumber(invID), tonumber(x) or 1, tonumber(y) or 1)) then
			net.Start("ixUnequipSlot")
				net.WriteUInt(item:GetID(), 32)
			net.SendToServer()
		end
	end)

	html:AddFunction("efg", "wequip", function(id)
		local item = byID(id)
		if (item and !item:GetData("equip")) then runFunction(item, "Equip") end
	end)

	html:AddFunction("efg", "wunequip", function(id, invID, x, y)
		local item = byID(id)
		if (!item) then return end

		if (item:GetData("equip")) then runFunction(item, "EquipUn") end

		invID, x, y = tonumber(invID), tonumber(x), tonumber(y)
		if (invID and x and y) then
			timer.Simple(0.15, function()
				if (item and ix.item.instances[item:GetID()]) then INV.Move(item, invID, x, y) end
			end)
		end
	end)

	-- acceso rápido: el servidor (ix_invkey, ixHotbarUpdate) valida y guarda
	html:AddFunction("efg", "hotbar", function(slot, id)
		slot, id = tonumber(slot), tonumber(id) or 0
		if (!slot or slot < 1 or slot > INV.HOTBAR_SLOTS) then return end

		local item = id != 0 and ix.item.instances[id]
		if (id != 0 and (!item or !INV.CanHotbar(item))) then return end

		net.Start("ixHotbarUpdate")
			net.WriteUInt(slot, 8)
			net.WriteUInt(id, 32)
		net.SendToServer()

		surface.PlaySound("efg/ui/click.wav")
	end)

	html:AddFunction("efg", "menu", function(id)
		local item = byID(id)
		if (item) then INV.OpenMenu(item) end
	end)

	html:AddFunction("efg", "inspect", function(id)
		local item = byID(id)
		if (!item) then return end

		-- doble clic en una medicina: se usa donde más falta haga (efg_health)
		if ((item.category == "Medicamentos" or item.category == "Estimulantes") and ix.efg.health and ix.efg.health.QuickUse
			and ix.efg.health.QuickUse(item)) then
			surface.PlaySound("efg/ui/click.wav")
			return
		end

		if (ix.efg.inspect and ix.efg.inspect.Open) then ix.efg.inspect.Open(item) end
	end)

	html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	html:SetHTML(ix.efgui.InjectCSS(PLUGIN.invHTML))

	-- alijo (strongbox): se pide al abrir y se suelta al cerrar
	local client = LocalPlayer()
	if (!(client.InRaid and client:InRaid())) then
		net.Start("ixEFGStashTab")
			net.WriteBool(true)
		net.SendToServer()
		self.stashRequested = true
	end
end

function PAGE:SetStash(invID)
	self.stashID = invID
	self.sig = nil
end

function PAGE:SetEmbedded(embedded)
	self.embedded = embedded
	if (self.ready) then self:Push() end
end

function PAGE:Push()
	if (!self.ready or !LocalPlayer():GetCharacter()) then return end

	local payload = INV.BuildPayload(self)
	payload.embedded = self.embedded or false

	self.sig = INV.Signature(self)
	self.html:RunJavascript("render(" .. util.TableToJSON(payload) .. ")")
end

function PAGE:Think()
	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.2

	if (!self:IsVisible() or !LocalPlayer():GetCharacter()) then return end
	if (INV.Signature(self) != self.sig) then self:Push() end
end

function PAGE:RequestClose()
	CloseDermaMenus()
	if (self.OnRequestClose) then self:OnRequestClose() end
end

function PAGE:OnRemove()
	if (ix.gui.efgInvHTML == self) then ix.gui.efgInvHTML = nil end

	-- la pantalla de comerciante también usa el alijo: no se suelta mientras siga abierta
	if (self.stashRequested and !IsValid(ix.gui.efgTrader)) then
		net.Start("ixEFGStashTab")
			net.WriteBool(false)
		net.SendToServer()
	end
end

vgui.Register("efgxInventoryPage", PAGE, "EditablePanel")

-- ─── Ventana suelta ──────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgInvFrame)) then ix.gui.efgInvFrame:Remove() end
	ix.gui.efgInvFrame = self
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
	self:AlphaTo(255, 0.1)

	self.page = self:Add("efgxInventoryPage")
	self.page:Dock(FILL)
	self.page.OnRequestClose = function() self:Close() end
end

function PANEL:Think()
	if (!LocalPlayer():GetCharacter() or IsValid(ix.gui.menu)) then self:Close() end
end

function PANEL:Paint(w, h)
	ix.util.DrawBlur(self, 3)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:Close()
	if (self.closing) then return end
	self.closing = true

	CloseDermaMenus()
	self:AlphaTo(0, 0.08, 0, function() if (IsValid(self)) then self:Remove() end end)
end

function PANEL:OnRemove()
	if (ix.gui.efgInvFrame == self) then ix.gui.efgInvFrame = nil end
end

vgui.Register("efgxInventoryHTML", PANEL, "DFrame")

function INV.Open()
	return vgui.Create("efgxInventoryHTML")
end

function INV.Toggle()
	if (IsValid(ix.gui.efgInvFrame)) then
		ix.gui.efgInvFrame:Close()
	else
		INV.Open()
	end
end

concommand.Add("efg_inventario", function()
	if (LocalPlayer():GetCharacter()) then INV.Toggle() end
end)

-- el servidor quita el alijo al salir del escondite (strongbox)
net.Receive("ixEFGStashTabLost", function()
	if (IsValid(ix.gui.efgInvHTML)) then ix.gui.efgInvHTML:SetStash(nil) end
	if (IsValid(ix.gui.efgTrader)) then ix.gui.efgTrader:SetStash(nil) end
end)

-- ix_invkey también escucha ixEFGStashTabReady: se envuelve su receptor
function PLUGIN:InitializedPlugins()
	local previous = net.Receivers["ixefgstashtabready"]

	net.Receive("ixEFGStashTabReady", function(length)
		local panel = ix.gui.efgInvHTML

		local trader = ix.gui.efgTrader

		if (IsValid(panel) or IsValid(trader)) then
			local id = net.ReadUInt(32)
			if (IsValid(panel)) then panel:SetStash(id) end
			if (IsValid(trader)) then trader:SetStash(id) end
		elseif (previous) then
			previous(length)
		end
	end)
end
