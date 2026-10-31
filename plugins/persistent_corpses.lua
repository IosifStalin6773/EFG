
local PLUGIN = PLUGIN

PLUGIN.name = "Persistent Corpses"
PLUGIN.author = "`impulse"
PLUGIN.description = "Makes player corpses stay on the map after the player has respawned."
PLUGIN.license = [[
Copyright 2018 - 2020 Igor Radovanovic
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
PLUGIN.readme = [[
Makes player corpses stay on the map after the player has respawned. Items can also be set to drop into the ragdoll's inventory
upon death.
## Enabling drops
To allow items to be put into a corpse's inventory when a player dies, you must set the `dropItemsOnDeath` config to `true`,
and then add `ITEM.bDropOnDeath = true` to any item that you want to be placed into the inventory.
]]

PLUGIN.hardCorpseMax = 64

ix.lang.AddTable("english", {
	searchingCorpse = "Searching corpse..."
})

ix.config.Add("persistentCorpses", true, "Whether or not corpses remain on the map after a player dies and respawns.", nil, {
	category = "Persistent Corpses"
})

ix.config.Add("corpseMax", 8, "Maximum number of corpses that are allowed to be spawned.", nil, {
	data = {min = 0, max = PLUGIN.hardCorpseMax},
	category = "Persistent Corpses"
})

ix.config.Add("corpseDecayTime", 180, "How long it takes for a corpse to decay in seconds. Set to 0 to never decay.", nil, {
	data = {min = 0, max = 1800},
	category = "Persistent Corpses"
})

ix.config.Add("corpseSearchTime", 1, "How long it takes to search a corpse.", nil, {
	data = {min = 0, max = 60},
	category = "Persistent Corpses"
})

ix.config.Add("dropItemsOnDeath", true, "Whether or not to drop specific items on death.", nil, {
	category = "Persistent Corpses"
})

if (SERVER) then
	util.AddNetworkString("ixCorpseSearchSnd")

	PLUGIN.corpses = {}

	-- IDs únicos para los inventarios de cadáver (noSave). Deben ser positivos: Helix
	-- los envía con net.WriteUInt(id, 32), y un negativo rompe el saqueo. Empiezan muy
	-- por encima de los IDs de la BD para no chocar con ellos.
	local CORPSE_INV_BASE = 3000000000
	local corpseInvCounter = 0

	function ix.NextCorpseInventoryID()
		corpseInvCounter = corpseInvCounter + 1
		return CORPSE_INV_BASE + corpseInvCounter
	end

	-- disable the regular hl2 ragdolls
	function PLUGIN:ShouldSpawnClientRagdoll(client)
		return false
	end

	function PLUGIN:PlayerSpawn(client)
		client:SetLocalVar("ragdoll", nil)
	end

	function PLUGIN:ShouldRemoveRagdollOnDeath(client)
		return false
	end

	function PLUGIN:PlayerInitialSpawn(client)
		self:CleanupCorpses()
	end

	function PLUGIN:CleanupCorpses(maxCorpses)
		maxCorpses = maxCorpses or ix.config.Get("corpseMax", 8)
		local toRemove = {}

		if (#self.corpses > maxCorpses) then
			for k, v in ipairs(self.corpses) do
				if (!IsValid(v)) then
					toRemove[#toRemove + 1] = k
				elseif (#self.corpses - #toRemove > maxCorpses) then
					v:Remove()
					toRemove[#toRemove + 1] = k
				end
			end
		end

		for k, _ in ipairs(toRemove) do
			table.remove(self.corpses, k)
		end
	end

	-- si se desconecta mientras está saqueando un cadáver, ix.storage nunca recibe el
	-- "ixStorageClose": la inventory queda con storageInfo activo y ix.storage.InUse
	-- seguiría contando a este jugador como receptor hasta que GetReceivers lo filtre,
	-- pero mientras tanto bloquea a los demás si bMultipleUsers no está activo.
	function PLUGIN:PlayerDisconnected(client)
		local inventory = client.ixOpenStorage

		if (inventory) then
			ix.storage.RemoveReceiver(client, inventory)
		end
	end

	function PLUGIN:RemoveEquippableItem(client, item)
		if (item.Unequip) then
			item:Unequip(client)
		elseif (item.RemoveOutfit) then
			item:RemoveOutfit(client)
		elseif (item.RemovePart) then
			item:RemovePart(client)
		end
	end

	function PLUGIN:DoPlayerDeath(client, attacker, damageinfo)
		if (!ix.config.Get("persistentCorpses", true)) then
			return
		end

		if (hook.Run("ShouldSpawnPlayerCorpse", client) == false) then
			return
		end

		-- remove old corpse if we've hit the limit
		local maxCorpses = ix.config.Get("corpseMax", 8)

		if (maxCorpses == 0) then
			return
		end

		local entity = IsValid(client.ixRagdoll) and client.ixRagdoll or client:CreateServerRagdoll()
		local decayTime = ix.config.Get("corpseDecayTime", 60)
		local uniqueID = "ixCorpseDecay" .. entity:EntIndex()

		entity:RemoveCallOnRemove("fixer")
		entity:CallOnRemove("ixPersistentCorpse", function(ragdoll)
			if (ragdoll.ixInventory) then
				ix.storage.Close(ragdoll.ixInventory)

				-- Eliminar de la BD los ítems que nadie saqueó del cadáver.
				-- Se hace por SQL directo (no item:Remove), así que hay que limpiar a
				-- mano el sub-inventario de las mochilas: si no, su contenido queda
				-- huérfano en la BD (ahora las mochilas siempre caen al cadáver).
				local processed = {}

				for _, slot in pairs(ragdoll.ixInventory.slots or {}) do
					for _, item in pairs(slot) do
						if (item and item.id and not processed[item.id]) then
							processed[item.id] = true

							-- mochila: borrar su sub-inventario y los ítems de dentro
							local bagInvID = item.GetData and item:GetData("id")
							if (bagInvID) then
								local bagInv = ix.item.inventories[bagInvID]

								if (bagInv and bagInv.slots) then
									for _, bagSlot in pairs(bagInv.slots) do
										for _, bagItem in pairs(bagSlot) do
											if (bagItem and bagItem.id) then
												ix.item.instances[bagItem.id] = nil
											end
										end
									end
								end

								local q = mysql:Delete("ix_items")
									q:Where("inventory_id", bagInvID)
								q:Execute()

								q = mysql:Delete("ix_inventories")
									q:Where("inventory_id", bagInvID)
								q:Execute()

								ix.item.inventories[bagInvID] = nil
							end

							local query = mysql:Delete("ix_items")
								query:Where("item_id", item.id)
							query:Execute()

							ix.item.instances[item.id] = nil
						end
					end
				end
			end

			if (IsValid(client) and !client:Alive()) then
				client:SetLocalVar("ragdoll", nil)
			end

			local index

			for k, v in ipairs(PLUGIN.corpses) do
				if (v == ragdoll) then
					index = k
					break
				end
			end

			if (index) then
				table.remove(PLUGIN.corpses, index)
			end

			if (timer.Exists(uniqueID)) then
				timer.Remove(uniqueID)
			end
		end)

		-- start decay process only if we have a time set
		if (decayTime > 0) then
			timer.Create(uniqueID, decayTime, 1, function()
				if (IsValid(entity)) then
					entity:Remove()
				else
					timer.Remove(uniqueID)
				end
			end)
		end

		-- remove reference to ragdoll so it isn't removed on spawn when SetRagdolled is called
		client.ixRagdoll = nil
		-- remove reference to the player so no more damage can be dealt
		entity.ixPlayer = nil

		-- Sello de dueño/hora de muerte para el bloqueo de auto-loot (ver PlayerUse):
		-- por SteamID64, no por entidad, para que siga funcionando aunque el jugador
		-- se reconecte dentro de la ventana de bloqueo.
		entity.ixCorpseOwnerSID = client:SteamID64()
		entity.ixCorpseDeathTime = CurTime()

		self.corpses[#self.corpses + 1] = entity

		-- clean up old corpses after we've added this one
		if (#self.corpses >= maxCorpses) then
			self:CleanupCorpses(maxCorpses)
		end

		hook.Run("OnPlayerCorpseCreated", client, entity)
	end

	function PLUGIN:OnPlayerCorpseCreated(client, entity)
		if (!ix.config.Get("dropItemsOnDeath", false) or !client:GetCharacter()) then
			return
		end

		client:SetLocalVar("ragdoll", entity:EntIndex())

		local character = client:GetCharacter()
		local charInventory = character:GetInventory()
		local width, height = charInventory:GetSize()

		-- +2 filas extra: loot_on_death también vuelca el inventario de equipo
		-- (uniforme/mochila) al cadáver; sin margen no cabrían si el inv principal
		-- está lleno y se quedarían sin lootear.
		local inventory = ix.inventory.Create(width, height + 2, ix.NextCorpseInventoryID())
		inventory.noSave = true

		if (ix.config.Get("dropItemsOnDeath")) then
			for _, slot in pairs(charInventory.slots) do
				for _, item in pairs(slot) do
					if (item.bDropOnDeath) then
						if (item:GetData("equip")) then
							self:RemoveEquippableItem(client, item)
						end

						item:Transfer(inventory:GetID(), item.gridX, item.gridY)

						-- noSave impide el UPDATE en la BD; sin esto, el ítem
						-- reaparece en el inventario del personaje al reconectar.
						local query = mysql:Update("ix_items")
							query:Update("inventory_id", 0)
							query:Where("item_id", item.id)
						query:Execute()
					end
				end
			end
		end

		entity.ixInventory = inventory
	end

	local SEARCH_SOUND = "metrorp/search_body.wav"
	local SELF_LOOT_LOCK_TIME = 600 -- 10 minutos

	function PLUGIN:PlayerUse(client, entity)
		if (entity:GetClass() != "prop_ragdoll" or !entity.ixInventory) then return end

		-- Bloquea que un jugador se looteé su propio cadáver recién muerto (evita
		-- morir y volver corriendo a por el botín al instante). Cualquier rango
		-- que no sea el estándar ("user") queda exento.
		if (entity.ixCorpseOwnerSID == client:SteamID64() and client:GetUserGroup() == "user") then
			local elapsed = CurTime() - (entity.ixCorpseDeathTime or 0)

			if (elapsed < SELF_LOOT_LOCK_TIME) then
				local remaining = math.ceil((SELF_LOOT_LOCK_TIME - elapsed) / 60)
				client:Notify("No puedes lootear tu propio cadáver todavía. Espera " .. remaining .. " min más.")
				return false
			end
		end

		local inventory = entity.ixInventory

		-- el motor llama PlayerUse en cada tick mientras se mantiene pulsado USAR, no
		-- solo una vez. Antes se usaba `client.ixOpenStorage == inventory` como candado
		-- para no relanzar la búsqueda, pero ese valor puede quedar OBSOLETO: si el panel
		-- se cierra sin mandar "ixStorageClose" (al morir mirando el cadáver, cambiar de
		-- menú, etc.) el receptor queda colgado, el candado nunca se libera y el cadáver
		-- se vuelve imposible de reabrir → "no se puede lootear una vez abierto".
		-- En su lugar, debounce por cadáver: se refresca mientras se mantiene pulsado y
		-- expira poco después de soltar, sin depender de estado que pueda quedar sucio.
		local now = CurTime()

		if (client.ixCorpseSearchEnt == entity and (client.ixCorpseSearchCD or 0) > now) then
			client.ixCorpseSearchCD = now + 0.5
			return false
		end

		local searchTime = ix.config.Get("corpseSearchTime", 1)
		client.ixCorpseSearchEnt = entity
		client.ixCorpseSearchCD = now + math.max(searchTime, 0.5) + 0.5

		-- si venía de otro cadáver/taquilla abierto sin cerrar (cambió de uno a otro sin
		-- pulsar CERRAR), cerrarlo antes: si no, se queda "en uso" para siempre.
		ix.storage.CloseCurrent(client, inventory)

		-- El cadáver es de UN SOLO saqueador a la vez. El problema del candado clásico
		-- (ix.storage.InUse) es que un receptor puede quedar COLGADO si el panel se cerró
		-- sin avisar al servidor, bloqueando el cuerpo para siempre. Para evitarlo,
		-- validamos al ocupante actual: si ya no está en condiciones de saquear
		-- (desconectado, muerto o lejos del cuerpo) liberamos su candado en vez de
		-- bloquear. Solo si sigue habiendo un ocupante legítimo se avisa "en uso".
		if (!ix.storage.InUseBy(inventory, client)) then
			local occupied = false

			for _, receiver in ipairs(inventory:GetReceivers()) do
				if (!IsValid(receiver) or !receiver:IsPlayer()) then continue end

				if (receiver:Alive() and receiver:GetPos():DistToSqr(entity:GetPos()) <= (200 * 200)) then
					occupied = true
				else
					ix.storage.RemoveReceiver(receiver, inventory)
				end
			end

			if (occupied) then
				client:NotifyLocalized("storageInUse")
				return false
			end
		end

		if (!inventory.storageInfo) then
			ix.storage.CreateContext(inventory, {
				entity = entity,
				name = "Cadaver",
				searchText = "Buscando...",
				searchTime = searchTime
			})
		end

		ix.storage.AddReceiver(client, inventory, true)

		client:EmitSound(SEARCH_SOUND, 75, 100, 1)

		net.Start("ixCorpseSearchSnd")
			net.WriteBool(true)
		net.Send(client)

		client:SetAction("Buscando...", searchTime)
		client:DoStaredAction(entity, function()
			if (IsValid(client)) then
				client:StopSound(SEARCH_SOUND)
				net.Start("ixCorpseSearchSnd")
					net.WriteBool(false)
				net.Send(client)
			end

			if (IsValid(client) and IsValid(entity) and inventory.storageInfo) then
				ix.storage.Sync(client, inventory)
			end
		end, searchTime, function()
			if (IsValid(client)) then
				client:StopSound(SEARCH_SOUND)
				net.Start("ixCorpseSearchSnd")
					net.WriteBool(false)
				net.Send(client)
				ix.storage.RemoveReceiver(client, inventory)
				client:SetAction()
			end
		end)

		return false
	end
end

if (CLIENT) then
	local _searchSnd = nil

	net.Receive("ixCorpseSearchSnd", function()
		if (net.ReadBool()) then
			if (_searchSnd) then _searchSnd:Stop() end
			_searchSnd = CreateSound(LocalPlayer(), "metrorp/search_body.wav")
			_searchSnd:PlayEx(1, 100)
		elseif (_searchSnd) then
			_searchSnd:Stop()
			_searchSnd = nil
		end
	end)
end