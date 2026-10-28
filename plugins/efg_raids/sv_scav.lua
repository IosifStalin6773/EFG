local PLUGIN = PLUGIN

-- ─── Scav run ────────────────────────────────────────────────────────────────
-- El Scav usa el mismo personaje: al desplegar, todo lo que lleva el PMC se
-- guarda en un inventario oculto ("efg_scavhold"), el personaje pasa a la
-- facción Scav y recibe equipo aleatorio. Al acabar:
--   · si extrae, lo que lleva el Scav va al stash y el PMC recupera su equipo;
--   · si muere, el botín se queda en su cadáver y el PMC recupera su equipo al reaparecer.

ix.inventory.Register("efg_scavhold", 12, 20)

-- Equipo aleatorio del Scav: {uniqueID, probabilidad 0-1, cantidad}
-- Solo se entregan los ítems que existan (ix.item.list), así se puede ampliar sin miedo.
PLUGIN.scavKit = {
	weapons = {
		"arc9_eft_ak74", "arc9_eft_aks74u", "arc9_eft_mr133", "arc9_eft_mr43", "arc9_eft_toz106",
		"arc9_eft_pm", "arc9_eft_tt33", "arc9_eft_vpo136", "arc9_eft_sks", "arc9_eft_mosin_infantry",
		"arc9_eft_kedr", "arc9_eft_ppsh41"
	},
	gear = {
		{"venda_militar", 0.8, 1}, {"ai2", 0.5, 1}, {"analgin", 0.2, 1}, {"water", 0.6, 1},
		{"canned", 0.5, 1}, {"bread", 0.3, 1}, {"flashlight", 0.4, 1},
		{"armor_paca", 0.15, 1}, {"armor_6b2", 0.1, 1}, {"helmet_ssh68", 0.2, 1}, {"bp_scav", 0.4, 1}
	},
	ammo = {"ammo_pistol", "ammo_ar2", "ammo_buckshot", "ammo_smg1"},
	melee = {"arc9_eft_melee_6x5", "arc9_eft_melee_mpl50", "arc9_eft_melee_crowbar", "arc9_eft_melee_sp8"}
}

local function itemExists(uniqueID)
	return ix.item.list[uniqueID] != nil
end

-- crea o restaura el inventario donde se guarda el equipo del PMC
function PLUGIN:EnsureScavHold(client, character, callback)
	local id = character:GetData("efgScavHoldID")

	local function setup(inventory)
		-- Helix marca como bolsa todo inventario con tipo al restaurarlo; si se
		-- quedara así, las mochilas y el contenedor seguro no podrían entrar
		inventory.vars.isEFGHold = true
		inventory.vars.isBag = nil
		inventory:SetOwner(character:GetID(), true)

		if (callback) then callback(inventory) end
	end

	if (id and ix.item.inventories[id]) then
		setup(ix.item.inventories[id])
		return
	end

	if (id) then
		ix.inventory.Restore(id, 12, 20, setup)
	else
		ix.inventory.New(character:GetID(), "efg_scavhold", function(inventory)
			character:SetData("efgScavHoldID", inventory:GetID())
			setup(inventory)
		end)
	end
end

-- el inventario oculto no se puede usar desde la interfaz
function PLUGIN:CanTransferItem(item, oldInv, newInv)
	if (item._efgScavMove) then return end

	if ((newInv and newInv.vars and newInv.vars.isEFGHold) or (oldInv and oldInv.vars and oldInv.vars.isEFGHold)) then
		return false
	end
end

local function transfer(item, inventory, x, y)
	item._efgScavMove = true
	item._ixEquipMove = true -- deja entrar/salir del inventario de equipo (ix_invkey)
	local ok, result = pcall(item.Transfer, item, inventory:GetID(), x, y)
	item._efgScavMove = nil
	item._ixEquipMove = nil

	return ok and result != false
end

