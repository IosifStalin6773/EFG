ix.efg = ix.efg or {}

if (SERVER) then
	-- Las descargas (resource.AddFile / AddWorkshop) solo sirven a jugadores que
	-- entran a un servidor dedicado. En una partida local el contenido ya está en
	-- el disco, y recorrer content/ con file.Find (que busca en cada addon
	-- montado) y llenar la tabla de descargas alarga "Cargando recursos".
	local contenidoLocal = CreateConVar("efg_contenido_local", "0", FCVAR_ARCHIVE,
		"1 = registrar las descargas de EFG también en partidas locales (amigos sin el contenido).")

	function ix.efg.SendContent()
		return game.IsDedicated() or contenidoLocal:GetBool()
	end
end
