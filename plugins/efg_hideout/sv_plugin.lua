local PLUGIN = PLUGIN
local hideout = ix.efg.hideout

util.AddNetworkString("ixEFGHideoutState")
util.AddNetworkString("ixEFGHideoutUpgrade")

-- Inventarios de los que se cogen los materiales: el principal y el stash
local function getSources(character)
	local sources = {character:GetInventory()}
	local stash = ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character)

	if (stash) then
		sources[#sources + 1] = stash
	end

	return sources
end

-- Cantidad de un ítem contando montones (dato "Amount" de los recursos)
local function countItem(character, uniqueID)
	local total = 0

	for _, inventory in ipairs(getSources(character)) do
		for _, item in pairs(inventory:GetItems()) do
			if (item.uniqueID == uniqueID and !item:GetData("equip")) then
				total = total + item:GetData("Amount", 1)
			end
		end
	end

	return total
end

local function takeItem(character, uniqueID, amount)
	for _, inventory in ipairs(getSources(character)) do
		for _, item in pairs(inventory:GetItems()) do
			if (amount <= 0) then return end

			if (item.uniqueID == uniqueID and !item:GetData("equip")) then
				local stack = item:GetData("Amount", 1)

				if (stack <= amount) then
					amount = amount - stack
					item:Remove()
				else
					item:SetData("Amount", stack - amount)
					amount = 0
				end
			end
		end
	end
end

-- Devuelve si se puede subir el módulo y la lista de requisitos con su estado
function hideout.CheckUpgrade(character, moduleID)
	local module = hideout.byID[moduleID]
	if (!module) then return false, {} end

	local current = hideout.GetLevel(character, moduleID)
	local nextLevel = module.levels[current + 1]
	if (!nextLevel) then return false, {} end

	local requirements = {}
	local ok = true

	local function add(text, met)
		requirements[#requirements + 1] = {text = text, met = met}
		ok = ok and met
	end

	local pmcLevel = character.GetEFGLevel and character:GetEFGLevel() or 1
	add(("Nivel de PMC %d"):format(nextLevel.level or 1), pmcLevel >= (nextLevel.level or 1))

	for otherID, level in SortedPairs(nextLevel.modules or {}) do
		add(("%s nivel %d"):format(hideout.byID[otherID].name, level), hideout.GetLevel(character, otherID) >= level)
	end

	if ((nextLevel.money or 0) > 0) then
		add(("%s RUB"):format(string.Comma(nextLevel.money)), character:GetMoney() >= nextLevel.money)
	end

	for uniqueID, amount in SortedPairs(nextLevel.items or {}) do
		local itemTable = ix.item.list[uniqueID]
		local have = countItem(character, uniqueID)

		add(("%s (%d/%d)"):format(itemTable and itemTable.name or uniqueID, math.min(have, amount), amount), have >= amount)
	end

	return ok, requirements
end

function PLUGIN:SendState(client)
	local character = client:GetCharacter()
	if (!character) then return end

	local state = {}

	for _, module in ipairs(hideout.modules) do
		local canUpgrade, requirements = hideout.CheckUpgrade(character, module.id)

		state[#state + 1] = {
			id = module.id,
			level = hideout.GetLevel(character, module.id),
			maxLevel = #module.levels,
			canUpgrade = canUpgrade,
			requirements = requirements
		}
	end

	net.Start("ixEFGHideoutState")
		net.WriteTable(state)
	net.Send(client)
end

net.Receive("ixEFGHideoutUpgrade", function(_, client)
	local moduleID = net.ReadString()
	local character = client:GetCharacter()

	if (!character or client:InRaid() or (client.ixEFGNextUpgrade or 0) > CurTime()) then return end
	client.ixEFGNextUpgrade = CurTime() + 1

	local module = hideout.byID[moduleID]
	local canUpgrade = hideout.CheckUpgrade(character, moduleID)

	if (!module or !canUpgrade) then
		client:Notify("No cumples los requisitos para mejorar ese módulo.")
		PLUGIN:SendState(client)
		return
	end

	local newLevel = hideout.GetLevel(character, moduleID) + 1
	local requirements = module.levels[newLevel]

	if ((requirements.money or 0) > 0) then
		character:TakeMoney(requirements.money)
	end

	for uniqueID, amount in pairs(requirements.items or {}) do
		takeItem(character, uniqueID, amount)
	end

	local data = table.Copy(character:GetData("efgHideout", {}) or {})
	data[moduleID] = newLevel
	character:SetData("efgHideout", data)

	client:Notify(("%s mejorado a nivel %d."):format(module.name, newLevel))
	PLUGIN:SendState(client)

	-- Expandir el alijo si se mejoró el módulo de stash
	if (moduleID == "stash" and ix.strongbox and ix.strongbox.Refresh) then
		ix.strongbox.Refresh(client)
	end
end)

-- Efectos pasivos de los módulos
function PLUGIN:EFGGetRegenMultiplier(client)
	local character = client:GetCharacter()
	if (!character) then return end

	return 1 + hideout.GetLevel(character, "rest") * 0.25 + hideout.GetLevel(character, "medstation") * 0.1
end

function PLUGIN:EFGGetScavCooldownMultiplier(client)
	local character = client:GetCharacter()
	if (!character) then return end

	return math.max(0.2, 1 - hideout.GetLevel(character, "intelligence") * 0.2)
end
