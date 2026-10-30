local PLUGIN = PLUGIN
local health = ix.efg.health

-- Estado por jugador:
-- client.efgHP     = {head = 35, thorax = 85, ...}
-- client.efgStatus = {bleed = {part = "light"|"heavy"}, fracture = {part = true}}
-- client.efgPainkillerUntil = CurTime()

local hitgroupParts = {
	[HITGROUP_HEAD]     = "head",
	[HITGROUP_CHEST]    = "thorax",
	[HITGROUP_STOMACH]  = "stomach",
	[HITGROUP_LEFTARM]  = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
	[HITGROUP_LEFTLEG]  = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg"
}

local function fullHP()
	local hp = {}

	for _, part in ipairs(health.parts) do
		hp[part.id] = part.max
	end

	return hp
end

local function emptyStatus()
	return {bleed = {}, fracture = {}}
end

function health.GetHP(client)
	client.efgHP = client.efgHP or fullHP()
	return client.efgHP
end

function health.GetStatus(client)
	client.efgStatus = client.efgStatus or emptyStatus()
	return client.efgStatus
end

function health.GetTotal(client)
	local total = 0

	for _, value in pairs(health.GetHP(client)) do
		total = total + value
	end

	return total
end

function health.HasPainkiller(client)
	return (client.efgPainkillerUntil or 0) > CurTime()
end

-- Envía el estado al cliente y ajusta la vida de GMod (suma de todas las partes)
function health.Sync(client)
	local hp = health.GetHP(client)
	local status = health.GetStatus(client)
	local net = {}
	local noSprint, pain = false, false

	for i, part in ipairs(health.parts) do
		local flags = 0

		if (status.bleed[part.id] == "light") then flags = bit.bor(flags, 1) end
		if (status.bleed[part.id] == "heavy") then flags = bit.bor(flags, 2) end
		if (status.fracture[part.id]) then flags = bit.bor(flags, 4) end

		net[i] = {math.Round(hp[part.id], 1), flags}

		if (part.leg and (status.fracture[part.id] or hp[part.id] <= 0)) then
			noSprint = true
		end

		if (!part.vital and (status.fracture[part.id] or hp[part.id] <= 0)) then
			pain = true
		end
	end

	local painkiller = health.HasPainkiller(client)

	client:SetNetVar("efgHP", net)
	client:SetNetVar("efgNoSprint", noSprint and !painkiller)
	client:SetNetVar("efgPain", pain and !painkiller)
	client:SetNetVar("efgPainkiller", painkiller and client.efgPainkillerUntil or nil)

	client:SetMaxHealth(health.total)
	client.efgLastHealth = math.max(1, math.ceil(health.GetTotal(client)))
	client:SetHealth(client.efgLastHealth)
end

function health.Save(client)
	local character = client:GetCharacter()

	if (character and client.efgHP) then
		character:SetData("efgHP", table.Copy(client.efgHP), true)
	end
end

function health.Reset(client)
	client.efgHP = fullHP()
	client.efgStatus = emptyStatus()
	client.efgPainkillerUntil = nil
	health.Sync(client)
	hook.Run("EFGHealthReset", client)
end

