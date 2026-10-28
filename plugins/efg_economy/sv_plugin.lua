local PLUGIN = PLUGIN

if (!SERVER) then return end

local ECO = ix.efg.economy

-- ─── Cambio de divisas ──────────────────────────────────────────────────────
local function countCurrency(inventory, uniqueID)
	local total, stacks = 0, {}

	for _, item in pairs(inventory:GetItems()) do
		if (item.uniqueID == uniqueID) then
			total = total + item:GetCount()
			stacks[#stacks + 1] = item
		end
	end

	return total, stacks
end

function PLUGIN:Exchange(client, currency, amount, bSell)
	local info = ECO.currencies[currency]
	if (!info) then return "Divisa no válida: usd o eur." end
	if (amount < 1 or amount > 1000000) then return "Cantidad no válida." end

	if (!ECO.FindTrader(client, info.trader)) then
		return "Tienes que estar con " .. (info.trader == "peacekeeper" and "El Agregado (Peacekeeper)" or "El Contrabandista (Skier)") .. "."
	end

	local character = client:GetCharacter()
	local inventory = character:GetInventory()
	local rate = ix.config.Get(info.rate, 140)

	if (bSell) then
		local total, stacks = countCurrency(inventory, info.item)
		if (total < amount) then return "Solo tienes " .. string.Comma(total) .. info.symbol .. "." end

		local left = amount

		for _, stack in ipairs(stacks) do
			local take = math.min(stack:GetCount(), left)
			left = left - take

			if (stack:GetCount() - take <= 0) then stack:Remove() else stack:SetData("count", stack:GetCount() - take) end
			if (left <= 0) then break end
		end

		local paid = math.floor(amount * rate * ix.config.Get("efgExchangeSellRatio", 0.9))
		character:GiveMoney(paid)

		return ("Vendidos %s%s por %s RUB."):format(string.Comma(amount), info.symbol, string.Comma(paid))
	end

	local cost = amount * rate
	if (!character:HasMoney(cost)) then return ("Necesitas %s RUB."):format(string.Comma(cost)) end

	local _, stacks = countCurrency(inventory, info.item)

	if (stacks[1]) then
		stacks[1]:SetData("count", stacks[1]:GetCount() + amount)
	elseif (!inventory:Add(info.item, 1, {count = amount})) then
		return "No tienes sitio en el inventario."
	end

	character:TakeMoney(cost)

	return ("Comprados %s%s por %s RUB."):format(string.Comma(amount), info.symbol, string.Comma(cost))
end

-- ─── Reparación en comerciante ──────────────────────────────────────────────
function PLUGIN:TraderRepair(client, item, repairerID)
	local repairer = ECO.repairers[repairerID]
	if (!repairer) then return end

	if (!ECO.FindTrader(client, repairerID)) then
		return client:Notify("Tienes que estar con " .. repairer.name .. ".")
	end

	local current, maximum, kind = ECO.GetRepairState(item)
	if (!current or current >= maximum) then return end

	local character = client:GetCharacter()
	local cost = ECO.RepairCost(item, repairerID)

	if (!character:HasMoney(cost)) then
		return client:Notify(("La reparación cuesta %s RUB."):format(string.Comma(cost)))
	end

	character:TakeMoney(cost)

	local degrade = repairer.degrade[kind]
	local newMax

	if (kind == "weapon") then
		newMax = ix.efg.weapons.Repair(item, degrade)
	else
		newMax = math.max(1, maximum - (maximum - current) * degrade)
		item:SetData("efgRepairMax", newMax)
		item:SetData("efgDurability", newMax)
	end

	client:Notify(("%s reparado por %s RUB (durabilidad %d)."):format(item:GetName(), string.Comma(cost), math.floor(newMax)))
end

-- ─── Chapas (Dogtags) ───────────────────────────────────────────────────────
-- Un PMC muerto en raid deja su chapa junto al cuerpo con quién lo mató.
function PLUGIN:DoPlayerDeath(client, attacker, dmginfo)
	local character = client:GetCharacter()
	if (!character or !(client.GetRaidSide and client:GetRaidSide() == "pmc")) then return end

	local faction = ix.faction.indices[character:GetFaction()]
	local uniqueID = (faction and faction.uniqueID == "bear") and "dogtag_bear" or "dogtag_usec"
	local weapon = IsValid(attacker) and attacker.GetActiveWeapon and attacker:GetActiveWeapon()

	local tag = {
		name = character:GetName(),
		level = character.GetEFGLevel and character:GetEFGLevel() or 1,
		killer = IsValid(attacker) and (attacker:IsPlayer() and (attacker:GetCharacter() and attacker:GetCharacter():GetName() or attacker:Name()) or attacker:GetClass()) or "?",
		weapon = IsValid(weapon) and (weapon.PrintName or weapon:GetClass()) or "?",
		date = os.date("%d/%m/%Y %H:%M")
	}

	ix.item.Spawn(uniqueID, client:GetPos() + Vector(0, 0, 20), nil, angle_zero, {tag = tag, fir = true})
end
