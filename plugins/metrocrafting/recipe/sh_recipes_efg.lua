local RECIPE = nil

-- Unidad de nutrición del escondite (metro_stove)

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_efg_agua'
    RECIPE.name         = 'Agua potable'
    RECIPE.description  = 'Agua filtrada y hervida.'
    RECIPE.model        = 'models/props_junk/garbage_glassbottle001a.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'efgui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 10
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'ui/buttonclick.wav'
    RECIPE.oficio       = 'cocinero'
    RECIPE.tierRequired = 1
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['botella_cristal'] = 1,
        ['quimicos'] = 1,
    }
    RECIPE.result       = { ['water'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_efg_lata'
    RECIPE.name         = 'Comida en lata'
    RECIPE.description  = 'Conserva casera.'
    RECIPE.model        = 'models/props_junk/garbage_glassbottle001a.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'efgui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 20
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'ui/buttonclick.wav'
    RECIPE.oficio       = 'cocinero'
    RECIPE.tierRequired = 1
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['residuos_organicos'] = 3,
        ['hierro'] = 1,
    }
    RECIPE.result       = { ['canned'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_efg_energetica'
    RECIPE.name         = 'Bebida energética'
    RECIPE.description  = 'Mezcla azucarada con cafeína.'
    RECIPE.model        = 'models/props_junk/garbage_glassbottle001a.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'efgui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 15
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'ui/buttonclick.wav'
    RECIPE.oficio       = 'cocinero'
    RECIPE.tierRequired = 2
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['water'] = 1,
        ['quimicos'] = 1,
    }
    RECIPE.result       = { ['energy'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_efg_vodka'
    RECIPE.name         = 'Vodka'
    RECIPE.description  = 'Destilado casero de 40 grados.'
    RECIPE.model        = 'models/props_junk/garbage_glassbottle001a.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'efgui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 30
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'ui/buttonclick.wav'
    RECIPE.oficio       = 'cocinero'
    RECIPE.tierRequired = 3
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['water'] = 2,
        ['residuos_organicos'] = 2,
        ['botella_cristal'] = 1,
    }
    RECIPE.result       = { ['vodka'] = 1 }
RECIPE:Append()
