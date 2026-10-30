PLUGIN.name = "Spawn Menu: Items"
PLUGIN.author = "EFG Project" -- original: Rune Knight
PLUGIN.description = "Pestaña de objetos en el menú Q para admins: grupos, subcategorías y buscador."
PLUGIN.license = [[Copyright 2021 Rune Knight

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.]]

--[[
	STEAM: https://steamcommunity.com/profiles/76561198028996329/
	DISCORD: Rune Knight#5972
]]

local PRIVILEGE = "Spawn Menu: Items - Spawning"

CAMI.RegisterPrivilege({
	Name = PRIVILEGE,
	MinAccess = "superadmin"
})

local PLUGIN = PLUGIN

-- ─── Grupos del menú ────────────────────────────────────────────────────────
-- Cada categoría de Helix cae en un grupo; lo que no esté aquí va a "Otros".
-- Armas, munición y accesorios se subdividen por tipo, calibre y pieza.
PLUGIN.groups = {
	{name = "Armas", icon = "icon16/gun.png", categories = {"Armas", "Weapons", "ARC9 Weapons"}},
	{name = "Accesorios de armas", icon = "icon16/plugin.png", categories = {"Accesorios", "Accesorios T1", "Accesorios T2", "Accesorios T3", "ARC9 Attachments", "Mods"}},
	{name = "Munición", icon = "icon16/box.png", categories = {"Municion", "Munición", "Ammunition"}},
	{name = "Cargadores", icon = "icon16/bullet_black.png", categories = {"Cargadores"}},
	{name = "Protección", icon = "icon16/shield.png", categories = {"Cascos", "Chalecos", "Armaduras", "Placas"}},
	{name = "Equipo", icon = "icon16/briefcase.png", categories = {"Mochilas", "Contenedores", "Equipamiento", "Equipo", "Radios", "Clothing", "Storage", "misc"}},
	{name = "Medicina", icon = "icon16/heart.png", categories = {"Medicamentos", "Estimulantes", "Drogas", "Medical"}},
	{name = "Provisiones", icon = "icon16/cake.png", categories = {"Comestibles", "Bebidas", "Consumibles", "Comida"}},
	{name = "Botín", icon = "icon16/coins.png", categories = {"Objetos de valor", "Electrónica", "Recursos", "Herramientas", "Dinero", "Chapas"}},
	{name = "Llaves y misiones", icon = "icon16/key.png", categories = {"Llaves", "Misión", "Datos Técnicos", "Documentos", "Permits", "Aprendizaje"}},
	{name = "Otros", icon = "icon16/folder.png", categories = {}}
}

-- nombre de subcategoría para categorías que son lo mismo con otro nombre
PLUGIN.categoryAlias = {
	["misc"] = "Equipamiento", ["Equipo"] = "Equipamiento", ["Weapons"] = "Armas", ["ARC9 Weapons"] = "Armas",
	["ARC9 Attachments"] = "Accesorios", ["Municion"] = "Munición", ["Ammunition"] = "Munición", ["Comida"] = "Comestibles"
}

-- ARC9 SWEP.Class → tipo de arma (el orden importa: "submachine" antes que "machine")
PLUGIN.weaponTypes = {
	{"submachine", "Subfusiles"}, {"smg", "Subfusiles"}, {"pdw", "Subfusiles"},
	{"machine pistol", "Pistolas"}, {"machine gun", "Ametralladoras"}, {"lmg", "Ametralladoras"},
	{"assault", "Fusiles de asalto"}, {"carbine", "Carabinas"}, {"battle", "Fusiles de combate"},
	{"marksman", "Fusiles de tirador"}, {"dmr", "Fusiles de tirador"}, {"sniper", "Fusiles de cerrojo"}, {"bolt", "Fusiles de cerrojo"},
	{"shotgun", "Escopetas"}, {"launcher", "Lanzagranadas"}, {"grenade", "Granadas"},
	{"pistol", "Pistolas"}, {"revolver", "Pistolas"}, {"handgun", "Pistolas"},
	{"melee", "Cuerpo a cuerpo"}, {"knife", "Cuerpo a cuerpo"}
}

