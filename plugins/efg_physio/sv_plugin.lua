-- Fisiología del servidor. Cada segundo (Think) se recalcula, por jugador:
--   sangre   = - sangrados (efg_health) - hemorragia interna + transfusiones
--   tensión  = función del volumen (shock hipovolémico clases II-IV)
--   SpO2     = tiende a un objetivo que bajan el neumotórax, la vía aérea
--              obstruida, la falta de sangre y la parada
--   cerebro  = daño por hipoxia (SpO2 < 60) y por parada; 100 = muerte
-- El estado solo cambia aquí y en los tratamientos (PH.Treat*), que solo se
-- llaman al terminar la acción de un ítem validado en el servidor.
local PLUGIN = PLUGIN
local PH = ix.efg.physio
local FLAG = PH.FLAG

local function fresh()
	return {
		blood = PH.BLOOD_MAX, spo2 = 98, brain = 0,
		pneumo = 0,          -- 0 nada, 1 neumotórax abierto, 2 a tensión
		pneumoSince = 0,
		airway = nil,        -- nil, "guedel" o "tube"
		unconscious = false, unconsciousSince = 0,
		arrest = false, arrestSince = 0,
		cprUntil = 0,
		infusions = {},      -- {ml, rate}
	}
end

function PH.Get(client)
	client.efgPhysio = client.efgPhysio or fresh()
	return client.efgPhysio
end

function PH.Reset(client)
	client.efgPhysio = fresh()
	if (client.efgPhysioRagdoll) then PH.WakeUp(client, true) end
	PH.Sync(client)
end

local function bloodRatio(state) return state.blood / PH.BLOOD_MAX end

-- ─── Red ─────────────────────────────────────────────────────────────────────
function PH.Compute(state)
	local ratio = bloodRatio(state)
	local hr, sys

	if (state.arrest) then
		hr, sys = 0, 0
	else
		hr = math.Clamp(72 + (1 - ratio) * 190 + (state.pneumo * 12) + (state.spo2 < 90 and (90 - state.spo2) or 0), 40, 190)
		sys = math.Clamp(120 - (1 - ratio) * 200 - (state.pneumo == 2 and 25 or 0), 0, 140)
	end

	return math.Round(hr), math.Round(sys), math.Round(sys * 0.66)
end

