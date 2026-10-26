-- inv:GetItems() de Helix ya funde el contenido de cualquier mochila que
-- encuentre dentro (ver META:GetItems en core/meta/sh_inventory.lua), así que
-- basta con sumar cada inventario una vez; sumarlo aparte lo contaría dos veces.
local function sumInventoryWeight(inv)
	local weight = 0
	if (!inv) then return weight end

	for _, item in pairs(inv:GetItems()) do
		if (item:GetWeight()) then
			weight = weight + item:GetWeight()
		end
	end

	return weight
end

function ix.weight.CalculateWeight(character) -- Calculates the total weight of all items a character is carrying.
	local inventory = character:GetInventory()
	if (!inventory) then return 0 end

	local weight = sumInventoryWeight(inventory)

	-- La mochila equipada en el slot de equipo (fuera del inventario principal)
	-- vive en un inventario aparte; su propio GetItems() ya suma su contenido.
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)
	if (eqInv) then
		weight = weight + sumInventoryWeight(eqInv)
	end

	return weight
end

function ix.weight.Recalculate(character)
	if (!character) then return end

	local weight = ix.weight.CalculateWeight(character)
	character:SetData("carry", weight)
end

util.AddNetworkString("ixWeightRecalculate")

net.Receive("ixWeightRecalculate", function(len, client)
	if (!IsValid(client)) then return end
	if ((client.ixWeightRecalcCD or 0) > CurTime()) then return end
	client.ixWeightRecalcCD = CurTime() + 2

	local character = client:GetCharacter()
	if (!character) then return end

	ix.weight.Recalculate(character)
end)

function PLUGIN:CharacterLoaded(character)
	ix.weight.Recalculate(character)
end

function PLUGIN:CanTransferItem(item, old, inv) -- When a player attempts to take an item out of a container.
	if (inv.owner and item:GetWeight() and (old and old.owner != inv.owner)) then
		local character = ix.char.loaded[inv.owner]
		local client = character:GetPlayer()

		if (IsValid(client) and client:IsAdmin() and !old.owner) then
			return
		end

		if (!character:CanCarry(item)) then
			client:Notify("Llevas demasiado peso encima para coger eso.")
			return false
		end
	end
end

function PLUGIN:OnItemTransferred(item, old, new)
	if (item:GetWeight()) then
		if (old.owner) then
			local oldChar = ix.char.loaded[old.owner]
			if (oldChar) then
				ix.weight.Recalculate(oldChar)
			end
		end

		if (new.owner) then
			local newChar = ix.char.loaded[new.owner]
			if (newChar) then
				ix.weight.Recalculate(newChar)
			end
		end
	end
end

function PLUGIN:InventoryItemAdded(old, new, item)
	if (item:GetWeight()) then
		if (!old and new.owner) then
			local character = ix.char.loaded[new.owner]
			if (character) then
				ix.weight.Recalculate(character)
			end
		end
	end
end

function PLUGIN:InventoryItemRemoved(inventory, item)
	if (inventory.owner and item:GetWeight()) then
		local character = ix.char.loaded[inventory.owner]
		if (character) then
			ix.weight.Recalculate(character)
		end
	end
end

function PLUGIN:CanPlayerTakeItem(client, item)
	local character = client:GetCharacter()
	if (!character) then return end

	local itm = item:GetItemTable()

	if (itm:GetWeight()) then
		if (!character:CanCarry(itm)) then
			client:Notify("Llevas demasiado peso encima para recoger eso.")
			return false
		end
	end
end

-- EFT-style footstep noise increase when overweight.
-- Emits the same sound louder and suppresses the default footstep.
function PLUGIN:PlayerFootstep(client, pos, foot, sound, volume, filter)
	local character = client:GetCharacter()
	if (!character) then return end

	local carry = character:GetData("carry", 0)
	local maxW = character.GetMaxWeight and character:GetMaxWeight() or ix.config.Get("maxWeight", 30)

	if (carry <= maxW) then return end

	local over = carry - maxW
	local maxOver = math.max(ix.config.Get("maxOverWeight", 30), 1)
	local frac = math.Clamp(over / maxOver, 0, 1)
	local newVol = math.Clamp(volume * (1 + frac * 0.6), 0, 1)

	client:EmitSound(sound, 75, 100, newVol, CHAN_BODY)
	return true
end

-- EFT-style speed reduction when overweight.
-- Also runs on client for prediction (sh_plugin includes sv_plugin on SERVER only,
-- so this SERVER hook fires after the client-side PLUGIN:SetupMove set by cl_plugin).
function PLUGIN:SetupMove(client, mv, cmd)
	local character = client:GetCharacter()
	if (!character) then return end

	local carry = character:GetData("carry", 0)
	local maxW = character.GetMaxWeight and character:GetMaxWeight() or ix.config.Get("maxWeight", 30)

	if (carry <= maxW) then return end

	local over = carry - maxW
	local maxOver = math.max(ix.config.Get("maxOverWeight", 30), 1)
	local frac = math.Clamp(over / maxOver, 0, 1)
	local mult = math.Clamp(1 - frac * 0.55, 0.25, 1)

	mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
	mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
end
