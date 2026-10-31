-- ============================================================================
--  Objetos de botín de EFT que no existían como ítems de Helix: objetos de
--  valor, inteligencia, electrónica, trueque y suministros médicos.
--  Tamaño, peso e icono salen de eft_items.json (efg_eftdata, carga antes);
--  nombre, descripción, categoría y precio son de aquí.
--  Precios en RUB: aproximación al valor de venta en EFT. [VERIFICAR]
--
--  Formato: {uniqueID, nombre, categoría, precio, modelo, descripción}
--  El uniqueID es la clave de la wiki en eft_items.json.
-- ============================================================================

local LOOT = ix.efg.loot

local MODEL_SMALL = "models/props_lab/box01a.mdl"
local MODEL_ELECTRONIC = "models/props_lab/reciever01d.mdl"
local MODEL_PAPER = "models/props_lab/clipboard.mdl"
local MODEL_VALUABLE = "models/props_c17/oildrum001_explosive.mdl"
local MODEL_MED = "models/healthvial.mdl"
local MODEL_TOOL = "models/props_c17/tools_wrench01a.mdl"

LOOT.Items = {
	-- Objetos de valor
	{"gingy_keychain", "Llavero de Gingy", "Objetos de valor", 25000, MODEL_SMALL, "Un llavero con forma de galleta de jengibre. Los coleccionistas pagan bien por él."},
	{"golden_neck_chain", "Cadena de oro", "Objetos de valor", 40000, MODEL_SMALL, "Cadena de oro para el cuello. Fácil de vender a cualquier comerciante."},
	{"roler_submariner_gold_wrist_watch", "Reloj de oro Roler Submariner", "Objetos de valor", 75000, MODEL_SMALL, "Reloj de pulsera de oro. Una imitación cara, pero de oro de verdad."},
	{"golden_rooster_figurine", "Figura de gallo dorado", "Objetos de valor", 90000, MODEL_VALUABLE, "Figura decorativa pesada y llamativa. Muy buscada para trueques."},
	-- Carteras: llevan rublos dentro (dato count); "Vaciar" los pasa al inventario
	{"simple_wallet", "Cartera", "Dinero", 5000, MODEL_SMALL, "Cartera de cuero gastada.", {wallet = true}},
	{"wz_wallet", "Cartera WZ", "Dinero", 12000, MODEL_SMALL, "Cartera de marca con varios compartimentos.", {wallet = true}},
	-- Inteligencia
	{"slim_diary", "Diario fino", "Información", 25000, MODEL_PAPER, "Un diario con anotaciones de alguien que conocía bien la zona."},
	{"secure_flash_drive", "Memoria USB segura", "Información", 45000, MODEL_SMALL, "Memoria USB cifrada. Puede contener datos de TerraGroup."},
	{"sas_drive", "Disco SAS", "Información", 60000, MODEL_ELECTRONIC, "Disco duro de servidor. Los comerciantes quieren saber qué guarda."},
	{"intelligence_folder", "Carpeta de inteligencia", "Información", 200000, MODEL_PAPER, "Carpeta con documentos clasificados. Muy valiosa para el Centro de inteligencia."},
	{"military_flash_drive", "Memoria USB militar", "Información", 150000, MODEL_SMALL, "Memoria USB de uso militar con información sensible."},
	-- Electrónica
	{"bundle_of_wires", "Manojo de cables", "Electrónica", 9000, MODEL_ELECTRONIC, "Cables sueltos de distintos colores."},
	{"capacitors", "Condensadores", "Electrónica", 12000, MODEL_ELECTRONIC, "Condensadores recuperados de aparatos rotos."},
	{"printed_circuit_board", "Placa de circuito impreso", "Electrónica", 15000, MODEL_ELECTRONIC, "Placa de circuito de un aparato doméstico."},
	{"cpu_fan", "Ventilador de CPU", "Electrónica", 20000, MODEL_ELECTRONIC, "Ventilador de procesador. Útil para la granja de bitcoin."},
	{"broken_gphone_smartphone", "Móvil GPhone roto", "Electrónica", 25000, MODEL_ELECTRONIC, "Teléfono con la pantalla rota. Las piezas siguen sirviendo."},
	{"phase_control_relay", "Relé de control de fase", "Electrónica", 25000, MODEL_ELECTRONIC, "Relé industrial."},
	{"tetriz_portable_game_console", "Consola portátil Tetriz", "Electrónica", 40000, MODEL_ELECTRONIC, "Consola portátil antigua. Funciona con pilas."},
	{"military_cable", "Cable militar", "Electrónica", 70000, MODEL_ELECTRONIC, "Cable de uso militar, apantallado y resistente."},
	{"military_power_filter", "Filtro de energía militar", "Electrónica", 60000, MODEL_ELECTRONIC, "Filtro de alimentación de equipos militares."},
	-- Trueque
	{"bolts", "Pernos", "Trueque", 15000, MODEL_TOOL, "Una bolsa de pernos de varios tamaños."},
	{"pack_of_screws", "Paquete de tornillos", "Trueque", 12000, MODEL_TOOL, "Tornillos para madera y metal."},
	{"pack_of_nails", "Paquete de clavos", "Trueque", 10000, MODEL_TOOL, "Clavos de construcción."},
	{"duct_tape", "Cinta americana", "Trueque", 14000, MODEL_SMALL, "Cinta adhesiva resistente. Sirve para casi todo."},
	{"insulating_tape", "Cinta aislante", "Trueque", 8000, MODEL_SMALL, "Cinta aislante para cables."},
	{"corrugated_hose", "Manguera corrugada", "Trueque", 25000, MODEL_TOOL, "Manguera flexible de plástico."},
	{"toilet_paper", "Papel higiénico", "Trueque", 9000, MODEL_SMALL, "Un rollo de papel higiénico. Escaso en Tarkov."},
	{"wd_40_100ml", "WD-40 (100 ml)", "Trueque", 20000, MODEL_SMALL, "Lubricante y desengrasante en espray."},
	{"light_bulb", "Bombilla", "Trueque", 15000, MODEL_SMALL, "Bombilla incandescente."},
	{"spark_plug", "Bujía", "Trueque", 12000, MODEL_TOOL, "Bujía de motor de gasolina."},
	-- Suministros médicos
	{"bottle_of_hydrogen_peroxide", "Frasco de agua oxigenada", "Suministros médicos", 15000, MODEL_MED, "Desinfectante para heridas."},
	{"pile_of_meds", "Montón de medicinas", "Suministros médicos", 25000, MODEL_MED, "Pastillas y blísteres sin etiqueta."},
	{"ophthalmoscope", "Oftalmoscopio", "Suministros médicos", 40000, MODEL_MED, "Instrumento médico para examinar el ojo."},
	{"ledx_skin_transilluminator", "Transiluminador LEDX", "Suministros médicos", 900000, MODEL_MED, "Aparato médico de alta gama. Uno de los objetos más caros de Tarkov."}
}

