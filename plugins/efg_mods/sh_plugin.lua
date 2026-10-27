local PLUGIN = PLUGIN

PLUGIN.name        = "EFG Accesorios"
PLUGIN.author      = "EFG"
PLUGIN.description = "Accesorios de arma como objetos: se instalan en las ranuras del arma y cambian ergonomía, retroceso y peso."

ix.efg = ix.efg or {}
ix.efg.mods = ix.efg.mods or {}

local mods = ix.efg.mods

mods.slotNames = {
	sight    = "Mira",
	muzzle   = "Bocacha",
	grip     = "Empuñadura",
	stock    = "Culata",
	tactical = "Táctico",
	mag      = "Cargador"
}

-- ranuras por categoría de arma (weaponCategory del ítem)
mods.weaponSlots = {
	primary   = {"sight", "muzzle", "grip", "stock", "tactical", "mag"},
	primary2  = {"sight", "muzzle", "grip", "stock", "tactical", "mag"},
	secondary = {"sight", "muzzle", "tactical", "mag"},
	melee     = {}
}

-- accesorios instalados en un arma: {slot = uniqueID}
function mods.GetMods(weapon)
	return weapon:GetData("efgMods", {})
end

function mods.GetSlots(weapon)
	return weapon.efgModSlots or mods.weaponSlots[weapon.weaponCategory] or {}
end

function mods.HasSlot(weapon, slot)
	return table.HasValue(mods.GetSlots(weapon), slot)
end

-- suma de un campo numérico de todos los accesorios instalados
function mods.Sum(weapon, field)
	local total = 0

	for _, uniqueID in pairs(mods.GetMods(weapon)) do
		local mod = ix.item.list[uniqueID]
		total = total + (mod and mod[field] or 0)
	end

	return total
end

function mods.GetRecoilMult(weapon)
	local mult = 1

	for _, uniqueID in pairs(mods.GetMods(weapon)) do
		local mod = ix.item.list[uniqueID]
		mult = mult * (mod and mod.recoilMult or 1)
	end

	return mult
end

-- Añade a cada arma ARC9 la ergonomía con accesorios, la descripción y la
-- acción de quitar accesorios. Se hace tras cargar todos los plugins porque
-- efg_arc9 registra las armas en su propio InitializedPlugins.
local function patchWeapon(ITEM)
	if (ITEM.efgModsPatched) then return end
	ITEM.efgModsPatched = true

	function ITEM:GetErgonomics()
		-- con efg_inspect: stats_base del arma + accesorios
		if (ix.efg.inspect and ix.efg.inspect.Calc) then return ix.efg.inspect.Calc(self).ergo end
		return math.Clamp((self.ergonomics or 55) + mods.Sum(self, "ergoDelta"), 5, 100)
	end

	local baseDescription = ITEM.GetDescription

	function ITEM:GetDescription()
		local text = baseDescription and baseDescription(self) or self.description
		local lines = {}

		for _, slot in ipairs(mods.GetSlots(self)) do
			local uniqueID = mods.GetMods(self)[slot]
			local mod = uniqueID and ix.item.list[uniqueID]
			lines[#lines + 1] = ("%s: %s"):format(mods.slotNames[slot] or slot, mod and mod.name or "—")
		end

		if (#lines > 0) then
			text = text .. ("\n\nErgonomía con accesorios: %d\n"):format(self:GetErgonomics()) .. table.concat(lines, "\n")
		end

		return text
	end

	ITEM.functions = ITEM.functions or {}
	ITEM.functions.EfgQuitarMod = {
		name = "Quitar accesorio",
		icon = "icon16/wrench.png",
		isMulti = true,
		multiOptions = function(item)
			local options = {}

			for slot, uniqueID in pairs(mods.GetMods(item)) do
				local mod = ix.item.list[uniqueID]
				options[#options + 1] = {name = (mod and mod.name or uniqueID) .. " (" .. (mods.slotNames[slot] or slot) .. ")", data = {slot}}
			end

			return options
		end,
		OnCanRun = function(item)
			return !IsValid(item.entity) and !table.IsEmpty(mods.GetMods(item)) and !item:GetData("equip")
		end,
		OnRun = function(item, data)
			if (SERVER) then mods.Remove(item.player, item, data and data[1]) end
			return false
		end
	}
end

function PLUGIN:InitializedPlugins()
	timer.Simple(0, function()
		for _, ITEM in pairs(ix.item.list) do
			if (ITEM.isARC9) then patchWeapon(ITEM) end
		end
	end)
end

if (SERVER) then
	function mods.Install(client, mod, weapon)
		if (!IsValid(client) or !weapon or !mod) then return false end

		if (weapon:GetData("equip")) then
			client:Notify("Desequipa el arma antes de cambiar accesorios.")
			return false
		end

		if (!mods.HasSlot(weapon, mod.modSlot)) then
			client:Notify("Esta arma no tiene ranura de " .. string.lower(mods.slotNames[mod.modSlot] or mod.modSlot) .. ".")
			return false
		end

		if (ix.efg.inspect and !ix.efg.inspect.IsCompatible(weapon, mod)) then
			client:Notify(mod.name .. " no es compatible con " .. weapon.name .. ".")
			return false
		end

		local installed = mods.GetMods(weapon)

		if (installed[mod.modSlot]) then
			client:Notify("La ranura ya está ocupada. Quita antes el accesorio.")
			return false
		end

		installed = table.Copy(installed)
		installed[mod.modSlot] = mod.uniqueID
		weapon:SetData("efgMods", installed)
		mod:Remove()
		client:Notify(("%s instalado en %s."):format(mod.name, weapon.name))

		return true
	end

	function mods.Remove(client, weapon, slot)
		local installed = mods.GetMods(weapon)
		local uniqueID = slot and installed[slot]
		if (!uniqueID) then return false end

		local character = client:GetCharacter()
		local ok, err = character:GetInventory():Add(uniqueID)

		if (!ok) then
			client:NotifyLocalized(err or "noFit")
			return false
		end

		installed = table.Copy(installed)
		installed[slot] = nil
		weapon:SetData("efgMods", installed)

		return true
	end
end
