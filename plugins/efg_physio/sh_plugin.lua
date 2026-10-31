local PLUGIN = PLUGIN

PLUGIN.name = "EFG Fisiología"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Fisiología al estilo KAT encima de la salud por partes de EFT: volumen de sangre y tensión, SpO2, neumotórax, vía aérea, inconsciencia, parada cardiaca, daño cerebral y grupos sanguíneos."

-- Capas:
--   efg_health   partes del cuerpo (440 PV), sangrados, fracturas, extremidades destruidas
--   efg_effects  estimulantes y herida fresca
--   efg_physio   (este) sangre, SpO2, vía aérea, shock, parada y transfusiones
-- Todo el estado vive en el servidor (client.efgPhysio); el cliente solo recibe
-- la netvar efgVitals para dibujar y nunca puede modificarla.

ix.efg = ix.efg or {}
ix.efg.physio = ix.efg.physio or {}

local PH = ix.efg.physio

PH.BLOOD_MAX = 6000 -- ml

-- Grupos sanguíneos (frecuencias aproximadas en Europa) y compatibilidad de
-- concentrado de hematíes: donante → receptores que lo aceptan.
PH.bloodTypes = {
	{"O+", 35}, {"A+", 36}, {"B+", 8}, {"AB+", 3},
	{"O-", 7}, {"A-", 7}, {"B-", 2}, {"AB-", 2},
}

PH.compatible = {
	["O-"]  = {"O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"},
	["O+"]  = {"O+", "A+", "B+", "AB+"},
	["A-"]  = {"A-", "A+", "AB-", "AB+"},
	["A+"]  = {"A+", "AB+"},
	["B-"]  = {"B-", "B+", "AB-", "AB+"},
	["B+"]  = {"B+", "AB+"},
	["AB-"] = {"AB-", "AB+"},
	["AB+"] = {"AB+"},
}

function PH.CanReceive(donor, recipient)
	return table.HasValue(PH.compatible[donor] or {}, recipient)
end

function PH.RandomBloodType()
	local total = 0
	for _, entry in ipairs(PH.bloodTypes) do total = total + entry[2] end

	local roll = math.random() * total

	for _, entry in ipairs(PH.bloodTypes) do
		roll = roll - entry[2]
		if (roll <= 0) then return entry[1] end
	end

	return "O+"
end

-- ─── Variables de personaje ──────────────────────────────────────────────────
-- Grupo sanguíneo: se sortea al crear el personaje y no se puede elegir.
ix.char.RegisterVar("efgBloodType", {
	field = "efg_blood_type",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true,
	isLocal = true,
	OnValidate = function()
		return PH.RandomBloodType()
	end
})

-- Constantes guardadas entre sesiones: {blood, spo2, pneumo, brain}. La vía
-- aérea, la parada y la inconsciencia no se guardan: al reconectar se despierta.
ix.char.RegisterVar("efgVitals", {
	field = "efg_vitals",
	fieldType = ix.type.text,
	default = {},
	bNoDisplay = true,
	isLocal = true,
})

-- ─── Ajustes ─────────────────────────────────────────────────────────────────
local function config(key, default, text, min, max, decimals)
	ix.config.Add(key, default, text, nil, {data = {min = min, max = max, decimals = decimals}, category = "EFG Fisiología"})
end

config("efgPhysioLightBleed", 4, "Sangre perdida (ml/s) por cada sangrado leve.", 0, 50)
config("efgPhysioHeavyBleed", 18, "Sangre perdida (ml/s) por cada sangrado grave.", 0, 100)
config("efgPhysioBloodRegen", 8, "Sangre recuperada (ml/s) fuera de raid cuando no hay ningún sangrado.", 0, 50)
config("efgPhysioInternalBleed", 6, "Hemorragia interna (ml/s) con el estómago destruido.", 0, 50)
config("efgPhysioPneumoChance", 20, "Probabilidad (%) de neumotórax por impacto en el tórax que no para el chaleco.", 0, 100)
config("efgPhysioTensionTime", 45, "Segundos sin tratar antes de que un neumotórax pueda pasar a tensión.", 5, 600)
config("efgPhysioHypoxia", 1, "Multiplicador del daño cerebral por hipoxia.", 0, 5, 2)
config("efgPhysioArrestTime", 240, "Segundos máximos en parada cardiaca antes de morir (con RCP se alarga).", 30, 900)

-- ─── Datos para el HUD ───────────────────────────────────────────────────────
-- netvar efgVitals (la ven todos para los monitores y el pulsioxímetro):
--   {spo2, hr, sys, dia, blood (ml), brain (0-100), flags}
PH.FLAG = {
	PNEUMO = 1,      -- neumotórax abierto
	TENSION = 2,     -- neumotórax a tensión
	UNCONSCIOUS = 4,
	AIRWAY = 8,      -- vía aérea obstruida
	ARREST = 16,     -- parada cardiaca
	GUEDEL = 32,
	TUBE = 64,
	INFUSION = 128,  -- transfusión en curso
	CPR = 256,
	SHOCK2 = 512,    -- shock hipovolémico clase II
	SHOCK3 = 1024,   -- clase III
	SHOCK4 = 2048,   -- clase IV
	INTERNAL = 4096, -- hemorragia interna
}

function PH.Vitals(entity)
	local client = IsValid(entity) and (entity:IsPlayer() and entity or entity:GetNetVar("player")) or nil
	return IsValid(client) and client:GetNetVar("efgVitals") or nil
end

function PH.HasFlag(vitals, flag)
	return vitals and bit.band(vitals[7] or 0, flag) != 0 or false
end

-- Jugador al que apunta el médico: el propio jugador o su cuerpo inconsciente
-- (ragdoll de Helix, netvar "player").
function PH.GetPatient(client, range)
	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or trace.HitPos:Distance(client:GetShootPos()) > (range or 96)) then return end

	local patient = entity:IsPlayer() and entity or entity:GetNetVar("player")

	if (IsValid(patient) and patient:IsPlayer() and patient != client and patient:Alive() and patient:GetCharacter()) then
		return patient, entity
	end
end

-- Velocidad con shock: clase III anda más lento y no corre
hook.Add("SetupMove", "ixEFGPhysioShock", function(client, mv)
	local vitals = client:GetNetVar("efgVitals")
	if (!vitals) then return end

	if (PH.HasFlag(vitals, PH.FLAG.SHOCK3)) then
		mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), client:GetWalkSpeed() * 0.8))
	elseif (PH.HasFlag(vitals, PH.FLAG.SHOCK2) and mv:KeyDown(IN_SPEED)) then
		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * 0.85)
	end
end)

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
