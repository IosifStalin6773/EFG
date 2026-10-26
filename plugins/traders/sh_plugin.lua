PLUGIN.name        = "Traders"
PLUGIN.author      = "Metro RP By Cono y Manperra, adaptado a EFG"
PLUGIN.description = "Comerciantes (El Intendente, La Doctora, El Contrabandista...) con niveles de lealtad ligados al nivel del PMC, stock físico y panel de administración."

ix.traders = ix.traders or {}

-- ¿Puede el jugador usar este comerciante? Cerca del NPC, o desde el menú
-- principal (lobby de EFG, ver efg_pmc) mientras no esté en una raid.
function ix.traders.CanReach(client, traderEnt)
	if (client:GetPos():Distance(traderEnt:GetPos()) <= 200) then
		return true
	end

	return client.efgLobbyTrader == traderEnt and (client.efgLobbyTraderUntil or 0) > CurTime()
		and !(client.InRaid and client:InRaid())
end

-- Comerciantes de EFT (la clave es la "facción" del trader)
ix.traders.factions = {
	"prapor", "therapist", "fence", "skier", "peacekeeper", "mechanic", "ragman", "jaeger"
}

-- Slots máximos por defecto para cualquier trader
ix.config.Add("traders_maxSlots", 20, "Número máximo de slots de inventario de un trader por defecto.", nil, {
	data     = {min = 5, max = 100},
	category = "Traders"
})

-- Ciclo de restock (6 horas por defecto): al completarse, el stock de admin
-- vuelve de golpe al máximo y se borra todo el stock vendido por jugadores.
ix.config.Add("traders_restockInterval", 21600, "Segundos entre cada restock completo de un trader (al terminar el ciclo el stock de admin vuelve al máximo y se borra el stock vendido por jugadores).", nil, {
	data     = {min = 600, max = 86400},
	category = "Traders"
})

-- Margen aleatorio añadido al ciclo (0 a este valor) para que los jugadores no
-- puedan calcular la hora exacta del restock y camperlo.
ix.config.Add("traders_restockJitter", 1800, "Margen aleatorio en segundos (0 a este valor) que se suma al ciclo de restock para que no se pueda predecir la hora exacta.", nil, {
	data     = {min = 0, max = 7200},
	category = "Traders"
})

-- Granularidad de la comprobación del ciclo (no es restock progresivo, solo
-- cada cuánto se revisa si ya toca reponer).
ix.config.Add("traders_restockTickInterval", 60, "Cada cuántos segundos se comprueba si ya toca el restock del ciclo.", nil, {
	data     = {min = 15, max = 600},
	category = "Traders"
})

-- Variable de personaje: reputación por facción almacenada como JSON
ix.char.RegisterVar("traderRep", {
	field     = "trader_rep",
	fieldType = ix.type.string,
	default   = "{}",
	bNoDisplay = true,
	OnGet = function(self, default)
		local raw = self.vars["traderRep"] or default
		if (type(raw) == "string") then
			return util.JSONToTable(raw) or {}
		end
		return raw
	end,
	OnSet = function(self, value)
		if (type(value) == "table") then
			self.vars["traderRep"] = util.TableToJSON(value)
		else
			self.vars["traderRep"] = value
		end
	end,
})

-- Niveles de lealtad (LL) de EFT. La reputación (0-1000) sube comerciando y con
-- misiones; para pasar de nivel hace falta además el nivel de PMC (minLevel).
-- minRep de cada slot del trader marca a partir de qué LL se vende: LL2 = 200,
-- LL3 = 500, LL4 = 800.
ix.traders.repLevels = {
	{min = 0,   max = 199,  minLevel = 1,  name = "Lealtad 1", discount = 0,  sellBonus = 0,  color = Color(150, 150, 150)},
	{min = 200, max = 499,  minLevel = 15, name = "Lealtad 2", discount = 5,  sellBonus = 5,  color = Color(100, 200, 100)},
	{min = 500, max = 799,  minLevel = 26, name = "Lealtad 3", discount = 10, sellBonus = 10, color = Color(80, 160, 220)},
	{min = 800, max = 1000, minLevel = 36, name = "Lealtad 4", discount = 15, sellBonus = 15, color = Color(200, 160, 50)},
}

