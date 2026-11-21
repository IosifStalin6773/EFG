local PLUGIN = PLUGIN
local INV = ix.efg.invgrid
local H = INV.H
local ASSET, CONTAINERS, CURRENCIES, EQUIP_KINDS = H.ASSET, H.CONTAINERS, H.CURRENCIES, H.EQUIP_KINDS
local itemName, iconOf, catOf, countOf, shortName, describe, posOf, fits, serialize, innerInv, gridOf, lootWin, lootItem, weaponSlot, sortedItems, action, canRun, runFunction = H.itemName, H.iconOf, H.catOf, H.countOf, H.shortName, H.describe, H.posOf, H.fits, H.serialize, H.innerInv, H.gridOf, H.lootWin, H.lootItem, H.weaponSlot, H.sortedItems, H.action, H.canRun, H.runFunction

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

	-- saqueo: el servidor (efg_loot_ui) valida, mueve y devuelve las secciones
	local function lootMove(item, toLoot, target, x, y)
		net.Start("efgLootWinMove")
			net.WriteUInt(item:GetID(), 32)
			net.WriteBool(toLoot)
			net.WriteUInt(tonumber(target) or 0, 32)
			net.WriteUInt(math.Clamp(tonumber(x) or 0, 0, 255), 8)
			net.WriteUInt(math.Clamp(tonumber(y) or 0, 0, 255), 8)
		net.SendToServer()

		surface.PlaySound("efg/ui/click.wav")
		self.sig = nil
	end

	html:AddFunction("efg", "loottake", function(id, invID, x, y)
		local item = byID(id)
		if (item and lootWin()) then lootMove(item, false, invID, x, y) end
	end)

	html:AddFunction("efg", "lootput", function(id, section, x, y)
		local item = byID(id)
		if (item and lootWin()) then lootMove(item, true, section, x, y) end
	end)

	html:AddFunction("efg", "lootsearch", function(index)
		index = tonumber(index)
		if (!index or !lootWin()) then return end

		net.Start("efgLootWinSearch")
			net.WriteUInt(index, 8)
		net.SendToServer()
	end)

	html:AddFunction("efg", "examine", function(id)
		local item = byID(id)
		if (!item) then return end

		net.Start("efgLootWinExamine")
			net.WriteUInt(item:GetID(), 32)
		net.SendToServer()
	end)

	html:AddFunction("efg", "lootmenu", function(id)
		local item = byID(id)
		local WIN = lootWin()
		if (!item or !WIN) then return end

		local menu = DermaMenu()

		if (WIN.IsUnknown and WIN.IsUnknown(item)) then
			menu:AddOption(L("efgLootWinExamine"), function()
				net.Start("efgLootWinExamine")
					net.WriteUInt(item:GetID(), 32)
				net.SendToServer()
			end):SetImage("icon16/magnifier.png")
		else
			if (ix.efg.inspect and ix.efg.inspect.Open) then
				menu:AddOption("Inspeccionar", function() ix.efg.inspect.Open(item) end):SetImage("icon16/magnifier.png")
			end
		end

		menu:AddOption(L("efgLootWinTake"), function() lootMove(item, false, 0) end):SetImage("icon16/arrow_left.png")
		menu:Open()
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

	-- cerrar la pantalla termina el saqueo
	local WIN = ix.efg.lootwin
	if (WIN and WIN.active and WIN.active.page == self) then
		WIN.active = nil
		WIN.sections = {}

		net.Start("efgLootWinClose")
		net.SendToServer()
	end

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
