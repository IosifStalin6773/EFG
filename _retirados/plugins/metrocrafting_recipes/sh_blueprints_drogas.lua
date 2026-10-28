local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  QUÍMICO (BANDIDOS) — TIER 2  → mesa drogas
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_droga_narcotico_casero'
    BLUEPRINT.name          = 'Narcótico Casero'
    BLUEPRINT.description   = 'Pasta de setas de túnel maceradas en químicos. Adormece el dolor a costa de nublar la vista.'
    BLUEPRINT.model         = 'models/props_lab/jar01a.mdl'
    BLUEPRINT.category      = 'Drogas'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'drogas'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['setas']    = 3,
    }
    BLUEPRINT.result        = { ['narcotico_casero'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_droga_coctel_energetico'
    BLUEPRINT.name          = 'Cóctel Energético'
    BLUEPRINT.description   = 'Bebida prebélica recargada con estimulantes. Acelera el paso durante unos minutos y deja una sed brutal.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/consumable/energy_drink.mdl'
    BLUEPRINT.category      = 'Drogas'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'drogas'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['energy']   = 2,
        ['quimicos'] = 2,
    }
    BLUEPRINT.result        = { ['coctel_energetico'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_droga_musculoso'
    BLUEPRINT.name          = 'Musculoso'
    BLUEPRINT.description   = 'Vodka, carne de mutante y químicos en un frasco sin etiqueta. Multiplica la fuerza de carga y arrasa con tus reservas.'
    BLUEPRINT.model         = 'models/props_lab/jar01c.mdl'
    BLUEPRINT.category      = 'Drogas'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'drogas'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['vodka']    = 2,
        ['quimicos'] = 3,
        ['carne']    = 2,
    }
    BLUEPRINT.result        = { ['musculoso'] = 1 }
BLUEPRINT:Append()
