local PLUGIN = PLUGIN

if (!SERVER) then return end

local INV = ix.efg.inv

util.AddNetworkString("ixEFGRotate")
util.AddNetworkString("ixEFGRotated")
util.AddNetworkString("ixEFGRotateMove")
util.AddNetworkString("ixEFGRotMoved")

-- ─── Rotación ────────────────────────────────────────────────────────────────
net.Receive("ixEFGRotate", function(_, client)
	if ((client.efgRotateNext or 0) > CurTime()) then return end
	client.efgRotateNext = CurTime() + 0.15

	local character = client:GetCharacter()
	local item = ix.item.instances[net.ReadUInt(32)]
	local inventory = item and ix.item.inventories[item.invID]

	if (!character or !inventory or inventory.owner != character:GetID()) then return end
	if (inventory.vars and inventory.vars.isEquipment) then return end
	if (item.width == item.height) then return end

	local x, y = item.gridX, item.gridY
	if (!x or !y) then return end

	local w, h = item.height, item.width -- tamaño girado

	if (y + h - 1 > inventory.h or !inventory:CanItemFit(x, y, w, h, item)) then
		client:Notify("No hay sitio para girarlo.")
		return
	end

	item:SetData("rot", !INV.IsRotated(item) or nil)
	INV.ApplyFootprint(inventory, item, x, y, item.width, item.height)

	net.Start("ixEFGRotated")
		net.WriteUInt(item.id, 32)
		net.WriteUInt(inventory:GetID(), 32)
	net.Send(client)
end)

-- Girar y mover a la vez (R mientras se arrastra en efg_invgrid): itemID,
-- inventario destino, x, y y si queda girado.
local function canAccess(client, character, inventory)
	return inventory and ((inventory.owner and inventory.owner == character:GetID()) or inventory:OnCheckAccess(client))
end

net.Receive("ixEFGRotateMove", function(_, client)
	if ((client.efgRotateNext or 0) > CurTime()) then return end
	client.efgRotateNext = CurTime() + 0.15

	local character = client:GetCharacter()
	local item = ix.item.instances[net.ReadUInt(32)]
	local newInv = ix.item.inventories[net.ReadUInt(32)]
	local x, y, rot = net.ReadUInt(6), net.ReadUInt(6), net.ReadBool()
	local oldInv = item and ix.item.inventories[item.invID]

	if (!character or !oldInv or !newInv or item.width == item.height) then return end
	if (!canAccess(client, character, oldInv) or !canAccess(client, character, newInv)) then return end
	if ((oldInv.vars and oldInv.vars.isEquipment) or (newInv.vars and newInv.vars.isEquipment)) then return end
	if (!item.gridX or INV.IsRotated(item) == rot) then return end

	local stock = ix.item.list[item.uniqueID]
	local w, h = rot and stock.height or stock.width, rot and stock.width or stock.height

	if (x < 1 or y < 1 or x + w - 1 > newInv.w or y + h - 1 > newInv.h) then return end

	if (oldInv == newInv) then
		if (!newInv:CanItemFit(x, y, w, h, item)) then return end

		item:SetData("rot", rot or nil)
		INV.ApplyFootprint(newInv, item, x, y, w, h)
		item.gridX, item.gridY = x, y

		if (!newInv.noSave) then
			local query = mysql:Update("ix_items")
				query:Update("x", x)
				query:Update("y", y)
				query:Where("item_id", item.id)
			query:Execute()
		end

		local receivers = newInv:GetReceivers()

		net.Start("ixEFGRotMoved")
			net.WriteUInt(item.id, 32)
			net.WriteUInt(newInv:GetID(), 32)
			net.WriteUInt(x, 6)
			net.WriteUInt(y, 6)
		net.Send(istable(receivers) and receivers or client)

		return
	end

	-- a otro inventario: se gira y se transfiere; si no entra, se deshace el giro
	local previous = item:GetData("rot")
	item:SetData("rot", rot or nil)

	local ok, err = item:Transfer(newInv:GetID(), x, y, client)

	if (!ok) then
		item:SetData("rot", previous)
		client:NotifyLocalized(err or "unknownError")
	end
end)

-- ─── Found in raid ───────────────────────────────────────────────────────────
-- Found_in_raid: lo que se recoge durante la raid (suelo, contenedores, cuerpos)
-- queda marcado. Lo que se lleva al entrar no.
local function ownerOf(inventory)
	local character = inventory and inventory.owner and ix.char.loaded[inventory.owner]

	return character, character and character:GetPlayer()
