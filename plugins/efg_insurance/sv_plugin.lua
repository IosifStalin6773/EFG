local PLUGIN = PLUGIN

if (!SERVER) then return end

-- Al morir en raid se apuntan los objetos asegurados que llevaba (antes de que
-- loot_on_death los pase al cadáver).
function PLUGIN:DoPlayerDeath(client)
	local character = client:GetCharacter()
	if (!character or !(client.InRaid and client:InRaid())) then return end

	local charID = character:GetID()
	local list = {}

	for _, inventory in pairs(ix.item.inventories) do
		local containerID = inventory.vars and isstring(inventory.vars.isBag) and inventory.vars.isBag
		local secure = containerID and ix.item.list[containerID] and ix.item.list[containerID].isSecureContainer

		if (inventory.owner == charID and !secure) then
			for _, item in pairs(inventory:GetItems(true)) do
				if (item:GetData("insured") == charID and !item.noLoot) then
					local data = table.Copy(item.data or {})
					data.insured, data.equip, data.id, data.fir, data.rot = nil, nil, nil, nil, nil

					list[#list + 1] = {id = item.id, uniqueID = item.uniqueID, data = data}
				end
			end
		end
	end

	if (#list == 0) then return end

	local pending = character:GetData("efgInsurance", {})
	pending[#pending + 1] = {ready = os.time() + ix.config.Get("efgInsuranceMinutes", 30) * 60, items = list}
	character:SetData("efgInsurance", pending)
end

-- ¿Se lo ha quedado otro personaje?
local function takenByOther(itemID, charID)
	local item = ix.item.instances[itemID]
	local inventory = item and ix.item.inventories[item.invID]
	local owner = inventory and inventory.owner

	return owner != nil and owner != charID
end

local function deliver(client, character)
	local pending = character:GetData("efgInsurance")
	if (!istable(pending) or #pending == 0 or client:InRaid()) then return end

	local stash = ix.strongbox and ix.strongbox.GetStash(character)
	if (!stash) then return end

	local now, keep, returned, lost = os.time(), {}, 0, 0

	for _, entry in ipairs(pending) do
		if (entry.ready > now) then
			keep[#keep + 1] = entry
		else
			local left = {}

			for _, info in ipairs(entry.items) do
				if (takenByOther(info.id, character:GetID())) then
					lost = lost + 1
				elseif (stash:Add(info.uniqueID, 1, info.data)) then
					local old = ix.item.instances[info.id]
					if (old and old.invID != stash:GetID()) then old:Remove() end

					returned = returned + 1
				else
					left[#left + 1] = info -- alijo lleno: se reintenta
				end
			end

			if (#left > 0) then
				entry.items = left
				keep[#keep + 1] = entry
			end
		end
	end

	character:SetData("efgInsurance", #keep > 0 and keep or nil)

	if (returned > 0) then
		client:Notify(("Seguro: %d objeto(s) devueltos a tu alijo."):format(returned))
	end

	if (lost > 0) then
		client:Notify(("Seguro: %d objeto(s) no han vuelto, alguien se los llevó."):format(lost))
	end
end

local nextCheck = 0

function PLUGIN:Think()
	if (nextCheck > CurTime()) then return end
	nextCheck = CurTime() + 30

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and client:Alive()) then
			deliver(client, character)
		end
	end
end
