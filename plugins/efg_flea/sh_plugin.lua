local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Mercadillo"
PLUGIN.author      = "EFG"
PLUGIN.description = "Mercadillo (flea market) entre jugadores: se pone a la venta un objeto con precio y cualquiera lo compra, aunque el vendedor esté desconectado."

ix.efg = ix.efg or {}
ix.efg.flea = ix.efg.flea or {}

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
function ix.efg.flea.CanList(item)
	return !(item.noLoot or item.isSecureContainer or item.uniqueID == "bala" or item.category == "Misión")
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

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
