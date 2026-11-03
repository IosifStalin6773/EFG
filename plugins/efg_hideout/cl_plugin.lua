local PLUGIN = PLUGIN
local hideout = ix.efg.hideout

local colorText   = Color(199, 197, 179)
local colorQuiet  = Color(130, 128, 116)
local colorGood   = Color(106, 150, 64)
local colorBad    = Color(196, 60, 51)

local function buildPanel(state)
	if (IsValid(ix.gui.efgHideout)) then
		ix.gui.efgHideout:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 40, 760), math.min(ScrH() - 40, 640))
	frame:Center()
	frame:SetTitle("Escondite")
	frame:MakePopup()
	frame:DockPadding(8, ix.efgui.Scale(30) + 6, 8, 8)
	ix.efgui.StyleFrame(frame, "ESCONDITE")
	ix.gui.efgHideout = frame

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)

	for _, entry in ipairs(state) do
		local module = hideout.byID[entry.id]

		if (module) then
			local row = scroll:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(0, 0, 0, 6)
			row:DockPadding(10, 8, 10, 8)
			row.Paint = function(_, w, h)
				ix.efgui.DrawPanel(0, 0, w, h, 255)
				surface.SetDrawColor(ix.efgui.color.accent)
				surface.DrawRect(0, 0, 2, h)
			end

			local title = row:Add("DLabel")
			title:Dock(TOP)
			title:SetFont("efgui.Header")
			title:SetTextColor(colorText)
			title:SetText(("%s  ·  nivel %d/%d"):format(module.name, entry.level, entry.maxLevel))
			title:SizeToContents()

			local description = row:Add("DLabel")
			description:Dock(TOP)
			description:SetFont("efgui.Small")
			description:SetTextColor(colorQuiet)
			description:SetText(module.description)
			description:SetWrap(true)
			description:SetAutoStretchVertical(true)

			local height = 60

			if (entry.level < entry.maxLevel) then
				local header = row:Add("DLabel")
				header:Dock(TOP)
				header:DockMargin(0, 6, 0, 0)
				header:SetFont("efgui.Small")
				header:SetTextColor(colorText)
				header:SetText(("Para el nivel %d:"):format(entry.level + 1))
				header:SizeToContents()

				for _, requirement in ipairs(entry.requirements) do
					local line = row:Add("DLabel")
					line:Dock(TOP)
					line:SetFont("efgui.Small")
					line:SetTextColor(requirement.met and colorGood or colorBad)
					line:SetText("  • " .. requirement.text)
					line:SizeToContents()
					height = height + line:GetTall()
				end

				local button = row:Add("DButton")
				button:Dock(TOP)
				button:DockMargin(0, 6, 0, 0)
				button:SetTall(26)
				button:SetText(entry.canUpgrade and "Mejorar" or "Faltan requisitos")
				button:SetEnabled(entry.canUpgrade)
				ix.efgui.StyleButton(button)
				button.DoClick = function()
					net.Start("ixEFGHideoutUpgrade")
						net.WriteString(entry.id)
					net.SendToServer()
				end

				height = height + 60
			else
				local maxed = row:Add("DLabel")
				maxed:Dock(TOP)
				maxed:DockMargin(0, 6, 0, 0)
				maxed:SetFont("efgui.Small")
				maxed:SetTextColor(colorGood)
				maxed:SetText("Nivel máximo")
				maxed:SizeToContents()
			end

			-- el alto de la fila se ajusta a lo que contiene
			row:SetTall(height + 20)
			row.PerformLayout = function(me)
				local bottom = 0

				for _, child in ipairs(me:GetChildren()) do
					local _, y = child:GetPos()
					bottom = math.max(bottom, y + child:GetTall())
				end

				if (bottom > 0 and me:GetTall() != bottom + 8) then
					me:SetTall(bottom + 8)
				end
			end
		end
	end
end

net.Receive("ixEFGHideoutState", function()
	local state = net.ReadTable()
	hideout.lastState = state

	-- con el mapa abierto se actualiza; /Escondite abre el TAB en ESCONDITE
	if (IsValid(ix.gui.efgHideoutMap)) then
		ix.gui.efgHideoutMap:SetState(state)
	elseif (vgui.GetControlTable("ixEFGInventory") and !IsValid(ix.gui.efgInventory)) then
		ix.gui.invKeyStartTab = "hideout"
		ix.gui.efgInventory = vgui.Create("ixEFGInventory")
	else
		buildPanel(state)
	end
end)

-- ─── Mapa del escondite (pestaña ESCONDITE del TAB) ─────────────────────────
-- Corte del búnker en tres plantas con un punto por módulo. Clic en un punto
-- para ver sus requisitos y mejorarlo. Posiciones en fracción del mapa.
hideout.mapFloors = {
	{name = "Superficie y techo", y0 = 0.04, y1 = 0.34},
	{name = "Planta principal", y0 = 0.36, y1 = 0.66},
	{name = "Sótano", y0 = 0.68, y1 = 0.98}
}

