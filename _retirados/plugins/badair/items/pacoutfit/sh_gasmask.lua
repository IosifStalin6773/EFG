ITEM.name = "Mascara de Gas"
ITEM.weight = 0.8
ITEM.description = "Una máscara de gas que te protege de ambientes tóxicos."
ITEM.model = "models/half-dead/metroll/p_mask_1.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.isGasMask = true
ITEM.price = 50
ITEM.category = "Equipamiento"
ITEM.exRender = false
ITEM.iconCam = {
	pos = Vector(0, -0.5, 16.873525619507),
	ang = Angle(90, 0, 261),
	fov = 45,
}

ITEM.pacData = {
	[1] = {
	["children"] = {
		[1] = {
			["children"] = {
			},
			["self"] = {
				["Skin"] = 0,
				["Invert"] = false,
				["LightBlend"] = 1,
				["CellShade"] = 0,
				["OwnerName"] = "self",
				["AimPartName"] = "",
				["IgnoreZ"] = false,
				["AimPartUID"] = "",
				["Passes"] = 1,
				["Name"] = "",
				["NoTextureFiltering"] = false,
				["DoubleFace"] = false,
				["PositionOffset"] = Vector(0, 0, 0),
				["IsDisturbing"] = false,
				["Fullbright"] = false,
				["EyeAngles"] = false,
				["DrawOrder"] = 0,
				["TintColor"] = Vector(0, 0, 0),
				["UniqueID"] = "1851946727",
				["Translucent"] = false,
				["LodOverride"] = -1,
				["BlurSpacing"] = 0,
				["Alpha"] = 1,
				["Material"] = "",
				["UseWeaponColor"] = false,
				["UsePlayerColor"] = false,
				["UseLegacyScale"] = false,
				["Bone"] = "head",
				["Color"] = Vector(255, 255, 255),
				["Brightness"] = 1,
				["BoneMerge"] = false,
				["BlurLength"] = 0,
				["Position"] = Vector(1.3916015625, -4.37744140625, -0.004730224609375),
				["AngleOffset"] = Angle(0, 0, 0),
				["AlternativeScaling"] = false,
				["Hide"] = false,
				["OwnerEntity"] = false,
				["Scale"] = Vector(0.001, 0.001, 0.001),
				["ClassName"] = "model",
				["EditorExpand"] = true,
				["Size"] = 1,
				["ModelFallback"] = "",
				["Angles"] = Angle(90, -65.364295959473, 0),
				["TextureFilter"] = 3,
				["Model"] = "models/half-dead/metroll/p_mask_1.mdl",
				["BlendMode"] = "",
			},
		},
	},
	["self"] = {
		["DrawOrder"] = 0,
		["UniqueID"] = "2776970907",
		["AimPartUID"] = "",
		["Hide"] = false,
		["Duplicate"] = false,
		["ClassName"] = "group",
		["OwnerName"] = "self",
		["IsDisturbing"] = false,
		["Name"] = "my outfit",
		["EditorExpand"] = true,
	},
},

}

local txtTable = {
	{math.huge, "txtCond0"},
	{75, "txtCond1"},
	{50, "txtCond2"},
	{25, "txtCond3"},
	{0.1, "txtCond4"}
}


if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end

	function ITEM:PopulateTooltip(tooltip)
		local filter = tonumber(self:getFilter()) or 0

		local healthPercent = math.Round((self:getHealth() / self:getMaxHealth()) * 100)
		local fineHealthText = "ERROR"

		for _, b in pairs(txtTable) do
			if (b[1] > healthPercent) then
				fineHealthText = L(b[2])
			end
		end

		local panel = tooltip:AddRowAfter("name", "gasmaskstatus")
		panel:SetBackgroundColor((filter <= 0 and Color (192, 57, 43) or Color(39, 174, 96)))
		panel:SetText("Filter: " ..  L(filter <= 0 and "txtFail" or "txtFunc"))
		panel:SizeToContents()

		local panel2 = tooltip:AddRowAfter("gasmaskstatus", "gasmaskhp")
		panel2:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel2:SetText("Condición: "..fineHealthText .. "(" ..healthPercent .. "%)")
		panel2:SizeToContents()
	end
