local PLUGIN = PLUGIN

util.AddNetworkString("medico_npc_OpenDialogue")
util.AddNetworkString("medico_npc_Action")
util.AddNetworkString("medico_npc_AdminSave")

-- Duración (en segundos) de la canalización de curación/tratamiento.
local CAST_TIME = 10

-- Última vez (CurTime) que cada superviviente (por SteamID64) fue reanimado.
-- Solo en memoria: se reinicia si el servidor reinicia, igual que las canalizaciones.
PLUGIN.ultimosRevives = PLUGIN.ultimosRevives or {}

-- ============================================================
--  PERSISTENCIA DE LOS NPC MÉDICO DE GUARDIA
-- ============================================================

function PLUGIN:LoadData()
	ix.medico = ix.medico or {}
	ix.medico.npcs = self:GetData() or {}

	-- Diferir el spawn para asegurar que el mapa esté completamente cargado.
	timer.Simple(1, function()
		for _, info in ipairs(ix.medico.npcs or {}) do
			local pos = Vector(info.px, info.py, info.pz)

			-- Evitar duplicados si ya existe un NPC en esa posición.
			local exists = false
			for _, e in pairs(ents.FindByClass("ix_medico_guardia")) do
				if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
					exists = true
					break
				end
			end

			if (!exists) then
				local npc = ents.Create("ix_medico_guardia")
				if (IsValid(npc)) then
					-- Asignar modelo y animación antes de Spawn para que
					-- Initialize() los use en la primera llamada a ApplyAppearance.
					npc.npcModel = info.model
					npc.npcAnim  = info.anim
					npc:SetPos(pos)
					npc:SetAngles(Angle(0, info.ay or 0, 0))
					npc:Spawn()
					npc:Activate()
					-- Segunda pasada para garantizar que el modelo queda
					-- aplicado incluso si Initialize corrió antes del asign.
					npc:ApplyAppearance()
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(ix.medico and ix.medico.npcs or {})
end

-- ============================================================
--  ACCIONES DEL DIÁLOGO DEL NPC MÉDICO DE GUARDIA
-- ============================================================

net.Receive("medico_npc_Action", function(len, client)
	local ent = net.ReadEntity()
	local action = net.ReadString()

	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end
	if (!IsValid(ent) or ent:GetClass() != "ix_medico_guardia") then return end

	-- El jugador debe estar junto al NPC.
	if (client:GetPos():DistToSqr(ent:GetPos()) > (200 * 200)) then return end

	if (action == "heal") then
		ent:IntentarCurar(client)
	elseif (action == "treat") then
		ent:IntentarTratar(client)
	end
end)

-- Guarda la apariencia (modelo y animación) editada desde el panel de admin.
net.Receive("medico_npc_AdminSave", function(len, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local ent   = net.ReadEntity()
	local model = net.ReadString()
	local anim  = net.ReadString()

	if (!IsValid(ent) or ent:GetClass() != "ix_medico_guardia") then return end

	local newModel = (model != "" and util.IsValidModel(model)) and model or (ent.npcModel or ent:GetModel())
	local pos = ent:GetPos()
	local ang = ent:GetAngles()

	-- Reflejar el cambio en la persistencia del NPC correspondiente.
	ix.medico = ix.medico or {}
	ix.medico.npcs = ix.medico.npcs or {}
	for _, info in ipairs(ix.medico.npcs) do
		if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
			info.model = newModel
			info.anim  = anim
		end
	end
	PLUGIN:SaveData()

	-- Recrear la entidad para que todos los clientes vean el modelo nuevo
	-- (SetModel en un SENT no siempre se propaga de forma fiable).
	ent:Remove()
	timer.Simple(0.1, function()
		local npc = ents.Create("ix_medico_guardia")
		if (IsValid(npc)) then
			npc.npcModel = newModel
			npc.npcAnim  = anim
			npc:SetPos(pos)
			npc:SetAngles(ang)
			npc:Spawn()
			npc:Activate()
		end
	end)

	client:ChatPrint("Médico de guardia: apariencia guardada.")
end)

-- Cancela cualquier canalización activa de un médico.
local function LimpiarCast(client)
	if (!IsValid(client)) then return end
	client.ixMedicoCasting = nil
	client:SetAction()

	local id = "medico_cast_" .. client:SteamID64()
	if (timer.Exists(id)) then
		timer.Remove(id)
	end
end

-- ============================================================
--  APLICACIÓN DE LA VIDA MÁXIMA SEGÚN HERIDAS
-- ============================================================

-- Ajusta la vida máxima del jugador en función de sus heridas acumuladas.
-- @param client      Player   Jugador a ajustar.
-- @param bRellenar   boolean  Si es true, además rellena la vida hasta el nuevo máximo.
function PLUGIN:AplicarHeridas(client, bRellenar)
	if (!IsValid(client) or !client:Alive()) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	local heridas = character:GetHeridas() or 0
	local maxVida = self:CalcularVidaMaxima(heridas)

	client:SetMaxHealth(maxVida)

	if (bRellenar) then
		client:SetHealth(maxVida)
	else
		-- Si la vida actual supera el nuevo tope, recórtala.
		if (client:Health() > maxVida) then
			client:SetHealth(maxVida)
		end
	end
end

-- Tras el loadout de Helix, el jugador reaparece con su capacidad vital reducida.
-- Si viene de una reanimación con desfibrilador, el propio GM:PlayerLoadout de Helix
-- rellena la vida con character:GetData("health", ...), que IntentarRevivir ya dejó
-- en medico_revivir_vida; aquí solo hace falta ajustar el tope según sus heridas.
function PLUGIN:PlayerLoadout(client)
	if (client.ixMedicoRevivir) then
		client.ixMedicoRevivir = nil
		self:AplicarHeridas(client, false)
		return
	end

	self:AplicarHeridas(client, true)
end

-- ============================================================
--  ACUMULACIÓN DE HERIDAS AL MORIR
-- ============================================================

function PLUGIN:PlayerDeath(client)
	if (!IsValid(client)) then return end

	-- Si el médico estaba atendiendo a alguien y muere, se interrumpe.
	LimpiarCast(client)

	local character = client:GetCharacter()
	if (!character) then return end

	local incremento = ix.config.Get("medico_herida_porcentaje", 10)
	local tope = ix.config.Get("medico_herida_max", 90)
	local nuevo = math.min((character:GetHeridas() or 0) + incremento, tope)

	character:SetHeridas(nuevo)
end

function PLUGIN:PlayerDisconnected(client)
	LimpiarCast(client)
end

-- ============================================================
--  REANIMACIÓN (DESFIBRILADOR)
-- ============================================================

-- persistent_corpses/loot_on_death ya usan este hook (ejecuta DESPUÉS de que el
-- cadáver exista y limpian entity.ixPlayer), así que aquí guardamos nuestra propia
-- referencia al dueño para poder apuntar al cadáver con el desfibrilador.
function PLUGIN:OnPlayerCorpseCreated(client, entity)
	if (!IsValid(client) or !IsValid(entity)) then return end

	entity.medicoDueno = client
end

-- Vacía el inventario del cadáver en el inventario del propio reanimado. No es una
-- vida nueva (sigue siendo el mismo personaje), así que el bloqueo de auto-loot de
-- persistent_corpses (pensado para no correr a saquearte a ti mismo tras morir) no
-- debería aplicarle aquí: se le devuelven sus cosas directamente y el cadáver, ya
-- vacío, se elimina en vez de dejarlo tirado en el mapa.
local function DevolverPertenencias(paciente, corpse)
	local inventory = corpse.ixInventory
	local character = paciente:GetCharacter()
	local charInventory = character and character:GetInventory()
	if (!inventory or !charInventory) then return end

	-- recopilar antes de transferir: Transfer muta inventory.slots, así que iterar
	-- y mutar a la vez saltaría/duplicaría entradas.
	local items = {}
	for _, slot in pairs(inventory.slots or {}) do
		for _, item in pairs(slot) do
			items[#items + 1] = item
		end
	end

	for _, item in ipairs(items) do
		item:Transfer(charInventory:GetID(), nil, nil, paciente)
	end
end

-- Devuelve el cadáver (ragdoll) de un superviviente muerto al que el médico apunta, o nil.
local function ObtenerCadaverObjetivo(client)
	local rango = ix.config.Get("medico_botiquin_rango", 150)
	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or !IsValid(entity.medicoDueno)) then return nil end
	if (client:GetPos():DistToSqr(entity:GetPos()) > (rango * rango)) then return nil end

	return entity
end

-- Intenta reanimar al superviviente dueño del cadáver al que apunta el médico.
function PLUGIN:IntentarRevivir(client, item)
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	if (!self:EsMedico(client:GetCharacter())) then
		client:Notify("Solo un médico sabe usar correctamente un desfibrilador.")
		return
	end

	local corpse = ObtenerCadaverObjetivo(client)
	if (!corpse) then
		client:Notify("Debes apuntar al cadáver de un superviviente caído recientemente.")
		return
	end

	local paciente = corpse.medicoDueno
	if (!IsValid(paciente) or paciente:Alive() or !paciente:GetCharacter()) then
		client:Notify("Este superviviente ya no puede ser reanimado.")
		return
	end

	local steamID = paciente:SteamID64()
	local cooldown = ix.config.Get("medico_revivir_cooldown", 600)
	local ultimo = self.ultimosRevives[steamID]

	if (ultimo and (CurTime() - ultimo) < cooldown) then
		local restante = math.ceil(cooldown - (CurTime() - ultimo))
		client:Notify(paciente:Name() .. " no puede ser reanimado todavía (" .. restante .. "s).")
		return
	end

	item.player = client

	local probabilidad = ix.config.Get("medico_revivir_probabilidad", 100)
	if (math.random(1, 100) > probabilidad) then
		client:Notify("La reanimación ha fallado.")
		item:Remove()
		return
	end

	self.ultimosRevives[steamID] = CurTime()

	local pos = corpse:GetPos()
	local ang = corpse:GetAngles()
	local vida = ix.config.Get("medico_revivir_vida", 10)

	-- Deja la vida inicial en los datos del personaje: el propio GM:PlayerLoadout de
	-- Helix la lee con character:GetData("health", ...) al reaparecer (ver PlayerLoadout).
	paciente:GetCharacter():SetData("health", vida)
	paciente.ixMedicoRevivir = true
	paciente:Spawn()
	paciente:SetPos(pos)
	paciente:SetAngles(Angle(0, ang.y, 0))

	paciente:EmitSound("items/medshot4.wav")

	client:Notify("Has reanimado a " .. paciente:Name() .. ".")
	paciente:Notify("¡Un médico te ha reanimado con un desfibrilador!")

	-- Recupera sus pertenencias del cadáver y lo elimina (ya no tiene sentido
	-- dejarlo tirado, ni que persistent_corpses le bloquee lootear su propio cuerpo).
	if (IsValid(corpse)) then
		DevolverPertenencias(paciente, corpse)
		corpse:Remove()
	end

	item:Remove()
end

-- ============================================================
--  CANALIZACIÓN DE CURACIÓN Y TRATAMIENTO (10 SEGUNDOS)
-- ============================================================

-- Devuelve el jugador al que apunta el médico dentro del rango, o nil.
local function ObtenerObjetivo(client)
	local rango = ix.config.Get("medico_botiquin_rango", 150)
	local trace = client:GetEyeTrace()
	local objetivo = trace.Entity

	if (!IsValid(objetivo) or !objetivo:IsPlayer()) then return nil end
	if (objetivo == client) then return nil end
	if (client:GetPos():DistToSqr(objetivo:GetPos()) > (rango * rango)) then return nil end

	return objetivo
end

-- Comprueba que el objetivo sigue siendo válido a mitad de la canalización.
local function ObjetivoValido(client, objetivo)
	if (!IsValid(objetivo) or !objetivo:Alive() or !objetivo:GetCharacter()) then return false end
	-- El médico debe seguir apuntando al mismo superviviente dentro del rango.
	return ObtenerObjetivo(client) == objetivo
end

-- Aplica el efecto final una vez completada la canalización.
local function AplicarEfecto(plugin, client, objetivo, item, modo)
	if (modo == "curar") then
		local curacion = ix.config.Get("medico_botiquin_curacion", 60)
		objetivo:SetHealth(math.min(objetivo:GetMaxHealth(), objetivo:Health() + curacion))
		objetivo:EmitSound("items/medshot4.wav")

		client:Notify("Has curado a " .. objetivo:Name() .. ".")
		objetivo:Notify("Un médico te ha curado " .. curacion .. " puntos de vida.")
	elseif (modo == "radiacion") then
		local objChar = objetivo:GetCharacter()
		local rebaja = ix.config.Get("medico_botiquin_rads", 20)
		local nuevaRad = math.max(0, (objChar:GetRadiation() or 0) - rebaja)
		objChar:SetRadiation(nuevaRad)
		objetivo:EmitSound("items/smallmedkit1.wav")

		client:Notify("Has rebajado la radiación de " .. objetivo:Name() .. ".")
		objetivo:Notify("Un médico te ha rebajado " .. rebaja .. " puntos de radiación.")
	else
		local objChar = objetivo:GetCharacter()
		objChar:SetHeridas(0)

		-- Tratar las heridas restaura la capacidad y deja la vida al máximo.
		plugin:AplicarHeridas(objetivo, true)
		objetivo:EmitSound("items/smallmedkit1.wav")

		client:Notify("Has tratado las heridas de " .. objetivo:Name() .. ".")
		objetivo:Notify("Un médico ha tratado tus heridas; recuperas capacidad vital.")
	end

	-- Conocimientos Médicos: XP por atender a un superviviente.
	hook.Run("OnCuracionRealizada", client, false)

	if (IsValid(item.entity)) then return end
	item.player = client
	item:ConsumirUso()
end

-- Inicia la canalización de 10 s. modo = "curar" o "tratar".
function PLUGIN:IniciarTratamiento(client, item, modo)
	local character = client:GetCharacter()
	if (!self:EsMedico(character)) then
		client:Notify("Solo un médico sabe usar correctamente un botiquín.")
		return
	end

	if (client.ixMedicoCasting) then
		client:Notify("Ya estás atendiendo a un superviviente.")
		return
	end

	local objetivo = ObtenerObjetivo(client)
	if (!objetivo or !objetivo:Alive() or !objetivo:GetCharacter()) then
		client:Notify("Debes apuntar a un superviviente cercano.")
		return
	end

	-- Validaciones específicas según el modo.
	if (modo == "curar") then
		if (objetivo:Health() >= objetivo:GetMaxHealth()) then
			client:Notify(objetivo:Name() .. " ya tiene la vida al máximo de su capacidad.")
			return
		end
	elseif (modo == "radiacion") then
		if ((objetivo:GetCharacter():GetRadiation() or 0) <= 0) then
			client:Notify(objetivo:Name() .. " no tiene radiación que tratar.")
			return
		end
	else
		if ((objetivo:GetCharacter():GetHeridas() or 0) <= 0) then
			client:Notify(objetivo:Name() .. " no tiene heridas que tratar.")
			return
		end
	end

	client.ixMedicoCasting = true
	client:SetAction("Atendiendo a " .. objetivo:Name() .. "...", CAST_TIME)
	client:Notify("Comienzas a atender a " .. objetivo:Name() .. "... mantente apuntándole (" .. CAST_TIME .. "s).")
	objetivo:Notify("Un médico ha comenzado a atenderte; no te muevas.")

	local id = "medico_cast_" .. client:SteamID64()
	local restante = CAST_TIME

	timer.Create(id, 1, CAST_TIME, function()
		if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then
			LimpiarCast(client)
			return
		end

		-- El médico debe conservar el botiquín con usos disponibles.
		if (!item or item:getUsos() <= 0) then
			client:Notify("El botiquín ya no está disponible.")
			LimpiarCast(client)
			return
		end

		if (!ObjetivoValido(client, objetivo)) then
			client:Notify("Has perdido de vista al superviviente; tratamiento interrumpido.")
			LimpiarCast(client)
			return
		end

		restante = restante - 1
		if (restante <= 0) then
			AplicarEfecto(self, client, objetivo, item, modo)
			LimpiarCast(client)
		end
	end)
end

-- Comandos definidos en sh_commands.lua (compartido) para que
-- aparezcan en el autocompletado del chat del cliente.