hideout.mapPoints = {
	security = {0.07, 0.19}, illumination = {0.20, 0.19}, heating = {0.33, 0.19}, vents = {0.46, 0.19},
	air_filter = {0.59, 0.19}, solar = {0.72, 0.19}, water_collector = {0.85, 0.19},
	generator = {0.07, 0.51}, workbench = {0.20, 0.51}, medstation = {0.33, 0.51}, lavatory = {0.46, 0.51},
	nutrition = {0.59, 0.51}, booze = {0.72, 0.51}, bitcoin = {0.85, 0.51},
	stash = {0.07, 0.83}, rest = {0.20, 0.83}, intelligence = {0.33, 0.83}, scav_case = {0.46, 0.83},
	shooting_range = {0.59, 0.83}, library = {0.72, 0.83}, gym = {0.85, 0.83},
	weapon_rack = {0.95, 0.51}, hall_of_fame = {0.95, 0.83}
}

local MAP = {}

function MAP:Init()
	ix.gui.efgHideoutMap = self
	self.state = hideout.lastState or {}
	self.selected = "generator"

	local s = ix.efgui.Scale
	self.side = self:Add("DPanel")
	self.side.Paint = function(_, w, h) ix.efgui.DrawPanel(0, 0, w, h, 240) end
	self.side:DockPadding(s(14), s(12), s(14), s(12))

	self:RebuildSide()

	net.Start("ixEFGHideoutRequest")
	net.SendToServer()
end

function MAP:OnRemove()
	if (ix.gui.efgHideoutMap == self) then ix.gui.efgHideoutMap = nil end
end

function MAP:SetState(state)
	self.state = state
	self:RebuildSide()
end

function MAP:Entry(id)
	for _, entry in ipairs(self.state) do
		if (entry.id == id) then return entry end
	end
end

function MAP:PerformLayout(w, h)
	local sideW = math.Round(w * 0.3)
	self.side:SetPos(w - sideW, 0)
	self.side:SetSize(sideW, h)
	self.mapW = w - sideW - ix.efgui.Scale(10)
end

