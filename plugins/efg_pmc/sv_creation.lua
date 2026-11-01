-- Servidor del creador de PMC: valida lo que manda el cliente (apariencia,
-- accesorios, atributos y rol), monta el equipo inicial y aplica la apariencia.
-- Nada de lo que llega del cliente se usa sin pasar por PMC.Validate*.
local PLUGIN = PLUGIN
local PMC = ix.efg.pmc

util.AddNetworkString("ixEFGPMCLook")

-- habilidad de EFT que sube cada atributo de inicio (plugin habilidades)
PMC.attribPerk = {fue = "fuerza", res = "resistencia", sal = "aguante", pun = "mantenimiento"}

-- Helix: puntos que se pueden repartir en la creación
function PLUGIN:GetDefaultAttributePoints(client, count)
	return PMC.attribPoints
end

-- Se llama desde CanPlayerCreateCharacter (sv_plugin.lua) para los bandos PMC.
-- Limpia el payload en el sitio y guarda lo validado para AdjustCreationPayload,
-- que se ejecuta después de que Helix descarte los campos que no son variables.
function PMC.ValidateCreation(client, payload, sideKey)
	local attributes, fault = PMC.ValidateAttributes(payload.attributes)
	if (!attributes) then return false, fault end

	local look
	look, fault = PMC.ValidateLook(sideKey, payload.efgLook)
	if (!look) then return false, fault end

	local role = PMC.roleByID[tostring(payload.efgRole or "")]
	if (!role) then return false, "efgInvalidRole" end

	local face = tonumber(payload.efgFace)

	payload.attributes = attributes
	payload.chosenSkin = look.skin
	payload.chosenBodygroups = {[PMC.BG_HEAD] = face - 1, [PMC.BG_TOP] = look.top, [PMC.BG_LEGS] = look.legs}

	client.efgPendingPMC = {
		side = sideKey,
		look = look,
		role = role.id,
		kit = PMC.BuildKit(role.id, sideKey, attributes),
		groups = payload.chosenBodygroups,
	}
end

function PLUGIN:AdjustCreationPayload(client, payload, newPayload)
	local pending = client.efgPendingPMC
	client.efgPendingPMC = nil

	if (!pending or PMC.GetSideKey(payload.faction) != pending.side) then return end

	newPayload.data = table.Merge(newPayload.data or payload.data or {}, {
		groups = pending.groups,
		skin = pending.look.skin,
		efgCosmetic = pending.look.cosmetics,
		efgRole = pending.role,
		efgKit = pending.kit,
	})
end

-- equipo del rol y niveles de habilidad de los atributos
function PMC.GrantStart(client, character)
	local kit = character:GetData("efgKit")
	if (!kit) then return end

	character:SetData("efgKit", nil)

	local inventory = character:GetInventory()

	for _, entry in ipairs(kit) do
		local id, amount = entry[1], math.Clamp(tonumber(entry[2]) or 1, 1, 10)

		if (ix.item.list[id]) then
			for _ = 1, amount do
				local ok = inventory:Add(id)

				-- sin hueco en el inventario: al suelo, junto al jugador
				if (!ok and IsValid(client)) then
					ix.item.Spawn(id, client:GetPos() + Vector(0, 0, 16))
				end
			end
		end
	end

	if (character.SetPerkXP and ix.perks) then
		for key, perk in pairs(PMC.attribPerk) do
			local points = character:GetAttribute(key, 0)

			if (points > 0) then
				character:SetPerkXP(perk, ix.perks.GetXPForLevel(1 + points * PMC.levelsPerPoint))
			end
		end
	end
end

-- ─── Accesorios visibles ─────────────────────────────────────────────────────
-- netvar efgCosmetic = {id = opción}. Un objeto equipado en el mismo hueco
-- (casco, máscara, gafas, auriculares) oculta el accesorio estético.
local function equippedSlots(character)
	local slots = {}
	local inventory = ix.GetEquipInventory and ix.GetEquipInventory(character)

	if (inventory) then
		for _, item in pairs(inventory:GetItems(true)) do
			local kind = ix.GetEquipSlotKind and ix.GetEquipSlotKind(item) or item.efgSlot
			if (kind) then slots[kind] = true end
		end
	end

	return slots
end

function PMC.SyncCosmetic(client)
	local character = client:GetCharacter()
	local chosen = character and PMC.GetSideKey(character:GetFaction()) and character:GetData("efgCosmetic")
	local list

	if (istable(chosen) and client:Alive()) then
		local slots = equippedSlots(character)

		for _, info in ipairs(PMC.cosmetics) do
			local option = tonumber(chosen[info.id])

			if (option and option > 0 and !slots[info.slot] and PMC.HasCosmetic(info.id, option)) then
				list = list or {}
				list[info.id] = option
			end
		end
	end

	local sig = list and util.TableToJSON(list) or ""

	if (client.efgCosmeticSig != sig) then
		client.efgCosmeticSig = sig
		client:SetNetVar("efgCosmetic", list)
	end
end

local nextCosmetic = 0

function PLUGIN:Think()
	if (nextCosmetic > CurTime()) then return end
	nextCosmetic = CurTime() + 1

	for _, client in player.Iterator() do
		if (client:GetCharacter()) then PMC.SyncCosmetic(client) end
	end
end

function PLUGIN:OnPlayerCorpseCreated(client, entity)
	entity:SetNetVar("efgCosmetic", client:GetNetVar("efgCosmetic"))
end

-- ─── Cambio de atuendo desde la pestaña PERSONAJE ────────────────────────────
-- chaqueta, pantalón y los accesorios en el orden de PMC.cosmetics
net.Receive("ixEFGPMCLook", function(_, client)
	if ((client.efgNextLook or 0) > CurTime()) then return end
	client.efgNextLook = CurTime() + 1

	local top, legs = net.ReadUInt(8), net.ReadUInt(8)
	local cosmetics = {}

	for _, info in ipairs(PMC.cosmetics) do
		cosmetics[info.id] = net.ReadUInt(8)
	end

	local character = client:GetCharacter()
	local sideKey = character and PMC.GetSideKey(character:GetFaction())
	if (!sideKey) then return end

	if (client.InRaid and client:InRaid()) then
		client:Notify("No puedes cambiarte de ropa en plena raid.")
		return
	end

	local look = PMC.ValidateLook(sideKey, {top = top, legs = legs, skin = character:GetData("skin", 0), cosmetics = cosmetics})

	if (!look) then
		client:NotifyLocalized("efgInvalidLook")
		return
	end

	local groups = character:GetData("groups", {})
	groups[PMC.BG_TOP] = look.top
	groups[PMC.BG_LEGS] = look.legs
	character:SetData("groups", groups)
	character:SetData("efgCosmetic", look.cosmetics)

	-- menu_ui vuelve a aplicar chosenBodygroups al cargar el personaje
	if (character.SetChosenBodygroups) then
		local chosen = {}
		for id, value in pairs(groups) do chosen[tonumber(id) or id] = value end
		character:SetChosenBodygroups(pon.encode(chosen))
	end

	client:SetBodygroup(PMC.BG_TOP, look.top)
	client:SetBodygroup(PMC.BG_LEGS, look.legs)
	PMC.SyncCosmetic(client)
end)
