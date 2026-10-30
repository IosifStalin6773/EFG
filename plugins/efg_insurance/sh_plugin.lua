local PLUGIN = PLUGIN

PLUGIN.name = "EFG Seguro"
PLUGIN.author = "EFG"
PLUGIN.description = "Seguro de equipo: lo asegurado que nadie se lleva vuelve al alijo un tiempo después de morir."

-- Fuente: https://escapefromtarkov.fandom.com/wiki/Insurance
-- EFT: Prapor devuelve en 24-36 h y Therapist en 12-24 h de tiempo real; aquí el
-- plazo es configurable (por defecto más corto, para un servidor de GMod).

ix.efg = ix.efg or {}
ix.efg.insurance = ix.efg.insurance or {}

ix.config.Add("efgInsurancePercent", 10, "[VERIFICAR wiki: Insurance] Coste del seguro en % del precio del objeto.", nil, {
	data = {min = 1, max = 100}, category = "EFG Seguro"
})
ix.config.Add("efgInsuranceMinutes", 30, "Minutos hasta que vuelve el equipo asegurado (EFT: 12-36 h reales).", nil, {
	data = {min = 1, max = 2880}, category = "EFG Seguro"
})

-- Aseguradoras (Insurance): Prapor más barato y más lento, Therapist más caro y rápido.
-- price = multiplicador del %, time = multiplicador de efgInsuranceMinutes.
ix.efg.insurance.insurers = {
	prapor    = {name = "Prapor", price = 1.0, time = 1.5},
	therapist = {name = "Therapist", price = 1.4, time = 1.0}
}

function ix.efg.insurance.GetPrice(item, insurer)
	local price = ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(item.uniqueID) or item.price or 0
	local mult = (ix.efg.insurance.insurers[insurer or "prapor"] or ix.efg.insurance.insurers.prapor).price

	return math.max(1, math.ceil(price * ix.config.Get("efgInsurancePercent", 10) / 100 * mult)), price
end

function ix.efg.insurance.CanInsure(item)
	local _, price = ix.efg.insurance.GetPrice(item)

	return price > 0 and !item.noLoot and !item.isSecureContainer and item.uniqueID != "bala" and item.category != "Misión"
end

function PLUGIN:InitializedPlugins()
	for _, item in pairs(ix.item.list) do
		-- el precio se comprueba al usarlo (los precios globales se cargan después)
		if (!item.noLoot and !item.isSecureContainer and item.uniqueID != "bala") then
			item.functions = item.functions or {}
			item.functions.efgInsure = {
				name = "Asegurar",
				icon = "icon16/shield.png",
				isMulti = true,
				multiOptions = function(it, client)
					local options = {}

					for id, insurer in SortedPairs(ix.efg.insurance.insurers) do
						options[#options + 1] = {name = ("%s · %s RUB"):format(insurer.name, string.Comma(ix.efg.insurance.GetPrice(it, id))), data = {id}}
					end

					return options
				end,
				OnCanRun = function(it)
					local client = it.player
					local character = IsValid(client) and client:GetCharacter()

					return ix.efg.insurance.CanInsure(it) and !IsValid(it.entity) and character != nil and !client:InRaid()
						and it:GetData("insured") != character:GetID()
				end,
				OnRun = function(it, data)
					local client = it.player
					local character = client:GetCharacter()
					local insurer = istable(data) and ix.efg.insurance.insurers[data[1]] and data[1] or "prapor"
					local cost = ix.efg.insurance.GetPrice(it, insurer)

					if (!character:HasMoney(cost)) then
						client:Notify(("El seguro cuesta %s RUB."):format(string.Comma(cost)))
						return false
					end

					character:TakeMoney(cost)
					it:SetData("insured", character:GetID())
					it:SetData("insurer", insurer)
					client:Notify(("%s asegurado con %s por %s RUB."):format(it:GetName(), ix.efg.insurance.insurers[insurer].name, string.Comma(cost)))

					return false
				end
			}
		end
	end
end

if (CLIENT) then
	hook.Add("PopulateItemTooltip", "efgInsurance.Tooltip", function(tooltip, item)
		local character = LocalPlayer():GetCharacter()
		if (!item.GetData or !character or item:GetData("insured") != character:GetID()) then return end

		local row = tooltip:AddRow("efg_insured")
		row:SetText("ASEGURADO")
		row:SetTextColor(Color(110, 170, 225))
		row:SizeToContents()
	end)
end

ix.util.Include("sv_plugin.lua")