-- Daño a una parte. Si la parte ya está destruida (o se destruye), el sobrante
-- se reparte entre las demás con el multiplicador de EFT. Devuelve true si mata.
function health.DamagePart(client, partID, amount)
	local hp = health.GetHP(client)
	local part = health.byID[partID]
	if (!part or amount <= 0) then return false end

	local overflow = 0

	if (hp[partID] > 0) then
		hp[partID] = hp[partID] - amount

		if (hp[partID] <= 0) then
			overflow = -hp[partID]
			hp[partID] = 0
			hook.Run("EFGHealthEvent", client, "lost", partID)

			if (part.vital) then
				return true
			end
		end
	else
		overflow = amount
	end

	if (overflow > 0) then
		overflow = overflow * (part.spread or 1)

		local alive = {}

		for _, other in ipairs(health.parts) do
			if (other.id != partID and hp[other.id] > 0) then
				alive[#alive + 1] = other
			end
		end

		if (#alive == 0) then
			return true
		end

		local share = overflow / #alive

		for _, other in ipairs(alive) do
			hp[other.id] = math.max(0, hp[other.id] - share)

			if (other.vital and hp[other.id] <= 0) then
				return true
			end
		end
	end

	return false
end

-- Curación: si se ha elegido una parte (arrastrando la medicina sobre ella en
-- la pestaña SALUD) se cura esa primero; el resto se reparte empezando por la
-- más dañada que no esté destruida. Devuelve lo que se ha usado.
function health.Heal(client, amount, prefer)
	local hp = health.GetHP(client)
	local used = 0
	local first = prefer and health.byID[prefer]

	if (first and hp[first.id] > 0 and hp[first.id] < first.max) then
		used = math.min(first.max - hp[first.id], amount)
		hp[first.id] = hp[first.id] + used
	end

	while (amount - used > 0.01) do
		local worst, worstMissing

		for _, part in ipairs(health.parts) do
			local missing = part.max - hp[part.id]

			if (hp[part.id] > 0 and missing > 0.01 and (!worstMissing or missing > worstMissing)) then
				worst, worstMissing = part, missing
			end
		end

		if (!worst) then break end

		local heal = math.min(worstMissing, amount - used)
		hp[worst.id] = hp[worst.id] + heal
		used = used + heal
	end

	health.Sync(client)

	-- efg_progression: XP por curar en raid
	if (used > 0 and client.InRaid and client:InRaid()) then
		hook.Run("EFGHealed", client, used)
	end

	return used
end

-- severity: "light", "heavy" o "all"
function health.StopBleeding(client, severity, prefer)
	local bleed = health.GetStatus(client).bleed
	local stopped = false

	if (prefer and bleed[prefer] and (severity == "all" or bleed[prefer] == severity)) then
		bleed[prefer] = nil
		hook.Run("EFGBleedStopped", client, prefer)
		health.Sync(client)
		return true
	end

	for partID, level in pairs(bleed) do
		if (severity == "all" or level == severity) then
			bleed[partID] = nil
			stopped = true
			hook.Run("EFGBleedStopped", client, partID)

			-- en EFT cada uso trata un solo sangrado
			if (severity != "all") then break end
		end
	end

	health.Sync(client)

	return stopped
end

function health.FixFracture(client, prefer)
	local fracture = health.GetStatus(client).fracture

	if (prefer and fracture[prefer]) then
		fracture[prefer] = nil
		health.Sync(client)
		return true
	end

	for partID in pairs(fracture) do
		fracture[partID] = nil
		health.Sync(client)
		return true
	end

	return false
end

-- Kit quirúrgico: recupera una extremidad destruida a 1 de vida
function health.RestoreBlacked(client, prefer)
	local hp = health.GetHP(client)
	local first = prefer and health.byID[prefer]

	if (first and !first.vital and hp[first.id] <= 0) then
		hp[first.id] = 1
		health.Sync(client)
		return true
	end

	for _, part in ipairs(health.parts) do
		if (!part.vital and hp[part.id] <= 0) then
			hp[part.id] = 1
			health.Sync(client)
			return true
		end
	end

	return false
end

function health.AddPainkiller(client, seconds)
	client.efgPainkillerUntil = math.max(client.efgPainkillerUntil or 0, CurTime()) + seconds
	health.Sync(client)
end

-- ─── Daño ────────────────────────────────────────────────────────────────────
-- Chalecos y cascos (efg_gear): reducen el daño de bala y corte en las zonas que
-- cubren y pierden durabilidad. La penetración de la bala reduce la protección efectiva
-- según la clase de armadura (pen alta bypasa armaduras de clase baja).
-- Si la armadura detiene más del 50% del impacto no hay sangrado ni fractura.
function PLUGIN:ScalePlayerDamage(client, hitgroup, dmginfo)
	if (!ix.efg.armor or !(dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_SLASH))) then return end

	local character = client:GetCharacter()
	local partID = hitgroupParts[hitgroup]
	if (!character or !partID) then return end

	-- Penetración del proyectil: se obtiene del tipo de munición del arma infligidora
	local pen
	if (dmginfo:IsBulletDamage()) then
		local inflictor = dmginfo:GetInflictor()
		if (IsValid(inflictor) and inflictor:IsWeapon()) then
			local ammoID = inflictor:GetPrimaryAmmoType()
			local ammoName = (ammoID >= 0) and game.GetAmmoName(ammoID) or nil
			pen = ix.efg.armor.GetBulletPen(ammoName)
		end
	end

	local B = ix.efg.ballistics
	local useEFT = B and B.ResolveArmorHit and ix.config.Get("efgBallisticsEFT", true) and dmginfo:IsBulletDamage()
	local round = useEFT and B.GetDamageRound(dmginfo)
	local zone = (useEFT and partID == "head") and B.GetHeadZone(client, dmginfo:GetDamagePosition()) or nil

	for _, item in ipairs(ix.efg.armor.GetCovering(character, partID)) do
		if (useEFT) then
			-- efg_ballistics: fórmula de penetración de EFT, zonas del casco y rebotes
			if (ix.efg.armor.GetProtection(item) > 0 and (!zone or B.HelmetCovers(item, zone))) then
				if (zone and B.TryRicochet(item, dmginfo, client)) then
					dmginfo:ScaleDamage(0)
					client.efgArmorStopped = CurTime()
					return
				end

				local mult, stopped = B.ResolveArmorHit(client, item, dmginfo, round, pen)
				dmginfo:ScaleDamage(mult)

				if (stopped) then
					client.efgArmorStopped = CurTime()
				end

				break
			end
		else
			local baseProtection = ix.efg.armor.GetProtection(item)

			if (baseProtection > 0) then
				-- Factor de penetración: 1.0 si la bala no supera el umbral de la clase,
				-- baja hasta 0.05 conforme la penetración supera el umbral de la clase
				local penFactor = (pen and ix.efg.armor.GetPenFactor(pen, ix.efg.armor.GetClass(item))) or 1.0
				local protection = baseProtection * penFactor

				local absorbed = dmginfo:GetDamage() * protection
				dmginfo:ScaleDamage(1 - protection)
				hook.Run("EFGHealthEvent", client, "absorbed", nil, absorbed)

				-- La durabilidad se daña incluso si la bala penetra (el impacto desgasta la armadura)
				local degradeMult = hook.Run("AdjustArmorDurabilityLoss", client, character) or 1
				-- si lleva placa, el desgaste va a la placa (efg_gear/libs/sh_armor.lua)
				local durability = ix.efg.armor.Damage(item, absorbed * ix.efg.armor.durabilityDamage * degradeMult)

				-- Solo se marca como "bloqueado por armadura" si la protección es sustancial
				if (penFactor > 0.5) then
					client.efgArmorStopped = CurTime()
				end

				if (durability <= 0) then
					local plate = ix.efg.armor.GetPlate(item)
					client:Notify((plate and item:GetEFGDurability() > 0) and ("La placa de " .. item.name .. " se ha partido.") or (item.name .. " está destrozado y ya no protege."))
				end

				break
			end
		end
	end
end

function PLUGIN:PostEntityTakeDamage(client, dmginfo, took)
	if (!took or !IsValid(client) or !client:IsPlayer() or !client:Alive() or !client:GetCharacter()) then return end

	local amount = dmginfo:GetDamage()
	if (amount <= 0) then return end

	local status = health.GetStatus(client)
	local killed = false
	local fractures = table.Count(status.fracture)

	if (dmginfo:IsFallDamage()) then
		killed = health.DamagePart(client, "lleg", amount / 2) or killed
		killed = health.DamagePart(client, "rleg", amount / 2) or killed

		if (amount >= 15 and math.random(100) <= 60) then
			local leg = math.random(2) == 1 and "lleg" or "rleg"
			status.fracture[leg] = true
			hook.Run("EFGHealthEvent", client, "fracture", leg)
		end
	elseif (dmginfo:IsExplosionDamage() or dmginfo:IsDamageType(DMG_BURN) or dmginfo:IsDamageType(DMG_SLOWBURN)
		or dmginfo:IsDamageType(DMG_DROWN) or dmginfo:IsDamageType(DMG_POISON) or dmginfo:IsDamageType(DMG_RADIATION)) then
		-- daño de área: repartido por todo el cuerpo
		for _, part in ipairs(health.parts) do
			killed = health.DamagePart(client, part.id, amount * part.max / health.total) or killed
		end
	else
		local partID = hitgroupParts[client:LastHitGroup()] or "thorax"
		killed = health.DamagePart(client, partID, amount)

		if ((dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_SLASH)) and client.efgArmorStopped != CurTime()) then
			-- efg_effects: herida fresca (x2) y hemostáticos (x0)
			local bleedMult = hook.Run("EFGBleedChanceMult", client, partID) or 1

			if (math.random(100) <= ix.config.Get("efgHeavyBleedChance", 8) * bleedMult) then
				status.bleed[partID] = "heavy"
				hook.Run("EFGHealthEvent", client, "bleed", partID)
			elseif (status.bleed[partID] != "heavy" and math.random(100) <= ix.config.Get("efgLightBleedChance", 25) * bleedMult) then
				status.bleed[partID] = "light"
				hook.Run("EFGHealthEvent", client, "bleed", partID)
			end

			local part = health.byID[partID]

			if ((part.arm or part.leg) and math.random(100) <= ix.config.Get("efgFractureChance", 12)) then
				status.fracture[partID] = true
				hook.Run("EFGHealthEvent", client, "fracture", partID)
			end
		end
	end

	if (!killed and table.Count(status.fracture) > fractures) then
		client:EmitSound("efg/health/bone_break.wav", 70)
	end

	if (killed) then
		timer.Simple(0, function()
			if (IsValid(client) and client:Alive()) then
				client:Kill()
			end
		end)
	else
		health.Sync(client)
	end
