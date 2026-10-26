local PLUGIN = PLUGIN
ix.recipe = ix.recipe || {stored = {}}

local CLASS = {
    __index         = CLASS,
    name            = 'Recipe',
    uniqueID        = 'recipe',
    skin            = 0,
    model           = 'models/error.mdl',
    category        = 'Recipes',
    description     = 'Cooking recipe description',
    cookingTime     = 5,
    cookingEnt      = NULL
}

function CLASS:__tostring()
    return ('RECIPE[%s]'):format(self.uniqueID)
end

function CLASS:Append()
    ix.recipe:Register(self)
end

function CLASS:CanCookRecipe(client)
    return ix.recipe:CanCookRecipe(self, client)
end

function CLASS:Override(key, value)
    self[key] = value
end

function ix.recipe:GetAll()
    return self.stored
end

function ix.recipe:GetCategories()
    local cats = {}
    for _, v in pairs(self:GetAll()) do
        if not v.category || not isstring(v.category) then continue end
        if table.HasValue(cats, v.category) then continue end
        table.insert(cats, v.category)
    end
    return cats
end

function ix.recipe:GetCategoriesWithItems()
    local cats = {}
    for _, v in pairs(self:GetAll()) do
        cats[v.category] = cats[v.category] || {}
        table.insert(cats[v.category], v)
    end
    return cats
end

function ix.recipe:New(obj)
    local _obj = {}
        setmetatable(_obj, CLASS)
        CLASS.__index = CLASS
    return _obj
end

function ix.recipe:Register(recipe)
    recipe.uniqueID = string.utf8lower(string.gsub(recipe.uniqueID || string.gsub(recipe.name, '%s', '_'), '[\'%.]', ''))
    self.stored[recipe.uniqueID] = recipe

    if recipe.model && recipe.model ~= 'models/error.mdl' then
        util.PrecacheModel(recipe.model)
    end
end

function ix.recipe:FindByID(id)
    if not id || type(id) ~= 'string' then return end
    if not self.stored[id] then return end
    return self.stored[id]
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

function ix.recipe:Init()
    for id, v in pairs( self:GetAll() ) do
        if hasMissingItems(v) then
            self.stored[id] = nil
            continue
        end

        if not v.OnSetup then continue end
        v:OnSetup()
    end
end

function ix.recipe:CanCookRecipe(recipe, client)
    local char = client:GetCharacter()
    local inventory = char:GetInventory()
    if not char || not inventory then return false, 'First error' end

	if (recipe.oficio) then
		local tierRequired = recipe.tierRequired || 1
		if (not ix.oficios or not ix.oficios.CanCraft(char, recipe.oficio, tierRequired)) then
			local officeName = (ix.oficios and ix.oficios.lista and ix.oficios.lista[recipe.oficio]) or recipe.oficio
			return false, ('Necesitas %s nivel %i en el escondite para cocinar esto.'):format(officeName, tierRequired)
		end
	end

    if recipe.tools and istable(recipe.tools) then
        for _, v in ipairs(recipe.tools) do
            if not inventory:HasItem(v) then
                return false, ('You don\'t have "%s" tool'):format( ix.item.list[v].name )
            end
        end
    end

    if recipe.ingredients and istable(recipe.ingredients) then
		for ingredient, amount in pairs(recipe.ingredients) do
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

function ix.recipe:MaxCookable(recipe, client)
	if (not ix.recipe:CanCookRecipe(recipe, client)) then return 0 end
	local char = client:GetCharacter()
	local inventory = char:GetInventory()
	if (not char or not inventory) then return 0 end

	local maxTimes = 99
	if (recipe.ingredients and istable(recipe.ingredients)) then
		for ingredient, amount in pairs(recipe.ingredients) do
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
    function ix.recipe:GetIcon(recipe)
        local mdl = recipe.model || 'models/error.mdl'
        local skin = recipe.skin || 0
        return mdl, skin
    end

    function ix.recipe:CanSee(recipe)
        return recipe.hidden && true || false
    end
end

if SERVER then
    function ix.recipe:GetLookingTarget(recipe, client)
        if not isstring(recipe.cookingEnt) then return NULL end
        local tr = client:GetEyeTraceLimited()
        tr = tr.Entity
        if not IsValid(tr) then return end
        return recipe.cookingEnt == tr:GetClass() && tr || false
    end

    function ix.recipe:Cook(recipe, client, quantity)
        quantity = quantity or 1
        local char = client:GetCharacter()
        local inv = char:GetInventory()
        if not char || not inv then return end
        if not ix.recipe:CanCookRecipe(recipe, client) then return end
        local lookingTarget = ix.recipe:GetLookingTarget(recipe, client)
        if not IsValid(lookingTarget) then return end

        local maxCookable = ix.recipe:MaxCookable(recipe, client)
        quantity = math.Clamp(quantity, 1, maxCookable)

        local totalTime = recipe.cookingTime * quantity
        lookingTarget:EmitSound(recipe.cookSound)
        -- El cocinado ya no obliga a mirar fijamente la cocina: no se cancela al
        -- mover la cámara, moverte o pulsar teclas. Solo se revalida al terminar
        -- que sigas cerca de una cocina válida y con los materiales necesarios.
        client:SetAction('Cocinando...', totalTime, function(client)
            if (not IsValid(client) or not IsValid(lookingTarget)) then return end

            if (client:GetPos():DistToSqr(lookingTarget:GetPos()) > 22500) then
                client:Notify('Te has alejado de la cocina; se canceló el cocinado.')
                return
            end

            local char = client:GetCharacter()
            local inv = char and char:GetInventory()
            if (not char or not inv) then return end
            if (not ix.recipe:CanCookRecipe(recipe, client)) then return end

            for n = 1, quantity do
                local saveChance = hook.Run("GetApanadoSaveChance", char) or 0

                for ingredient, amount in pairs(recipe.ingredients) do
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
                if (recipe.tools and istable(recipe.tools)) then
                    for _, toolID in ipairs(recipe.tools) do
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

                for result, amount in pairs(recipe.result) do
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

                hook.Run("OnRecipeCooked", client, char, recipe)
            end

            if (quantity > 1) then
                client:Notify(('Has cocinado "%s" x%i'):format(recipe.name, quantity))
            else
                client:Notify(('Has cocinado "%s"'):format(recipe.name))
            end
        end)
    end
end