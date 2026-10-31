-- Redirige la ventana de almacenamiento de Helix (ixStorageView) a la versión estilo EFT.
-- Se envuelve vgui.Create una sola vez; si la config está apagada o el panel no existe,
-- se usa la ventana clásica sin cambios.
if (not ix.efg.lootui.wrapped) then
	ix.efg.lootui.wrapped = true

	local create = vgui.Create

	function vgui.Create(name, parent, ...)
		if (name == "ixStorageView" and ix.config.Get("efgLootUI", true)
			and vgui.GetControlTable("efgxLootView")) then
			name = "efgxLootView"
		end

		return create(name, parent, ...)
	end
end
