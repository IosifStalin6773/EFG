-- Transfers all inventory items to the corpse on death.
-- Items with ITEM.noLoot = true are kept in the character inventory.
-- Uses timer.Simple(0) to run after persistent_corpses has already moved bDropOnDeath items.
function PLUGIN:OnPlayerCorpseCreated(client, entity)
	if (!client:GetCharacter()) then return end

	timer.Simple(0, function()
		if (!IsValid(entity) or !IsValid(client)) then return end

		local character = client:GetCharacter()
		if (!character) then return end

		local charInventory = character:GetInventory()
		if (!charInventory) then return end

		local corpseInventory = entity.ixInventory

		-- create corpse inventory if persistent_corpses didn't (e.g. dropItemsOnDeath disabled)
		-- +2 filas extra para que quepa también el equipo (uniforme/mochila).
		if (!corpseInventory) then
			local width, height = charInventory:GetSize()
			corpseInventory = ix.inventory.Create(width, height + 2, ix.NextCorpseInventoryID and ix.NextCorpseInventoryID() or -os.time())
			corpseInventory.noSave = true
			entity.ixInventory = corpseInventory
			client:SetLocalVar("ragdoll", entity:EntIndex())
		end

		-- collect first to avoid modifying slots while iterating.
		-- cada entrada guarda las coords destino: para el inv principal se preservan
		-- (el cadáver tiene su mismo tamaño); para el equipo se auto-colocan (nil)
		-- porque las coords del inv de equipo 4×4 colisionarían con el principal.
		local toTransfer = {}

		for _, slot in pairs(charInventory.slots) do
			for _, item in pairs(slot) do
				if (!item.noLoot) then
					toTransfer[#toTransfer + 1] = {item = item, x = item.gridX, y = item.gridY}
				end
			end
		end

		-- el uniforme y la mochila viven en el inventario de equipo (ix_equipinv),
		-- no en el principal: hay que recorrerlo aparte para que también se looteen.
		-- El contenido de la mochila va con ella (es un sub-inventario del ítem).
		local equipInventory = ix.GetEquipInventory and ix.GetEquipInventory(character)
		if (equipInventory) then
			for _, slot in pairs(equipInventory.slots) do
				for _, item in pairs(slot) do
					if (!item.noLoot) then
						toTransfer[#toTransfer + 1] = {item = item}
					end
				end
			end
		end

		for _, entry in ipairs(toTransfer) do
			local item = entry.item

			-- desequipar antes de mover: el uniforme restablece el modelo (RemoveOutfit);
			-- la mochila se desequipa sola vía el hook InventoryItemRemoved de metrobags
			-- al salir del inventario de equipo.
			if (item:GetData("equip")) then
				if (item.Unequip) then
					item:Unequip(client)
				elseif (item.RemoveOutfit) then
					item:RemoveOutfit(client)
				end
			end

			local ok = item:Transfer(corpseInventory:GetID(), entry.x, entry.y)

			if (ok) then
				-- El inventario del cadáver tiene noSave = true, así que Helix no actualiza
				-- la BD al transferir. Sin este UPDATE, el ítem sigue apuntando al inventario
				-- del personaje y reaparece al reconectar.
				local query = mysql:Update("ix_items")
					query:Update("inventory_id", 0)
					query:Where("item_id", item.id)
				query:Execute()
			elseif (!item.isBag) then
				-- no cabe en el cadáver: se suelta junto a él y se borra del personaje
				-- (antes se marcaba inventory_id = 0 igualmente: duplicado o pérdida)
				local data = table.Copy(item.data or {})
				data.equip, data.id, data.insured = nil, nil, nil

				ix.item.Spawn(item.uniqueID, entity:GetPos() + Vector(0, 0, 24), nil, angle_zero, data)
				item:Remove()
			end
		end
	end)
end