-- Devuelve la tabla de nivel correspondiente a una puntuación de rep
function ix.traders.GetRepLevel(rep)
	for i = #ix.traders.repLevels, 1, -1 do
		if (rep >= ix.traders.repLevels[i].min) then
			return ix.traders.repLevels[i]
		end
	end
	return ix.traders.repLevels[1]
end

-- Reputación que cuenta de verdad: si el PMC no tiene nivel para el siguiente
-- LL, se queda en el tope del LL que sí tiene (así minRep bloquea el stock).
function ix.traders.GetEffectiveRep(character, factionKey)
	local traderRep = character:GetTraderRep() or {}
	local rep = math.Clamp(traderRep[factionKey] or 0, 0, 1000)
	local level = character.GetEFGLevel and character:GetEFGLevel() or 1

	for i = #ix.traders.repLevels, 2, -1 do
		local entry = ix.traders.repLevels[i]

		if (rep >= entry.min and level < entry.minLevel) then
			rep = entry.min - 1
		end
	end

	return rep
end

-- Devuelve el porcentaje de reputación (0-100)
function ix.traders.GetRepPercent(rep)
	return math.floor((math.Clamp(rep, 0, 1000) / 1000) * 100)
end

-- Nombre visible de cada comerciante
ix.traders.names = {
	prapor      = "El Intendente",
	therapist   = "La Doctora",
	fence       = "El Chatarrero",
	skier       = "El Contrabandista",
	peacekeeper = "El Agregado",
	mechanic    = "El Armero",
	ragman      = "La Costurera",
	jaeger      = "El Montero",
}

ix.traders.lore = {
	prapor      = "Llevaba el almacén de intendencia del cuartel cuando cerraron la zona. Lo que queda de aquellas estanterías lo vendo yo: armas de reglamento, munición y granadas. Trabaja para mí y no te faltará de nada.",
	therapist   = "Fui jefa de planta en el hospital comarcal hasta que lo evacuaron. Medicinas, comida y material de cura. La zona necesita médicos más que soldados, pero vosotros pagáis mejor.",
	fence       = "Nombre no tengo, contactos sí. Compro lo que traigas, sea de quien sea, y vendo lo que traen otros. Si te ensañas con los saqueadores, me acabaré enterando.",
	skier       = "Antes sellaba papeles en la aduana del puerto. Ahora muevo cajas que nadie ha sellado. Armas de fuera, recambios, contenedores... lo que sea, si el precio es justo.",
	peacekeeper = "Me mandaron aquí con la misión internacional y me quedé cuando se fueron los demás. Cobro en divisa y trabajo con material de importación. Ayúdame a sacar ciertas cosas de la zona y te trataré bien.",
	mechanic    = "Pasé veinte años en la cadena de montaje de la fábrica de armas. Aquí monto, modifico y reparo. Si quieres un arma que funcione de verdad, ven a verme.",
	ragman      = "Tenía un taller de costura en la galería comercial. Ahora remiendo y vendo mochilas, chalecos y cascos. Aquí la moda es seguir vivo.",
	jaeger      = "Fui guarda forestal del monte antes de que todo se torciera. Vendo lo que hace falta para aguantar ahí fuera y pago por limpiar los caminos de escoria.",
}

