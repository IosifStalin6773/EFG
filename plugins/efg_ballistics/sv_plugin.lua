local PLUGIN = PLUGIN

if (!SERVER) then return end

local B = ix.efg.ballistics

local function weaponItem(client, weapon)
	return ix.arc9 and ix.arc9.GetWeaponItem and ix.arc9.GetWeaponItem(client, weapon) or weapon.ixItem
end

-- ─── Montones de munición en el inventario ──────────────────────────────────
local function ammoStacks(inventory, roundID)
	local uniqueID = B.ItemID(roundID)
	local stacks = {}

	for _, item in pairs(inventory:GetItems()) do
		if (item.uniqueID == uniqueID) then
			stacks[#stacks + 1] = item
		end
	end

	-- se gastan primero los montones pequeños, como en EFT
	table.sort(stacks, function(a, b) return a:GetRounds() < b:GetRounds() end)

	return stacks
end

function B.CountRounds(inventory, roundID)
	local total = 0

	for _, item in ipairs(ammoStacks(inventory, roundID)) do
		total = total + item:GetRounds()
	end

	return total
end

function B.TakeRounds(inventory, roundID, amount)
	for _, item in ipairs(ammoStacks(inventory, roundID)) do
		if (amount <= 0) then break end

		local rounds = item:GetRounds()
		local take = math.min(rounds, amount)
		amount = amount - take

		if (rounds - take <= 0) then
			item:Remove()
		else
			item:SetData("rounds", rounds - take)
		end
	end
end

-- Añade balas al inventario llenando montones; lo que no cabe cae al suelo
function B.GiveRounds(client, roundID, amount)
	local inventory = client:GetCharacter():GetInventory()
	local uniqueID = B.ItemID(roundID)
	local itemTable = ix.item.list[uniqueID]
	if (!itemTable or amount <= 0) then return end

	for _, item in ipairs(ammoStacks(inventory, roundID)) do
		local space = item.maxStack - item:GetRounds()

		if (space > 0) then
			local put = math.min(space, amount)
			item:SetData("rounds", item:GetRounds() + put)
			amount = amount - put
		end

		if (amount <= 0) then return end
	end

	while (amount > 0) do
		local put = math.min(itemTable.maxStack, amount)
		amount = amount - put

		if (!inventory:Add(uniqueID, 1, {rounds = put})) then
			ix.item.Spawn(uniqueID, client:GetItemDropPos(), nil, nil, {rounds = put})
		end
	end
end

-- Saca las balas del cargador del arma y las devuelve como munición
function B.UnloadWeapon(client, item)
	local weapon = client:GetWeapon(item.class)
	local rounds = 0

	if (IsValid(weapon) and item:GetData("equip")) then
		rounds = math.max(0, weapon:Clip1())
		weapon:SetClip1(0)
	else
		rounds = item:GetData("ammo", 0)
	end

	item:SetData("ammo", 0)

	local round = B.GetSelectedRound(item)

	if (rounds > 0 and round) then
		B.GiveRounds(client, round.id, rounds)
		client:Notify(("Descargadas %d balas de %s."):format(rounds, round.name))
	end
end

-- ─── Reserva del arma = munición elegida en el inventario ───────────────────
-- Cada 0,2 s: si la reserva ha bajado (recarga), se descuenta del inventario;
-- después se iguala la reserva a lo que hay en el inventario (sin duplicar).
local function context(client)
	local weapon = client:GetActiveWeapon()
	if (!IsValid(weapon) or weapon:GetMaxClip1() <= 0) then return end

	local ammoType = weapon:GetPrimaryAmmoType()
	if (ammoType < 0) then return end

	local item = weaponItem(client, weapon)
	if (!item or item.isGrenade) then return end

	-- con cargadores (efg_mags) la reserva son las balas del cargador más lleno
	if (ix.efg.mags and ix.efg.mags.UsesMags(item)) then
		return {type = ammoType, weapon = weapon, reserve = ix.efg.mags.ReserveFor(client, item)}
	end

	local calID = B.GetWeaponCaliber(weapon:GetClass(), game.GetAmmoName(ammoType))
	local round = B.GetSelectedRound(item)
	local inventory = client:GetCharacter():GetInventory()

	-- sin munición elegida (o se ha acabado la elegida con el cargador vacío):
	-- coge la del calibre que más haya en el inventario
	if (!round or round.caliber != calID or (weapon:Clip1() <= 0 and B.CountRounds(inventory, round.id) <= 0)) then
		-- una sola pasada por el inventario: balas por tipo de este calibre
		local counts = {}

		for _, ammo in pairs(inventory:GetItems()) do
			if (ammo.isAmmo and ammo.efgCaliber == calID) then
				counts[ammo.efgRound] = (counts[ammo.efgRound] or 0) + ammo:GetRounds()
			end
		end

		local best, bestCount = nil, 0

		for id, count in pairs(counts) do
			if (count > bestCount) then
				best, bestCount = B.rounds[id], count
			end
		end

		if (best and (!round or best.id != round.id)) then
			item:SetData("efgRound", best.id)
			round = best
		end
	end

	if (!round or round.caliber != calID) then
		return {type = ammoType, weapon = weapon}
	end

	return {type = ammoType, round = round.id, weapon = weapon, inventory = inventory}
end

local nextSync = 0

function PLUGIN:Think()
	if (nextSync > CurTime()) then return end
	nextSync = CurTime() + 0.2

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and client:Alive()) then
			local last = client.efgPool
			local inventory = character:GetInventory()

			if (last and last.round) then
				local current = client:GetAmmoCount(last.type)

				if (current < last.set) then
					B.TakeRounds(inventory, last.round, last.set - current)
				elseif (current > last.set) then
					-- ARC9 vacía el cargador en la reserva al cambiar de cargador o
					-- de munición: esas balas vuelven al inventario
					B.GiveRounds(client, last.round, current - last.set)
				end
			end

			local ctx = context(client)

			if (ctx and ctx.reserve) then
				if (client:GetAmmoCount(ctx.type) != ctx.reserve) then
					client:SetAmmo(ctx.reserve, ctx.type)
				end

				client.efgPool = nil
			elseif (ctx and ctx.round) then
				local total = B.CountRounds(inventory, ctx.round)

				if (client:GetAmmoCount(ctx.type) != total) then
					client:SetAmmo(total, ctx.type)
				end

				client.efgPool = {type = ctx.type, round = ctx.round, set = total}
			else
				if (ctx and client:GetAmmoCount(ctx.type) > 0) then
					client:SetAmmo(0, ctx.type)
				end

				client.efgPool = nil
			end
		end
	end