end

function ITEM:isEquipped()
	return self:GetData("equip", false)
end

function ITEM:getMaxHealth()
	return ix.config.Get("gasmask_health", 240)
end

function ITEM:getHealth()
	return self:GetData("health", self:getMaxHealth())
end

function ITEM:damageHealth(amount)
	self:SetData("health", math.max(0, self:getHealth() - amount))
end

function ITEM:repairHealth(amount)
	self:SetData("health", math.min(self:getMaxHealth(), self:getHealth() + amount))
end

function ITEM:getFilter()
	return self:GetData("filter", ix.config.Get("gasmask_filter", 240))
end

function ITEM:damageFilter(amount)
	self:SetData("filter", math.max(0, self:getFilter() - amount))
end

local function playerGasmask(client, item, bool)
	local char = client:GetCharacter()

	if (bool) then
		client.ixGasMaskItem = item
		client:AddPart(item.uniqueID, item)

		netstream.Start(client, "ixMaskOn", item:GetID(), item:getHealth()) 
	else
		client.ixGasMaskItem = nil
		client:RemovePart(item.uniqueID)
		local activeWep = client:GetActiveWeapon()
		client.previousWep = IsValid(activeWep) and activeWep:GetClass() or "ix_hands"
		client:Give( "badair_gasmask_holster" )
		client:SelectWeapon("badair_gasmask_holster")
		client:SetWepRaised(true)
		timer.Simple( 1, function()
			if (!IsValid(client) or !client:Alive()) then return end
			client:StripWeapon("badair_gasmask_holster")
			client:SelectWeapon(client.previousWep or "ix_hands")
			client.previousWep = nil
		end )

		netstream.Start(client, "ixMaskOff")
	end

	item:SetData("equip", bool)
	if (!bool) then
	client:EmitSound("gasmask/gasmask_holster_fast.wav", 80)
	end

	client:ScreenFade(1, Color(0, 0, 0, 255), 1, 0)
end

// external use
function ITEM:EquipMask(client, item, bool)

	item.player = client
	return playerGasmask(client, item, bool)


end	

ITEM:Hook("drop", function(item)
	if (item:isEquipped()) then
		local client = item.player
		
		playerGasmask(client, item, false)
	end
end)

ITEM.functions.EquipUn = { -- sorry, for name order.
	name = "Desequipar",
	tip = "unequipTip",
	icon = "icon16/cross.png",
	OnRun = function(item)		
		playerGasmask(item.player, item, false)

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and item:isEquipped())
	end
}

ITEM.functions.Equip = {
	name = "Equipar",
	tip = "equipTip",
	icon = "icon16/tick.png",
	OnRun = function(item)
		local client = item.player

		-- Antes miraba "client.nutGasMaskItem", una variable que no se
		-- establece en ningún sitio (typo de un mod portado de otro
		-- framework) — el bloqueo nunca saltaba y se podían equipar varias
		-- máscaras a la vez. La variable real es "ixGasMaskItem" (ver
		-- playerGasmask más abajo y PLAYER:getGasMask() en sh_plugin.lua).
		if (client:getGasMask()) then
			client:NotifyLocalized("maskEquipped")

			return false
		end

		-- INITIALIZE TEMP MASKVARS
		local activeWep = client:GetActiveWeapon()
		client.previousWep = IsValid(activeWep) and activeWep:GetClass() or "ix_hands"
		client:Give( "badair_gasmask_deploy" )
		client:SelectWeapon("badair_gasmask_deploy")
		client:SetWepRaised(true)
		item.player:EmitSound("gasmask/gasmask_holster_fast.wav", 80)
		timer.Simple( 1.2, function()
			if (!IsValid(client) or !client:Alive()) then return end
			playerGasmask(client, item, true)
			client:StripWeapon("badair_gasmask_deploy")
			client:SelectWeapon(client.previousWep or "ix_hands")
			client.previousWep = nil
		end )

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and !item:isEquipped())
	end
}

local function changeFilter(client, item, targetItem)
	if (item and targetItem and targetItem.isFilter) then
		if (targetItem.onChangeFilter) then
			targetItem:onChangeFilter(item, targetItem)
		end

		local filter = targetItem:getFilterHealth()
		item:SetData("filter", filter)
		
        client:NotifyLocalized("gmskFilter")
		return true
	end

	return false
