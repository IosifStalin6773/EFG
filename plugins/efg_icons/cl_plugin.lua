local cache = {}
local warned = {}

-- Material cacheado del icono 2D de un ítem, o nil (entonces se usa el modelo 3D).
function ix.efg.icons.Get(item)
	if (!item) then return end

	local id = item.uniqueID

	if (cache[id] == nil) then
		local path = ix.efg.icons.Resolve(item)
		local mat = path and Material(path, "smooth mips")

		if (mat and !mat:IsError()) then
			cache[id] = mat
		else
			cache[id] = false

			if (item.iconMaterial and !warned[id]) then
				warned[id] = true
				MsgC(Color(232, 197, 71), ("[efg_icons] Falta el icono de %s: %s\n"):format(id, item.iconMaterial))
			end
		end
	end

	return cache[id] or nil
end

-- Dibuja el icono ajustado al rectángulo sin deformarlo. Devuelve false si el
-- ítem no tiene icono 2D.
function ix.efg.icons.Draw(item, x, y, w, h)
	local mat = ix.efg.icons.Get(item)
	if (!mat) then return false end

	local tw, th = mat:Width(), mat:Height()
	local scale = math.min(w / math.max(tw, 1), h / math.max(th, 1))
	local dw, dh = tw * scale, th * scale

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(math.floor(x + (w - dw) / 2), math.floor(y + (h - dh) / 2), math.floor(dw), math.floor(dh))

	return true
end

function ix.efg.icons.Reset()
	cache = {}
	warned = {}
end

-- Al cambiar de mapa o recargar se vuelven a buscar los archivos.
hook.Add("InitPostEntity", "efg_icons.Reset", ix.efg.icons.Reset)
