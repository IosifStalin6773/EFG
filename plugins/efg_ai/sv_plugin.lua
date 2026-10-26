local PLUGIN = PLUGIN

PLUGIN.alive = PLUGIN.alive or {} -- [npc] = zoneIndex

-- Botín que suelta la IA al morir: {uniqueID, probabilidad 0-1, cantidad}
PLUGIN.loot = {
	scav = {
		{"bala", 0.6, function() return {count = math.random(5, 60) * 100} end},
		{"vendas", 0.4}, {"ai2", 0.25}, {"analgin", 0.1}, {"water", 0.3}, {"canned", 0.3},
		{"ammo_pistol", 0.3}, {"ammo_smg1", 0.3}, {"ammo_buckshot", 0.2},
		{"arc9_eft_toz106", 0.06}, {"arc9_eft_pm", 0.1}, {"arc9_eft_mr43", 0.05},
		{"arc9_eft_kedr", 0.05}, {"arc9_eft_aks74u", 0.05},
		{"armor_paca", 0.08}, {"armor_6b2", 0.05}, {"helmet_ssh68", 0.1}, {"bp_scav", 0.15}
	},
	pmc = {
		{"bala", 0.8, function() return {count = math.random(20, 200) * 100} end},
		{"ifak", 0.3}, {"car", 0.3}, {"esmarch", 0.3}, {"ferula", 0.2}, {"analgin", 0.3},
		{"ammo_smg1", 0.5}, {"ammo_ar2", 0.5}, {"ammo_pistol", 0.3},
		{"arc9_eft_ak74", 0.1}, {"arc9_eft_m4a1", 0.06}, {"arc9_eft_mp5", 0.1}, {"arc9_eft_glock17", 0.1},
		{"armor_6b13", 0.1}, {"armor_trooper", 0.06}, {"helmet_fast", 0.08}, {"helmet_6b47", 0.1}, {"bp_trizip", 0.1}
	},
	boss = {
		{"bala", 1, function() return {count = math.random(300, 800) * 100} end},
		{"salewa", 0.6}, {"cms", 0.4}, {"ifak", 0.5},
		{"arc9_eft_ak103", 0.3}, {"arc9_eft_svds", 0.2}, {"arc9_eft_deagle_l6", 0.3},
		{"armor_korund", 0.3}, {"helmet_altyn", 0.2}, {"bp_blackjack", 0.2}
	}
}

function PLUGIN:LoadData()
	self.zones = self:GetData({}) or {}
end

function PLUGIN:SaveZones()
	self:SetData(self.zones)
end

function PLUGIN:AddZone(zone)
	self.zones = self.zones or {}
	self.zones[#self.zones + 1] = zone
	self:SaveZones()
end

function PLUGIN:RemoveNearestZone(pos)
	local bestIndex, bestDist

	for i, zone in ipairs(self.zones or {}) do
		local dist = zone.pos:Distance(pos)

		if (dist < 500 and (!bestDist or dist < bestDist)) then
			bestIndex, bestDist = i, dist
		end
	end

	if (!bestIndex) then
		return "No hay ninguna zona de IA a menos de 500 unidades."
	end

	table.remove(self.zones, bestIndex)
	self:SaveZones()

	return "Zona de IA borrada."
end

function PLUGIN:ClearAI()
	local count = 0

	for npc in pairs(self.alive) do
		if (IsValid(npc)) then
			npc:Remove()
			count = count + 1
		end
	end

	self.alive = {}

	return count
end

local function raiders()
	local list = {}

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive() and client.InRaid and client:InRaid()) then
			list[#list + 1] = client
		end
	end

	return list
end

local function nearestDistance(pos, players)
	local best = math.huge

	for _, client in ipairs(players) do
		best = math.min(best, client:GetPos():Distance(pos))
	end

	return best
end

-- busca un punto libre en el suelo dentro del radio de la zona
local function findSpot(zone, players, minDist)
	for _ = 1, 8 do
		local angle = math.Rand(0, math.pi * 2)
		local dist = math.Rand(0, zone.radius)
		local pos = zone.pos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 32)

		local trace = util.TraceHull({
			start = pos,
			endpos = pos - Vector(0, 0, 256),
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 72),
			mask = MASK_NPCSOLID
		})

		if (!trace.StartSolid and trace.Hit and nearestDistance(trace.HitPos, players) >= minDist) then
			return trace.HitPos
		end
	end
end

