local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Salud"
PLUGIN.author      = "EFG"
PLUGIN.description = "Salud por partes del cuerpo: sangrados, fracturas, dolor y extremidades destruidas."

ix.efg = ix.efg or {}
ix.efg.health = ix.efg.health or {}

-- Vida máxima de cada parte (valores de EFT, 440 en total)
ix.efg.health.parts = {
	{id = "head",     name = "Cabeza",          max = 35, vital = true},
	{id = "thorax",   name = "Tórax",           max = 85, vital = true},
	{id = "stomach",  name = "Estómago",        max = 70, spread = 1.5},
	{id = "larm",     name = "Brazo izquierdo", max = 60, spread = 0.7, arm = true},
	{id = "rarm",     name = "Brazo derecho",   max = 60, spread = 0.7, arm = true},
	{id = "lleg",     name = "Pierna izquierda", max = 65, spread = 1, leg = true},
	{id = "rleg",     name = "Pierna derecha",  max = 65, spread = 1, leg = true}
}

ix.efg.health.byID = {}
ix.efg.health.total = 0

for i, part in ipairs(ix.efg.health.parts) do
	part.index = i
	ix.efg.health.byID[part.id] = part
	ix.efg.health.total = ix.efg.health.total + part.max
end

ix.config.Add("efgLightBleedChance", 25, "Probabilidad (%) de sangrado leve por impacto de bala.", nil, {
	data = {min = 0, max = 100},
	category = "EFG Salud"
})

ix.config.Add("efgHeavyBleedChance", 8, "Probabilidad (%) de sangrado grave por impacto de bala.", nil, {
	data = {min = 0, max = 100},
	category = "EFG Salud"
})

ix.config.Add("efgFractureChance", 12, "Probabilidad (%) de fractura por impacto de bala en una extremidad.", nil, {
	data = {min = 0, max = 100},
	category = "EFG Salud"
})

-- [VERIFICAR] EFT regenera mucho más despacio fuera de raid (del orden de horas)
ix.config.Add("efgOutOfRaidRegenTime", 120, "Segundos para recuperar una parte entera fuera de raid (se para mientras sangras).", nil, {
	data = {min = 10, max = 36000},
	category = "EFG Salud"
})

-- Brazos rotos o destruidos: los objetos (y las recargas ARC9) tardan más.
-- +25 % por brazo roto, +50 % por brazo destruido; los analgésicos quitan la
-- mitad del castigo de las fracturas. Lee la netvar efgHP, así vale en los dos lados.
function ix.efg.health.UseTimeMult(client)
	local data = IsValid(client) and client:GetNetVar("efgHP")
	if (!data) then return 1 end

	local mult = 1
	local painkiller = client:GetNetVar("efgPainkiller")

	for _, part in ipairs(ix.efg.health.parts) do
		local entry = part.arm and data[part.index]

		if (entry) then
			if (entry[1] <= 0) then
				mult = mult + 0.5
			elseif (bit.band(entry[2], 4) != 0) then
				mult = mult + (painkiller and 0.125 or 0.25)
			end
		end
	end

	return math.min(mult, 2)
end

-- Recarga más lenta con los brazos dañados: ARC9 lee ReloadTime del arma, así
-- que se escala el valor base de la instancia y se vacían sus cachés.
local nextReloadCheck = 0

hook.Add("Think", "ixEFGHealthReload", function()
	if (nextReloadCheck > CurTime()) then return end
	nextReloadCheck = CurTime() + 0.5

	for _, client in ipairs(CLIENT and {LocalPlayer()} or player.GetAll()) do
		local weapon = IsValid(client) and client:GetActiveWeapon()

		if (IsValid(weapon) and weapon.ARC9 and weapon.ReloadTime and !(weapon.GetReloading and weapon:GetReloading())) then
			local mult = ix.efg.health.UseTimeMult(client)

			if (weapon.efgReloadMult != mult) then
				weapon.efgReloadBase = weapon.efgReloadBase or weapon.ReloadTime
				weapon.ReloadTime = weapon.efgReloadBase * mult
				weapon.efgReloadMult = mult

				if (weapon.InvalidateCache) then weapon:InvalidateCache() end
			end
		end
	end
end)

