local BLUEPRINT = nil

-- Recetas de EFG: el oficio indica el módulo del escondite (ver efg_hideout)
-- y tierRequired el nivel que necesita ese módulo.

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_ai2'
    BLUEPRINT.name          = 'Botiquín AI-2'
    BLUEPRINT.description   = 'Botiquín básico montado con vendas y química.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['vendas'] = 2,
        ['quimicos'] = 1,
    }
    BLUEPRINT.result        = { ['ai2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_esmarch'
    BLUEPRINT.name          = 'Torniquete'
    BLUEPRINT.description   = 'Torniquete para cortar sangrados graves.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela'] = 2,
        ['plastico'] = 1,
    }
    BLUEPRINT.result        = { ['esmarch'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_analgin'
    BLUEPRINT.name          = 'Analgésico'
    BLUEPRINT.description   = 'Analgésico casero.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['quimicos'] = 2,
    }
    BLUEPRINT.result        = { ['analgin'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_ferula'
    BLUEPRINT.name          = 'Férula'
    BLUEPRINT.description   = 'Inmoviliza fracturas.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['madera'] = 1,
        ['tela'] = 1,
    }
    BLUEPRINT.result        = { ['ferula'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_car'
    BLUEPRINT.name          = 'Botiquín de coche'
    BLUEPRINT.description   = 'Botiquín de coche completo.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['vendas'] = 2,
        ['jeringa'] = 1,
        ['quimicos'] = 1,
    }
    BLUEPRINT.result        = { ['car'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_salewa'
    BLUEPRINT.name          = 'Botiquín de montaña'
    BLUEPRINT.description   = 'Botiquín de primeros auxilios de montaña.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['vendas'] = 3,
        ['jeringa'] = 2,
        ['quimicos'] = 2,
    }
    BLUEPRINT.result        = { ['salewa'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_ifak'
    BLUEPRINT.name          = 'Botiquín individual'
    BLUEPRINT.description   = 'Botiquín individual militar.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['car'] = 1,
        ['esmarch'] = 1,
    }
    BLUEPRINT.result        = { ['ifak'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_cms'
    BLUEPRINT.name          = 'Kit quirúrgico CMS'
    BLUEPRINT.description   = 'Kit para reconstruir extremidades destruidas.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['herramientas_precision'] = 1,
        ['jeringa'] = 2,
    }
    BLUEPRINT.result        = { ['cms'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_morphine'
    BLUEPRINT.name          = 'Morfina'
    BLUEPRINT.description   = 'Inyector de morfina.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Medicinas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'quimica_medica'
    BLUEPRINT.oficio        = 'medico'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['jeringa'] = 1,
        ['quimicos'] = 3,
    }
    BLUEPRINT.result        = { ['morphine'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_kit_reparacion'
    BLUEPRINT.name          = 'Kit de reparación de armadura'
    BLUEPRINT.description   = 'Placas y adhesivo para reparar chalecos y cascos.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela'] = 2,
        ['placas_metalicas'] = 1,
        ['adhesivo'] = 1,
    }
    BLUEPRINT.result        = { ['kit_reparacion_armadura'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_paca'
    BLUEPRINT.name          = 'Chaleco blando'
    BLUEPRINT.description   = 'Chaleco blando de clase 2.'
    BLUEPRINT.model         = 'models/eft_props/gear/armor/ar_paca.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['tela'] = 4,
        ['adhesivo'] = 2,
    }
    BLUEPRINT.result        = { ['armor_paca'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_ssh68'
    BLUEPRINT.name          = 'Casco SSh-68'
    BLUEPRINT.description   = 'Casco de acero de clase 3.'
    BLUEPRINT.model         = 'models/eft_props/gear/helmets/helmet_s_sh_68.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['hierro'] = 3,
        ['placas_metalicas'] = 1,
    }
    BLUEPRINT.result        = { ['helmet_ssh68'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_6b13'
    BLUEPRINT.name          = 'Chaleco 6B13'
    BLUEPRINT.description   = 'Chaleco de asalto de clase 4.'
    BLUEPRINT.model         = 'models/eft_props/gear/armor/ar_6b13_digi.mdl'
    BLUEPRINT.category      = 'Armaduras'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['placas_metalicas'] = 4,
        ['tela'] = 3,
        ['aleacion_reforzada'] = 1,
    }
    BLUEPRINT.result        = { ['armor_6b13'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_pm'
    BLUEPRINT.name          = 'Pistola PM'
    BLUEPRINT.description   = 'Pistola Makarov montada con piezas sueltas.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['muelles'] = 2,
        ['hierro'] = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['arc9_eft_pm'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'efg_ak74'
    BLUEPRINT.name          = 'AK-74'
    BLUEPRINT.description   = 'Fusil de asalto montado con componentes militares.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box004a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = {}
    BLUEPRINT.ingredients   = {
        ['componentes_militares'] = 2,
        ['engranajes'] = 2,
        ['muelles'] = 2,
    }
    BLUEPRINT.result        = { ['arc9_eft_ak74'] = 1 }
BLUEPRINT:Append()
