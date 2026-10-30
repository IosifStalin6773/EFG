local PLUGIN = PLUGIN

-- Menú radial adaptado de Multiverse | Radial Menus, sin su framework.
--   ix.efg.radial.Open(options)
--   option = {name =, description =, icon = Material o nil, color =, click = function, sub = {options}}
-- Si una opción tiene sub, al elegirla se abre otro menú con esas opciones.
-- Mantén Z para el menú de acciones rápidas: suelta sobre una opción o haz clic.

ix.efg = ix.efg or {}
ix.efg.radial = ix.efg.radial or {}
local radial = ix.efg.radial

local key = CreateClientConVar("efg_radial_tecla", tostring(KEY_Z), true, false, "Tecla del menú radial")

local matLMB = Material("efg/radial/lmb.png", "mips smooth")
local matRMB = Material("efg/radial/rmb.png", "mips smooth")

local colText = Color(227, 228, 218)
local colBack = Color(10, 12, 14)
local colAccent = Color(232, 131, 58)

local fontScale

local function createFonts(scale)
	fontScale = ScrH()
	surface.CreateFont("efgRadial.Option", {font = "MBender", extended = true, size = math.Round(22 * scale), weight = 700, antialias = true})
	surface.CreateFont("efgRadial.Title", {font = "MBender", extended = true, size = math.Round(32 * scale), weight = 700, antialias = true})
	surface.CreateFont("efgRadial.Desc", {font = "MBender", extended = true, size = math.Round(22 * scale), weight = 500, antialias = true})
	surface.CreateFont("efgRadial.Mouse", {font = "MBender", extended = true, size = math.Round(20 * scale), weight = 600, antialias = true})
end

