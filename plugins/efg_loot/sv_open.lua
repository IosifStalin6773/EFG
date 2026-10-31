-- ============================================================================
--  Abrir un contenedor o un cadáver de loot.
--
--  Toda entidad de loot lleva entity.efgLoot:
--    kind      "container" | "scav" | "pmc" | "player"
--    name      título que ve el jugador
--    sections  lista ordenada de {id, label, inventory}
--    serial    raid del servidor en que se generó
--
--  Fase 3 (efg_loot_ui) abre la ventana compuesta respondiendo true al hook
--  EFGLootOpen. Mientras no exista, se usa la ventana de almacenamiento de
--  Helix y las secciones se abren una detrás de otra: al cerrar una se abre la
--  siguiente. La primera vez que un jugador abre cada sección tarda
--  efgSearchBase + efgSearchPerItem × objetos.
-- ============================================================================

local LOOT = ix.efg.loot

LOOT.USE_DISTANCE = 120
LOOT.SELF_LOOT_LOCK = 600 -- segundos sin poder saquear tu propio cadáver

function LOOT.SearchTime(client, inventory, perItemOnly)
	local count = #LOOT.ItemsOf({inventory})
	local mult = hook.Run("EFGGetSearchMultiplier", client) or 1
	local base = perItemOnly and 0 or ix.config.Get("efgSearchBase", 1.5)

	return (base + count * ix.config.Get("efgSearchPerItem", 0.35)) * mult
end

-- Una mochila del cadáver solo se abre mientras siga en el cadáver
local function sectionAlive(section)
	if (!section.inventory or ix.item.inventories[section.inventory:GetID()] != section.inventory) then
		return false
	end

	if (section.parentItem) then
		local parent = ix.item.instances[section.parentItem]
		return parent != nil and parent.invID == section.parentInventory
	end

	return true
end

LOOT.SectionAlive = sectionAlive

