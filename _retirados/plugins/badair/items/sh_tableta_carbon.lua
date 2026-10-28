ITEM.name = "Tableta de Carbón"
ITEM.weight = 0.05
ITEM.model = Model("models/spec45as/stalker/items/antirad.mdl")
ITEM.description = "Pastillas de carbón activado usadas en el Metro para filtrar toxinas del sistema digestivo. Reduce 25 puntos de radiación progresivamente."
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Usar = {
	OnRun = function(item)
		local client = item.player
		client.ixAntiRadRemaining = (client.ixAntiRadRemaining or 0) + 25
		client:Notify("Has tomado una tableta de carbón. Sientes un ligero alivio de la contaminación.")
		return true
	end
}
