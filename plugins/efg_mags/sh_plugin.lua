local PLUGIN = PLUGIN

PLUGIN.name = "EFG Cargadores"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Cargadores de EFT como objetos: se llenan de balas, se meten en el arma y la recarga cambia el cargador entero."

ix.efg = ix.efg or {}
ix.efg.mags = ix.efg.mags or {}

local M = ix.efg.mags
local B = ix.efg.ballistics

ix.config.Add("efgMagazines", true, "Cargadores como objetos. Si se apaga, las armas recargan directamente con la munición del inventario.", nil, {
	category = "EFG Armas"
})

ix.config.Add("efgMagLoadTime", 0.5, "Segundos para meter una bala en un cargador.", nil, {
	data = {min = 0.05, max = 3, decimals = 2},
	category = "EFG Armas"
})

ix.config.Add("efgMagUnloadTime", 0.3, "Segundos para sacar una bala de un cargador.", nil, {
	data = {min = 0.05, max = 3, decimals = 2},
	category = "EFG Armas"
})

ix.util.Include("sh_data.lua")

-- ─── Registro de los cargadores ─────────────────────────────────────────────
M.byID = {}
M.groupCalibers = {}

for _, def in ipairs(M.data) do
	M.byID[def.id] = def
	M.groupCalibers[def.group] = M.groupCalibers[def.group] or {}

	for _, calID in ipairs(def.calibers) do
		M.groupCalibers[def.group][calID] = true
	end

	local ITEM = ix.item.Register(def.id, "base_efgmag", false, nil, true)
	ITEM.name = def.name
	ITEM.model = def.model
	ITEM.width = def.w
	ITEM.height = def.h
	ITEM.weight = def.weight
	ITEM.price = def.price
	ITEM.capacity = def.capacity
	ITEM.magDef = def
	ITEM.iconMaterial = def.icon
end

function M.GetDef(item)
	return item and (item.magDef or M.byID[item.uniqueID])
end

function M.CaliberName(calID)
	local caliber = B and B.calibers[calID]
	return caliber and caliber.name or tostring(calID)
end

function M.WeaponCaliber(weaponItem)
	return weaponItem and weaponItem.class and B and B.GetWeaponCaliber(weaponItem.class)
end

-- ¿Vale este cargador (definición) para el arma? Mismo calibre y mismo grupo;
-- si el arma no tiene grupo, o su grupo no tiene cargadores de su calibre,
-- vale cualquiera del calibre (de pistola solo para pistolas).
function M.Fits(weaponItem, def)
	local calID = M.WeaponCaliber(weaponItem)
	if (!calID or !def or !table.HasValue(def.calibers, calID)) then return false end

	local group = M.weaponGroups[weaponItem.class]

	if (group and M.groupCalibers[group] and M.groupCalibers[group][calID]) then
		return def.group == group
	end

	return (M.pistolGroups[def.group] or false) == (weaponItem.weaponCategory == "secondary")
end

-- Cargadores que valen para un arma (definiciones), por clase
M.fitCache = {}

