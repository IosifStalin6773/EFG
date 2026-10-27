-- ════════════════════════════════════════════════════════════════════════════
-- ALMACENAMIENTO (ixStorageView) — rediseño con la estética del inventario nuevo
-- Reutiliza el tema expuesto por ix_invkey (ixInvTheme): paleta, softPanel,
-- categorías, helpers de detalles y las fuentes globales ixInv.*.
-- Layout: COFRE (izq) | TU INVENTARIO + MOCHILA con categorías (centro) | DETALLES (der)
-- ════════════════════════════════════════════════════════════════════════════

local PLUGIN = PLUGIN
local S = SScale

-- el dinero del almacenamiento sigue deshabilitado igual que antes (los cofres
-- del schema no lo usan); se conservan los setters como no-ops por compatibilidad.

local PANEL = {}
DEFINE_BASECLASS("Panel")

AccessorFunc(PANEL, "storageID", "StorageID", FORCE_NUMBER)

local function makeGrid(parent, inv, iconSize)
	local panel = parent:Add("ixInventory")
	panel:SetDraggable(false); panel:SetSizable(false); panel:SetTitle(nil)
	panel.bNoBackgroundBlur = true; panel.childPanels = {}
	panel.Paint = nil; panel.PaintBackground = nil
	panel:SetIconSize(iconSize)
	panel:SetInventory(inv)
	return panel
end

