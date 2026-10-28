local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  ROPA DE BANDIDOS — SASTRE  → mesa sastre_bandido
--  Indumentaria de maleantes, matones y asaltantes del metro.
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civbandit'
    BLUEPRINT.name          = 'Indumentaria de Maleante'
    BLUEPRINT.description   = 'Chaqueta de cuero remendada para imponer en los túneles. Protección decadente.'
    BLUEPRINT.model         = 'models/kek1ch/rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'sastre_bandido'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']     = 4,
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['1civbandit'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civbandit'
    BLUEPRINT.name          = 'Chaqueta de Matón Veterano'
    BLUEPRINT.description   = 'Abrigo parcheado y tuneado, típico de los matones a sueldo. Protección moderada.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'sastre_bandido'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']            = 4,
        ['tela']             = 3,
        ['placas_metalicas'] = 2,
    }
    BLUEPRINT.result        = { ['2civbandit'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civbanditopt2'
    BLUEPRINT.name          = 'Chaqueta Pertrechada de Asaltante'
    BLUEPRINT.description   = 'Chaqueta con módulos de metal atornillados para resistir la metralla.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'sastre_bandido'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['placas_metalicas'] = 2,
        ['cuero']            = 3,
        ['tela']             = 3,
    }
    BLUEPRINT.result        = { ['2civbanditopt2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civbanditopt3'
    BLUEPRINT.name          = 'Chaleco de Guerrillero'
    BLUEPRINT.description   = 'Chaleco ligero y pantalones rasgados. Defensa decente, pintas cuestionables.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'sastre_bandido'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']     = 3,
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['2civbanditopt3'] = 1 }
BLUEPRINT:Append()