function PH.Sync(client)
	local state = PH.Get(client)
	local hr, sys, dia = PH.Compute(state)
	local ratio = bloodRatio(state)
	local flags = 0

	local function set(flag, on) if (on) then flags = bit.bor(flags, flag) end end

	set(FLAG.PNEUMO, state.pneumo == 1)
	set(FLAG.TENSION, state.pneumo == 2)
	set(FLAG.UNCONSCIOUS, state.unconscious)
	set(FLAG.AIRWAY, state.unconscious and !state.airway)
	set(FLAG.ARREST, state.arrest)
	set(FLAG.GUEDEL, state.airway == "guedel")
	set(FLAG.TUBE, state.airway == "tube")
	set(FLAG.INFUSION, #state.infusions > 0)
	set(FLAG.CPR, state.cprUntil > CurTime())
	set(FLAG.SHOCK4, ratio < 0.6)
	set(FLAG.SHOCK3, ratio >= 0.6 and ratio < 0.7)
	set(FLAG.SHOCK2, ratio >= 0.7 and ratio < 0.85)
	set(FLAG.INTERNAL, state.internal == true)

	local vitals = {math.Round(state.spo2), hr, sys, dia, math.Round(state.blood), math.Round(state.brain), flags}
	local sig = table.concat(vitals, ",")

	if (client.efgVitalsSig != sig) then
		client.efgVitalsSig = sig
		client:SetNetVar("efgVitals", vitals)
	end
end

function PH.Save(client)
	local character = client:GetCharacter()
	local state = client.efgPhysio
	if (!character or !state) then return end

	character:SetEfgVitals({blood = math.Round(state.blood), spo2 = math.Round(state.spo2), pneumo = state.pneumo, brain = math.Round(state.brain, 1)})
end

-- ─── Inconsciencia (ragdoll de Helix) ────────────────────────────────────────
function PH.KnockOut(client, reason)
	local state = PH.Get(client)
	if (state.unconscious) then return end

	state.unconscious = true
	state.unconsciousSince = CurTime()

	-- al caer, la lengua obstruye la vía aérea (si no hay cánula o tubo puestos)
	if (client.SetRagdolled) then
		client:SetRagdolled(true)
		client.efgPhysioRagdoll = true
	end

	client:Notify(reason or "Has perdido el conocimiento.")
	hook.Run("EFGPhysioUnconscious", client, true)
end

function PH.WakeUp(client, bSilent)
	local state = PH.Get(client)

	state.unconscious = false
	state.airway = nil -- al despertar se escupe la cánula o se retira el tubo

	if (client.efgPhysioRagdoll and client.SetRagdolled and client:Alive()) then
		client:SetRagdolled(false)
	end

	client.efgPhysioRagdoll = nil

	if (!bSilent) then
		client:ScreenFade(SCREENFADE.IN, color_black, 2, 0)
		client:Notify("Recuperas el conocimiento.")
	end

	hook.Run("EFGPhysioUnconscious", client, false)
end

function PH.Arrest(client)
	local state = PH.Get(client)
	if (state.arrest) then return end

	state.arrest = true
	state.arrestSince = CurTime()
	PH.KnockOut(client, "Parada cardiaca.")
end

-- ─── Bucle ───────────────────────────────────────────────────────────────────
local function approach(value, target, up, down)
	if (value < target) then return math.min(target, value + up) end
	return math.max(target, value - down)
end

function PH.Tick(client)
	local state = PH.Get(client)
	local health = ix.efg.health
	local now = CurTime()

	-- 1. circulación
	local loss = 0

	if (health and client.efgStatus) then
		for _, level in pairs(client.efgStatus.bleed) do
			loss = loss + (level == "heavy" and ix.config.Get("efgPhysioHeavyBleed", 18) or ix.config.Get("efgPhysioLightBleed", 4))
		end
	end

	local hp = health and client.efgHP
	state.internal = hp and hp.stomach and hp.stomach <= 0 or false
	if (state.internal) then loss = loss + ix.config.Get("efgPhysioInternalBleed", 6) end

	-- sin latido no se pierde (ni circula) sangre al mismo ritmo
	if (state.arrest) then loss = loss * 0.25 end

	local gain = 0

	for i = #state.infusions, 1, -1 do
		local bag = state.infusions[i]
		local step = math.min(bag.ml, bag.rate)
		bag.ml = bag.ml - step
		gain = gain + step

		if (bag.ml <= 0) then table.remove(state.infusions, i) end
	end

	-- fuera de raid el cuerpo repone sangre poco a poco, pero no mientras se
	-- pierde: antes los 8 ml/s tapaban un sangrado leve (4 ml/s) entero
	if (!(client.InRaid and client:InRaid()) and !state.arrest and loss <= 0) then
		gain = gain + ix.config.Get("efgPhysioBloodRegen", 8)
	end

	state.blood = math.Clamp(state.blood - loss + gain, 0, PH.BLOOD_MAX)

	local ratio = bloodRatio(state)

	-- 2. respiración: objetivo de SpO2 y velocidad de caída
	local target, fall = 98, 0.3

	if (state.pneumo == 1) then target, fall = 90, 0.15 end
	if (state.pneumo == 2) then target, fall = 62, 0.6 end

	if (state.unconscious and !state.arrest) then
		if (!state.airway) then target, fall = math.min(target, 40), math.max(fall, 1)
		elseif (state.airway == "guedel") then target, fall = math.min(target, 88), math.max(fall, 0.3) end
	end

	-- poca sangre = poco transporte de oxígeno
	target = target - math.max(0, (0.85 - ratio) * 80)

	if (state.arrest) then
		local cpr = state.cprUntil > now
		target, fall = cpr and 55 or 0, cpr and 0.6 or 1.6
	end

	state.spo2 = approach(state.spo2, math.max(target, 0), 0.8, fall)

	-- neumotórax sin tratar: puede pasar a tensión
	if (state.pneumo == 1 and now - state.pneumoSince > ix.config.Get("efgPhysioTensionTime", 45) and math.random(100) <= 5) then
		state.pneumo = 2
		client:Notify("Te cuesta mucho respirar: neumotórax a tensión.")
	end

	-- 3. cerebro
	local hypoxia = ix.config.Get("efgPhysioHypoxia", 1)

	if (state.spo2 < 60) then
		state.brain = state.brain + (60 - state.spo2) / 25 * hypoxia
	elseif (state.spo2 >= 92 and !state.unconscious) then
		state.brain = math.max(0, state.brain - 0.02)
	end

	if (state.arrest) then
		local limit = ix.config.Get("efgPhysioArrestTime", 240)
		state.brain = state.brain + 100 / limit * (state.cprUntil > now and 0.5 or 1)
	end

	-- 4. transiciones
	if (state.brain >= 100) then
		client.efgPhysioDeath = true

		if (health and health.Kill) then health.Kill(client) else client:Kill() end
		return
	end

	if (!state.arrest and (ratio < 0.45 or state.spo2 < 35)) then
		PH.Arrest(client)
	elseif (!state.unconscious and (ratio < 0.6 or state.spo2 < 70)) then
		PH.KnockOut(client, ratio < 0.6 and "Shock hipovolémico: pierdes el conocimiento." or "Hipoxia: pierdes el conocimiento.")
	elseif (state.unconscious and !state.arrest and ratio >= 0.65 and state.spo2 >= 85 and now - state.unconsciousSince > 10) then
		PH.WakeUp(client)
	end

	PH.Sync(client)
end

local nextTick = 0

function PLUGIN:Think()
	if (nextTick > CurTime()) then return end
	nextTick = CurTime() + 1

	for _, client in player.Iterator() do
		if (client:Alive() and client:GetCharacter()) then
			PH.Tick(client)
			PH.FreshWound(client)
		end
	end
end

-- ─── Herida fresca: se reabre al correr (y con más facilidad al recibir daño,
-- ver EFGBleedChanceMult en efg_effects) ───────────────────────────────────────
function PH.FreshWound(client)
	local FX = ix.efg.effects
	local status = client.efgStatus
	if (!FX or !status or !client:IsSprinting() or FX.Has(client, "hemostatic")) then return end

	for _, e in ipairs(client.efgEffects or {}) do
		local partID = e[3]

		if (e[1] == "freshwound" and e[2] > CurTime() and isstring(partID) and !status.bleed[partID] and math.random(100) <= 3) then
			status.bleed[partID] = "light"
			client:Notify("Se te ha vuelto a abrir la herida.")
			hook.Run("EFGHealthEvent", client, "bleed", partID)
			ix.efg.health.Sync(client)
			return
		end
	end
end

-- ─── Daño: neumotórax por impacto en el tórax ────────────────────────────────
function PLUGIN:PostEntityTakeDamage(client, dmginfo, took)
	if (!took or !IsValid(client) or !client:IsPlayer() or !client:Alive()) then return end
	if (!(dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_SLASH)) or client.efgArmorStopped == CurTime()) then return end

	local state = PH.Get(client)

	if (client:LastHitGroup() == HITGROUP_CHEST and state.pneumo == 0 and math.random(100) <= ix.config.Get("efgPhysioPneumoChance", 20)) then
		state.pneumo = 1
		state.pneumoSince = CurTime()
		client:Notify("Notas un silbido al respirar: neumotórax.")
	end
