-- ============================================================================
--  Servidor de la ventana de saqueo (Documento B)
--    · Abrir: efg_loot llama a hook EFGLootOpen; aquí se toma el control.
--    · Buscar: cada sección (cuerpo, bolsillos, mochila...) se busca aparte.
--      Mientras dura, los objetos aparecen uno a uno como siluetas; al acabar
--      el inventario se manda entero (antes el cliente no sabe qué hay).
--    · Examinar: objeto del cuerpo que el personaje aún no conoce; usa la
--      misma lista que efg_invrules (data efgExamined).
--    · Coger y dejar: los mueve el servidor (Transfer), así el FIR lo pone
--      efg_invrules como con cualquier objeto encontrado en raid.
-- ============================================================================

local PLUGIN = PLUGIN
local LOOT = ix.efg.loot
local WIN = ix.efg.lootwin

util.AddNetworkString("efgLootWinOpen")
util.AddNetworkString("efgLootWinSections")
util.AddNetworkString("efgLootWinSearch")
util.AddNetworkString("efgLootWinSearchStart")
util.AddNetworkString("efgLootWinReveal")
util.AddNetworkString("efgLootWinSearched")
util.AddNetworkString("efgLootWinCancel")
util.AddNetworkString("efgLootWinExamine")
util.AddNetworkString("efgLootWinMove")
util.AddNetworkString("efgLootWinClose")

-- secciones que se ven sin buscar (el equipo puesto se ve a simple vista)
WIN.VISIBLE_SECTIONS = {equip = true}

local function session(client)
	local data = client.efgLootWin
	if (!data or !IsValid(data.entity) or !data.entity.efgLoot) then return end

	return data
end

local function searchedTable(entity, character)
	entity.efgLoot.searched = entity.efgLoot.searched or {}

	local key = character:GetID()
	entity.efgLoot.searched[key] = entity.efgLoot.searched[key] or {}

	-- un contenedor regenerado en otra raid se vuelve a buscar
	local serial = entity.efgLoot.serial or 0

	if (entity.efgLoot.searched[key].serial != serial) then
		entity.efgLoot.searched[key] = {serial = serial}
	end

	return entity.efgLoot.searched[key]
end