-- Saludos según reputación (de mayor a menor umbral)
ix.traders.greetings = {
	prapor = {
		{min = 800, text = "¡Mi mejor soldado! Para ti tengo lo bueno, lo que no vendo a cualquiera."},
		{min = 500, text = "Ah, el que siempre vuelve. Bien, bien. ¿Qué necesitas?"},
		{min = 200, text = "Te veo más curtido. Sigue trabajando para mí y te irá bien."},
		{min = 0,   text = "¿Otro mercenario? Bueno, el dinero es dinero. Mira lo que tengo."},
	},
	therapist = {
		{min = 800, text = "Siempre es un placer verte entero. Tengo lo mejor de la farmacia para ti."},
		{min = 500, text = "Vuelves vivo, eso me gusta. ¿Qué te hace falta?"},
		{min = 200, text = "Hola de nuevo. Cuídate ahí fuera, no tengo tiempo para coserte."},
		{min = 0,   text = "Buenas. Medicinas y comida, no hago milagros. ¿Qué buscas?"},
	},
	fence = {
		{min = 0, text = "Compro de todo. Vendo de todo. No pregunto de dónde viene."},
	},
	skier = {
		{min = 800, text = "¡Socio! Para ti, los mejores contactos del puerto."},
		{min = 500, text = "Hombre, mi cliente favorito. Mira lo que acaba de llegar."},
		{min = 200, text = "Te recuerdo. Pagas bien. Eso me gusta."},
		{min = 0,   text = "¿Qué miras? Si tienes dinero, hablamos. Si no, fuera."},
	},
	peacekeeper = {
		{min = 800, text = "Mi amigo. Para ti, el mejor material de importación."},
		{min = 500, text = "Hola, socio. Tengo cosas nuevas del convoy."},
		{min = 200, text = "Ah, tú otra vez. Los negocios son los negocios."},
		{min = 0,   text = "Buenas. Equipo de importación, precios en divisa. ¿Te interesa?"},
	},
	mechanic = {
		{min = 800, text = "Tengo un par de proyectos que solo te enseñaría a ti."},
		{min = 500, text = "Ah, mi cliente fiable. ¿Qué montamos hoy?"},
		{min = 200, text = "Hola. Dime qué necesitas, estoy ocupado."},
		{min = 0,   text = "Habla rápido. Tengo trabajo."},
	},
	ragman = {
		{min = 800, text = "¡Mi cliente estrella! Lo más exclusivo de la temporada."},
		{min = 500, text = "Tú sí que sabes vestir para la zona. ¿Qué te llevas?"},
		{min = 200, text = "Bienvenido otra vez. Mochilas, chalecos, cascos... lo que quieras."},
		{min = 0,   text = "Hola, hola. Echa un vistazo, que lo barato sale caro."},
	},
	jaeger = {
		{min = 800, text = "Un verdadero cazador. Llévate lo que necesites."},
		{min = 500, text = "Has hecho buen trabajo en el bosque. Te lo agradezco."},
		{min = 200, text = "Sigues vivo. Eso ya dice mucho de ti."},
		{min = 0,   text = "No me fío de los mercenarios. Demuéstrame que eres diferente."},
	},
}

ix.traders.smalltalk = {
	prapor = {
		"Los de la misión internacional se creen dueños de la ciudad. Ya veremos.",
		"Los saqueadores se han vuelto muy osados en la zona industrial. Alguien debería darles una lección.",
	},
	therapist = {
		"El hospital está desbordado. Cada medicina que traes salva a alguien.",
		"Hay gente cayendo enferma en el este de la ciudad. No sé qué beben.",
	},
	fence = {
		"Los Scavs me cuentan todo. Todo.",
		"Si matas Scavs, no esperes que te trate bien.",
	},
	skier = {
		"Un contenedor del puerto ha desaparecido. Si lo encuentras, avísame.",
		"El negocio va bien. La guerra siempre es buena para el negocio.",
	},
	peacekeeper = {
		"Los convoyes de la misión ya no llegan como antes.",
		"Hay un piloto de una contrata que me debe dinero. Si lo ves, dímelo.",
	},
	mechanic = {
		"La fábrica aún tiene máquinas que funcionan. Solo hay que llegar a ellas.",
		"Un buen cerrojo vale más que cien balas mal disparadas.",
	},
	ragman = {
		"El centro comercial está lleno de Scavs. Una pena, tenía buen género.",
		"Una buena mochila es la diferencia entre volver rico o volver pobre.",
	},
	jaeger = {
		"Los bosques se han llenado de bandidos. Hay que limpiarlos.",
		"He visto francotiradores Scav en la colina. Cuidado.",
	},
}