local function registerWallet(ITEM)
	ITEM.efgWallet = true

	function ITEM:GetDescription()
		return ("%s\n\nDentro: %s RUB"):format(self.description, string.Comma(self:GetData("count", 0)))
	end

	ITEM.functions.Vaciar = {
		name = "Vaciar",
		icon = "icon16/money.png",
		OnCanRun = function(item)
			return !IsValid(item.entity) and item:GetData("count", 0) > 0
		end,
		OnRun = function(item)
			local client = item.player
			local character = IsValid(client) and client:GetCharacter()
			local amount = item:GetData("count", 0)

			if (!character or amount <= 0) then return false end

			local inventory = character:GetInventory()

			if (!inventory or !inventory:Add("bala", 1, {count = amount})) then
				client:NotifyLocalized("efgLootNoSpace")
				return false
			end

			item:SetData("count", 0)
			client:NotifyLocalized("efgLootWalletEmptied", string.Comma(amount))

			return false
		end
	}
end

for _, def in ipairs(LOOT.Items) do
	local uniqueID, name, category, price, model, description, extra = unpack(def)

	-- no pisar un ítem que otro plugin ya defina con ese uniqueID
	if (!ix.item.list[uniqueID]) then
		local ITEM = ix.item.Register(uniqueID, nil, false, nil, true)

		ITEM.name = name
		ITEM.description = description
		ITEM.category = category
		ITEM.price = price
		ITEM.model = model
		ITEM.width = 1
		ITEM.height = 1
		ITEM.weight = 0.1
		ITEM.isEFGLoot = true

		if (ix.eftdata and ix.eftdata.ApplyToItem) then
			ix.eftdata.ApplyToItem(ITEM, uniqueID)
		end

		if (extra and extra.wallet) then
			registerWallet(ITEM)
		end
	end
end