end

function PLUGIN:PlayerDeath(client)
	client.efgPool = nil
end

function PLUGIN:PlayerDisconnected(client)
	client.efgPool = nil
end

-- ARC9 regala cargadores de reserva al coger un arma; aquí la reserva es el
-- inventario y lo que suba se devuelve como balas
function PLUGIN:InitPostEntity()
	if (ConVarExists("arc9_mult_defaultammo")) then
		RunConsoleCommand("arc9_mult_defaultammo", "0")
	end
end

-- ─── Daño de la munición elegida ────────────────────────────────────────────
function PLUGIN:EntityFireBullets(entity, data)
	if (!IsValid(entity) or !entity:IsPlayer()) then return end

	local weapon = entity:GetActiveWeapon()
	local item = IsValid(weapon) and weaponItem(entity, weapon)
	local round = item and B.GetSelectedRound(item)
	if (!round or round.generic) then return end

	weapon.efgRound = round

	data.Damage = round.damage
	data.Num = round.pellets or data.Num

	if (round.pellets and round.pellets > 1 and (data.Spread or vector_origin):IsZero()) then
		data.Spread = Vector(0.04, 0.04, 0)
	end

	return true
end

-- Munición del disparo que ha causado el daño (para el blindaje)
function B.GetDamageRound(dmginfo)
	local inflictor = dmginfo:GetInflictor()
	local attacker = dmginfo:GetAttacker()

	if (IsValid(inflictor) and inflictor.efgRound) then return inflictor.efgRound end

	if (IsValid(attacker) and attacker:IsPlayer()) then
		local weapon = attacker:GetActiveWeapon()
		if (IsValid(weapon) and weapon.efgRound) then return weapon.efgRound end
	end
end

