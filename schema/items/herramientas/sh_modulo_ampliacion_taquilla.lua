ITEM.name = "Módulo de Ampliación de Taquilla"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/quest/toolkit_2.mdl")
ITEM.description = "Un conjunto de rieles y paneles reciclados para ampliar el compartimento interno de una taquilla. Instálalo mientras la tengas abierta para ganar más espacio de almacenamiento."
ITEM.category = "Herramientas"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = false

ITEM.functions.Usar = {
	name = "Instalar",
	OnRun = function(item)
		local client = item.player
		local inventory = client.ixOpenStorage

		if (!inventory or !inventory.vars or !inventory.vars.isContainer) then
			client:NotifyLocalized("strongboxNoOpen")
			return false
		end

		local success, reason = ix.strongbox.Expand(client, inventory)

		if (!success) then
			if (reason == "max") then
				client:NotifyLocalized("strongboxMaxExpanded")
			else
				client:NotifyLocalized("strongboxNoOpen")
			end

			return false
		end

		client:NotifyLocalized("strongboxExpanded")

		return true
	end
}

if (CLIENT) then
	ITEM.functions.Usar.OnCanRun = function(item)
		return IsValid(ix.gui.openedStorage)
	end
end
