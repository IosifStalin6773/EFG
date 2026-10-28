-- ============================================================
--  guia_via  |  sv_plugin.lua  (SERVER)
--  Persistencia de tramos y creación de los muros físicos invisibles.
-- ============================================================

util.AddNetworkString("GuiaVia_SendList")

-- ============================================================
--  Persistencia
-- ============================================================

function PLUGIN:LoadData()
	ix.guiavia.segments = self:GetData({})

	-- Igual que traders/tablon_encargos: diferir un frame para asegurar que
	-- el mapa esté completamente cargado antes de spawnear los muros.
	timer.Simple(1, function()
		for id, seg in pairs(ix.guiavia.segments) do
			ix.guiavia.SpawnWalls(id, seg)
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(ix.guiavia.segments)
end

-- ============================================================
--  Muros físicos
-- ============================================================

ix.guiavia.spawned = ix.guiavia.spawned or {} -- [id] = {ent1, ent2}

-- Crea (o recrea) las 2 paredes invisibles de un tramo a partir de sus datos guardados
function ix.guiavia.SpawnWalls(id, seg)
	ix.guiavia.RemoveWalls(id)

	local startPos = Vector(seg.startPos.x, seg.startPos.y, seg.startPos.z)
	local endPos = Vector(seg.endPos.x, seg.endPos.y, seg.endPos.z)
	local width = seg.width or ix.guiavia.defaultWidth

	local dir = endPos - startPos
	local length = dir:Length()
	if (length < 1) then return end
	dir:Normalize()

	local ang = dir:Angle()
	local perp = dir:Cross(vector_up)
	perp:Normalize()

	local center = (startPos + endPos) / 2
	local halfLen = length / 2
	local halfThick = ix.guiavia.wallThickness / 2

	local walls = {}
	for _, side in ipairs({1, -1}) do
		local wallCenter = center + perp * (width / 2) * side

		local ent = ents.Create("ix_guia_muro")
		if (IsValid(ent)) then
			ent:SetPos(wallCenter)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:SetupSize(halfLen, halfThick, ix.guiavia.wallHeight)
			ent.guiaviaID = id

			walls[#walls + 1] = ent
		end
	end

	-- Losa de suelo invisible: su superficie queda a la altura del rail (recta
	-- entre startPos y endPos, inclinada si hay pendiente), para que la dresina
	-- ruede por encima del escombro/bulto real del mapa en vez de sobre él.
	local floorEnt = ents.Create("ix_guia_muro")
	if (IsValid(floorEnt)) then
		floorEnt:SetPos(center)
		floorEnt:SetAngles(ang)
		floorEnt:Spawn()
		floorEnt:SetupFloor(halfLen, width / 2, ix.guiavia.floorThickness)
		floorEnt.guiaviaID = id

		walls[#walls + 1] = floorEnt
	end

	ix.guiavia.spawned[id] = walls
end

function ix.guiavia.RemoveWalls(id)
	local walls = ix.guiavia.spawned[id]
	if (!walls) then return end

	for _, ent in ipairs(walls) do
		if (IsValid(ent)) then ent:Remove() end
	end

	ix.guiavia.spawned[id] = nil
end

-- Siguiente ID libre (recalculado, para no depender de un contador persistido)
local function NextFreeID()
	local maxID = 0
	for id in pairs(ix.guiavia.segments) do
		if (id > maxID) then maxID = id end
	end
	return maxID + 1
end

function ix.guiavia.CreateSegment(startPos, endPos, width)
	local id = NextFreeID()

	local seg = {
		startPos = {x = startPos.x, y = startPos.y, z = startPos.z},
		endPos = {x = endPos.x, y = endPos.y, z = endPos.z},
		width = width,
	}

	ix.guiavia.segments[id] = seg
	ix.guiavia.SpawnWalls(id, seg)

	local plugin = ix.plugin.Get("guia_via")
	if (plugin) then plugin:SaveData() end

	return id
end

function ix.guiavia.RemoveSegment(id)
	if (!ix.guiavia.segments[id]) then return false end

	ix.guiavia.RemoveWalls(id)
	ix.guiavia.segments[id] = nil

	local plugin = ix.plugin.Get("guia_via")
	if (plugin) then plugin:SaveData() end

	return true
end

-- ============================================================
--  Overlay de depuración (/GuiaViaMostrar)
-- ============================================================

function PLUGIN:SendSegmentListTo(client)
	net.Start("GuiaVia_SendList")
		local count = table.Count(ix.guiavia.segments)
		net.WriteUInt(count, 16)
		for id, seg in pairs(ix.guiavia.segments) do
			net.WriteUInt(id, 16)
			net.WriteVector(Vector(seg.startPos.x, seg.startPos.y, seg.startPos.z))
			net.WriteVector(Vector(seg.endPos.x, seg.endPos.y, seg.endPos.z))
			net.WriteUInt(seg.width, 16)
		end
	net.Send(client)
end
