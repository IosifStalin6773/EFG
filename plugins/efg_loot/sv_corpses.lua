-- ============================================================================
--  Cadáver de jugador con las ranuras reales (Documento B, "réplica de
--  jugador"): en vez de una rejilla plana, el cadáver tiene
--    equip     armas equipadas, casco, chaleco, chaleco táctico, mochila,
--              ponibles y la chapa (las mochilas y los chalecos tácticos
--              conservan su contenido)
--    pockets   el resto del inventario principal, en las mismas casillas
--  Todo cae salvo ITEM.noLoot (contenedor seguro). Lo que no cabe se suelta
--  junto al cuerpo.
--
--  persistent_corpses sigue creando el ragdoll, el límite y el decaimiento.
--  loot_on_death no actúa mientras efgLootCorpseSlots esté activo.
-- ============================================================================

local LOOT = ix.efg.loot

LOOT.CORPSE_EQUIP_W, LOOT.CORPSE_EQUIP_H = 8, 8

function LOOT.HandlesPlayerCorpses()
	return ix.config.Get("efgLootCorpseSlots", true)
end

local function unequip(client, item)
	if (!item:GetData("equip")) then return end

	if (item.Unequip) then
		item:Unequip(client)
	elseif (item.RemoveOutfit) then
		item:RemoveOutfit(client)
	elseif (item.RemovePart) then
		item:RemovePart(client)
	end
end

local function moveTo(item, inventory, x, y)
	if (!x or !y) then
		x, y = inventory:FindEmptySlot(item.width, item.height, true)
	end

	if (!x or !y) then return false end

	local ok = item:Transfer(inventory:GetID(), x, y)

	if (ok) then
		-- el inventario del cadáver tiene noSave: Helix no actualiza la BD al
		-- transferir. Así el objeto deja de ser del personaje y, si nadie lo
		-- coge, PurgeOrphans lo borra al reiniciar.
		local query = mysql:Update("ix_items")
			query:Update("inventory_id", inventory:GetID())
			query:Where("item_id", item.id)
		query:Execute()
	end

	return ok
end

local function dropNear(entity, item)
	if (item.isBag) then return end

	local data = table.Copy(item.data or {})
	data.equip, data.id, data.insured = nil, nil, nil

	ix.item.Spawn(item.uniqueID, entity:GetPos() + Vector(0, 0, 24), nil, angle_zero, data)
	item:Remove()
end

-- Secciones de mochilas y chalecos tácticos del cadáver (para abrirlas)
function LOOT.AddContainerSections(entity, parentInventory)
	for _, item in ipairs(LOOT.ItemsOf({parentInventory})) do
		local bagID = item:GetData("id")
		local bag = bagID and ix.item.inventories[bagID]

		if (bag) then
			table.insert(entity.efgLoot.sections, {
				id = "bag_" .. item.id,
				label = item:GetName(),
				inventory = bag,
				nested = true,
				parentItem = item.id,
				parentInventory = parentInventory:GetID()
			})
		end
	end
end

function LOOT.BuildPlayerCorpse(client, entity, character)
	local charInventory = character:GetInventory()
	if (!charInventory) then return end

	local width, height = charInventory:GetSize()
	local pockets = LOOT.NewInventory(width, height)
	local equip = LOOT.NewInventory(LOOT.CORPSE_EQUIP_W, LOOT.CORPSE_EQUIP_H)

	local toEquip, toPockets = {}, {}

	for _, item in ipairs(LOOT.ItemsOf({charInventory})) do
		if (!item.noLoot) then
			if (item.isWeapon and item:GetData("equip")) then
				toEquip[#toEquip + 1] = item
			else
				toPockets[#toPockets + 1] = {item = item, x = item.gridX, y = item.gridY}
			end
		end
	end

	local equipInventory = ix.GetEquipInventory and ix.GetEquipInventory(character)

	if (equipInventory) then
		for _, item in ipairs(LOOT.ItemsOf({equipInventory})) do
			if (!item.noLoot) then
				toEquip[#toEquip + 1] = item
			end
		end
	end

	-- lo que persistent_corpses haya movido a su inventario plano (bDropOnDeath)
	local flat = entity.ixInventory

	if (flat) then
		for _, item in ipairs(LOOT.ItemsOf({flat})) do
			toEquip[#toEquip + 1] = item
		end
	end

	for _, item in ipairs(toEquip) do
		unequip(client, item)

		if (!moveTo(item, equip) and !moveTo(item, pockets)) then
			dropNear(entity, item)
		end
	end

	for _, entry in ipairs(toPockets) do
		unequip(client, entry.item)

		if (!moveTo(entry.item, pockets, entry.x, entry.y) and !moveTo(entry.item, pockets)
			and !moveTo(entry.item, equip)) then
			dropNear(entity, entry.item)
		end
	end

	-- el inventario plano de persistent_corpses ya está vacío: sin él, su
	-- PlayerUse y su borrado ignoran este cadáver
	if (flat) then
		ix.item.inventories[flat:GetID()] = nil
		entity.ixInventory = nil
	end

	-- la chapa va en el cuerpo (efg_economy la deja pendiente un instante)
	local tag = client.efgPendingDogtag

	if (tag) then
		client.efgPendingDogtag = nil
		LOOT.AddItem(equip, tag.uniqueID, tag.data)
	end

	entity.efgLoot = {
		kind = "player",
		name = character:GetName(),
		serial = LOOT.raidSerial,
		sections = {
			{id = "equip", labelKey = "efgLootSectionEquip", inventory = equip},
			{id = "pockets", labelKey = "efgLootSectionPockets", inventory = pockets}
		}
	}

	LOOT.AddContainerSections(entity, equip)

	entity:CallOnRemove("efgLoot", function(ragdoll)
		LOOT.ClearEntity(ragdoll)
	end)

	LOOT.Log("raid", ("raid %d · cadáver de jugador %s (%s) · %d objetos"):format(LOOT.raidSerial, character:GetName(),
		client:SteamID64() or "?", #LOOT.ItemsOf({equip, pockets})))
end

function PLUGIN:OnPlayerCorpseCreated(client, entity)
	if (!LOOT.HandlesPlayerCorpses()) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	-- después de DoPlayerDeath (el seguro ya apuntó lo asegurado) y de que
	-- persistent_corpses cree su inventario
	timer.Simple(0, function()
		if (IsValid(client) and IsValid(entity) and client:GetCharacter() == character) then
			LOOT.BuildPlayerCorpse(client, entity, character)
		end
	end)
end