end

function PLUGIN:OnItemTransferred(item, curInv, newInv)
	local character, client = ownerOf(newInv)
	if (!IsValid(client) or !(client.InRaid and client:InRaid())) then return end

	local oldCharacter = ownerOf(curInv)
	if (oldCharacter and oldCharacter == character) then return end

	if (!item:GetData("fir")) then
		-- el valor es la marca de la raid, para quitarlo si acaba en Run Through
		item:SetData("fir", client.efgRaidTag or true)
	end
end

function PLUGIN:EFGRaidStarted(client)
	client.efgRaidTag = os.time()
end

-- Raid#Run_Through: lo recogido en esa raid no cuenta como encontrado en raid
function PLUGIN:EFGRaidEnded(client, side, reason, runThrough)
	local tag = client.efgRaidTag
	client.efgRaidTag = nil

	local character = client:GetCharacter()
	if (!runThrough or !tag or !character) then return end

	for _, inventory in pairs(ix.item.inventories) do
		if (inventory.owner == character:GetID()) then
			for _, item in pairs(inventory:GetItems(true)) do
				if (item:GetData("fir") == tag) then item:SetData("fir", nil) end
			end
		end
	end
end

-- Secure_containers: al morir, lo del contenedor seguro pierde el FIR
function PLUGIN:PlayerDeath(client)
	local character = client:GetCharacter()
	if (!character) then return end

	for _, inventory in pairs(ix.item.inventories) do
		local containerID = INV.GetContainerID(inventory)
		local stock = containerID and ix.item.list[containerID]

		if (stock and stock.isSecureContainer and inventory.owner == character:GetID()) then
			for _, item in pairs(inventory:GetItems()) do
				if (item:GetData("fir")) then item:SetData("fir", nil) end
			end
		end
	end
end

-- ─── Examinar (Examine) ─────────────────────────────────────────────────────
function PLUGIN:Examine(client, item)
	local character = client:GetCharacter()
	if (!character or client.efgExamining) then return end

	local seconds = ix.efg.ExamineTime(item)
	local itemID, uniqueID = item.id, item.uniqueID

	client.efgExamining = true
	client:SetAction("Examinando…", seconds)

	timer.Simple(seconds, function()
		if (!IsValid(client)) then return end

		client.efgExamining = nil

		local current = ix.item.instances[itemID]
		if (!current or current:GetOwner() != client or client:GetCharacter() != character) then return end

		local known = character:GetData("efgExamined", {})
		if (known[uniqueID]) then return end

		known[uniqueID] = true
		character:SetData("efgExamined", known)

		hook.Run("EFGItemExamined", client, current)
		client:Notify("Examinado: " .. current:GetName())
	end)
end

-- ─── Tiempo de búsqueda en contenedores y cuerpos (Searching) ──────────────
-- Envuelve ix.storage.Open: la primera vez que un jugador abre un contenedor
-- tarda según cuántos objetos hay (EFT revela el contenido poco a poco).
ix.config.Add("efgSearchBase", 1.5, "Segundos base de búsqueda al abrir por primera vez un contenedor o un cuerpo.", nil, {
	data = {min = 0, max = 10, decimals = 1}, category = "EFG Inventario"
})
ix.config.Add("efgSearchPerItem", 0.35, "Segundos de búsqueda por cada objeto del contenedor.", nil, {
	data = {min = 0, max = 3, decimals = 2}, category = "EFG Inventario"
})

hook.Add("InitializedPlugins", "efgInvrules.SearchTime", function()
	if (!ix.storage or !ix.storage.Open or ix.storage.efgWrapped) then return end

	ix.storage.efgWrapped = true
	local open = ix.storage.Open

	ix.storage.Open = function(client, inventory, info)
		info = info or {}

		local entity = info.entity

		if (IsValid(client) and IsValid(entity) and !info.searchTime and inventory and inventory.GetItems) then
			entity.efgSearched = entity.efgSearched or {}

			if (!entity.efgSearched[client]) then
				local count = table.Count(inventory:GetItems())
				local mult = hook.Run("EFGGetSearchMultiplier", client) or 1
				local seconds = (ix.config.Get("efgSearchBase", 1.5) + count * ix.config.Get("efgSearchPerItem", 0.35)) * mult

				if (seconds > 0.2) then
					info.searchTime = seconds
					info.searchText = "Buscando…"
				end

				entity.efgSearched[client] = true
			end
		end

		return open(client, inventory, info)
	end
end)
