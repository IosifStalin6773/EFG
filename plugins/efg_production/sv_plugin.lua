local PLUGIN = PLUGIN

if (!SERVER) then return end

local function craftSeconds(blueprint)
	if (blueprint.craftTime) then return blueprint.craftTime end
	if (!blueprint.oficio) then return 0 end

	return ix.config.Get("efgCraftMinutes", 5) * 60 * (blueprint.tierRequired or 1)
end

-- cantidades ya resueltas (las recetas con {1, 2, 3} sortean al empezar)
local function resolveResult(result)
	local out = {}

	for uniqueID, amount in pairs(result) do
		out[uniqueID] = istable(amount) and amount[math.random(#amount)] or amount
	end

	return out
end

function PLUGIN:InitializedPlugins()
	if (!ix.blueprint or !ix.blueprint.Craft or ix.blueprint.efgOriginalCraft) then return end

	local original = ix.blueprint.Craft
	ix.blueprint.efgOriginalCraft = original

	function ix.blueprint:Craft(blueprint, client)
		local seconds = craftSeconds(blueprint)
		if (seconds <= 0) then return original(self, blueprint, client) end

		if (!ix.blueprint:CanCraftBlueprint(blueprint, client)) then return end

		-- se gastan los materiales con la función original, sin entregar nada
		local result = blueprint.result
		blueprint.result = {}
		local ok, err = pcall(original, self, blueprint, client)
		blueprint.result = result

		if (!ok) then ErrorNoHalt(err .. "\n") return end

		local character = client:GetCharacter()
		local queue = character:GetData("efgProduction", {})

		queue[#queue + 1] = {ready = os.time() + seconds, name = blueprint.name, result = resolveResult(result)}
		character:SetData("efgProduction", queue)

		client:Notify(("Producción de \"%s\" en marcha: lista en %d min (llega a tu alijo)."):format(blueprint.name, math.ceil(seconds / 60)))
	end
end

local function deliver(client, character)
	local queue = character:GetData("efgProduction")
	if (!istable(queue) or #queue == 0) then return end

	local stash = ix.strongbox and ix.strongbox.GetStash(character)
	local target = stash or character:GetInventory()
	local now, keep = os.time(), {}

	for _, entry in ipairs(queue) do
		if (entry.ready > now) then
			keep[#keep + 1] = entry
		else
			local left = {}

			for uniqueID, amount in pairs(entry.result) do
				local missing = 0

				for _ = 1, amount do
					if (!target:Add(uniqueID)) then missing = missing + 1 end
				end

				if (missing > 0) then left[uniqueID] = missing end
			end

			if (next(left)) then
				entry.result = left
				keep[#keep + 1] = entry
				client:Notify(("\"%s\" está lista pero no cabe en tu alijo."):format(entry.name))
			else
				client:Notify(("Producción terminada: \"%s\" está en tu alijo."):format(entry.name))
			end
		end
	end

	character:SetData("efgProduction", #keep > 0 and keep or nil)
end

local nextCheck = 0

function PLUGIN:Think()
	if (nextCheck > CurTime()) then return end
	nextCheck = CurTime() + 10

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character) then deliver(client, character) end
	end
end
