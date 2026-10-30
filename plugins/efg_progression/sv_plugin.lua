local PLUGIN = PLUGIN

if (!SERVER) then return end

local function giveXP(client, amount, kind)
	local raids = ix.plugin.Get("efg_raids")
	local character = IsValid(client) and client:GetCharacter()

	if (raids and character and amount >= 1) then
		raids:GiveXP(character, math.floor(amount), kind)
	end
end

-- Examinar un objeto nuevo (efg_invrules)
function PLUGIN:EFGItemExamined(client, item)
	local cfg = ix.efg.actionXP.examine
	local price = item.price or 1000

	giveXP(client, math.Clamp(math.log10(math.max(price, 10)) * 4, cfg.min, cfg.max), "loot")
end

-- Botear: primer objeto de cada tipo que coges en una raid
function PLUGIN:OnItemTransferred(item, oldInv, newInv)
	local character = newInv and newInv.owner and ix.char.loaded[newInv.owner]
	local client = character and character:GetPlayer()

	if (!IsValid(client) or !client:InRaid() or oldInv and oldInv.owner == newInv.owner) then return end

	client.efgLooted = client.efgLooted or {}

	if (!client.efgLooted[item.id]) then
		client.efgLooted[item.id] = true
		giveXP(client, ix.efg.actionXP.loot, "loot")
	end
end

-- Curar (EFG: botiquines y medicinas avisan con OnCuracionRealizada)
function PLUGIN:EFGHealed(client, amount)
	client.efgHealAcc = (client.efgHealAcc or 0) + amount * ix.efg.actionXP.heal

	if (client.efgHealAcc >= 1) then
		local whole = math.floor(client.efgHealAcc)
		client.efgHealAcc = client.efgHealAcc - whole
		giveXP(client, whole, "heal")
	end
end

function PLUGIN:EFGRaidEnded(client)
	client.efgLooted = nil
end