-- Rumores de la zona (sin comerciante, aleatorios)
ix.traders.news = {
	"Dicen que El Cacique ha vuelto a la residencia de la zona industrial con sus guardaespaldas.",
	"Alguien ha visto a un tipo enorme con casco en la galería comercial. Nadie que se haya cruzado con él ha vuelto.",
	"El Curandero sigue haciendo experimentos en el balneario de la costa.",
	"La farmacéutica cerró sus laboratorios, pero hay luz por las noches.",
	"Las carreteras de salida están bloqueadas otra vez. Solo quedan las extracciones de siempre.",
	"Un grupo de mercenarios ha limpiado el complejo químico esta mañana. Dicen que no quedó nadie.",
}

-- Precios globales: {[itemID] = precio} — referencia de venta para todos los traders.
-- Precios de compra: {[itemID] = precio} — lo que el trader paga al jugador.
ix.traders.globalPrices    = ix.traders.globalPrices or {}
ix.traders.globalBuyPrices = ix.traders.globalBuyPrices or {}

-- Ratio maximo de compra respecto a venta (65%) para evitar arbitraje con bonus de rep
ix.traders.MAX_BUY_RATIO = 0.65

function ix.traders.GetGlobalPrice(itemID)
	if (ix.traders.globalPrices[itemID] and ix.traders.globalPrices[itemID] > 0) then
		return ix.traders.globalPrices[itemID]
	end
	local itemData = ix.item.list[itemID]
	if (itemData and itemData.price and itemData.price > 0) then
		return itemData.price
	end
	return 0
end

-- Cuánto sube el precio de VENTA (lo que paga el jugador) al 0% de stock
-- respecto a su máximo histórico. 1.0 = el precio se duplica cuando se agota.
-- Compartido cliente/servidor para que lo que se muestra coincida con lo que
-- se cobra. maxQty también sirve de referencia para el stock vendido por
-- jugadores (crece con cada venta), así que la escasez se mide siempre contra
-- el mayor stock que ese slot ha llegado a tener.
ix.traders.STOCK_SCARCITY_MAX_INCREASE = 1.0

function ix.traders.GetStockPriceMultiplier(qty, maxQty)
	if (!maxQty or maxQty <= 0) then return 1 end

	local scarcity = 1 - math.Clamp((qty or 0) / maxQty, 0, 1)
	return 1 + scarcity * ix.traders.STOCK_SCARCITY_MAX_INCREASE
end

-- Cuánto BAJA el precio de COMPRA (lo que el trader paga al jugador) cuanto
-- más lleno está su stock de ese ítem: si ya tiene mucho, cada unidad
-- adicional vale menos (sobreoferta). 0.6 = paga hasta un 60% menos cuando
-- el slot está al máximo histórico (maxQty). Compartido cliente/servidor
-- para que la vista previa de venta coincida con lo que se cobra realmente.
ix.traders.STOCK_OVERSUPPLY_MAX_DECREASE = 0.6

function ix.traders.GetSellToTraderMultiplier(qty, maxQty)
	if (!maxQty or maxQty <= 0) then return 1 end

	local fullness = math.Clamp((qty or 0) / maxQty, 0, 1)
	return 1 - fullness * ix.traders.STOCK_OVERSUPPLY_MAX_DECREASE
end

function ix.traders.GetGlobalBuyPrice(itemID)
	local bp = ix.traders.globalBuyPrices[itemID]
	if (bp and bp > 0) then
		local sellPrice = ix.traders.GetGlobalPrice(itemID)
		local maxBuy = math.floor(sellPrice * ix.traders.MAX_BUY_RATIO)
		return math.Clamp(bp, 1, math.max(1, maxBuy))
	end
	local sellPrice = ix.traders.GetGlobalPrice(itemID)
	if (sellPrice <= 0) then return 0 end
	return math.max(1, math.floor(sellPrice * 0.5))
