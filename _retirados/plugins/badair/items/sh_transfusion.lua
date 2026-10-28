ITEM.name = "Transfusión de Sangre"
ITEM.weight = 0.5
ITEM.model = Model("models/fallout 3/blood_pack.mdl")
ITEM.description = "Una bolsa de sangre compatible O+. Procedimiento arriesgado pero extraordinariamente efectivo para eliminar la radiación del organismo. Recurso escasísimo en el Metro."
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 2
ITEM.noBusiness = false

ITEM.functions.Usar = {
	OnRun = function(item)
		local client = item.player
		client.ixAntiRadRemaining = (client.ixAntiRadRemaining or 0) + 75
		client:Notify("La transfusión purifica tu sangre de la radiación. Notarás la mejora en los próximos segundos.")
		return true
	end
}