local function isSearched(entity, character, section)
	if (WIN.VISIBLE_SECTIONS[section.id]) then return true end

	-- una sección vacía no tiene nada que buscar
	if (#LOOT.ItemsOf({section.inventory}) == 0) then return true end

	return searchedTable(entity, character)[section.id] == true
end

local function inRange(client, entity)
	return IsValid(client) and IsValid(entity) and client:Alive()
		and client:GetPos():Distance(entity:GetPos()) <= LOOT.USE_DISTANCE * 1.5
end

local function giveAccess(client, inventory)
	if (!inventory.receivers) then inventory.receivers = {} end

	inventory:AddReceiver(client)
	inventory:Sync(client)
end

local function sectionMeta(client, entity, character)
	local list = {}

	for index, section in ipairs(entity.efgLoot.sections or {}) do
		if (LOOT.SectionAlive(section)) then
			local inventory = section.inventory
			local w, h = inventory:GetSize()
			local searched = isSearched(entity, character, section)

			list[#list + 1] = {
				index = index,
				id = section.id,
				label = section.labelKey and L(section.labelKey, client) or section.label or section.id,
				invID = inventory:GetID(),
				w = w,
				h = h,
				nested = section.nested or nil,
				parentItem = section.parentItem,
				state = searched and "searched" or "hidden"
			}

			if (searched and !(inventory.receivers and inventory.receivers[client])) then
				giveAccess(client, inventory)
			end
		end
	end

	return list
end

local function sendSections(client, message)
	local data = session(client)
	if (!data) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	local entity = data.entity
	local sections = sectionMeta(client, entity, character)

	data.sections = {}

	for _, meta in ipairs(sections) do
		data.sections[meta.index] = true
	end

	net.Start(message or "efgLootWinSections")
		net.WriteEntity(entity)

		if (message == "efgLootWinOpen") then
			net.WriteString(entity.efgLoot.kind or "container")
			net.WriteString(entity.efgLoot.name or (entity.efgLoot.nameKey and L(entity.efgLoot.nameKey, client)) or "")
		end

		net.WriteTable(sections)
	net.Send(client)
end

local function stopSearch(client)
	local id = client:SteamID64()

	timer.Remove("efgLootStare" .. id)
	timer.Remove("efgLootWinReveal" .. id)

	if (client.efgLootWin) then
		client.efgLootWin.searching = nil
	end
end

function WIN.Close(client, bNotify)
	local data = client.efgLootWin
	if (!data) then return end

	stopSearch(client)
	client:SetAction()

	if (IsValid(data.entity) and data.entity.efgLoot) then
		for _, section in ipairs(data.entity.efgLoot.sections or {}) do
			if (section.inventory and section.inventory.receivers) then
				section.inventory:RemoveReceiver(client)
			end
		end
	end

	client.efgLootWin = nil

	if (bNotify) then
		net.Start("efgLootWinClose")
		net.Send(client)
	end
end

-- ─── Abrir ──────────────────────────────────────────────────────────────────
function PLUGIN:EFGLootOpen(client, entity)
	if (!ix.config.Get("efgLootWindow", true)) then return end
	if (!client:GetCharacter()) then return end

	WIN.Close(client)
	ix.storage.CloseCurrent(client)

	client.efgLootWin = {entity = entity}
	sendSections(client, "efgLootWinOpen")

	return true
end

-- ─── Buscar ─────────────────────────────────────────────────────────────────
net.Receive("efgLootWinSearch", function(_, client)
	local index = net.ReadUInt(8)
	local data = session(client)
	local character = client:GetCharacter()

	if (!data or !character or data.searching or !inRange(client, data.entity)) then return end

	local entity = data.entity
	local section = entity.efgLoot.sections[index]
	if (!section or !data.sections[index] or !LOOT.SectionAlive(section)) then return end
	if (isSearched(entity, character, section)) then return end

	local inventory = section.inventory
	local items = LOOT.ItemsOf({inventory})

	table.sort(items, function(a, b)
		if ((a.gridY or 0) == (b.gridY or 0)) then return (a.gridX or 0) < (b.gridX or 0) end
		return (a.gridY or 0) < (b.gridY or 0)
	end)

	local seconds = math.max(0.5, LOOT.SearchTime(client, inventory))
	local step = seconds / (#items + 1)
	local id = client:SteamID64()

	data.searching = index
	client:SetAction("@efgLootSearching", seconds)

	net.Start("efgLootWinSearchStart")
		net.WriteUInt(index, 8)
		net.WriteFloat(seconds)
	net.Send(client)

	-- siluetas: posición y tamaño, sin decir qué es
	local revealed = 0

	timer.Create("efgLootWinReveal" .. id, step, #items, function()
		if (!IsValid(client)) then return end

		revealed = revealed + 1
		local item = items[revealed]

		if (item and item.invID == inventory:GetID()) then
			net.Start("efgLootWinReveal")
				net.WriteUInt(index, 8)
				net.WriteUInt(item.gridX or 1, 8)
				net.WriteUInt(item.gridY or 1, 8)
				net.WriteUInt(item.width or 1, 8)
				net.WriteUInt(item.height or 1, 8)
			net.Send(client)
		end
	end)

	LOOT.StareAction(client, entity, seconds, function()
		if (!IsValid(client) or client:GetCharacter() != character) then return end

		timer.Remove("efgLootWinReveal" .. id)
		data.searching = nil
		searchedTable(entity, character)[section.id] = true

		if (LOOT.SectionAlive(section)) then
			giveAccess(client, inventory)
		end

		net.Start("efgLootWinSearched")
			net.WriteUInt(index, 8)
		net.Send(client)
	end, function()
		if (!IsValid(client)) then return end

		timer.Remove("efgLootWinReveal" .. id)
		client:SetAction()

		if (client.efgLootWin) then
			client.efgLootWin.searching = nil
		end

		net.Start("efgLootWinCancel")
			net.WriteUInt(index, 8)
		net.Send(client)
	end)
end)

-- ¿está el objeto en una sección ya buscada de la sesión?
local function lootSectionOf(client, item)
	local data = session(client)
	local character = client:GetCharacter()
	if (!data or !character or !item) then return end

	for index, section in ipairs(data.entity.efgLoot.sections or {}) do
		if (section.inventory and section.inventory:GetID() == item.invID and LOOT.SectionAlive(section)) then
			if (isSearched(data.entity, character, section)) then
				return index, section
			end

			return
		end
	end
end

-- ¿es un inventario del personaje (bolsillos o una bolsa que lleva)?
local function ownInventory(character, invID)
	local inventory = ix.item.inventories[invID]
	if (!inventory) then return end

	local main = character:GetInventory()
	if (main and main:GetID() == invID) then return inventory end

	if (inventory.owner == character:GetID() and inventory.vars and inventory.vars.isBag) then
		return inventory
	end

	-- bolsas del equipo de ix_invkey
	local equip = ix.GetEquipInventory and ix.GetEquipInventory(character)

	if (equip) then
		for _, item in pairs(equip:GetItems(true)) do
			if (item:GetData("id") == invID) then
				return inventory
			end
		end
	end

	if (main) then
		for _, item in pairs(main:GetItems(true)) do
			if (item:GetData("id") == invID) then
				return inventory
			end
		end
	end
end

-- ─── Examinar ───────────────────────────────────────────────────────────────
net.Receive("efgLootWinExamine", function(_, client)
	local itemID = net.ReadUInt(32)
	local character = client:GetCharacter()
	local item = ix.item.instances[itemID]

	if (!character or !item or client.efgExamining) then return end

	local inLoot = lootSectionOf(client, item) != nil
	local inOwn = ownInventory(character, item.invID) != nil

	if (!inLoot and !inOwn) then return end

	local known = character:GetData("efgExamined", {})
	if (known[item.uniqueID]) then return end

	local seconds = ix.efg.ExamineTime and ix.efg.ExamineTime(item) or 2
	local uniqueID = item.uniqueID

	client.efgExamining = true
	client:SetAction("@efgLootWinExamining", seconds)

	timer.Create("efgLootWinExamine" .. client:SteamID64(), seconds, 1, function()
		if (!IsValid(client)) then return end

		client.efgExamining = nil

		if (client:GetCharacter() != character or !ix.item.instances[itemID]) then return end
		if (inLoot and !(session(client) and inRange(client, session(client).entity))) then return end

		local list = character:GetData("efgExamined", {})
		if (list[uniqueID]) then return end

		list[uniqueID] = true
		character:SetData("efgExamined", list)

		local current = ix.item.instances[itemID]
		hook.Run("EFGItemExamined", client, current)
		client:NotifyLocalized("efgLootWinExamined", current:GetName())
	end)
end)

-- ─── Coger y dejar ──────────────────────────────────────────────────────────
local function tryTransfer(client, item, inventory)
	local x, y = inventory:FindEmptySlot(item.width or 1, item.height or 1, true)
	if (!x or !y) then return false end

	return item:Transfer(inventory:GetID(), x, y, client) == true
end

net.Receive("efgLootWinMove", function(_, client)
	local itemID = net.ReadUInt(32)
	local toLoot = net.ReadBool()
	local targetID = net.ReadUInt(32)

	local data = session(client)
	local character = client:GetCharacter()
	local item = ix.item.instances[itemID]

	if (!data or !character or !item or !inRange(client, data.entity)) then return end
	if ((client.efgLootWinNext or 0) > CurTime()) then return end
	client.efgLootWinNext = CurTime() + 0.15

	if (!toLoot) then
		if (!lootSectionOf(client, item)) then return end

		-- destino pedido (una bolsa propia) o bolsillos, y luego las bolsas
		local targets = {}
		local wanted = targetID > 0 and ownInventory(character, targetID)

		if (wanted) then targets[#targets + 1] = wanted end

		local main = character:GetInventory()
		if (main) then targets[#targets + 1] = main end

		local equip = ix.GetEquipInventory and ix.GetEquipInventory(character)

		for _, bagItem in pairs(equip and equip:GetItems(true) or {}) do
			local bag = bagItem:GetData("id") and ix.item.inventories[bagItem:GetData("id")]
			if (bag) then targets[#targets + 1] = bag end
		end

		for _, inventory in ipairs(targets) do
			if (inventory:GetID() != item.invID and tryTransfer(client, item, inventory)) then
				LOOT.Log("raid", ("raid %d · %s coge %s de %s"):format(LOOT.raidSerial, client:Name(),
					item.uniqueID, data.entity.efgLoot.name or data.entity.efgLoot.kind or "?"))
				sendSections(client)
				return
			end
		end

		client:NotifyLocalized("efgLootNoSpace")
		return
	end

	-- dejar en el cuerpo
	if (!ownInventory(character, item.invID)) then return end

	if (item:GetData("equip")) then
		client:NotifyLocalized("efgLootWinEquipped")
		return
	end

	local order = {}
	local wanted = data.entity.efgLoot.sections[targetID]

	if (wanted) then order[#order + 1] = wanted end

	for _, section in ipairs(data.entity.efgLoot.sections or {}) do
		if (section != wanted and section.id != "equip") then
			order[#order + 1] = section
		end
	end

	for _, section in ipairs(order) do
		if (LOOT.SectionAlive(section) and isSearched(data.entity, character, section)
			and section.inventory:GetID() != item:GetData("id")
			and tryTransfer(client, item, section.inventory)) then
			-- los inventarios del cuerpo no se guardan: así el objeto deja de
			-- ser del personaje en la BD y PurgeOrphans lo borra al reiniciar
			local query = mysql:Update("ix_items")
				query:Update("inventory_id", section.inventory:GetID())
				query:Where("item_id", item.id)
			query:Execute()

			sendSections(client)
			return
		end
	end

	client:NotifyLocalized("efgLootWinNoTarget")
end)

net.Receive("efgLootWinClose", function(_, client)
	WIN.Close(client)
end)

-- ─── Cierre por distancia, muerte o desconexión ─────────────────────────────
local nextCheck = 0

function PLUGIN:Think()
	if (nextCheck > CurTime()) then return end
	nextCheck = CurTime() + 0.5

	for _, client in ipairs(player.GetAll()) do
		local data = client.efgLootWin

		if (data and (!IsValid(data.entity) or !data.entity.efgLoot or !inRange(client, data.entity))) then
			WIN.Close(client, true)
		end
	end
end

function PLUGIN:PlayerDeath(client)
	WIN.Close(client, true)
end

function PLUGIN:PlayerDisconnected(client)
	WIN.Close(client)
	timer.Remove("efgLootWinExamine" .. client:SteamID64())
end

function PLUGIN:PlayerLoadedCharacter(client)
	WIN.Close(client, true)
end