end

-- Precio de compra EFECTIVO de un trader concreto para un ítem: si ese trader
-- tiene su propio precio de compra puesto (slotBuyPrice > 0) se usa tal cual,
-- sin techo — es la base de la economía dinámica (oferta/demanda por estación
-- del metro). Si no lo tiene, cae al precio de compra global de siempre.
function ix.traders.GetEffectiveBuyPrice(slotBuyPrice, itemID)
	if (slotBuyPrice and slotBuyPrice > 0) then
		return slotBuyPrice
	end
	return ix.traders.GetGlobalBuyPrice(itemID)
end

-- Factor de condición (0..1) de una unidad según su durabilidad.
-- 1 = como nuevo (100%); valores menores abaratan compra y venta.
-- Compartido (cliente y servidor) para mostrar precios coherentes en la UI.
-- Un ítem puede definir ITEM:GetConditionFactor(data) para calcularlo a medida.
function ix.traders.GetConditionFactor(itemID, data)
	if (not data) then return 1 end

	local itemTable = ix.item.list[itemID]
	if (not itemTable) then return 1 end

	if (isfunction(itemTable.GetConditionFactor)) then
		local f = itemTable:GetConditionFactor(data)
		if (isnumber(f)) then return math.Clamp(f, 0, 1) end
	end

	-- Durabilidad por "uses" / maxUses (cinta americana, etc.)
	if (data.uses != nil and isnumber(itemTable.maxUses) and itemTable.maxUses > 0) then
		return math.Clamp(data.uses / itemTable.maxUses, 0, 1)
	end

	-- Durabilidad por "health" / getMaxHealth() (máscara de gas, etc.)
	if (data.health != nil and isfunction(itemTable.getMaxHealth)) then
		local maxHealth = itemTable:getMaxHealth()
		if (isnumber(maxHealth) and maxHealth > 0) then
			return math.Clamp(data.health / maxHealth, 0, 1)
		end
	end

	-- Durabilidad por "Durability" en escala 0-100 (armaduras, etc.)
	if (isnumber(data.Durability)) then
		return math.Clamp(data.Durability / 100, 0, 1)
	end

	return 1
end

-- Stubs de cliente para que los comandos aparezcan en el autocompletado del chat
if (CLIENT) then
	ix.command.Add("TraderSpawn",      { adminOnly=true, arguments={ix.type.string}, description="Spawnea un trader de la faccion especificada.", OnRun=function(self, client, faction) end })
	ix.command.Add("TraderAdmin",      { adminOnly=true, description="Abre el panel de administracion del trader que estas mirando.", OnRun=function(self, client) end })
	ix.command.Add("TraderSetPrice",   { adminOnly=true, arguments={ix.type.string, ix.type.number}, description="Cambia el precio de un item en el trader que estas mirando.", OnRun=function(self, client, itemID, price) end })
	ix.command.Add("TraderSetSlots",   { adminOnly=true, arguments={ix.type.number}, description="Cambia los slots maximos del trader que estas mirando.", OnRun=function(self, client, slots) end })
	ix.command.Add("TraderAddItem",    { adminOnly=true, arguments={ix.type.string, ix.type.number, ix.type.number}, description="Agrega un item al inventario del trader que estas mirando.", OnRun=function(self, client, itemID, qty, price) end })
	ix.command.Add("TraderRemoveItem", { adminOnly=true, arguments={ix.type.string}, description="Elimina un item del inventario del trader que estas mirando.", OnRun=function(self, client, itemID) end })
	ix.command.Add("TraderPrices",     { adminOnly=true, description="Abre el editor de precios globales de items.", OnRun=function(self, client) end })
end

ix.util.Include("sh_eft_stock.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