function PANEL:Init()
	local T = ixInvTheme
	if (not T) then self:Remove() return end -- el tema lo expone ix_invkey
	self.T = T
	local C = T.C

	if (IsValid(ix.gui.openedStorage)) then ix.gui.openedStorage:Remove() end
	ix.gui.openedStorage = self

	local sw, sh = ScrW(), ScrH()
	self:SetSize(sw, sh); self:SetPos(0, 0)
	self:SetAlpha(0); self:AlphaTo(255, 0.2)

	self._selectedItem = nil
	self._lockedItem = nil
	self._activeCat = 1

	-- ── dimensiones (mismas proporciones que el TAB) ───────────────────
	local d = {}
	d.margin = S(7); d.topH = S(20); d.gap = S(4)
	d.contentY = d.topH + S(3); d.panelBottom = sh - S(5)
	d.LEFT_W = S(240); d.RIGHT_W = S(150)
	d.leftX = d.margin; d.rightX = sw - d.margin - d.RIGHT_W
	d.centerX = d.leftX + d.LEFT_W + d.gap; d.CENTER_W = d.rightX - d.gap - d.centerX
	d.panelH = d.panelBottom - d.contentY
	d.sw = sw; d.sh = sh
	self.dims = d

	-- ── botón cerrar ───────────────────────────────────────────────────
	self.closeBtn = self:Add("DButton"); self.closeBtn:SetText(""); self.closeBtn:SetSize(S(70), d.topH)
	self.closeBtn:SetPos(sw - S(74), 0)
	self.closeBtn.Paint = function(me, w, h)
		draw.SimpleText("CERRAR  X", "ixInv.Tab", w - S(8), h / 2,
			me:IsHovered() and C.accent or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	self.closeBtn.DoClick = function() self:Close() end

	self:BuildStoragePanel()
	self:BuildPlayerPanel()
	self:BuildDetailsPanel()

	self:MakePopup()
end

-- ── COFRE (izquierda) ────────────────────────────────────────────────────────
function PANEL:BuildStoragePanel()
	local d, T, C = self.dims, self.T, self.T.C

	local L = self:Add("DPanel")
	L:SetPos(d.leftX, d.contentY); L:SetSize(d.LEFT_W, d.panelH)
	L.Paint = function(me, w, h) T.softPanel(me, w, h) end
	self.storagePanelBox = L

	local hdrH = S(13)
	local hdr = L:Add("DPanel"); hdr:SetPos(0, 0); hdr:SetSize(d.LEFT_W, hdrH)
	hdr.Paint = function(_, w, h)
		draw.RoundedBoxEx(T.RAD, 0, 0, w, h, C.panelHdr, true, true, false, false)
		draw.SimpleText("ALMACENAMIENTO", "ixInv.Header", S(8), h / 2, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if (self._storageTitle and self._storageTitle != "") then
			draw.SimpleText(self._storageTitle:upper(), "ixInv.Small", w - S(8), h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	-- botón REORDENAR
	self.sortBtn = L:Add("DButton"); self.sortBtn:SetText(""); self.sortBtn:SetSize(S(70), S(12))
	self.sortBtn:SetPos(d.LEFT_W - S(78), d.panelH - S(16))
	self.sortBtn:SetVisible(false)
	self.sortBtn.Paint = function(me, w, h)
		draw.RoundedBox(S(3), 0, 0, w, h, me:IsHovered() and C.slotHover or C.slot)
		surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText("REORDENAR", "ixInv.Action", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	self.sortBtn.DoClick = function()
		if (not IsValid(self.storageInventory) or not self.storageInventory.invID) then return end
		surface.PlaySound("efg/ui/click.wav")
		net.Start("ixStorageSort"); net.WriteUInt(self.storageInventory.invID, 32); net.SendToServer()
	end

	-- área de la rejilla (con recorte para el scroll)
	self.storageGridY = hdrH + d.gap
	self.storageGridArea = {x = S(6), y = self.storageGridY, w = d.LEFT_W - S(12), h = d.panelH - self.storageGridY - S(20)}
end

-- ── TU INVENTARIO + MOCHILA (centro) ─────────────────────────────────────────
function PANEL:BuildPlayerPanel()
	local d, T, C = self.dims, self.T, self.T.C
	local char = LocalPlayer():GetCharacter()
	if (not char) then return end
	self._char = char

	local M = self:Add("DPanel")
	M:SetPos(d.centerX, d.contentY); M:SetSize(d.CENTER_W, d.panelH)
	M.Paint = function(me, w, h) T.softPanel(me, w, h) end
	self.playerPanelBox = M

	-- cabecera + barra de peso
	local hdrH = S(13)
	local hdr = M:Add("DPanel"); hdr:SetPos(0, 0); hdr:SetSize(d.CENTER_W, hdrH)
	hdr.Paint = function(_, w, h)
		draw.RoundedBoxEx(T.RAD, 0, 0, w, h, C.panelHdr, true, true, false, false)
		draw.SimpleText("INVENTARIO", "ixInv.Header", S(8), h / 2, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local maxW = char.GetMaxWeight and char:GetMaxWeight() or ix.config.Get("maxWeight", 30)
		local carry = char:GetData("carry", 0)
		local frac = math.Clamp(carry / math.max(maxW, 1), 0, 1)
		local txt = math.Round(carry, 1) .. " / " .. maxW .. " kg"
		surface.SetFont("ixInv.Stat"); local tw = surface.GetTextSize(txt)
		local barX = S(74); local barW = w - barX - tw - S(16); local barY = (h - S(4)) / 2
		draw.RoundedBox(S(2), barX, barY, barW, S(4), C.barBg)
		draw.RoundedBox(S(2), barX, barY, barW * frac, S(4), C.accent)
		draw.SimpleText(txt, "ixInv.Stat", w - S(8), h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- barra de categorías
	local catY = hdrH + d.gap; local catH = S(20)
	local catBar = M:Add("DPanel"); catBar:SetPos(0, catY); catBar:SetSize(d.CENTER_W, catH)
	catBar.Paint = function(_, w, h) surface.SetDrawColor(C.slotLine); surface.DrawRect(0, h - 1, w, 1) end
	local catW = d.CENTER_W / #T.CATEGORIES
	for i, cat in ipairs(T.CATEGORIES) do
		local b = catBar:Add("DButton"); b:SetText(""); b:SetPos((i - 1) * catW, 0); b:SetSize(catW, catH)
		b.Paint = function(me, w, h)
			local active = (self._activeCat == i)
			local col = active and C.accent or (me:IsHovered() and C.text or C.textDim)
			local isz = S(11); cat.icon((w - isz) / 2, (h - isz) / 2 - S(1), isz, col)
			if (active) then surface.SetDrawColor(C.accent); surface.DrawRect(0, h - S(2), w, S(2)) end
		end
		b.DoClick = function() self._activeCat = i; self:FilterByCategory(cat) end
	end
	local catLabel = M:Add("DLabel"); catLabel:SetPos(S(8), catY + catH + S(1)); catLabel:SetSize(d.CENTER_W - S(16), S(8))
	catLabel:SetFont("ixInv.Small"); catLabel:SetTextColor(C.textDim); catLabel:SetText(T.CATEGORIES[1].label)
	self._catLabel = catLabel

	self.playerGridY = catY + catH + S(10)
end

-- ── DETALLES (derecha) ───────────────────────────────────────────────────────
function PANEL:BuildDetailsPanel()
	local d, T, C = self.dims, self.T, self.T.C

	local R = self:Add("DPanel")
	R:SetPos(d.rightX, d.contentY); R:SetSize(d.RIGHT_W, d.panelH)
	R.Paint = function(me, w, h)
		T.softPanel(me, w, h)
		draw.RoundedBoxEx(T.RAD, 0, 0, w, S(13), C.panelHdr, true, true, false, false)
		draw.SimpleText("DETALLES", "ixInv.Header", w / 2, S(6), C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local dc = R:Add("DPanel"); dc:SetPos(S(8), S(17)); dc:SetSize(d.RIGHT_W - S(16), d.panelH - S(21)); dc.Paint = nil
	self._detailContent = dc
	self:BuildEmptyDetails()
end

function PANEL:BuildEmptyDetails()
	local c = self._detailContent
	if (not IsValid(c)) then return end; c:Clear()
	local C = self.T.C
	local lbl = c:Add("DLabel"); lbl:SetPos(0, c:GetTall() / 3); lbl:SetSize(c:GetWide(), S(24))
	lbl:SetFont("ixInv.Sub"); lbl:SetTextColor(C.textDim); lbl:SetContentAlignment(5)
	lbl:SetText("Pasa el ratón por un objeto\npara ver sus detalles.\n\nArrastra para mover entre\nel cofre y tu inventario."); lbl:SetWrap(true)
end

function PANEL:SetSelectedItem(item)
	if (not item or self._selectedItem == item) then return end
	self._selectedItem = item
	local T, C = self.T, self.T.C
	local c = self._detailContent
	if (not IsValid(c)) then return end; c:Clear()
	local W = c:GetWide()

	local nm = c:Add("DLabel"); nm:Dock(TOP)
	nm:SetFont("ixInv.ItemName"); nm:SetTextColor(C.white)
	nm:SetWrap(true); nm:SetAutoStretchVertical(true)
	nm:SetText((item.name or "Desconocido"):upper())

	local subTxt
	if (item.isWeapon or item.isCW) then
		subTxt = "ARMA · " .. (T.WCAT_ES[item.weaponCategory] or "ARMA")
	else
		subTxt = T.localizeCategory(item.category)
	end
	local sub = c:Add("DLabel"); sub:Dock(TOP); sub:DockMargin(0, 0, 0, S(4)); sub:SetTall(S(10))
	sub:SetFont("ixInv.Sub"); sub:SetTextColor(C.textDim); sub:SetText(subTxt)

	-- modelo
	local boxH = S(50)
	local mb = c:Add("DPanel"); mb:Dock(TOP); mb:DockMargin(0, 0, 0, S(5)); mb:SetTall(boxH)
	mb.Paint = function(_, w, h) draw.RoundedBox(S(3), 0, 0, w, h, Color(10, 9, 7, 150)) end
	local aw, ah = item.width or 1, item.height or 1
	local ic = T.createItemIcon(mb, item)
	ic.PaintOver = nil
	mb.PerformLayout = function(_, bw, bh)
		local scale = math.min(bw / aw, bh / ah)
		local iw, ih = aw * scale, ah * scale
		ic:SetSize(iw, ih); ic:SetPos((bw - iw) / 2, (bh - ih) / 2)
	end

	-- stats
	local function statRow(label, valTxt, frac, col)
		local row = c:Add("DPanel"); row:Dock(TOP); row:SetTall(S(12))
		row.Paint = function(_, w, h)
			draw.SimpleText(label, "ixInv.Stat", 0, S(1), C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(valTxt, "ixInv.StatVal", w, S(1), C.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			surface.SetDrawColor(C.barBg); surface.DrawRect(0, S(10), w, S(2))
			if (frac) then surface.SetDrawColor(col or C.accent); surface.DrawRect(0, S(10), w * math.Clamp(frac, 0, 1), S(2)) end
		end
	end
	if (item.isWeapon or item.isCW) then
		for _, st in ipairs(T.getWeaponStats(item)) do statRow(st[1], tostring(st[2]), st[3] and (st[2] / st[3]) or nil) end
	elseif (istable(item.stats)) then
		for _, st in ipairs(item.stats) do local mx = st[3] or st[2]; statRow(st[1], tostring(st[2]), mx and (st[2] / mx) or nil) end
	end
	statRow("PESO", math.Round(item.weight or 0, 2) .. " kg", nil)
	local dur = T.getDurability(item)
	if (dur) then
		local col = dur >= 50 and C.green or (dur >= 25 and C.energia or C.red)
		statRow("DURABILIDAD", dur .. "/100", dur / 100, col)
	end

	-- descripción
	local desc = item.description or ""
	if (item.GetDescription) then
		local ok, res = pcall(item.GetDescription, item)
		if (ok and res) then desc = res end
	end
	desc = T.cleanDesc(desc)
	local scr = c:Add("DScrollPanel"); scr:Dock(FILL); scr:DockMargin(0, S(4), 0, 0); scr:GetVBar():SetWide(S(2))
	local dl = scr:Add("DLabel"); dl:Dock(TOP); dl:SetWide(W - S(4))
	dl:SetFont("ixInv.Desc"); dl:SetTextColor(C.text); dl:SetWrap(true); dl:SetAutoStretchVertical(true); dl:SetText(desc)
end

-- ── filtros de categoría (solo afectan al inventario del jugador y la mochila) ─
function PANEL:FilterByCategory(cat)
	local T = self.T
	cat = cat or T.CATEGORIES[self._activeCat] or T.CATEGORIES[1]
	if (IsValid(self._catLabel)) then self._catLabel:SetText(cat.label) end
	if (dragndrop.IsDragging()) then return end
	local isAll = (cat.filter == nil and not cat.weaponOnly)
	T.compactPanel(self._invPanel, cat, isAll)
	T.compactPanel(self._bagPanel, cat, isAll)

	-- el cofre no tiene filtro de categoría, pero sí hay que recolocar sus iconos
	-- cuando el servidor reordena/mueve ítems (si no, se quedan en su posición vieja).
	if (IsValid(self.storageInventory) and self.storageInventory.RebuildItems) then
		self.storageInventory:RebuildItems()
	end
end

-- Firma barata del contenido de una rejilla (id + posición de cada ítem). Sirve
-- para detectar en el Think cuándo cambió algo y recolocar en el acto, en vez de
-- reaplicar el layout en un tick throttleado (que dejaba los iconos "desordenados"
-- durante ~0.3s tras reordenar o mover ítems entre el cofre y el inventario).
function PANEL:GridSignature(grid)
	if (not IsValid(grid) or not grid.invID) then return 0 end
	local inv = ix.item.inventories[grid.invID]
	if (not inv or not inv.slots) then return 0 end

	local h = 0
	for x, col in pairs(inv.slots) do
		for y, itm in pairs(col) do
			if (itm and itm.id) then
				h = (h * 131 + itm.id * 17 + x * 7 + y) % 2147483647
			end
		end
	end
	return h
end

-- ════════════════════════════════════════════════════════════════════════════
-- Setters que invoca Helix (sh_storage.lua) tras crear el panel
-- ════════════════════════════════════════════════════════════════════════════

function PANEL:SetStorageTitle(title)
	self._storageTitle = title or ""
end

function PANEL:SetStorageInventory(inventory)
	local d, a = self.dims, self.storageGridArea
	if (not a or not inventory or not inventory.slots) then return end

	local invW, invH = inventory:GetSize(); invW = invW or 6; invH = invH or 6
	local iconSize = math.min(math.floor(a.w / invW), S(34))
	iconSize = math.Clamp(iconSize, S(13), S(34))

	-- evitar que el cofre se auto-registre como childPanel del inv del jugador:
	-- SetInventory lo haría porque ix.gui.inv1 (ya creado por SetLocalInventory)
	-- tiene childPanels. El cofre se recolecta aparte (ix.gui.openedStorage.storageInventory).
	local savedChild = IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels or nil
	if (IsValid(ix.gui.inv1)) then ix.gui.inv1.childPanels = nil end
	local grid = makeGrid(self.storagePanelBox, inventory, iconSize)
	if (IsValid(ix.gui.inv1)) then ix.gui.inv1.childPanels = savedChild end

	local realW = invW * iconSize + 8
	local padX = math.floor((d.LEFT_W - realW) / 2)
	grid:SetPos(padX, a.y)

	-- scroll vertical si el cofre es más alto que el área visible
	local realH = invH * iconSize + 10
	if (realH > a.h) then
		grid.scrollMax = realH - a.h
		grid:SetTall(a.h)
	else
		grid.scrollMax = 0
	end
	grid.scrollY = 0

	self.storageInventory = grid
	ix.gui["inv" .. inventory:GetID()] = grid
	if (IsValid(self.sortBtn)) then self.sortBtn:SetVisible(true) end
end

function PANEL:SetLocalInventory(inventory)
	local d, T = self.dims, self.T
	if (not self.playerPanelBox or not inventory or not inventory.slots) then return end
	local char = self._char or LocalPlayer():GetCharacter()
	if (not char) then return end

	local M = self.playerPanelBox
	local gridY = self.playerGridY
	local gridAreaH = d.panelH - gridY - S(8)
	local gridAreaW = d.CENTER_W - S(16)

	local invW, invH = inventory:GetSize(); invW = invW or 6; invH = invH or 6

	-- mochila equipada (su contenido) para mover ítems mochila <-> cofre
	local bagItem, bagInv, bagW, bagH
	if (ix.plugin.Get("metrobags") and char.GetPrimaryBag) then
		local pb = char:GetPrimaryBag()
		if (pb) then
			local bid = pb:GetData("id"); local bi = bid and ix.item.inventories[bid]
			if (bi and bi.slots) then bagItem = pb; bagInv = bi; bagW, bagH = bi:GetSize() end
		end
	end
	local extraRows = (bagInv and bagH > 0) and bagH or 0
	local bagHdrSp = bagInv and S(9) or 0
	local widestCols = math.max(invW, (bagInv and bagW) or 0)

	local iconSize = math.min(
		math.floor((gridAreaH - bagHdrSp) / (invH + extraRows)),
		math.floor(gridAreaW / widestCols))
	iconSize = math.Clamp(iconSize, S(13), S(34))

	local realInvW = invW * iconSize + 8; local realInvH = invH * iconSize + 10
	local padX = math.floor((d.CENTER_W - realInvW) / 2)

	local invPanel = makeGrid(M, inventory, iconSize)
	invPanel:SetPos(padX, gridY)
	ix.gui.inv1 = invPanel; self._invPanel = invPanel
	invPanel.childPanels = invPanel.childPanels or {}

	if (bagInv) then
		local bagName = (bagItem.GetName and bagItem:GetName()) or bagItem.name or "Mochila"
		local byOff = gridY + realInvH + S(2)
		local bHdr = M:Add("DPanel"); bHdr:SetPos(padX, byOff); bHdr:SetSize(realInvW, S(8))
		bHdr.Paint = function(_, w, h) draw.SimpleText("MOCHILA — " .. bagName:upper(), "ixInv.Small", 0, h / 2, T.C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end

		local saved = invPanel.childPanels; invPanel.childPanels = nil
		local bagRealW = bagW * iconSize + 8; local bagPadX = math.floor((d.CENTER_W - bagRealW) / 2)
		local bagPanel = makeGrid(M, bagInv, iconSize)
		bagPanel:SetPos(bagPadX, byOff + S(9))
		invPanel.childPanels = saved
		invPanel.childPanels[#invPanel.childPanels + 1] = bagPanel
		ix.gui["inv" .. bagInv:GetID()] = bagPanel; self._bagPanel = bagPanel
	end
end

-- dinero deshabilitado (paridad con el comportamiento anterior)
function PANEL:SetStorageMoney(money) end
function PANEL:SetLocalMoney(money) end

-- ── hover/selección de ítems para el panel de detalles ───────────────────────
function PANEL:Think()
	local hovered = vgui.GetHoveredPanel()
	local hoveredItem = (IsValid(hovered) and hovered.itemTable) or nil
	local mDown = input.IsMouseDown(MOUSE_LEFT)
	if (mDown and not self._mDown) then
		self._mDown = true
		if (hoveredItem) then self._lockedItem = hoveredItem; self:SetSelectedItem(hoveredItem) end
	elseif (not mDown) then
		self._mDown = false
	end
	if (not self._lockedItem and hoveredItem) then self:SetSelectedItem(hoveredItem) end

	-- Recolocar los iconos en cuanto cambie el contenido de cualquier rejilla
	-- (reordenar, mover ítems entre cofre/inventario/mochila) o al soltar un arrastre.
	-- Antes se reaplicaba en un Think throttleado a 0.3s, por eso los iconos se veían
	-- "desordenados" hasta ~0.3s después de la acción. FilterByCategory ya se ignora
	-- durante el arrastre, así que no interfiere con el drag&drop.
	local dragging = dragndrop.IsDragging()
	local a = self:GridSignature(self._invPanel)
	local b = self:GridSignature(self._bagPanel)
	local c = self:GridSignature(self.storageInventory)

	if (a != self._sigA or b != self._sigB or c != self._sigC or dragging != self._wasDragging) then
		self._sigA, self._sigB, self._sigC = a, b, c
		self._wasDragging = dragging
		self:FilterByCategory()
	end
end

function PANEL:Paint(w, h)
	local T, C = self.T, self.T.C
	ix.util.DrawBlur(self, 6)
	surface.SetDrawColor(color_white); surface.SetMaterial(T.textures.menu3); surface.DrawTexturedRect(0, 0, w, h)
	surface.SetDrawColor(14, 11, 9, 200); surface.DrawRect(0, 0, w, h)

	local topH = S(20)
	surface.SetDrawColor(22, 17, 13, 200); surface.DrawRect(0, 0, w, topH)
	surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 120); surface.DrawRect(0, topH - S(1), w, S(1))
	draw.SimpleText("ALMACENAMIENTO", "ixInv.Title", S(10), topH / 2, C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:Close()
	net.Start("ixStorageClose"); net.SendToServer()
	self:Remove()
end

function PANEL:Remove()
	if (self._removing) then return end; self._removing = true
	self:AlphaTo(0, 0.15, 0, function() if (IsValid(self)) then BaseClass.Remove(self) end end)
end

function PANEL:OnRemove()
	if (ix.gui.openedStorage == self) then ix.gui.openedStorage = nil end
	-- evitar referencias colgantes a las rejillas (hijas de self, ya destruidas)
	if (ix.gui.inv1 == self._invPanel) then ix.gui.inv1 = nil end
	CloseDermaMenus()
end

vgui.Register("ixStorageView", PANEL, "Panel")
