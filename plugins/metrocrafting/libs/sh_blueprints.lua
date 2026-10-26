local PLUGIN = PLUGIN
ix.blueprint = ix.blueprint || {stored = {}}

local CLASS = {
    __index         = CLASS,
    name            = 'Blueprint',
    uniqueID        = 'blueprint',
    skin            = 0,
    model           = 'models/error.mdl',
    category        = 'Blueprint',
    description     = 'Blueprint description',
    icon            = 'efgui/icons/clay.png',
    craftSound      = 'ui/buttonclick.wav',
    mesa            = '',
    noOficio        = false,
}

function CLASS:__tostring()
    return ('BLUEPRINT[%s]'):format(self.uniqueID)
end

function CLASS:Append()
    ix.blueprint:Register(self)
end

function CLASS:CanCraftBlueprint(client)
    return ix.blueprint:CanCraftBlueprint(self, client)
end

function CLASS:Override(key, value)
    self[key] = value
end

function ix.blueprint:GetAll()
    return self.stored
end

function ix.blueprint:GetCategories(mesa)
    local cats = {}
    for _, v in pairs(self:GetAll()) do
        if (mesa and mesa ~= '' and v.mesa ~= mesa) then continue end
        if not v.category || not isstring(v.category) then continue end
        if table.HasValue(cats, v.category) then continue end
        table.insert(cats, v.category)
    end
    return cats
end

function ix.blueprint:GetCategoriesWithItems(mesa)
    local cats = {}
    for _, v in pairs(self:GetAll()) do
        if (mesa and mesa ~= '' and v.mesa ~= mesa) then continue end
        cats[v.category] = cats[v.category] || {}
        table.insert(cats[v.category], v)
    end
    return cats
end

function ix.blueprint:New(obj)
    local _obj = {}
        setmetatable(_obj, CLASS)
        CLASS.__index = CLASS
    return _obj
end

function ix.blueprint:Register(blueprint)
    blueprint.uniqueID = string.utf8lower(string.gsub(blueprint.uniqueID || string.gsub(blueprint.name, '%s', '_'), '[\'%.]', ''))
    self.stored[blueprint.uniqueID] = blueprint

    if blueprint.model && blueprint.model ~= 'models/error.mdl' then
        util.PrecacheModel(blueprint.model)
    end
end

function ix.blueprint:FindByID(id)
    if not id || type(id) ~= 'string' then return end
    if not self.stored[id] then return end
    return self.stored[id]
end

function ix.blueprint:FindByResult(itemUniqueID)
    for _, blueprint in pairs(self.stored) do
        if (blueprint.result and blueprint.result[itemUniqueID]) then
            return blueprint
        end
    end
end


-- EFG: quita las recetas que usan ítems que ya no existen (plugins de Metro retirados)
local function hasMissingItems(entry)
    for _, field in ipairs({'ingredients', 'result'}) do
        for itemID in pairs(entry[field] or {}) do
            if not ix.item.list[itemID] then return itemID end
        end
    end

    for _, itemID in ipairs(entry.tools or {}) do
        if not ix.item.list[itemID] then return itemID end
    end
end

function ix.blueprint:Init()
    for id, v in pairs( self:GetAll() ) do
        if hasMissingItems(v) then
            self.stored[id] = nil
            continue
        end

        if not v.OnSetup then continue end
        v:OnSetup()
    end
end

function ix.blueprint:CanCraftBlueprint(blueprint, client)
    local char = client:GetCharacter()
    local inventory = char:GetInventory()
    if not char || not inventory then return false, 'First error' end

	if (not blueprint.noOficio and blueprint.oficio) then
		local tierRequired = blueprint.tierRequired || 1
		if (not ix.oficios or not ix.oficios.CanCraft(char, blueprint.oficio, tierRequired)) then
			local officeName = (ix.oficios and ix.oficios.lista and ix.oficios.lista[blueprint.oficio]) or blueprint.oficio
			return false, ('Necesitas %s nivel %i en el escondite para fabricar esto.'):format(officeName, tierRequired)
		end
	end

    if blueprint.tools and istable(blueprint.tools) then
        for _, v in ipairs(blueprint.tools) do
            if not inventory:HasItem(v) then
                return false, ('You don\'t have "%s" tool'):format( ix.item.list[v].name )
            end
        end
    end

    if blueprint.ingredients and istable(blueprint.ingredients) then
		for ingredient, amount in pairs(blueprint.ingredients) do
			-- Suma la cantidad total considerando stacks (campo Amount)
			local function ingredientAmount()
				local total = 0
				for _, v in pairs(inventory:GetItems()) do
					if (v.uniqueID == ingredient) then
						total = total + v:GetData("Amount", 1)
					end
				end
				return total
			end

			if not inventory:HasItem(ingredient) then
                return false, ('You don\'t have "%s" item'):format(ix.item.list[ingredient].name)
			elseif ingredientAmount() < amount then
                local name = ingredient

                if amount > 1 then
                    name = PLUGIN:Pluralize(ix.item.list[ingredient].name)
                end

                return false, ('You need at least %i "%s"'):format(amount, name)
			end
		end
    end

    return true
