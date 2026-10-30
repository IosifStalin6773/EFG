local PLUGIN = PLUGIN

PLUGIN.name = "EFG Efectos"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Efectos temporales de EFT: estimulantes, herida fresca, fatiga, intoxicación, radiación y alcohol."

-- Fuentes (wiki de EFT): Stimulants, Status_effects, Medical.
-- [VERIFICAR] Valores de memoria; la wiki no es accesible desde el entorno de desarrollo.

ix.efg = ix.efg or {}
ix.efg.effects = ix.efg.effects or {}

local FX = ix.efg.effects

-- Tipos de efecto. Cada efecto activo es {id, until, strength, start}.
--   regen      PV por segundo repartidos (negativo = daño)
--   speed      multiplicador de velocidad (0.1 = +10 %)
--   stamina    multiplicador de recuperación de aguante
--   painkiller quita el dolor
--   hemostatic detiene sangrados nuevos y existentes
--   tremor     temblor de manos
--   tunnel     visión de túnel
--   water      hidratación por minuto
--   energy     energía por minuto
--   weight     multiplicador de peso máximo
--   antidote   cura intoxicación y radiación
--   toxin      intoxicación (daño y temblor hasta curar)
--   radiation  radiación (daño lento hasta curar)
--   freshwound más probabilidad de sangrado en esa zona
--   fatigue    menos velocidad y aguante
--   alcohol    analgésico leve, temblor y visión borrosa
FX.names = {
	regen = "Regeneración", speed = "Velocidad", stamina = "Recuperación de aguante",
	painkiller = "Analgésico", hemostatic = "Hemostático", tremor = "Temblor de manos",
	tunnel = "Visión de túnel", water = "Hidratación", energy = "Energía", weight = "Peso máximo",
	antidote = "Antídoto", toxin = "Intoxicación", radiation = "Radiación",
	freshwound = "Herida fresca", fatigue = "Fatiga", alcohol = "Embriaguez"
}

FX.negative = {tremor = true, tunnel = true, toxin = true, radiation = true, freshwound = true, fatigue = true, alcohol = true}

-- Estimulantes: lista de {efecto, fuerza, retraso (s), duración (s)}
FX.stims = {
	propital = {"Propital", 18000, {
		{"regen", 1, 0, 300}, {"painkiller", 1, 0, 300}, {"tremor", 1, 270, 30}}},
	etgc = {"eTG-change", 35000, {
		{"regen", 6.5, 0, 60}, {"energy", -15, 60, 120}, {"water", -15, 60, 120}}},
	adrenaline = {"Adrenalina", 25000, {
		{"painkiller", 1, 0, 60}, {"regen", 4, 0, 15}, {"stamina", 0.5, 0, 60}, {"water", -15, 0, 60}}},
	morphine = {"Morfina", 17000, {
		{"painkiller", 1, 0, 305}, {"energy", -10, 0, 60}, {"water", -15, 0, 60}}},
	sj1 = {"SJ1 TGLabs", 45000, {
		{"stamina", 0.3, 0, 180}, {"speed", 0.05, 0, 180}, {"energy", -10, 0, 180}, {"water", -10, 0, 180}}},
	sj6 = {"SJ6 TGLabs", 55000, {
		{"stamina", 2, 0, 240}, {"speed", 0.1, 0, 240}, {"tremor", 1, 240, 30}, {"water", -20, 240, 60}}},
	meldonin = {"Meldonin", 40000, {
		{"stamina", 0.5, 0, 900}, {"water", -5, 0, 900}}},
	l1 = {"L1 (Norepinefrina)", 30000, {
		{"painkiller", 1, 0, 120}, {"speed", 0.05, 0, 60}, {"water", -15, 0, 60}}},
	mule = {"M.U.L.E.", 50000, {
		{"weight", 0.5, 0, 900}, {"regen", -0.1, 0, 900}}},
	zagustin = {"Zagustin", 30000, {
		{"hemostatic", 1, 0, 180}, {"tremor", 1, 180, 30}, {"water", -10, 0, 180}}},
	ahf1m = {"AHF1-M", 30000, {
		{"hemostatic", 1, 0, 60}, {"water", -10, 0, 60}}},
	perfotoran = {"Perfotoran (sangre azul)", 45000, {
		{"antidote", 1, 0, 60}, {"regen", 1.5, 0, 60}, {"energy", -10, 60, 60}}},
	trimadol = {"Trimadol", 40000, {
		{"painkiller", 1, 0, 180}, {"stamina", 0.3, 0, 180}, {"speed", 0.05, 0, 180}, {"water", -10, 0, 180}}},
	xtg12 = {"xTG-12 (antídoto)", 70000, {
		{"antidote", 1, 0, 30}}},
	p22 = {"P22", 60000, {
		{"stamina", 0.5, 0, 240}, {"regen", 1, 0, 240}, {"water", -15, 240, 60}}},
	-- [VERIFICAR] SJ9: más aguante y menos temperatura; 3-(b-TG): fuerza y menos retroceso
	sj9 = {"SJ9 TGLabs", 58000, {
		{"stamina", 0.3, 0, 300}, {"water", -10, 0, 300}, {"tremor", 1, 280, 20}}},
	["3btg"] = {"3-(b-TG)", 55000, {
		{"weight", 0.1, 0, 240}, {"stamina", 0.2, 0, 240}, {"energy", -15, 0, 240}, {"tremor", 1, 240, 30}}},
	obdolbos = {"Obdolbos", 25000, "random"}
}

