local BLUEPRINT = nil

-- ════════════════════════════════════════════════════════════════════
--  MANUALES DE OFICIO → mesa reciclaje
--  Convierten los Datos Técnicos de cada oficio en el manual de estudio
--  correspondiente. Solo permiten progresar al tier inmediatamente
--  superior al actual (Tier 1 → Manual T2, Tier 2 → Manual T3).
-- ════════════════════════════════════════════════════════════════════

-- ───────────────────────  ARMERO  ───────────────────────

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_armero_t2'
	BLUEPRINT.name          = 'Manual: Armero Nivel 2'
	BLUEPRINT.description   = 'Manual técnico avanzado de armería. Permite fabricar armamento de grado medio.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'armero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_armero'] = 6,
	}
	BLUEPRINT.result        = { ['aprendizaje_armero_t2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_armero_t3'
	BLUEPRINT.name          = 'Manual: Armero Nivel 3'
	BLUEPRINT.description   = 'Manual de maestría en armería. Permite fabricar las armas más complejas del metro.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'armero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_armero'] = 10,
		['componentes_militares'] = 2,
	}
	BLUEPRINT.result        = { ['aprendizaje_armero_t3'] = 1 }
BLUEPRINT:Append()

-- ───────────────────────  CHATARRERO  ───────────────────────

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_chatarrero_t2'
	BLUEPRINT.name          = 'Manual: Chatarrero Nivel 2'
	BLUEPRINT.description   = 'Guía de ingeniería improvisada. Permite fabricar estructuras y equipos más complejos con chatarra.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_reciclaje'] = 6,
	}
	BLUEPRINT.result        = { ['aprendizaje_chatarrero_t2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_chatarrero_t3'
	BLUEPRINT.name          = 'Manual: Chatarrero Nivel 3'
	BLUEPRINT.description   = 'Compendio de ingeniería de las profundidades. Dominio total de la chatarra del metro.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_reciclaje'] = 10,
		['plano_prototipo'] = 2,
	}
	BLUEPRINT.result        = { ['aprendizaje_chatarrero_t3'] = 1 }
BLUEPRINT:Append()

-- ───────────────────────  MÉDICO  ───────────────────────

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_medico_t2'
	BLUEPRINT.name          = 'Manual: Médico Nivel 2'
	BLUEPRINT.description   = 'Tratado de medicina avanzada del metro. Permite preparar medicamentos más complejos.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'medico'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_medicina'] = 6,
	}
	BLUEPRINT.result        = { ['aprendizaje_medico_t2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_medico_t3'
	BLUEPRINT.name          = 'Manual: Médico Nivel 3'
	BLUEPRINT.description   = 'Compendio de cirugía y farmacología del metro. Permite las síntesis médicas más avanzadas.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'medico'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_medicina'] = 10,
		['desfibrilador_roto'] = 2,
	}
	BLUEPRINT.result        = { ['aprendizaje_medico_t3'] = 1 }
BLUEPRINT:Append()

-- ───────────────────────  QUÍMICO  ───────────────────────

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_quimico_t2'
	BLUEPRINT.name          = 'Manual: Químico Nivel 2'
	BLUEPRINT.description   = 'Tratado de química aplicada. Permite procesar materiales más complejos en el metro.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'quimico'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_quimico'] = 6,
	}
	BLUEPRINT.result        = { ['aprendizaje_quimico_t2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_quimico_t3'
	BLUEPRINT.name          = 'Manual: Químico Nivel 3'
	BLUEPRINT.description   = 'Compendio de síntesis química avanzada. Permite procesar los materiales más peligrosos.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'quimico'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_quimico'] = 10,
		['bateria'] = 2,
	}
	BLUEPRINT.result        = { ['aprendizaje_quimico_t3'] = 1 }
BLUEPRINT:Append()

-- ───────────────────────  SASTRE  ───────────────────────

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_sastre_t2'
	BLUEPRINT.name          = 'Manual: Sastre Nivel 2'
	BLUEPRINT.description   = 'Guía de confección avanzada con técnicas para trabajar cuero endurecido y materiales compuestos.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'sastre'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_sastre'] = 6,
	}
	BLUEPRINT.result        = { ['aprendizaje_sastre_t2'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_aprendizaje_sastre_t3'
	BLUEPRINT.name          = 'Manual: Sastre Nivel 3'
	BLUEPRINT.description   = 'Tratado de maestría en confección con los secretos para crear equipamiento de protección de alto rendimiento.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/document_01.mdl'
	BLUEPRINT.category      = 'Aprendizaje'
	BLUEPRINT.craftSound    = 'metroui/craft.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'metroui/icons/icon_quest64.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'sastre'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['datos_sastre'] = 10,
		['aleacion_reforzada'] = 2,
	}
	BLUEPRINT.result        = { ['aprendizaje_sastre_t3'] = 1 }
BLUEPRINT:Append()
