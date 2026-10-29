local PLUGIN = PLUGIN

if (!SERVER) then return end

local M = ix.efg.mags
local B = ix.efg.ballistics

local function inventoryOf(client)
	local character = IsValid(client) and client:GetCharacter()
	return character and character:GetInventory()
end

-- ¿Lleva el jugador este objeto (en el inventario o en sus bolsas)?
local function carries(client, item)
	local inventory = inventoryOf(client)
	return item and inventory and inventory:GetItemByID(item:GetID()) != nil
end

local function timerID(client)
	return "efgMagWork" .. client:EntIndex()
end

local function stopWork(client)
	timer.Remove(timerID(client))
	client.efgMagBusy = nil
end

-- Da un cargador con balas; si no cabe cae al suelo
local function giveMag(client, uniqueID, rounds, roundID)
	local data = {rounds = rounds, round = rounds > 0 and roundID or nil}
	local inventory = inventoryOf(client)

	if (!inventory or !inventory:Add(uniqueID, 1, data)) then
		ix.item.Spawn(uniqueID, client:GetItemDropPos(), nil, nil, data)
	end
end

-- ─── Llenar y vaciar ────────────────────────────────────────────────────────
-- Bala a bala, como en EFT: cada una suena y sube el contador del cargador.
-- El cliente pinta el cargador llenándose (cl_plugin.lua).
util.AddNetworkString("efgMagWorkUI")

local ROUND_SOUND = "eft_shared/weap_round_in_chamber_mag.wav"

local function sendUI(client, mag, loading, total, step)
	net.Start("efgMagWorkUI")
		net.WriteBool(mag != nil)

		if (mag) then
			net.WriteUInt(mag:GetID(), 32)
			net.WriteBool(loading)
			net.WriteUInt(total, 8)
			net.WriteFloat(step)
		end
	net.Send(client)
end

local function finishWork(client)
	stopWork(client)
	client:SetAction()
	sendUI(client)
end

-- repite step(i) cada `step` segundos `total` veces; step devuelve false para parar
local function startWork(client, mag, loading, total, step, onRound)
	client.efgMagBusy = true
	client:SetAction(loading and "Cargando cargador..." or "Descargando cargador...", total * step)
	sendUI(client, mag, loading, total, step)

	local done = 0

	timer.Create(timerID(client), step, total, function()
		if (!IsValid(client)) then return end

		if (!client:Alive() or !carries(client, mag) or onRound() == false) then
			finishWork(client)
			return
		end

		done = done + 1
		client:EmitSound(ROUND_SOUND, 50, math.random(96, 104), 0.6, CHAN_ITEM)

		if (done >= total) then
			finishWork(client)
		end
	end)
end

function M.Load(client, mag, roundID)
	local inventory = inventoryOf(client)
	local round = B.rounds[roundID]
	local def = M.GetDef(mag)
	if (!inventory or !round or !def or !carries(client, mag)) then return end

	if (client.efgMagBusy) then
		client:Notify("Ya estás con un cargador.")
		return
	end

	if (!table.HasValue(def.calibers, round.caliber)) then
		client:Notify("Esa munición no entra en este cargador.")
		return
	end

	if (mag:GetRounds() > 0 and mag:GetData("round") != roundID) then
		client:Notify("El cargador tiene otra munición: descárgalo antes.")
		return
	end

	local amount = math.min(def.capacity - mag:GetRounds(), B.CountRounds(inventory, roundID))

	if (amount <= 0) then
		client:Notify(mag:GetRounds() >= def.capacity and "El cargador está lleno." or "No te queda esa munición.")
		return
	end

	startWork(client, mag, true, amount, ix.config.Get("efgMagLoadTime", 0.5), function()
		local inv = inventoryOf(client)
		if (!inv or mag:GetRounds() >= def.capacity or B.CountRounds(inv, roundID) <= 0) then return false end

		B.TakeRounds(inv, roundID, 1)
		mag:SetData("round", roundID)
		mag:SetData("rounds", mag:GetRounds() + 1)
	end)
end

function M.Unload(client, mag)
	local rounds = mag:GetRounds()
	if (rounds <= 0 or !carries(client, mag)) then return end

	if (client.efgMagBusy) then
		client:Notify("Ya estás con un cargador.")
		return
	end

	local roundID = mag:GetData("round")

	startWork(client, mag, false, rounds, ix.config.Get("efgMagUnloadTime", 0.3), function()
		if (mag:GetRounds() <= 0) then return false end

		mag:SetData("rounds", mag:GetRounds() - 1)

		if (mag:GetRounds() <= 0) then
			mag:SetData("round", nil)
		end

		if (roundID and B.rounds[roundID]) then
			B.GiveRounds(client, roundID, 1)
		end
	end)
end