end

-- ─── Bucle: sangrados, curaciones de otros plugins, regeneración en el escondite ─
local nextTick = 0

function PLUGIN:Think()
	if (nextTick > CurTime()) then return end
	nextTick = CurTime() + 1

	for _, client in ipairs(player.GetAll()) do
		if (client.efgHP and client:Alive() and client:GetCharacter()) then
			-- los plugins antiguos (comida, AFAK...) curan con SetHealth: esa
			-- diferencia se reparte entre las partes
			local current = client:Health()

			if (client.efgLastHealth and current > client.efgLastHealth) then
				health.Heal(client, current - client.efgLastHealth)
			end

			local status = health.GetStatus(client)
			local killed, changed = false, false

			for partID, level in pairs(status.bleed) do
				killed = health.DamagePart(client, partID, level == "heavy" and 1.2 or 0.4) or killed
				changed = true
			end

			-- fuera de raid se recupera la salud poco a poco (como el escondite de EFT)
			if (!client:InRaid()) then
				local hp = health.GetHP(client)
				-- la zona de descanso y la estación médica del escondite aceleran la recuperación
				local regen = hook.Run("EFGGetRegenMultiplier", client) or 1

				for _, part in ipairs(health.parts) do
					if (hp[part.id] < part.max) then
						hp[part.id] = math.min(part.max, hp[part.id] + part.max / 120 * regen)
						changed = true
					end
				end
			end

			-- dolor con un brazo roto: el arma tiembla
			if (status.fracture.larm or status.fracture.rarm) and !health.HasPainkiller(client) then
				client:ViewPunch(Angle(math.Rand(-1.2, 1.2), math.Rand(-1.2, 1.2), 0))
			end

			if (client:GetNetVar("efgPainkiller") and !health.HasPainkiller(client)) then
				changed = true
			end

			if (killed) then
				client:Kill()
			elseif (changed) then
				health.Sync(client)
			end
		end
	end
