local PLUGIN = PLUGIN

PLUGIN.name = "EFG Estados"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Hidratación y energía de EFT (sustituye el desgaste de needs), deshidratación, agotamiento, conmoción, temblores, visión túnel y fractura de pierna."

-- Fuentes (wiki de EFT):
--   Health ................ https://escapefromtarkov.fandom.com/wiki/Health
--   Status effects ........ https://escapefromtarkov.fandom.com/wiki/Status_effects
--   Hydration / Energy .... https://escapefromtarkov.fandom.com/wiki/Character#Health
-- La wiki no se puede leer desde el entorno de desarrollo (proxy), así que los
-- valores marcados como [VERIFICAR] son configurables y deben contrastarse con
-- la wiki. Los demás están confirmados en las páginas citadas.

ix.efg = ix.efg or {}
ix.efg.status = ix.efg.status or {}

-- Hidratación y energía: 0-100 (Character#Health). Se guardan en las variables
-- de personaje de needs (saturation = hidratación, satiety = energía).
ix.config.Add("efgHydrationDrain", 1, "[VERIFICAR wiki: Character#Health] Hidratación que se pierde por minuto en raid.", nil, {
	data = {min = 0, max = 10, decimals = 2}, category = "EFG Estados"
})
ix.config.Add("efgEnergyDrain", 0.8, "[VERIFICAR wiki: Character#Health] Energía que se pierde por minuto en raid.", nil, {
	data = {min = 0, max = 10, decimals = 2}, category = "EFG Estados"
})
ix.config.Add("efgStomachDrainMult", 5, "Multiplicador del desgaste de hidratación y energía con el estómago destruido (x5 en EFT).", nil, {
	data = {min = 1, max = 10, decimals = 1}, category = "EFG Estados"
})
ix.config.Add("efgNeedsRegen", 1, "Hidratación y energía recuperadas por minuto fuera de raid (escondite).", nil, {
	data = {min = 0, max = 10, decimals = 2}, category = "EFG Estados"
})
ix.config.Add("efgDehydrationDamage", 30, "[VERIFICAR wiki: Status effects#Dehydration] Daño por minuto con hidratación a 0 (repartido por el cuerpo).", nil, {
	data = {min = 0, max = 200}, category = "EFG Estados"
})
ix.config.Add("efgExhaustionDamage", 20, "[VERIFICAR wiki: Status effects#Exhaustion] Daño por minuto con energía a 0 (repartido por el cuerpo).", nil, {
	data = {min = 0, max = 200}, category = "EFG Estados"
})
ix.config.Add("efgContusionTime", 15, "[VERIFICAR wiki: Status effects#Contusion] Segundos de conmoción tras una explosión o un impacto parado por el casco.", nil, {
	data = {min = 0, max = 120}, category = "EFG Estados"
})
ix.config.Add("efgContusionDSP", 35, "[VERIFICAR wiki.facepunch.com/gmod/DSP_Presets] Preset DSP del sonido apagado durante la conmoción.", nil, {
	data = {min = 0, max = 133}, category = "EFG Estados"
})
ix.config.Add("efgLegFractureSpeed", 0.75, "[VERIFICAR wiki: Status effects#Fracture] Multiplicador de velocidad con una pierna rota o destruida.", nil, {
	data = {min = 0.3, max = 1, decimals = 2}, category = "EFG Estados"
})

-- Velocidad con fractura de pierna (el sprint ya lo bloquea efg_health)
hook.Add("SetupMove", "ixEFGStatusLegs", function(client, mv)
	if (!client:GetNetVar("efgLegHurt") or client:GetNetVar("efgPainkiller")) then return end

	local mult = ix.config.Get("efgLegFractureSpeed", 0.75)
	mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
	mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
end)

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
