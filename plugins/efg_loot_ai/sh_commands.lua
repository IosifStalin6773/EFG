-- Comandos de prueba del loot de IA (Fase 4). Dejan un cuerpo delante del
-- admin con el loot generado y lo apuntan en data/efg/loot/raid_<fecha>.txt.

ix.command.Add("LootTestScav", {
	description = "@cmdLootTestScav",
	adminOnly = true,
	OnRun = function(self, client)
		local corpse, loadout = ix.efg.lootai.SpawnTestCorpse(client, "scav")
		if (!IsValid(corpse)) then return "@efgLootTestFailed" end

		return "@efgLootTestSpawned", ix.efg.lootai.TestSummary(loadout)
	end
})

ix.command.Add("LootTestPMC", {
	description = "@cmdLootTestPMC",
	adminOnly = true,
	arguments = bit.bor(ix.type.number, ix.type.optional),
	OnRun = function(self, client, level)
		local character = client:GetCharacter()
		level = math.Clamp(math.floor(level or (character and character.GetEFGLevel and character:GetEFGLevel()) or 1), 1, 79)

		local corpse, loadout = ix.efg.lootai.SpawnTestCorpse(client, "pmc", {level = level})
		if (!IsValid(corpse)) then return "@efgLootTestFailed" end

		return "@efgLootTestSpawned", ix.efg.lootai.TestSummary(loadout)
	end
})

ix.command.Add("LootTestPlayer", {
	description = "@cmdLootTestPlayer",
	adminOnly = true,
	OnRun = function(self, client)
		local character = client:GetCharacter()
		local level = (character and character.GetEFGLevel and character:GetEFGLevel()) or 1

		local corpse, loadout = ix.efg.lootai.SpawnTestCorpse(client, "pmc", {
			level = level,
			kind = "player",
			name = client:Name(),
			model = client:GetModel()
		})

		if (!IsValid(corpse)) then return "@efgLootTestFailed" end

		return "@efgLootTestSpawned", ix.efg.lootai.TestSummary(loadout)
	end
})
