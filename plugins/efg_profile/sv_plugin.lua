-- Recogida de estadísticas del perfil. Los cambios se acumulan en una copia en
-- memoria y se guardan (y envían al dueño) cada 20 s o al acabar una raid, para
-- no mandar la tabla entera con cada paso o cada disparo.
local PLUGIN = PLUGIN
local PROFILE = ix.efg.profile

util.AddNetworkString("ixEFGProfileExtra")

local cache = {} -- [character id] = {data =, dirty =}

local function entry(character)
	local id = character:GetID()
	local slot = cache[id]

	if (!slot) then
		slot = {data = table.Copy(PROFILE.Get(character))}
		cache[id] = slot
	end

	return slot
end

local function bump(character, group, key, amount)
	if (!character) then return end

	local slot = entry(character)
	local data = slot.data

	if (group) then
		data[group] = data[group] or {}
		data[group][key] = (data[group][key] or 0) + (amount or 1)
	else
		data[key] = (data[key] or 0) + (amount or 1)
	end

	slot.dirty = true
	return data
end

local function flush(character)
	local slot = character and cache[character:GetID()]

	if (slot and slot.dirty) then
		slot.dirty = nil
		character:SetData("efgProfile", slot.data)
	end
end

local function charOf(client)
	return IsValid(client) and client:IsPlayer() and client:GetCharacter() or nil
end

local function raidSide(client)
	return IsValid(client) and client:IsPlayer() and client:GetNetVar("efgRaidSide") or nil
end

timer.Create("efgProfileFlush", 20, 0, function()
	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (character) then
			bump(character, nil, "online", 20)
			flush(character)
		end
	end
end)

function PLUGIN:EFGCharacterWiped(client, character)
	cache[character:GetID()] = nil
	character:SetData("efgProfile", nil)
end

function PLUGIN:CharacterDeleted(client, id)
	cache[id] = nil
end

function PLUGIN:PlayerDisconnected(client)
	flush(client:GetCharacter())
	client.efgProfStart, client.efgProfPos = nil, nil
end

function PLUGIN:PrePlayerLoadedCharacter(client, character, lastChar)
	flush(lastChar)
end

-- ─── Raids ───────────────────────────────────────────────────────────────────
function PLUGIN:EFGRaidStarted(client, side)
	bump(charOf(client), side, "raids")
	client.efgProfStart = CurTime()
	client.efgProfPos = client:GetPos()
end

function PLUGIN:EFGRaidEnded(client, side, reason, runThrough)
	local character = charOf(client)
	if (!character) then return end

	if (client.efgProfStart) then
		bump(character, side, "lifeTime", math.floor(CurTime() - client.efgProfStart))
	end

	client.efgProfStart, client.efgProfPos = nil, nil

	local data = entry(character).data
	data[side] = data[side] or {}
	local stats = data[side]

	if (reason == "extract") then
		bump(character, side, "survived")
		if (runThrough) then bump(character, side, "runthrough") end
		stats.streak = (stats.streak or 0) + 1
		stats.bestStreak = math.max(stats.bestStreak or 0, stats.streak)
	elseif (reason == "death") then
		bump(character, side, "kia")
		stats.streak = 0
	elseif (reason == "mia") then
		bump(character, side, "mia")
		stats.streak = 0
	end

	flush(character)
end

-- salir del servidor o cambiar de personaje en plena raid (AWOL)
function PLUGIN:EFGRaidAbandoned(client, character, side)
	side = side == "scav" and "scav" or "pmc"
	bump(character, side, "awol")
	entry(character).data[side].streak = 0
	flush(character)
end

-- ─── Combate ─────────────────────────────────────────────────────────────────
function PLUGIN:PlayerDeath(victim, inflictor, attacker)
	local side = raidSide(attacker)
	if (!side or attacker == victim) then return end

	local character = charOf(attacker)
	bump(character, side, "kills")
	bump(character, side, raidSide(victim) == "scav" and "killsScav" or "killsPMC")

	if (victim:LastHitGroup() == HITGROUP_HEAD) then bump(character, side, "headshots") end
end

function PLUGIN:OnNPCKilled(npc, attacker)
	local side = raidSide(attacker)
	if (!side) then return end

	local character = charOf(attacker)
	bump(character, side, "kills")
	bump(character, side, npc.efgIsScav and "killsScav" or "killsAI")

	if (npc.LastHitGroup and npc:LastHitGroup() == HITGROUP_HEAD) then bump(character, side, "headshots") end
