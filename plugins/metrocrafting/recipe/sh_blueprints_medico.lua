local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  MÉDICO — TIER 1  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_vendas'
    BLUEPRINT.name          = 'Vendas'
    BLUEPRINT.description   = 'Vendaje estéril para tratar heridas. Fabricado con tela tratada y compuestos antisépticos.'
    BLUEPRINT.model         = 'models/weapons/sweps/eft/afak/w_meds_afak.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['retales_tela'] = 2,
    }
    BLUEPRINT.result        = { ['vendas'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_botiquin'
    BLUEPRINT.name          = 'Botiquín de Médico'
    BLUEPRINT.description   = 'Maletín médico con suministros para tratar heridas y curar a otros supervivientes.'
    BLUEPRINT.model         = 'models/weapons/krycek/metro_2k33/prop_medkit_phys.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
        ['tela']     = 2,
        ['jeringa']  = 2,
    }
    BLUEPRINT.result        = { ['botiquin'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_jeringa'
    BLUEPRINT.name          = 'Jeringa vacía'
    BLUEPRINT.description   = 'Jeringa de uso médico fabricada con plástico reciclado y vidrio. Necesaria para preparar inyecciones y medicamentos.'
    BLUEPRINT.model         = 'models/illusion/eftcontainers/medsyringe.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['plastico'] = 2,
        ['vidrio']   = 2,
    }
    BLUEPRINT.result        = { ['jeringa'] = 2 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  MÉDICO — TIER 2  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_metro_medkit'
    BLUEPRINT.name          = 'Botiquín Rápido (AI-2)'
    BLUEPRINT.description   = 'Botiquín de inyección rápida con jeringas precargadas para autocuración de emergencia.'
    BLUEPRINT.model         = 'models/weapons/krycek/metro_2k33/prop_medkit_phys.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 3,
        ['jeringa']  = 2,
    }
    BLUEPRINT.result        = { ['metro_medkit'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_salino'
    BLUEPRINT.name          = 'Suero Salino'
    BLUEPRINT.description   = 'Solución salina estéril para reducir la radiación acumulada en el organismo.'
    BLUEPRINT.model         = 'models/weapons/w_package.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos']          = 2,
        ['jeringa']           = 2,
        ['bolsa_transfusion'] = 1,
    }
    BLUEPRINT.result        = { ['salino'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_desfibrilador'
    BLUEPRINT.name          = 'Desfibrilador Reparado'
    BLUEPRINT.description   = 'Desfibrilador restaurado a partir de piezas oxidadas y componentes electrónicos reciclados. Permite reanimar a un superviviente caído.'
    BLUEPRINT.model         = 'models/illusion/eftcontainers/defib.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['desfibrilador_roto'] = 1,
        ['quimicos']           = 2,
        ['plastico']           = 1,
        ['bateria']           = 1,
    }
    BLUEPRINT.result        = { ['desfibrilador_reparado'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  MÉDICO — TIER 3  → mesa quimica_medica
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_medico_transfusion'
    BLUEPRINT.name          = 'Transfusión de Sangre'
    BLUEPRINT.description   = 'Bolsa de sangre preparada para eliminar la radiación acumulada. El tratamiento antirad más efectivo del metro.'
    BLUEPRINT.model         = 'models/fallout 3/blood_pack.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/medicaments.png'
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['bolsa_transfusion'] = 1,
        ['quimicos']          = 3,
        ['jeringa']           = 2,
    }
    BLUEPRINT.result        = { ['transfusion'] = 2 }
BLUEPRINT:Append()
