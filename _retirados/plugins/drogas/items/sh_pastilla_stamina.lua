ITEM.name = "Energizante Sintético"
ITEM.weight = 0.05
ITEM.uniqueID = "pastilla_stamina"
ITEM.model = Model("models/lostsignalproject/items/medical/stim_pack1.mdl")
ITEM.description = "Pastilla naranja que mantiene los músculos despiertos. Durante unos minutos no sientes el cansancio y tu aguante apenas se agota, a costa de tu hambre y sed."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "stamina")
		return true
	end
}