end

-- ─── Tratamientos (los llaman los ítems al terminar su acción) ───────────────
-- Cada función devuelve true si ha hecho algo; si no, false y el motivo.
PH.treatments = {}

PH.treatments.guedel = function(patient, state)
	if (!state.unconscious) then return false, "Solo se coloca a alguien inconsciente." end
	if (state.airway) then return false, "Ya tiene la vía aérea asegurada." end
	state.airway = "guedel"
	return true
end

PH.treatments.tube = function(patient, state)
	if (!state.unconscious) then return false, "Solo se intuba a alguien inconsciente." end
	if (state.airway == "tube") then return false, "Ya está intubado." end
	state.airway = "tube"
	return true
end

PH.treatments.chestseal = function(patient, state)
	if (state.pneumo == 0) then return false, "No tiene ninguna herida abierta en el tórax." end
	if (state.pneumo == 2) then return false, "Neumotórax a tensión: primero descomprime con la aguja." end
	state.pneumo = 0
	return true
end

PH.treatments.needle = function(patient, state)
	if (state.pneumo != 2) then return false, "No hay neumotórax a tensión que descomprimir." end
	state.pneumo = 1
	state.pneumoSince = CurTime()
	return true
end

PH.treatments.defib = function(patient, state)
	if (!state.arrest) then return false, "El monitor no indica un ritmo desfibrilable." end

	local chance = 0.65
	if (bloodRatio(state) < 0.6) then chance = chance * 0.3 end
	if (state.spo2 < 50) then chance = chance * 0.6 end
	if (state.brain > 60) then chance = chance * 0.5 end

	patient:EmitSound("ambient/energy/zap1.wav", 70)

	if (math.random() <= chance) then
		state.arrest = false
		state.spo2 = math.max(state.spo2, 60)
		return true
	end

	return true, "Descarga sin éxito: sigue con la RCP y vuelve a intentarlo."
end

PH.treatments.cpr = function(patient, state)
	if (!state.arrest and !(state.unconscious and state.spo2 < 70)) then return false, "No necesita RCP." end
	state.cprUntil = CurTime() + 15

	-- a veces la RCP sola recupera el pulso si hay sangre suficiente
	if (state.arrest and bloodRatio(state) >= 0.6 and math.random(100) <= 6) then
		state.arrest = false
	end

	return true
end

