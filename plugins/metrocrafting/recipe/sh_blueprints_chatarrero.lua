local BLUEPRINT = nil

-- 50% de probabilidad de producir la mitad extra en recetas Tier 1 cuando el chatarrero está en Tier 3
local function bonusTier3(self, client)
	local char = client:GetCharacter()
	if (not char) then return end
	if ((char:GetChatarreroTier() or 0) < 3) then return end
	local inv = char:GetInventory()
	for result, amount in pairs(self.result) do
		local n = type(amount) == 'table' and amount[1] or amount
		local bonus = math.ceil(n / 2)
		if (math.random() < 0.5) then
			for _ = 1, bonus do
				if (not inv:Add(result)) then
					ix.item.Spawn(result, client)
				end
			end
		end
	end
end

-- ════════════════════════════════════════════════════════════════════
--  RECICLAJE BÁSICO — SIN OFICIO  → mesa reciclaje
--  Cualquier jugador puede refinar materiales en bruto
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_reciclar_hierro'
	BLUEPRINT.name          = 'Hierro'
	BLUEPRINT.description   = 'Fragmentos metálicos fundidos y prensados a partir de piezas en desuso.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/ballistic3.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['piezas_metalicas'] = 2,
	}
	BLUEPRINT.result        = { ['hierro'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_reciclar_madera'
	BLUEPRINT.name          = 'Madera'
	BLUEPRINT.description   = 'Tablones aprovechables extraídos de madera húmeda y podrida.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/box_wood_07.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['madera_humeda'] = 2,
	}
	BLUEPRINT.result        = { ['madera'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_reciclar_tela'
	BLUEPRINT.name          = 'Tela'
	BLUEPRINT.description   = 'Tejido utilizable extraído y limpiado de retales andrajosos.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/retardant12.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['retales_tela'] = 2,
	}
	BLUEPRINT.result        = { ['tela'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_reciclar_cuero'
	BLUEPRINT.name          = 'Cuero'
	BLUEPRINT.description   = 'Cuero tratado a partir de piel de mutante curtida y limpiada.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/fabrics2.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['piel_mutante'] = 2,
	}
	BLUEPRINT.result        = { ['cuero'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  CHATARRERO — TIER 1  → mesa reciclaje
--  Tier 3: 50% prob. de +50% producción gracias a OnCraft
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_plomo'
	BLUEPRINT.name          = 'Plomo'
	BLUEPRINT.description   = 'Plomo extraído de cargadores dañados. Material esencial para proyectiles artesanales.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/damaged_ammo.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['cargador_danado'] = 2,
	}
	BLUEPRINT.result        = { ['plomo'] = 2 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_tornillos'
	BLUEPRINT.name          = 'Tornillos'
	BLUEPRINT.description   = 'Tornillos recuperados y enderezados de piezas metálicas desechadas.'
	BLUEPRINT.model         = 'models/illusion/eftcontainers/screwnutbolt.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['piezas_metalicas'] = 2,
	}
	BLUEPRINT.result        = { ['tornillos'] = 4 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_muelles'
	BLUEPRINT.name          = 'Muelles'
	BLUEPRINT.description   = 'Resortes y muelles extraídos de componentes mecánicos en desuso.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/jar.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['componentes_mecanicos'] = 2,
	}
	BLUEPRINT.result        = { ['muelles'] = 3 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_plastico'
	BLUEPRINT.name          = 'Plástico'
	BLUEPRINT.description   = 'Plástico fundido y moldeado a partir de restos mezclados y botellas de lejía.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/plastic.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['restos_mezclados'] = 2,
		['botella_lejia']    = 2,
	}
	BLUEPRINT.result        = { ['plastico'] = 2 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_vidrio'
	BLUEPRINT.name          = 'Vidrio'
	BLUEPRINT.description   = 'Fragmentos de vidrio limpios y procesados de botellas de cristal rotas.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/jar.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['botella_cristal'] = 2,
	}
	BLUEPRINT.result        = { ['vidrio'] = 2 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_polvora'
	BLUEPRINT.name          = 'Pólvora'
	BLUEPRINT.description   = 'Pólvora recuperada de cargadores dañados y restos mezclados. Base para munición artesanal.'
	BLUEPRINT.model         = 'models/illusion/eftcontainers/gpblue.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 1
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['cargador_danado']  = 2,
		['restos_mezclados'] = 2,
	}
	BLUEPRINT.result        = { ['polvora'] = 3 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  CHATARRERO — TIER 2  → mesa reciclaje
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_cobre'
	BLUEPRINT.name          = 'Cobre'
	BLUEPRINT.description   = 'Cobre extraído de cables y circuitos de basura electrónica.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/quest/wire.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['basura_electronica'] = 2,
	}
	BLUEPRINT.result        = { ['cobre'] = 2 }
	BLUEPRINT.OnCraft       = bonusTier3
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_placas'
	BLUEPRINT.name          = 'Placas Metálicas'
	BLUEPRINT.description   = 'Planchas de metal reforzado forjadas a partir de hierro y tornillos.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/outfit_parts/ballistic1.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['hierro']    = 3,
		['tornillos'] = 2,
	}
	BLUEPRINT.result        = { ['placas_metalicas'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_circuitos'
	BLUEPRINT.name          = 'Circuitos'
	BLUEPRINT.description   = 'Circuitos funcionales soldados y recuperados desde basura electrónica con cobre.'
	BLUEPRINT.model         = 'models/illusion/eftcontainers/circuitboard.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['cobre']              = 2,
		['basura_electronica'] = 2,
	}
	BLUEPRINT.result        = { ['circuitos'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_engranajes'
	BLUEPRINT.name          = 'Engranajes'
	BLUEPRINT.description   = 'Engranajes torneados a partir de hierro bruto y muelles recuperados.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/jar.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['componentes_mecanicos']  = 4,
	}
	BLUEPRINT.result        = { ['engranajes'] = 2 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_carbonvegetal'
	BLUEPRINT.name          = 'Carbón Vegetal'
	BLUEPRINT.description   = 'Carbón producido mediante pirólisis de madera húmeda a alta temperatura.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/charcoal.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 2
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['madera_humeda'] = 3,
	}
	BLUEPRINT.result        = { ['carbonvegetal'] = 1 }
BLUEPRINT:Append()

-- ════════════════════════════════════════════════════════════════════
--  CHATARRERO — TIER 3  → mesa reciclaje
-- ════════════════════════════════════════════════════════════════════

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_aleacion'
	BLUEPRINT.name          = 'Aleación Reforzada'
	BLUEPRINT.description   = 'Aleación metálica avanzada obtenida fundiendo hierro y placas con cobre. El material más resistente que puede forjar un chatarrero experto.'
	BLUEPRINT.model         = 'models/illusion/eftcontainers/armorrepair.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 3
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['hierro']           = 3,
		['placas_metalicas'] = 2,
		['cobre']            = 2,
	}
	BLUEPRINT.result        = { ['aleacion_reforzada'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_componentes_militares'
	BLUEPRINT.name          = 'Componentes Militares'
	BLUEPRINT.description   = 'Piezas de grado militar ensambladas a partir de placas mecanizadas, engranajes de precisión y resortes de alta presión. Solo un chatarrero experto sabe replicarlas.'
	BLUEPRINT.model         = 'models/lostsignalproject/items/misc/grooming.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 3
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['placas_metalicas'] = 2,
		['engranajes']       = 2,
		['muelles']          = 3,
	}
	BLUEPRINT.result        = { ['componentes_militares'] = 1 }
BLUEPRINT:Append()

BLUEPRINT = ix.blueprint:New()
	BLUEPRINT.uniqueID      = 'craft_chata_bateria'
	BLUEPRINT.name          = 'Batería de coche'
	BLUEPRINT.description   = 'Batería reacondicionada montando celdas de cobre, circuitos recuperados y una carcasa de plástico. Fuente de energía preciada en el metro.'
	BLUEPRINT.model         = 'models/illusion/eftcontainers/carbattery.mdl'
	BLUEPRINT.category      = 'Materiales'
	BLUEPRINT.craftSound    = 'ui/buttonclick.wav'
	BLUEPRINT.hidden        = false
	BLUEPRINT.icon          = 'efgui/icons/craft/ammo.png'
	BLUEPRINT.mesa          = 'reciclaje'
	BLUEPRINT.oficio        = 'chatarrero'
	BLUEPRINT.tierRequired  = 3
	BLUEPRINT.tools         = {}
	BLUEPRINT.ingredients   = {
		['cobre']     = 3,
		['circuitos'] = 2,
		['plastico']  = 2,
	}
	BLUEPRINT.result        = { ['bateria'] = 1 }
BLUEPRINT:Append()
