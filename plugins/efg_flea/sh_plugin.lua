local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Mercadillo"
PLUGIN.author      = "EFG"
PLUGIN.description = "Mercadillo (flea market) entre jugadores: se pone a la venta un objeto con precio y cualquiera lo compra, aunque el vendedor esté desconectado."

ix.efg = ix.efg or {}
ix.efg.flea = ix.efg.flea or {}

-- Comisión del mercadillo con la fórmula de la wiki (Flea_market#Fees):
--   V0·Ti·4^PO·Q + VR·Tr·4^PR·Q
-- V0 = precio base del objeto, VR = precio pedido, PO = log10(V0/VR), PR = log10(VR/V0)
-- (cada uno elevado a 1,08 cuando la parte va por encima del valor base).
-- Con efgFleaFeeEFT desactivado se usa el porcentaje fijo de efgFleaFee.
ix.config.Add("efgFleaFeeEFT", true, "[VERIFICAR wiki: Flea_market#Fees] Usar la fórmula de comisión de EFT.", nil, {
	category = "EFG Mercadillo"
})

function ix.efg.flea.Fee(item, price, quantity)
	quantity = quantity or 1
	price = math.max(price or 0, 1)

	if (!ix.config.Get("efgFleaFeeEFT", true)) then
		return math.ceil(price * ix.config.Get("efgFleaFee", 5) / 100)
	end

	local uniqueID = istable(item) and item.uniqueID or item
	local base = (ix.traders and ix.traders.GetGlobalPrice and ix.traders.GetGlobalPrice(uniqueID))
		or (ix.item.list[uniqueID] and ix.item.list[uniqueID].price) or price
	base = math.max(tonumber(base) or price, 1)

	local Ti, Tr = 0.03, 0.03
	local PO = math.log10(base / price)
	local PR = math.log10(price / base)

	if (price < base) then PO = PO ^ 1.08 end
	if (price >= base) then PR = PR ^ 1.08 end

	return math.ceil(base * Ti * 4 ^ PO * quantity + price * Tr * 4 ^ PR * quantity)
end

ix.config.Add("efgFleaLevel", 15, "Nivel de PMC necesario para usar el mercadillo.", nil, {
	data = {min = 1, max = 60},
	category = "EFG"
})

ix.config.Add("efgFleaFee", 5, "Comisión (%) sobre el precio que paga el vendedor al publicar una oferta.", nil, {
	data = {min = 0, max = 50},
	category = "EFG"
})

ix.config.Add("efgFleaHours", 24, "Horas que dura una oferta antes de volver al vendedor.", nil, {
	data = {min = 1, max = 168},
	category = "EFG"
})

ix.config.Add("efgFleaMaxOffers", 5, "Ofertas a la vez por personaje.", nil, {
	data = {min = 1, max = 20},
	category = "EFG"
})

-- Lo que no se puede vender: contenedores seguros, objetos de misión, dinero
ix.config.Add("efgFleaRequireFIR", true, "Solo se pueden vender en el mercadillo objetos encontrados en raid (Flea_Market#Found_in_raid).", nil, {
	category = "EFG"
})

function ix.efg.flea.CanList(item)
	if (item.noLoot or item.isSecureContainer or item.uniqueID == "bala" or item.uniqueID == "rublos" or item.category == "Misión") then
		return false
	end

	-- Flea_Market: solo objetos encontrados en raid (efg_invrules, data.fir)
	if (ix.config.Get("efgFleaRequireFIR", true) and item.GetData and !item:GetData("fir")) then
		return false
	end

	return true
end

ix.command.Add("Mercadillo", {
	description = "Abre el mercadillo entre jugadores.",
	OnRun = function(self, client)
		local character = client:GetCharacter()

		if (client:InRaid()) then
			return "No puedes usar el mercadillo durante una raid."
		end

		local required = ix.config.Get("efgFleaLevel", 15)

		if (character:GetEFGLevel() < required) then
			return ("El mercadillo se desbloquea al nivel %d."):format(required)
		end

		PLUGIN:SendListings(client)
	end
})

-- ─── Mercado simulado (sv_sim.lua) ──────────────────────────────────────────
-- Vendedores y compradores simulados encima de las ofertas de los jugadores.
-- Precio = referencia del comerciante (ix.traders.GetGlobalPrice) × índice de
-- mercado del objeto (0,7 a 1,6), que sube con las compras y baja con las ventas.
ix.config.Add("efgFleaSim", true, "Mercado simulado: ofertas de vendedores simulados y compradores para las ofertas de los jugadores.", nil, {
	category = "EFG Mercadillo"
})

ix.config.Add("efgFleaSimInterval", 120, "Segundos entre cada movimiento del mercado simulado.", nil, {
	data = {min = 30, max = 1800},
	category = "EFG Mercadillo"
})

ix.config.Add("efgFleaSimOffersMin", 3, "Ofertas simuladas mínimas por objeto.", nil, {
	data = {min = 0, max = 20},
	category = "EFG Mercadillo"
})

ix.config.Add("efgFleaSimOffersMax", 8, "Ofertas simuladas máximas por objeto.", nil, {
	data = {min = 1, max = 30},
	category = "EFG Mercadillo"
})

ix.config.Add("efgFleaSimSellChance", 25, "Probabilidad (%) por movimiento de que se venda una oferta de jugador puesta al precio de mercado (más barata, más probable).", nil, {
	data = {min = 0, max = 100},
	category = "EFG Mercadillo"
})

-- Fuera del mercado simulado (además de CanList): llaves, contenedores seguros,
-- objetos de misión, dinero y lo que no tiene precio
function ix.efg.flea.CanSimulate(item)
	if (item.noLoot or item.isSecureContainer or item.isEFGKey or item.isDogtag) then return false end
	if (item.uniqueID == "bala" or item.uniqueID == "rublos") then return false end

	local category = item.category or ""
	if (category == "Misión" or category == "Objetos de misión" or category == "Llaves" or category == "Dinero") then return false end

	return true
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_sim.lua")
ix.util.Include("cl_plugin.lua")
