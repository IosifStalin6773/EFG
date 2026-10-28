local PLUGIN = PLUGIN

PLUGIN.name = "EFG Balística"
PLUGIN.author = "EFG"
PLUGIN.description = "Munición de EFT por calibre como objetos apilables, elección de munición en cada arma, penetración y desgaste de blindaje con la fórmula de EFT, cascos con zonas y rebotes."

-- Fuentes (wiki de EFT): Ballistics, Ammunition, Armor_vests, Helmets.
-- Sustituye la munición física que daba ix_cwsupport (retirado): los ítems ammo_*
-- vuelven a existir y la reserva del arma se sincroniza con el inventario.

ix.efg = ix.efg or {}
ix.efg.ballistics = ix.efg.ballistics or {}

local B = ix.efg.ballistics

ix.util.Include("sh_data.lua")

ix.config.Add("efgBallisticsEFT", true, "Usar la fórmula de penetración de EFT (si no, la protección por clase antigua).", nil, {
	category = "EFG Balística"
})
ix.config.Add("efgRicochet", true, "Los cascos pueden hacer rebotar las balas.", nil, {
	category = "EFG Balística"
})

-- ─── Índices ────────────────────────────────────────────────────────────────
-- B.rounds["545x39_bs"] = {id, caliber, name, damage, pen, armorDamage, frag, pellets, price}
B.rounds = {}

for calID, cal in pairs(B.calibers) do
	cal.id = calID

	for _, r in ipairs(cal.rounds) do
		local id = calID .. "_" .. r[1]

		B.rounds[id] = {
			id = id, caliber = calID, name = cal.name .. " " .. r[2],
			damage = r[3], pen = r[4], armorDamage = r[5], frag = r[6], pellets = r[7], price = r[8]
		}
	end
end

for ammo, g in pairs(B.generic) do
	B.rounds[ammo] = {id = ammo, caliber = "g_" .. ammo, name = g[1], pen = g[3], generic = true, pack = g[2]}
end

function B.ItemID(roundID)
	return "ammo_" .. roundID
end

function B.GetCaliber(calID)
	return B.calibers[calID]
end

-- ─── Calibre de un arma ─────────────────────────────────────────────────────
-- Se busca en la tabla del SWEP (Trivia, Caliber, descripción). Si no aparece,
-- se usa la munición de GMod del arma ("g_ar2"…). Los admins pueden fijarlo
-- con /EFGCalibre y se guarda.
B.overrides = B.overrides or {}
local cache = {}

local function scan(text)
	if (!isstring(text)) then return end
	text = text:lower()

	for calID, cal in pairs(B.calibers) do
		for _, pattern in ipairs(cal.match) do
			if (text:find(pattern)) then
				return calID
			end
		end
	end
end

function B.GetWeaponCaliber(class, ammoName)
	class = class:lower()

	if (B.overrides[class]) then return B.overrides[class] end
	if (cache[class] != nil) then return cache[class] or ("g_" .. (ammoName or ""):lower()) end

	local swep = weapons.GetStored(class)
	local found

	if (swep) then
		found = scan(swep.Caliber) or scan(swep.Calibre)

		if (!found and istable(swep.Trivia)) then
			for k, v in pairs(swep.Trivia) do
				found = found or scan(v) or scan(k)
			end
		end

		found = found or scan(swep.Description) or scan(swep.Primary and swep.Primary.Ammo) or scan(swep.Ammo)
	end

	cache[class] = found or false

	return found or ("g_" .. (ammoName or (swep and (swep.Ammo or (swep.Primary and swep.Primary.Ammo))) or "")):lower()
end

-- Munición que tiene seleccionada un arma
function B.GetSelectedRound(item)
	local round = B.rounds[item:GetData("efgRound", "")]
	return round
end

-- ─── Ítems de munición ──────────────────────────────────────────────────────
local AMMO_MODEL = "models/Items/BoxSRounds.mdl"
local AMMO_MODEL_BIG = "models/Items/BoxMRounds.mdl"
local SHELL_MODEL = "models/Items/BoxBuckshot.mdl"