-- bolsa: {ml, tipo de sangre o nil para suero}
function PH.Transfuse(patient, state, ml, bloodType)
	if (state.blood >= PH.BLOOD_MAX - 100) then return false, "No le falta sangre." end
	if (#state.infusions >= 2) then return false, "Ya tiene dos vías con transfusión en curso." end

	local character = patient:GetCharacter()
	local recipient = character and character:GetEfgBloodType()

	if (bloodType and recipient != "" and !PH.CanReceive(bloodType, recipient)) then
		-- reacción hemolítica aguda
		local health = ix.efg.health
		if (health) then
			health.DamagePart(patient, "thorax", 20)
			health.DamagePart(patient, "stomach", 25)
			health.Sync(patient)
		end

		state.spo2 = math.max(0, state.spo2 - 15)
		patient:Notify("Escalofríos, fiebre y dolor en el pecho: reacción a la transfusión.")

		if (math.random(100) <= 30) then PH.Arrest(patient) end

		return true, "¡Grupo incompatible! El paciente sufre una reacción hemolítica."
	end

	state.infusions[#state.infusions + 1] = {ml = ml, rate = bloodType and 12 or 20}
	return true
end

-- Aplica un tratamiento. kind es la clave de PH.treatments o "blood"/"saline".
function PH.Treat(patient, kind, item)
	local state = PH.Get(patient)
	local ok, message

	if (kind == "blood") then
		ok, message = PH.Transfuse(patient, state, item.bloodML or 500, item.bloodType)
	elseif (kind == "saline") then
		ok, message = PH.Transfuse(patient, state, item.bloodML or 500, nil)
	elseif (PH.treatments[kind]) then
		ok, message = PH.treatments[kind](patient, state)
	else
		return false, "Tratamiento desconocido."
	end

	PH.Sync(patient)
	return ok, message
end

-- Comprueba sin aplicar (para no empezar una acción que no sirve)
function PH.CanTreat(patient, kind, item)
	local state = table.Copy(PH.Get(patient))
	state.infusions = table.Copy(state.infusions)

	if (kind == "blood" or kind == "saline") then
		if (state.blood >= PH.BLOOD_MAX - 100) then return false, "No le falta sangre." end
		if (#state.infusions >= 2) then return false, "Ya tiene dos vías con transfusión en curso." end
		return true
	end

	if (kind == "defib") then
		return state.arrest, "El monitor no indica un ritmo desfibrilable."
	end

	local fn = PH.treatments[kind]
	if (!fn) then return false, "Tratamiento desconocido." end

	local fake = setmetatable({}, {__index = function() return function() end end})
	return fn(fake, state)
end

-- ─── Ciclo de vida ───────────────────────────────────────────────────────────
function PLUGIN:PlayerLoadedCharacter(client, character)
	client.efgPhysio = fresh()

	if (character:GetEfgBloodType() == "") then
		character:SetEfgBloodType(PH.RandomBloodType())
	end

	local saved = character:GetEfgVitals()

	if (istable(saved)) then
		local state = client.efgPhysio
		state.blood = math.Clamp(tonumber(saved.blood) or PH.BLOOD_MAX, PH.BLOOD_MAX * 0.7, PH.BLOOD_MAX)
		state.spo2 = math.Clamp(tonumber(saved.spo2) or 98, 90, 100)
		state.pneumo = math.Clamp(math.floor(tonumber(saved.pneumo) or 0), 0, 1)
		state.pneumoSince = CurTime()
		state.brain = math.Clamp(tonumber(saved.brain) or 0, 0, 50)
	end

	PH.Sync(client)
end

function PLUGIN:PlayerDeath(client)
	client.efgPhysio = fresh()
	client.efgPhysioRagdoll = nil

	local character = client:GetCharacter()
	if (character) then character:SetEfgVitals({}) end
end

function PLUGIN:PlayerSpawn(client)
	if (client.efgPhysio and !client.efgPhysio.unconscious) then PH.Sync(client) end
end

function PLUGIN:PlayerDisconnected(client)
	PH.Save(client)
end

-- al volver de la raid (o pagar el tratamiento) la fisiología se normaliza
function PLUGIN:EFGRaidEnded(client)
	if (client:Alive()) then PH.Reset(client) end
end

function PLUGIN:EFGHealthReset(client)
	if (client:Alive()) then PH.Reset(client) end
end

local nextSave = 0

function PLUGIN:Tick()
	if (nextSave > CurTime()) then return end
	nextSave = CurTime() + 30

	for _, client in player.Iterator() do
		if (client:Alive()) then PH.Save(client) end
	end
end

-- inconsciente: no puede usar objetos, hablar por radio ni moverse
function PLUGIN:CanPlayerInteractItem(client, action)
	local state = client.efgPhysio
	if (state and state.unconscious) then return false end
end

function PLUGIN:PlayerCanHearPlayersVoice(listener, speaker)
	local state = speaker.efgPhysio
	if (state and state.unconscious) then return false end
end

-- el Helix "getUp" no debe despertar a quien sigue inconsciente
function PLUGIN:CanPlayerUseCharacter(client)
	local state = client.efgPhysio
	if (state and state.unconscious) then return false, "No puedes cambiar de personaje estando inconsciente." end
end
