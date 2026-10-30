-- Pantalla de modding de armas de ARC9, como la de EFT. Se abre con MODIFICAR,
-- el banco de armas o la tecla de personalizar de ARC9 (ix.arc9.OpenEFTInspect):
-- el arma queda en modo personalizar y ARC9 la muestra en el centro de la
-- pantalla; la página (cl_modhtml.lua) deja ese hueco transparente.
-- Montar y desmontar usa Attach/Detach de ARC9 en el cliente; ARC9 manda el
-- arma al servidor y arc9_support quita o devuelve el objeto de la pieza.

local PLUGIN = PLUGIN
local INS = ix.efg.inspect

local ASSET = "asset://garrysmod/materials/"

local STAT_ROWS = {
	{key = "ergo",     label = "Ergonomía",            max = 100, better = "high"},
	{key = "recoilV",  label = "Retroceso vertical",   max = 600, better = "low"},
	{key = "recoilH",  label = "Retroceso horizontal", max = 600, better = "low"},
	{key = "accuracy", label = "Precisión",            max = 12,  better = "low", unit = "moa"},
	{key = "weight",   label = "Peso",                 max = 8,   better = "low", unit = "kg"},
}

local function attName(att)
	local atttbl = ARC9.GetAttTable(att)
	return atttbl and (atttbl.PrintName or atttbl.CompactName) or att
end

-- icono de la pieza: el del objeto de Helix (efg_icons) o el propio de ARC9
local iconCache = {}

local function attIcon(att)
	if (iconCache[att] != nil) then return iconCache[att] or nil end

	local path
	local uniqueID = ix.arc9.GetItemForAttachment(att)
	local itemTable = uniqueID and ix.item.list[uniqueID]

	if (itemTable and ix.efg.icons) then path = ix.efg.icons.Resolve(itemTable) end

	if (!path) then
		local atttbl = ARC9.GetAttTable(att)
		local icon = atttbl and atttbl.Icon

		if (type(icon) == "IMaterial") then
			local name = icon:GetName()

			for _, ext in ipairs({".png", ".jpg"}) do
				if (file.Exists("materials/" .. name .. ext, "GAME")) then path = name .. ext break end
			end
		end
	end

	iconCache[att] = path and (ASSET .. path) or false
	return iconCache[att] or nil
end

local function installedOf(slot)
	return isstring(slot.Installed) and slot.Installed != "" and slot.Installed or nil
end

