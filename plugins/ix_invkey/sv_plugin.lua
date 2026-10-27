if (not SERVER) then return end

util.AddNetworkString("ixInvSaveDesc")
util.AddNetworkString("ixInvSaveSkin")
util.AddNetworkString("ixHotbarUpdate")
util.AddNetworkString("ixBGPresetSave")
util.AddNetworkString("ixEquipToSlot")
util.AddNetworkString("ixUnequipSlot")
util.AddNetworkString("ixSelectWeapon")
util.AddNetworkString("ixStaffToolGive")

net.Receive("ixSelectWeapon", function(len, client)
	local class = net.ReadString()
	if (not IsValid(client) or not client:Alive()) then return end
	if (not client:HasWeapon(class)) then return end
	client:SelectWeapon(class)
end)

local STAFF_TOOLS = {
	[1] = "weapon_physgun",
	[2] = "gmod_tool",
}

net.Receive("ixStaffToolGive", function(len, client)
	if (not IsValid(client) or not client:Alive() or not client:IsAdmin()) then return end
	local class = STAFF_TOOLS[net.ReadUInt(2)]
	if (not class or client:HasWeapon(class)) then return end
	client:Give(class)
end)

net.Receive("ixBGPresetSave", function(len, client)
	local slot = net.ReadUInt(8)
	local groups = net.ReadTable()
	local skin = net.ReadUInt(8)
	if (slot < 1 or slot > 3) then return end
	local char = client:GetCharacter()
	if (not char) then return end
	local presets = char:GetData("bgPresets", {})
	local clean = {}
	for k, v in pairs(groups) do
		clean[tonumber(k) or 0] = tonumber(v) or 0
	end
	presets[slot] = {groups = clean, skin = math.Clamp(math.floor(skin), 0, 255)}
	char:SetData("bgPresets", presets)
	char:Save()
end)

net.Receive("ixInvSaveDesc", function(len, client)
	local text = net.ReadString()
	if (type(text) != "string") then return end
	local char = client:GetCharacter()
	if (not char) then return end
	text = text:sub(1, 1000)
	if (char.SetDescription) then char:SetDescription(text)
	elseif (char.SetDesc) then char:SetDesc(text) end
end)

net.Receive("ixInvSaveSkin", function(len, client)
	local skinIndex = net.ReadUInt(8)
	local char = client:GetCharacter()
	if (not char) then return end
	skinIndex = math.Clamp(math.floor(skinIndex), 0, 255)
	client:SetSkin(skinIndex)
	char:SetData("skin", skinIndex)
	char:Save()
end)

net.Receive("ixHotbarUpdate", function(len, client)
	local slot   = net.ReadUInt(8)
	local itemID = net.ReadUInt(32)
	if (slot < 1 or slot > 5) then return end
	local char = client:GetCharacter()
	if (not char) then return end
	local hotbar = char:GetData("hotbar", {})

	if (itemID == 0) then
		hotbar[slot] = nil
	else
		local item = ix.item.instances[itemID]
		if (not item) then return end

		-- máximo 2 armas primarias en el acceso rápido
		if (item.isWeapon and item.weaponCategory == "primary") then
			local primCount = 0
			for s, id in pairs(hotbar) do
				if (s != slot) then
					local other = ix.item.instances[id]
					if (other and other.weaponCategory == "primary") then
						primCount = primCount + 1
					end
				end
			end
			if (primCount >= 2) then return end
		end

		hotbar[slot] = itemID
	end

	char:SetData("hotbar", hotbar)
end)

-- ─── Inventario de equipo ────────────────────────────────────────────────────

local function ensureEquipInv(client, char)
	if (not IsValid(client) or not char) then return end
	local id = char:GetData("equipInvID")

	if (id and ix.item.inventories[id]) then
		local inv = ix.item.inventories[id]
		inv.vars.isEquipment = true
		inv.vars.isBag = nil
		inv:SetOwner(char:GetID(), true)
		inv:AddReceiver(client)
		inv:Sync(client)
		return
	end

	if (id) then
		ix.inventory.Restore(id, ix.EQUIP_INV_W, ix.EQUIP_INV_H, function(inv)
			inv.vars.isEquipment = true
			inv.vars.isBag = nil
			inv:SetOwner(char:GetID(), true)
			inv:AddReceiver(client)
			inv:Sync(client)
		end)
	else
		ix.inventory.New(char:GetID(), "ix_equipinv", function(inv)
			char:SetData("equipInvID", inv:GetID())
			inv.vars.isEquipment = true
			inv.vars.isBag = nil
			inv:AddReceiver(client)
			inv:Sync(client)
		end)
	end
end

function PLUGIN:CanTransferItem(item, oldInv, newInv)
	if (newInv and newInv.vars and newInv.vars.isEquipment and not item._ixEquipMove) then
		return false
	end
end

-- Devuelve true si el ítem está en el inventario principal o en una bolsa/rig
-- que el jugador lleva encima (no en el stash).
local function isCarried(item, char)
	local mainInv = char:GetInventory()
	if (not mainInv) then return false end
	if (item.invID == mainInv:GetID()) then return true end
	-- buscar en bolsas/rigs equipados
	local eqInv = ix.GetEquipInventory(char)
	if (not eqInv) then return false end
	for _, carried in pairs(eqInv:GetItems()) do
		local bagID = carried:GetData("id")
		if (bagID and item.invID == bagID) then return true end
	end
	return false
