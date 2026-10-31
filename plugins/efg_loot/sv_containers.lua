-- ============================================================================
--  Contenedores del mundo (Documento A): posición fija colocada por un admin,
--  contenido nuevo en cada raid del servidor sacado de LOOT.Tables.
--  Los tipos están en LOOT.ContainerTypes (sh_loot_tables.lua).
-- ============================================================================

local LOOT = ix.efg.loot

LOOT.raidSerial = LOOT.raidSerial or 0
LOOT.containers = LOOT.containers or {}

-- Borra los inventarios de cualquier entidad de loot
function LOOT.ClearEntity(entity)
	-- las secciones anidadas (mochilas) se borran con su inventario padre
	for _, section in ipairs(entity.efgLoot and entity.efgLoot.sections or {}) do
		if (!section.nested) then
			LOOT.DestroyInventory(section.inventory)
		end
	end

	entity.efgLoot = nil
	entity.efgLootSearched = nil
end

function LOOT.GenerateContainer(entity)
	local info = LOOT.ContainerTypes[entity:GetLootType()]
	local lootTable = info and LOOT.Tables[info.table]
	if (!lootTable) then return end

	LOOT.ClearEntity(entity)

	local inventory = LOOT.NewInventory(lootTable.w or 4, lootTable.h or 4)
	local rolled = LOOT.Roll(info.table)

	LOOT.Fill(inventory, rolled)

	entity.efgLoot = {
		kind = "container",
		name = info.name,
		serial = LOOT.raidSerial,
		sections = {{id = "main", label = info.name, inventory = inventory}}
	}

	LOOT.Log("raid", ("raid %d · contenedor %s (%s) en %s · %s"):format(LOOT.raidSerial, entity:GetLootType(),
		entity:EntIndex(), tostring(entity:GetPos()), LOOT.Describe(rolled)))
end

-- Genera el contenido si es de otra raid (o si nunca se generó)
function LOOT.EnsureContainer(entity)
	if (!entity.efgLoot or entity.efgLoot.serial != LOOT.raidSerial) then
		LOOT.GenerateContainer(entity)
	end
end

function LOOT.SpawnContainer(lootType, pos, ang)
	local info = LOOT.ContainerTypes[lootType]
	if (!info) then return end

	local entity = ents.Create("efg_loot_container")
	if (!IsValid(entity)) then return end

	entity:SetModel(info.model)
	entity:SetPos(pos)
	entity:SetAngles(ang or angle_zero)
	entity:Spawn()
	entity:SetLootType(lootType)
	entity:SetLootName(info.name)

	LOOT.containers[#LOOT.containers + 1] = entity
	LOOT.GenerateContainer(entity)

	return entity
end

function LOOT.GetContainers()
	local list = {}

	for _, entity in ipairs(LOOT.containers) do
		if (IsValid(entity)) then
			list[#list + 1] = entity
		end
	end

	LOOT.containers = list

	return list
end

function PLUGIN:SaveContainers()
	local data = {}

	for _, entity in ipairs(LOOT.GetContainers()) do
		data[#data + 1] = {type = entity:GetLootType(), pos = entity:GetPos(), ang = entity:GetAngles()}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData({}) or {}

	timer.Simple(1, function()
		for _, entry in ipairs(data) do
			LOOT.SpawnContainer(entry.type, entry.pos, entry.ang)
		end
	end)
end

-- Las entidades ya se guardan al añadir/quitar; esto cubre el cierre del mapa
function PLUGIN:SaveData()
	self:SaveContainers()
end

-- Nueva raid del servidor cuando entra el primero: contenido nuevo en todos
-- los contenedores (como efg_ai con los jefes).
function PLUGIN:EFGRaidStarted(client)
	for _, other in ipairs(player.GetAll()) do
		if (other != client and other.InRaid and other:InRaid()) then return end
	end

	LOOT.raidSerial = LOOT.raidSerial + 1
	LOOT.Log("raid", ("── raid %d · mapa %s · %d contenedores ──"):format(LOOT.raidSerial, game.GetMap(), #LOOT.GetContainers()))

	for _, entity in ipairs(LOOT.GetContainers()) do
		LOOT.GenerateContainer(entity)
	end

	hook.Run("EFGLootRaidStarted", LOOT.raidSerial)
end

function PLUGIN:DatabaseConnected()
	LOOT.PurgeOrphans()
end
