-- Tirada de tareas diarias: plantilla por comerciante, banda por nivel y
-- refresco según tareasDiariasHoras. No hay if por tipo de objetivo en el
-- generador: los datos vienen de las plantillas.

local function fill(text, vars)
	return (text:gsub("{(%w+)}", function(key)
		return vars[key] or ""
	end))
end

-- Recompensa escalada por banda [VERIFICAR]: +50 % por banda por encima de la primera.
local function scaleReward(reward, band)
	local mult = 1 + 0.5 * (band - 1)

	return {
		rublos = math.floor((reward.rublos or 0) * mult / 1000 + 0.5) * 1000,
		rep    = math.floor((reward.rep or 0) * mult + 0.5),
		xp     = math.floor((reward.xp or 0) * mult + 0.5)
	}
end

function ix.tareasDiarias.Roll(character, traderKey)
	local level = character.GetEFGLevel and character:GetEFGLevel() or 1
	local band = ix.tareasDiarias.GetBand(level)
	local rep = ix.traders.GetEffectiveRep(character, traderKey)
	local pool = {}

	for _, template in ipairs(ix.tareasDiarias.templates) do
		local usable = template.trader == traderKey
			and rep >= (template.minRep or 0)
			and template.count[band] ~= nil
			and (template.kind != "explore" or #(template.zones or {}) > 0)

		if (usable) then table.insert(pool, template) end
	end

	if (#pool == 0) then return nil end

	local template = pool[math.random(#pool)]
	local range = template.count[band]
	local count = math.random(range[1], range[2])
	local mapID = template.maps[math.random(#template.maps)]
	local vars = {count = tostring(count), map = ix.tareasDiarias.maps[mapID] or mapID}

	return {
		id = traderKey .. "_" .. template.id .. "_" .. os.time(),
		traderKey = traderKey,
		templateID = template.id,
		band = band,
		kind = template.kind,
		title = fill(template.title, vars),
		description = fill(template.description, vars),
		steps = {{
			type = template.kind,
			npcGroup = template.npcGroup,
			itemID = template.itemID,
			count = count,
			map = mapID
		}},
		requires = {
			minLevel = ix.traders.repLevels[band].minLevel,
			minRep = template.minRep or 0
		},
		rewardOptions = {scaleReward(template.reward, band)},
		status = "available"
	}
end

-- Devuelve la tarea vigente de este comerciante, tirando una nueva si caducó.
function ix.tareasDiarias.GetForTrader(character, traderKey)
	if (!ix.config.Get("tareasDiariasActivas", true)) then return nil end
	if (!character or !traderKey or traderKey == "") then return nil end

	local state = character:GetTareasDiarias() or {}
	local entry = state[traderKey]
	local maxAge = ix.config.Get("tareasDiariasHoras", 24) * 3600

	if (entry and entry.task and os.time() - (entry.at or 0) < maxAge) then
		return entry.task
	end

	local task = ix.tareasDiarias.Roll(character, traderKey)

	if (task) then
		state[traderKey] = {at = os.time(), task = task}
		character:SetTareasDiarias(state)
	end

	return task
end
