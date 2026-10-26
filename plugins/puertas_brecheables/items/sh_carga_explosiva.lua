ITEM.name = "Carga Explosiva"
ITEM.description = "Carga demoledora artesanal. Colócala en una puerta brecha y aléjate: detona en 10 segundos."
ITEM.model = Model("models/Weapons/w_c4.mdl") -- Requiere CS:S; cambiar si no está montado
ITEM.category = "Equipamiento"
ITEM.width = 2
ITEM.height = 1

ITEM.functions.Colocar = {
	label = "Colocar",
	OnRun = function(item)
		local client = item.player
		if (!IsValid(client)) then return false end

		local trace = client:GetEyeTrace()
		local ent = trace.Entity

		if (!IsValid(ent)) then
			client:Notify("No hay una puerta válida frente a ti.")
			return false
		end

		local plugin = ix.plugin.list["puertas_brecheables"]
		if (!plugin) then return false end

		local success, err = plugin:PlaceExplosive(client, ent)
		if (!success) then
			client:Notify(err or "No puedes colocar el explosivo aquí.")
			return false
		end

		return true
	end
}
