local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  ARMADURAS BETTER ARMOR — TIER 1  (sastre Tier 1) → mesa armas_armaduras
--  Protección: Decadente / Baja
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civropa'
    BLUEPRINT.name          = 'Ropa Remendada'
    BLUEPRINT.description   = 'Ropa básica remendada con retales. Apenas protege del frío.'
    BLUEPRINT.model         = 'models/kek1ch/cs_rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {  }
    BLUEPRINT.ingredients   = {
        ['tela']         = 2,
    }
    BLUEPRINT.result        = { ['1civropa'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civbullet'
    BLUEPRINT.name          = 'Traje de Cuero'
    BLUEPRINT.description   = 'Chaqueta de cuero con refuerzos improvisados. Detiene algún disparo despistado.'
    BLUEPRINT.model         = 'models/kek1ch/rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']     = 4,
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['1civbullet'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civchaquetaslash'
    BLUEPRINT.name          = 'Chaqueta Gruesa'
    BLUEPRINT.description   = 'Chaquetón de tela gruesa. Aguanta los ataques de mutantes pequeños.'
    BLUEPRINT.model         = 'models/kek1ch/rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela']      = 2,
        ['cuero']     = 4,
    }
    BLUEPRINT.result        = { ['1civchaquetaslash'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civsurvivor'
    BLUEPRINT.name          = 'Abrigo de Superviviente'
    BLUEPRINT.description   = 'Equipo remendado con ropa reutilizada. Común en los túneles.'
    BLUEPRINT.model         = 'models/kek1ch/rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']     = 2,
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['1civsurvivor'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_civmedico'
    BLUEPRINT.name          = 'Traje Médico Civil'
    BLUEPRINT.description   = 'Traje identificativo de los médicos civiles del metro.'
    BLUEPRINT.model         = 'models/props_c17/BriefCase001a.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['civmedico'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_1civsurvivor2'
    BLUEPRINT.name          = 'Jersey con Chaleco de Cuero'
    BLUEPRINT.description   = 'Equipo ligero con algo de protección general. Cómodo y manejable.'
    BLUEPRINT.model         = 'models/kek1ch/rookie_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']     = 3,
        ['tela']      = 2,
    }
    BLUEPRINT.result        = { ['1civsurvivor2'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ARMADURAS BETTER ARMOR — TIER 2  (sastre Tier 2) → mesa armas_armaduras
--  Protección: Moderada / Decente
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civmerch'
    BLUEPRINT.name          = 'Ropa de Mercader'
    BLUEPRINT.description   = 'Ropa cómoda con multitud de bolsillos. Para quien vive del comercio.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela']      = 3,
        ['cuero']     = 2,
    }
    BLUEPRINT.result        = { ['2civmerch'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civbullet'
    BLUEPRINT.name          = 'Chaleco de Seguridad Metro'
    BLUEPRINT.description   = 'Equipo reutilizado de seguridad ferroviaria. Resistente pero pesado.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['placas_metalicas'] = 2,
        ['cuero']            = 3,
        ['tela']             = 3,
    }
    BLUEPRINT.result        = { ['2civbullet'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civchaquetaslash'
    BLUEPRINT.name          = 'Equipo de Cazador Subterráneo'
    BLUEPRINT.description   = 'Ropa gruesa con cuero endurecido. Prioriza la defensa frente a mutantes.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']         = 4,
        ['piel_mutante']  = 2,
        ['tela']          = 2,
    }
    BLUEPRINT.result        = { ['2civchaquetaslash'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civsurvivor'
    BLUEPRINT.name          = 'Abrigo de Superviviente Reforzado'
    BLUEPRINT.description   = 'Abrigo con refuerzos y espacio para pertrechos. Ideal para los túneles.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']            = 3,
        ['placas_metalicas'] = 2,
        ['tela']             = 2,
    }
    BLUEPRINT.result        = { ['2civsurvivor'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civsurvivoropt2'
    BLUEPRINT.name          = 'Abrigo de buscador reforzado'
    BLUEPRINT.description   = 'Abrigo con refuerzos y espacio para pertrechos. Ideal para los túneles.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']            = 3,
        ['placas_metalicas'] = 2,
        ['tela']             = 2,
    }
    BLUEPRINT.result        = { ['2civsurvivoropt2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civsurvivoropt3'
    BLUEPRINT.name          = 'Abrigo de buscavidas reforzado'
    BLUEPRINT.description   = 'Abrigo con refuerzos y espacio para pertrechos. Ideal para los túneles.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['cuero']            = 3,
        ['placas_metalicas'] = 2,
        ['tela']             = 2,
    }
    BLUEPRINT.result        = { ['2civsurvivoropt3'] = 1 }
BLUEPRINT:Append()


BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_2civstalker'
    BLUEPRINT.name          = 'Traje Improvisado de Stalker'
    BLUEPRINT.description   = 'Equipo NBC viejo adaptado con filtros improvisados. Algo de protección radiológica.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['tela']             = 6,
        ['cuero']            = 4,
        ['tornillos']        = 2,
        ['vidrio']           = 3,
        ['placas_metalicas'] = 2,
    }
    BLUEPRINT.result        = { ['2civstalker'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_civstalkerfemale'
    BLUEPRINT.name          = 'Traje de stalker Mujer'
    BLUEPRINT.description   = 'Traje sellado para entornos tóxicos y radiactivos. Inmunidad a la radiación.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['tela']             = 6,
        ['cuero']            = 4,
        ['tornillos']        = 2,
        ['vidrio']           = 3,
        ['placas_metalicas'] = 2,
    }
    BLUEPRINT.result        = { ['civstalkerfemale'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ARMADURAS BETTER ARMOR — TIER 3  (sastre Tier 3) → mesa armas_armaduras
--  Protección: Buena / Excelente
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_3civhunter'
    BLUEPRINT.name          = 'Equipo de Cazador Veterano'
    BLUEPRINT.description   = 'Cuero endurecido y piel de mutante. Muy resistente a garras y colmillos.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'llave_inglesa', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['cuero']              = 8,
        ['piel_mutante']       = 6,
        ['placas_metalicas']   = 3,
        ['tela']               = 8,
        ['tornillos']          = 6,
        ['aleacion_reforzada'] = 2,
    }
    BLUEPRINT.result        = { ['3civhunter'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_3civheavy'
    BLUEPRINT.name          = 'Armadura de Placas'
    BLUEPRINT.description   = 'Blindaje ensamblado de equipo militar reutilizado. Soporta fuego intenso a costa de movilidad.'
    BLUEPRINT.model         = 'models/kek1ch/stalker_outfit.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'metroui/craft.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'metroui/icons/craft/armor.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'sastre'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'llave_inglesa', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['placas_metalicas']   = 10,
        ['hierro']             = 4,
        ['aleacion_reforzada'] = 4,
        ['tela']               = 8,
        ['cuero']              = 6,
    }
    BLUEPRINT.result        = { ['3civheavy'] = 1 }
BLUEPRINT:Append()

