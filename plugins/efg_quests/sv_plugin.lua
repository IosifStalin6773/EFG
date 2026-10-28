local PLUGIN = PLUGIN

if (!SERVER) then return end

local function kill(group, count)
	return {type = "kill", npcGroup = group, count = count}
end

local function deliver(itemID, count)
	return {type = "deliver", itemID = itemID, count = count, fir = true}
end

-- id = "eft_*" para no chocar con las creadas en el juego ("m1", "m2"...).
-- rewardOptions.balas = rublos; rep en la escala 0-1000 de traders.
PLUGIN.quests = {
	{
		id = "eft_debut", trader = "prapor", name = "Debut",
		description = "Prapor quiere ver de qué estás hecho: elimina Scavs en la zona.",
		steps = {kill("scav", 5)},
		reward = {balas = 15000, rep = 20}
	},
	{
		id = "eft_shootout_picnic", trader = "prapor", name = "Picnic de tiroteo", requires = {"eft_debut"},
		description = "Los Scavs se están organizando. Reduce su número.",
		steps = {kill("scav", 15)},
		reward = {balas = 30000, rep = 30}
	},
	{
		id = "eft_shortage", trader = "therapist", name = "Escasez",
		description = "Al hospital le faltan botiquines. Encuentra Salewa en raid y tráelos.",
		steps = {deliver("salewa", 3)},
		reward = {balas = 15000, rep = 20}
	},
	{
		id = "eft_painkiller", trader = "therapist", name = "Analgésico", requires = {"eft_shortage"},
		description = "Therapist necesita inyectores de morfina encontrados en raid.",
		steps = {deliver("stim_morphine", 4)},
		reward = {balas = 25000, rep = 30}
	},
	{
		id = "eft_friend_west_1", trader = "skier", name = "Un amigo del Oeste, parte 1",
		description = "Skier tiene cuentas pendientes con los USEC. Elimínalos.",
		steps = {kill("usec", 7)},
		reward = {balas = 30000, rep = 30}
	},
	{
		id = "eft_acquaintance", trader = "jaeger", name = "Conocidos",
		description = "Jaeger quiere comprobar si eres de fiar: tráele comida y agua encontradas en raid.",
		steps = {deliver("canned", 2), deliver("water", 2)},
		reward = {balas = 20000, rep = 20}
	},
	{
		id = "eft_tigr_safari", trader = "peacekeeper", name = "Safari",
		description = "Peacekeeper paga por bajas de PMC en la zona.",
		steps = {kill("pmc", 5)},
		reward = {balas = 40000, rep = 30}
	},
	{
		id = "eft_bosses", trader = "prapor", name = "Cazador de jefes", requires = {"eft_shootout_picnic"},
		description = "Elimina a uno de los jefes que controlan la zona.",
		steps = {kill("boss", 1)},
		reward = {balas = 80000, rep = 50}
	},
}

function PLUGIN:PostLoadData()
	if (!ix.missions or !ix.missions.list) then return end

	local added = 0

	for _, quest in ipairs(self.quests) do
		if (!ix.missions.list[quest.id]) then
			ix.missions.list[quest.id] = {
				id = quest.id,
				name = quest.name,
				description = quest.description,
				factions = {quest.trader},
				traderKey = "",
				traderName = "",
				adminName = "EFG",
				allowedFactions = {},
				repeatMode = "once",
				cooldown = 0,
				isDaily = false,
				rewardOptions = {{balas = quest.reward.balas, rep = quest.reward.rep, items = {}}},
				steps = table.Copy(quest.steps),
				requires = quest.requires or {}
			}

			added = added + 1
		end
	end

	if (added > 0) then
		local missions = ix.plugin.Get("missions")
		if (missions) then missions:SaveData() end

		MsgC(Color(227, 114, 45), ("[EFG] %d tareas de EFT añadidas a missions.\n"):format(added))
	end
end
