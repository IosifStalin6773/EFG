local PLUGIN = PLUGIN

PLUGIN.name = "EFG Economía"
PLUGIN.author = "EFG"
PLUGIN.description = "Dólares y euros con cambio en Peacekeeper y Skier, reparación en Prapor y Mechanic, chapas (dogtags) y surtido de EFT para los comerciantes."

-- Fuentes (wiki de EFT): Dollars, Euros, Repair, Dogtags, cada página de comerciante.
-- [VERIFICAR] Tipos de cambio y coeficientes de reparación de memoria.

ix.efg = ix.efg or {}
ix.efg.economy = ix.efg.economy or {}

local ECO = ix.efg.economy

ix.config.Add("efgUSDRate", 140, "[VERIFICAR] Rublos por dólar al comprar en Peacekeeper.", nil, {
	data = {min = 1, max = 1000}, category = "EFG Economía"
})
ix.config.Add("efgEURRate", 155, "[VERIFICAR] Rublos por euro al comprar en Skier.", nil, {
	data = {min = 1, max = 1000}, category = "EFG Economía"
})
ix.config.Add("efgExchangeSellRatio", 0.9, "Parte del tipo de cambio que te pagan al vender divisas.", nil, {
	data = {min = 0.1, max = 1, decimals = 2}, category = "EFG Economía"
})

ECO.currencies = {
	usd = {item = "dolares", trader = "peacekeeper", rate = "efgUSDRate", symbol = "$"},
	eur = {item = "euros", trader = "skier", rate = "efgEURRate", symbol = "€"}
}

-- Reparación en comerciantes (Repair): coste por punto de durabilidad (en % del
-- precio del objeto) y parte de lo que faltaba que se pierde de durabilidad máxima.
ECO.repairers = {
	prapor   = {name = "Prapor", cost = 0.006, degrade = {weapon = 0.15, armor = 0.20}},
	mechanic = {name = "Mechanic",   cost = 0.009, degrade = {weapon = 0.06, armor = 0.10}}
}

-- Comerciante de esa clave al alcance del jugador
function ECO.FindTrader(client, factionKey)
	for _, entity in ipairs(ents.FindByClass("ix_trader")) do
		if (entity:GetNetVar("factionKey") == factionKey and ix.traders.CanReach(client, entity)) then
			return entity
		end
	end
end

local function itemPrice(item)
	return (ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(item.uniqueID)) or item.price or 10000
end

-- {actual, máximo, tipo} de un objeto reparable
function ECO.GetRepairState(item)
	local WEP = ix.efg.weapons

	if (WEP and WEP.IsFirearm(item)) then
		return WEP.GetDurability(item), WEP.GetMaxDurability(item), "weapon", 100
	end

	if (item.isEFGArmor) then
		return item:GetEFGDurability(), item:GetEFGMaxDurability(), "armor", item.efgMaxDurability
	end
end

function ECO.RepairCost(item, repairer)
	local current, maximum, _, base = ECO.GetRepairState(item)
	if (!current) then return 0 end

	local missing = (maximum - current) / math.max(base, 1) * 100
	return math.max(1, math.ceil(missing * itemPrice(item) * ECO.repairers[repairer].cost))
end

-- Divisas: un objeto con data count (como los rublos)
local function setupCurrency(item)
	function item:GetCount()
		return self:GetData("count", 1)
	end

	function item:GetDescription()
		return ("%s\n\nCantidad: %s %s"):format(self.description, string.Comma(self:GetCount()), ECO.currencies[self.efgCurrency].symbol)
	end

	if (CLIENT) then
		function item:PaintOver(it, w, h)
			draw.SimpleText(string.Comma(it:GetCount()), "DermaDefault", w - 3, h - 3, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	item.functions.combine = {
		OnRun = function(it, data)
			local other = ix.item.instances[data[1]]
			if (!other or other == it or other.uniqueID != it.uniqueID) then return false end

			it:SetData("count", it:GetCount() + other:GetCount())
			other:Remove()

			return false
		end,
		OnCanRun = function(it, data)
			local other = data and ix.item.instances[data[1]]
			return !IsValid(it.entity) and other != nil and other != it and other.uniqueID == it.uniqueID
		end
	}
end

function PLUGIN:InitializedPlugins()
	for _, item in pairs(ix.item.list) do
		if (item.efgCurrency) then
			setupCurrency(item)
		end

		local repairable = item.isEFGArmor or (ix.efg.weapons and ix.efg.weapons.IsFirearm(item))

		if (repairable) then
			item.functions = item.functions or {}
			item.functions.efgTraderRepair = {
				name = "Reparar en comerciante",
				icon = "icon16/wrench_orange.png",
				isMulti = true,
				multiOptions = function(it, client)
					local options = {}

					for id, repairer in SortedPairs(ECO.repairers) do
						options[#options + 1] = {name = ("%s · %s RUB"):format(repairer.name, string.Comma(ECO.RepairCost(it, id))), data = {id}}
					end

					return options
				end,
				OnCanRun = function(it)
					local current, maximum = ECO.GetRepairState(it)
					return !IsValid(it.entity) and IsValid(it.player) and current != nil and current < maximum
						and !(it.player.InRaid and it.player:InRaid())
				end,
				OnRun = function(it, data)
					if (SERVER) then
						PLUGIN:TraderRepair(it.player, it, istable(data) and data[1])
					end

					return false
				end
			}
		end
	end

	-- surtido de EFT (solo para comerciantes nuevos; los ya creados se ajustan con /TraderAdmin)
	if (ix.traders and ix.traders.defaultStock) then
		for factionKey, entries in pairs(ECO.extraStock) do
			local stock = ix.traders.defaultStock[factionKey]

			if (stock) then
				for _, entry in ipairs(entries) do
					local itemTable = ix.item.list[entry[1]]

					if (itemTable) then
						-- la munición se vende por cajas (ammoAmount balas): la cantidad viene en balas
						local qty = itemTable.isAmmo and math.max(1, math.ceil(entry[2] / itemTable.ammoAmount)) or entry[2]
						stock[#stock + 1] = {entry[1], qty, entry[3], entry[4] or itemTable.price}
					end
				end
			end
		end

		local categories = ix.traders.buyCategories

		if (categories and categories.therapist) then
			table.insert(categories.therapist, "Estimulantes")
		end
	end
end

ix.command.Add("Cambio", {
	description = "Compra o vende divisas con el comerciante: /Cambio usd|eur <cantidad> [vender].",
	arguments = {ix.type.string, ix.type.number, bit.bor(ix.type.string, ix.type.optional)},
	OnRun = function(self, client, currency, amount, mode)
		return PLUGIN:Exchange(client, currency:lower(), math.floor(amount), mode == "vender")
	end
})

ix.util.Include("sh_stock.lua")
ix.util.Include("sv_plugin.lua")