FX.alcohol = {vodka = 90, whiskey = 90, moonshine = 120, cerveza = 30, beer = 30, wine = 60}

function FX.Describe(id)
	local stim = FX.stims[id]
	if (!stim) then return "" end
	if (stim[3] == "random") then return "Efectos aleatorios, buenos y malos." end

	local lines = {}

	for _, e in ipairs(stim[3]) do
		local name = FX.names[e[1]] or e[1]
		local when = e[3] > 0 and (" tras " .. e[3] .. " s") or ""
		local value = (e[1] == "speed" or e[1] == "stamina" or e[1] == "weight") and (("%+d %%"):format(e[2] * 100))
			or (e[1] == "regen" and ("%+.1f PV/s"):format(e[2]))
			or ((e[1] == "water" or e[1] == "energy") and ("%+d/min"):format(e[2])) or ""

		lines[#lines + 1] = ("%s %s%s (%d s)"):format(name, value, when, e[4])
	end

	return table.concat(lines, "\n")
end

-- Efectos activos del jugador (en el cliente vienen por netvar)
function FX.Get(client)
	return SERVER and (client.efgEffects or {}) or (client:GetNetVar("efgEffects") or {})
end

function FX.Has(client, id)
	local now = CurTime()

	for _, e in ipairs(FX.Get(client)) do
		if (e[1] == id and e[2] > now and (e[4] or 0) <= now) then
			return e[3] or 1
		end
	end
end

-- Velocidad (estimulantes y fatiga)
hook.Add("SetupMove", "ixEFGEffectsSpeed", function(client, mv)
	local speed = FX.Has(client, "speed")
	local fatigue = FX.Has(client, "fatigue")

	if (speed or fatigue) then
		local mult = 1 + (speed or 0) - (fatigue and 0.1 or 0)
		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
	end
end)

-- Peso máximo con M.U.L.E. (plugin weight, CHAR:GetMaxWeight)
function PLUGIN:EFGGetCarryMultiplier(client)
	local weight = FX.Has(client, "weight")
	return weight and (1 + weight) or nil
end

-- Recuperación de aguante (plugin stamina de Helix)
function PLUGIN:AdjustStaminaOffset(client, offset)
	if (offset <= 0) then return end

	local stamina = FX.Has(client, "stamina")
	local fatigue = FX.Has(client, "fatigue")

	if (stamina or fatigue) then
		return offset * (1 + (stamina or 0)) * (fatigue and 0.5 or 1)
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
