local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  QUÍMICO — TIER 1  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_item_aceite'
    BLUEPRINT.name          = 'Aceite'
    BLUEPRINT.description   = 'Aceite para diversos usos.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/repair/gun_oil_ru.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['hierro'] = 2,
    }
    BLUEPRINT.result        = { ['aceite'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_quimicos'
    BLUEPRINT.name          = 'Síntesis de Químicos'
    BLUEPRINT.description   = 'Extrae y concentra compuestos químicos a partir de residuos orgánicos y un recipiente de cristal.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/kerosene.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['residuos_organicos'] = 2,
    }
    BLUEPRINT.result        = { ['quimicos'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_filtro'
    BLUEPRINT.name          = 'Filtro de Gas'
    BLUEPRINT.description   = 'Filtro de carbón activo para máscaras antigas. Fabricado con productos químicos y tela tratada.'
    BLUEPRINT.model         = 'models/teebeutel/metro/objects/gasmask_filter.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['tela']     = 2,
    }
    BLUEPRINT.result        = { ['gasmfilter'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_polvora'
    BLUEPRINT.name          = 'Pólvora'
    BLUEPRINT.description   = 'Mezcla de azufre, carbón y nitratos obtenidos con compuestos químicos. Indispensable para munición artesanal.'
    BLUEPRINT.model         = 'models/illusion/eftcontainers/gpblue.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['azufre']        = 2,
        ['carbonvegetal'] = 2,
    }
    BLUEPRINT.result        = { ['polvora'] = 3 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_azufre'
    BLUEPRINT.name          = 'Azufre'
    BLUEPRINT.description   = 'Polvo de azufre extraído mediante reacción química a partir de residuos orgánicos.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/sack.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
    }
    BLUEPRINT.result        = { ['azufre'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_carbon_activo'
    BLUEPRINT.name          = 'Tableta de Carbón'
    BLUEPRINT.description   = 'Pastillas de carbón activado sintetizadas para filtrar toxinas y reducir la radiación.'
    BLUEPRINT.model         = 'models/spec45as/stalker/items/antirad.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos']      = 2,
        ['carbonvegetal'] = 2,
    }
    BLUEPRINT.result        = { ['tableta_carbon'] = 2 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  QUÍMICO — TIER 2  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_adhesivo'
    BLUEPRINT.name          = 'Cinta Americana'
    BLUEPRINT.description   = 'Rollo de cinta americana fabricado con compuestos químicos adhesivos y tela resistente.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/retardant9.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['tela']     = 2,
        ['plastico'] = 2,
    }
    BLUEPRINT.result        = { ['adhesivo'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_velocidad'
    BLUEPRINT.name          = 'Estimulante de Combate'
    BLUEPRINT.description   = 'Cóctel químico que dispara la adrenalina. Sintetizado a partir de quimicos concentrados.'
    BLUEPRINT.model         = 'models/props_junk/popcan01a.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos']           = 2,
        ['jeringa']            = 2,
        ['residuos_organicos'] = 2,
    }
    BLUEPRINT.result        = { ['pastilla_velocidad'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_stamina'
    BLUEPRINT.name          = 'Energizante Sintético'
    BLUEPRINT.description   = 'Pastilla de síntesis química que mantiene los músculos activos y reduce la fatiga.'
    BLUEPRINT.model         = 'models/props_lab/jar01a.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos']      = 2,
        ['jeringa']       = 2,
        ['carbonvegetal'] = 2,
    }
    BLUEPRINT.result        = { ['pastilla_stamina'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_radiacion'
    BLUEPRINT.name          = 'Pastilla de Yoduro'
    BLUEPRINT.description   = 'Compuesto de yoduro sintetizado que bloquea la absorción de radiación durante un tiempo.'
    BLUEPRINT.model         = 'models/props_lab/jar01c.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['jeringa']  = 2,
        ['azufre']   = 2,
    }
    BLUEPRINT.result        = { ['pastilla_radiacion'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  QUÍMICO — TIER 3  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_fosforo'
    BLUEPRINT.name          = 'Fósforo'
    BLUEPRINT.description   = 'Fósforo refinado obtenido mediante procesos químicos avanzados. Componente clave para explosivos e incendiarios.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/sack.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos']      = 2,
        ['azufre']        = 2,
        ['carbonvegetal'] = 2,
    }
    BLUEPRINT.result        = { ['fosforo'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_quimico_bomba'
    BLUEPRINT.name          = 'Bomba Casera'
    BLUEPRINT.description   = 'Dispositivo explosivo artesanal fabricado con fósforo, pólvora y compuestos químicos concentrados.'
    BLUEPRINT.model         = 'models/weapons/krycek/metro_2k33/w_bomb_ent.mdl'
    BLUEPRINT.category      = 'Quimicos'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'quimico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['polvora']  = 3,
        ['hierro']   = 2,
        ['fosforo']  = 2,
    }
    BLUEPRINT.result        = { ['bomba'] = 1 }
BLUEPRINT:Append()