function M.GetFitting(weaponItem)
	local class = weaponItem.class
	if (!class) then return {} end

	if (!M.fitCache[class]) then
		local list = {}

		for _, def in ipairs(M.data) do
			if (M.Fits(weaponItem, def)) then
				list[#list + 1] = def
			end
		end

		M.fitCache[class] = list
	end

	return M.fitCache[class]
end

-- El arma usa cargadores si es de ARC9, no recarga bala a bala y hay alguno que le valga
function M.UsesMags(weaponItem)
	if (!weaponItem or !weaponItem.isARC9 or weaponItem.isGrenade or !ix.config.Get("efgMagazines", true)) then
		return false
	end

	local swep = weapons.GetStored(weaponItem.class)
	if (!swep or swep.ShotgunReload) then return false end

	return #M.GetFitting(weaponItem) > 0
end

-- Cargador por defecto de un arma: el de capacidad más parecida a la del SWEP
function M.DefaultMag(weaponItem)
	local swep = weapons.GetStored(weaponItem.class)
	local wanted = swep and tonumber(swep.ClipSize) or 30
	local best, bestScore

	for _, def in ipairs(M.GetFitting(weaponItem)) do
		local score = math.abs(def.capacity - wanted) * 1000 + def.price

		if (!bestScore or score < bestScore) then
			best, bestScore = def, score
		end
	end

	return best
end

-- Munición más barata de un calibre (la que traen los cargadores de inicio)
function M.DefaultRound(calID)
	local caliber = B and B.calibers[calID]
	local first = caliber and caliber.rounds and caliber.rounds[1]

	return first and B.rounds[calID .. "_" .. first[1]] and (calID .. "_" .. first[1]) or nil
end

-- Cargador puesto en un arma (uniqueID) y sus balas
function M.GetWeaponMag(weaponItem)
	return weaponItem:GetData("efgMag")
end

function M.GetClip(client, weaponItem)
	local weapon = IsValid(client) and weaponItem.class and client:GetWeapon(weaponItem.class)

	if (IsValid(weapon) and weaponItem:GetData("equip")) then
		return math.max(0, weapon:Clip1())
	end

	return weaponItem:GetData("ammo", 0)
end

if (CLIENT) then
	-- objetos que caben en el arma para la descripción del cargador
	M.weaponNamesCache = {}

	function M.WeaponNames(def)
		if (M.weaponNamesCache[def.id]) then return M.weaponNamesCache[def.id] end

		local names = {}

		for _, item in pairs(ix.item.list) do
			if (item.isARC9 and !item.isGrenade and M.Fits(item, def)) then
				names[#names + 1] = item.name
			end
		end

		table.sort(names)
		M.weaponNamesCache[def.id] = table.concat(names, ", ")

		return M.weaponNamesCache[def.id]
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- ─── Acciones en las armas ──────────────────────────────────────────────────
local function patchWeapon(ITEM)
	if (ITEM.efgMagsPatched) then return end
	ITEM.efgMagsPatched = true
	ITEM.functions = ITEM.functions or {}

	ITEM.functions.efgMagEject = {
		name = "Quitar cargador",
		icon = "icon16/bullet_delete.png",
		OnCanRun = function(item)
			if (IsValid(item.entity) or !IsValid(item.player) or !M.UsesMags(item)) then return false end

			return M.GetWeaponMag(item) != nil or M.GetClip(item.player, item) > 0
		end,
		OnRun = function(item)
			if (SERVER) then M.Eject(item.player, item) end
			return false
		end
	}

	ITEM.functions.efgMagInsert = {
		name = "Poner cargador",
		icon = "icon16/bullet_add.png",
		isMulti = true,
		multiOptions = function(item, client)
			local options = {}
			local character = IsValid(client) and client:GetCharacter()

			for _, mag in pairs(character and character:GetInventory():GetItems() or {}) do
				if (mag.isMagazine and M.Fits(item, M.GetDef(mag))) then
					options[#options + 1] = {name = ("%s [%d/%d]"):format(mag.name, mag:GetRounds(), mag.capacity), data = {mag:GetID()}}
				end
			end

			return options
		end,
		OnCanRun = function(item)
			return !IsValid(item.entity) and IsValid(item.player) and M.UsesMags(item)
		end,
		OnRun = function(item, data)
			if (SERVER and data) then
				local mag = ix.item.instances[data[1]]
				if (mag) then M.Insert(item.player, item, mag) end
			end

			return false
		end
	}

	-- con cargadores, la munición se elige al llenarlos y se descarga quitándolos
	for _, key in ipairs({"efgAmmoSelect", "efgUnload"}) do
		local action = ITEM.functions[key]

		if (action and !action.efgMagsGate) then
			local canRun = action.OnCanRun
			action.efgMagsGate = true

			action.OnCanRun = function(item, ...)
				if (M.UsesMags(item)) then return false end
				return !canRun or canRun(item, ...)
			end
		end
	end

	local baseDescription = ITEM.GetDescription

	function ITEM:GetDescription()
		local text = baseDescription and baseDescription(self) or self.description or ""
		if (!M.UsesMags(self)) then return text end

		local def = M.byID[M.GetWeaponMag(self) or ""]

		if (def) then
			return text .. ("\n\nCargador: %s"):format(def.name)
		end

		return text .. "\n\nSin cargador"
	end
end

function PLUGIN:InitializedPlugins()
	-- tras efg_arc9, efg_ballistics y efg_mods, que añaden sus acciones en InitializedPlugins
	timer.Simple(0.05, function()
		for _, ITEM in pairs(ix.item.list) do
			if (ITEM.isARC9) then patchWeapon(ITEM) end
		end
	end)

	if (SERVER) then
		self:AddToTradersAndLoot()
	end
end