local function liveSections(entity)
	local list = {}

	for index, section in ipairs(entity.efgLoot and entity.efgLoot.sections or {}) do
		if (sectionAlive(section)) then
			list[#list + 1] = {index = index, section = section}
		end
	end

	return list
end

-- Como DoStaredAction de Helix, pero tolerante con los ragdolls: basta con
-- seguir cerca y mirando hacia el cuerpo (la línea de tiro de Helix se pierde
-- entre brazos y piernas y cancelaba la búsqueda).
function LOOT.StareAction(client, entity, seconds, onDone, onCancel)
	local timerID = "efgLootStare" .. client:SteamID64()
	local reps = math.max(1, math.ceil(seconds / 0.1))

	timer.Create(timerID, 0.1, reps, function()
		local ok = IsValid(client) and IsValid(entity) and client:Alive()
			and client:GetPos():Distance(entity:GetPos()) <= LOOT.USE_DISTANCE

		if (ok) then
			local toEntity = (entity:WorldSpaceCenter() - client:GetShootPos()):GetNormalized()
			ok = client:GetAimVector():Dot(toEntity) >= 0.75
		end

		if (!ok) then
			timer.Remove(timerID)
			if (onCancel) then onCancel() end
		elseif (timer.RepsLeft(timerID) == 0) then
			onDone()
		end
	end)
end

local openSection

-- Siguiente sección de la cadena del jugador
local function advance(client, entity, fromIndex)
	local chain = client.efgLootChain

	if (!chain or chain.entity != entity or chain.index != fromIndex) then return end

	chain.index = fromIndex + 1

	timer.Simple(0, function()
		if (IsValid(client) and IsValid(entity) and client.efgLootChain == chain) then
			openSection(client, entity, chain.index)
		end
	end)
end

openSection = function(client, entity, position)
	local sections = liveSections(entity)
	local entry = sections[position]

	if (!entry or client:GetPos():Distance(entity:GetPos()) > LOOT.USE_DISTANCE * 1.5) then
		client.efgLootChain = nil
		return
	end

	local section, inventory = entry.section, entry.section.inventory
	local serial = entity.efgLoot.serial or 0

	entity.efgLootSearched = entity.efgLootSearched or {}
	entity.efgLootSearched[client] = entity.efgLootSearched[client] or {}

	local searched = entity.efgLootSearched[client][section.id] == serial
	local seconds = searched and 0 or LOOT.SearchTime(client, inventory, section.single)

	local function show()
		if (!IsValid(client) or !IsValid(entity)) then return end

		entity.efgLootSearched[client][section.id] = serial

		local info = entity.efgLoot
		local name = info.nameKey and L(info.nameKey, client) or info.name or ""
		local label = section.labelKey and L(section.labelKey, client) or section.label or section.id
		local title = ("%s · %s"):format(name, label)

		if (inventory.storageInfo) then
			inventory.storageInfo.searchTime = 0
			inventory.storageInfo.name = title
		end

		ix.storage.Open(client, inventory, {
			entity = entity,
			name = title,
			bMultipleUsers = true,
			searchTime = 0,
			OnPlayerClose = function(closer)
				if (IsValid(closer)) then
					advance(closer, entity, position)
				end
			end
		})
	end

	if (seconds <= 0.2) then
		show()
		return
	end

	client:SetAction("@efgLootSearching", seconds)
	LOOT.StareAction(client, entity, seconds, show, function()
		if (IsValid(client)) then
			client:SetAction()
			client.efgLootChain = nil
		end
	end)
end

function LOOT.Open(client, entity)
	if (!IsValid(client) or !IsValid(entity) or !entity.efgLoot or !client:GetCharacter()) then return end
	if (!client:Alive() or client:GetPos():Distance(entity:GetPos()) > LOOT.USE_DISTANCE) then return end

	-- Fase 3: ventana compuesta
	if (hook.Run("EFGLootOpen", client, entity) == true) then return end

	-- la cadena nueva va antes de cerrar lo abierto: así el cierre no avanza
	-- la cadena anterior
	client.efgLootChain = {entity = entity, index = 1}
	ix.storage.CloseCurrent(client)
	openSection(client, entity, 1)
end

-- Los cadáveres (prop_ragdoll) no tienen ENT:Use: se abren con PlayerUse y,
-- como los de VJ nacen con colisión de escombro y el +use de GMod no siempre
-- los encuentra, también al pulsar E mirando a uno (KeyPress).
-- persistent_corpses se salta los cadáveres de este sistema porque ya no
-- tienen entity.ixInventory, así que el orden de los hooks no importa.
function LOOT.TryUse(client, entity)
	if (!IsValid(entity) or !entity.efgLoot or entity:GetClass() != "prop_ragdoll") then return end

	if ((client.efgLootUseNext or 0) > CurTime()) then return false end
	client.efgLootUseNext = CurTime() + 1

	if (entity.ixCorpseOwnerSID == client:SteamID64() and client:GetUserGroup() == "user") then
		local remaining = LOOT.SELF_LOOT_LOCK - (CurTime() - (entity.ixCorpseDeathTime or 0))

		if (remaining > 0) then
			client:NotifyLocalized("efgLootOwnCorpse", math.ceil(remaining / 60))
			return false
		end
	end

	LOOT.Open(client, entity)

	return false
end

function PLUGIN:PlayerUse(client, entity)
	return LOOT.TryUse(client, entity)
end

local USE_RANGE = 96

-- Cadáver con botín al que mira el jugador (la línea de tiro y, si roza, el
-- más cercano al punto donde mira)
function LOOT.CorpseInSight(client)
	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * USE_RANGE,
		filter = client,
		mask = MASK_SHOT
	})

	local entity = trace.Entity

	if (IsValid(entity) and entity.efgLoot and entity:GetClass() == "prop_ragdoll") then
		return entity
	end

	local best, bestDist

	for _, candidate in ipairs(ents.FindInSphere(trace.HitPos, 32)) do
		if (candidate.efgLoot and candidate:GetClass() == "prop_ragdoll") then
			local dist = candidate:NearestPoint(trace.HitPos):DistToSqr(trace.HitPos)

			if (!bestDist or dist < bestDist) then
				best, bestDist = candidate, dist
			end
		end
	end

	return best
end

function PLUGIN:KeyPress(client, key)
	if (key != IN_USE or !client:Alive() or !client:GetCharacter()) then return end

	local entity = LOOT.CorpseInSight(client)

	if (entity) then
		LOOT.TryUse(client, entity)
	end
end

function PLUGIN:PlayerDisconnected(client)
	client.efgLootChain = nil
	timer.Remove("efgLootStare" .. client:SteamID64())
end

function PLUGIN:PlayerDeath(client)
	client.efgLootChain = nil
end