local function roundDescription(round)
	if (round.generic) then
		return "Munición estándar. Penetración aproximada: " .. (round.pen or 0) .. "."
	end

	return ("Daño: %d%s · Penetración: %d · Daño a blindaje: %d%% · Fragmentación: %d%%"):format(
		round.damage, round.pellets and round.pellets > 1 and (" x" .. round.pellets) or "",
		round.pen, round.armorDamage, math.Round((round.frag or 0) * 100))
end

local function registerAmmo(round)
	local cal = B.calibers[round.caliber]
	local uniqueID = B.ItemID(round.id)
	local ITEM = ix.item.Register(uniqueID, "base_ammo", nil, nil, true)

	ITEM.name = round.name
	ITEM.category = "Municion"
	ITEM.ammo = round.generic and round.id or nil
	ITEM.ammoAmount = cal and cal.pack or round.pack or 30
	ITEM.maxStack = cal and cal.stack or ITEM.ammoAmount * 2
	ITEM.price = round.price and round.price * ITEM.ammoAmount or 200
	ITEM.model = (round.pellets or round.caliber == "g_buckshot") and SHELL_MODEL or (cal and cal.stack <= 40 and AMMO_MODEL_BIG or AMMO_MODEL)
	ITEM.width = 1
	ITEM.height = 1
	ITEM.isAmmo = true
	ITEM.efgRound = round.id
	ITEM.efgCaliber = round.caliber
	ITEM.description = roundDescription(round)

	function ITEM:GetRounds()
		return self:GetData("rounds", self.ammoAmount)
	end

	function ITEM:GetDescription()
		return ("%s\n\nBalas: %d/%d"):format(self.description, self:GetRounds(), self.maxStack)
	end

	-- la reserva del arma se gestiona sola: sin "Cargar"
	ITEM.functions.use = nil

	-- arrastrar un montón sobre otro del mismo tipo los junta hasta el máximo
	ITEM.functions.combine = {
		OnRun = function(item, data)
			local other = ix.item.instances[data[1]]
			if (!other or other == item or other.uniqueID != item.uniqueID) then return false end

			local space = item.maxStack - item:GetRounds()
			local move = math.min(space, other:GetRounds())
			if (move <= 0) then return false end

			item:SetData("rounds", item:GetRounds() + move)

			if (other:GetRounds() - move <= 0) then
				other:Remove()
			else
				other:SetData("rounds", other:GetRounds() - move)
			end

			if (IsValid(item.player)) then
				item.player:EmitSound("items/ammo_pickup.wav", 60)
			end

			return false
		end,
		OnCanRun = function(item, data)
			local other = data and ix.item.instances[data[1]]
			return !IsValid(item.entity) and other != nil and other != item and other.uniqueID == item.uniqueID
				and item:GetRounds() < item.maxStack
		end
	}

	ITEM.functions.efgSplit = {
		name = "Dividir el montón",
		icon = "icon16/arrow_divide.png",
		OnCanRun = function(item)
			return !IsValid(item.entity) and item:GetRounds() > 1
		end,
		OnRun = function(item)
			if (SERVER) then
				local half = math.floor(item:GetRounds() / 2)
				local inventory = item.player:GetCharacter():GetInventory()
				local ok = inventory:Add(item.uniqueID, 1, {rounds = half})

				if (ok) then
					item:SetData("rounds", item:GetRounds() - half)
				else
					item.player:NotifyLocalized("noFit")
				end
			end

			return false
		end
	}
end