-- ranuras del arma en orden de árbol (ARC9 las da en preorden) con su
-- profundidad, sacada de ParentAddress
local function slotTree(weapon)
	local list = weapon:GetSubSlotList()
	local entries, byAddr = {}, {}

	for i, slot in ipairs(list) do
		byAddr[slot.Address or i] = slot
	end

	for i, slot in ipairs(list) do
		local depth, parent, guard = 0, slot.ParentAddress, 0

		while (parent and byAddr[parent] and guard < 16) do
			depth = depth + 1
			parent = byAddr[parent].ParentAddress
			guard = guard + 1
		end

		entries[#entries + 1] = {slot = slot, addr = slot.Address or i, key = tostring(slot.Address or i), depth = depth}
	end

	return entries, byAddr
end

-- la ranura y todas las que cuelgan de ella (al cambiar la pieza se pierden)
local function subtree(entries, byAddr, addr)
	local skip = {[addr] = true}

	for _, entry in ipairs(entries) do
		local parent, guard = entry.slot.ParentAddress, 0

		while (parent and guard < 16) do
			if (parent == addr) then skip[entry.addr] = true break end
			parent = byAddr[parent] and byAddr[parent].ParentAddress
			guard = guard + 1
		end
	end

	return skip
end

local function attsExcept(entries, skip)
	local out = {}

	for _, entry in ipairs(entries) do
		local att = installedOf(entry.slot)
		if (att and !skip[entry.addr]) then out[#out + 1] = att end
	end

	return out
end

-- piezas que cuenta ARC9:PlayerGetAtts (inventario principal del personaje)
local function ownedAtts(character)
	local out = {}
	local inventory = character and character:GetInventory()
	if (!inventory) then return out end

	for _, item in ipairs(inventory:GetItemsByBase("base_arc9_attachments", false)) do
		local att = item:GetAttachment()
		out[att] = (out[att] or 0) + 1
	end

	return out
end

local function call(weapon, method, ...)
	if (!weapon[method]) then return end

	local ok, result = pcall(weapon[method], weapon, ...)
	if (ok) then return result end
end

local FIREMODES = {[-1] = "Auto", [0] = "Seguro", [1] = "Semi"}

local function weaponInfo(weapon, installed)
	local info = {}
	local ammo = call(weapon, "GetValue", "Ammo")
	local caliber = isstring(ammo) and INS.AmmoStats(ammo).name

	if (caliber) then info[#info + 1] = {"Calibre", caliber} end

	local rpm = tonumber(call(weapon, "GetValue", "RPM"))
	if (rpm and rpm > 0) then info[#info + 1] = {"Cadencia", math.Round(rpm) .. " dpm"} end

	local clip = tonumber(call(weapon, "GetValue", "ClipSize"))
	if (clip and clip > 0) then info[#info + 1] = {"Cargador", clip .. " balas"} end

	local modes = call(weapon, "GetValue", "Firemodes")

	if (istable(modes)) then
		local names = {}

		for _, mode in ipairs(modes) do
			local m = tonumber(mode.Mode) or 1
			names[#names + 1] = FIREMODES[m] or (m .. "R")
		end

		if (#names > 0) then info[#info + 1] = {"Modos de fuego", table.concat(names, ", ")} end
	end

	info[#info + 1] = {"Piezas montadas", tostring(#installed)}

	return info, caliber
end

function PLUGIN:BuildModPayload(item, weapon)
	local entries = slotTree(weapon)
	local installed = attsExcept(entries, {})
	local info, caliber = weaponInfo(weapon, installed)
	local payload = {
		name = item:GetName(), sub = caliber or "", slots = {}, info = info, statRows = STAT_ROWS,
		stats = ix.arc9.CalcEFTStats(item, installed)
	}

	for _, entry in ipairs(entries) do
		local slot = entry.slot
		if (slot.Hidden) then continue end

		local att = installedOf(slot)

		payload.slots[#payload.slots + 1] = {
			k = entry.key, label = slot.PrintName or "Ranura", depth = entry.depth,
			att = att, name = att and attName(att), icon = att and attIcon(att),
			integral = att and call(weapon, "CanDetach", entry.addr) == false or nil,
			blocked = !att and call(weapon, "GetSlotBlocked", slot) == true or nil
		}
	end

	if (!weapon:GetCustomize()) then
		payload.note = "El arma ya no está en modo personalizar."
	end

	return payload
end

-- piezas compatibles con una ranura: las del inventario se pueden montar,
-- el resto sale en gris como "No disponible" (igual que en EFT)
function PLUGIN:BuildModParts(item, weapon, key)
	local entries, byAddr = slotTree(weapon)
	local entry

	for _, e in ipairs(entries) do
		if (e.key == key) then entry = e break end
	end

	if (!entry) then return end

	local slot = entry.slot
	local current = installedOf(slot)
	local base = attsExcept(entries, subtree(entries, byAddr, entry.addr))
	local owned = ownedAtts(LocalPlayer():GetCharacter())
	local allFree = ix.config.Get("freeAttachments(ARC9)", false)
	local list, seen = {}, {}

	for _, att in ipairs(ARC9.GetAttsForCats(slot.Category or {})) do
		if (seen[att]) then continue end
		seen[att] = true

		local atttbl = ARC9.GetAttTable(att)
		if (!atttbl or atttbl.AdminOnly or ARC9.Blacklist[att]) then continue end
		if (att != current and call(weapon, "CanAttach", entry.addr, att, slot, true) != true) then continue end

		local free = allFree or ix.arc9.IsFreeAttachment(att) and true or false
		local count = free and 0 or (owned[atttbl.InvAtt or att] or 0)
		local preview = table.Copy(base)
		preview[#preview + 1] = att

		list[#list + 1] = {
			att = att, name = attName(att), icon = attIcon(att), on = att == current,
			free = free, count = count, have = free or count > 0,
			preview = ix.arc9.CalcEFTStats(item, preview)
		}
	end

	table.sort(list, function(a, b)
		if (a.on != b.on) then return a.on end
		if (a.have != b.have) then return a.have end
		return a.name < b.name
	end)

	return {
		k = key, label = slot.PrintName or "Ranura", list = list,
		installed = current != nil, integral = current and call(weapon, "CanDetach", entry.addr) == false or nil,
		removePreview = ix.arc9.CalcEFTStats(item, base)
	}
end

function PLUGIN:ModSignature(item, weapon)
	local sig = {}

	for _, att in ipairs(ix.arc9.GetInstalledAtts(weapon)) do sig[#sig + 1] = att end

	local inventory = LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetInventory()

	if (inventory) then
		for _, other in ipairs(inventory:GetItemsByBase("base_arc9_attachments", false)) do sig[#sig + 1] = other:GetID() end
	end

	return table.concat(sig, ",") .. tostring(weapon:GetCustomize())
end

-- ─── Panel ───────────────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgWeaponMod)) then ix.gui.efgWeaponMod:Remove() end
	ix.gui.efgWeaponMod = self

	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.15)

	self.html = self:Add("DHTML")
	self.html:Dock(FILL)
	self.html:SetAllowLua(false)

	local function weapon() return IsValid(self.weapon) and self.weapon:GetCustomize() and self.weapon or nil end
	local function item() return self.itemID and ix.item.instances[self.itemID] end
	local function addr(key) return self.addrs and self.addrs[tostring(key)] end

	self.html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	self.html:AddFunction("efg", "close", function() self:Close() end)

	self.html:AddFunction("efg", "select", function(key)
		local swep, it = weapon(), item()
		if (!swep or !it or !isstring(key)) then return end

		local parts = PLUGIN:BuildModParts(it, swep, key)
		if (parts) then self.html:RunJavascript("parts(" .. util.TableToJSON(parts) .. ")") end
	end)

	self.html:AddFunction("efg", "install", function(key, att)
		local swep, address = weapon(), addr(key)
		if (!swep or address == nil or !isstring(att) or !ARC9.GetAttTable(att)) then return end

		-- ARC9:PlayerGetAtts devuelve 0 si el cliente aún no tiene la tabla
		LocalPlayer().ARC9_AttInv = LocalPlayer().ARC9_AttInv or {}

		if (swep:Attach(address, att)) then
			self.flash = key
		else
			ix.util.Notify("No se puede montar esa pieza.")
		end
	end)

	self.html:AddFunction("efg", "remove", function(key)
		local swep, address = weapon(), addr(key)
		if (!swep or address == nil) then return end

		if (!swep:Detach(address)) then ix.util.Notify("Esa pieza no se puede desmontar.") end
	end)

	-- igual que el menú de ARC9: arrastrar gira el arma y la rueda acerca
	self.html:AddFunction("efg", "rotate", function(dx, dy, reset)
		local swep = weapon()
		if (!swep) then return end

		if (reset) then
			swep.CustomizePitch, swep.CustomizeYaw, swep.CustomizeZoom = 0, 0, 0
			return
		end

		local scale = ARC9ScreenScale or ScreenScale
		swep.CustomizePitch = (swep.CustomizePitch or 0) - (tonumber(dx) or 0) / scale(4) * 3
		swep.CustomizeYaw = (swep.CustomizeYaw or 0) + (tonumber(dy) or 0) / scale(8) * 3
	end)

	self.html:AddFunction("efg", "zoom", function(dir)
		local swep = weapon()
		if (!swep) then return end

		swep.CustomizeZoom = math.Clamp((swep.CustomizeZoom or 0) + (tonumber(dir) or 0) * 3, -64, 64)
	end)

	self.html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	self.html:SetHTML(ix.efgui.InjectCSS(PLUGIN.modHTML))
end

function PANEL:Setup(item, weapon)
	self.itemID = item:GetID()
	self.weapon = weapon
	self.openedAt = RealTime()
	self:Push()
end

function PANEL:Push()
	local item = self.itemID and ix.item.instances[self.itemID]
	if (!self.ready or !item or !IsValid(self.weapon)) then return end

	self.sig = PLUGIN:ModSignature(item, self.weapon)

	local payload = PLUGIN:BuildModPayload(item, self.weapon)
	payload.flash = self.flash
	self.flash = nil

	self.addrs = {}
	for _, entry in ipairs(slotTree(self.weapon)) do self.addrs[entry.key] = entry.addr end

	self.html:RunJavascript("render(" .. util.TableToJSON(payload) .. ")")
end

function PANEL:Think()
	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.2

	local item = self.itemID and ix.item.instances[self.itemID]
	local weapon = self.weapon

	if (!item or !LocalPlayer():GetCharacter() or !IsValid(weapon) or LocalPlayer():GetActiveWeapon() != weapon) then
		self:Close()
		return
	end

	-- ARC9 salió del modo personalizar (p. ej. te alejaste del banco)
	if (!weapon:GetCustomize() and RealTime() > (self.openedAt or 0) + 1) then
		self:Close()
		return
	end

	if (PLUGIN:ModSignature(item, weapon) != self.sig) then self:Push() end
end

-- posición en pantalla de cada ranura sobre el arma de ARC9 (como los puntos
-- del menú de ARC9); se mandan a la página cuando cambian
function PANEL:UpdateMarkers()
	local weapon = self.weapon
	if (!self.ready or !IsValid(weapon) or !weapon.GetAttachmentPos) then return end

	local fov = weapon.WidescreenFix and weapon:WidescreenFix(weapon:GetViewModelFOV()) or weapon.ViewModelFOV
	local list = {}

	cam.Start3D(nil, nil, fov)
		for i, slot in ipairs(weapon:GetSubSlotList()) do
			if (slot.Hidden or !slot.Pos or !slot.Bone) then continue end

			local ok, pos = pcall(weapon.GetAttachmentPos, weapon, slot, false, false, true)

			if (ok and isvector(pos)) then
				local screen = pos:ToScreen()

				if (screen.visible) then
					list[#list + 1] = {k = tostring(slot.Address or i), x = math.Round(screen.x), y = math.Round(screen.y)}
				end
			end
		end
	cam.End3D()

	local json = util.TableToJSON(list)

	if (json != self.lastMarkers) then
		self.lastMarkers = json
		self.html:RunJavascript("markers(" .. json .. ")")
	end
end

function PANEL:Paint(w, h)
	if ((self.nextMarkers or 0) > RealTime()) then return end
	self.nextMarkers = RealTime() + 0.05

	self:UpdateMarkers()
end

function PANEL:StopCustomize()
	local weapon = self.weapon

	if (IsValid(weapon) and weapon.ARC9 and weapon:GetCustomize()) then
		hook.Run("StopCustomizing", LocalPlayer(), weapon)
	end
end

function PANEL:Close()
	if (self.closing) then return end
	self.closing = true

	self:StopCustomize()
	self:AlphaTo(0, 0.1, 0, function() if (IsValid(self)) then self:Remove() end end)
end

function PANEL:OnRemove()
	if (!self.closing) then self:StopCustomize() end
	if (ix.gui.efgWeaponMod == self) then ix.gui.efgWeaponMod = nil end
end

vgui.Register("efgxWeaponMod", PANEL, "EditablePanel")

function INS.OpenModding(item, weapon)
	if (!item or !IsValid(weapon) or !weapon.ARC9) then return end
	surface.PlaySound("ui/buttonclickrelease.wav")

	if (IsValid(ix.gui.efgInspect)) then ix.gui.efgInspect:Remove() end

	local panel = vgui.Create("efgxWeaponMod")
	panel:Setup(item, weapon)

	return panel
end