function PLUGIN:BeginScav(client, character)
	local hold = ix.item.inventories[character:GetData("efgScavHoldID") or -1]
	local mainInv = character:GetInventory()

	if (!hold or !mainInv) then
		self:EnsureScavHold(client, character)
		return false
	end

	hold.vars.isEFGHold = true
	hold.vars.isBag = nil

	-- 1. guardar todo el equipo del PMC (incluido el contenedor seguro)
	local equipped = {}

	for _, item in ipairs(self:GetCarriedItems(character, true)) do
		local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

		if (eqInv and item.invID == eqInv:GetID()) then
			equipped[#equipped + 1] = item.id
		elseif (item:GetData("equip")) then
			equipped[#equipped + 1] = item.id
		end

		item.player = client
		self:UnequipItem(client, item)
		item.player = nil

		if (!transfer(item, hold)) then
			ErrorNoHalt("[EFG] No se pudo guardar el ítem " .. item.uniqueID .. " del PMC antes del Scav run\n")
		end
	end

	character:SetData("efgScavEquipped", equipped)

	-- 2. cambiar a la facción Scav conservando la original
	character:SetData("efgScavOrig", {
		faction = ix.faction.indices[character:GetFaction()].uniqueID,
		model = character:GetModel()
	})

	local scavFaction = ix.faction.indices[FACTION_SCAV]

	character:SetFaction(FACTION_SCAV)
	client:SetTeam(FACTION_SCAV)

	if (scavFaction and scavFaction.models and #scavFaction.models > 0) then
		character:SetModel(scavFaction.models[math.random(#scavFaction.models)])
	end

	-- 3. equipo aleatorio
	self:GiveScavKit(client, character)

	return true
end

function PLUGIN:GiveScavKit(client, character)
	local inventory = character:GetInventory()
	local kit = self.scavKit

	local weapons = {}

	for _, uniqueID in ipairs(kit.weapons) do
		if (itemExists(uniqueID)) then
			weapons[#weapons + 1] = uniqueID
		end
	end

	local weaponAmmo

	if (#weapons > 0) then
		local uniqueID = weapons[math.random(#weapons)]
		inventory:Add(uniqueID)

		local ammoType = ix.item.list[uniqueID].ammoType
		weaponAmmo = ammoType and itemExists("ammo_" .. ammoType) and ("ammo_" .. ammoType) or nil
	end

	local melee = {}

	for _, uniqueID in ipairs(kit.melee) do
		if (itemExists(uniqueID)) then
			melee[#melee + 1] = uniqueID
		end
	end

	if (#melee > 0) then
		inventory:Add(melee[math.random(#melee)])
	end

	for _, entry in ipairs(kit.gear) do
		if (itemExists(entry[1]) and math.random() <= entry[2]) then
			inventory:Add(entry[1], entry[3])
		end
	end

	local ammo = {}

	for _, uniqueID in ipairs(kit.ammo) do
		if (itemExists(uniqueID)) then
			ammo[#ammo + 1] = uniqueID
		end
	end

	if (weaponAmmo) then
		inventory:Add(weaponAmmo, math.random(1, 3))
	elseif (#ammo > 0) then
		inventory:Add(ammo[math.random(#ammo)], math.random(1, 3))
	end

	if (itemExists("bala")) then
		inventory:Add("bala", 1, {count = math.random(1, 20) * 500})
	end
end

-- survived = true si extrajo: el botín del Scav pasa al stash
function PLUGIN:EndScav(client, character, survived)
	if (!character:GetData("efgScavOrig")) then return end

	if (survived) then
		local stash = ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character)
		local leftovers = 0

		for _, item in ipairs(self:GetCarriedItems(character, true)) do
			item.player = client
			self:UnequipItem(client, item)
			item.player = nil

			if (!stash or !transfer(item, stash)) then
				leftovers = leftovers + 1
				item:Remove()
			end
		end

		if (leftovers > 0) then
			client:Notify(("Tu stash está lleno: se han perdido %d objetos del Scav."):format(leftovers))
		else
			client:Notify("El botín de tu Scav está en tu stash.")
		end
	end

	-- si el jugador está muerto, se espera a que reaparezca: el botín debe quedarse
	-- en el cadáver antes de devolverle su equipo de PMC
	if (client:Alive()) then
		self:RestorePMC(client, character)
	else
		character:SetData("efgScavRestore", true)
	end
end

function PLUGIN:RestorePMC(client, character)
	local orig = character:GetData("efgScavOrig")
	if (!orig) then return end

	-- lo que quede del Scav (por ejemplo, tras una desconexión) desaparece
	for _, item in ipairs(self:GetCarriedItems(character)) do
		if (!table.HasValue(character:GetData("efgScavEquipped", {}), item.id)) then
			item.player = client
			self:UnequipItem(client, item)
			item.player = nil
			item:Remove()
		end
	end

	local faction = ix.faction.teams[orig.faction]

	if (faction) then
		character:SetFaction(faction.index)
		client:SetTeam(faction.index)
	end

	if (orig.model) then
		character:SetModel(orig.model)
	end

	local hold = ix.item.inventories[character:GetData("efgScavHoldID") or -1]
	local mainInv = character:GetInventory()
	local equipped = character:GetData("efgScavEquipped", {})

	if (hold and mainInv) then
		for _, slot in pairs(hold.slots) do
			for _, item in pairs(slot) do
				if (!transfer(item, mainInv)) then
					local stash = ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character)

					if (!stash or !transfer(item, stash)) then
						ErrorNoHalt("[EFG] No cabe el ítem " .. item.uniqueID .. " al volver del Scav run; se queda guardado\n")
					end
				end
			end
		end

		-- volver a equipar uniforme y mochila
		local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

		for _, itemID in ipairs(equipped) do
			local item = ix.item.instances[itemID]

			if (item and item.invID == mainInv:GetID()) then
				item.player = client

				if (eqInv and ix.GetEquipSlotKind and ix.GetEquipSlotKind(item)) then
					if (item.outfitCategory and item.functions.Equip and item.functions.Equip.OnRun) then
						item.functions.Equip.OnRun(item)
					end

					transfer(item, eqInv)
				elseif (item.Equip) then
					item:Equip(client)
				end

				item.player = nil
			end
		end
	end

	character:SetData("efgScavOrig", nil)
	character:SetData("efgScavEquipped", nil)
	character:SetData("efgScavRestore", nil)
end

function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()
	if (!IsValid(client)) then return end

	timer.Simple(0.75, function()
		if (IsValid(client) and client:GetCharacter() == character) then
			self:EnsureScavHold(client, character, function()
				-- quedó a medias (por ejemplo, caída del servidor tras morir como Scav)
				if (character:GetData("efgScavRestore") and !character:GetData("efgInRaid")) then
					self:RestorePMC(client, character)
				end
			end)

			if (ix.strongbox and ix.strongbox.EnsureStash) then
				ix.strongbox.EnsureStash(character)
			end
		end
	end)
end

function PLUGIN:PlayerSpawn(client)
	local character = client:GetCharacter()

	if (character and character:GetData("efgScavRestore")) then
		timer.Simple(0.5, function()
			if (IsValid(client) and client:GetCharacter() == character and client:Alive()) then
				self:RestorePMC(client, character)
			end
		end)
	end
end
