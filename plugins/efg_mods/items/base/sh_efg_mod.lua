-- items/base/sh_efg_mod.lua
-- Accesorio de arma. Cada accesorio define modSlot y sus modificadores:
--   ergoDelta  suma a la ergonomía del arma
--   recoilMult multiplica el retroceso (menos de 1 = menos retroceso)
--   weight     peso del accesorio (se suma al del arma cuando está instalado)

ITEM.name        = "Accesorio"
ITEM.description = "Accesorio de arma."
ITEM.model       = "models/props_lab/box01a.mdl"
ITEM.width       = 1
ITEM.height      = 1
ITEM.weight      = 0.2
ITEM.category    = "Accesorios"
ITEM.isEFGMod    = true
ITEM.modSlot     = "sight"
ITEM.ergoDelta   = 0
ITEM.recoilMult  = 1

function ITEM:GetDescription()
	local slotName = ix.efg.mods.slotNames[self.modSlot] or self.modSlot
	local lines = {self.description, "", "Ranura: " .. slotName}

	if (self.ergoDelta != 0) then
		lines[#lines + 1] = ("Ergonomía: %+d"):format(self.ergoDelta)
	end

	if (self.recoilMult != 1) then
		lines[#lines + 1] = ("Retroceso: %+d%%"):format(math.Round((self.recoilMult - 1) * 100))
	end

	return table.concat(lines, "\n")
end

ITEM.functions.EfgInstalar = {
	name = "Instalar en arma",
	icon = "icon16/wrench.png",
	isMulti = true,
	multiOptions = function(item, client)
		local options = {}
		local character = IsValid(client) and client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (inventory) then
			for _, weapon in pairs(inventory:GetItems()) do
				if (weapon.isARC9 and ix.efg.mods.HasSlot(weapon, item.modSlot)) then
					options[#options + 1] = {name = weapon.name, data = {weapon:GetID()}}
				end
			end
		end

		return options
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and IsValid(item.player)
	end,
	OnRun = function(item, data)
		if (SERVER) then
			local weapon = data and ix.item.instances[data[1]]
			local character = item.player:GetCharacter()

			if (weapon and character and weapon.invID == character:GetInventory():GetID()) then
				ix.efg.mods.Install(item.player, item, weapon)
			end
		end

		return false
	end
}
