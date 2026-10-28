local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  MOCHILAS — crafteables por el SASTRE → mesa armas_armaduras
--  Distintos tamaños gated por tier del oficio (sin decoración de tier
--  en la UI: se diferencian por nombre y capacidad).
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID     = 'craft_morral'
	BLUEPRINT.name         = 'Morral de Tela'
	BLUEPRINT.description  = 'Un morral de tela con 12 huecos de almacenaje. Lo básico para no ir con las manos vacías.'
	BLUEPRINT.model        = 'models/z-o-m-b-i-e/metro_ll/equipment/m_ll_wpn_rukzak_01.mdl'
	BLUEPRINT.category     = 'Mochilas'
	BLUEPRINT.craftSound   = 'metroui/craft.wav'
	BLUEPRINT.hidden       = false
	BLUEPRINT.icon         = 'metroui/icons/icon_inventory64.png'
	BLUEPRINT.mesa         = 'armas_armaduras'
	BLUEPRINT.oficio       = 'sastre'
	BLUEPRINT.tierRequired = 1
	BLUEPRINT.tools        = {}
	BLUEPRINT.ingredients  = {
		['tela']  = 4,
		['cuero'] = 2,
	}
	BLUEPRINT.result       = { ['morral'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID     = 'craft_mochila_cuero'
	BLUEPRINT.name         = 'Mochila de Cuero'
	BLUEPRINT.description  = 'Mochila de cuero curtido con 18 huecos. Fiable y resistente para largas travesías.'
	BLUEPRINT.model        = 'models/devcon/mrp/props/backpack.mdl'
	BLUEPRINT.category     = 'Mochilas'
	BLUEPRINT.craftSound   = 'metroui/craft.wav'
	BLUEPRINT.hidden       = false
	BLUEPRINT.icon         = 'metroui/icons/icon_inventory64.png'
	BLUEPRINT.mesa         = 'armas_armaduras'
	BLUEPRINT.oficio       = 'sastre'
	BLUEPRINT.tierRequired = 2
	BLUEPRINT.tools        = { 'llave_inglesa' }
	BLUEPRINT.ingredients  = {
		['cuero'] = 6,
		['tela']  = 3,
	}
	BLUEPRINT.result       = { ['mochila_cuero'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID     = 'craft_mochila_militar'
	BLUEPRINT.name         = 'Mochila Militar'
	BLUEPRINT.description  = 'Mochila de asalto con armazón rígido y 24 huecos. El sueño de todo superviviente.'
	BLUEPRINT.model        = 'models/z-o-m-b-i-e/metro_ll/equipment/m_ll_wpn_rukzak_02.mdl'
	BLUEPRINT.category     = 'Mochilas'
	BLUEPRINT.craftSound   = 'metroui/craft.wav'
	BLUEPRINT.hidden       = false
	BLUEPRINT.icon         = 'metroui/icons/icon_inventory64.png'
	BLUEPRINT.mesa         = 'armas_armaduras'
	BLUEPRINT.oficio       = 'sastre'
	BLUEPRINT.tierRequired = 3
	BLUEPRINT.tools        = { 'llave_inglesa', 'herramientas_precision' }
	BLUEPRINT.ingredients  = {
		['cuero']            = 8,
		['tela']             = 6,
		['placas_metalicas'] = 2,
		['tornillos']        = 4,
	}
	BLUEPRINT.result       = { ['mochila_militar'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID     = 'craft_kit_reparacion_armadura_sastre'
	BLUEPRINT.name         = 'Kit de Reparación de Armadura'
	BLUEPRINT.description  = 'Un conjunto de herramientas y materiales improvisados para reparar armaduras dañadas.'
	BLUEPRINT.model        = 'models/lostsignalproject/items/repair/sewing_kit_a.mdl'
	BLUEPRINT.category     = 'Accesorios'
	BLUEPRINT.craftSound   = 'metroui/craft.wav'
	BLUEPRINT.hidden       = false
	BLUEPRINT.icon         = 'metroui/icons/craft/armor.png'
	BLUEPRINT.mesa         = 'armas_armaduras'
	BLUEPRINT.oficio       = 'sastre'
	BLUEPRINT.tierRequired = 1
	BLUEPRINT.tools        = {}
	BLUEPRINT.ingredients  = {
		['tela']  = 3,
		['cuero'] = 2,
	}
	BLUEPRINT.result       = { ['kit_reparacion_armadura'] = 1 }
BLUEPRINT:Append()
