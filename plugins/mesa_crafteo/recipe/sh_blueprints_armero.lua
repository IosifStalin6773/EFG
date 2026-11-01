local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  MUNICIÓN — TIER 1  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_pistol'
    BLUEPRINT.name          = 'Munición de Pistola'
    BLUEPRINT.description   = 'Cartuchos de pistola artesanales.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/ammo/357.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['plomo']   = 2,
        ['polvora'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_pistol'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_buckshot'
    BLUEPRINT.name          = 'Munición de Escopeta'
    BLUEPRINT.description   = 'Cartuchos de perdigones artesanales.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/ammo/12x70.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['plomo']   = 2,
        ['polvora'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_buckshot'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_357'
    BLUEPRINT.name          = 'Balas de Rodamiento'
    BLUEPRINT.description   = 'Proyectiles de acero improvisados. Munición neumática.'
    BLUEPRINT.model         = 'models/props_lab/box01a.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_357'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_smg1'
    BLUEPRINT.name          = 'Dardos'
    BLUEPRINT.description   = 'Dardos de acero para armas neumáticas como la Hellsing.'
    BLUEPRINT.model         = 'models/props_lab/box01a.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['hierro'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_smg1'] = 2 }
BLUEPRINT:Append()
-- ════════════════════════════════════════════════════════════════════
--  MUNICIÓN — TIER 2  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_ar2'
    BLUEPRINT.name          = 'Munición de Fusil'
    BLUEPRINT.description   = 'Cartuchos de rifle artesanales para Kalash y similares.'
    BLUEPRINT.model         = 'models/devcon/mrp/props/ak_magazine.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa' }
    BLUEPRINT.ingredients   = {
        ['plomo']   = 2,
        ['polvora'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_ar2'] = 2 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  MUNICIÓN — TIER 3  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_sniperround'
    BLUEPRINT.name          = 'Munición de Francotirador'
    BLUEPRINT.description   = 'Cartuchos de largo alcance de alta precisión.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/ammo/762x39.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'llave_inglesa', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['plomo']   = 3,
        ['polvora'] = 2,
    }
    BLUEPRINT.result        = { ['ammo_sniperround'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ammo_ar2altfire'
    BLUEPRINT.name          = 'Munición Pesada'
    BLUEPRINT.description   = 'Cartuchos de alta densidad para armas de fuego lento y gran daño.'
    BLUEPRINT.model         = 'models/devcon/mrp/props/ammo_lenta.mdl'
    BLUEPRINT.category      = 'Munición'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'llave_inglesa', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['plomo']   = 4,
        ['polvora'] = 2,
        ['hierro']  = 2,
    }
    BLUEPRINT.result        = { ['ammo_ar2altfire'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ARMAS — TIER 1  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_revolver'
    BLUEPRINT.name          = 'Revolver'
    BLUEPRINT.description   = 'Revólver artesanal de 6 disparos. Fiable y robusto.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box003a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['madera']    = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_revolver'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_padonak'
    BLUEPRINT.name          = 'Padonak'
    BLUEPRINT.description   = 'Pistola artesanal compacta. Fácil de fabricar y ocultar.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box003a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['cw_metro2033_padonak'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_duplet'
    BLUEPRINT.name          = 'Duplet'
    BLUEPRINT.description   = 'Escopeta de dos cañones. Devastadora a corta distancia.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box003a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['hierro']    = 2,
        ['muelles']   = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_duplet'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_hellsing'
    BLUEPRINT.name          = 'Hellsing'
    BLUEPRINT.description   = 'Ballesta neumática. Silenciosa y letal a media distancia.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box003a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['muelles']   = 2,
        ['hierro'] = 2,
    }
    BLUEPRINT.result        = { ['cw_metro2033_hellsing'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ACCESORIOS — TIER 1  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_silenciador_pistola'
    BLUEPRINT.name          = 'Silenciador de Pistola'
    BLUEPRINT.description   = 'Silenciador artesanal para pistolas.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['tela']   = 2,
        ['hierro'] = 2,
    }
    BLUEPRINT.result        = { ['att_silenciador_pistola'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_canon_largo_pistola'
    BLUEPRINT.name          = 'Cañón Largo de Pistola'
    BLUEPRINT.description   = 'Extiende el cañón de pistolas artesanales.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['att_canon_largo_pistola'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_stock_pistola'
    BLUEPRINT.name          = 'Stock de Pistola'
    BLUEPRINT.description   = 'Culata artesanal para pistolas.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['att_stock_pistola'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_stock_escopeta'
    BLUEPRINT.name          = 'Stock de Escopeta'
    BLUEPRINT.description   = 'Culata de madera para la Duplet.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['att_stock_escopeta'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_canon_largo_escopeta'
    BLUEPRINT.name          = 'Cañón Largo de Escopeta'
    BLUEPRINT.description   = 'Cañón extendido para la Duplet.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['att_canon_largo_escopeta'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_condensador_hellsing'
    BLUEPRINT.name          = 'Condensador (Hellsing)'
    BLUEPRINT.description   = 'Sistema neumático mejorado para la Hellsing.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']     = 2,
        ['engranajes'] = 2,
    }
    BLUEPRINT.result        = { ['att_condensador_hellsing'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_weptools'
    BLUEPRINT.name          = 'Kit de Reparación de Armas'
    BLUEPRINT.description   = 'Aceite, baquetas, paños y piezas de recambio improvisadas para mantener un arma engrasada y en condiciones de disparo.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/repair/toolkit_wp.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 1
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['weptools'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ARMAS — TIER 2  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_bastarda'
    BLUEPRINT.name          = 'Bastarda'
    BLUEPRINT.description   = 'Escopeta artesanal robusta. Más potente que la Duplet.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']     = 4,
        ['muelles']    = 2,
        ['tornillos']  = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_ubludok'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_shambler'
    BLUEPRINT.name          = 'Shambler'
    BLUEPRINT.description   = 'Escopeta de acción de palanca. Brutal a corta distancia.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']     = 4,
        ['muelles']    = 2,
        ['tornillos']  = 2,
        ['engranajes'] = 2
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_uboynik'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_tikhar'
    BLUEPRINT.name          = 'Tikhar'
    BLUEPRINT.description   = 'Rifle neumático de precisión. Silencioso e impredecible.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'llave_inglesa', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['muelles']   = 2,
        ['hierro']    = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_tikhar'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ACCESORIOS — TIER 2  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_stock_bastarda'
    BLUEPRINT.name          = 'Culata Bastarda'
    BLUEPRINT.description   = 'Culata reforzada para la Bastarda.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['madera']    = 2,
        ['hierro']    = 2,
        ['tornillos'] = 2,
    }
    BLUEPRINT.result        = { ['att_stock_bastarda'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_radiador_bastarda'
    BLUEPRINT.name          = 'Radiador Bastarda'
    BLUEPRINT.description   = 'Módulo de ventilación para la Bastarda.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['cobre']  = 2,
    }
    BLUEPRINT.result        = { ['att_radiador_bastarda'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_laser'
    BLUEPRINT.name          = 'Puntero Láser'
    BLUEPRINT.description   = 'Punto de mira láser rojo.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['cobre']     = 2,
        ['circuitos'] = 2,
        ['vidrio']    = 2,
    }
    BLUEPRINT.result        = { ['att_laser'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_mira_holografica'
    BLUEPRINT.name          = 'Mira Holográfica'
    BLUEPRINT.description   = 'Colimador de punto rojo. Requiere materiales de calidad.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 2
    BLUEPRINT.tools         = { 'destornillador', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['vidrio']                = 2,
        ['circuitos']             = 2,
        ['cobre']                 = 2,
        ['hierro']                = 2,
    }
    BLUEPRINT.result        = { ['att_mira_holografica'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ARMAS — TIER 3  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_kalash'
    BLUEPRINT.name          = 'Kalash'
    BLUEPRINT.description   = 'Fusil de asalto militar. El arma más común de la zona.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'herramientas_precision', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']                = 4,
        ['componentes_militares'] = 1,
        ['muelles']               = 2,
        ['tornillos']             = 4,
        ['madera']                = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_ak'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_vsv'
    BLUEPRINT.name          = 'VSV'
    BLUEPRINT.description   = 'Rifle de francotirador compacto. Alta precisión a larga distancia.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'herramientas_precision', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']                = 5,
        ['componentes_militares'] = 1,
        ['engranajes']            = 4,
        ['muelles']               = 2,
        ['madera']                = 2,
    }
    BLUEPRINT.result        = { ['cw_metro2033_vsv'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_saiga'
    BLUEPRINT.name          = 'Saiga'
    BLUEPRINT.description   = 'Escopeta semiautomática militar. Devastadora en espacios cerrados.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'herramientas_precision', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']                = 5,
        ['componentes_militares'] = 1,
        ['muelles']               = 4,
        ['tornillos']             = 3,
        ['madera']                = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_saiga'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_ventil'
    BLUEPRINT.name          = 'Ventil'
    BLUEPRINT.description   = 'Rifle neumático pesado. El más costoso de fabricar en la zona.'
    BLUEPRINT.model         = 'models/props_junk/cardboard_box001a.mdl'
    BLUEPRINT.category      = 'Armas'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'herramientas_precision', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['hierro']                = 8,
        ['componentes_militares'] = 1,
        ['muelles']               = 3,
        ['aleacion_reforzada']    = 2,
        ['tornillos']             = 4,
        ['madera']                = 2,
    }
    BLUEPRINT.result        = { ['cw_kry_metro_2k33_ventil'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  ACCESORIOS — TIER 3  (armero) → mesa armas_armaduras
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_cargador_extendido'
    BLUEPRINT.name          = 'Cargador Extendido'
    BLUEPRINT.description   = 'Cargador de alta capacidad para rifles y escopetas.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'destornillador', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['placas_metalicas'] = 2,
        ['muelles']          = 6,
        ['tornillos']        = 2,
    }
    BLUEPRINT.result        = { ['att_cargador_extendido'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_mira_x4_ventil'
    BLUEPRINT.name          = 'Mira x4 (Ventil)'
    BLUEPRINT.description   = 'Mira telescópica de 4 aumentos adaptada para la Ventil.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'herramientas_precision', 'destornillador' }
    BLUEPRINT.ingredients   = {
        ['vidrio']                = 8,
        ['hierro']                = 3,
        ['componentes_militares'] = 1,
    }
    BLUEPRINT.result        = { ['att_mira_x4_ventil'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
    BLUEPRINT.uniqueID      = 'craft_att_compensador'
    BLUEPRINT.name          = 'Compensador/Silenciador'
    BLUEPRINT.description   = 'Compensador de retroceso para fusiles de Tier 3.'
    BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
    BLUEPRINT.category      = 'Accesorios'
    BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
    BLUEPRINT.hidden        = false
    BLUEPRINT.icon          = 'efgui/icons/craft/guns.png'
    BLUEPRINT.mesa          = 'armas_armaduras'
    BLUEPRINT.oficio        = 'armero'
    BLUEPRINT.tierRequired  = 3
    BLUEPRINT.tools         = { 'destornillador', 'herramientas_precision' }
    BLUEPRINT.ingredients   = {
        ['hierro']                = 6,
        ['tela']                  = 4,
        ['tornillos']             = 4,
        ['componentes_militares'] = 1,
    }
    BLUEPRINT.result        = { ['att_compensador'] = 1 }
BLUEPRINT:Append()
