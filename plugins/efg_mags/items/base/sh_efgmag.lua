ITEM.name = "Cargador"
ITEM.description = "Cargador de un arma."
ITEM.category = "Cargadores"
ITEM.model = "models/items/arc9/att_cardboard_box.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.weight = 0.2
ITEM.capacity = 30
ITEM.isMagazine = true
ITEM.noBusiness = true

function ITEM:GetRounds()
	return self:GetData("rounds", 0)
end

function ITEM:GetRound()
	local B = ix.efg.ballistics
	return B and B.rounds[self:GetData("round", "")]
end

function ITEM:GetDescription()
	local M = ix.efg.mags
	local def = M.GetDef(self)
	if (!def) then return self.description end

	local calibers = {}

	for _, calID in ipairs(def.calibers) do
		calibers[#calibers + 1] = M.CaliberName(calID)
	end

	local round = self:GetRound()
	local text = ("Cargador de %d balas.\nCalibre: %s\nBalas: %d/%d%s"):format(def.capacity, table.concat(calibers, ", "),
		self:GetRounds(), def.capacity, (round and self:GetRounds() > 0) and ("\nMunición: " .. round.name) or "")

	if (def.ergo != 0) then
		text = text .. ("\nErgonomía: %d"):format(def.ergo)
	end

	if (CLIENT) then
		local names = M.WeaponNames(def)

		if (names != "") then
			text = text .. "\n\nArmas: " .. names
		end
	end

	return text
end

if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		draw.SimpleText(item:GetRounds() .. "/" .. item.capacity, "DermaDefault", w - 5, h - 5,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
	end
end

-- munición del inventario que se puede meter en este cargador
local function loadableRounds(item, client)
	local M = ix.efg.mags
	local def = M.GetDef(item)
	local character = IsValid(client) and client:GetCharacter()
	local counts, names = {}, {}
	if (!def or !character) then return counts, names end

	local current = item:GetRounds() > 0 and item:GetData("round")

	for _, ammo in pairs(character:GetInventory():GetItems()) do
		if (ammo.isAmmo and table.HasValue(def.calibers, ammo.efgCaliber) and (!current or ammo.efgRound == current)) then
			counts[ammo.efgRound] = (counts[ammo.efgRound] or 0) + ammo:GetRounds()
			names[ammo.efgRound] = ammo.name
		end
	end

	return counts, names
end

ITEM.functions.efgMagLoad = {
	name = "Cargar munición",
	icon = "icon16/bullet_add.png",
	isMulti = true,
	multiOptions = function(item, client)
		local options = {}
		local counts, names = loadableRounds(item, client)

		for roundID, count in SortedPairs(counts) do
			options[#options + 1] = {name = ("%s (%d)"):format(names[roundID], count), data = {roundID}}
		end

		return options
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and IsValid(item.player) and item:GetRounds() < item.capacity
	end,
	OnRun = function(item, data)
		if (SERVER and data and data[1]) then
			ix.efg.mags.Load(item.player, item, data[1])
		end

		return false
	end
}

ITEM.functions.efgMagUnload = {
	name = "Descargar",
	icon = "icon16/bullet_delete.png",
	OnCanRun = function(item)
		return !IsValid(item.entity) and IsValid(item.player) and item:GetRounds() > 0
	end,
	OnRun = function(item)
		if (SERVER) then
			ix.efg.mags.Unload(item.player, item)
		end

		return false
	end
}

ITEM.functions.efgMagToWeapon = {
	name = "Poner en el arma",
	icon = "icon16/gun.png",
	isMulti = true,
	multiOptions = function(item, client)
		local M = ix.efg.mags
		local options = {}
		local character = IsValid(client) and client:GetCharacter()

		for _, weapon in pairs(character and character:GetInventory():GetItems() or {}) do
			if (weapon.isARC9 and M.UsesMags(weapon) and M.Fits(weapon, M.GetDef(item))) then
				options[#options + 1] = {name = weapon.name .. (weapon:GetData("equip") and " (equipada)" or ""), data = {weapon:GetID()}}
			end
		end

		return options
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and IsValid(item.player)
	end,
	OnRun = function(item, data)
		if (SERVER and data) then
			local weapon = ix.item.instances[data[1]]

			if (weapon) then
				ix.efg.mags.Insert(item.player, weapon, item)
			end
		end

		return false
	end
}

-- arrastrar munición sobre el cargador lo llena con esa munición
ITEM.functions.combine = {
	OnRun = function(item, data)
		local ammo = data and ix.item.instances[data[1]]

		if (SERVER and ammo and ammo.isAmmo) then
			ix.efg.mags.Load(item.player, item, ammo.efgRound)
		end

		return false
	end,
	OnCanRun = function(item, data)
		local ammo = data and ix.item.instances[data[1]]
		return ammo != nil and ammo.isAmmo == true
	end
}
