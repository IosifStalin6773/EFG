ITEM.name = "Armadura"
ITEM.description = "Base de armadura."
ITEM.category = "Armaduras"
ITEM.model = "models/Gibs/HGIBS.mdl"
ITEM.width = 1
ITEM.armorAmount = 1
ITEM.resiAmount = 1
ITEM.height = 1
ITEM.outfitCategory = "model"
ITEM.gasmask = false
ITEM.resistance = false
ITEM.handsModel = nil  -- modelo de manos en 1ª persona (opcional, e.g. "models/...")
ITEM.pacData = {}
ITEM.damage = {1, 1, 1, 1, 1, 1, 1}
-- Aislamiento térmico: temperatura (°C) mínima que la armadura mantiene cómoda.
-- Menor = más abrigada. nil = sin aislamiento (usa la tolerancia base del jugador).
-- Lo consume el plugin "temperatura".
ITEM.coldThreshold = nil

--[[
-- This will change a player's skin after changing the model. Keep in mind it starts at 0.
ITEM.newSkin = 1
-- This will change a certain part of the model.
ITEM.replacements = {"group01", "group02"}
-- This will change the player's model completely.
ITEM.replacements = "models/manhack.mdl"
-- This will have multiple replacements.
ITEM.replacements = {
	{"male", "female"},
	{"group01", "group02"}
}

-- This will apply body groups.
ITEM.bodyGroups = {
	["blade"] = 1,
	["bladeblur"] = 1
}
]]--

function ITEM:GetDescription()
	local durabilidad = math.floor(self:GetData("Durability", 100))
	local desc = self.description .. "\n\nDurabilidad: " .. durabilidad .. "%"

	if (self.resistance and self.damage) then
		local d = self.damage
		desc = desc .. "\n\nProtección:"
		if (d[1] and d[1] < 1) then desc = desc .. "\n  Balas:        " .. math.Round((1 - d[1]) * 100) .. "%" end
		if (d[2] and d[2] < 1) then desc = desc .. "\n  Corte:        " .. math.Round((1 - d[2]) * 100) .. "%" end
		if (d[3] and d[3] < 1) then desc = desc .. "\n  Electricidad: " .. math.Round((1 - d[3]) * 100) .. "%" end
		if (d[4] and d[4] < 1) then desc = desc .. "\n  Fuego:        " .. math.Round((1 - d[4]) * 100) .. "%" end
		if (d[5] and d[5] < 1) then desc = desc .. "\n  Radiación:    " .. math.Round((1 - d[5]) * 100) .. "%" end
		if (d[6] and d[6] < 1) then desc = desc .. "\n  Ácido:        " .. math.Round((1 - d[6]) * 100) .. "%" end
		if (d[7] and d[7] < 1) then desc = desc .. "\n  Explosión:    " .. math.Round((1 - d[7]) * 100) .. "%" end
	end

	if (self.coldThreshold != nil) then
		desc = desc .. "\n\nAísla del frío hasta: " .. self.coldThreshold .. "°C"
	end

	return desc
end


-- Inventory drawing
if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end

end

-- Resetea bodygroups y skin a su valor por defecto (0). Se usa al cambiar de
-- modelo para evitar que índices de bodygroup/skin del modelo anterior queden
-- aplicados incorrectamente sobre el nuevo modelo.
function ITEM:ResetAppearance(client)
	client:SetSkin(0)

	for _, bodyGroup in ipairs(client:GetBodyGroups()) do
		client:SetBodygroup(bodyGroup.id, 0)
	end
end

