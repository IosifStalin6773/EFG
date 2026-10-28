ITEM.name = "Cóctel energético"
ITEM.weight = 0.3
ITEM.uniqueID = "coctel_energetico"
ITEM.model = Model("models/lostsignalproject/items/consumable/energy_drink.mdl")
ITEM.description = "Lata de bebida prebélica recargada con estimulantes de laboratorio. Corres más rápido durante unos minutos; cuando baja, la sed te parte la garganta."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "coctel")
		return true
	end
}
