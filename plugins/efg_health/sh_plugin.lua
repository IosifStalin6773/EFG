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

-- Bloquea el sprint con una pierna rota o destruida (salvo con analgésicos)
hook.Add("SetupMove", "ixEFGHealthSprint", function(client, mv)
	if (client:GetNetVar("efgNoSprint") and mv:KeyDown(IN_SPEED)) then
		mv:SetMaxClientSpeed(client:GetWalkSpeed())
		mv:SetMaxSpeed(client:GetWalkSpeed())
	end
end)

-- ─── Tratamiento tras la raid (La Doctora) ───────────────────────────────────
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

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