PLUGIN.attachmentTypes = {
	muzzle_brake = "Frenos de boca", compensator = "Compensadores", flash_hider = "Apagallamas", suppressor = "Supresores",
	muzzle = "Bocachas", scope = "Miras de aumento", sight = "Miras", mount = "Monturas", barrel = "Cañones",
	handguard = "Guardamanos", foregrip = "Empuñaduras", pistol_grip = "Pistoletes", stock = "Culatas",
	buffer = "Tubos de culata", gas_block = "Bloques de gas", receiver = "Cajones de mecanismos",
	charging = "Palancas de carga", magazine = "Cargadores", tactical = "Dispositivos tácticos",
	bipod = "Bípodes", ammo = "Munición especial"
}

local function isWeaponItem(item)
	return item.isARC9 or item.isGrenade or (item.class and item.weaponCategory)
end

function PLUGIN:GetWeaponType(item)
	if (item.isGrenade) then return "Granadas" end

	local swep = item.class and weapons.GetStored(item.class)
	local class = swep and isstring(swep.Class) and swep.Class:lower() or ""

	for _, entry in ipairs(self.weaponTypes) do
		if (class:find(entry[1], 1, true)) then
			return entry[2]
		end
	end

	if (item.weaponCategory == "secondary") then return "Pistolas" end
	if (item.weaponCategory == "melee") then return "Cuerpo a cuerpo" end

	return "Otras armas"
end

-- grupo (índice en PLUGIN.groups) y subcategoría de un ítem
function PLUGIN:Classify(item)
	local category = item.category or "misc"

	if (item.isAmmo) then
		local B = ix.efg and ix.efg.ballistics
		local caliber = B and B.calibers and B.calibers[item.efgCaliber]

		return self.groupIndex["Munición"], caliber and caliber.name or "Otros calibres"
	end

	-- cargadores por calibre (efg_mags)
	if (item.isMagazine and item.magDef) then
		local mags = ix.efg and ix.efg.mags
		return self.groupIndex["Cargadores"], mags and mags.CaliberName(item.magDef.calibers[1]) or "Cargadores"
	end

	if (isWeaponItem(item)) then
		return self.groupIndex["Armas"], self:GetWeaponType(item)
	end

	if (item.eftType or item.modSlot) then
		local name = item.eftType and self.attachmentTypes[item.eftType]

		if (!name and item.modSlot) then
			local mods = ix.efg and ix.efg.mods
			name = mods and mods.slotNames and mods.slotNames[item.modSlot]
		end

		return self.groupIndex["Accesorios de armas"], name or "Otros accesorios"
	end

	return self.categoryGroup[category] or #self.groups, self.categoryAlias[category] or category
end

function PLUGIN:BuildIndex()
	self.groupIndex, self.categoryGroup = {}, {}

	for index, group in ipairs(self.groups) do
		self.groupIndex[group.name] = index

		for _, category in ipairs(group.categories) do
			self.categoryGroup[category] = index
		end
	end

	local index = {}

	for _, item in pairs(ix.item.list) do
		local group, sub = self:Classify(item)

		index[group] = index[group] or {count = 0, subs = {}}
		index[group].subs[sub] = index[group].subs[sub] or {}
		index[group].count = index[group].count + 1
		table.insert(index[group].subs[sub], item)
	end

	self.index = index

	return index
end

if (SERVER) then
	util.AddNetworkString("spawnmenuspawnitem")
	util.AddNetworkString("spawnmenugiveitem")

	ix.log.AddType("spawnmenuspawnitem", function(client, name, amount)
		local character = client:GetCharacter()
		return string.format("%s ha sacado \"%s\"%s.", character and character:GetName() or client:Name(), tostring(name), (amount and amount > 1) and (" x" .. amount) or "")
	end)

	net.Receive("spawnmenuspawnitem", function(len, client)
		local item = ix.item.list[net.ReadString()]
		if (!item or !CAMI.PlayerHasAccess(client, PRIVILEGE, nil)) then return end

		ix.item.Spawn(item.uniqueID, client:GetShootPos() + client:GetAimVector() * 84 + Vector(0, 0, 16))
		ix.log.Add(client, "spawnmenuspawnitem", item.name)
	end)

	net.Receive("spawnmenugiveitem", function(len, client)
		local item = ix.item.list[net.ReadString()]
		local amount = math.Clamp(net.ReadUInt(8), 1, 50)
		local character = client:GetCharacter()
		if (!item or !character or !CAMI.PlayerHasAccess(client, PRIVILEGE, nil)) then return end

		local inventory = character:GetInventory()
		local given = 0

		for _ = 1, amount do
			local ok, err = inventory:Add(item.uniqueID)

			if (!ok) then
				client:NotifyLocalized(err or "noFit")
				break
			end

			given = given + 1
		end

		if (given > 0) then
			ix.log.Add(client, "spawnmenuspawnitem", item.name, given)
		end
	end)

	return
