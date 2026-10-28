local RECIPE = nil

-- ════════════════════════════════════════════════════════════════════
--  COCINA — COMIDA  → metro_stove  (sin oficio)
-- ════════════════════════════════════════════════════════════════════

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_carnecocida'
    RECIPE.name         = 'Carne Cocida'
    RECIPE.description  = 'Carne asada directamente sobre las brasas. Más segura y nutritiva que cruda.'
    RECIPE.model        = 'models/lostsignalproject/items/consumable/meat_boar.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 5
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['carne'] = 1,
    }
    RECIPE.result       = { ['carnecocida'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_pincho_rata'
    RECIPE.name         = 'Pincho de Carne'
    RECIPE.description  = 'Trozos de carne de topo o rata asados en un palo. Ración rápida en los túneles.'
    RECIPE.model        = 'models/lostsignalproject/items/consumable/meat_tushkano.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 8
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['carne_extrana'] = 3,
    }
    RECIPE.result       = { ['pinchocarne'] = 3 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_salchicha'
    RECIPE.name         = 'Salchicha'
    RECIPE.description  = 'Carne prensada y curada en tripa improvisada. Dura semanas sin estropearse.'
    RECIPE.model        = 'models/weapons/sweps/stalker2/sausage/w_item_sausage.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 12
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['carne']              = 3,
    }
    RECIPE.result       = { ['sausage'] = 2 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_estofado_setas'
    RECIPE.name         = 'Estofado de Setas'
    RECIPE.description  = 'Setas del metro cocinadas a fuego lento. Sustancioso y fácil de preparar.'
    RECIPE.model        = 'models/lostsignalproject/items/consumable/food_chimera.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 15
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['setas'] = 4,
        ['carne'] = 1,
        ['agua_sucia'] = 1,
    }
    RECIPE.result       = { ['estofadosetas'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_estofado_carne'
    RECIPE.name         = 'Estofado de Carne'
    RECIPE.description  = 'Guiso espeso de carne con setas. Una de las comidas más nutritivas del metro.'
    RECIPE.model        = 'models/lostsignalproject/items/consumable/meat_dog.mdl'
    RECIPE.category     = 'Comida'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 20
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['carne'] = 3,
        ['setas'] = 2,
        ['agua_sucia'] = 1,
    }
    RECIPE.result       = { ['estofadocarne'] = 1 }
RECIPE:Append()

-- ════════════════════════════════════════════════════════════════════
--  COCINA — BEBIDAS  → metro_stove  (sin oficio)
-- ════════════════════════════════════════════════════════════════════

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_agua_limpia'
    RECIPE.name         = 'Agua Limpia'
    RECIPE.description  = 'Agua sucia hervida y filtrada. Imprescindible para sobrevivir en los túneles.'
    RECIPE.model        = 'models/props_junk/garbage_metalcan001a.mdl'
    RECIPE.category     = 'Bebidas'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 8
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['agua_sucia'] = 2,
    }
    RECIPE.result       = { ['water'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_te_setas'
    RECIPE.name         = 'Té de Setas'
    RECIPE.description  = 'Infusión caliente de setas del metro. Hidrata y reconforta en los túneles fríos.'
    RECIPE.model        = 'models/lostsignalproject/items/consumable/tea.mdl'
    RECIPE.category     = 'Bebidas'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 8
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['setas']      = 2,
        ['agua_sucia'] = 1,
    }
    RECIPE.result       = { ['tesetas'] = 1 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_cerveza'
    RECIPE.name         = 'Cerveza Artesanal'
    RECIPE.description  = 'Fermentado de setas y agua del metro. Amargo y turbio, pero sacia la sed.'
    RECIPE.model        = 'models/props_junk/GlassBottle01a.mdl'
    RECIPE.category     = 'Bebidas'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 20
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['setas']           = 2,
        ['agua_sucia']      = 2,
        ['botella_cristal'] = 1,
    }
    RECIPE.result       = { ['botella_cerveza'] = 2 }
RECIPE:Append()

RECIPE = ix.recipe:New()
    RECIPE.uniqueID     = 'cook_vodka'
    RECIPE.name         = 'Vodka'
    RECIPE.description  = 'Destilado artesanal de fermentado de setas. Alta graduación, moneda social en el metro.'
    RECIPE.model        = 'models/weapons/sweps/stalker2/vodka/w_item_vodka.mdl'
    RECIPE.category     = 'Bebidas'
    RECIPE.hidden       = false
    RECIPE.icon         = 'metroui/icons/cooking/bread.png'
    RECIPE.cookingTime  = 25
    RECIPE.cookingEnt   = 'metro_stove'
    RECIPE.cookSound    = 'metroui/craft.wav'
    RECIPE.tools        = {}
    RECIPE.ingredients  = {
        ['setas']           = 3,
        ['agua_sucia']      = 3,
        ['botella_cristal'] = 1,
    }
    RECIPE.result       = { ['vodka'] = 1 }
RECIPE:Append()