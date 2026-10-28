ITEM.name = "Estimulante de Combate"
ITEM.weight = 0.05
ITEM.uniqueID = "pastilla_velocidad"
ITEM.model = Model("models/lostsignalproject/items/medical/stim_pack3.mdl")
ITEM.description = "Cóctel químico que dispara la adrenalina. Durante unos minutos te mueves notablemente más rápido, pero quema tus reservas de comida y bebida."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "velocidad")
		return true
	end
}