end

-- Función pública usable por otros plugins (ej. efg_gear para wearables)
function ix.EquipToSlot(client, item)
	local char = client:GetCharacter()
	if (not char or not item) then return end

	if (not isCarried(item, char)) then
		client:Notify("Solo puedes equipar objetos que llevas encima.")
		return
	end

	local eqInv = ix.GetEquipInventory(char)
	if (not eqInv) then client:Notify("Inventario de equipo no disponible, reconecta.") return end

	local kind = ix.GetEquipSlotKind(item)
	if (not kind) then return end

	-- una sola pieza por ranura
	for _, it in pairs(eqInv:GetItems()) do
		if (ix.GetEquipSlotKind(it) == kind) then
			client:Notify("Ya llevas " .. (ix.EQUIP_SLOT_NAMES[kind] or kind) .. " equipado.")
			return
		end
	end

	-- Chaleco / casco: disparar equip del outfit
	if (item.outfitCategory and item.functions and item.functions.Equip) then
		item.player = client
		if (not item:GetData("equip")) then
			item.functions.Equip.OnRun(item)
		end
		if (not item:GetData("equip")) then
			item.player = nil
			client:Notify("No se pudo equipar el " .. (ix.EQUIP_SLOT_NAMES[kind] or kind) .. ".")
			return
		end
		item.player = nil
	end

	item._ixEquipMove = true
	local ok, err = pcall(function() item:Transfer(eqInv:GetID(), nil, nil, client) end)
	item._ixEquipMove = nil
	if (not ok) then
		ErrorNoHalt("[ixEquip] Transfer falló para " .. tostring(item.uniqueID) .. ": " .. tostring(err) .. "\n")
	end
end

net.Receive("ixEquipToSlot", function(len, client)
	local item = ix.item.instances[net.ReadUInt(32)]
	if (not item) then return end
	ix.EquipToSlot(client, item)
end)

net.Receive("ixUnequipSlot", function(len, client)
	local itemID = net.ReadUInt(32)
	local char = client:GetCharacter()
	if (not char) then return end
	local item = ix.item.instances[itemID]
	if (not item) then return end

	local eqInv = ix.GetEquipInventory(char)
	if (not eqInv or item.invID != eqInv:GetID()) then return end
	local mainInv = char:GetInventory()
	if (not mainInv) then return end

	item.player = client
	if (item.outfitCategory and item:GetData("equip") and item.RemoveOutfit) then
		item:RemoveOutfit(client)
	end
	item:Transfer(mainInv:GetID(), nil, nil, client)
	item.player = nil
end)

-- ─── Contenedores equipados fuera de los bolsillos ───────────────────────────
-- Mochilas, chalecos tácticos y contenedores seguros no deben ocupar celdas del
-- inventario principal. Si uno acaba ahí marcado como equipado (recogida con
-- autoequipado, equipado desde el menú de Helix, o un traslado que falló) o es
-- un contenedor seguro, se pasa a su ranura de equipo si está libre.
local containerKinds = {backpack = true, rig = true, secure = true}

local function wantsSlot(item)
	local kind = ix.GetEquipSlotKind(item)
	if (not kind or not containerKinds[kind]) then return end
	if (item.isSecureContainer or item:GetData("equip")) then return kind end
end

local function slotFree(eqInv, kind)
	for _, it in pairs(eqInv:GetItems()) do
		if (ix.GetEquipSlotKind(it) == kind) then return false end
	end
	return true
end

local function settleContainers(client, char)
	if (not IsValid(client) or client:GetCharacter() != char) then return end

	local mainInv = char:GetInventory()
	local eqInv = ix.GetEquipInventory(char)
	if (not mainInv or not eqInv) then return end

	for _, item in pairs(mainInv:GetItems()) do
		local kind = wantsSlot(item)

		if (kind and slotFree(eqInv, kind)) then
			ix.EquipToSlot(client, item)
		elseif (kind and item:GetData("equip") and not item.isSecureContainer) then
			-- ranura ocupada: queda como objeto normal en los bolsillos
			item:SetData("equip", false)
		end
	end
end

ix.SettleEquippedContainers = settleContainers

function PLUGIN:InventoryItemAdded(oldInv, inv, item)
	if (not inv or not inv.owner or (inv.vars and (inv.vars.isEquipment or inv.vars.isBag))) then return end

	local char = ix.char.loaded[inv.owner]
	if (not char or char:GetInventory() != inv) then return end

	-- después del resto de hooks (metrobags marca equip al recoger)
	timer.Simple(0, function()
		if (item.invID == inv:GetID() and wantsSlot(item)) then
			settleContainers(char:GetPlayer(), char)
		end
	end)
end

function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()
	if (not IsValid(client)) then return end

	local skin = character:GetData("skin", nil)
	if (skin != nil) then client:SetSkin(skin) end

	timer.Simple(0.5, function()
		if (IsValid(client) and client:GetCharacter() == character) then
			ensureEquipInv(client, character)
			-- el inventario de equipo puede restaurarse de forma asíncrona
			timer.Simple(1.5, function() settleContainers(client, character) end)
		end
	end)
end
