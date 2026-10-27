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

function PLUGIN:BuildInspectPayload(item)
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

	if (kind == "weapon" and item.isARC9) then
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

	return payload
end

-- firma: si cambia (accesorios montados, equipado, objetos llevados) se repinta
function PLUGIN:InspectSignature(item)
	local sig = util.TableToJSON(item:GetData("efgMods", {})) .. tostring(item:GetData("equip"))
	local character = LocalPlayer():GetCharacter()

	if (character and kindOf(item) == "weapon") then
		for _, other in ipairs(carriedItems(character)) do
			if (other.isEFGMod) then sig = sig .. other:GetID() .. "," end
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

		net.Start("ixEFGInspectMod")
			net.WriteString("install")
			net.WriteUInt(weapon:GetID(), 32)
			net.WriteUInt(modID, 32)
		net.SendToServer()
	end)
	self.html:AddFunction("efg", "remove", function(slot)
		local weapon = item()
		if (!weapon or !isstring(slot) or !ix.efg.mods.slotNames[slot]) then return end

		net.Start("ixEFGInspectMod")
			net.WriteString("remove")
			net.WriteUInt(weapon:GetID(), 32)
			net.WriteString(slot)
		net.SendToServer()
	end)
	self.html:AddFunction("efg", "action", function(key)
		local it = item()
		if (!it or !isstring(key) or !(it.functions or {})[key]) then return end

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
	self.html:RunJavascript("render(" .. util.TableToJSON(PLUGIN:BuildInspectPayload(item)) .. ")")
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
	self:AlphaTo(0, 0.1, 0, function() if (IsValid(self)) then self:Remove() end end)
end

function PANEL:OnRemove()
	if (ix.gui.efgInspect == self) then ix.gui.efgInspect = nil end
end

vgui.Register("efgxInspectMod", PANEL, "EditablePanel")

function INS.Open(item)
	if (!item) then return end
	surface.PlaySound("ui/buttonclickrelease.wav")
	vgui.Create("efgxInspectMod"):SetItem(item)
end

-- clic derecho en la rejilla (cl_inventory.lua llama a este hook): abre la
-- ventana; con Mayús deja pasar el menú de acciones de Helix
function PLUGIN:EFGItemRightClick(icon, item)
	if (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) then return end

	INS.Open(item)
	return true
end