end

function PLUGIN:PostEntityTakeDamage(target, dmginfo, took)
	if (!took or !IsValid(target)) then return end

	local amount = math.floor(dmginfo:GetDamage())
	if (amount <= 0) then return end

	local attacker = dmginfo:GetAttacker()

	if (raidSide(attacker) and attacker != target and (target:IsPlayer() or target:IsNPC())) then
		bump(charOf(attacker), "combat", "dealt", amount)
	end

	if (target:IsPlayer()) then
		bump(charOf(target), "health", "taken", amount)
	end
end

-- ─── Salud (efg_health) ──────────────────────────────────────────────────────
local HEALTH_KEYS = {lost = "lost", fracture = "fractures", bleed = "bleeds"}

function PLUGIN:EFGHealthEvent(client, kind, partID, amount)
	local character = charOf(client)

	if (kind == "absorbed") then
		bump(character, "combat", "absorbed", math.floor(amount or 0))
	elseif (HEALTH_KEYS[kind]) then
		bump(character, "health", HEALTH_KEYS[kind])
		if (partID) then bump(character, "parts", partID) end
	end
end

function PLUGIN:EFGHealed(client, used)
	bump(charOf(client), "health", "healed", math.floor(used or 0))
end

-- consumibles usados (cualquier acción que no sea mover, tirar o equipar)
local PASSIVE = {drop = true, take = true, combine = true, Equip = true, EquipUn = true, View = true}

function PLUGIN:PlayerInteractItem(client, action, item)
	if (PASSIVE[action] or !istable(item)) then return end

	local character = charOf(client)

	if (item.base == "base_efgmed") then
		bump(character, "health", "meds")
	elseif (item.category == "Bebidas") then
		bump(character, "health", "drink")
	elseif (item.category == "Comestibles") then
		bump(character, "health", "food")
	end
end

-- ─── Experiencia por tipo (efg_raids GiveXP) ─────────────────────────────────
function PLUGIN:EFGXPGained(character, amount, kind)
	bump(character, "xp", kind, amount)
end

-- ─── Botín y distancia ───────────────────────────────────────────────────────
function PLUGIN:OnItemTransferred(item, oldInv, newInv)
	local character = newInv and newInv.owner and ix.char.loaded[newInv.owner]
	local client = character and character:GetPlayer()

	if (!raidSide(client) or (oldInv and oldInv.owner == newInv.owner)) then return end

	bump(character, "loot", "items")
end

local nextMove = 0

function PLUGIN:Think()
	if (nextMove > CurTime()) then return end
	nextMove = CurTime() + 1

	for _, client in player.Iterator() do
		if (client.efgProfPos and client:Alive() and raidSide(client)) then
			local pos = client:GetPos()
			local dist = pos:Distance(client.efgProfPos)
			client.efgProfPos = pos

			-- descarta teletransportes (unidades de Source → metros)
			if (dist > 4 and dist < 1200) then
				bump(client:GetCharacter(), "loot", "distance", dist * 0.01905)
			end
		end
	end
end

-- ─── Datos que el cliente no tiene (al abrir la pestaña) ─────────────────────
local function stashValue(character)
	local stash = ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character)
	local total, seen = 0, {}
	local queue = {stash}

	while (#queue > 0) do
		local inventory = table.remove(queue)

		if (inventory and !seen[inventory:GetID()]) then
			seen[inventory:GetID()] = true

			for _, item in pairs(inventory:GetItems(true)) do
				total = total + (tonumber(item.price) or 0) * math.max(1, tonumber(item:GetData("count")) or 1)

				local bag = item:GetData("id") and ix.item.inventories[item:GetData("id")]
				if (bag) then queue[#queue + 1] = bag end
			end
		end
	end

	return math.floor(total)
end

net.Receive("ixEFGProfileExtra", function(_, client)
	if ((client.efgNextProfile or 0) > CurTime()) then return end
	client.efgNextProfile = CurTime() + 2

	local character = client:GetCharacter()
	if (!character) then return end

	flush(character)

	net.Start("ixEFGProfileExtra")
		net.WriteUInt(math.max(0, math.floor(tonumber(character.GetCreateTime and character:GetCreateTime()) or 0)), 32)
		net.WriteUInt(math.max(0, math.floor(tonumber(character.GetLastJoinTime and character:GetLastJoinTime()) or 0)), 32)
		net.WriteDouble(stashValue(character))
	net.Send(client)
end)