end

-- ─── Cliente ────────────────────────────────────────────────────────────────
local MAX_ICONS = 300

-- minúsculas sin tildes, para buscar "municion" y encontrar "Munición"
local accents = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n"
}

local function fold(text)
	text = tostring(text or "")

	for from, to in pairs(accents) do
		text = text:gsub(from, to)
	end

	return text:lower()
end

local function itemName(item)
	return (item.GetName and item:GetName()) or item.name or item.uniqueID
end

local function sortedItems(list)
	local sorted = table.Copy(list)

	table.sort(sorted, function(a, b)
		return fold(itemName(a)) < fold(itemName(b))
	end)

	return sorted
end

local function sendGive(uniqueID, amount)
	net.Start("spawnmenugiveitem")
		net.WriteString(uniqueID)
		net.WriteUInt(amount, 8)
	net.SendToServer()
end

local function sendSpawn(uniqueID)
	net.Start("spawnmenuspawnitem")
		net.WriteString(uniqueID)
	net.SendToServer()
end

function PLUGIN:InitializedPlugins()
	-- las armas, la munición y los accesorios se registran en InitializedPlugins
	-- de otros plugins (algunos con un tick de retraso): se espera antes de rehacer el menú
	timer.Simple(1, function()
		RunConsoleCommand("spawnmenu_reload")
	end)
end

