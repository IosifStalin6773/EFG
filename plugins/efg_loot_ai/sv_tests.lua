-- ============================================================================
--  Cuerpos de prueba (Fase 4): un ragdoll delante del admin con el mismo
--  equipo y botín que llevaría la IA, montado con AI.BuildCorpse. Sirve para
--  probar la generación y la ventana sin esperar a que aparezca la IA.
-- ============================================================================

local LOOT = ix.efg.loot
local AI = ix.efg.lootai

AI.TEST_MODEL = "models/Humans/Group01/male_07.mdl"

local function spawnSpot(client)
	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetAimVector() * 150,
		filter = client
	})

	return trace.HitPos + trace.HitNormal * 16
end

-- profileID: perfil de sh_ai_tables ("scav", "pmc", "boss", "raider")
-- opts: level (nivel fijo), kind (diseño de la ventana), name, model
function AI.SpawnTestCorpse(client, profileID, opts)
	opts = opts or {}

	local loadout = AI.BuildLoadout(client, profileID, opts.level)
	if (!loadout) then return end

	if (opts.kind) then loadout.kind = opts.kind end

	local corpse = ents.Create("prop_ragdoll")
	if (!IsValid(corpse)) then return end

	corpse:SetModel(opts.model or AI.TEST_MODEL)
	corpse:SetPos(spawnSpot(client))
	corpse:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
	corpse:Spawn()
	corpse:Activate()

	AI.BuildCorpse({efgLoot = loadout}, corpse)

	if (opts.name and corpse.efgLoot) then
		corpse.efgLoot.name = opts.name
	end

	-- se borra solo con la limpieza del mapa o con el undo del admin
	undo.Create("efg_loot_test")
		undo.AddEntity(corpse)
		undo.SetPlayer(client)
	undo.Finish()

	LOOT.Log("raid", ("raid %d · prueba de %s · %s (%s%s) · equipo %s · botín %s · valor %s RUB"):format(LOOT.raidSerial,
		client:Name(), loadout.kind, profileID, loadout.level and (" nv " .. loadout.level) or "",
		AI.DescribeGear(loadout), LOOT.Describe(AI.AllLoot(loadout)), string.Comma(AI.Value(loadout))))

	return corpse, loadout
end

function AI.TestSummary(loadout)
	return ("%s%s · equipo: %s · botín: %d objetos · valor %s RUB"):format(loadout.profile,
		loadout.level and (" nv " .. loadout.level) or "", AI.DescribeGear(loadout),
		#AI.AllLoot(loadout), string.Comma(AI.Value(loadout)))
end
