local PLUGIN = PLUGIN

-- EFG: las texturas propias van en content/materials/efgui (ver efg_ui); ya no se envía el addon Metro UI.
-- resource.AddWorkshop('2969247971')

util.AddNetworkString("ixStorageSort")

-- Reempaqueta los ítems de un inventario en la rejilla: ordena por tamaño
-- (más grandes primero) agrupando ítems idénticos, y los recoloca sin huecos.
-- Sincroniza el nuevo orden a todos los espectadores y actualiza la base de datos.
local function ReorderInventory(inventory)
	-- Capturamos los ítems y su posición actual antes de tocar los slots.
	-- GetItems(true) deduplica ítems multi-celda y excluye el contenido de bolsas.
	local items = {}

	for _, item in pairs(inventory:GetItems(true)) do
		if (isnumber(item.gridX) and isnumber(item.gridY)) then
			items[#items + 1] = {item = item, oldX = item.gridX, oldY = item.gridY}
		end
	end

	table.sort(items, function(a, b)
		local ia, ib = a.item, b.item

		if (ia.height != ib.height) then return ia.height > ib.height end
		if (ia.width != ib.width) then return ia.width > ib.width end
		if (ia.uniqueID != ib.uniqueID) then return ia.uniqueID < ib.uniqueID end

		return ia.id < ib.id
	end)

	inventory.slots = {}

	local receivers = inventory:GetReceivers()

	for _, entry in ipairs(items) do
		local item = entry.item
		local x, y = inventory:FindEmptySlot(item.width, item.height, true)

		-- Si por algún motivo no cabe, lo dejamos donde estaba.
		if (!x) then
			x, y = entry.oldX, entry.oldY
		end

		item.gridX = x
		item.gridY = y

		for x2 = 0, item.width - 1 do
			for y2 = 0, item.height - 1 do
				inventory.slots[x + x2] = inventory.slots[x + x2] or {}
				inventory.slots[x + x2][y + y2] = item
			end
		end

		if (x != entry.oldX or y != entry.oldY) then
			if (!inventory.noSave) then
				local query = mysql:Update("ix_items")
					query:Update("x", x)
					query:Update("y", y)
					query:Where("item_id", item.id)
				query:Execute()
			end
		end

		-- Reposicionamos el icono en el cliente de todos los espectadores.
		if (#receivers > 0) then
			net.Start("ixInventoryMove")
				net.WriteUInt(inventory:GetID(), 32)
				net.WriteUInt(item.id, 32)
				net.WriteUInt(entry.oldX, 6)
				net.WriteUInt(entry.oldY, 6)
				net.WriteUInt(x, 6)
				net.WriteUInt(y, 6)
			net.Send(receivers)
		end
	end
end

net.Receive("ixStorageSort", function(length, client)
	if (CurTime() < (client.ixStorageSortTimer or 0)) then
		return
	end

	client.ixStorageSortTimer = CurTime() + 0.5

	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local storageID = net.ReadUInt(32)
	local inventory = client.ixOpenStorage

	if (!inventory or !inventory.storageInfo or storageID != inventory:GetID()) then
		return
	end

	if (!inventory:OnCheckAccess(client)) then
		return
	end

	ReorderInventory(inventory)
end)

function PLUGIN:AdjustCreationPayload(client, payload, newPayload)
    newPayload.creationBonus = payload.bonus_id
    newPayload.spawnPoint = payload.spawnPoint --- @field useless?

    -- Obtener la facción para poder traducir el índice numérico de vuelta al string del modelo
    local faction = ix.faction.indices[payload.faction]
    if faction and faction.models then
        newPayload.chosenModel = faction.models[payload.model] or faction.models[1]
    else
        newPayload.chosenModel = "models/error.mdl"
    end

    newPayload.chosenSkin = payload.chosenSkin
    newPayload.chosenBodygroups = pon.encode(payload.chosenBodygroups)
    newPayload.class = payload.class or 0
    newPayload.oficio = payload.oficio
end

function PLUGIN:PlayerLoadedCharacter(client, char)
    if char:GetCreationBonus() ~= 0 then
        local bonusId = char:GetCreationBonus()
        char:SetCreationBonus(0)

        local inv = char:GetInventory()

        for _, v in ipairs( self.bonuses[bonusId].items ) do
            inv:Add(v, 1)
        end
    end

    if char:GetSpawnPoint() ~= 0 then
        local pos = PLUGIN.spawns[char:GetSpawnPoint()].spawn_poses
        if not pos then return end
        if not istable(pos) && isvector(pos) then
            pos = pos
        else
            pos = pos[ math.random(#pos) ]
        end
        if not IsValid(char:GetPlayer()) then return end
        char:GetPlayer():SetPos(pos)
        char:SetChosenFaction(PLUGIN.spawns[char:GetSpawnPoint()].name)
        char:SetChosenFactionId(char:GetSpawnPoint())
        char:SetSpawnPoint(0)
    end

    local skin = char:GetChosenSkin()
    if (isnumber(skin) and skin > 0 and skin < client:SkinCount()) then
        client:SetSkin(skin)
    end

    local bgStr = char:GetChosenBodygroups()
    if (bgStr and bgStr != "[}") then
        local bodygroups = pon.decode(bgStr)
        if (istable(bodygroups)) then
            for bId, bOption in pairs(bodygroups) do
                bId = tonumber(bId) or 0
                bOption = tonumber(bOption) or 0
                if (bOption >= 0 and bOption < client:GetBodygroupCount(bId)) then
                    client:SetBodygroup(bId, bOption)
                end
            end
        end
    end
end