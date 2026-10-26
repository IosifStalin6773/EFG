-- Componentes Derma de Pizarra: ranura de equipo, pestañas y filas extra del tooltip.

local UI = ix.efgui

-- ─── Ranura de equipo ────────────────────────────────────────────────────────
-- Icono + nombre del objeto. Setup(label, item, accepts, onDrop):
--   accepts(item) -> bool  decide si un arrastre es válido (verde/rojo)
--   onDrop(item)           se llama al soltar un objeto encima
local SLOT = {}

function SLOT:Init()
	self.label = ""
	self:SetTall(UI.Scale(40))
	self:SetMouseInputEnabled(true)
end

function SLOT:Setup(label, item, accepts, onDrop)
	self.label, self.item, self.accepts, self.onDrop = label or "", item, accepts, onDrop

	self:Receiver("ixInventoryItem", function(_, panels, dropped)
		local it = IsValid(panels[1]) and panels[1].itemTable

		if (dropped and it and self.onDrop) then
			self.onDrop(it)
		end
	end)
end

function SLOT:GetState()
	if (dragndrop.IsDragging() and self:IsHovered()) then
		local dragged = dragndrop.GetDroppable("ixInventoryItem")
		local it = dragged and IsValid(dragged[1]) and dragged[1].itemTable

		return (it and self.accepts and self.accepts(it)) and "valid" or "invalid"
	end

	return self:IsHovered() and "hover" or "normal"
end

function SLOT:Paint(w, h)
	local iconW = math.floor(h * 1.4)
	UI.DrawCell(0, 0, iconW, h, self:GetState(), self.item != nil)

	if (self.item) then
		if (ix.efg and ix.efg.icons) then
			ix.efg.icons.Draw(self.item, 2, 2, iconW - 4, h - 4, true)
		end

		UI.DrawRarity(0, 0, iconW, h, self.item.rarity)
		draw.SimpleText(self.item.GetName and self.item:GetName() or self.item.name, "efgx.Body",
			iconW + UI.Scale(8), h / 2, UI.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(self.label, "efgx.Small", iconW + UI.Scale(8), h / 2, UI.color.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("efgxSlot", SLOT, "DPanel")

-- ─── Pestañas ────────────────────────────────────────────────────────────────
-- AddTab(nombre, build) donde build(panel) rellena el contenido de la pestaña.
local TABS = {}

function TABS:Init()
	self.bar = self:Add("Panel")
	self.bar:Dock(TOP)
	self.bar:SetTall(UI.Scale(34))
	self.bar.Paint = function(_, w, h)
		surface.SetDrawColor(UI.color.line)
		surface.DrawRect(0, h - 1, w, 1)
	end

	self.body = self:Add("Panel")
	self.body:Dock(FILL)
	self.tabs = {}
end

function TABS:AddTab(name, build)
	local btn = self.bar:Add("DButton")
	btn:Dock(LEFT)
	btn:SetText(string.upper(name))
	btn:SetFont("efgx.Header")
	btn:SizeToContentsX(UI.Scale(28))
	btn.Paint = function(this, w, h)
		local active = self.active == this
		this:SetTextColor(active and UI.color.text or UI.color.text2)

		if (active) then
			surface.SetDrawColor(UI.color.accent)
			surface.DrawRect(0, h - 2, w, 2)
		end
	end
	btn.DoClick = function() self:Select(btn) end
	btn.build = build

	self.tabs[#self.tabs + 1] = btn

	if (#self.tabs == 1) then
		self:Select(btn)
	end

	return btn
end

function TABS:Select(btn)
	if (self.active == btn) then return end

	self.active = btn
	self.body:Clear()
	btn.build(self.body)
end

vgui.Register("efgxTabs", TABS, "Panel")

-- ─── Tooltip ─────────────────────────────────────────────────────────────────
-- Helix construye ixTooltip; aquí solo se añaden la rareza y la durabilidad.
hook.Add("PopulateItemTooltip", "efgx.Tooltip", function(tooltip, item)
	local rarity = UI.rarity[item.rarity or ""]

	if (rarity) then
		local row = tooltip:AddRowAfter("name", "efgx_rarity")
		row:SetText(string.upper(rarity.name))
		row:SetFont("efgx.Label")
		row:SetTextColor(rarity.color)
		row:SizeToContents()
	end

	local frac

	if (item.isEFGArmor and item.GetEFGDurability) then
		frac = item:GetEFGDurability() / math.max(1, item:GetEFGMaxDurability())
	end

	if (frac) then
		local row = tooltip:AddRow("efgx_durability")
		row:SetText("")
		row:SetTall(UI.Scale(18))
		row.PaintOver = function(_, w, h)
			UI.DrawMeter(UI.Scale(8), math.floor(h / 2 - UI.Scale(3)), w - UI.Scale(16), UI.Scale(6), frac)
		end
	end
end)
