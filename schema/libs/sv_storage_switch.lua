if (!SERVER) then return end

--[[
	Cuando un jugador abre un almacenamiento (taquilla, cadáver, cofre) mientras
	todavía tiene otro distinto abierto, el cliente simplemente sustituye el panel
	visual (ixStorageView:Init hace ix.gui.openedStorage:Remove()) sin avisar al
	servidor. Como ix.storage.AddReceiver sobreescribe client.ixOpenStorage con el
	nuevo inventario, el servidor pierde toda referencia al anterior: su
	OnPlayerClose (que limpia cosas como entity.InUse en la taquilla) nunca se
	ejecuta, y esa taquilla/cadáver queda marcada como "en uso" para siempre,
	bloqueando a cualquier otro jugador.

	Los plugins que abren un storage (strongbox, cadáveres, cofres) deben llamar
	a esto ANTES de añadir al jugador como receptor del nuevo inventario.
]]
function ix.storage.CloseCurrent(client, inventory)
	if (IsValid(client) and client.ixOpenStorage and client.ixOpenStorage != inventory) then
		ix.storage.RemoveReceiver(client, client.ixOpenStorage)
	end
end

--[[
	Parche universal: antes de abrir CUALQUIER storage, cerramos el que el jugador
	tuviera abierto en el servidor. Así ningún inventario queda con un receptor
	fantasma que lo marque como "en uso" para siempre.

	Esto cubre también los containers core de Helix (armarios con
	models/devcon/mrp/props/cabinet_closed.mdl), cuyo ENT:OpenInventory NO llama a
	ix.storage.CloseCurrent por su cuenta: si un jugador abría un armario mientras
	tenía otro storage abierto, el anterior quedaba bloqueado y no se podía reabrir.

	Un jugador solo puede tener un panel de storage abierto a la vez
	(ix.gui.openedStorage es una única referencia), por lo que cerrar el previo
	siempre es correcto y no afecta a bMultipleUsers (que permite varios jugadores
	distintos en el MISMO inventario, no un jugador en varios).
]]
if (!ix.storage.ixOriginalOpen) then
	ix.storage.ixOriginalOpen = ix.storage.Open

	function ix.storage.Open(client, inventory, info)
		ix.storage.CloseCurrent(client, inventory)

		return ix.storage.ixOriginalOpen(client, inventory, info)
	end
end
