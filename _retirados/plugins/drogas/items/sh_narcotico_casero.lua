ITEM.name = "Narcótico casero"
ITEM.weight = 0.1
ITEM.uniqueID = "narcotico_casero"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "Pasta turbia de setas de túnel maceradas en químicos. Adormece el dolor hasta hacerte olvidar que sangras, al precio de ver el mundo entre nieblas."
ITEM.category = "Drogas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Tomar = {
	OnRun = function(item)
		local client = item.player
		ix.drogas.Apply(client, "narcotico")
		return true
	end
}