local function circle(x, y, r)
	local points = {}
	for i = 0, 360, 2 do
		points[#points + 1] = {x = x + math.cos(math.rad(i)) * r, y = y + math.sin(math.rad(i)) * r}
	end
	surface.DrawPoly(points)
end

-- arco de grosor "thickness" entre dos ángulos (en grados, 0 = derecha, antihorario)
local function arc(cx, cy, radius, thickness, a0, a1)
	local step = a0 > a1 and -2 or 2
	local inner, outer = {}, {}
	local r = radius - thickness

	for deg = a0, a1, step do
		local rad = math.rad(deg)
		inner[#inner + 1] = {x = cx + math.cos(rad) * r, y = cy - math.sin(rad) * r}
		outer[#outer + 1] = {x = cx + math.cos(rad) * radius, y = cy - math.sin(rad) * radius}
	end

	for i = 1, #inner - 1 do
		-- surface.DrawPoly solo dibuja polígonos en sentido horario
		local quad = {inner[i], inner[i + 1], outer[i + 1], outer[i]}
		if (step < 0) then quad = {outer[i], outer[i + 1], inner[i + 1], inner[i]} end
		surface.DrawPoly(quad)
	end
end

function radial.Open(options, holdKey)
	if (#options == 0) then return end
	if (IsValid(radial.active)) then radial.active:Remove() end

	local scale = ScrH() / 900
	if (fontScale != ScrH()) then createFonts(scale) end

	local outerR = 325 * scale
	local thick = outerR * 0.4
	local size = 360 / #options
	local cx, cy = ScrW() / 2, ScrH() / 2

	local menu = vgui.Create("DButton")
	menu:SetText("")
	menu:SetSize(ScrW(), ScrH())
	menu:MakePopup()
	menu:SetKeyboardInputEnabled(false)
	menu:SetCursor("hand")
	menu.selected = nil -- hasta que el ratón sale del centro
	menu.cursorColor = colAccent
	menu.holdKey = holdKey
	input.SetCursorPos(cx, cy)
	surface.PlaySound("efg/ui/hover.wav")

	function menu:Think()
		local mx, my = gui.MouseX() - cx, gui.MouseY() - cy

		if (mx * mx + my * my > (outerR - thick) ^ 2 * 0.15) then
			local ang = 360 - (math.deg(math.atan2(mx, my)) + 180)
			local index = math.floor(math.abs(ang + size / 2) / size)
			if (index >= #options) then index = 0 end

			if (self.selected != index + 1) then
				self.selected = index + 1
				surface.PlaySound("efg/ui/hover.wav")
			end
		end

		-- con la tecla soltada se elige lo que esté señalado
		if (self.holdKey and !input.IsKeyDown(self.holdKey)) then
			self.holdKey = nil
			self:Choose()
		end
	end

	function menu:Choose()
		local option = self.selected and options[self.selected]
		self:Remove()
		if (!option) then return end

		surface.PlaySound("efg/ui/click.wav")

		if (option.sub) then
			if (#option.sub > 0) then radial.Open(option.sub) end
		elseif (option.click) then
			option.click()
		end
	end

	function menu:Paint(w, h)
		local mx, my = gui.MouseX() - cx, gui.MouseY() - cy
		local cursorAng = 360 - (math.deg(math.atan2(mx, my)) + 180)
		local option = self.selected and options[self.selected]
		local selAng = ((self.selected or 1) - 1) * size

		self.cursorColor = LerpVector(FrameTime() * 5, self.cursorColor:ToVector(), (option and option.color or colAccent):ToVector()):ToColor()

		draw.NoTexture()
		surface.SetDrawColor(colBack.r, colBack.g, colBack.b, 100)
		circle(cx, cy, outerR)

		if (option) then
			surface.SetDrawColor(option.color or colAccent)
			arc(cx, cy, outerR + 4, 4, 90 - selAng - size / 2, 90 - selAng + size / 2)
			surface.SetDrawColor(colBack.r, colBack.g, colBack.b, 160)
			arc(cx, cy, outerR, thick, 90 - selAng - size / 2, 90 - selAng + size / 2)
		end

		-- hueco central
		surface.SetDrawColor(colBack.r, colBack.g, colBack.b, 140)
		circle(cx, cy, outerR - thick)

		for i, opt in ipairs(options) do
			local rad = math.rad((i - 1) * size)
			local r = outerR - thick / 2
			local x, y = cx + math.sin(rad) * r, cy - math.cos(rad) * r
			local selected = i == self.selected

			if (opt.icon and !opt.icon:IsError()) then
				local is = 56 * scale * (selected and 1.2 or 1)
				surface.SetDrawColor(colText)
				surface.SetMaterial(opt.icon)
				surface.DrawTexturedRect(x - is / 2, y - is / 2, is, is)
			else
				draw.SimpleText(opt.name, "efgRadial.Option", x, y, selected and (opt.color or colAccent) or colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		-- centro: nombre, descripción y ratón
		if (!option) then
			draw.SimpleText("Elige una opción", "efgRadial.Title", cx, cy, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return true
		end

		draw.NoTexture()
		surface.SetDrawColor(self.cursorColor)
		arc(cx, cy, outerR - thick + 12, 6, -cursorAng + 90 - size / 2, -cursorAng + 90 + size / 2)

		local oy = cy - 35 * scale
		draw.SimpleText(option.name, "efgRadial.Title", cx, oy - 15 * scale, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if (option.description) then
			draw.SimpleText(option.description, "efgRadial.Desc", cx, oy + 15 * scale, Color(170, 170, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local ms = 32 * scale
		surface.SetDrawColor(colText)
		surface.SetMaterial(matLMB)
		surface.DrawTexturedRect(cx - 50 * scale - ms / 2, oy + 50 * scale, ms, ms)
		draw.SimpleText("Elegir", "efgRadial.Mouse", cx - 50 * scale, oy + 50 * scale + ms + 10 * scale, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetMaterial(matRMB)
		surface.DrawTexturedRect(cx + 50 * scale - ms / 2, oy + 50 * scale, ms, ms)
		draw.SimpleText("Cancelar", "efgRadial.Mouse", cx + 50 * scale, oy + 50 * scale + ms + 10 * scale, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return true
	end

	menu.DoClick = function(this) this:Choose() end
	menu.DoRightClick = function(this) this:Remove() end

	radial.active = menu
	return menu
end

-- ─── Acciones rápidas ────────────────────────────────────────────────────────
local function openTab(id)
	if (IsValid(ix.gui.metroInventory)) then
		ix.gui.metroInventory:SwitchTab(id)
		return
	end

	ix.gui.invKeyStartTab = id
	ix.gui.metroInventory = vgui.Create("ixMetroInventory")
end

local function medOptions(character)
	local out = {}
	local seen = {}
	local inventories = {character:GetInventory()}
	local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(character)
	if (equipInv) then inventories[#inventories + 1] = equipInv end

	for i = 1, #inventories do
		for _, item in pairs(inventories[i]:GetItems(true)) do
			local sub = item:GetData("id") and ix.item.inventories[item:GetData("id")]
			if (sub and sub != inventories[i] and #inventories < 12) then inventories[#inventories + 1] = sub end
		end
	end

	for _, inventory in ipairs(inventories) do
		for _, item in pairs(inventory:GetItems(true)) do
			if (!seen[item.uniqueID] and item.category == "Medicamentos" and item.functions and item.functions.Use) then
				seen[item.uniqueID] = true
				out[#out + 1] = {
					name = item:GetName(),
					description = "Usar donde más falta haga",
					color = Color(150, 215, 90),
					click = function()
						net.Start("ixInventoryAction")
							net.WriteString("Use")
							net.WriteUInt(item.id, 32)
							net.WriteUInt(item.invID or 0, 32)
							net.WriteTable({})
						net.SendToServer()
					end
				}
			end
		end
	end

	return out
end

function radial.QuickActions()
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local options = {
		{name = "Cargador", description = "Comprobar cuánta munición queda", click = function() RunConsoleCommand("efg_cargador") end},
		{name = "Modo de disparo", description = "Comprobar el modo de disparo", click = function() RunConsoleCommand("efg_mododisparo") end},
		{name = "Salud", description = "Abrir la pantalla de salud", color = Color(225, 70, 60), click = function() openTab("health") end},
		{name = "Medicinas", description = "Usar una medicina que lleves encima", color = Color(150, 215, 90), sub = character and medOptions(character) or {}},
		{name = "Inventario", description = "Abrir el inventario", click = function() openTab("inv") end}
	}

	if (!client:InRaid() and ix.efg.outfits and ix.efg.outfits.GetSet(client:GetModel())) then
		options[#options + 1] = {name = "Atuendo", description = "Cambiar cabeza, chaqueta y pantalón", click = function()
			ix.command.Send("Atuendo")
		end}
	end

	local raids = ix.plugin.Get("efg_raids")

	if (client:InRaid() and raids and raids.extractHUD) then
		table.insert(options, 3, {name = "Extracciones", description = "Ver el tiempo y tus extracciones", color = Color(140, 200, 50),
			click = function() raids.extractHUD:OpenFull() end})
	end

	return options
end

function PLUGIN:PlayerButtonDown(client, button)
	if (button != key:GetInt() or !IsFirstTimePredicted() or client != LocalPlayer()) then return end
	if (!client:Alive() or !client:GetCharacter() or vgui.CursorVisible() or IsValid(radial.active)) then return end

	radial.Open(radial.QuickActions(), button)
end
