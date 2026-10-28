ITEM.name = "Musculoso"
ITEM.weight = 0.1
ITEM.uniqueID = "musculoso"
ITEM.model = Model("models/props_lab/jar01c.mdl")
ITEM.description = "Vodka, sangre de mutante y químicos en un frasco sin etiqueta. Los porteadores del metro juran por él: cargas el doble sin notarlo, y luego te desplomas de hambre."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "musculoso")
		return true
	end
}