spawnmenu.AddCreationTab("Items", function()
	local panel = vgui.Create("SpawnmenuContentPanel")
	local tree = panel.ContentNavBar.Tree
	local index = PLUGIN:BuildIndex()

	local function show(fill)
		if (IsValid(panel.efgContainer)) then
			panel.efgContainer:Remove()
		end

		local container = vgui.Create("ContentContainer", panel)
		container:SetVisible(false)
		container:SetTriggerSpawnlistChange(false)
		fill(container)

		panel.efgContainer = container
		panel:SwitchPanel(container)
	end

	local function addItems(container, items, limit)
		local shown = 0

		for _, item in ipairs(sortedItems(items)) do
			if (limit and shown >= limit) then break end

			spawnmenu.CreateContentIcon("item", container, {
				nicename = itemName(item),
				spawnname = item.uniqueID
			})

			shown = shown + 1
		end

		return shown
	end

	-- buscador encima del árbol
	local search = vgui.Create("DTextEntry", panel.ContentNavBar)
	search:Dock(TOP)
	search:DockMargin(0, 0, 0, 4)
	search:SetTall(24)
	search:SetPlaceholderText("Buscar por nombre o ID...")
	search:SetUpdateOnType(true)

	search.OnValueChange = function(this, value)
		timer.Create("ixSpawnmenuItemSearch", 0.25, 1, function()
			if (!IsValid(panel)) then return end

			local query = fold(string.Trim(value))
			if (#query < 2) then return end

			local results = {}

			for _, item in pairs(ix.item.list) do
				if (fold(itemName(item)):find(query, 1, true) or item.uniqueID:lower():find(query, 1, true)) then
					results[#results + 1] = item
				end
			end

			show(function(container)
				local text = #results > MAX_ICONS and ("Resultados: %d (se muestran %d, afina la búsqueda)"):format(#results, MAX_ICONS) or ("Resultados: %d"):format(#results)
				spawnmenu.CreateContentIcon("header", container, {text = text})
				addItems(container, results, MAX_ICONS)
			end)
		end)
	end

	for groupID, group in ipairs(PLUGIN.groups) do
		local data = index[groupID]

		if (data) then
			local node = tree:AddNode(("%s (%d)"):format(group.name, data.count), group.icon)

			-- el grupo entero, con un encabezado por subcategoría
			node.DoClick = function()
				show(function(container)
					local left = MAX_ICONS

					for sub, items in SortedPairs(data.subs) do
						spawnmenu.CreateContentIcon("header", container, {text = ("%s (%d)"):format(sub, #items)})

						if (left > 0) then
							left = left - addItems(container, items, left)
						end
					end

					if (left <= 0) then
						spawnmenu.CreateContentIcon("header", container, {text = "Hay más objetos: abre una subcategoría o usa el buscador."})
					end
				end)
			end

			for sub, items in SortedPairs(data.subs) do
				local child = node:AddNode(("%s (%d)"):format(sub, #items), group.icon)

				child.DoClick = function()
					show(function(container)
						addItems(container, items)
					end)
				end
			end
		end
	end

	local first = tree:Root():GetChildNode(0)

	if (IsValid(first)) then
		first:InternalDoClick()
	end

	return panel
end, "icon16/cog_add.png", 201)

-- Icono de un objeto: imagen 2D de EFG si la hay, si no el modelo.
-- Clic: aparece delante. Clic derecho: dar al inventario, copiar ID...
spawnmenu.AddContentType("item", function(container, data)
	local item = ix.item.list[data.spawnname]
	if (!item) then return end

	local uniqueID = item.uniqueID
	local icon = vgui.Create("DButton", container)
	icon:SetSize(64, 64)
	icon:SetText("")
	icon:SetTooltip(("%s\n%s\n\nClic: aparecer delante\nClic derecho: dar al inventario / copiar ID"):format(data.nicename, uniqueID))

	local path = ix.efg and ix.efg.icons and ix.efg.icons.Resolve(item)

	if (path) then
		icon.material = Material(path, "smooth mips")
	else
		local model = vgui.Create("SpawnIcon", icon)
		model:Dock(FILL)
		model:SetModel((item.GetModel and item:GetModel()) or item.model or "models/props_junk/cardboard_box004a.mdl", item.skin or 0)
		model:SetMouseInputEnabled(false)
	end

	icon.Paint = function(this, width, height)
		surface.SetDrawColor(this:IsHovered() and Color(70, 70, 64) or Color(40, 40, 36))
		surface.DrawRect(0, 0, width, height)

		if (this.material and !this.material:IsError()) then
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(this.material)
			surface.DrawTexturedRect(2, 2, width - 4, height - 4)
		end
	end

	-- nombre abajo, por encima del modelo
	icon.PaintOver = function(this, width, height)
		surface.SetFont("DefaultSmall")

		local text = this.shortName

		if (!text) then
			text = data.nicename

			while (#text > 3 and surface.GetTextSize(text) > width - 4) do
				text = text:sub(1, (utf8.offset(text, -1) or #text) - 1)
			end

			this.shortName = text
		end

		surface.SetDrawColor(0, 0, 0, 170)
		surface.DrawRect(0, height - 13, width, 13)
		draw.SimpleText(text, "DefaultSmall", width / 2, height - 7, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	icon.DoClick = function()
		surface.PlaySound("ui/buttonclickrelease.wav")
		sendSpawn(uniqueID)
	end

	icon.DoRightClick = function()
		local menu = DermaMenu()
		menu:AddOption("Dar al inventario", function() sendGive(uniqueID, 1) end):SetIcon("icon16/basket_put.png")
		menu:AddOption("Dar x5", function() sendGive(uniqueID, 5) end):SetIcon("icon16/basket_add.png")
		menu:AddOption("Aparecer delante", function() sendSpawn(uniqueID) end):SetIcon("icon16/arrow_down.png")
		menu:AddSpacer()
		menu:AddOption("Copiar ID (" .. uniqueID .. ")", function() SetClipboardText(uniqueID) end):SetIcon("icon16/page_copy.png")
		menu:Open()
	end

	container:Add(icon)

	return icon
end)
