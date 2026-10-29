-- Ventana de inspección/modding (DHTML) que se abre con clic derecho sobre
-- un objeto de la rejilla. Mayús + clic derecho abre el menú de acciones de
-- Helix de siempre.

local PLUGIN = PLUGIN
local INS = ix.efg.inspect

local ASSET = "asset://garrysmod/materials/"
local S = function(v) return ix.efgui.Scale(v) end

local KIND_LABEL = {weapon = "Arma", ammo = "Munición", mod = "Accesorio", other = ""}

local function iconOf(item)
	local path = ix.efg.icons and ix.efg.icons.Resolve(item)
	return path and (ASSET .. path) or nil
end

local function kindOf(item)
	if (item.isARC9 or item.isWeapon) then return "weapon" end
	if (item.isAmmo) then return "ammo" end
	if (item.isEFGMod) then return "mod" end
	return "other"
end

-- todos los objetos que lleva el personaje (inventario, equipo y contenedores)
local function carriedItems(character)
	local out, seen = {}, {}
	local queue = {character:GetInventory()}

	if (ix.GetEquipInventory) then queue[#queue + 1] = ix.GetEquipInventory(character) end

	while (#queue > 0) do
		local inventory = table.remove(queue, 1)

		if (inventory and !seen[inventory:GetID()]) then
			seen[inventory:GetID()] = true

			for _, item in pairs(inventory:GetItems(true)) do
				out[#out + 1] = item

				local inner = item:GetData("id")
				if (isnumber(inner) and ix.item.inventories[inner]) then queue[#queue + 1] = ix.item.inventories[inner] end
			end
		end
	end

	return out
end

local function weaponStats(st)
	return {
		{key = "ergo",     label = "Ergonomía",            value = st.ergo,     max = 100, better = "high"},
		{key = "recoilV",  label = "Retroceso vertical",   value = st.recoilV,  max = 600, better = "low"},
		{key = "recoilH",  label = "Retroceso horizontal", value = st.recoilH,  max = 600, better = "low"},
		{key = "accuracy", label = "Precisión",            value = st.accuracy, max = 12,  better = "low", unit = "moa"},
		{key = "weight",   label = "Peso",                 value = st.weight,   max = 8,   better = "low", unit = "kg"},
	}
end

local function ammoStats(a)
	return {
		{key = "damage",   label = a.pellets and ("Daño (" .. a.pellets .. " perdigones)") or "Daño", value = a.damage, max = 150, better = "high"},
		{key = "pen",      label = "Penetración de blindaje", value = a.pen,      max = 100,  better = "high"},
		{key = "armorDmg", label = "Daño a la armadura",      value = a.armorDmg, max = 100,  better = "high", unit = "%"},
		{key = "speed",    label = "Velocidad inicial",       value = a.speed,    max = 1000, better = "high", unit = "ms"},
		{key = "frag",     label = "Fragmentación",           value = a.frag,     max = 100,  better = "high", unit = "%"},
	}
end

-- ─── Armas de arc9_support (accesorios nativos de ARC9) ─────────────────────
-- arma de ARC9 en mano para este ítem (solo si está equipada)
function PLUGIN:GetArc9Weapon(item, hint)
	if (IsValid(hint)) then return hint end
	if (!item:GetData("equip")) then return end

	local weapon = LocalPlayer():GetWeapon(item.class or "")
	return IsValid(weapon) and weapon.ARC9 and weapon or nil
end

local function attName(att)
	local tbl = ARC9 and ARC9.GetAttTable(att)
	return tbl and (tbl.CompactName or tbl.PrintName) or att
end

local function without(list, att)
	local out, removed = {}, false
	for _, a in ipairs(list) do
		if (!removed and a == att) then removed = true else out[#out + 1] = a end
	end
	return out
end

-- rellena el payload con las ranuras reales del arma de ARC9 y devuelve el
-- mapa clave -> dirección de ranura / accesorio que usan install y remove
function PLUGIN:BuildArc9Payload(item, payload, weapon, character)
	local map = {slots = {}, parts = {}}
	local installed = IsValid(weapon) and ix.arc9.GetInstalledAtts(weapon) or (item.GetPresetAtts and item:GetPresetAtts() or {})

	payload.stats = weaponStats(ix.arc9.CalcEFTStats(item, installed))
	payload.canMod = IsValid(weapon) and weapon:GetCustomize() == true

	if (IsValid(weapon)) then
		for i, slot in ipairs(weapon:GetSubSlotList()) do
			if (slot.Hidden) then continue end

			local key = tostring(i)
			local att = isstring(slot.Installed) and slot.Installed != "" and slot.Installed or nil
			map.slots[key] = slot.Address

			payload.slots[#payload.slots + 1] = {
				slot = key, label = slot.PrintName or "Ranura",
				mod = att and {uid = att, name = attName(att)} or {},
				previewRemove = att and ix.arc9.CalcEFTStats(item, without(installed, att)) or nil
			}
		end

		for _, other in ipairs(carriedItems(character)) do
			if (!other.isARC9Attachment) then continue end

			local att = other:GetAttachment()

			for i, slot in ipairs(weapon:GetSubSlotList()) do
				if (slot.Hidden or slot.Installed == att) then continue end

				local ok, can = pcall(weapon.CanAttach, weapon, slot.Address, att)

				if (ok and can) then
					local list = installed
					if (isstring(slot.Installed)) then list = without(installed, slot.Installed) end
					list = table.Copy(list)
					list[#list + 1] = att

					map.parts[other:GetID()] = {att = att, addr = slot.Address}
					payload.parts[#payload.parts + 1] = {
						id = other:GetID(), name = other:GetName(), icon = iconOf(other), slot = tostring(i),
						slotLabel = slot.PrintName or "Ranura", preview = ix.arc9.CalcEFTStats(item, list)
					}
					break
				end
			end
		end

		local ammo = weapon.GetValue and weapon:GetValue("Ammo")
		if (isstring(ammo)) then payload.info[#payload.info + 1] = {"Calibre", INS.AmmoStats(ammo).name} end
	else
		-- guardada: solo se ven los accesorios del preset
		for i, att in ipairs(installed) do
			payload.slots[#payload.slots + 1] = {slot = "p" .. i, label = ix.arc9.GetAttType(att), mod = {uid = att, name = attName(att)}}
		end
	end

	if (!IsValid(weapon)) then
		payload.note = "Usa MODIFICAR en el arma para cambiar accesorios."
	elseif (!payload.canMod) then
		payload.note = ix.config.Get("useWeaponBenches(ARC9)", false) and "Usa un banco de armas para cambiar accesorios."
			or "Pulsa la tecla de personalizar de ARC9 para cambiar accesorios."
	end

	return map
end

function PLUGIN:BuildInspectPayload(item, arc9Hint)
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local kind = kindOf(item)
	local equipped = item:GetData("equip") == true
	local inRaid = client.InRaid and client:InRaid()
	local payload = {
		item = {id = item:GetID(), name = item:GetName(), kind = kind, kindLabel = KIND_LABEL[kind], icon = iconOf(item),
			rarity = item.rarity, desc = item.GetDescription and item:GetDescription() or item.description},
		stats = {}, slots = {}, parts = {}, actions = {}, info = {},
		canMod = kind == "weapon" and !equipped and (!inRaid or ix.config.Get("efgModInRaid", false))
	}

	local arc9Map

	if (kind == "weapon" and item.isARC9Weapon and ix.arc9 and ix.arc9.CalcEFTStats) then
		arc9Map = self:BuildArc9Payload(item, payload, self:GetArc9Weapon(item, arc9Hint), character)
	elseif (kind == "weapon" and item.isARC9) then
		payload.stats = weaponStats(INS.Calc(item))

		local installed = ix.efg.mods.GetMods(item)

		for _, slot in ipairs(INS.GetSlots(item)) do
			local uid = installed[slot]
			local mod = uid and ix.item.list[uid]

			payload.slots[#payload.slots + 1] = {
				slot = slot, label = ix.efg.mods.slotNames[slot] or slot,
				mod = mod and {uid = uid, name = mod.name, icon = iconOf(mod)} or {},
				previewRemove = mod and INS.CalcWith(item, slot, nil) or nil
			}
		end

		for _, other in ipairs(carriedItems(character)) do
			if (other.isEFGMod and INS.IsCompatible(item, other)) then
				payload.parts[#payload.parts + 1] = {
					id = other:GetID(), name = other.name, icon = iconOf(other), slot = other.modSlot,
					slotLabel = ix.efg.mods.slotNames[other.modSlot] or other.modSlot,
					preview = INS.CalcWith(item, other.modSlot, other.uniqueID)
				}
			end
		end

		local caliber = item.ammoType and item.ammoType != "" and INS.AmmoStats(item.ammoType)
		if (caliber) then payload.info[#payload.info + 1] = {"Calibre", caliber.name} end

		if (equipped) then
			payload.note = "Desequipa el arma para cambiar accesorios."
		elseif (inRaid and !payload.canMod) then
			payload.note = "No puedes cambiar accesorios durante la raid."
		end
	elseif (kind == "ammo") then
		payload.ammo = INS.AmmoStats(item.ammo)
		payload.stats = ammoStats(payload.ammo)
		payload.info[#payload.info + 1] = {"Balas", tostring(item:GetData("rounds", item.ammoAmount or 0)) .. "/" .. tostring(item.ammoAmount or 0)}
	elseif (kind == "mod") then
		payload.stats = {
			{key = "ergo",     label = "Ergonomía",  value = item.ergoDelta or 0, better = "high"},
			{key = "recoil",   label = "Retroceso",  value = math.Round(((item.recoilMult or 1) - 1) * 100), better = "low", unit = "%"},
			{key = "accuracy", label = "Precisión",  value = math.Round(((item.accuracyMult or 1) - 1) * 100), better = "low", unit = "%"},
			{key = "weight",   label = "Peso",       value = item.weight or 0, max = 2, better = "low", unit = "kg"},
		}
		payload.info[#payload.info + 1] = {"Ranura", ix.efg.mods.slotNames[item.modSlot] or item.modSlot}
	else
		payload.stats = {{key = "weight", label = "Peso", value = item.weight or 0, max = 30, better = "low", unit = "kg"}}
	end

	payload.info[#payload.info + 1] = {"Tamaño", (item.width or 1) .. "x" .. (item.height or 1)}
	payload.info[#payload.info + 1] = {"Peso", ("%.2f kg"):format(item.weight or 0)}
	if (item.price) then payload.info[#payload.info + 1] = {"Precio", string.Comma(item.price) .. " ₽"} end

	-- acciones de Helix (equipar, usar, tirar...) que se pueden hacer ahora
	item.player = client

	for key, fn in SortedPairs(item.functions or {}) do
		if (key == "combine" or key == "EfgQuitarMod" or key == "EfgInstalar" or fn.isMulti) then continue end
		if (fn.OnCanRun and fn.OnCanRun(item) == false) then continue end

		local style = (key == "Equip" or key == "EquipUn" or key == "use") and "go" or (key == "drop" and "bad" or nil)
		payload.actions[#payload.actions + 1] = {key = key, name = L(fn.name or key), style = style}
	end

	item.player = nil

	return payload, arc9Map
end

-- firma: si cambia (accesorios montados, equipado, objetos llevados) se repinta
function PLUGIN:InspectSignature(item)
	-- GetData puede no devolver nada (ni nil): tostring() sin argumento falla
	local sig = (util.TableToJSON(item:GetData("efgMods", {}) or {}) or "") .. tostring(item:GetData("equip", false) or false)
	local character = LocalPlayer():GetCharacter()

	if (character and kindOf(item) == "weapon") then
		for _, other in ipairs(carriedItems(character)) do
			if (other.isEFGMod or other.isARC9Attachment) then sig = sig .. other:GetID() .. "," end
		end

		-- ARC9: accesorios montados ahora y modo personalizar
		local weapon = item.isARC9Weapon and ix.arc9 and self:GetArc9Weapon(item)
		if (IsValid(weapon)) then
			sig = sig .. table.concat(ix.arc9.GetInstalledAtts(weapon), ",") .. tostring(weapon:GetCustomize())
		end
	end

	return sig
end

-- ─── Panel ───────────────────────────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgInspect)) then ix.gui.efgInspect:Remove() end
	ix.gui.efgInspect = self

	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.12)

	self.html = self:Add("DHTML")
	self.html:SetAllowLua(false)

	local function item() return self.itemID and ix.item.instances[self.itemID] end

	self.html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	self.html:AddFunction("efg", "close", function() self:Close() end)
	self.html:AddFunction("efg", "install", function(modID)
		local weapon = item()
		modID = tonumber(modID)
		if (!weapon or !modID) then return end

		-- ARC9 nativo: Attach en el cliente; ARC9 manda el arma al servidor y
		-- arc9_support quita el ítem del accesorio del inventario
		if (self.arc9Map) then
			local part = self.arc9Map.parts[modID]
			local swep = PLUGIN:GetArc9Weapon(weapon, self.arc9Weapon)
			if (part and IsValid(swep) and swep:GetCustomize()) then swep:Attach(part.addr, part.att) end
			return
		end

		net.Start("ixEFGInspectMod")
			net.WriteString("install")
			net.WriteUInt(weapon:GetID(), 32)
			net.WriteUInt(modID, 32)
		net.SendToServer()
	end)
	self.html:AddFunction("efg", "remove", function(slot)
		local weapon = item()
		if (!weapon or !isstring(slot)) then return end

		if (self.arc9Map) then
			local addr = self.arc9Map.slots[slot]
			local swep = PLUGIN:GetArc9Weapon(weapon, self.arc9Weapon)
			if (addr != nil and IsValid(swep) and swep:GetCustomize()) then swep:Detach(addr) end
			return
		end

		if (!ix.efg.mods.slotNames[slot]) then return end

		net.Start("ixEFGInspectMod")
			net.WriteString("remove")
			net.WriteUInt(weapon:GetID(), 32)
			net.WriteString(slot)
		net.SendToServer()
	end)
	self.html:AddFunction("efg", "action", function(key)
		local it = item()
		local fn = it and isstring(key) and (it.functions or {})[key]
		if (!fn) then return end

		-- igual que el menú de Helix: OnClick va en el cliente y, si devuelve
		-- false (p. ej. "Ver" de las mochilas), no se manda nada al servidor
		if (fn.OnClick) then
			it.player = LocalPlayer()
			local ok, result = pcall(fn.OnClick, it)
			it.player = nil

			if (!ok) then ErrorNoHalt("[EFG] " .. tostring(result) .. "\n") return end
			if (result == false) then
				if (key == "View") then self:Close() end
				return
			end
		end

		net.Start("ixInventoryAction")
			net.WriteString(key)
			net.WriteUInt(it:GetID(), 32)
			net.WriteUInt(it.invID or 0, 32)
			net.WriteTable({})
		net.SendToServer()

		if (key == "drop" or key == "use") then self:Close() end
	end)

	self.html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	self.html:SetHTML(ix.efgui.InjectCSS(PLUGIN.inspectHTML))
end

function PANEL:SetItem(item)
	self.itemID = item:GetID()
	self:Push()
end

function PANEL:Push()
	local item = self.itemID and ix.item.instances[self.itemID]
	if (!self.ready or !item) then return end

	self.sig = PLUGIN:InspectSignature(item)

	local payload, arc9Map = PLUGIN:BuildInspectPayload(item, self.arc9Weapon)
	self.arc9Map = arc9Map
	self.html:RunJavascript("render(" .. util.TableToJSON(payload) .. ")")
end

function PANEL:PerformLayout(w, h)
	local pw, ph = math.min(w - S(40), S(1180)), math.min(h - S(40), S(700))
	self.html:SetSize(pw, ph)
	self.html:SetPos((w - pw) / 2, (h - ph) / 2)
end

function PANEL:Think()
	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.3

	local item = self.itemID and ix.item.instances[self.itemID]
	if (!item or !LocalPlayer():GetCharacter()) then self:Close() return end

	-- abierta desde el banco o la tecla de personalizar: si ARC9 sale del modo
	-- personalizar (p. ej. te alejas del banco), se cierra
	local weapon = self.arc9Weapon
	if (self.fromCustomize and (!IsValid(weapon) or (!weapon:GetCustomize() and RealTime() > (self.openedAt or 0) + 1))) then
		self:Close()
		return
	end

	if (PLUGIN:InspectSignature(item) != self.sig) then self:Push() end
end

-- fondo modal oscuro; clic fuera de la ventana = cerrar
function PANEL:Paint(w, h)
	ix.util.DrawBlur(self, 4)
	surface.SetDrawColor(0, 0, 0, 190)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:OnMousePressed()
	self:Close()
end

function PANEL:Close()
	if (self.closing) then return end
	self.closing = true

	-- sale del modo personalizar de ARC9 (también en el servidor)
	local weapon = self.arc9Weapon
	if (IsValid(weapon) and weapon.ARC9 and weapon:GetCustomize()) then
		hook.Run("StopCustomizing", LocalPlayer(), weapon)
	end

	self:AlphaTo(0, 0.1, 0, function() if (IsValid(self)) then self:Remove() end end)
end

function PANEL:OnRemove()
	if (ix.gui.efgInspect == self) then ix.gui.efgInspect = nil end
end

vgui.Register("efgxInspectMod", PANEL, "EditablePanel")

-- weapon: arma de ARC9 en modo personalizar (banco o tecla de ARC9)
function INS.Open(item, weapon)
	if (!item) then return end
	surface.PlaySound("ui/buttonclickrelease.wav")

	local panel = vgui.Create("efgxInspectMod")

	if (IsValid(weapon)) then
		panel.arc9Weapon = weapon
		panel.fromCustomize = true
		panel.openedAt = RealTime()
	end

	panel:SetItem(item)
	return panel
end

-- clic derecho en la rejilla (cl_inventory.lua llama a este hook): abre la
-- ventana; con Mayús deja pasar el menú de acciones de Helix
function PLUGIN:EFGItemRightClick(icon, item)
	if (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) then return end

	INS.Open(item)
	return true
end