-- Cancelar a mano (tecla o moverse no lo cancela, como en EFT; esto es para la UI)
net.Receive("efgMagWorkUI", function(_, client)
	if (client.efgMagBusy) then
		finishWork(client)
	end
end)

-- ─── Cargador del arma ──────────────────────────────────────────────────────
local function equippedWeapon(client, weaponItem)
	local weapon = IsValid(client) and weaponItem.class and client:GetWeapon(weaponItem.class)
	return (IsValid(weapon) and weaponItem:GetData("equip")) and weapon or nil
end

function M.SetCapacity(weapon, uniqueID)
	if (!IsValid(weapon)) then return end

	local def = M.byID[uniqueID or ""]
	weapon:SetNW2Int("efgMagCap", def and def.capacity or 0)
end

local function setClip(client, weaponItem, rounds)
	local weapon = equippedWeapon(client, weaponItem)

	if (weapon) then
		weapon:SetClip1(rounds)

		-- efg_weapons cuenta disparos por bajadas del cargador
		if (client.efgLastWeapon == weapon) then
			client.efgLastClip = rounds
		end
	else
		weaponItem:SetData("ammo", rounds)
	end
end

-- Saca el cargador del arma al inventario (con sus balas)
function M.Eject(client, weaponItem, silent)
	local uniqueID = M.GetWeaponMag(weaponItem)
	local rounds = M.GetClip(client, weaponItem)
	local roundID = weaponItem:GetData("efgRound")

	setClip(client, weaponItem, 0)
	weaponItem:SetData("efgMag", nil)
	M.SetCapacity(equippedWeapon(client, weaponItem), nil)

	if (uniqueID and M.byID[uniqueID]) then
		giveMag(client, uniqueID, rounds, roundID)

		if (!silent) then
			client:Notify("Cargador quitado.")
		end
	elseif (rounds > 0 and roundID and B.rounds[roundID]) then
		-- balas sueltas de antes de los cargadores
		B.GiveRounds(client, roundID, rounds)
	end
end

function M.Insert(client, weaponItem, mag)
	local def = M.GetDef(mag)
	if (!def or !carries(client, mag) or !carries(client, weaponItem)) then return end

	if (!M.UsesMags(weaponItem) or !M.Fits(weaponItem, def)) then
		client:Notify("Ese cargador no vale para esta arma.")
		return
	end

	local round = mag:GetRound()

	if (mag:GetRounds() > 0 and (!round or round.caliber != M.WeaponCaliber(weaponItem))) then
		client:Notify("La munición del cargador no es del calibre del arma.")
		return
	end

	M.Eject(client, weaponItem, true)

	weaponItem:SetData("efgMag", mag.uniqueID)

	if (round and mag:GetRounds() > 0) then
		weaponItem:SetData("efgRound", round.id)
	end

	M.SetCapacity(equippedWeapon(client, weaponItem), mag.uniqueID)
	setClip(client, weaponItem, mag:GetRounds())
	mag:Remove()

	client:EmitSound("weapons/arc9/ammo_pickup.wav", 55, 100, 0.5, CHAN_ITEM)
end

-- Cargador más lleno que valga para el arma y tenga munición de su calibre
function M.FindBest(client, weaponItem)
	local inventory = inventoryOf(client)
	if (!inventory) then return end

	local calID = M.WeaponCaliber(weaponItem)
	local best

	for _, mag in pairs(inventory:GetItems()) do
		if (mag.isMagazine and mag:GetRounds() > 0 and (!best or mag:GetRounds() > best:GetRounds())) then
			local round = mag:GetRound()

			if (round and round.caliber == calID and M.Fits(weaponItem, M.GetDef(mag))) then
				best = mag
			end
		end
	end

	return best
end

-- Al equipar: capacidad del cargador puesto; un arma con balas pero sin
-- cargador (loot, IA, partidas antiguas) recibe el suyo por defecto
function PLUGIN:EFG_ARC9InitWeapon(client, weapon, weaponItem)
	if (!M.UsesMags(weaponItem)) then
		weapon:SetNW2Int("efgMagCap", 0)
		return
	end

	local uniqueID = M.GetWeaponMag(weaponItem)

	if (!uniqueID and weaponItem:GetData("ammo", 0) > 0) then
		local def = M.DefaultMag(weaponItem)

		if (def) then
			uniqueID = def.id
			weaponItem:SetData("efgMag", uniqueID)
			weaponItem:SetData("ammo", math.min(weaponItem:GetData("ammo", 0), def.capacity))
		end
	end

	M.SetCapacity(weapon, uniqueID)
end