function ITEM:RemoveOutfit(client)
	local character = client:GetCharacter()

	self:SetData("equip", false)

	client:SetNetVar("gasmask", false)
	client:SetNetVar("resistance", false)
	client:SetNetVar("customHands", nil)
	client:SetupHands()
	if (character:GetData("oldModel" .. self.outfitCategory)) then
		character:SetModel(character:GetData("oldModel" .. self.outfitCategory))
		character:SetData("oldModel" .. self.outfitCategory, nil)

		self:ResetAppearance(client)
	end

	if (self.newSkin) then
		client:SetSkin(0)
	end

	for k, _ in pairs(self.bodyGroups or {}) do
		local index = client:FindBodygroupByName(k)

		if (index > -1) then
			client:SetBodygroup(index, 0)

			local groups = character:GetData("groups" .. self.outfitCategory, {})

			if (groups[index]) then
				groups[index] = nil
				character:SetData("groups" .. self.outfitCategory, groups)
			end
		end
	end

	if (self.attribBoosts) then
		for k, _ in pairs(self.attribBoosts) do
			character:RemoveBoost(self.uniqueID, k)
		end
	end

	for k, _ in pairs(self:GetData("outfitAttachments", {})) do
		self:RemoveAttachment(k, client)
	end

	self:OnUnequipped()
end

-- makes another outfit depend on this outfit in terms of requiring this item to be equipped in order to equip the attachment
-- also unequips the attachment if this item is dropped
function ITEM:AddAttachment(id)
	local attachments = self:GetData("outfitAttachments", {})
	attachments[id] = true

	self:SetData("outfitAttachments", attachments)
end

function ITEM:RemoveAttachment(id, client)
	local item = ix.item.instances[id]
	local attachments = self:GetData("outfitAttachments", {})

	if (item and attachments[id]) then
		item:OnDetached(client)
	end

	attachments[id] = nil
	self:SetData("outfitAttachments", attachments)
end

function ITEM:OnInstanced()
	-- Solo inicializar si no hay durabilidad previa; OnInstanced corre DESPUÉS de
	-- asignar item.data, así que sobrescribir aquí borraría la durabilidad
	-- preservada al recomprar una armadura usada en los traders.
	if (self:GetData("Durability") == nil) then
		self:SetData("Durability", 100)
	end
end

ITEM.functions.RepararConKit = {
	name = "Reparar con Kit",
	icon = "icon16/wrench.png",
	OnRun = function(item)
		local client = item.player
		if (!IsValid(client)) then return false end
		local character = client:GetCharacter()
		if (!character) then return false end
		local inventory = character:GetInventory()

		local kit = nil
		for k, v in pairs(inventory:GetItems()) do
			if (v.uniqueID == "kit_reparacion_armadura") then
				kit = v
				break
			end
		end

		if (!kit) then
			client:Notify("Necesitas un Kit de Reparación de Armadura.")
			return false
		end

		kit:Remove()
		local calidad = hook.Run("GetCalidadReparacion", character) or 100
		item:SetData("Durability", calidad)
		hook.Run("OnEquipoReparado", client)
		client:Notify("Has reparado " .. item.name .. " con el kit.")
		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and IsValid(item.player) and item:GetData("Durability", 100) < 100
	end
}

ITEM:Hook("drop", function(item)
	local client = item.player
	if (item:GetData("equip") and IsValid(client)) then
		item:RemoveOutfit(client)
	end
end)

ITEM.functions.EquipUn = {
	name = "Quitar",
	tip = "equipTip",
	icon = "icon16/cross.png",
	OnRun = function(item)
		local client = item.player

		item:RemoveOutfit(item.player)

		client:SetNetVar("gasmask", false)
		client:SetNetVar("resistance", false)

		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") == true and
			hook.Run("CanPlayerUnequipItem", client, item) != false and item.invID == client:GetCharacter():GetInventory():GetID()
	end
}

