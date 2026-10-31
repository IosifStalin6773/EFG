-- Bolsillos de los chalecos tácticos. Cada chaleco tiene una sola rejilla de
-- Helix y ITEM.efgPockets = {{ancho, alto, cantidad}, ...}. Los bolsillos se
-- colocan de izquierda a derecha en filas de ROW_W columnas; las casillas que
-- no son de ningún bolsillo quedan bloqueadas y un objeto no puede ocupar
-- casillas de dos bolsillos.
ix.efg = ix.efg or {}
ix.efg.rig = ix.efg.rig or {}

local RIG = ix.efg.rig
local ROW_W = 8

RIG.cache = RIG.cache or {}

-- {w, h, cells[x][y] = bolsillo, pockets = {{x, y, w, h}, ...}}
-- Acepta el uniqueID o la tabla del objeto (en OnRegistered aún no está en la lista)
function RIG.Layout(item)
	local stock = istable(item) and item or ix.item.list[item or ""]
	local uniqueID = stock and stock.uniqueID
	if (!uniqueID) then return end
	if (RIG.cache[uniqueID]) then return RIG.cache[uniqueID] end

	local spec = stock.efgPockets
	if (!spec) then return end

	local layout = {cells = {}, pockets = {}, w = 0, h = 0}
	local x, y, rowH = 1, 1, 0

	for _, entry in ipairs(spec) do
		local pw, ph = entry[1], entry[2]

		for _ = 1, entry[3] or 1 do
			if (x > 1 and x + pw - 1 > ROW_W) then
				x, y, rowH = 1, y + rowH, 0
			end

			local index = #layout.pockets + 1
			layout.pockets[index] = {x = x, y = y, w = pw, h = ph}

			for cx = x, x + pw - 1 do
				layout.cells[cx] = layout.cells[cx] or {}

				for cy = y, y + ph - 1 do
					layout.cells[cx][cy] = index
				end
			end

			layout.w = math.max(layout.w, x + pw - 1)
			rowH = math.max(rowH, ph)
			x = x + pw
		end
	end

	layout.h = y + rowH - 1
	RIG.cache[uniqueID] = layout

	return layout
end

-- uniqueID del chaleco dueño de un inventario, o nil
function RIG.ForInventory(inv)
	if (!inv or !inv.GetID) then return end

	if (inv.vars and inv.vars.efgRig) then return inv.vars.efgRig end
	if (inv.efgRigUID) then return inv.efgRigUID end
	if (inv.efgRigNext and CurTime() < inv.efgRigNext) then return end

	local id = inv:GetID()

	for _, item in pairs(ix.item.instances) do
		if (item.efgPockets and item.data and item.data.id == id) then
			inv.efgRigUID = item.uniqueID
			return item.uniqueID
		end
	end

	-- no es de un chaleco; en el cliente el chaleco puede llegar después que
	-- su rejilla, así que se vuelve a mirar al cabo de un rato
	inv.efgRigNext = CurTime() + (SERVER and 30 or 2)
end

-- ¿puede un rectángulo w x h en (x, y) ir en ese inventario? (solo bolsillos)
function RIG.Fits(inv, x, y, w, h)
	local uniqueID = RIG.ForInventory(inv)
	local layout = uniqueID and RIG.Layout(uniqueID)
	if (!layout) then return true end

	local pocket = layout.cells[x] and layout.cells[x][y]
	if (!pocket) then return false end

	for cx = x, x + w - 1 do
		for cy = y, y + h - 1 do
			if (!layout.cells[cx] or layout.cells[cx][cy] != pocket) then return false end
		end
	end

	return true
end

-- Helix (Add, Transfer, FindEmptySlot) y efg_invrules pasan por CanItemFit
local META = ix.meta.inventory

if (META and !RIG.originalCanItemFit) then
	RIG.originalCanItemFit = META.CanItemFit

	function META:CanItemFit(x, y, w, h, item2)
		if (!RIG.Fits(self, x, y, w, h)) then return false end

		return RIG.originalCanItemFit(self, x, y, w, h, item2)
	end
end
