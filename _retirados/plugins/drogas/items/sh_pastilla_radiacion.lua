ITEM.name = "Pastilla de Yoduro"
ITEM.weight = 0.05
ITEM.uniqueID = "pastilla_radiacion"
ITEM.model = Model("models/spec45as/stalker/items/drug_radioprotector.mdl")
ITEM.description = "Pastilla azulada sintetizada por los químicos del Metro. Durante unos minutos satura tu organismo y bloquea casi por completo la radiación que absorbes. Pasa factura a tu hambre y sed."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "radiacion")
		return true
	end
}