ITEM.functions.Equip = {
	name = "Equipar",
	tip = "equipTip",
	icon = "icon16/tick.png",
	OnRun = function(item)
		if (item:GetData("Durability", 100) >= 50) then
			local client = item.player
			local char = client:GetCharacter()
			local items = char:GetInventory():GetItems()

			for _, v in pairs(items) do
				if (v.id != item.id) then
					local itemTable = ix.item.instances[v.id]

					if (itemTable.pacData and v.outfitCategory == item.outfitCategory and itemTable:GetData("equip")) then
						client:NotifyLocalized(item.equippedNotify or "outfitAlreadyEquipped")
						return false
					end
				end
			end

			item:SetData("equip", true)
			
			if (item.gasmask == true) then
				client:SetNetVar("gasmask", true)
			else
				client:SetNetVar("gasmask", false)
			end
			
			if (item.resistance == true) then
				client:SetNetVar("resistance", true)
			else
				client:SetNetVar("resistance", false)
			end

			if (item.handsModel) then
				client:SetNetVar("customHands", item.handsModel)
			else
				client:SetNetVar("customHands", nil)
			end
			client:SetupHands()

			client:SetNWFloat("dmg_bullet", item.damage[1])
			client:SetNWFloat("dmg_slash", item.damage[2])
			client:SetNWFloat("dmg_shock", item.damage[3])
			client:SetNWFloat("dmg_burn", item.damage[4])
			client:SetNWFloat("dmg_radiation", item.damage[5])
			client:SetNWFloat("dmg_acid", item.damage[6])
			client:SetNWFloat("dmg_explosive", item.damage[7])
			
			item.player:EmitSound("snd_jack_clothequip.wav", 80)

			if (type(item.OnGetReplacement) == "function") then
				char:SetData("oldModel" .. item.outfitCategory, char:GetData("oldModel" .. item.outfitCategory, item.player:GetModel()))
				char:SetModel(item:OnGetReplacement())
				item:ResetAppearance(item.player)
			elseif (item.replacement or item.replacements) then
				char:SetData("oldModel" .. item.outfitCategory, char:GetData("oldModel" .. item.outfitCategory, item.player:GetModel()))

				if (type(item.replacements) == "table") then
					if (#item.replacements == 2 and type(item.replacements[1]) == "string") then
						char:SetModel(item.player:GetModel():gsub(item.replacements[1], item.replacements[2]))
					else
						for _, v in ipairs(item.replacements) do
							char:SetModel(item.player:GetModel():gsub(v[1], v[2]))
						end
					end
				else
					char:SetModel(item.replacement or item.replacements)
				end

				item:ResetAppearance(item.player)
			end

			if (item.newSkin) then
				item.player:SetSkin(item.newSkin)
			end

			if (item.bodyGroups) then
				local groups = {}

				for k, value in pairs(item.bodyGroups) do
					local index = item.player:FindBodygroupByName(k)

					if (index > -1) then
						groups[index] = value
					end
				end

				local newGroups = char:GetData("groups", {})

				for index, value in pairs(groups) do
					newGroups[index] = value
					item.player:SetBodygroup(index, value)
				end

				if (table.Count(newGroups) > 0) then
					char:SetData("groups", newGroups)
				end
			end

			if (item.attribBoosts) then
				for k, v in pairs(item.attribBoosts) do
					char:AddBoost(item.uniqueID, k, v)
				end
			end

			item:OnEquipped()
		return false
	else
		return false
	end
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") != true and item:CanEquipOutfit() and
			hook.Run("CanPlayerEquipItem", client, item) != false and item.invID == client:GetCharacter():GetInventory():GetID()
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	-- permitir mover hacia/desde el inventario de equipo aunque esté equipada
	-- (lo gestiona el plugin ix_invkey: equipar = mover al inv de equipo).
	if (newInventory and newInventory.vars and newInventory.vars.isEquipment) then
		return true
	end
	if (oldInventory and oldInventory.vars and oldInventory.vars.isEquipment) then
		return true
	end

	if (newInventory and self:GetData("equip")) then
		return false
	end

	return true
end

function ITEM:OnRemoved()
	if (self.invID != 0 and self:GetData("equip")) then
		self.player = self:GetOwner()
			self:RemoveOutfit(self.player)
		self.player = nil
	end
end

function ITEM:OnEquipped()
end

function ITEM:OnUnequipped()
end

function ITEM:CanEquipOutfit()
	if (self:GetData("Durability", 100) <= 50) then
		return false
	end

	return true
end