-- rectángulo de cada punto en el mapa (los módulos sin posición van al final del sótano)
function MAP:Nodes()
	local s = ix.efgui.Scale
	local w, h = self.mapW or self:GetWide(), self:GetTall()
	local nw, nh = math.min(s(118), w * 0.12), s(54)
	local nodes, extra = {}, 0

	for _, module in ipairs(hideout.modules) do
		local pos = hideout.mapPoints[module.id]
		if (!pos) then
			extra = extra + 1
			pos = {0.07 + 0.13 * ((extra - 1) % 7), 0.93}
		end
		nodes[#nodes + 1] = {id = module.id, module = module, x = math.Round(pos[1] * w - nw / 2), y = math.Round(pos[2] * h - nh / 2), w = nw, h = nh}
	end

	return nodes
end

function MAP:NodeAt(mx, my)
	for _, node in ipairs(self:Nodes()) do
		if (mx >= node.x and mx <= node.x + node.w and my >= node.y and my <= node.y + node.h) then
			return node
		end
	end
end

function MAP:OnMousePressed(code)
	if (code != MOUSE_LEFT) then return end

	local node = self:NodeAt(self:CursorPos())
	if (node) then
		self.selected = node.id
		surface.PlaySound("ui/buttonclickrelease.wav")
		self:RebuildSide()
	end
end

function MAP:Think()
	local node = self:NodeAt(self:CursorPos())
	self.hovered = node and node.id or nil
	self:SetCursor(node and "hand" or "arrow")
end

function MAP:Paint(w, h)
	local UI = ix.efgui
	local c = UI.color
	local s = UI.Scale
	local mw = self.mapW or w

	surface.SetDrawColor(c.bg0.r, c.bg0.g, c.bg0.b, 230)
	surface.DrawRect(0, 0, mw, h)

	for _, floor in ipairs(hideout.mapFloors) do
		local y0, y1 = math.Round(floor.y0 * h), math.Round(floor.y1 * h)
		surface.SetDrawColor(c.bg1)
		surface.DrawRect(s(4), y0, mw - s(8), y1 - y0)
		surface.SetDrawColor(c.line)
		surface.DrawOutlinedRect(s(4), y0, mw - s(8), y1 - y0)

		-- trama de hormigón muy suave
		surface.SetDrawColor(255, 255, 255, 4)
		for x = s(4), mw - s(8), s(24) do
			surface.DrawLine(x, y0, x + s(12), y1)
		end

		draw.SimpleText(string.upper(floor.name), "efgx.Label", s(12), y0 + s(6), c.textDim)
	end

	local nodes = self:Nodes()
	local byID = {}
	for _, node in ipairs(nodes) do byID[node.id] = node end

	-- líneas a los módulos que pide el siguiente nivel del seleccionado
	local selected = hideout.byID[self.selected]
	local selEntry = self:Entry(self.selected)
	local selNode = byID[self.selected]
	local nextLevel = selected and selected.levels[(selEntry and selEntry.level or 0) + 1]

	if (nextLevel and selNode) then
		for otherID, level in pairs(nextLevel.modules or {}) do
			local other, otherEntry = byID[otherID], self:Entry(otherID)
			if (other) then
				local met = otherEntry and otherEntry.level >= level
				surface.SetDrawColor(met and c.green or c.red)
				surface.DrawLine(selNode.x + selNode.w / 2, selNode.y + selNode.h / 2, other.x + other.w / 2, other.y + other.h / 2)
			end
		end
	end

	for _, node in ipairs(nodes) do
		local entry = self:Entry(node.id)
		local level = entry and entry.level or 0
		local maxLevel = entry and entry.maxLevel or #node.module.levels
		local isSel, isHover = node.id == self.selected, node.id == self.hovered

		surface.SetDrawColor(level > 0 and c.bg3 or c.cell)
		surface.DrawRect(node.x, node.y, node.w, node.h)

		local border = (level >= maxLevel and c.green) or (entry and entry.canUpgrade and c.accent) or (isHover and c.lineHi) or c.line
		surface.SetDrawColor(border)
		surface.DrawOutlinedRect(node.x, node.y, node.w, node.h)
		if (isSel) then
			surface.SetDrawColor(c.accent)
			surface.DrawOutlinedRect(node.x - 2, node.y - 2, node.w + 4, node.h + 4, 2)
		end

		local name = node.module.name
		local cut = utf8.offset(name, 17)
		if (cut and cut <= #name) then name = string.sub(name, 1, cut - 1) .. "." end
		draw.SimpleText(string.upper(name), "efgx.Label", node.x + s(6), node.y + s(5), level > 0 and c.text or c.text2)

		-- un segmento por nivel
		local segW = math.floor((node.w - s(12) - (maxLevel - 1) * s(3)) / math.max(maxLevel, 1))
		for i = 1, maxLevel do
			surface.SetDrawColor(i <= level and c.green or c.line)
			surface.DrawRect(node.x + s(6) + (i - 1) * (segW + s(3)), node.y + node.h - s(12), segW, s(5))
		end

		draw.SimpleText(level .. "/" .. maxLevel, "efgx.Num", node.x + node.w - s(6), node.y + s(22), c.text2, TEXT_ALIGN_RIGHT)
	end
end

function MAP:RebuildSide()
	local UI = ix.efgui
	local c = UI.color
	local s = UI.Scale
	local side = self.side

	side:Clear()

	local module = hideout.byID[self.selected]
	if (!module) then return end

	local entry = self:Entry(self.selected) or {level = 0, maxLevel = #module.levels, requirements = {}}

	local function label(text, font, color, margin)
		local l = side:Add("DLabel")
		l:Dock(TOP)
		l:DockMargin(0, margin or 0, 0, 0)
		l:SetFont(font)
		l:SetTextColor(color)
		l:SetText(text)
		l:SetWrap(true)
		l:SetAutoStretchVertical(true)
		return l
	end

	label(string.upper(module.name), "efgx.Title", c.text)
	label(("Nivel %d de %d"):format(entry.level, entry.maxLevel), "efgx.Num", entry.level >= entry.maxLevel and c.green or c.text2, s(4))
	label(module.description or "", "efgx.Body", c.text2, s(10))

	if (entry.level >= entry.maxLevel) then
		label("Nivel máximo", "efgx.Header", c.green, s(16))
		return
	end

	label(("Para el nivel %d"):format(entry.level + 1), "efgx.Header", c.text, s(16))

	if (#(entry.requirements or {}) == 0) then
		label(#self.state == 0 and "Cargando…" or "Sin requisitos.", "efgx.Small", c.textDim, s(4))
	end

	for _, requirement in ipairs(entry.requirements or {}) do
		label("•  " .. requirement.text, "efgx.Body", requirement.met and c.green or c.red, s(4))
	end

	local button = side:Add("DButton")
	button:Dock(BOTTOM)
	button:SetTall(s(44))
	button:SetText(entry.canUpgrade and "Mejorar" or "Faltan requisitos")
	button:SetEnabled(entry.canUpgrade == true)
	UI.StyleButton(button, nil, entry.canUpgrade and "primary" or nil)
	button.DoClick = function()
		net.Start("ixEFGHideoutUpgrade")
			net.WriteString(module.id)
		net.SendToServer()
	end
end

vgui.Register("efgxHideoutMap", MAP, "EditablePanel")
