local PLUGIN = PLUGIN

local function isEquipInv(inv)
	return inv and inv.vars and inv.vars.isEquipment
end

function PLUGIN:InventoryItemAdded(oInv, inv, item)
	if item.base ~= 'base_metrobags' then return end

	if (isEquipInv(inv)) then
		-- Bag moved to equipment slot → equipar
		local char = inv.owner and ix.char.loaded[inv.owner]
		if not char then return end
		item:SetData('equip', true)
		local ply = char:GetPlayer()
		if IsValid(ply) then ply:AddPart(item.uniqueID, item) end
		return
	end

	-- Auto-equipar solo al recoger de fuera (mundo / otro personaje)
	if not inv.owner || (oInv && oInv.owner == inv.owner) then return end
	local char = ix.char.loaded[inv.owner]
	if not char then return end
	item:SetData('equip', true)
	char:GetPlayer():AddPart(item.uniqueID, item)
end

function PLUGIN:InventoryItemRemoved(inv, item)
	if item.base ~= 'base_metrobags' then return end
	if not inv.owner then return end
	local char = ix.char.loaded[inv.owner]
	if not char then return end

	-- Si el ítem YA está en el slot de equipo (Added dispara antes que Removed),
	-- no desequipar: la bolsa acaba de ser equipada.
	local eqInv = ix.GetEquipInventory(char)
	if (eqInv and item.invID == eqInv:GetID()) then return end

	item:SetData('equip', false)
	local ply = char:GetPlayer()
	if IsValid(ply) then ply:RemovePart(item.uniqueID) end
end

-- No se pueden usar/aplicar/equipar objetos mientras siguen dentro de una mochila:
-- hay que sacarlos primero al inventario principal. "drop" y "combine" siguen
-- permitidos porque no requieren tener el objeto "en la mano".
function PLUGIN:CanPlayerInteractItem(client, action, item, data)
	if (action == "drop" or action == "combine") then return end

	local itemTable

	if (isnumber(item)) then
		itemTable = ix.item.instances[item]
	elseif (isentity(item) and item.ixItemID) then
		itemTable = ix.item.instances[item.ixItemID]
	end

	if (!itemTable) then return end

	local inv = ix.item.inventories[itemTable.invID]

	if (inv and inv.vars and inv.vars.isBag) then
		client:Notify("Tienes que sacar el objeto de la mochila antes de usarlo.")

		return false
	end
end

function PLUGIN:CanPlayerTakeItem(client, item)
	if not item.GetItemTable then return end
	if item:GetItemTable().base == 'base_metrobags' then
		local char = client:GetCharacter()
		if not char then return end

		if char:GetPrimaryBag() then
			return false
		end
	end
end

function PLUGIN:PlayerLoadedCharacter(client, char)
	timer.Simple(0, function()
		local primaryBag = char:GetPrimaryBag()
		if primaryBag && primaryBag:GetData('equip') == true then
			client:AddPart(primaryBag.uniqueID, primaryBag)
		end
	end)
end