end

function ix.blueprint:MaxCraftable(blueprint, client)
	if (not ix.blueprint:CanCraftBlueprint(blueprint, client)) then return 0 end
	local char = client:GetCharacter()
	local inventory = char:GetInventory()
	if (not char or not inventory) then return 0 end

	local maxTimes = 99
	if (blueprint.ingredients and istable(blueprint.ingredients)) then
		for ingredient, amount in pairs(blueprint.ingredients) do
			local total = 0
			for _, item in pairs(inventory:GetItems()) do
				if (item.uniqueID == ingredient) then
					total = total + item:GetData("Amount", 1)
				end
			end
			maxTimes = math.min(maxTimes, math.floor(total / amount))
		end
	end

	return maxTimes
end

if CLIENT then
    function ix.blueprint:GetIcon(blueprint)
        local mdl = blueprint.model || 'models/error.mdl'
        local skin = blueprint.skin || 0
        return mdl, skin
    end

    function ix.blueprint:CanSee(blueprint)
        return blueprint.hidden && true || false
    end
end

if SERVER then
    function ix.blueprint:Craft(blueprint, client)
        local char = client:GetCharacter()
        local inv = char:GetInventory()
        if not char || not inv then return end
        if not ix.blueprint:CanCraftBlueprint(blueprint, client) then return end

		-- Apañado: probabilidad de ahorrar cada unidad de material.
		local saveChance = hook.Run("GetApanadoSaveChance", char) or 0

		-- Consumir ingredientes respetando stacks (campo Amount)
		for ingredient, amount in pairs(blueprint.ingredients) do
			local toConsume = amount
			if (saveChance > 0) then
				local saved = 0
				for _ = 1, amount do
					if (math.random() < saveChance) then
						saved = saved + 1
					end
				end
				if (saved > 0) then
					toConsume = math.max(amount - saved, 0)
					local itemName = ix.item.list[ingredient] and ix.item.list[ingredient].name or ingredient
					client:Notify(("¡Apañado! Ahorraste %ix %s."):format(saved, itemName))
				end
			end

			local remaining = toConsume
			for _, item in pairs(inv:GetItems()) do
				if (item.uniqueID == ingredient and remaining > 0) then
					local stackAmt = item:GetData("Amount", 1)
					if (stackAmt <= remaining) then
						remaining = remaining - stackAmt
						item:Remove()
					else
						item:SetData("Amount", stackAmt - remaining)
						remaining = 0
					end
				end
				if (remaining <= 0) then break end
			end
		end

		-- Cada herramienta requerida tiene una probabilidad de romperse al craftear.
		if (blueprint.tools and istable(blueprint.tools)) then
			for _, toolID in ipairs(blueprint.tools) do
				for _, item in pairs(inv:GetItems()) do
					if (item.uniqueID == toolID) then
						if (math.random() < (item.breakChance or 0.20)) then
							client:Notify(("Tu %s se ha roto."):format(item.name or "herramienta"))
							item:Remove()
						end
						break
					end
				end
			end
		end

		-- Snapshot de ítems existentes para identificar los nuevos tras el crafteo.
		local durBonus = hook.Run("GetManitasDurabilityBonus", char) or 0
		local preIDs = {}
		if (durBonus > 0) then
			for _, item in pairs(inv:GetItems()) do
				preIDs[item.id] = true
			end
		end

        for result, amount in pairs(blueprint.result) do
			local actualAmount
			if type(amount) == 'table' then
				actualAmount = amount[math.random(1, #amount)]
			else
				actualAmount = amount
			end

			for _ = 1, actualAmount do
				if not client:GetCharacter():GetInventory():Add(result) then
					ix.item.Spawn(result, client)
				end
			end
		end

		-- Manitas: aplicar bonus de durabilidad a los objetos recién crafteados.
		if (durBonus > 0) then
			for _, item in pairs(inv:GetItems()) do
				if (not preIDs[item.id]) then
					local armDur = item:GetData("Durability")
					if (armDur) then
						item:SetData("Durability", math.floor(armDur * (1 + durBonus)))
					end
					local wepDur = item:GetData("durability")
					if (wepDur) then
						item:SetData("durability", math.floor(wepDur * (1 + durBonus)))
					end
				end
			end
		end

		if blueprint.OnCraft then
			blueprint:OnCraft(client)
		end

		-- Manitas: XP por craftear.
		hook.Run("OnBlueprintCrafted", client, char, blueprint)
    end
end