-- ─── Funciones de las armas ─────────────────────────────────────────────────
local function addWeaponFunctions(item)
	item.functions = item.functions or {}

	item.functions.efgAmmoSelect = {
		name = "Cambiar munición",
		icon = "icon16/bullet_go.png",
		isMulti = true,
		multiOptions = function(it, client)
			local options = {}
			local character = IsValid(client) and client:GetCharacter()
			local calID = B.GetWeaponCaliber(it.class)
			local seen = {}

			for _, ammo in pairs(character and character:GetInventory():GetItems() or {}) do
				if (ammo.isAmmo and ammo.efgCaliber == calID and !seen[ammo.efgRound] and ammo.efgRound != it:GetData("efgRound")) then
					seen[ammo.efgRound] = true
					options[#options + 1] = {name = ammo.name, data = {ammo.efgRound}}
				end
			end

			return options
		end,
		OnCanRun = function(it)
			return !IsValid(it.entity) and IsValid(it.player)
		end,
		OnRun = function(it, data)
			if (SERVER and data and B.rounds[data[1]]) then
				B.UnloadWeapon(it.player, it)
				it:SetData("efgRound", data[1])
				it.player:Notify("Munición: " .. B.rounds[data[1]].name)
			end

			return false
		end
	}

	item.functions.efgUnload = {
		name = "Descargar",
		icon = "icon16/bullet_delete.png",
		OnCanRun = function(it)
			if (IsValid(it.entity) or !IsValid(it.player)) then return false end

			local weapon = it.player:GetWeapon(it.class)
			return (IsValid(weapon) and it:GetData("equip") and weapon:Clip1() > 0) or it:GetData("ammo", 0) > 0
		end,
		OnRun = function(it)
			if (SERVER) then
				B.UnloadWeapon(it.player, it)
			end

			return false
		end
	}
end

function PLUGIN:InitializedPlugins()
	for _, round in pairs(B.rounds) do
		registerAmmo(round)
	end

	for _, item in pairs(ix.item.list) do
		if (item.isWeapon and isstring(item.class) and !item.isGrenade) then
			addWeaponFunctions(item)
		end
	end
end

-- ─── Comandos ───────────────────────────────────────────────────────────────
ix.command.Add("EFGCalibre", {
	description = "Fija el calibre de una clase de arma (p. ej. arc9_eft_ak74 545x39). Sin calibre muestra el detectado.",
	adminOnly = true,
	arguments = {ix.type.string, bit.bor(ix.type.string, ix.type.optional)},
	OnRun = function(self, client, class, calID)
		class = class:lower()

		if (!calID) then
			return class .. " → " .. B.GetWeaponCaliber(class)
		end

		if (!B.calibers[calID]) then
			return "Calibre desconocido. Válidos: " .. table.concat(table.GetKeys(B.calibers), ", ")
		end

		B.overrides[class] = calID
		PLUGIN:SetData(B.overrides)
		net.Start("ixEFGCaliberOverrides")
			net.WriteTable(B.overrides)
		net.Broadcast()

		return class .. " usa ahora " .. B.calibers[calID].name
	end
})

ix.command.Add("Municion", {
	description = "Muestra los datos de la munición del arma que llevas en la mano.",
	OnRun = function(self, client)
		local weapon = client:GetActiveWeapon()
		if (!IsValid(weapon)) then return "No llevas un arma." end

		local item = ix.arc9 and ix.arc9.GetWeaponItem(client, weapon) or weapon.ixItem
		local round = item and B.GetSelectedRound(item)

		local ammoID = weapon:GetPrimaryAmmoType()
		local calID = B.GetWeaponCaliber(weapon:GetClass(), ammoID >= 0 and game.GetAmmoName(ammoID) or nil)
		local cal = B.calibers[calID]

		return ("%s · %s · %s"):format(weapon:GetClass(), cal and cal.name or calID,
			round and (round.name .. " — " .. roundDescription(round)) or "sin munición elegida")
	end
})

if (SERVER) then
	util.AddNetworkString("ixEFGCaliberOverrides")

	function PLUGIN:LoadData()
		B.overrides = self:GetData({}) or {}
	end

	function PLUGIN:PlayerInitialSpawn(client)
		timer.Simple(5, function()
			if (IsValid(client)) then
				net.Start("ixEFGCaliberOverrides")
					net.WriteTable(B.overrides)
				net.Send(client)
			end
		end)
	end
else
	net.Receive("ixEFGCaliberOverrides", function()
		B.overrides = net.ReadTable()
	end)
end

ix.util.Include("sv_plugin.lua")