end

-- for external use.
function ITEM:changeFilter(client, item, targetItem)
	if (item:canChangeFilter()) then
		return changeFilter(client, item, targetItem)
	else
		client:NotifyLocalized("maskFull")
		
		return false
	end
end

function ITEM:canChangeFilter()
	return (self:getHealth() > 0 and self:getFilter() < ix.config.Get("gasmask_filter", 240))
end

ITEM.functions.Filter = {
	name = "Cambair Filtro",
	tip = "filterTip",
	icon = "icon16/wrench.png",
	-- isMulti = true,
	-- multiOptions = function(item, client)
	-- 	local char = client:GetCharacter()
	-- 	local inv = char:GetInventory()
	-- 	local items = inv:GetItems()
	-- 	local result = {}

	-- 	for k, v in pairs(items) do
	-- 		if (v.isFilter) then
	-- 			table.insert(result, {
	-- 				name = Format("%s (%s)", v.name, v:getFilterHealth() or 0),
	-- 				data = v:GetID()
	-- 			})
	-- 		end
	-- 	end

	-- 	return result
	-- end,
	OnRun = function(item, data)
		local client = item.player
		if (item:canChangeFilter()) then
			local char = client:GetCharacter()
			local inv = char:GetInventory()
			local items = inv:GetItems()
			local target

			-- if (data) then
			-- 	target = ix.item.instances[data]
				
			-- 	if (!items[target.id]) then
			-- 		return false -- stop hacking you dumb fuck
			-- 	end
			-- else
				for k, invItem in pairs(items) do
					if (invItem.isFilter) then
						target = invItem
						
						break
					end
				end
			-- end

			if (target) then
				if (changeFilter(client, item, target)) then
					target:Remove()
				end
			else
				client:NotifyLocalized("noFilter")
			end
		else
			client:NotifyLocalized("maskFull")
		end

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and item:canChangeFilter())
	end
}

ITEM.functions.Reparar = {
	name = "Reparar",
	tip = "repairTip",
	icon = "icon16/wrench.png",
	OnRun = function(item)
		local client = item.player
		local char = client:GetCharacter()

		if (!char) then return false end

		local inv = char:GetInventory()
		local tape

		for k, invItem in pairs(inv:GetItems()) do
			if (invItem.uniqueID == "adhesivo") then
				tape = invItem

				break
			end
		end

		if (!tape) then
			client:NotifyLocalized("noTape")

			return false
		end

		item:repairHealth(ix.config.Get("gasmask_repair", 50))

		-- Descontar un uso del rollo; gastarlo solo cuando se agota.
		local usesLeft = tape:getUses() - 1

		if (usesLeft <= 0) then
			tape:Remove()
		else
			tape:SetData("uses", usesLeft)
		end

		-- Refrescar las grietas del overlay si la máscara está equipada.
		if (item:isEquipped()) then
			netstream.Start(client, "ixMaskOn", item:GetID(), item:getHealth())
			item.curCracks = math.Round((1 - item:getHealth() / item:getMaxHealth()) * 6)
		end

		client:EmitSound("gasmask/gasmask_holster_fast.wav", 80)
		client:NotifyLocalized("maskRepaired")

		return false
	end,
	OnCanRun = function(item)
		return (!IsValid(item.entity) and item:getHealth() < item:getMaxHealth())
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and self:GetData("equip")) then
		return false
	end

	return true
end

-- Called when a new instance of this item has been made.
-- OnInstanced corre DESPUÉS de asignar item.data en ix.item.Instance, así que
-- solo inicializamos las claves ausentes; de lo contrario pisaríamos los datos
-- preservados al recomprar una máscara usada (durabilidad/filtro) en los traders.
function ITEM:OnInstanced(invID, x, y)
	if (self:GetData("equip") == nil) then
		self:SetData("equip", false)
	end
	if (self:GetData("health") == nil) then
		self:SetData("health", self:getMaxHealth())
	end
	if (self:GetData("filter") == nil) then
		self:SetData("filter", ix.config.Get("gasmask_filter", 240))
	end
end