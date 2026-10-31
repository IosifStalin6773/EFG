-- ============================================================================
--  Diseño de la ventana derecha (Documento B). Solo datos: recibe el tipo de
--  cuerpo o contenedor y sus secciones, y devuelve la lista de bloques que
--  el cliente dibuja de arriba abajo.
--    scav       "Dead Scav" 4x4, equipo compacto, bolsillos 4x1 y lo anidado
--    replica    PMC de IA, jugador, jefe y Raider: ranuras de un jugador
--               (armas, casco, blindaje, chaleco, mochila) y sus rejillas
--    container  contenedor del mundo: rejilla pura
-- ============================================================================

local WIN = ix.efg.lootwin

WIN.LAYOUT_BY_KIND = {
	scav = "scav",
	pmc = "replica",
	player = "replica",
	boss = "replica",
	raider = "replica",
	container = "container"
}

-- Ranuras de la réplica, en el orden en que se dibujan
WIN.REPLICA_SLOTS = {
	{id = "primary", labelKey = "efgLootWinPrimary", w = 5, h = 2},
	{id = "secondary", labelKey = "efgLootWinSecondary", w = 5, h = 2},
	{id = "holster", labelKey = "efgLootWinHolster", w = 2, h = 2},
	{id = "helmet", labelKey = "efgLootWinHelmet", w = 2, h = 2},
	{id = "armor", labelKey = "efgLootWinArmor", w = 3, h = 3},
	{id = "rig", labelKey = "efgLootWinRig", w = 3, h = 3},
	{id = "backpack", labelKey = "efgLootWinBackpack", w = 3, h = 3},
	{id = "other", labelKey = "efgLootWinOther", w = 2, h = 2, many = true}
}

-- El Scav enseña lo mismo en menos sitio
WIN.SCAV_SLOTS = {
	{id = "primary", labelKey = "efgLootWinPrimary", w = 4, h = 2},
	{id = "holster", labelKey = "efgLootWinHolster", w = 2, h = 2},
	{id = "armor", labelKey = "efgLootWinArmor", w = 2, h = 2},
	{id = "rig", labelKey = "efgLootWinRig", w = 2, h = 2},
	{id = "backpack", labelKey = "efgLootWinBackpack", w = 2, h = 2},
	{id = "other", labelKey = "efgLootWinOther", w = 2, h = 2, many = true}
}

local function sectionsBy(data, id)
	for index, section in ipairs(data.sections or {}) do
		if (section.id == id) then
			return index, section
		end
	end
end

local function nested(data)
	local list = {}

	for index, section in ipairs(data.sections or {}) do
		if (section.nested) then
			list[#list + 1] = index
		end
	end

	return list
end

-- kind: tipo de efgLoot ("scav", "pmc", "player", "boss", "raider",
-- "container"). data: {title, sections = {{id, label, w, h, nested...}}}
function WIN.BuildLootLayout(kind, data)
	local layout = WIN.LAYOUT_BY_KIND[kind] or "replica"
	local blocks = {}

	if (layout == "container") then
		for index in ipairs(data.sections or {}) do
			blocks[#blocks + 1] = {type = "grid", section = index}
		end

		return blocks, layout
	end

	local body = sectionsBy(data, "body")
	local equip = sectionsBy(data, "equip")
	local pockets = sectionsBy(data, "pockets")

	if (layout == "scav") then
		if (body) then
			blocks[#blocks + 1] = {type = "grid", section = body, labelKey = "efgLootWinDeadScav"}
		end

		if (equip) then
			blocks[#blocks + 1] = {type = "slots", section = equip, slots = WIN.SCAV_SLOTS}
		end
	else
		if (equip) then
			blocks[#blocks + 1] = {type = "slots", section = equip, slots = WIN.REPLICA_SLOTS}
		end

		if (body) then
			blocks[#blocks + 1] = {type = "grid", section = body}
		end
	end

	if (pockets) then
		blocks[#blocks + 1] = {type = "grid", section = pockets}
	end

	for _, index in ipairs(nested(data)) do
		blocks[#blocks + 1] = {type = "grid", section = index}
	end

	-- secciones sin sitio fijo (por si un plugin añade otras)
	for index, section in ipairs(data.sections or {}) do
		if (index != body and index != equip and index != pockets and !section.nested) then
			blocks[#blocks + 1] = {type = "grid", section = index}
		end
	end

	return blocks, layout
end

-- Global con el nombre del documento de diseño
BuildLootLayout = WIN.BuildLootLayout
