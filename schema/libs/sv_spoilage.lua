
local ROT_TICK = 10 -- segundos entre cada barrido de podredumbre

--- Resta ROT_TICK segundos a todos los ítems perecederos de un inventario dado.
local function tickInventoryPerishables(inv)
	for _, item in pairs(inv:GetItems()) do
		if (item.isPerishable and !item:GetData("spoiled", false)) then
			local remaining = item:GetData("spoilRemaining", item.spoilDuration or ix.spoilage.duration) - ROT_TICK

			if (remaining <= 0) then
				item:SetData("spoilRemaining", 0)
				item:SetData("spoiled", true)
			else
				item:SetData("spoilRemaining", remaining)
			end
		end
	end
end

--- Recorre el inventario del personaje y sus taquillas (strongbox) que ya
-- estén cargadas en memoria (se cargan al abrirlas), restando tiempo a los
-- ítems perecederos que encuentre. El propio character:GetData() expone las
-- taquillas como claves "strongbox_<lockerID>" = {id = invID, ...}.
local function tickPerishablesForCharacter(character)
	local inventories = {character:GetInventory()}

	for key, val in pairs(character:GetData()) do
		if (string.match(key, "^strongbox_%d+$") and istable(val) and val.id) then
			local boxInv = ix.item.inventories[val.id]
			if (boxInv) then
				inventories[#inventories + 1] = boxInv
			end
		end
	end

	for _, inv in ipairs(inventories) do
		if (inv) then
			tickInventoryPerishables(inv)
		end
	end
end

--- Los armarios/contenedores del mundo (ix.container, entidad "ix_container",
-- modelo cabinet_closed.mdl entre otros) no pertenecen a ningún personaje: son
-- props persistentes que existen mientras el servidor está en marcha, así que
-- su comida se pudre siempre, sin depender de que algún jugador esté conectado.
local function tickPerishablesInContainers()
	for _, container in ipairs(ents.FindByClass("ix_container")) do
		if (IsValid(container)) then
			local inv = container:GetInventory()

			if (inv) then
				tickInventoryPerishables(inv)
			end
		end
	end
end

timer.Create("ixSpoilageTick", ROT_TICK, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client)) then continue end

		local character = client:GetCharacter()
		if (character) then
			tickPerishablesForCharacter(character)
		end
	end

	tickPerishablesInContainers()
end)