function PLUGIN:SpawnNPC(class, pos, zoneIndex, zoneType, weapons, bBoss)
	if (!scripted_ents.GetStored(class) and !list.Get("NPC")[class]) then
		if (!self.warned) then
			self.warned = true
			ErrorNoHalt("[EFG] No existe la clase de NPC " .. class .. ". ¿Está instalado VJ Base y el addon de SNPC de EFT?\n")
		end

		return
	end

	local npc = ents.Create(class)
	if (!IsValid(npc)) then return end

	npc:SetPos(pos)
	npc:SetAngles(Angle(0, math.random(0, 359), 0))
	npc:Spawn()
	npc:Activate()

	if (weapons and #weapons > 0) then
		npc:Give(weapons[math.random(#weapons)])
	end

	npc.efgZone = zoneIndex
	npc.efgAIType = zoneType
	npc.efgIsScav = self.zoneTypes[zoneType].isScav
	npc.efgIsBoss = bBoss

	self.alive[npc] = zoneIndex

	return npc
end

function PLUGIN:SpawnWave()
	local players = raiders()
	if (#players == 0 or !self.zones) then return end

	local total = 0

	for npc in pairs(self.alive) do
		if (IsValid(npc) and npc:Health() > 0) then
			total = total + 1
		else
			self.alive[npc] = nil
		end
	end

	local maxTotal = ix.config.Get("efgAIMax", 30)
	local activation = ix.config.Get("efgAIActivationDistance", 7000)
	local minDist = ix.config.Get("efgAIMinPlayerDistance", 900)

	for index, zone in ipairs(self.zones) do
		local zoneType = self.zoneTypes[zone.type]

		if (zoneType and nearestDistance(zone.pos, players) <= activation) then
			local count = 0

			for _, zoneIndex in pairs(self.alive) do
				if (zoneIndex == index) then
					count = count + 1
				end
			end

			if (count == 0 and zoneType.boss) then
				-- el jefe aparece con su escolta, y no en todas las raids
				if (math.random(100) <= (zoneType.chance or 100)) then
					local pos = findSpot(zone, players, minDist)

					if (pos) then
						self:SpawnNPC(zoneType.boss, pos, index, zone.type, nil, true)
						total = total + 1

						for _ = 1, zone.max - 1 do
							local guardPos = findSpot(zone, players, minDist)

							if (guardPos and total < maxTotal) then
								self:SpawnNPC(zoneType.classes[math.random(#zoneType.classes)], guardPos, index, zone.type)
								total = total + 1
							end
						end
					end
				end
			elseif (!zoneType.boss) then
				while (count < zone.max and total < maxTotal) do
					local pos = findSpot(zone, players, minDist)
					if (!pos) then break end

					self:SpawnNPC(zoneType.classes[math.random(#zoneType.classes)], pos, index, zone.type, zoneType.weapons)
					count = count + 1
					total = total + 1
				end
			end
		end
	end
end

local nextWave, nextCleanup = 0, 0

function PLUGIN:Think()
	if (nextWave <= CurTime()) then
		nextWave = CurTime() + ix.config.Get("efgAIWaveSeconds", 120)
		self:SpawnWave()
	end

	-- la IA lejos de cualquier jugador en raid desaparece
	if (nextCleanup <= CurTime()) then
		nextCleanup = CurTime() + 60

		local players = raiders()

		for npc in pairs(self.alive) do
			if (!IsValid(npc)) then
				self.alive[npc] = nil
			elseif (#players == 0 or nearestDistance(npc:GetPos(), players) > ix.config.Get("efgAIActivationDistance", 7000) * 1.5) then
				npc:Remove()
				self.alive[npc] = nil
			end
		end
	end
end

function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
	if (!self.alive[npc]) then return end

	self.alive[npc] = nil

	local lootTable = npc.efgIsBoss and self.loot.boss or (npc.efgAIType == "pmc" and self.loot.pmc or self.loot.scav)
	local pos = npc:GetPos() + Vector(0, 0, 24)

	for _, entry in ipairs(lootTable) do
		if (ix.item.list[entry[1]] and math.random() <= entry[2]) then
			local data = isfunction(entry[3]) and entry[3]() or nil
			ix.item.Spawn(entry[1], pos + VectorRand() * 12, nil, angle_zero, data)
		end
	end
end

-- Los Scav IA no atacan a los jugadores que juegan como Scav (como en EFT)
function PLUGIN:EFGRaidStarted(client, side)
	client.VJ_NPC_Class = (side == "scav") and {"CLASS_FRAC_WILD"} or nil
end

function PLUGIN:EFGRaidEnded(client)
	client.VJ_NPC_Class = nil
end