end

-- ─── Ciclo de vida ───────────────────────────────────────────────────────────
function PLUGIN:PlayerLoadedCharacter(client, character)
	client.efgHP = nil
	client.efgStatus = emptyStatus()
	client.efgPainkillerUntil = nil

	local saved = character:GetData("efgHP")

	if (istable(saved)) then
		client.efgHP = fullHP()

		for partID in pairs(client.efgHP) do
			if (isnumber(saved[partID])) then
				client.efgHP[partID] = math.Clamp(saved[partID], 0, health.byID[partID].max)
			end
		end
	end
end

function PLUGIN:PostPlayerLoadout(client)
	if (!client:GetCharacter()) then return end

	-- tras morir se vuelve con la salud completa
	if (client.efgDied or !client.efgHP) then
		client.efgDied = nil
		health.Reset(client)
	else
		health.Sync(client)
	end
end

-- quejidos y gritos de muerte de EFT (Welcome To Tarkov Extras) en vez de los de Helix
function PLUGIN:GetPlayerPainSound(client)
	return ("efg/damage/pl_damage_minor_%02d.wav"):format(math.random(5))
end

function PLUGIN:GetPlayerDeathSound(client)
	return ("efg/damage/pl_deathshout_%02d.wav"):format(math.random(17))
end