-- ─── Blindaje: fórmula de EFT (Ballistics#Armor) ────────────────────────────
-- Probabilidad de penetrar según la penetración de la bala, la clase y la
-- durabilidad (%) que queda en el blindaje.
function B.PenetrationChance(pen, armorClass, durabilityPct)
	local d = math.Clamp(durabilityPct, 0, 1) * 100
	local effective = (121 - 5000 / (45 + d * 2)) * armorClass * 10 * 0.01

	if (pen >= effective) then
		return math.Clamp((100 + pen / (0.9 * effective - pen)) / 100, 0, 1)
	elseif (pen > effective - 15) then
		return math.Clamp(0.4 * (effective - pen - 15) ^ 2 / 100, 0, 1)
	end

	return 0
end

-- Resuelve un impacto sobre una pieza de blindaje. Devuelve multiplicador de daño
-- y si se ha parado la bala.
-- round puede ser nil (NPC, armas sin munición EFT): se usa la penetración genérica.
function B.ResolveArmorHit(client, item, dmginfo, round, pen)
	local armor = ix.efg.armor
	local class = armor.GetClass(item)
	local plate, plateItem = armor.GetPlate(item)
	local maximum, durability

	if (plate and plate.durability > 0) then
		maximum, durability = plateItem.plateDurability, plate.durability
	else
		maximum, durability = item:GetEFGMaxDurability(), item:GetEFGDurability()
	end

	if (durability <= 0) then return 1, false end

	pen = round and round.pen or pen or 25

	local material = B.materials[item.efgMaterial or (plateItem and plateItem.efgMaterial) or B.defaultMaterial[class]] or B.materials.aramid
	local chance = B.PenetrationChance(pen, class, durability / math.max(maximum, 1))
	local penetrated = math.random() < chance
	local armorDamagePct = (round and round.armorDamage or 40) / 100

	-- desgaste: penetración × daño a blindaje × destructibilidad del material
	local loss = pen * armorDamagePct * material.destructibility

	if (!penetrated) then
		loss = loss * math.Clamp(pen / (class * 10), 0.6, 1.1)
	end

	loss = loss * (hook.Run("AdjustArmorDurabilityLoss", client, client:GetCharacter()) or 1)

	local left = armor.Damage(item, loss)

	if (left <= 0) then
		client:Notify((plate and item:GetEFGDurability() > 0) and ("La placa de " .. item.name .. " se ha partido.") or (item.name .. " está destrozado y ya no protege."))
	end

	if (penetrated) then
		-- la bala pierde fuerza al atravesar: menos daño cuanto más justa va
		local factor = math.Clamp(0.5 + pen / (class * 10) * 0.5, 0.5, 1)
		return factor, false
	end

	-- daño contundente (Blunt throughput)
	return item.efgBlunt or (item.outfitCategory == "helmet" and 0.3 or 0.25), true
end

-- ─── Cascos: zona de la cabeza y rebote ─────────────────────────────────────
function B.GetHeadZone(client, hitPos)
	local bone = client:LookupBone("ValveBiped.Bip01_Head1")
	local head = bone and client:GetBonePosition(bone) or client:EyePos()
	local angles = client:EyeAngles()
	angles.p = 0

	local dir = hitPos - head
	local up = dir.z
	local forward = dir:Dot(angles:Forward())
	local right = dir:Dot(angles:Right())

	if (up > 4) then return "top" end
	if (forward < -1.5) then return "nape" end
	if (math.abs(right) > 3) then return "ears" end
	if (up > 0) then return "eyes" end

	return "jaws"
end

function B.HelmetCovers(item, zone)
	local zones = item.efgZones or B.helmetZones[item.uniqueID] or {"top", "nape", "ears"}
	return table.HasValue(zones, zone)
end

-- Rebote: más probable cuanto más rasante llega la bala
function B.TryRicochet(item, dmginfo, client)
	if (!ix.config.Get("efgRicochet", true)) then return false end

	local chance = item.efgRicochet or B.helmetRicochet[item.uniqueID] or 0.2
	local attacker = dmginfo:GetAttacker()
	if (!IsValid(attacker)) then return false end

	local bone = client:LookupBone("ValveBiped.Bip01_Head1")
	local head = bone and client:GetBonePosition(bone) or client:EyePos()
	local normal = (dmginfo:GetDamagePosition() - head):GetNormalized()
	local incoming = (dmginfo:GetDamagePosition() - attacker:EyePos()):GetNormalized()
	local grazing = 1 - math.abs(normal:Dot(incoming)) -- 0 = de frente, 1 = rasante

	if (grazing > 0.35 and math.random() < chance * grazing) then
		client:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 75)
		return true
	end

	return false
end
