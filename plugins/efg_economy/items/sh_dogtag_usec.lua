ITEM.name = "Chapa USEC"
ITEM.description = "Chapa de identificación de un PMC de USEC."
ITEM.model = Model("models/props_lab/box01a.mdl")
ITEM.category = "Chapas"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.01
ITEM.isDogtag = true
ITEM.price = 5000

function ITEM:GetDescription()
	local info = self:GetData("tag")
	if (!info) then return self.description end

	return ("%s\n\nNombre: %s\nNivel: %d\nMuerto por: %s\nArma: %s\nFecha: %s"):format(self.description,
		info.name or "?", info.level or 1, info.killer or "?", info.weapon or "?", info.date or "?")
end
