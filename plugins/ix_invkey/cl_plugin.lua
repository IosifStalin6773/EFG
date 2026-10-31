if (not CLIENT) then return end

local PLUGIN = PLUGIN -- captura la tabla del plugin (igual que el resto del schema)
local S = SScale -- alias corto al escalado de metroui

-- ─── Fuentes (EFGX, familias OFL renombradas del kit Pizarra) ───────────────

local FONT = "MBender"

-- jerarquía tipográfica coherente:
--   Title(15) > ItemName(12) > Name(11) > Header/Tab(10) > Action(9) > Body(8) > Small(7)
local function registerFonts()
	surface.CreateFont("ixInv.Title",    {font = "MBender", size = S(15), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.ItemName", {font = FONT, size = S(12), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Name",     {font = FONT, size = S(11), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Header",   {font = "MBender", size = S(10), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Tab",      {font = "MBender", size = S(10), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Action",   {font = FONT, size = S(9),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Sub",      {font = FONT, size = S(8),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Label",    {font = "MBender", size = S(8),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Stat",     {font = FONT, size = S(8),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.StatVal",  {font = FONT, size = S(8),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Desc",     {font = FONT, size = S(8),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInv.Small",    {font = FONT, size = S(7),  weight = 500, extended = true, antialias = true})
	surface.CreateFont("efgInv.CellName", {font = "MBender", size = math.max(11, math.floor(ScrH() / 1080 * 13)), weight = 500, extended = true, antialias = true})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "ixInvKey.Fonts", registerFonts)

-- ─── Paleta ─────────────────────────────────────────────────────────────────

local C = {
	panel     = Color(22, 28, 34, 238),   -- Pizarra bg1
	panelHdr  = Color(31, 39, 48, 245),   -- bg2
	panelLine = Color(46, 58, 70, 255),   -- line
	slot      = Color(38, 48, 58, 230),   -- bg3
	slotHover = Color(52, 64, 77, 240),
	slotLine  = Color(74, 90, 106, 255),  -- lineHi
	text      = Color(227, 228, 218),
	textDim   = Color(154, 165, 175),
	textFaint = Color(104, 115, 125),
	white     = Color(237, 238, 231),
	accent    = Color(232, 131, 58),      -- naranja señal
	accentLit = Color(245, 160, 98),
	accentGlow = Color(232, 131, 58, 22),
	barBg     = Color(31, 39, 48, 220),
	salud     = Color(224, 90, 71),
	hidrat    = Color(108, 195, 213),
	energia   = Color(232, 197, 71),
	peso      = Color(154, 165, 175),
	green     = Color(127, 176, 105),
	red       = Color(224, 90, 71),
}

local RAD = 0 -- Pizarra: esquinas rectas (el chaflán lo dibuja ix.efgui)

local textures = {
	menu3 = ix.util.GetMaterial("efgui/spawnmenu/Menu/3.jpg"),
	grad  = Material("vgui/gradient-d"),
	gradU = Material("vgui/gradient-u"),
}

-- fondo grunge EFT (efg/ui/grunge.png, 512x512 en mosaico)
local GRUNGE = Material("efg/ui/grunge.png", "noclamp smooth")

local function grunge(w, h, alpha)
	surface.SetMaterial(GRUNGE)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, w / 512, h / 512)
end

-- panel EFT: grunge gris oscuro con borde sutil
local function softPanel(me, w, h, fill, noBlur)
	if (not noBlur) then ix.util.DrawBlur(me, 3) end
	if (not fill) then
		grunge(w, h, 235)
		surface.SetDrawColor(255, 255, 255, 18)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		return
	end
	surface.SetDrawColor(fill or C.panel); surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(C.panelLine)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

-- ─── Iconos de categoría ─────────────────────────────────────────────────────

local function iconGrid(x, y, s, col)
	surface.SetDrawColor(col)
	local u = s / 3.4; local g = u * 1.25
	for i = 0, 2 do for j = 0, 2 do surface.DrawRect(x + i * g, y + j * g, u, u) end end
end
local function iconStack(x, y, s, col)
	surface.SetDrawColor(col)
	local h = s / 4.2
	surface.DrawRect(x, y, s, h)
	surface.DrawRect(x + s * 0.1, y + h * 1.6, s * 0.8, h)
	surface.DrawRect(x, y + h * 3.2, s, h)
end
local function iconMelee(x, y, s, col)
	surface.SetDrawColor(col)
	surface.DrawLine(x, y + s, x + s, y); surface.DrawLine(x + 1, y + s, x + s + 1, y)
	surface.DrawLine(x, y + s * 0.35, x + s * 0.65, y + s)
end
local function iconAmmo(x, y, s, col)
	surface.SetDrawColor(col)
	local w = s / 4.5
	for i = 0, 2 do
		local bx = x + i * (w * 1.6)
		surface.DrawRect(bx, y + s * 0.25, w, s * 0.75)
		draw.NoTexture()
		surface.DrawPoly({{x = bx, y = y + s * 0.25}, {x = bx + w / 2, y = y}, {x = bx + w, y = y + s * 0.25}})
	end
end
local function iconFood(x, y, s, col)
	surface.SetDrawColor(col)
	local fx = x + s * 0.2
	for i = 0, 2 do surface.DrawRect(fx + i * (s * 0.12), y, s * 0.05, s * 0.4) end
	surface.DrawRect(fx, y + s * 0.4, s * 0.29, s * 0.12)
	surface.DrawRect(fx + s * 0.11, y + s * 0.5, s * 0.06, s * 0.5)
	surface.DrawRect(x + s * 0.7, y, s * 0.07, s)
end
local function iconMed(x, y, s, col)
	surface.SetDrawColor(col)
	local t = s / 3.2
	surface.DrawRect(x + (s - t) / 2, y, t, s); surface.DrawRect(x, y + (s - t) / 2, s, t)
end
local function iconTool(x, y, s, col)
	surface.SetDrawColor(col)
	surface.DrawLine(x, y + s, x + s, y); surface.DrawLine(x, y + s - 1, x + s, y - 1)
	surface.DrawRect(x + s * 0.6, y, s * 0.4, s * 0.4); surface.DrawRect(x, y + s * 0.6, s * 0.4, s * 0.4)
end
local function iconGear(x, y, s, col)
	surface.SetDrawColor(col)
	local c = s / 2
	for i = 0, 7 do
		local a = math.rad(i * 45)
		surface.DrawRect(x + c + math.cos(a) * c * 0.85 - 1, y + c + math.sin(a) * c * 0.85 - 1, 2, 2)
	end
	surface.DrawOutlinedRect(x + s * 0.3, y + s * 0.3, s * 0.4, s * 0.4, 1)
end

local function catMatch(item, list, weaponOnly)
	if (weaponOnly) then return item.isWeapon == true or item.weaponCategory != nil end
	if (not list) then return true end
	local cat = item.category
	if (not cat) then return false end
	for _, f in ipairs(list) do
		if (cat == f or cat:sub(1, #f) == f) then return true end
	end
	return false
end

-- Filtra una rejilla ixInventory por categoría compactando visualmente los ítems
-- coincidentes hacia la esquina superior izquierda (sin huecos), respetando el
-- tamaño de cada ítem. NO mueve los ítems en el inventario real, solo reposiciona
-- los iconos. Con isAll restaura el layout original (RebuildItems usa gridX/gridY).
local function compactPanel(p, cat, isAll)
	if (not IsValid(p)) then return end

	-- con un filtro activo la rejilla es solo-lectura: los iconos están recolocados
	-- visualmente, así que mover ítems daría posiciones erróneas (ver ixItemIcon).
	p.bFilterLocked = not isAll

	if (isAll) then
		for _, ic in pairs(p.panels or {}) do
			if (IsValid(ic)) then ic:SetVisible(true) end
		end
		if (p.RebuildItems) then p:RebuildItems() end
		return
	end

	local gridW = p.gridW or 1
	local iconSize = p.iconSize or 1
	local padTop = (p.GetPadding and p:GetPadding(2)) or 4
	local scrollY = p.scrollY or 0

	local matched = {}
	for _, ic in pairs(p.panels or {}) do
		if (IsValid(ic) and ic.itemTable) then
			if (catMatch(ic.itemTable, cat.filter, cat.weaponOnly)) then
				matched[#matched + 1] = ic
			else
				ic:SetVisible(false)
			end
		end
	end

	-- orden estable por posición original (fila, luego columna)
	table.sort(matched, function(a, b)
		if (a.gridY != b.gridY) then return a.gridY < b.gridY end
		return a.gridX < b.gridX
	end)

	local occupied = {}
	local function fits(x, y, w, h)
		if (x + w - 1 > gridW) then return false end
		for dx = 0, w - 1 do
			local col = occupied[x + dx]
			if (col) then
				for dy = 0, h - 1 do
					if (col[y + dy]) then return false end
				end
			end
		end
		return true
	end

	for _, ic in ipairs(matched) do
		ic:SetVisible(true)
		local w, h = ic.gridW or 1, ic.gridH or 1
		local placed, y = false, 1
		while (not placed and y <= 256) do
			for x = 1, gridW - w + 1 do
				if (fits(x, y, w, h)) then
					for dx = 0, w - 1 do
						occupied[x + dx] = occupied[x + dx] or {}
						for dy = 0, h - 1 do occupied[x + dx][y + dy] = true end
					end
					ic:SetPos((x - 1) * iconSize + 4, (y - 1) * iconSize + padTop - scrollY)
					placed = true
					break
				end
			end
			y = y + 1
		end
	end
end

-- icono a partir de un material (siluetas del addon metroui, igual que metrocrafting).
-- Carga perezosa + se tinta con el color de estado (activo/hover/tenue). Misma firma
-- (x, y, s, col) que los iconos vectoriales para no cambiar los call sites.
-- icono de categoría EFT de UTILS (ix.efg.utils), con el material como respaldo
local function iconUtils(name, fallback)
	return function(x, y, s, col)
		local utils = ix.efg and ix.efg.utils
		if (not (utils and utils.DrawUI(name, x - s * 0.25, y, s * 1.5, s, col))) then fallback(x, y, s, col) end
	end
end

local function iconMat(path)
	local mat
	return function(x, y, s, col)
		mat = mat or ix.util.GetMaterial(path, "noclamp smooth")
		surface.SetDrawColor(col)
		surface.SetMaterial(mat)
		surface.DrawTexturedRect(x, y, s, s)
	end
end

local CATEGORIES = {
	{icon = iconGrid,                                      label = "TODOS",    filter = nil},
	{icon = iconMat("efgui/icons/fragments_icon.png"),  label = "RECURSOS", filter = {"Recursos", "Datos Técnicos"}},
	{icon = iconUtils("assault_rifles", iconMat("efgui/icons/craft/guns.png")), label = "ARMAS", weaponOnly = true},
	{icon = iconMat("efgui/icons/craft/ammo.png"),      label = "MUNICIÓN", filter = {"Currency", "Munición", "Municion"}},
	{icon = iconUtils("food", iconMat("efgui/icons/cooking/bread.png")), label = "COMIDA",   filter = {"Consumables", "Consumibles", "Comestibles"}},
	{icon = iconUtils("heal", iconMed),                   label = "MÉDICO",   filter = {"Medicamentos", "Medkits", "Drugs", "Stimulants", "Drogas"}},
	{icon = iconMat("efgui/icons/key.png"),             label = "ÚTILES",   filter = {"Herramientas", "Aprendizaje"}},
	{icon = iconUtils("armor", iconMat("efgui/icons/craft/armor.png")), label = "EQUIPO",   filter = {"Equipamiento", "Armaduras", "Outfit", "Storage", "Accesorios"}},
}

local CAT_ES = {
	Weapons = "ARMAS", Weapon = "ARMAS", Ammo = "MUNICIÓN", Ammunition = "MUNICIÓN",
	Medical = "MÉDICO", Medkits = "MÉDICO", Medicamentos = "MÉDICO", Drugs = "MÉDICO",
	Food = "COMIDA", Consumables = "COMIDA", Consumibles = "COMIDA", Comestibles = "COMIDA",
	Equipment = "EQUIPO", Equipamiento = "EQUIPO", Armaduras = "ARMADURA", Outfit = "EQUIPO",
	Storage = "CONTENEDOR", Accesorios = "ACCESORIO", Resources = "RECURSO", Recursos = "RECURSO",
	Currency = "MONEDA", Misc = "VARIOS", Tools = "ÚTIL", Herramientas = "ÚTIL",
}
local function localizeCategory(cat)
	if (not cat) then return "OBJETO" end
	return (CAT_ES[cat] or cat):upper()
end

-- limpia etiquetas <color=...></color> del markup de descripciones
local function cleanDesc(text)
	if (not text) then return "" end
	return (text:gsub("<color=[^>]->", ""):gsub("</color>", ""))
end

-- ─── Equipamiento ───────────────────────────────────────────────────────────

-- lee el inventario de equipo del personaje (chaleco, casco, mochila y
-- contenedor seguro van ahí, no en los bolsillos, para no ocupar celdas)
local function getEquipped(char)
	local eq = {}
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(char)
	if (eqInv and ix.GetEquipSlotKind) then
		for _, item in pairs(eqInv:GetItems()) do
			local kind = ix.GetEquipSlotKind(item)
			if (kind) then eq[kind] = item end
		end
	end
	-- nombres antiguos (los usan otros paneles)
	eq.uniforme = eq.armor
	eq.mochila = eq.backpack
	return eq
end

-- ─── Helpers ────────────────────────────────────────────────────────────────

local function InventoryAction(action, itemID, invID, data)
	net.Start("ixInventoryAction")
		net.WriteString(action)
		net.WriteUInt(itemID, 32)
		net.WriteUInt(invID, 32)
		net.WriteTable(data or {})
	net.SendToServer()
end

local function getWeaponStats(item)
	local out = {}
	local swep = item.class and weapons.GetStored(item.class)
	if (not swep) then return out end
	local dmg = swep.Damage or (swep.Primary and swep.Primary.Damage)
	if (dmg) then out[#out + 1] = {"DAÑO", math.Round(dmg), 100} end
	local delay = swep.Primary and swep.Primary.Delay
	if (delay and delay > 0) then out[#out + 1] = {"CADENCIA", math.Round(60 / delay), 1200} end
	local clip = swep.Primary and swep.Primary.ClipSize
	if (clip and clip > 0) then out[#out + 1] = {"CARGADOR", clip, 100} end
	local spread = swep.HipSpread or (swep.Primary and swep.Primary.Spread) or swep.AccuracyMOA
	if (spread and spread > 0) then out[#out + 1] = {"PRECISIÓN", math.Clamp(math.Round(100 - spread * 2000), 1, 100), 100} end
	local recoil = swep.Recoil or swep.Kick or (swep.Primary and swep.Primary.Recoil)
	if (recoil) then out[#out + 1] = {"CONTROL", math.Clamp(math.Round(100 - recoil * 12), 1, 100), 100} end
	if (item.ergonomics) then out[#out + 1] = {"ERGONOMÍA", item.ergonomics, 100} end
	return out
end

local function getDurability(item)
	if (not item.GetData) then return nil end
	local dur = item:GetData("Durability")
	if (not dur) then dur = item:GetData("durability") end -- armas CW usan minúscula
	if (not dur and item.getHealth and item.getMaxHealth) then
		local mh = item:getMaxHealth()
		if (mh and mh > 0) then dur = math.Round((item:getHealth() / mh) * 100) end
	end
	if (not dur) then return nil end
	return math.floor(dur)
end

local function getFactionIcon(fi)
	local hud = ix.plugin.Get("hud")
	return hud and hud.FACTION_ICONS and hud.FACTION_ICONS[fi]
end

-- selecciona la acción a ejecutar al pulsar la tecla del acceso rápido
-- (solo para ítems NO-arma; las armas se gestionan aparte en el PlayerBindPress)
local function pickHotbarAction(item)
	if (item.functions.Usar) then return "Usar" end
	if (item.functions.use) then return "use" end
	for k, v in SortedPairs(item.functions) do
		if (k != "drop" and k != "combine") then return k end
	end
end

local HOTBAR_COUNT = ix.hotbar.SLOTS

local function setHotbar(slot, itemID)
	net.Start("ixHotbarUpdate"); net.WriteUInt(slot, 8); net.WriteUInt(itemID or 0, 32); net.SendToServer()
end

local function isPrimaryWeapon(item)
	return item and item.isWeapon and item.weaponCategory == "primary"
end

-- ¿hay ya un arma principal en otra ranura del acceso rápido?
local function hotbarHasOtherPrimary(slots, exceptIndex)
	for i, sl in pairs(slots or {}) do
		if (i != exceptIndex and IsValid(sl) and sl._itemID) then
			local it = ix.item.instances[sl._itemID]
			if (it and it.weaponCategory == "primary") then return true end
		end
	end
	return false
end

-- comprueba si se puede asignar 'item' a la ranura 'index' (regla: 1 arma principal)
local function canAssignHotbar(slots, index, item)
	if (isPrimaryWeapon(item) and hotbarHasOtherPrimary(slots, index)) then
		LocalPlayer():Notify("Solo puedes asignar un arma principal al acceso rápido.")
		return false
	end
	return true
end

-- crea el icono de un ítem EXACTAMENTE como la rejilla del inventario (cw2.0):
-- DModelPanel estático con el iconCam para armas/objetos con cámara, SpawnIcon
-- para el resto. Devuelve el panel (el llamante lo posiciona/redimensiona).
local function createItemIcon(parent, item)
	-- icono 2D propio (efg_icons) si el objeto lo tiene
	if (ix.efg and ix.efg.icons and ix.efg.icons.Get(item)) then
		local pnl = vgui.Create("DPanel", parent)
		pnl:SetMouseInputEnabled(false)
		pnl.Paint = function(_, w, h) ix.efg.icons.Draw(item, 0, 0, w, h) end
		return pnl
	end
	if (item.iconCam) then
		local mdl = vgui.Create("DModelPanel", parent)
		mdl:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")
		mdl:SetCamPos(item.iconCam.pos)
		mdl:SetLookAng(item.iconCam.ang)
		mdl:SetFOV(item.iconCam.fov)
		mdl:SetMouseInputEnabled(false)
		mdl:SetKeyboardInputEnabled(false)
		mdl.LayoutEntity = function() end
		if (IsValid(mdl.Entity)) then
			mdl.Entity:SetPos(vector_origin)
			mdl.Entity:SetAngles(angle_zero)
		end
		return mdl
	end
	local ic = vgui.Create("SpawnIcon", parent)
	ic:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")
	ic:SetMouseInputEnabled(false)
	return ic
end

-- ─── Ranuras de equipo (Pizarra) ─────────────────────────────────────────

-- cabecera de sección Pizarra
local function sectionHeader(x, y, w, h, text)
	if (ix.efgui) then
		ix.efgui.DrawHeader(x, y, w, h, nil)
	else
		surface.SetDrawColor(C.panelHdr); surface.DrawRect(x, y, w, h)
	end
	if (text) then
		draw.SimpleText(text, "ixInv.Header", x + S(6), y + h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

-- armas equipadas por categoría (siguen en los bolsillos: Helix las da al
-- personaje desde el inventario principal)
local function getEquippedWeapons(char)
	local out = {}
	local inv = char:GetInventory()
	if (not inv) then return out end
	for _, item in pairs(inv:GetItems()) do
		if (item.isWeapon and item:GetData("equip")) then
			-- primary2: armas duales – el slot real se guarda en item data "efgSlot"
			local slot = item:GetData("efgSlot") or item.weaponCategory
			if (slot and not out[slot]) then out[slot] = item end
		end
	end
	return out
end

-- contenedor seguro que siga en los bolsillos (personajes de antes de las ranuras)
local function findSecureInMain(inv)
	for _, item in pairs(inv:GetItems()) do
		if (item.isSecureContainer) then return item end
	end
end

-- slotKind: dibuja la silueta EFT de la ranura vacía (ix.efg.utils.slots)
local function paintSlotFrame(w, h, filled, hovered, label, slotKind)
	if (ix.efgui) then
		ix.efgui.DrawCell(0, 0, w, h, hovered)
	else
		surface.SetDrawColor(C.slot); surface.DrawRect(0, 0, w, h)
	end
	surface.SetDrawColor(hovered and C.accent or (filled and C.slotLine or C.panelLine))
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	local utils = ix.efg and ix.efg.utils
	if (not filled and slotKind and utils and utils.DrawUI(utils.slots[slotKind], S(4), S(4), w - S(8), h - S(8), Color(255, 255, 255, hovered and 90 or 45))) then
		return
	end
	if (not filled and label) then
		draw.SimpleText(label, "ixInv.Small", w / 2, h / 2, C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- Ranura de equipo: casco, chaleco, mochila o contenedor seguro. Se equipa
-- arrastrando el objeto encima; clic derecho lo devuelve a los bolsillos.
local function makeEquipSlot(owner, parent, x, y, sz, label, kind, item, onSelect, onUnequip, hideLabel)
	local labelH = hideLabel and 0 or S(9)
	local pnl = parent:Add("DPanel")
	pnl:SetPos(x, y); pnl:SetSize(sz, sz + labelH); pnl:SetMouseInputEnabled(true)
	pnl.Paint = function(me, w, h)
		if (hideLabel) then return end
		-- pestaña oscura con el nombre de la ranura (EFT)
		surface.SetDrawColor(14, 15, 15, 235); surface.DrawRect(0, 0, w, labelH)
		draw.SimpleText(label, "ixInv.Small", S(2), labelH / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local box = pnl:Add("DPanel")
	box:SetPos(0, labelH); box:SetSize(sz, sz); box:SetMouseInputEnabled(true)
	box.Paint = function(me, w, h)
		local hov = me:IsHovered() or (IsValid(me._icon) and me._icon:IsHovered()) or (dragndrop.IsDragging() and me:IsHovered())
		paintSlotFrame(w, h, item != nil, hov, "+", kind)
		if (item) then
			surface.SetDrawColor(ix.efgui and ix.efgui.GetItemColor(item) or C.slot)
			surface.DrawRect(1, 1, w - 2, h - 2)
		end
	end
	if (item) then
		local ic = createItemIcon(box, item)
		ic:SetPos(S(2), S(2)); ic:SetSize(sz - S(4), sz - S(4))
		ic:SetMouseInputEnabled(true)
		ic.itemTable = item -- para que el Think de detalles lo previsualice al pasar el ratón
		ic.OnMousePressed = function(_, code)
			if (code == MOUSE_RIGHT) then if (onUnequip) then onUnequip(item) end
			else if (onSelect) then onSelect(item) end end
		end
		box._icon = ic
	end
	box:Receiver("ixInventoryItem", function(_, panels, dropped)
		if (not dropped) then return end
		local it = IsValid(panels[1]) and panels[1].itemTable
		if (not it) then return end
		if (ix.GetEquipSlotKind and ix.GetEquipSlotKind(it) == kind) then
			owner:EquipToSlot(it)
		else
			LocalPlayer():Notify("Ese objeto no va en la ranura " .. (ix.EQUIP_SLOT_NAMES[kind] or label:lower()) .. ".")
		end
	end)
	return pnl
end

-- Ranura de arma (PRINCIPAL / ARMA CORTA / CUERPO A CUERPO). El arma sigue en los
-- bolsillos; la ranura muestra la equipada de esa categoría y permite
-- equipar arrastrando o desequipar con clic derecho.
local function makeWeaponSlot(owner, parent, x, y, w, h, label, category, item)
	local pnl = parent:Add("DPanel")
	pnl:SetPos(x, y); pnl:SetSize(w, h + S(9)); pnl:SetMouseInputEnabled(true)
	pnl.Paint = function(_, pw)
		surface.SetDrawColor(14, 15, 15, 235); surface.DrawRect(0, 0, pw, S(9))
		draw.SimpleText(label, "ixInv.Small", S(2), S(9) / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local box = pnl:Add("DPanel")
	box:SetPos(0, S(9)); box:SetSize(w, h)
	box.Paint = function(me, bw, bh)
		paintSlotFrame(bw, bh, item != nil, me:IsHovered(), item and nil or "VACÍO", category)
		if (item) then
			surface.SetDrawColor(ix.efgui and ix.efgui.color.item.weapon or C.slot)
			surface.DrawRect(1, 1, bw - 2, bh - 2)
		end
	end
	box.PaintOver = function(me, bw, bh)
		if (item) then
			draw.SimpleText((item.name or ""):upper(), "ixInv.Small", bw - S(2), S(1), C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
	end
	if (item) then
		local aw, ah = item.width or 1, item.height or 1
		local scale = math.min((w - S(4)) / aw, (h - S(4)) / ah)
		local ic = createItemIcon(box, item)
		ic:SetSize(aw * scale, ah * scale); ic:SetPos((w - aw * scale) / 2, (h - ah * scale) / 2)
		ic:SetMouseInputEnabled(false)
		box.itemTable = item
		box.OnMousePressed = function(_, code)
			if (code == MOUSE_RIGHT) then
				InventoryAction("EquipUn", item.id, item.invID or 0)
				surface.PlaySound("ui/buttonclickrelease.wav")
				timer.Simple(0.35, function() if (IsValid(owner)) then owner:RebuildInventoryView() end end)
			else
				owner:SetSelectedItem(item)
			end
		end
	end
	box:Receiver("ixInventoryItem", function(_, panels, dropped)
		if (not dropped) then return end
		local it = IsValid(panels[1]) and panels[1].itemTable
		if (not it) then return end
		-- primary2 acepta armas cuyo weaponCategory base sea "primary"
		local itCat = it.weaponCategory
		local ok = itCat == category or (category == "primary2" and itCat == "primary")
		if (not it.isWeapon or not ok) then
			LocalPlayer():Notify("Esa arma no va en la ranura " .. label:lower() .. ".")
			return
		end
		if (it:GetData("equip")) then return end
		-- Helix solo permite un arma equipada por categoría: primero se quita la actual
		if (item and item.id != it.id) then InventoryAction("EquipUn", item.id, item.invID or 0) end
		InventoryAction("Equip", it.id, it.invID or 0)
		surface.PlaySound("ui/buttonclickrelease.wav")
		timer.Simple(0.35, function() if (IsValid(owner)) then owner:RebuildInventoryView() end end)
	end)
	return pnl
end

-- ─── Panel principal ────────────────────────────────────────────────────────

local PANEL = {}
DEFINE_BASECLASS("Panel")

function PANEL:Init()
	local sw, sh = ScrW(), ScrH()
	self:SetPos(0, 0); self:SetSize(sw, sh)
	self:SetMouseInputEnabled(true)
	self:SetAlpha(0); self:AlphaTo(255, 0.2)

	local char = LocalPlayer():GetCharacter()
	if (not char) then self:Remove() return end
	local inv = char:GetInventory()
	if (not inv) then self:Remove() return end
	self._char = char; self._inv = inv

	local fi = char:GetFaction()
	local fd = ix.faction and ix.faction.indices and ix.faction.indices[fi]
	self._charName    = (char:GetName() or "Desconocido"):upper()
	self._factionDisp = ((fd and fd.name) or "Sin facción"):upper()
	self._factionCol  = (fd and fd.color) or C.textDim
	self._factionIcon = getFactionIcon(fi)

	-- Oficio elegido en la creación del personaje (plugins/oficios), si tiene uno.
	local oficioID = char.GetOficio and char:GetOficio()
	local oficioNombre = oficioID and ix.oficios and ix.oficios.lista and ix.oficios.lista[oficioID]
	if (oficioNombre) then
		self._factionDisp = self._factionDisp .. " - " .. oficioNombre:upper()
	end
	self._selectedItem = nil
	self._activeCat = 1
	self._charSubTab = 1

	-- dimensiones compartidas
	local d = {}
	d.margin = S(7); d.topH = S(20); d.gap = S(4)
	d.contentY = d.topH + S(3); d.panelBottom = sh - S(5)
	d.LEFT_W = S(182); d.RIGHT_W = S(200)
	d.leftX = d.margin; d.rightX = sw - d.margin - d.RIGHT_W
	d.centerX = d.leftX + d.LEFT_W + d.gap; d.CENTER_W = d.rightX - d.gap - d.centerX
	d.statusH = S(26); d.leftH = d.panelBottom - d.contentY - d.statusH - S(2)
	d.statusY = d.contentY + d.leftH + S(2); d.panelH = d.panelBottom - d.contentY
	d.sw = sw; d.sh = sh
	self.dims = d

	-- ── barra superior: pestañas + cerrar ──────────────────────────
	self.tabBtns = {}
	local function makeTab(id, label, onClick)
		local b = self:Add("DButton"); b:SetText(""); b:SetTall(d.topH)
		b.id = id
		-- estilo de la barra de secciones de EFT: la activa en un bloque claro
		b.Paint = function(me, w, h)
			local active = (self._tab == id)
			local pad = math.floor(h * 0.18)
			if (active) then
				surface.SetDrawColor(226, 224, 204); surface.DrawRect(0, pad, w, h - pad * 2)
			elseif (me:IsHovered()) then
				surface.SetDrawColor(255, 255, 255, 12); surface.DrawRect(0, pad, w, h - pad * 2)
			end
			draw.SimpleText(label, "efgx.Header", w / 2, h / 2,
				active and Color(17, 17, 15) or (me:IsHovered() and C.text or C.textDim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = onClick or function() self:SwitchTab(id) end
		self.tabBtns[id] = b
		return b
	end
	-- todo el juego cabe en el TAB: el antiguo menú F4 (efg_pmc/cl_lobby.lua)
	-- aporta las pestañas de comerciantes, escondite, raid, mercadillo y ajustes
	-- una sola barra, como la de la pantalla de personaje de EFT: GENERAL,
	-- HABILIDADES y LOGROS son vistas de la página PERSONAJE (efg_profile)
	local tabList = {
		{"char", "GENERAL"}, {"inv", "EQUIPO"}, {"health", "SALUD"}, {"skills", "HABILIDADES"},
		{"raid", "MAPA"}, {"tasks", "TAREAS"}, {"achievements", "LOGROS"},
		{"traders", "COMERCIANTES"}, {"hideout", "ESCONDITE"}, {"flea", "MERCADILLO"}, {"settings", "AJUSTES"},
	}
	for _, t in ipairs(tabList) do makeTab(t[1], t[2]) end
	-- alineadas a la izquierda, como en EFT
	surface.SetFont("efgx.Header")
	local tx = d.margin
	for _, t in ipairs(tabList) do
		local tw = surface.GetTextSize(t[2]) + S(14)
		self.tabBtns[t[1]]:SetWide(tw); self.tabBtns[t[1]]:SetPos(tx, 0); tx = tx + tw + S(1)
	end
	self._tabList = tabList

	self.closeBtn = self:Add("DButton"); self.closeBtn:SetText(""); self.closeBtn:SetSize(S(70), d.topH)
	self.closeBtn:SetPos(sw - S(74), 0)
	self.closeBtn.Paint = function(me, w, h)
		draw.SimpleText("CERRAR  X", "efgx.Header", w - S(8), h / 2,
			me:IsHovered() and C.accent or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	self.closeBtn.DoClick = function() self:Remove() end

	-- ── vistas ───────────────────────────────────────────────────────
	self.invView = self:Add("DPanel"); self.invView:SetPos(0, 0); self.invView:SetSize(sw, sh)
	self.invView.Paint = nil

	-- pestaña INVENTARIO: la de EFT en VGUI (efg_invgrid, config efgInvEFT), la
	-- DHTML de efg_invhtml (config efgInvHTML) o la rejilla antigua
	local pageClass = (vgui.GetControlTable("efgxInventoryEFT") and ix.config.Get("efgInvEFT", true)) and "efgxInventoryEFT"
		or ((vgui.GetControlTable("efgxInventoryPage") and ix.config.Get("efgInvHTML", true)) and "efgxInventoryPage")

	if (pageClass) then
		local page = self.invView:Add(pageClass)
		page:SetPos(0, d.topH)
		page:SetSize(sw, sh - d.topH)
		page:SetEmbedded(true)
		page.OnRequestClose = function() self:Remove() end
		self._htmlPage = page
	else
		self:BuildInventoryView(self.invView)
	end

	self.charView = self:Add("DPanel"); self.charView:SetPos(0, 0); self.charView:SetSize(sw, sh)
	self.charView.Paint = nil
	self:BuildCharacterView(self.charView)

	-- las vistas cubren toda la pantalla (incluida la barra superior); traer
	-- los botones de pestaña al frente para que reciban los clics.
	self.extraViews = {}
	for _, t in ipairs(tabList) do self.tabBtns[t[1]]:MoveToFront() end
	self.closeBtn:MoveToFront()

	self:SwitchTab(ix.gui.invKeyStartTab or "inv")
	ix.gui.invKeyStartTab = nil
	self:MakePopup(); self:SetKeyboardInputEnabled(self._tab == "inv" and IsValid(self._htmlPage))
end

function PANEL:SwitchTab(id)
	self._tab = id
	if (IsValid(self.invView)) then self.invView:SetVisible(id == "inv") end
	local charViews = {char = "overall", skills = "skills", achievements = "achievements"}
	if (IsValid(self.charView)) then self.charView:SetVisible(charViews[id] != nil) end
	if (charViews[id] and IsValid(self._charPage)) then self._charPage:SetView(charViews[id]) end
	-- la búsqueda del alijo (DHTML) necesita teclado
	self:SetKeyboardInputEnabled(id == "inv" and IsValid(self._htmlPage))

	-- las demás pestañas se crean al entrar (así muestran datos al día)
	for key, view in pairs(self.extraViews or {}) do
		if (IsValid(view)) then view:Remove() end
		self.extraViews[key] = nil
	end

	if (id == "inv" or charViews[id]) then return end

	local d = self.dims
	local view = self:Add("DPanel")
	view:SetPos(d.margin, d.contentY + S(4))
	view:SetSize(d.sw - d.margin * 2, d.panelH - S(4))
	view.Paint = nil
	self.extraViews[id] = view

	if (id == "health") then
		-- SALUD: bloque 2D centrado de tamaño fijo, no a pantalla completa
		local hp = view:Add("efgxHealth")
		view.PerformLayout = function(_, vw, vh)
			local hw, hh = math.min(vw, S(980)), math.min(vh, S(560))
			hp:SetSize(hw, hh)
			hp:SetPos((vw - hw) / 2, (vh - hh) / 2)
		end
	elseif (id == "flea" and vgui.GetControlTable("efgxFlea")) then
		local flea = view:Add("efgxFlea")
		flea:Dock(FILL)
	elseif (id == "tasks" and vgui.GetControlTable("efgxTasks")) then
		local tasks = view:Add("efgxTasks")
		tasks:Dock(FILL)
	elseif (id == "raid" and vgui.GetControlTable("efgxRaidSelect")) then
		local sel = view:Add("efgxRaidSelect")
		sel:SetEmbedded(true)
		sel:Dock(FILL)
	else
		-- constructores del menú principal de efg_pmc; su self:Remove() cierra el TAB
		local lobby = vgui.GetControlTable("efgLobby")
		local build = lobby and lobby["Build_" .. id]

		if (build) then
			build(self, view)
		else
			local lbl = view:Add("DLabel")
			lbl:SetText("Esta sección no está disponible (falta el plugin efg_pmc).")
			lbl:SetFont("ixInv.Name"); lbl:SetTextColor(C.textDim); lbl:SizeToContents()
		end
	end

	for _, t in ipairs(self._tabList or {}) do
		if (IsValid(self.tabBtns[t[1]])) then self.tabBtns[t[1]]:MoveToFront() end
	end
	if (IsValid(self.closeBtn)) then self.closeBtn:MoveToFront() end
end

-- ════════════════════════════════════════════════════════════════════════════
-- VISTA INVENTARIO
-- ════════════════════════════════════════════════════════════════════════════

function PANEL:BuildInventoryView(view)
	local d = self.dims
	local char, inv = self._char, self._inv
	local UI = ix.efgui

	local equipped = getEquipped(char)
	local selFn = function(item) self:SetSelectedItem(item) end
	-- click derecho en una ranura con ítem = desequipar (vuelve a los bolsillos)
	local unequipFn = function(item) self:UnequipSlot(item) end

	-- ══ IZQUIERDA: EQUIPO (ranuras alrededor del personaje) ══
	local L = view:Add("DPanel")
	L:SetPos(d.leftX, d.contentY); L:SetSize(d.LEFT_W, d.leftH)
	L.Paint = function(me, w, h)
		softPanel(me, w, h)
		sectionHeader(0, 0, w, S(13), "EQUIPO")
	end

	local nameY = S(16)
	if (self._factionIcon) then
		local f = L:Add("DPanel"); f:SetPos(S(6), nameY + S(1)); f:SetSize(S(13), S(13))
		f.Paint = function(_, w, h) surface.SetDrawColor(color_white); surface.SetMaterial(self._factionIcon); surface.DrawTexturedRect(0, 0, w, h) end
	end
	local nameLbl = L:Add("DLabel"); nameLbl:SetPos(S(23), nameY); nameLbl:SetSize(d.LEFT_W - S(28), S(10))
	nameLbl:SetFont("ixInv.Name"); nameLbl:SetTextColor(C.white); nameLbl:SetText(self._charName)
	local facLbl = L:Add("DLabel"); facLbl:SetPos(S(23), nameY + S(9)); facLbl:SetSize(d.LEFT_W - S(28), S(8))
	facLbl:SetFont("ixInv.Label"); facLbl:SetTextColor(C.textDim); facLbl:SetText(self._factionDisp)

	-- Distribución de la pestaña EQUIPO de EFT: ranuras en rejilla de 3
	-- (auricular, casco, cubrecaras / brazalete, chaleco, gafas), el PMC detrás
	-- y las armas abajo (en bandolera, a la espalda, funda y vaina). La
	-- mochila, el chaleco táctico y el contenedor seguro van en el centro, junto
	-- a su rejilla, como en EFT.
	local pad = S(6)
	local gap = S(4)
	local slotTop = nameY + S(22)
	local colW = math.floor((d.LEFT_W - pad * 2 - gap * 2) / 3)
	local slotSz = math.min(colW, S(40))
	local slotStep = slotSz + S(9) + S(6)
	local colX = {}
	for c = 1, 3 do colX[c] = pad + (c - 1) * (colW + gap) + math.floor((colW - slotSz) / 2) end

	-- armas abajo
	local wpnH = S(28)
	local wpnRow = wpnH + S(9) + S(4)
	local wpnW = d.LEFT_W - pad * 2
	local halfW = math.floor((wpnW - gap) / 2)
	local wpnY = d.leftH - wpnRow * 3 - S(2)
	local weaponsBy = getEquippedWeapons(char)

	-- el PMC detrás de las ranuras, tenue, como la silueta de EFT
	local mdlY = slotTop
	local mdlH = wpnY - S(4) - mdlY
	self.invModel = self:BuildCharModel(L, pad, mdlY, wpnW, mdlH)
	if (IsValid(self.invModel)) then self.invModel:SetAlpha(110) end

	makeEquipSlot(self, L, colX[1], slotTop, slotSz, "AURICULAR",  "headset",   equipped.headset,   selFn, unequipFn)
	makeEquipSlot(self, L, colX[2], slotTop, slotSz, "CASCO",      "helmet",    equipped.helmet,    selFn, unequipFn)
	makeEquipSlot(self, L, colX[3], slotTop, slotSz, "CUBRECARAS", "facecover", equipped.facecover, selFn, unequipFn)
	makeEquipSlot(self, L, colX[1], slotTop + slotStep, slotSz, "BRAZALETE", "armband", equipped.armband, selFn, unequipFn)
	makeEquipSlot(self, L, colX[2], slotTop + slotStep, slotSz, "CHALECO",   "armor",   equipped.armor,   selFn, unequipFn)
	makeEquipSlot(self, L, colX[3], slotTop + slotStep, slotSz, "GAFAS",     "eyewear", equipped.eyewear, selFn, unequipFn)

	makeWeaponSlot(self, L, pad, wpnY,               wpnW, wpnH, "EN BANDOLERA", "primary",  weaponsBy.primary)
	makeWeaponSlot(self, L, pad, wpnY + wpnRow,      wpnW, wpnH, "A LA ESPALDA", "primary2", weaponsBy.primary2)
	makeWeaponSlot(self, L, pad, wpnY + wpnRow * 2,  halfW, wpnH, "FUNDA", "secondary", weaponsBy.secondary)
	makeWeaponSlot(self, L, pad + halfW + gap, wpnY + wpnRow * 2, halfW, wpnH, "VAINA", "melee", weaponsBy.melee)

	-- presets de apariencia debajo de las ranuras
	local prY = slotTop + slotStep * 2
	local prLbl = L:Add("DLabel"); prLbl:SetPos(pad, prY); prLbl:SetSize(S(60), S(8))
	prLbl:SetFont("ixInv.Small"); prLbl:SetTextColor(C.textDim); prLbl:SetText("PRESETS")
	local pbSz = S(12)
	for i = 1, 3 do
		local pb = L:Add("DButton"); pb:SetText("")
		pb:SetPos(pad + (i - 1) * (pbSz + S(2)), prY + S(9)); pb:SetSize(pbSz, pbSz)
		pb.Paint = function(me, w, h)
			local has = (char:GetData("bgPresets", {})[i] != nil)
			surface.SetDrawColor(me:IsHovered() and C.slotHover or C.slot); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(has and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(i, "ixInv.Label", w / 2, h / 2, has and C.white or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		pb.DoClick = function() self:LoadBGPreset(i) end
	end

	-- ══ barras de estado ══
	local strip = view:Add("DPanel"); strip:SetPos(d.leftX, d.statusY); strip:SetSize(d.LEFT_W, d.statusH)
	strip.Paint = function(me, w, h)
		softPanel(me, w, h, nil, true)
		local segW = w / 4; local lp = LocalPlayer()
		local maxW = char.GetMaxWeight and char:GetMaxWeight() or ix.config.Get("maxWeight", 30)
		local carry = char:GetData("carry", 0)
		local sat = char.GetSaturation and char:GetSaturation() or 0
		local sti = char.GetSatiety and char:GetSatiety() or 0
		local segs = {
			{lbl = "SALUD", col = C.salud, val = lp:Health(), max = lp:GetMaxHealth(), txt = lp:Health() .. "/" .. lp:GetMaxHealth()},
			{lbl = "HIDRATACIÓN", col = C.hidrat, val = sat, max = 100, txt = math.Round(sat) .. "/100"},
			{lbl = "ENERGÍA", col = C.energia, val = sti, max = 100, txt = math.Round(sti) .. "/100"},
			{lbl = "PESO", col = carry > maxW and C.red or C.peso, val = carry, max = maxW, txt = math.Round(carry, 1) .. "/" .. maxW .. " kg"},
		}
		for i, seg in ipairs(segs) do
			local sx = (i - 1) * segW + S(3)
			draw.SimpleText(seg.lbl, "ixInv.Small", sx, S(3), C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(seg.txt, "ixInv.StatVal", sx, S(10), C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local bw, by = segW - S(6), h - S(5)
			surface.SetDrawColor(C.barBg); surface.DrawRect(sx, by, bw, S(2))
			surface.SetDrawColor(seg.col); surface.DrawRect(sx, by, bw * math.Clamp(seg.val / math.max(seg.max, 1), 0, 1), S(2))
		end
	end

	-- ══ CENTRO: bolsillos, mochila y contenedor seguro ══
	local M = view:Add("DPanel"); M:SetPos(d.centerX, d.contentY); M:SetSize(d.CENTER_W, d.panelH)
	M.Paint = function(me, w, h) softPanel(me, w, h) end

	local hdrH = S(13)
	local invHdr = M:Add("DPanel"); invHdr:SetPos(0, 0); invHdr:SetSize(d.CENTER_W, hdrH)
	invHdr.Paint = function(_, w, h)
		sectionHeader(0, 0, w, h, "INVENTARIO")
		local money = char.GetMoney and char:GetMoney() or 0
		draw.SimpleText(string.Comma(money) .. " RUB", "ixInv.Stat", w - S(6), h / 2, C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local catY = hdrH + S(2); local catH = S(18)
	local catBar = M:Add("DPanel"); catBar:SetPos(0, catY); catBar:SetSize(d.CENTER_W, catH)
	catBar.Paint = function(_, w, h) surface.SetDrawColor(C.slotLine); surface.DrawRect(0, h - 1, w, 1) end
	local catW = d.CENTER_W / #CATEGORIES
	for i, cat in ipairs(CATEGORIES) do
		local b = catBar:Add("DButton"); b:SetText(""); b:SetPos((i - 1) * catW, 0); b:SetSize(catW, catH)
		b:SetTooltip(cat.label)
		b.Paint = function(me, w, h)
			local active = (self._activeCat == i)
			if (active) then surface.SetDrawColor(C.slotHover); surface.DrawRect(1, 1, w - 2, h - 2) end
			local col = active and C.white or (me:IsHovered() and C.text or C.textDim)
			local isz = S(10); cat.icon((w - isz) / 2, (h - isz) / 2, isz, col)
			if (active) then surface.SetDrawColor(C.accent); surface.DrawRect(0, h - S(1), w, S(1)) end
		end
		b.DoClick = function() self._activeCat = i; self:FilterByCategory(cat) end
	end
	local catLabel = M:Add("DLabel"); catLabel:SetPos(S(6), catY + catH + S(1)); catLabel:SetSize(d.CENTER_W - S(12), S(8))
	catLabel:SetFont("ixInv.Small"); catLabel:SetTextColor(C.textDim); catLabel:SetText(CATEGORIES[1].label)
	self._catLabel = catLabel

	local hbH = S(22); local hbHdrH = S(11)
	local hbHdrY = d.panelH - hbH - hbHdrH - S(4)
	local hbHdr = M:Add("DPanel"); hbHdr:SetPos(0, hbHdrY); hbHdr:SetSize(d.CENTER_W, hbHdrH)
	hbHdr.Paint = function(_, w, h)
		sectionHeader(0, 0, w, h, "ACCESO RÁPIDO")
		draw.SimpleText("arrastra un objeto o pulsa Ctrl + nº", "ixInv.Small", w - S(6), h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- rejillas dentro de un scroll: bolsillos, mochila y contenedor seguro
	local gridY = catY + catH + S(10)
	local gridAreaH = hbHdrY - S(3) - gridY
	local gridAreaW = d.CENTER_W - S(12)

	local scroll = M:Add("DScrollPanel")
	scroll:SetPos(S(6), gridY); scroll:SetSize(gridAreaW, gridAreaH)
	scroll:GetVBar():SetWide(S(3))
	self._gridScroll = scroll

	local invW, invH = inv:GetSize(); invW = invW or 6; invH = invH or 6

	-- inventario interno de un contenedor equipado (mochila / contenedor seguro)
	local function innerInv(item)
		if (not item) then return nil end
		local id = item:GetData("id")
		local bi = id and ix.item.inventories[id]
		if (bi and bi.slots) then return bi end
	end

	local bagItem = equipped.backpack
	local bagInv = innerInv(bagItem)
	local rigItem = equipped.rig
	local rigInv  = innerInv(rigItem)
	local secItem = equipped.secure or findSecureInMain(inv)
	local secInv = innerInv(secItem)

	local widestCols = math.max(invW,
		bagInv and select(1, bagInv:GetSize()) or 0,
		rigInv and select(1, rigInv:GetSize()) or 0,
		secInv and select(1, secInv:GetSize()) or 0)
	-- a la izquierda de cada rejilla va la ranura del contenedor (EFT)
	local previewW = S(40)
	local gridX = previewW + S(6)
	-- celdas de EFT: 48 px a 1080p (63 px de icono en 1440p); solo encogen si
	-- la rejilla más ancha no cabe en la columna central
	local cellEFT = math.floor(48 * ScrH() / 1080)
	local iconSize = math.max(S(10), math.min(cellEFT, math.floor((gridAreaW - gridX - S(4) - 8) / math.max(widestCols, 1))))
	self._iconSize = iconSize

	local canvasY = 0
	local hdrH = math.floor(22 * ScrH() / 1080)
	local function addSection(title, sub)
		local hdr = scroll:Add("DPanel"); hdr:SetPos(0, canvasY); hdr:SetSize(gridAreaW - S(4), hdrH)
		title = string.upper(title)
		hdr.Paint = function(_, w, h)
			-- barra negra sólida a todo el ancho con el título en mayúsculas (EFT)
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255, 10)
			surface.DrawRect(0, h - 1, w, 1)
			draw.SimpleText(title, "ixInv.Header", S(4), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if (sub) then draw.SimpleText(string.upper(sub), "ixInv.Small", w - S(4), h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
		end
		canvasY = canvasY + hdrH + S(3)
	end

	local function addGrid(inventory)
		local w, h = inventory:GetSize()
		local pnl = scroll:Add("ixInventory")
		pnl:SetPos(gridX, canvasY)
		pnl:SetDraggable(false); pnl:SetSizable(false); pnl:SetTitle(nil)
		pnl.bNoBackgroundBlur = true; pnl.childPanels = {}
		pnl.Paint = nil; pnl.PaintBackground = nil
		pnl:SetIconSize(iconSize); pnl:SetInventory(inventory)
		canvasY = canvasY + math.max(h * iconSize + 10, previewW) + S(4)
		return pnl
	end

	-- ranura del contenedor (mochila, chaleco táctico, contenedor seguro) junto
	-- a su rejilla; se equipa arrastrando encima, clic derecho lo quita
	local function addContainerSlot(kind, item)
		makeEquipSlot(self, scroll, 0, canvasY, previewW, "", kind, item, selFn, unequipFn, true)
	end

	addSection("BOLSILLOS", invW .. "x" .. invH)
	local invPanel = addGrid(inv)
	ix.gui.inv1 = invPanel; self._invPanel = invPanel

	local saved = invPanel.childPanels; invPanel.childPanels = nil
	if (rigInv) then
		local rw, rh = rigInv:GetSize()
		addSection("CHALECO TÁCTICO · " .. ((rigItem.GetName and rigItem:GetName()) or rigItem.name or ""):upper(), rw .. "x" .. rh)
		addContainerSlot("rig", rigItem)
		local rigPanel = addGrid(rigInv)
		ix.gui["inv" .. rigInv:GetID()] = rigPanel; self._rigPanel = rigPanel
		saved[#saved + 1] = rigPanel
	else
		addSection("CHALECO TÁCTICO", "arrastra un chaleco táctico aquí")
		addContainerSlot("rig", nil)
		canvasY = canvasY + previewW + S(4)
	end

	if (bagInv) then
		local bw, bh = bagInv:GetSize()
		addSection("MOCHILA · " .. ((bagItem.GetName and bagItem:GetName()) or bagItem.name or ""):upper(), bw .. "x" .. bh)
		addContainerSlot("backpack", bagItem)
		local bagPanel = addGrid(bagInv)
		ix.gui["inv" .. bagInv:GetID()] = bagPanel; self._bagPanel = bagPanel
		saved[#saved + 1] = bagPanel
	else
		addSection("MOCHILA", "arrastra una mochila aquí")
		addContainerSlot("backpack", nil)
		canvasY = canvasY + previewW + S(4)
	end

	if (secInv) then
		local sw2, sh2 = secInv:GetSize()
		addSection("CONTENEDOR SEGURO · " .. ((secItem.GetName and secItem:GetName()) or secItem.name or ""):upper(), sw2 .. "x" .. sh2)
		addContainerSlot("secure", secItem)
		local secPanel = addGrid(secInv)
		ix.gui["inv" .. secInv:GetID()] = secPanel; self._secPanel = secPanel
		saved[#saved + 1] = secPanel
	else
		addSection("CONTENEDOR SEGURO", "arrastra tu contenedor seguro aquí")
		addContainerSlot("secure", nil)
		canvasY = canvasY + previewW + S(4)
	end
	invPanel.childPanels = saved

	-- ranuras de acceso rápido (con drop-receiver)
	local hbY = hbHdrY + hbHdrH + S(2); local hbGap = S(3)
	local hbSz = math.min(hbH, math.floor((d.CENTER_W - S(16) - hbGap * (HOTBAR_COUNT - 1)) / HOTBAR_COUNT))
	local hbTotal = hbSz * HOTBAR_COUNT + hbGap * (HOTBAR_COUNT - 1)
	local hbX0 = math.floor((d.CENTER_W - hbTotal) / 2)
	self._hotbarSlots = {}
	local hotbarData = ix.hotbar.Get(char)

	for i = 1, HOTBAR_COUNT do
		local sl = M:Add("DPanel")
		sl:SetPos(hbX0 + (i - 1) * (hbSz + hbGap), hbY); sl:SetSize(hbSz, hbSz); sl:SetMouseInputEnabled(true)
		sl._index = i; sl._itemID = hotbarData[i]
		if (sl._itemID and not ix.item.instances[sl._itemID]) then sl._itemID = nil end
		sl.Paint = function(me, w, h)
			UI.DrawCell(0, 0, w, h, me:IsHovered())
			surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		sl.PaintOver = function(me, w, h)
			draw.SimpleText(ix.hotbar.KeyLabel(i), "ixInv.Small", S(2), S(1), C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		local function buildIcon(it)
			if (IsValid(sl._icon)) then sl._icon:Remove() end
			local ic = createItemIcon(sl, it)
			ic:SetPos(S(2), S(2)); ic:SetSize(hbSz - S(4), hbSz - S(4))
			sl._icon = ic
		end
		sl._buildIcon = buildIcon
		local hbItem = sl._itemID and ix.item.instances[sl._itemID]
		if (hbItem) then buildIcon(hbItem) end
		-- click izquierdo: asignar seleccionado; click derecho: vaciar
		sl.OnMousePressed = function(me, code)
			if (code == MOUSE_RIGHT and me._itemID) then
				me._itemID = nil
				if (IsValid(me._icon)) then me._icon:Remove() end
				setHotbar(i, 0)
			elseif (code == MOUSE_LEFT and self._selectedItem) then
				local it = self._selectedItem
				if (not canAssignHotbar(self._hotbarSlots, i, it)) then return end
				me._itemID = it.id; buildIcon(it); setHotbar(i, it.id)
			end
		end
		-- arrastrar y soltar un ítem del inventario
		sl:Receiver("ixInventoryItem", function(recv, panels, dropped)
			if (not dropped) then return end
			local icon = panels[1]
			local it = IsValid(icon) and icon.itemTable
			if (not it) then return end
			if (not canAssignHotbar(self._hotbarSlots, i, it)) then return end
			recv._itemID = it.id; buildIcon(it); setHotbar(i, it.id)
		end)
		self._hotbarSlots[i] = sl
	end

	-- ══ DERECHA: detalles / misiones ══
	local R = view:Add("DPanel"); R:SetPos(d.rightX, d.contentY); R:SetSize(d.RIGHT_W, d.panelH)
	R.Paint = function(me, w, h)
		softPanel(me, w, h)
		sectionHeader(0, 0, w, S(13))
	end
	self._rightTab = "det"
	local tabW = d.RIGHT_W / 3
	local function rtab(id, label, x)
		local b = R:Add("DButton"); b:SetText(""); b:SetPos(x, 0); b:SetSize(tabW, S(13))
		b.Paint = function(me, w, h)
			local active = (self._rightTab == id)
			if (active) then surface.SetDrawColor(C.accent); surface.DrawRect(0, h - S(1), w, S(1)) end
			draw.SimpleText(label, "ixInv.Header", w / 2, h / 2,
				active and C.white or (me:IsHovered() and C.text or C.textDim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() self:SwitchRightTab(id) end
	end
	rtab("stash", "ALIJO", 0)
	rtab("det", "DETALLES", tabW)
	rtab("mis", "MISIONES", tabW * 2)

	local dc = R:Add("DPanel"); dc:SetPos(S(6), S(17)); dc:SetSize(d.RIGHT_W - S(12), d.panelH - S(21)); dc.Paint = nil
	self._detailContent = dc
	local mc = R:Add("DPanel"); mc:SetPos(S(6), S(17)); mc:SetSize(d.RIGHT_W - S(12), d.panelH - S(21)); mc.Paint = nil
	self._missionContent = mc

	-- alijo (10 de ancho) a la derecha, como en EFT; el servidor lo manda al
	-- abrir el TAB fuera de raid (strongbox, net ixEFGStashTab)
	local sc = R:Add("DPanel"); sc:SetPos(S(6), S(17)); sc:SetSize(d.RIGHT_W - S(12), d.panelH - S(21))
	sc.Paint = function(_, w, h)
		if (not IsValid(self._stashPanel)) then
			local lp = LocalPlayer()
			local text = (lp.InRaid and lp:InRaid()) and "El alijo no está disponible durante la raid." or "Cargando el alijo…"
			draw.SimpleText(text, "ixInv.Sub", w / 2, S(20), C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	self._stashContent = sc

	self:BuildEmptyDetails()

	if (self._stashID and ix.item.inventories[self._stashID]) then
		self:BuildStashView(self._stashID)
	else
		local lp = LocalPlayer()
		if (not (lp.InRaid and lp:InRaid())) then
			net.Start("ixEFGStashTab"); net.WriteBool(true); net.SendToServer()
			self._stashRequested = true
		end
	end

	self:SwitchRightTab(self._stashID and "stash" or ((LocalPlayer().InRaid and LocalPlayer():InRaid()) and "det" or "stash"))
end

-- Rejilla del alijo dentro de la columna derecha
function PANEL:BuildStashView(invID)
	local sc = self._stashContent
	local inv = ix.item.inventories[invID]
	if (not IsValid(sc) or not inv) then return end
	sc:Clear()
	self._stashID = invID

	local w, h = inv:GetSize()
	local hdr = sc:Add("DPanel"); hdr:Dock(TOP); hdr:SetTall(S(11))
	hdr.Paint = function(_, pw, ph)
		draw.SimpleText("ALIJO", "ixInv.Header", 0, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(w .. "x" .. h, "ixInv.Small", pw, ph / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local scroll = sc:Add("DScrollPanel"); scroll:Dock(FILL); scroll:DockMargin(0, S(2), 0, 0)
	scroll:GetVBar():SetWide(S(3))

	local iconSize = math.max(S(10), math.floor((sc:GetWide() - S(5) - 8) / math.max(w, 1)))
	local pnl = scroll:Add("ixInventory")
	pnl:SetPos(0, 0)
	pnl:SetDraggable(false); pnl:SetSizable(false); pnl:SetTitle(nil)
	pnl.bNoBackgroundBlur = true; pnl.childPanels = {}
	pnl.Paint = nil; pnl.PaintBackground = nil
	-- con inv1.childPanels puesto, SetInventory marca la rejilla con
	-- SetPaintedManually y nadie la pinta (quedaba invisible); igual que las
	-- rejillas del centro, se quita mientras tanto
	local main = IsValid(ix.gui.inv1) and ix.gui.inv1
	local saved = main and main.childPanels
	if (main) then main.childPanels = nil end
	pnl:SetIconSize(iconSize); pnl:SetInventory(inv)
	if (main) then main.childPanels = saved end
	pnl:SetPaintedManually(false)
	ix.gui["inv" .. invID] = pnl
	self._stashPanel = pnl

	if (IsValid(self._invPanel) and self._invPanel.childPanels) then
		table.insert(self._invPanel.childPanels, pnl)
	end
end

net.Receive("ixEFGStashTabReady", function()
	local id = net.ReadUInt(32)
	local panel = ix.gui.metroInventory

	if (IsValid(panel)) then
		panel:BuildStashView(id)
		if (panel._rightTab == "stash" or not panel._rightTab) then panel:SwitchRightTab("stash") end
	else
		-- el TAB ya se cerró: dejar de recibirlo
		net.Start("ixEFGStashTab"); net.WriteBool(false); net.SendToServer()
	end
end)

function PANEL:SwitchRightTab(id)
	self._rightTab = id
	if (IsValid(self._detailContent)) then self._detailContent:SetVisible(id == "det") end
	if (IsValid(self._missionContent)) then self._missionContent:SetVisible(id == "mis") end
	if (IsValid(self._stashContent)) then self._stashContent:SetVisible(id == "stash") end
	if (id == "mis") then self._missionSig = nil end -- fuerza un único rebuild en Think
end

function PANEL:BuildMissionView()
	local c = self._missionContent
	if (not IsValid(c)) then return end; c:Clear()
	local char = self._char
	local active = char.GetMissionActive and char:GetMissionActive()

	if (not active or not active.missionId) then
		local lbl = c:Add("DLabel"); lbl:Dock(TOP); lbl:DockMargin(0, S(10), 0, 0); lbl:SetTall(S(24))
		lbl:SetFont("ixInv.Sub"); lbl:SetTextColor(C.textDim); lbl:SetContentAlignment(5)
		lbl:SetWrap(true); lbl:SetText("No tienes ninguna misión activa.")
		return
	end

	local nm = c:Add("DLabel"); nm:Dock(TOP)
	nm:SetFont("ixInv.ItemName"); nm:SetTextColor(C.white); nm:SetWrap(true); nm:SetAutoStretchVertical(true)
	nm:SetText((active.missionName or "MISIÓN"):upper())

	local total = active.totalSteps or 0
	local idx = active.stepIndex or 1
	local summaries = active.stepSummaries or {}
	local prog = active.progress or {}
	local ready = active.readyToComplete

	local sub = c:Add("DLabel"); sub:Dock(TOP); sub:DockMargin(0, 0, 0, S(5)); sub:SetTall(S(10))
	sub:SetFont("ixInv.Sub"); sub:SetTextColor(C.accent); sub:SetText("PASO " .. math.min(idx, total) .. " / " .. total)

	local scroll = c:Add("DScrollPanel"); scroll:Dock(FILL); scroll:GetVBar():SetWide(S(2))
	local lastStep = ready and total or math.min(idx, total)
	for i = 1, lastStep do
		local text = summaries[i] or ("Paso " .. i)
		local current = (i == idx) and not ready
		if (current) then
			local live = prog.killed or prog.collected
			if (live) then text = text:gsub("%((%d+)/(%d+)%)", "(" .. live .. "/%2)") end
		end
		local row = scroll:Add("DLabel"); row:Dock(TOP); row:DockMargin(0, 0, 0, S(3))
		row:SetFont("ixInv.Desc"); row:SetWrap(true); row:SetAutoStretchVertical(true); row:SetText(text)
		if (ready or i < idx) then row:SetTextColor(C.textDim)
		elseif (current) then row:SetTextColor(C.accent)
		else row:SetTextColor(C.text) end
	end

	if (ready) then
		local trader = active.traderDisplayName or "el comerciante"
		local row = scroll:Add("DLabel"); row:Dock(TOP); row:DockMargin(0, S(3), 0, 0)
		row:SetFont("ixInv.Desc"); row:SetTextColor(C.green); row:SetWrap(true); row:SetAutoStretchVertical(true)
		row:SetText("¡Misión lista! Vuelve con " .. trader .. " para entregarla.")
	end
end

-- ════════════════════════════════════════════════════════════════════════════
-- VISTA PERSONAJE (apariencia + presets de bodygroups + habilidades)
-- ════════════════════════════════════════════════════════════════════════════

function PANEL:BuildCharacterView(view)
	local d = self.dims; local char = self._char

	-- pantalla OVERALL de EFT (plugin efg_profile); si falta, la vista antigua
	if (vgui.GetControlTable("efgxCharacterPage")) then
		local page = view:Add("efgxCharacterPage")
		page:SetPos(d.margin, d.contentY)
		page:SetSize(d.sw - d.margin * 2, d.panelH)
		self._charPage = page
		return
	end

	-- panel central grande
	local pad = d.margin
	local px = pad; local pw = d.sw - pad * 2
	local panel = view:Add("DPanel"); panel:SetPos(px, d.contentY); panel:SetSize(pw, d.panelH)
	panel.Paint = function(me, w, h) softPanel(me, w, h) end

	-- sub-pestañas APARIENCIA | HABILIDADES | DESCRIPCIÓN
	local stH = S(14)
	local subInfo = {{id = 1, label = "APARIENCIA"}, {id = 2, label = "HABILIDADES"}, {id = 3, label = "DESCRIPCIÓN"}}
	local stbar = panel:Add("DPanel"); stbar:SetPos(0, 0); stbar:SetSize(pw, stH)
	stbar.Paint = function(_, w, h) surface.SetDrawColor(C.panelHdr); surface.DrawRect(0, 0, w, h) end
	surface.SetFont("ixInv.Header")
	local stx = S(10)
	for _, t in ipairs(subInfo) do
		local tw = surface.GetTextSize(t.label) + S(20)
		local b = stbar:Add("DButton"); b:SetText(""); b:SetPos(stx, 0); b:SetSize(tw, stH)
		b.Paint = function(me, w, h)
			local active = (self._charSubTab == t.id)
			draw.SimpleText(t.label, "ixInv.Header", w / 2, h / 2,
				active and C.accent or (me:IsHovered() and C.text or C.textDim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if (active) then surface.SetDrawColor(C.accent); surface.DrawRect(S(4), h - S(2), w - S(8), S(2)) end
		end
		b.DoClick = function()
			self._charSubTab = t.id
			self.appPanel:SetVisible(t.id == 1)
			self.skillPanel:SetVisible(t.id == 2)
			self.descPanel:SetVisible(t.id == 3)
		end
		stx = stx + tw
	end

	local bodyY = stH + S(4); local bodyH = d.panelH - bodyY - S(4)

	-- ── APARIENCIA ──
	self.appPanel = panel:Add("DPanel"); self.appPanel:SetPos(0, bodyY); self.appPanel:SetSize(pw, bodyH); self.appPanel.Paint = nil
	local ap = self.appPanel

	-- modelo grande a la izquierda
	local mW = pw * 0.5
	self.charModel = self:BuildCharModel(ap, S(10), 0, mW - S(20), bodyH)

	-- editor de bodygroups a la derecha
	local edX = mW; local edW = pw - mW - S(10)
	local edHdr = ap:Add("DLabel"); edHdr:SetPos(edX, 0); edHdr:SetSize(edW, S(12))
	edHdr:SetFont("ixInv.Header"); edHdr:SetTextColor(C.accent); edHdr:SetText("PERSONALIZACIÓN")

	self._bgData = {}; self._skinData = {value = LocalPlayer():GetSkin()}
	local mdlRef = self.charModel
	local skinMax = IsValid(mdlRef) and IsValid(mdlRef.Entity) and math.max(0, mdlRef.Entity:SkinCount() - 1) or 0

	local scrollH = bodyH - S(80)
	local scroll = ap:Add("DScrollPanel"); scroll:SetPos(edX, S(14)); scroll:SetSize(edW, scrollH)
	scroll:GetVBar():SetWide(S(2))

	-- skin
	if (skinMax > 0) then
		local row = scroll:Add("DPanel"); row:Dock(TOP); row:DockMargin(0, 0, S(2), S(2)); row:SetTall(S(13))
		row.Paint = function(_, w, h)
			surface.SetDrawColor(C.slot); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("Skin", "ixInv.Small", S(4), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(self._skinData.value, "ixInv.Small", w - S(26), h / 2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local function apply(n) self._skinData.value = n; if (IsValid(mdlRef) and IsValid(mdlRef.Entity)) then mdlRef.Entity:SetSkin(n) end end
		local bl = row:Add("DButton"); bl:SetText(""); bl:SetSize(S(9), S(9))
		bl.Paint = function(me, w, h) surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1); draw.SimpleText("<", "ixInv.Small", w / 2, h / 2, C.text, 1, 1) end
		bl.DoClick = function() if (self._skinData.value > 0) then apply(self._skinData.value - 1) end end
		local br = row:Add("DButton"); br:SetText(""); br:SetSize(S(9), S(9))
		br.Paint = function(me, w, h) surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1); draw.SimpleText(">", "ixInv.Small", w / 2, h / 2, C.text, 1, 1) end
		br.DoClick = function() if (self._skinData.value < skinMax) then apply(self._skinData.value + 1) end end
		row.PerformLayout = function(s, w, h) bl:SetPos(w - S(20), S(2)); br:SetPos(w - S(10), S(2)) end
	end

	-- bodygroups
	for _, bg in ipairs(LocalPlayer():GetBodyGroups()) do
		if (bg.id == 0) then continue end
		local maxV = LocalPlayer():GetBodygroupCount(bg.id) - 1
		if (maxV < 1) then continue end
		local cur = {value = LocalPlayer():GetBodygroup(bg.id)}
		self._bgData[bg.id] = cur
		local function apply(n) cur.value = n; if (IsValid(mdlRef) and IsValid(mdlRef.Entity)) then mdlRef.Entity:SetBodygroup(bg.id, n) end end
		local row = scroll:Add("DPanel"); row:Dock(TOP); row:DockMargin(0, 0, S(2), S(2)); row:SetTall(S(13))
		local nm = bg.name:sub(1, 1):upper() .. bg.name:sub(2)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(C.slot); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(nm, "ixInv.Small", S(4), h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(cur.value, "ixInv.Small", w - S(26), h / 2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local bl = row:Add("DButton"); bl:SetText(""); bl:SetSize(S(9), S(9))
		bl.Paint = function(me, w, h) surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1); draw.SimpleText("<", "ixInv.Small", w / 2, h / 2, C.text, 1, 1) end
		bl.DoClick = function() if (cur.value > 0) then apply(cur.value - 1) end end
		local br = row:Add("DButton"); br:SetText(""); br:SetSize(S(9), S(9))
		br.Paint = function(me, w, h) surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1); draw.SimpleText(">", "ixInv.Small", w / 2, h / 2, C.text, 1, 1) end
		br.DoClick = function() if (cur.value < maxV) then apply(cur.value + 1) end end
		row.PerformLayout = function(s, w, h) bl:SetPos(w - S(20), S(2)); br:SetPos(w - S(10), S(2)) end
	end

	-- botón EQUIPAR: aplica la apariencia editada al jugador
	local eqBtn = ap:Add("DButton"); eqBtn:SetText(""); eqBtn:SetPos(edX, scrollH + S(16)); eqBtn:SetSize(edW, S(16))
	eqBtn.Paint = function(me, w, h)
		surface.SetDrawColor(me:IsHovered() and C.accentLit or C.accent); surface.DrawRect(0, 0, w, h)
		draw.SimpleText("EQUIPAR APARIENCIA", "ixInv.Action", w / 2, h / 2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	eqBtn.DoClick = function() self:ApplyAppearance() end

	-- presets de apariencia
	local prLbl = ap:Add("DLabel"); prLbl:SetPos(edX, scrollH + S(36)); prLbl:SetSize(edW, S(10))
	prLbl:SetFont("ixInv.Label"); prLbl:SetTextColor(C.textDim); prLbl:SetText("PRESETS")
	local hint = ap:Add("DLabel"); hint:SetPos(edX + S(40), scrollH + S(36)); hint:SetSize(edW - S(40), S(9))
	hint:SetFont("ixInv.Small"); hint:SetTextColor(C.textFaint); hint:SetContentAlignment(6); hint:SetText("izq: cargar · der: guardar")

	local pbW = (edW - S(8)) / 3
	for i = 1, 3 do
		local pb = ap:Add("DButton"); pb:SetText(""); pb:SetPos(edX + (i - 1) * (pbW + S(4)), scrollH + S(48)); pb:SetSize(pbW, S(16))
		pb.Paint = function(me, w, h)
			local has = (char:GetData("bgPresets", {})[i] != nil)
			surface.SetDrawColor(me:IsHovered() and C.slotHover or C.slot); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(has and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("PRESET " .. i, "ixInv.Small", w / 2, h / 2, has and C.white or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		pb.OnMousePressed = function(me, code)
			if (code == MOUSE_RIGHT) then self:SaveBGPreset(i)
			elseif (code == MOUSE_LEFT) then self:LoadBGPreset(i) end
		end
	end

	-- ── HABILIDADES (perks del plugin "habilidades", en dos columnas) ──
	self.skillPanel = panel:Add("DPanel"); self.skillPanel:SetPos(0, bodyY); self.skillPanel:SetSize(pw, bodyH); self.skillPanel.Paint = nil
	self.skillPanel:SetVisible(false)
	local sp = self.skillPanel
	local skScroll = sp:Add("DScrollPanel"); skScroll:SetPos(S(12), S(4)); skScroll:SetSize(pw - S(24), bodyH - S(8))
	skScroll:GetVBar():SetWide(S(2))

	-- recopilar perks (categoría "perk") del plugin de habilidades
	local perks = {}
	if (ix.perks and ix.perks.list) then
		for _, def in ipairs(ix.perks.list) do
			if (def.category == "perk") then perks[#perks + 1] = def end
		end
	end

	if (#perks > 0 and char.GetPerkXP) then
		local maxLvl = ix.perks.maxLevel or 10
		local canvasW = (pw - S(24)) - S(6) -- ancho útil descontando la barra de scroll
		local colGap, rowGap = S(6), S(5)
		local cardW = math.floor((canvasW - colGap) / 2)
		local cardH = S(46)
		local rows = math.ceil(#perks / 2)

		-- contenedor de la rejilla (su alto = nº de filas) para que el scroll funcione
		local grid = skScroll:Add("DPanel"); grid:Dock(TOP); grid:SetTall(rows * (cardH + rowGap)); grid.Paint = nil

		local function perkCard(def, x, y)
			local card = grid:Add("DPanel"); card:SetPos(x, y); card:SetSize(cardW, cardH)
			card.Paint = function(_, w, h)
				local level, xpInto, xpNeeded = ix.perks.GetProgress(char:GetPerkXP(def.id))
				surface.SetDrawColor(C.slot); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText((def.name or def.id) .. "   [" .. level .. "/" .. maxLvl .. "]",
					"ixInv.Sub", S(6), S(5), C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				if (def.recompensa) then
					draw.SimpleText("Recompensa: " .. def.recompensa,
						"ixInv.Small", S(6), S(17), C.accentLit, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				end
				local barX, barY, barW, barH = S(6), h - S(14), w - S(12), S(10)
				local frac = (xpNeeded > 0) and math.Clamp(xpInto / xpNeeded, 0, 1) or 1
				surface.SetDrawColor(C.barBg); surface.DrawRect(barX, barY, barW, barH)
				surface.SetDrawColor(C.accent); surface.DrawRect(barX, barY, barW * frac, barH)
				surface.SetDrawColor(C.slotLine); surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
				local txt = (xpNeeded > 0) and (xpInto .. " / " .. xpNeeded .. " XP") or "NIVEL MÁXIMO"
				draw.SimpleText(txt, "ixInv.Small", barX + barW / 2, barY + barH / 2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		for i, def in ipairs(perks) do
			local col = (i - 1) % 2
			local rowN = math.floor((i - 1) / 2)
			perkCard(def, col * (cardW + colGap), rowN * (cardH + rowGap))
		end
	else
		local none = skScroll:Add("DLabel"); none:Dock(TOP); none:SetTall(S(20))
		none:SetFont("ixInv.Small"); none:SetTextColor(C.textDim); none:SetText("No hay habilidades disponibles.")
	end

	-- ── DESCRIPCIÓN (biografía editable) ──
	-- Un DTextEntry EMBEBIDO en este panel grande no recibe foco de teclado de forma
	-- fiable en GMod, ni siquiera con el truco de "SetKeyboardInputEnabled(false) en
	-- la raíz tras MakePopup". El único patrón fiable: un DFrame popup aparte con su
	-- propio MakePopup + RequestFocus (mismo patrón ya usado en el menú TAB viejo,
	-- ver ix.gui.descEditor referenciado en el bloqueo de la tecla TAB más abajo).
	self.descPanel = panel:Add("DPanel"); self.descPanel:SetPos(0, bodyY); self.descPanel:SetSize(pw, bodyH); self.descPanel.Paint = nil
	self.descPanel:SetVisible(false)
	local dp = self.descPanel
	local dHdr = dp:Add("DLabel"); dHdr:SetPos(S(12), 0); dHdr:SetSize(pw - S(24), S(12))
	dHdr:SetFont("ixInv.Header"); dHdr:SetTextColor(C.accent); dHdr:SetText("DESCRIPCIÓN")
	local dHint = dp:Add("DLabel"); dHint:SetPos(pw - S(180), 0); dHint:SetSize(S(168), S(12))
	dHint:SetFont("ixInv.Small"); dHint:SetTextColor(C.textFaint); dHint:SetContentAlignment(6)
	dHint:SetText("clic para editar")

	local descData = {text = (char.GetDescription and char:GetDescription()) or ""}

	local preview = dp:Add("DPanel"); preview:SetPos(S(12), S(15)); preview:SetSize(pw - S(24), bodyH - S(34))
	preview:SetMouseInputEnabled(true); preview:SetCursor("hand")
	preview.Paint = function(me, w, h)
		surface.SetDrawColor(C.slot); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(me:IsHovered() and C.accent or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	local previewLbl = preview:Add("DLabel"); previewLbl:SetPos(S(6), S(4)); previewLbl:SetSize(pw - S(36), bodyH - S(42))
	previewLbl:SetFont("ixInv.Desc"); previewLbl:SetTextColor(C.text); previewLbl:SetWrap(true)
	previewLbl:SetAutoStretchVertical(false); previewLbl:SetMouseInputEnabled(false)
	previewLbl:SetText(descData.text != "" and descData.text or "Sin descripción. Haz clic para añadir una.")

	local function openDescEditor()
		if (IsValid(ix.gui.descEditor)) then ix.gui.descEditor:Remove() end

		local frame = vgui.Create("DFrame")
		ix.gui.descEditor = frame
		frame:SetTitle("Editar Descripción")
		frame:SetSize(S(280), S(160))
		frame:Center()
		frame:MakePopup()
		frame:SetDeleteOnClose(true)

		local entry = frame:Add("DTextEntry")
		entry:SetPos(S(8), S(28)); entry:SetSize(S(264), S(90))
		entry:SetMultiline(true); entry:SetFont("ixInv.Desc")
		entry:SetText(descData.text)

		local saveBtn = frame:Add("DButton"); saveBtn:SetText("Guardar")
		saveBtn:SetPos(S(8), S(122)); saveBtn:SetSize(S(128), S(28))
		saveBtn.DoClick = function()
			local newText = entry:GetValue():sub(1, 1000)
			descData.text = newText
			previewLbl:SetText(newText != "" and newText or "Sin descripción. Haz clic para añadir una.")
			net.Start("ixInvSaveDesc"); net.WriteString(newText); net.SendToServer()
			surface.PlaySound("ui/buttonclickrelease.wav")
			LocalPlayer():ChatPrint("Descripción guardada.")
			frame:Remove()
		end

		local cancelBtn = frame:Add("DButton"); cancelBtn:SetText("Cancelar")
		cancelBtn:SetPos(S(144), S(122)); cancelBtn:SetSize(S(128), S(28))
		cancelBtn.DoClick = function() frame:Remove() end

		-- RequestFocus debe ir DESPUÉS de que el frame sea popup y esté en pantalla;
		-- sin esto el DTextEntry no recibe el caret ni el teclado.
		entry:RequestFocus()
	end

	-- previewLbl tiene el ratón desactivado a propósito: el clic pasa al panel
	-- "preview" de debajo. DPanel no invoca DoClick automáticamente al pulsar
	-- (a diferencia de DButton/DLabel), así que se engancha OnMousePressed directo.
	preview.OnMousePressed = function(_, code)
		if (code == MOUSE_LEFT) then openDescEditor() end
	end
end

-- presets de bodygroups
function PANEL:SaveBGPreset(slot)
	local groups = {}
	for id, cur in pairs(self._bgData or {}) do groups[id] = cur.value end
	net.Start("ixBGPresetSave")
		net.WriteUInt(slot, 8)
		net.WriteTable(groups)
		net.WriteUInt(self._skinData and self._skinData.value or 0, 8)
	net.SendToServer()
	-- reflejar en char data local de inmediato. SetData es solo de servidor (usa
	-- net.Send), así que en el cliente actualizamos la caché local directamente,
	-- igual que hace OnSet internamente. El servidor persiste vía ixBGPresetSave.
	local presets = self._char:GetData("bgPresets", {})
	presets[slot] = {groups = groups, skin = self._skinData and self._skinData.value or 0}
	self._char.vars.data = self._char.vars.data or {}
	self._char.vars.data.bgPresets = presets
	surface.PlaySound("ui/buttonclickrelease.wav")
	LocalPlayer():ChatPrint("Preset de apariencia " .. slot .. " guardado.")
end

-- aplica una tabla de bodygroups (+skin) a los modelos de vista previa
function PANEL:PreviewAppearance(groups, skin)
	for _, m in ipairs({self.charModel, self.invModel}) do
		if (IsValid(m) and IsValid(m.Entity)) then
			for id, val in pairs(groups) do m.Entity:SetBodygroup(tonumber(id) or 0, val) end
			if (skin) then m.Entity:SetSkin(skin) end
		end
	end
end

-- aplica la apariencia editada actualmente al jugador real
function PANEL:ApplyAppearance()
	local groups = {}
	for id, cur in pairs(self._bgData or {}) do groups[id] = cur.value end
	local skin = self._skinData and self._skinData.value or 0
	self:PreviewAppearance(groups, skin)
	net.Start("ixBodygroupTableSet"); net.WriteEntity(LocalPlayer()); net.WriteTable(groups); net.SendToServer()
	net.Start("ixInvSaveSkin"); net.WriteUInt(skin, 8); net.SendToServer()
	surface.PlaySound("ui/buttonclickrelease.wav")
	LocalPlayer():ChatPrint("Apariencia equipada.")
end

function PANEL:LoadBGPreset(slot)
	local preset = self._char:GetData("bgPresets", {})[slot]
	if (not preset) then LocalPlayer():ChatPrint("El preset " .. slot .. " está vacío.") return end
	local groups = preset.groups or {}
	self:PreviewAppearance(groups, preset.skin)
	for id, val in pairs(groups) do if (self._bgData and self._bgData[id]) then self._bgData[id].value = val end end
	if (preset.skin and self._skinData) then self._skinData.value = preset.skin end
	net.Start("ixBodygroupTableSet"); net.WriteEntity(LocalPlayer()); net.WriteTable(groups); net.SendToServer()
	net.Start("ixInvSaveSkin"); net.WriteUInt(preset.skin or 0, 8); net.SendToServer()
	surface.PlaySound("ui/buttonclickrelease.wav")
	LocalPlayer():ChatPrint("Preset " .. slot .. " cargado.")
end

-- ─── Modelo de personaje ────────────────────────────────────────────────────

function PANEL:BuildCharModel(parent, x, y, w, h)
	local lp = LocalPlayer()
	local m = parent:Add("ixModelPanel")
	m:SetPos(x, y); m:SetSize(w, h)
	m:SetModel(lp:GetModel()); m:SetFOV(33)
	m:SetLookAt(Vector(0, 0, 42)); m:SetCamPos(Vector(110, 0, 44))
	m:SetAmbientLight(Color(70, 70, 80))
	m:SetDirectionalLight(BOX_FRONT, Color(240, 180, 130))
	m:SetDirectionalLight(BOX_TOP, Color(120, 120, 140))
	if (IsValid(m.Entity)) then
		m.Entity:SetSkin(lp:GetSkin())
		for _, bg in ipairs(lp:GetBodyGroups()) do m.Entity:SetBodygroup(bg.id, lp:GetBodygroup(bg.id)) end
	end
	function m:LayoutEntity()
		local ent = self.Entity
		if (not IsValid(ent)) then return end
		if (not self._idleSet) then
			local seq = ent:LookupSequence("idle_all_01")
			if (seq <= 0) then seq = ent:LookupSequence("idle_unarmed") end
			if (seq <= 0) then seq = ent:SelectWeightedSequence(ACT_IDLE) end
			if (seq > 0) then ent:ResetSequence(seq); self._idleSet = true end
		end
		ent:SetAngles(Angle(0, 45, 0)); ent:SetIK(false); self:RunAnimation()
	end
	m._lastModel = lp:GetModel()
	return m
end

-- ─── Detalles ───────────────────────────────────────────────────────────────

function PANEL:BuildEmptyDetails()
	local c = self._detailContent
	if (not IsValid(c)) then return end; c:Clear()
	local lbl = c:Add("DLabel"); lbl:SetPos(0, c:GetTall() / 3); lbl:SetSize(c:GetWide(), S(20))
	lbl:SetFont("ixInv.Sub"); lbl:SetTextColor(C.textDim); lbl:SetContentAlignment(5)
	lbl:SetText("Selecciona un objeto\npara ver sus detalles."); lbl:SetWrap(true)
end

local WCAT_ES = {
	primary = "ARMA PRIMARIA", secondary = "ARMA SECUNDARIA", melee = "CUERPO A CUERPO",
	pistol = "PISTOLA", grenade = "GRANADA", misc = "UTILIDAD",
}

function PANEL:SetSelectedItem(item)
	if (not item or self._selectedItem == item) then return end
	self._selectedItem = item
	local c = self._detailContent
	if (not IsValid(c)) then return end; c:Clear()
	local W = c:GetWide()

	-- ── cabecera (Dock TOP) ──
	local nm = c:Add("DLabel"); nm:Dock(TOP)
	nm:SetFont("ixInv.ItemName"); nm:SetTextColor(C.white)
	nm:SetWrap(true); nm:SetAutoStretchVertical(true)
	nm:SetText((item.name or "Desconocido"):upper())

	local subTxt
	if (item.isWeapon or item.isCW) then
		subTxt = "ARMA · " .. (WCAT_ES[item.weaponCategory] or "ARMA")
	else
		subTxt = localizeCategory(item.category)
	end
	local sub = c:Add("DLabel"); sub:Dock(TOP); sub:DockMargin(0, 0, 0, S(4)); sub:SetTall(S(10))
	sub:SetFont("ixInv.Sub"); sub:SetTextColor(C.textDim); sub:SetText(subTxt)

	-- ── modelo (Dock TOP) ──
	local boxH = S(50)
	local mb = c:Add("DPanel"); mb:Dock(TOP); mb:DockMargin(0, 0, 0, S(5)); mb:SetTall(boxH)
	mb.Paint = function(_, w, h) surface.SetDrawColor(ix.efgui and ix.efgui.GetItemColor(item) or Color(9, 9, 8, 150)); surface.DrawRect(0, 0, w, h); surface.SetDrawColor(C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1) end
	-- icono estático con la proporción real del ítem (igual que la rejilla cw2.0)
	local aw, ah = item.width or 1, item.height or 1
	local ic = createItemIcon(mb, item)
	ic.PaintOver = nil
	mb.PerformLayout = function(_, bw, bh)
		local scale = math.min(bw / aw, bh / ah)
		local iw, ih = aw * scale, ah * scale
		ic:SetSize(iw, ih); ic:SetPos((bw - iw) / 2, (bh - ih) / 2)
	end
	-- clic en el modelo: ventana de inspección (efg_menus)
	mb:SetCursor("hand")
	mb.OnMousePressed = function()
		if (vgui.GetControlTable("efgxInspect")) then
			surface.PlaySound("ui/buttonclickrelease.wav")
			vgui.Create("efgxInspect"):SetItem(item)
		end
	end
	mb.PaintOver = function(_, w, h)
		draw.SimpleText("INSPECCIONAR", "ixInv.Label", w - S(3), h - S(2), C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	-- ── recoger acciones (para construir los botones abajo) ──
	local invID = item.invID or 0
	item.player = LocalPlayer()
	local actions = {}
	for k, v in SortedPairs(item.functions) do
		if (k == "drop" or k == "combine") then continue end
		if (v.OnCanRun and v.OnCanRun(item) == false) then continue end
		actions[#actions + 1] = {key = k, fn = v, name = v.name or k}
	end
	local primary
	for i, a in ipairs(actions) do
		if (a.key == "Equip" or a.key == "EquipUn" or a.key == "Usar" or a.name == "equip" or a.name == "unequip") then
			primary = table.remove(actions, i); break
		end
	end
	local dropFn = item.functions.drop
	local hasDrop = dropFn and (not dropFn.OnCanRun or dropFn.OnCanRun(item) != false)
	item.player = nil

	-- armadura (uniforme) y mochila: equipar/desequipar las mueve al inventario de
	-- equipo (no ocupan el inventario principal). Sustituimos el botón principal.
	if (ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)) then
		if (self:IsEquipSlotItem(item)) then
			primary = {custom = true, label = "GUARDAR", fn = function() self:UnequipSlot(item) end}
		else
			primary = {custom = true, label = "EQUIPAR", fn = function() self:EquipToSlot(item) end}
		end
	end

	-- abre un menú para funciones multi-opción (p.ej. quitar un accesorio concreto)
	local function refresh()
		timer.Simple(0.25, function()
			if (not IsValid(self)) then return end
			self._selectedItem = nil
			local ref = ix.item.instances[item.id]
			if (ref) then self:SetSelectedItem(ref) else self:BuildEmptyDetails() end
		end)
	end
	local function runMulti(a)
		item.player = LocalPlayer()
		local opts = isfunction(a.fn.multiOptions) and a.fn.multiOptions(item, LocalPlayer()) or a.fn.multiOptions
		item.player = nil
		if (not opts or #opts == 0) then self:RunAction(item, a.key, a.fn, invID) return end
		local menu = DermaMenu()
		for _, subo in ipairs(opts) do
			menu:AddOption(tostring(subo.name or "?"), function()
				item.player = LocalPlayer()
				local send = true
				if (subo.OnClick) then send = subo.OnClick(item) end
				if (send != false) then InventoryAction(a.key, item.id, invID, subo.data) end
				item.player = nil
				refresh()
			end)
		end
		menu:Open()
	end

	local secondary = {}
	if (hasDrop) then
		local wasEquipSlotItem = self:IsEquipSlotItem(item)
		secondary[#secondary + 1] = {name = "SOLTAR", col = C.red, fn = function()
			item.player = LocalPlayer()
			local send = true
			if (dropFn.OnClick) then send = dropFn.OnClick(item) end
			if (send != false) then InventoryAction("drop", item.id, invID) end
			item.player = nil; self._selectedItem = nil; self:BuildEmptyDetails()

			-- si se soltó directamente desde el slot de uniforme/mochila, hay que
			-- refrescar esos slots (getEquipped() solo se recalcula al reconstruir
			-- la vista); si no, el slot sigue mostrando el ítem ya soltado hasta
			-- cerrar y reabrir el inventario.
			if (wasEquipSlotItem) then
				timer.Simple(0.35, function() if (IsValid(self)) then self:RebuildInventoryView() end end)
			end
		end}
	end
	for _, a in ipairs(actions) do
		secondary[#secondary + 1] = {name = a.name:upper(), col = C.text, fn = function()
			if (a.fn.isMulti or a.fn.multiOptions) then runMulti(a) else self:RunAction(item, a.key, a.fn, invID) end
		end}
	end

	-- ── botones (Dock BOTTOM, nunca se solapan con la descripción) ──
	local btnH = S(13); local btnGap = S(2)
	local secRows = math.ceil(#secondary / 2)
	local btnAreaH = (primary and (btnH + btnGap) or 0) + secRows * (btnH + btnGap)
	if (btnAreaH > 0) then
		local btnArea = c:Add("DPanel"); btnArea:Dock(BOTTOM); btnArea:DockMargin(0, S(4), 0, 0)
		btnArea:SetTall(btnAreaH); btnArea.Paint = nil
		local by = btnAreaH
		if (primary) then
			by = by - btnH
			local pn = primary.custom and primary.label or primary.name
			if (pn == "equip") then pn = "EQUIPAR" elseif (pn == "unequip") then pn = "GUARDAR" end
			local pb = btnArea:Add("DButton"); pb:SetText(""); pb:SetPos(0, by); pb:SetSize(W, btnH)
			pb.Paint = function(me, w, h)
				surface.SetDrawColor(me:IsHovered() and C.accentLit or C.accent); surface.DrawRect(0, 0, w, h)
				draw.SimpleText(pn:upper(), "ixInv.Action", w / 2, h / 2, Color(14, 15, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			pb.DoClick = function()
				if (primary.custom) then primary.fn()
				else self:RunAction(item, primary.key, primary.fn, invID) end
			end
			by = by - btnGap
		end
		for row = secRows, 1, -1 do
			by = by - btnH
			local a1 = secondary[(row - 1) * 2 + 1]
			local a2 = secondary[(row - 1) * 2 + 2]
			local cols = a2 and 2 or 1
			local bw = math.floor((W - btnGap * (cols - 1)) / cols)
			local function mk(idx, info)
				local b = btnArea:Add("DButton"); b:SetText(""); b:SetPos(idx * (bw + btnGap), by); b:SetSize(bw, btnH)
				b.Paint = function(me, w, h)
					surface.SetDrawColor(me:IsHovered() and C.slotHover or C.slot); surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(me:IsHovered() and info.col or C.slotLine); surface.DrawOutlinedRect(0, 0, w, h, 1)
					draw.SimpleText(info.name, "ixInv.Action", w / 2, h / 2, info.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				b.DoClick = info.fn
			end
			if (a1) then mk(0, a1) end
			if (a2) then mk(1, a2) end
			by = by - btnGap
		end
	end

	-- ── stats (Dock TOP, debajo del modelo) ──
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
		for _, st in ipairs(getWeaponStats(item)) do statRow(st[1], tostring(st[2]), st[3] and (st[2] / st[3]) or nil) end
	elseif (istable(item.stats)) then
		for _, st in ipairs(item.stats) do local mx = st[3] or st[2]; statRow(st[1], tostring(st[2]), mx and (st[2] / mx) or nil) end
	end
	statRow("PESO", math.Round(item.weight or 0, 2) .. " kg", nil)
	local dur = getDurability(item)
	if (dur) then
		local col = dur >= 50 and C.green or (dur >= 25 and C.energia or C.red)
		statRow("DURABILIDAD", dur .. "/100", dur / 100, col)
	end
	if (item.ammoType) then statRow("MUNICIÓN", tostring(L(item.ammoType)), nil) end

	-- ── descripción (Dock FILL, ocupa el espacio restante y hace scroll) ──
	local desc = item.description or ""
	if (item.GetDescription) then
		local ok, res = pcall(item.GetDescription, item)
		if (ok and res) then desc = res end
	end
	desc = cleanDesc(desc)
	local scr = c:Add("DScrollPanel"); scr:Dock(FILL); scr:DockMargin(0, S(4), 0, 0); scr:GetVBar():SetWide(S(2))
	local dl = scr:Add("DLabel"); dl:Dock(TOP); dl:SetWide(W - S(4))
	dl:SetFont("ixInv.Desc"); dl:SetTextColor(C.text); dl:SetWrap(true); dl:SetAutoStretchVertical(true); dl:SetText(desc)
end

function PANEL:RunAction(item, key, fn, invID)
	item.player = LocalPlayer()
	local send = true
	if (fn.OnClick) then send = fn.OnClick(item) end
	if (fn.sound) then surface.PlaySound(fn.sound) end
	if (send != false) then InventoryAction(key, item.id, invID) end
	item.player = nil
	timer.Simple(0.25, function()
		if (not IsValid(self)) then return end
		self._selectedItem = nil
		local ref = ix.item.instances[item.id]
		if (ref) then self:SetSelectedItem(ref) else self:BuildEmptyDetails() end
	end)
end

-- reconstruye la vista de inventario (tras equipar/desequipar, para reflejar
-- el movimiento de uniforme/mochila entre el inv principal y el de equipo)
function PANEL:RebuildInventoryView()
	-- las páginas de EFT (VGUI o HTML) se refrescan solas por firma
	if (not IsValid(self.invView) or IsValid(self._htmlPage)) then return end
	local vis = self.invView:IsVisible()
	self._selectedItem = nil; self._lockedItem = nil
	self.invView:Clear()
	self:BuildInventoryView(self.invView)
	self.invView:SetVisible(vis)
end

-- equipa un ítem moviéndolo al inventario de equipo (libera celdas del principal)
function PANEL:EquipToSlot(item)
	net.Start("ixEquipToSlot"); net.WriteUInt(item.id, 32); net.SendToServer()
	surface.PlaySound("ui/buttonclickrelease.wav")
	timer.Simple(0.35, function() if (IsValid(self)) then self:RebuildInventoryView() end end)
end

-- desequipa: lo devuelve al inventario principal
function PANEL:UnequipSlot(item)
	net.Start("ixUnequipSlot"); net.WriteUInt(item.id, 32); net.SendToServer()
	surface.PlaySound("ui/buttonclickrelease.wav")
	timer.Simple(0.35, function() if (IsValid(self)) then self:RebuildInventoryView() end end)
end

-- ¿el ítem está en el inventario de equipo (equipado en su slot)?
function PANEL:IsEquipSlotItem(item)
	if (not item) then return false end
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(self._char)
	return eqInv and item.invID == eqInv:GetID() or false
end

function PANEL:FilterByCategory(cat)
	cat = cat or CATEGORIES[self._activeCat] or CATEGORIES[1]
	if (IsValid(self._catLabel)) then self._catLabel:SetText(cat.label) end
	-- no reposicionar mientras se arrastra un ítem (interferiría con el drag)
	if (dragndrop.IsDragging()) then return end
	local isAll = (cat.filter == nil and not cat.weaponOnly)
	compactPanel(self._invPanel, cat, isAll)
	compactPanel(self._rigPanel, cat, isAll)
	compactPanel(self._bagPanel, cat, isAll)
	compactPanel(self._secPanel, cat, isAll)
end

-- Firma barata del contenido de una rejilla (id + posición de cada ítem) para
-- detectar cambios en el Think y recolocar en el acto (ver Think).
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

-- ─── Paint ──────────────────────────────────────────────────────────────────

function PANEL:Paint(w, h)
	-- como en EFT: el mundo desenfocado detrás y un velo oscuro
	ix.util.DrawBlur(self, 10)
	grunge(w, h, 230)
	surface.SetDrawColor(0, 0, 0, 90); surface.DrawRect(0, 0, w, h)

	local topH = S(20)
	surface.SetDrawColor(12, 13, 13, 245); surface.DrawRect(0, 0, w, topH)
	surface.SetDrawColor(C.panelLine); surface.DrawRect(0, topH - 1, w, 1)
end

function PANEL:Think()
	if (IsValid(ix.gui.menu)) then self:Remove() return end

	-- detalles: el hover previsualiza, pero al hacer clic en un ítem se FIJA y ya
	-- no cambia aunque pases el ratón por otro (hasta que pulses otro ítem distinto).
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

	-- Reaplicar el layout en cuanto cambie el contenido de una rejilla (reordenar,
	-- mover/equipar ítems) o al soltar un arrastre, en vez de en un tick throttleado
	-- a 0.3s que dejaba los iconos "desordenados" hasta ~0.3s después de la acción.
	-- FilterByCategory ya se ignora durante el arrastre, así que no rompe el drag&drop.
	if (self._tab == "inv") then
		local dragging = dragndrop.IsDragging()
		local a = self:GridSignature(self._invPanel)
		local b = self:GridSignature(self._rigPanel) + self:GridSignature(self._bagPanel) + self:GridSignature(self._secPanel)

		if (a != self._sigA or b != self._sigB or dragging != self._wasDragging) then
			self._sigA, self._sigB = a, b
			self._wasDragging = dragging
			self:FilterByCategory()
		end
	end

	-- Ctrl + número (4-8): asigna el ítem seleccionado a esa ranura del acceso rápido
	-- (no si estás escribiendo en un campo de texto, p.ej. la descripción)
	local focus = vgui.GetKeyboardFocus()
	local typing = IsValid(focus) and focus.GetClassName and tostring(focus:GetClassName()):find("Entry")
	local ctrl = (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) and not typing
	self._numDown = self._numDown or {}
	for i = 1, HOTBAR_COUNT do
		local down = input.IsKeyDown(KEY_1 + (i - 1) + ix.hotbar.KEY_OFFSET)
		if (down and not self._numDown[i]) then
			self._numDown[i] = true
			if (ctrl and self._selectedItem and canAssignHotbar(self._hotbarSlots, i, self._selectedItem)) then
				local it = self._selectedItem
				setHotbar(i, it.id)
				local sl = self._hotbarSlots[i]
				if (IsValid(sl)) then sl._itemID = it.id; if (sl._buildIcon) then sl._buildIcon(it) end end
				surface.PlaySound("ui/buttonclickrelease.wav")
			end
		elseif (not down) then
			self._numDown[i] = false
		end
	end

	-- refrescar el progreso de la misión solo cuando cambia (evita parpadeo)
	if (self._rightTab == "mis") then
		local char = self._char
		local active = char.GetMissionActive and char:GetMissionActive()
		local sig = "none"
		if (active and active.missionId) then
			local p = active.progress or {}
			sig = active.missionId .. "|" .. (active.stepIndex or 0) .. "|" .. (p.killed or 0) .. "|" .. (p.collected or 0) .. "|" .. tostring(active.readyToComplete)
		end
		if (sig != self._missionSig) then
			self._missionSig = sig
			self:BuildMissionView()
		end
	end
	-- ambos paneles de modelo (inv y char) se refrescan por separado, cada uno con
	-- su propio _lastModel; si solo se actualizara el de la pestaña activa, el otro
	-- se quedaría con el modelo viejo (p.ej. sin el traje recién equipado) al volver
	-- a esa pestaña, porque nunca detectaría el cambio.
	local lp = LocalPlayer(); local model = lp:GetModel()
	for _, m in ipairs({self.invModel, self.charModel}) do
		if (IsValid(m) and model != m._lastModel) then
			m._lastModel = model
			m:SetModel(model, lp:GetSkin()); m._idleSet = false
			if (IsValid(m.Entity)) then
				for _, bg in ipairs(lp:GetBodyGroups()) do m.Entity:SetBodygroup(bg.id, lp:GetBodygroup(bg.id)) end
			end
		end
	end
end

function PANEL:Remove()
	if (self._removing) then return end; self._removing = true
	self:AlphaTo(0, 0.15, 0, function() if (IsValid(self)) then BaseClass.Remove(self) end end)
end

function PANEL:OnRemove()
	if (ix.gui.metroInventory == self) then ix.gui.metroInventory = nil end
	if (self._stashID or self._stashRequested) then
		net.Start("ixEFGStashTab"); net.WriteBool(false); net.SendToServer()
	end
	CloseDermaMenus()
end

vgui.Register("ixMetroInventory", PANEL, "Panel")

-- ─── Menú contextual: asignar a acceso rápido ───────────────────────────────

-- con el inventario Metro abierto, suprimimos el menú contextual por defecto:
-- todas las acciones (equipar, soltar, acceso rápido…) están en el panel DETALLES.
hook.Add("CreateItemInteractionMenu", "ixInvKey.SuppressMenu", function(icon, menu, item)
	if (IsValid(ix.gui.metroInventory)) then return true end
end)

-- ─── Tecla TAB ──────────────────────────────────────────────────────────────

-- ¿el arma activa del jugador local está recargando? Se usa para no abrir el inventario.
-- Los flags que expone CW2 (isReloading()/IsReloading/GetIsReloading/NWBool "reloading")
-- no son fiables desde el cliente: pueden quedarse "pegados" en true tras una recarga
-- interrumpida o en escopetas shell-by-shell (mismo problema ya parcheado server-side en
-- ix_cwsupport/sv_plugin.lua vía ixCWSPendingReload), lo que dejaba el inventario
-- bloqueado incluso después de terminar de recargar. En vez de fiarnos de esos flags,
-- detectamos la pulsación de R nosotros mismos y medimos la ventana de bloqueo con la
-- duración real de recarga del arma (wep.ReloadSpeed, el mismo valor que usa CW2), así
-- que expira justo cuando la recarga termina de verdad en vez de depender del estado.
local reloadWep, reloadUntil = nil, 0
hook.Add("KeyPress", "ixInvKey.TrackReload", function(ply, key)
	if (key != IN_RELOAD or ply != LocalPlayer()) then return end
	local wep = ply:GetActiveWeapon()
	if (not IsValid(wep)) then return end
	if (wep.Clip1 and wep.GetMaxClip1 and wep:Clip1() >= wep:GetMaxClip1()) then return end -- cargador lleno, no recarga

	reloadWep = wep
	reloadUntil = CurTime() + (wep.ReloadSpeed or 2.5) + 1
end)

local function isLocalReloading(lp)
	if (reloadWep != lp:GetActiveWeapon()) then return false end
	return CurTime() < reloadUntil
end

-- pide al servidor que cambie al arma indicada (fiable: no depende del HUD).
local function switchToWeapon(ply, class)
	local wep = ply:GetWeapon(class)
	if (IsValid(wep)) then input.SelectWeapon(wep) end
	net.Start("ixSelectWeapon"); net.WriteString(class); net.SendToServer()
	return true
end

-- guarda el arma cambiando al SWEP de manos.
local function selectHands(ply)
	local hands = ply:GetWeapon("ix_hands")
	if (not IsValid(hands)) then hands = ply:GetWeapon("ohandsswep") end
	if (not IsValid(hands)) then return false end
	return switchToWeapon(ply, hands:GetClass())
end

local invKeyDown = false
hook.Add("Think", "ixMetroInventoryKey", function()
	local isDown = input.IsKeyDown(ix.efg.binds and ix.efg.binds.Key("inventory") or KEY_TAB)
	-- AJUSTES > CONTROLES esperando una tecla: no abrir ni cerrar el TAB
	if (ix.efg.binds and IsValid(ix.efg.binds.capturing)) then invKeyDown = isDown; return end
	if (isDown and not invKeyDown) then
		invKeyDown = true
		local lp = LocalPlayer()
		if (not IsValid(lp) or not lp:GetCharacter()) then return end
		if (IsValid(ix.gui.descEditor)) then return end
		local focus = vgui.GetKeyboardFocus()
		if (IsValid(focus) and focus:GetClassName():find("Entry")) then return end
		if (IsValid(ix.gui.metroInventory)) then ix.gui.metroInventory:Remove(); return end
		-- no se puede abrir el inventario mientras estás esposado (cerrarlo sí está permitido)
		if (lp:IsRestricted()) then
			lp:Notify("No puedes abrir el inventario mientras estás esposado.")
			return
		end
		-- no se puede abrir el inventario mientras se recarga (cerrarlo sí está permitido)
		if (isLocalReloading(lp)) then
			lp:Notify("No puedes abrir el inventario mientras recargas.")
			return
		end
		if (IsValid(ix.gui.menu)) then ix.gui.menu:Remove() end
		ix.gui.metroInventory = vgui.Create("ixMetroInventory")
	elseif (not isDown) then invKeyDown = false end
end)

-- Desactivar el selector de armas por defecto: mismo método que new_wepselect.lua.
-- Helix ejecuta de forma fiable los hooks de PLUGIN (no así un hook.Add normal de
-- HUDShouldDraw, porque GM:HUDShouldDraw consulta una tabla local). ix_invkey ES un
-- plugin, así que definimos el hook del plugin directamente.
function PLUGIN:HUDShouldDraw(name)
	if (name == "CHudWeaponSelection") then
		return false
	end
end

hook.Add("ShouldDrawCrosshair", "DCROSS", function() return false end)
hook.Add("ShouldHideBars", "DBARS", function() return false end)
hook.Add("ShouldBarDraw", "DBARS", function(bar) return false end)

-- El selector visible es el plugin CORE de Helix "wepselect" (su PLUGIN:HUDPaint lo
-- dibuja). new_wepselect lo desactivaba eliminando sus hooks del HOOKS_CACHE de Helix;
-- hacemos lo mismo para quitarlo por completo (dibujo + ciclado de armas).
local function killHelixWepSelect()
	if (not HOOKS_CACHE) then return end
	local wepselect = ix.plugin.Get("wepselect")
	if (not wepselect) then return end
	for _, hookName in ipairs({"HUDPaint", "HUDShouldDraw", "PlayerBindPress", "Think", "ScoreboardShow", "ShouldPopulateEntityInfo", "OnIndexChanged"}) do
		if (HOOKS_CACHE[hookName]) then HOOKS_CACHE[hookName][wepselect] = nil end
	end
end
function PLUGIN:InitializedPlugins() killHelixWepSelect() end
killHelixWepSelect()
hook.Add("InitPostEntity", "ixInvKey.KillHelixWepSelect", killHelixWepSelect)
timer.Simple(1, killHelixWepSelect)
timer.Simple(5, killHelixWepSelect)

-- El selector de armas (new_wepselect / GS_WeaponSelector) registra hooks
-- globales persistentes que sobreviven aunque el plugin esté desactivado.
-- Quitamos su DIBUJADO y el ciclado de armas por completo.
local function killWepSelector()
	for _, ev in ipairs({"HUDPaint", "PlayerBindPress", "Think", "ScoreboardShow", "PostDrawHUD", "DrawOverlay", "HUDShouldDraw"}) do
		hook.Remove(ev, "GS_WeaponSelector")
	end
end
killWepSelector()
hook.Add("InitPostEntity", "ixInvKey.KillWepSelector", killWepSelector)
timer.Create("ixInvKey.KillWepSelector", 2, 5, killWepSelector)

-- ─── Acceso rápido: teclas numéricas ─────────────────────────────────────────

local function hotbarBind(ply, bind, pressed)
	-- desactivar el selector de armas base de Helix/GMod: el cambio de arma
	-- solo se hace por el acceso rápido, así que bloqueamos el ciclado nativo.
	if (bind == "invnext" or bind == "invprev" or bind == "lastinv") then return true end
	if (not pressed or not ply:Alive()) then return end
	local slot = bind:match("^slot(%d)$")
	if (not slot) then return end
	slot = tonumber(slot)

	-- Staff: 9 = physgun, 0 = toolgun. No son ítems de inventario (no caben en
	-- el acceso rápido de 5 ranuras) y el selector de armas nativo está
	-- desactivado, así que sin esto el staff no tiene forma de sacarlas.
	if (slot == 9 or slot == 0) then
		if (not ply:IsAdmin()) then return end

		local toolID = (slot == 9) and 1 or 2
		local class = (slot == 9) and "weapon_physgun" or "gmod_tool"
		local wep = ply:GetWeapon(class)

		if (not IsValid(wep)) then
			-- No la tiene (p.ej. su personaje no tiene la flag p/t): pedir al
			-- servidor que se la dé y reintentar el cambio cuando la tenga.
			net.Start("ixStaffToolGive")
				net.WriteUInt(toolID, 2)
			net.SendToServer()

			timer.Simple(0.3, function()
				if (not IsValid(ply)) then return end
				local w = ply:GetWeapon(class)
				if (IsValid(w)) then switchToWeapon(ply, class) end
			end)

			return true
		end

		local active = ply:GetActiveWeapon()
		if (IsValid(active) and active:GetClass() == class) then
			selectHands(ply)
		else
			switchToWeapon(ply, class)
		end

		return true
	end

	-- con el inventario abierto, las teclas numéricas se usan para asignar
	-- (Ctrl + nº); bloqueamos el cambio de arma nativo.
	if (IsValid(ix.gui.metroInventory)) then return true end
	local char = ply:GetCharacter()
	if (not char) then return end

	-- 1, 2 y 3: sacar o guardar el arma equipada en pistolera, bandolera y espalda
	local weaponKey = ix.hotbar.WEAPON_KEYS[slot]

	if (weaponKey) then
		for _, item in pairs(char:GetInventory():GetItems(true)) do
			if (item.isWeapon and item:GetData("equip") and (item:GetData("efgSlot") or item.weaponCategory or "primary") == weaponKey) then
				local wep = item.class and ply:GetWeapon(item.class)
				local active = ply:GetActiveWeapon()

				if (not IsValid(wep) or (IsValid(active) and active:GetClass() == "weapon_stalker2_bpa")) then break end

				if (IsValid(active) and active == wep) then
					selectHands(ply)
				else
					switchToWeapon(ply, item.class)
				end

				break
			end
		end

		return true
	end

	-- 4 a 8: ranuras del acceso rápido
	slot = slot and slot - ix.hotbar.KEY_OFFSET
	if (not slot or slot < 1 or slot > HOTBAR_COUNT) then return end
	local itemID = ix.hotbar.Get(char)[slot]
	if (not itemID) then return end
	local item = ix.item.instances[itemID]
	if (not item) then return end

	if (item.isWeapon) then
		-- Las armas NO se desequipan desde el acceso rápido (equipar/desequipar rápido
		-- buguea la munición). El arma permanece SIEMPRE equipada; la tecla solo
		-- alterna entre SACARLA y GUARDARLA (sacar las manos), sin tocar la munición.
		local active = ply:GetActiveWeapon()

		-- La animación de guardar la mochila (plugin anim_inv / SWEP "weapon_stalker2_bpa")
		-- debe acabar antes de sacar un arma: mientras ese SWEP siga siendo el arma activa
		-- (animación en curso tras cerrar el inventario), no equipamos nada.
		if (IsValid(active) and active:GetClass() == "weapon_stalker2_bpa") then
			return true
		end

		local wep = item.class and ply:GetWeapon(item.class)
		if (IsValid(wep)) then
			if (IsValid(active) and active:GetClass() == item.class) then
				-- ya en mano → guardar (sacar las manos, sin desequipar el arma)
				selectHands(ply)
			else
				switchToWeapon(ply, wep:GetClass())
			end
		else
			-- no la tiene equipada → equiparla y sacarla.
			-- Helix solo permite UN arma equipada por categoría (weaponCategory): si ya
			-- hay otra de la misma categoría equipada, item:Equip la rechaza
			-- ("weaponSlotFilled"). Para poder CAMBIAR de arma, desequipamos primero la
			-- que ocupa esa categoría (EquipUn). El net es fiable y ordenado, así que el
			-- servidor procesa el EquipUn antes que el Equip.
			if (item.weaponCategory) then
				local char = ply:GetCharacter()
				local inv = char and char:GetInventory()
				if (inv) then
					for _, other in pairs(inv:GetItems()) do
						if (other.id != itemID and other.isWeapon and other.weaponCategory == item.weaponCategory and other:GetData("equip") == true) then
							other.player = ply
							InventoryAction("EquipUn", other.id, other.invID or 0)
							other.player = nil
						end
					end
				end
			end
			item.player = ply
			InventoryAction("Equip", itemID, item.invID or 0)
			item.player = nil
			timer.Simple(0.2, function()
				if (not IsValid(ply)) then return end
				local w = item.class and ply:GetWeapon(item.class)
				if (IsValid(w)) then switchToWeapon(ply, w:GetClass()) end
			end)
		end
		return true
	end

	item.player = ply
	local action = pickHotbarAction(item)
	item.player = nil
	if (action) then InventoryAction(action, itemID, item.invID or 0); return true end
end

-- Con efg_ui, las teclas de armas (1-3) y acceso rápido (4-8) salen de
-- AJUSTES > CONTROLES y llegan por PlayerButtonDown; los "slotN" de GMod del 1
-- al 8 se bloquean. 9 y 0 (staff) siguen por PlayerBindPress.
local SLOT_BINDS = {"weapon1", "weapon2", "weapon3", "quick1", "quick2", "quick3", "quick4", "quick5"}

hook.Add("PlayerBindPress", "ixInvKey.Hotbar", function(ply, bind, pressed)
	if (ix.efg.binds) then
		local n = tonumber(bind:match("^slot(%d)$") or "")
		if (n and n >= 1 and n <= #SLOT_BINDS) then return true end
	end

	return hotbarBind(ply, bind, pressed)
end)

hook.Add("PlayerButtonDown", "ixInvKey.HotbarKeys", function(ply, button)
	if (ply != LocalPlayer() or !IsFirstTimePredicted() or !ix.efg.binds or vgui.CursorVisible()) then return end

	for n, id in ipairs(SLOT_BINDS) do
		if (ix.efg.binds.Matches(id, button)) then
			hotbarBind(ply, "slot" .. n, true)
			return
		end
	end
end)

concommand.Add("openMetroMenu", function()
	local lp = LocalPlayer()
	if (not IsValid(lp) or not lp:GetCharacter()) then return end
	if (IsValid(ix.gui.metroNewMenu)) then ix.gui.metroNewMenu:Remove(); return end
	if (IsValid(ix.gui.metroInventory)) then ix.gui.metroInventory:Remove() end
	vgui.Create("metroNewMenu")
end)

-- ─── Tema compartido ─────────────────────────────────────────────────────────
-- Expone la estética del inventario (paleta, paneles, categorías, helpers) para
-- que otros paneles (p.ej. el almacenamiento ixStorageView) la reutilicen y se
-- vean idénticos. Las fuentes ixInv.* ya son globales (surface.CreateFont).
ixInvTheme = {
	C               = C,
	RAD             = RAD,
	textures        = textures,
	softPanel       = softPanel,
	createItemIcon  = createItemIcon,
	CATEGORIES      = CATEGORIES,
	catMatch        = catMatch,
	localizeCategory = localizeCategory,
	cleanDesc       = cleanDesc,
	getDurability   = getDurability,
	getWeaponStats  = getWeaponStats,
	InventoryAction = InventoryAction,
	WCAT_ES         = WCAT_ES,
	compactPanel    = compactPanel,
}