function PLUGIN:PlayerDeath(client)
	client.efgDied = true
	client.efgPMCHP = nil
	client.efgStatus = emptyStatus()
	client.efgPainkillerUntil = nil

	local character = client:GetCharacter()

	if (character) then
		character:SetData("efgHP", nil, true)
	end
end

function PLUGIN:PlayerDisconnected(client)
	health.Save(client)
end

local nextSave = 0

function PLUGIN:Tick()
	if (nextSave > CurTime()) then return end
	nextSave = CurTime() + 30

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive()) then
			health.Save(client)
		end
	end
end

-- Al salir de la raid desaparecen sangrados y fracturas (como en EFT)
function PLUGIN:EFGRaidEnded(client, side, reason)
	if (!client:Alive()) then return end

	client.efgStatus = emptyStatus()

	-- el Scav tiene su propia salud: el PMC recupera la suya
	if (side == "scav" and client.efgPMCHP) then
		client.efgHP = client.efgPMCHP
		client.efgPMCHP = nil
	end

	health.Sync(client)
	health.Save(client)
end

function PLUGIN:EFGRaidStarted(client, side)
	if (side == "scav") then
		client.efgPMCHP = table.Copy(health.GetHP(client))
		health.Reset(client)
	end
end

-- ─── Medicamentos de anims_meds ──────────────────────────────────────────────
function PLUGIN:EFT_MedApplied(client, kind, data)
	hook.Run("OnCuracionRealizada", client, true)

	if (kind == "afak") then
		health.StopBleeding(client, "all")
	end

	if (data and data.painkillers) then
		health.AddPainkiller(client, data.painkillers)
	elseif (data and data.endurance and kind == "morphine") then
		health.AddPainkiller(client, data.endurance)
	end
end


-- ─── Tratamiento pagado tras la raid ─────────────────────────────────────────
util.AddNetworkString("ixEFGTreatment")

net.Receive("ixEFGTreatment", function(_, client)
	if ((client.efgNextTreatment or 0) > CurTime()) then return end
	client.efgNextTreatment = CurTime() + 1

	local character = client:GetCharacter()
	if (!character or !client:Alive()) then return end

	if (client.InRaid and client:InRaid()) then
		client:Notify("No puedes pagar tratamiento durante una raid.")
		return
	end

	health.Sync(client)
	local quote = health.TreatmentQuote(client:GetNetVar("efgHP"))

	if (quote.total <= 0) then
		client:Notify("No necesitas tratamiento.")
		return
	end

	if (!character:HasMoney(quote.total)) then
		client:Notify(("Necesitas %s RUB para el tratamiento."):format(string.Comma(quote.total)))
		return
	end

	character:TakeMoney(quote.total)
	health.Reset(client)
	health.Save(client)
	client:Notify(("Tratamiento completo: %s RUB."):format(string.Comma(quote.total)))
end)