-- ─── Recarga: se cambia el cargador entero ──────────────────────────────────
-- ARC9 hace la animación y mete balas de la reserva (el cargador más lleno);
-- al acabar se deja el cargador nuevo en el arma y el viejo en el inventario.
local function finishReload(client, state, weapon)
	local weaponItem = state.item
	local mag = ix.item.instances[state.mag]

	if (!mag or !carries(client, mag) or mag:GetRounds() <= 0) then
		weapon:SetClip1(state.clip)
		return
	end

	-- la bala de la recámara se queda en el arma, como en EFT
	local chamber = (state.clip > 0 and (weapon.ChamberSize or 1) > 0) and 1 or 0
	local oldMag = M.GetWeaponMag(weaponItem)
	local oldRound = weaponItem:GetData("efgRound")
	local round = mag:GetRound()

	if (oldMag and M.byID[oldMag]) then
		giveMag(client, oldMag, state.clip - chamber, oldRound)
	elseif (state.clip - chamber > 0 and oldRound and B.rounds[oldRound]) then
		B.GiveRounds(client, oldRound, state.clip - chamber)
	end

	weaponItem:SetData("efgMag", mag.uniqueID)
	weaponItem:SetData("efgRound", round.id)
	M.SetCapacity(weapon, mag.uniqueID)

	local clip = mag:GetRounds() + chamber
	mag:Remove()

	weapon:SetClip1(clip)

	if (client.efgLastWeapon == weapon) then
		client.efgLastClip = clip
	end
end

function PLUGIN:Think()
	for _, client in ipairs(player.GetAll()) do
		local weapon = client:GetActiveWeapon()
		local state = client.efgMagReload

		if (IsValid(weapon) and weapon.GetReloading and weapon.ixItem and client:Alive()) then
			local reloading = weapon:GetReloading()

			if (reloading and !state) then
				if (M.UsesMags(weapon.ixItem)) then
					local best = M.FindBest(client, weapon.ixItem)

					if (best) then
						client.efgMagReload = {weapon = weapon, item = weapon.ixItem, clip = weapon:Clip1(), mag = best:GetID()}
					elseif (weapon.CancelReload) then
						weapon:CancelReload()
					end
				end
			elseif (!reloading and state) then
				client.efgMagReload = nil

				-- solo si ARC9 llegó a meter balas; si no, se canceló
				if (state.weapon == weapon and weapon:Clip1() > state.clip) then
					finishReload(client, state, weapon)
				end
			end
		elseif (state) then
			client.efgMagReload = nil
		end
	end
end

-- Reserva que ve ARC9 para un arma con cargadores: las balas del mejor cargador
function M.ReserveFor(client, weaponItem)
	local best = M.FindBest(client, weaponItem)
	return best and best:GetRounds() or 0
end

-- ─── Kits de inicio ─────────────────────────────────────────────────────────
-- Cada arma de inicio sale con su cargador lleno y dos de repuesto
function M.GiveStarterMags(client, character, spares)
	local inventory = character:GetInventory()
	if (!inventory) then return end

	for _, weaponItem in pairs(inventory:GetItems()) do
		if (weaponItem.isARC9 and M.UsesMags(weaponItem) and !M.GetWeaponMag(weaponItem)) then
			local def = M.DefaultMag(weaponItem)
			local roundID = M.DefaultRound(M.WeaponCaliber(weaponItem))

			if (def and roundID) then
				weaponItem:SetData("efgMag", def.id)
				weaponItem:SetData("efgRound", roundID)
				weaponItem:SetData("ammo", def.capacity)

				for _ = 1, (spares or 2) do
					giveMag(client, def.id, def.capacity, roundID)
				end
			end
		end
	end
end

function PLUGIN:OnCharacterCreated(client, character)
	timer.Simple(0.5, function()
		if (IsValid(client) and character) then
			M.GiveStarterMags(client, character, 2)
		end
	end)
end

function PLUGIN:PlayerDisconnected(client)
	stopWork(client)
	client.efgMagReload = nil
end

function PLUGIN:PlayerDeath(client)
	if (client.efgMagBusy) then finishWork(client) end
	client.efgMagReload = nil
end

-- ─── Comerciantes y loot ────────────────────────────────────────────────────
function PLUGIN:AddToTradersAndLoot()
	local stock = ix.traders and ix.traders.defaultStock

	if (stock) then
		for _, def in ipairs(M.data) do
			for _, entry in ipairs(def.traders) do
				local list = stock[entry[1]]

				if (list) then
					list[#list + 1] = {def.id, def.capacity >= 50 and 2 or 6, entry[2]}
				end
			end
		end
	end

	-- cargadores vacíos en el loot de armas: los comunes (de comerciante LL1-2, hasta 30 balas)
	local loot = ix.loot and ix.loot.tables and ix.loot.tables.armamento

	if (loot) then
		for _, def in ipairs(M.data) do
			local level = def.traders[1] and def.traders[1][2] or 4

			if (level <= 2 and def.capacity <= 30) then
				loot[#loot + 1] = {def.id, 0.4, 1}
			end
		end
	end
end