-- Bloquea el sprint con una pierna rota o destruida (salvo con analgésicos)
hook.Add("SetupMove", "ixEFGHealthSprint", function(client, mv)
	if (client:GetNetVar("efgNoSprint") and mv:KeyDown(IN_SPEED)) then
		mv:SetMaxClientSpeed(client:GetWalkSpeed())
		mv:SetMaxSpeed(client:GetWalkSpeed())
	end
end)

-- ─── Tratamiento tras la raid (Therapist) ───────────────────────────────────
-- Precio por punto de vida que falta y por cada herida. data es la tabla que
-- llega en la netvar efgHP: {{hp, flags}, ...} en el orden de health.parts.
ix.efg.health.treatmentPrice = {hp = 25, lightBleed = 400, heavyBleed = 1200, fracture = 1500, destroyed = 6000}

function ix.efg.health.TreatmentQuote(data)
	local price = ix.efg.health.treatmentPrice
	local quote = {hp = 0, lightBleed = 0, heavyBleed = 0, fracture = 0, destroyed = 0, total = 0}

	for i, part in ipairs(ix.efg.health.parts) do
		local entry = data and data[i]

		if (entry) then
			local hp, flags = entry[1], entry[2]
			quote.hp = quote.hp + math.max(0, part.max - math.max(hp, 0))
			if (hp <= 0) then quote.destroyed = quote.destroyed + 1 end
			if (bit.band(flags, 1) != 0) then quote.lightBleed = quote.lightBleed + 1 end
			if (bit.band(flags, 2) != 0) then quote.heavyBleed = quote.heavyBleed + 1 end
			if (bit.band(flags, 4) != 0) then quote.fracture = quote.fracture + 1 end
		end
	end

	quote.hp = math.ceil(quote.hp)

	for key, value in pairs(price) do
		quote.total = quote.total + (quote[key] or 0) * value
	end

	return quote
end

-- Botiquines (AI-2, coche, Salewa, IFAK): curan la parte elegida (o la más
-- dañada) y, según el botiquín, detienen sangrados gastando puntos.
function ix.efg.health.MedkitCanApply(item, client, part)
	local health = ix.efg.health
	local hp = health.GetHP(client)
	local bleed = health.GetStatus(client).bleed

	if (part) then
		local info = health.byID[part]

		if (hp[part] <= 0) then return false, "Esa parte está destruida: necesitas un kit quirúrgico." end
		if (hp[part] < info.max) then return true end
		if (bleed[part] and (item.stopsBleed == "heavy" or bleed[part] == item.stopsBleed)) then return true end

		return false, info.name .. " no necesita " .. item.name .. "."
	end

	for _, info in ipairs(health.parts) do
		if (hp[info.id] > 0 and hp[info.id] < info.max) then return true end
	end

	if (item.stopsBleed != "" and next(bleed)) then return true end

	return false, "Estás sano."
end

function ix.efg.health.MedkitApply(item, client, part)
	local health = ix.efg.health
	local spent = health.Heal(client, math.min(item.healPerUse, item:GetUses()), part)

	-- detener un sangrado cuesta puntos del botiquín, como en EFT; los que paran
	-- sangrados graves también paran los leves
	if (item.stopsBleed != "" and health.StopBleeding(client, item.stopsBleed, part)) then
		spent = spent + (item.stopsBleed == "heavy" and 175 or 50)
	elseif (item.stopsBleed == "heavy" and health.StopBleeding(client, "light", part)) then
		spent = spent + 50
	end

	return math.ceil(spent)
end

if (SERVER and ix.efg.SendContent()) then
	resource.AddFile("sound/efg/health/ui_open.wav")
	resource.AddFile("sound/efg/health/ui_close.wav")
	resource.AddFile("sound/efg/health/bone_break.wav")

	for _, name in ipairs(file.Find("sound/efg/damage/*.wav", "GAME")) do
		resource.AddFile("sound/efg/damage/" .. name)
	end

	for _, name in ipairs(file.Find("sound/efg/health/items/*.wav", "GAME")) do
		resource.AddFile("sound/efg/health/items/" .. name)
	end
end

ix.util.Include("sh_medanim.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_vitals.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_movement.lua")
