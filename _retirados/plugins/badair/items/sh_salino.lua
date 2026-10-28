ITEM.name = "Suero Salino"
ITEM.weight = 0.3
ITEM.model = Model("models/weapons/w_package.mdl")
ITEM.description = "Un bolso de suero salino estéril usado por los médicos del Metro para limpiar toxinas y reducir la radiación acumulada. Más efectivo que las tabletas de carbón."
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Usar = {
	OnRun = function(item)
		local client = item.player
		client.ixAntiRadRemaining = (client.ixAntiRadRemaining or 0) + 50
		client:Notify("El suero salino recorre tus venas. La radiación disminuirá progresivamente.")
		return true
	end
}
