ITEM.name = "Pastilla extraña"
ITEM.weight = 0.05
ITEM.uniqueID = "pastilla_mareo"
ITEM.model = Model("models/lostsignalproject/items/medical/caffeine.mdl")
ITEM.description = "Mejora todos tus atributos durante unos minutos, pero a costa de tu hambre y sed."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "mareo")
		return true
	end
}
