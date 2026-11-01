
-- Here is where all of your serverside hooks should go.

-- ============================================================================
-- DEBUG ARMAS v3 — Instrumentación máxima para encontrar la causa raíz.
--
-- Registra SOLO a data/efg_weapondebug.txt (no consola).
-- Detours: StripWeapons, StripWeapon, Weapon:Remove(), Player:Give()
-- Captura: traceback, edict count, lista de armas, estado del jugador,
--          hook activo, y correlaciona Remove→INCIDENTE.
-- ============================================================================
do
	local LOGFILE = "efg_weapondebug.txt"
	local watched = {
		["ix_hands"] = true,
		["ix_keys"]  = true,
	}

	local function WeaponLog(line)
		file.Append(LOGFILE, os.date("[%Y-%m-%d %H:%M:%S] ") .. line .. "\n")
	end

	-- ── Helpers de diagnóstico ─────────────────────────────────────────
	local function GetEdictInfo()
		local count = ents.GetCount and ents.GetCount() or #ents.GetAll()
		return "edicts=" .. count .. "/8192"
	end

	local function GetCurrentHookName()
		for level = 3, 15 do
			local info = debug.getinfo(level, "Sl")
			if (!info) then break end
			if (info.short_src and info.short_src:find("hook%.lua")) then
				local name, val = debug.getlocal(level, 1)
				if (val and isstring(val)) then return val end
			end
		end
		return "?"
	end

	local function GetPlayerState(ply)
		local parts = {}
		parts[#parts + 1] = "alive=" .. tostring(ply:Alive())
		parts[#parts + 1] = "moveType=" .. tostring(ply:GetMoveType())
		parts[#parts + 1] = "inVehicle=" .. tostring(ply:InVehicle())
		parts[#parts + 1] = "ragdoll=" .. tostring(IsValid(ply.ixRagdoll))
		parts[#parts + 1] = "inLoadout=" .. tostring(ply.ixInLoadout or false)
		parts[#parts + 1] = "hasChar=" .. tostring(ply:GetCharacter() != nil)
		parts[#parts + 1] = "team=" .. tostring(ply:Team())
		return table.concat(parts, ", ")
	end

	local function GetWeaponList(ply)
		local weps = {}
		for _, wep in ipairs(ply:GetWeapons()) do
			if (IsValid(wep)) then
				weps[#weps + 1] = wep:GetClass()
			end
		end
		if (#weps == 0) then return "(ninguna)" end
		return table.concat(weps, ", ")
	end

	-- ── Contexto de eliminación ────────────────────────────────────────
	-- Guarda el traceback del último Remove/StripWeapon/Give sobre armas
	-- vigiladas, para correlacionarlo con el INCIDENTE 0.5s después.
	-- Key: steamid_class  Value: {time, trace, method}
	local removalCtx = {}

	local function SaveRemovalContext(ply, class, method, trace)
		removalCtx[ply:SteamID() .. "_" .. class] = {
			time   = CurTime(),
			trace  = trace,
			method = method,
		}
	end

	local function PopRemovalContext(ply, class)
		local key = ply:SteamID() .. "_" .. class
		local ctx = removalCtx[key]
		if (ctx and CurTime() - ctx.time < 5) then
			removalCtx[key] = nil
			return ctx
		end
		removalCtx[key] = nil
		return nil
	end

	-- ── EntityRemoved — detección de pérdida ───────────────────────────
	hook.Add("EntityRemoved", "ixWeaponGoneDebug", function(entity)
		if (!IsValid(entity) or !entity:IsWeapon()) then return end
		local class = entity:GetClass()
		if (!watched[class]) then return end

		local owner = entity:GetOwner()
		if (!IsValid(owner) or !owner:IsPlayer()) then return end
		if (!owner:Alive() or !owner:GetCharacter()) then return end

		local spawnTag    = owner.ixSpawnCount or 0
		local traceER     = debug.traceback("", 2)
		local hookName    = GetCurrentHookName()
		local edictSnap   = GetEdictInfo()
		local stateSnap   = GetPlayerState(owner)
		local wepListSnap = GetWeaponList(owner)
		local entIdx      = entity:EntIndex()
		local nick        = owner:Nick()
		local sid         = owner:SteamID()

		timer.Simple(0.5, function()
			if (!IsValid(owner) or !owner:Alive()) then return end
			if ((owner.ixSpawnCount or 0) != spawnTag) then return end
			if (IsValid(owner.ixRagdoll)) then return end
			if (owner:HasWeapon(class)) then return end

			local ctx = PopRemovalContext(owner, class)

			WeaponLog("═══ INCIDENTE ═══════════════════════════════════════")
			WeaponLog("  Jugador: " .. nick .. " (" .. sid .. ")")
			WeaponLog("  Arma perdida: '" .. class .. "' (entIdx=" .. entIdx .. ")")
			WeaponLog("  " .. edictSnap)
			WeaponLog("  Estado al perderla: " .. stateSnap)
			WeaponLog("  Armas al perderla: " .. wepListSnap)
			WeaponLog("  Hook activo al perderla: " .. hookName)
			WeaponLog("  Armas ahora (T+0.5s): " .. GetWeaponList(owner))
			WeaponLog("  " .. GetEdictInfo() .. " (ahora)")
			WeaponLog("  EntityRemoved traceback:\n" .. traceER)

			if (ctx) then
				WeaponLog("  ┌─ CONTEXTO PREVIO (" .. ctx.method .. " hace " ..
					string.format("%.2f", CurTime() - ctx.time) .. "s):")
				WeaponLog("  └─ " .. ctx.trace)
			else
				WeaponLog("  ⚠ SIN CONTEXTO — ni Remove(), ni StripWeapon(), ni Give() dispararon el detour.")
				WeaponLog("    La eliminación fue engine-side (C++) sin pasar por Lua.")
			end

			WeaponLog("═════════════════════════════════════════════════════")

			owner:Give(class)
			WeaponLog("  -> restaurado '" .. class .. "' a " .. nick)
		end)
	end)

	-- ── Detour: Weapon:Remove() ────────────────────────────────────────
	-- Captura llamadas directas a entity:Remove() sobre armas vigiladas.
	-- Solo se aplica a la metatabla Weapon (no a todas las entidades).
	local WEAPON_META = FindMetaTable("Weapon")
	local ENTITY_META = FindMetaTable("Entity")

	if (!WEAPON_META.ixOrigRemove) then
		WEAPON_META.ixOrigRemove = WEAPON_META.Remove or ENTITY_META.Remove
	end

	WEAPON_META.Remove = function(self, ...)
		if (IsValid(self) and watched[self:GetClass()]) then
			local owner = self:GetOwner()
			if (IsValid(owner) and owner:IsPlayer() and owner:Alive()) then
				local trace = debug.traceback("", 2)
				WeaponLog("Weapon:Remove() sobre '" .. self:GetClass() .. "' de " ..
					owner:Nick() .. " (" .. owner:SteamID() .. ")" ..
					" hook=" .. GetCurrentHookName() .. " " .. GetEdictInfo() ..
					"\n" .. trace)
				SaveRemovalContext(owner, self:GetClass(), "Weapon:Remove()", trace)
			end
		end

		return WEAPON_META.ixOrigRemove(self, ...)
	end

	-- ── Detour: StripWeapons / StripWeapon ──────────────────────────────
	local PLAYER = FindMetaTable("Player")

	if (!PLAYER.ixOrigStripWeapons) then
		PLAYER.ixOrigStripWeapons = PLAYER.StripWeapons
		PLAYER.ixOrigStripWeapon  = PLAYER.StripWeapon
	end

	function PLAYER:StripWeapons(...)
		if (!self.ixInLoadout and IsValid(self) and self:IsPlayer() and self:Alive() and
			self:GetCharacter() and self:HasWeapon("ix_hands")) then
			local trace = debug.traceback("", 2)
			WeaponLog("StripWeapons() ANORMAL — " .. self:Nick() .. " (" ..
				self:SteamID() .. ") hook=" .. GetCurrentHookName() ..
				" " .. GetEdictInfo() ..
				" armas=" .. GetWeaponList(self) .. "\n" .. trace)
			SaveRemovalContext(self, "ix_hands", "StripWeapons()", trace)
			SaveRemovalContext(self, "ix_keys", "StripWeapons()", trace)
		end

		return PLAYER.ixOrigStripWeapons(self, ...)
	end

	function PLAYER:StripWeapon(class, ...)
		if (watched[class] and !self.ixInLoadout and IsValid(self) and self:IsPlayer() and self:Alive()) then
			local trace = debug.traceback("", 2)
			WeaponLog("StripWeapon('" .. tostring(class) .. "') ANORMAL — " .. self:Nick() ..
				" (" .. self:SteamID() .. ") hook=" .. GetCurrentHookName() ..
				" " .. GetEdictInfo() .. "\n" .. trace)
			SaveRemovalContext(self, class, "StripWeapon()", trace)
		end

		return PLAYER.ixOrigStripWeapon(self, class, ...)
	end

	-- ── Detour: Player:Give() ──────────────────────────────────────────
	-- Registra cada Give("ix_hands"/"ix_keys") para saber si algo re-da
	-- la arma (lo cual primero elimina la existente, triggering EntityRemoved).
	if (!PLAYER.ixOrigGive) then
		PLAYER.ixOrigGive = PLAYER.Give
	end

	function PLAYER:Give(class, ...)
		if (watched[class] and IsValid(self) and self:IsPlayer()) then
			local alreadyHas = self:HasWeapon(class)
			local trace = debug.traceback("", 2)

			if (alreadyHas) then
				WeaponLog("Give('" .. class .. "') DUPLICADO — " .. self:Nick() ..
					" (" .. self:SteamID() .. ") YA TIENE esta arma. " ..
					"hook=" .. GetCurrentHookName() .. " " .. GetEdictInfo() ..
					"\n" .. trace)
				SaveRemovalContext(self, class, "Give() duplicado", trace)
			elseif (!self.ixInLoadout) then
				WeaponLog("Give('" .. class .. "') — " .. self:Nick() ..
					" (" .. self:SteamID() .. ") " ..
					"hook=" .. GetCurrentHookName() .. " " .. GetEdictInfo() ..
					"\n" .. trace)
			end
		end

		return PLAYER.ixOrigGive(self, class, ...)
	end

	-- ── Marca la ventana del loadout ────────────────────────────────────
	hook.Add("PlayerLoadout", "ixWeaponDebugLoadoutStart", function(client)
		client.ixInLoadout = true
	end)

	hook.Add("PostPlayerLoadout", "ixWeaponDebugLoadoutEnd", function(client)
		client.ixInLoadout = nil
	end)

	-- ── Protección de game.CleanUpMap ───────────────────────────────────
	if (game and game.CleanUpMap) then
		local _origCleanUpMap = game.CleanUpMap
		game.CleanUpMap = function(dontSend, extraFilters, callback)
			WeaponLog("game.CleanUpMap() LLAMADO " .. GetEdictInfo() .. "\n" .. debug.traceback("", 2))

			local protect = {}
			for _, client in ipairs(player.GetAll()) do
				for _, wep in ipairs(client:GetWeapons()) do
					if (IsValid(wep)) then
						protect[wep:GetClass()] = true
					end
				end
			end

			extraFilters = extraFilters or {}
			for cls, _ in pairs(protect) do
				extraFilters[#extraFilters + 1] = cls
			end

			return _origCleanUpMap(dontSend, extraFilters, callback)
		end
	end

	-- ── Snapshot periódico de edicts ────────────────────────────────────
	-- Cada 60s registra el edict count, así podemos correlacionar presión
	-- de entidades con los incidentes sin mirar el log en tiempo real.
	timer.Create("ixWeaponDebug_EdictPulse", 60, 0, function()
		local count = ents.GetCount and ents.GetCount() or #ents.GetAll()
		if (count > 6000) then
			WeaponLog("⚠ EDICT ALTO: " .. count .. "/8192 (" ..
				math.floor(count / 8192 * 100) .. "%)")
		end
	end)
end

-- ============================================================================
-- Bloquea el comando "strip" de SAM. Hacía StripWeapons() sobre jugadores vivos
-- y les quitaba ix_hands/ix_keys (manos y llaves), dejándolos sin poder
-- interactuar ni abrir puertas. Usamos el hook oficial de SAM para no editar el
-- addon (sobrevive a sus actualizaciones): devolver false cancela el comando.
-- ============================================================================
hook.Add("SAM.CanRunCommand", "ixEFGBlockStrip", function(ply, cmdName)
	if (cmdName != "strip") then return end

	if (IsValid(ply) and ply:IsPlayer()) then
		ply:ChatPrint("[EFG] El comando 'strip' está desactivado: dejaba a los jugadores sin manos ni llaves.")
	end

	return false
end)

-- Contador de spawns por jugador: lo usa la restauración de armas para descartar
-- los casos en los que el jugador murió/respawneó mientras estaba en ragdoll.
hook.Add("PlayerSpawn", "ixEFGSpawnCount", function(client)
	client.ixSpawnCount = (client.ixSpawnCount or 0) + 1
end)

-- NOTA: Aquí había dos mecanismos de "recuperación de armas" (un hook
-- EntityRemoved que re-equipaba y un timer de 10s) que se ELIMINARON porque
-- creaban un bucle infinito de Equip→StripWeapon→EntityRemoved→Equip. Ese churn
-- de entidades saturaba los edicts del motor y reiniciaba el servidor entero.
-- No reintroducir re-equip automático desde EntityRemoved.

-- Restaurar armas tras un ragdoll forzado (p.ej. el agarre de los demonios SNPC).
--
-- Cuando algo hace SetRagdolled(true) sobre un jugador vivo, Helix le hace
-- StripWeapons y guarda el inventario de armas en el ragdoll. Solo las devuelve si el
-- ragdoll se elimina de forma "normal" (CallOnRemove "fixer", gated por !ixIgnoreDelete).
-- El addon de demonios borra el ragdoll con ixIgnoreDelete al meterte en su nido, así
-- que la restauración nativa NUNCA corre y te quedas sin armas (CW y no-CW).
--
-- Aquí enganchamos nuestra propia restauración: si al terminar el ragdoll el jugador
-- SIGUE VIVO (no murió), reponemos lo que falte usando el mismo snapshot que Helix ya
-- construyó. Solo repone lo ausente, así que no duplica nada aunque el restore nativo
-- también haya corrido.
do
	local PLAYER = FindMetaTable("Player")
	local _origSetRagdolled = PLAYER.SetRagdolled

	PLAYER.SetRagdolled = function(self, bState, ...)
		local ret = _origSetRagdolled(self, bState, ...)

		if (bState == true and IsValid(self) and self:Alive() and self:GetCharacter() and
			IsValid(self.ixRagdoll)) then
			local client   = self
			local ragdoll  = self.ixRagdoll
			local spawnTag = client.ixSpawnCount or 0

			ragdoll:CallOnRemove("ixEFGRestoreWeapons", function()
				-- Capturar el snapshot AHORA: tras la eliminación, la entidad es NULL
				-- y sus campos Lua dejan de ser accesibles.
				local weapons     = ragdoll.ixWeapons
				local activeClass = ragdoll.ixActiveWeapon

				-- Diferir para correr después del restore nativo de Helix (si lo hubo).
				timer.Simple(0.25, function()
					if (!IsValid(client) or !client:Alive()) then return end
					-- Si murió/respawneó mientras tanto, no tocar nada (el loadout o el
					-- drop de muerte ya gestionan las armas).
					if ((client.ixSpawnCount or 0) != spawnTag) then return end

					local character = client:GetCharacter()
					if (!character) then return end
					local inv = character:GetInventory()

					if (istable(weapons)) then
						for _, v in ipairs(weapons) do
							if (v.class) then
								-- Arma "cruda" (SWEP que no es ítem de inventario).
								if (!client:HasWeapon(v.class)) then
									local weapon = client:Give(v.class, true)
									if (IsValid(weapon)) then
										if (v.item) then weapon.ixItem = v.item end
										client:SetAmmo(v.ammo, weapon:GetPrimaryAmmoType())
										weapon:SetClip1(v.clip)
									end
								end
							elseif (v.item and v.item.GetData and v.item:GetData("equip") != true) then
								-- Ítem de inventario (armas CW, etc.): solo si sigue en el
								-- mismo inventario y no está ya equipado.
								if (inv and v.invID == v.item.invID and v.item.invID == inv:GetID()) then
									v.item:Equip(client, true, true)

									local carry = client.carryWeapons and client.carryWeapons[v.item.weaponCategory]
									if (IsValid(carry)) then
										client:SetAmmo(v.ammo, carry:GetPrimaryAmmoType())
									end
								end
							end
						end
					end

					if (activeClass and client:HasWeapon(activeClass)) then
						client:SetActiveWeapon(client:GetWeapon(activeClass))
					end
				end)
			end)
		end

		return ret
	end
end

-- ============================================================================
-- FORCEJEO CONTRA EL AGARRE DE LOS DEMONIOS SNPC (QTE roto de fábrica).
--
-- El addon de demonios (entities/lima_demon_interaction.lua) resuelve el
-- escape con un contador ENT.KeyPresses que decae solo cada tick (-0.05) y
-- necesita superar 30 para soltarte (self:Remove()) — pero en TODO el addon
-- no hay ningún código que incremente ese contador al pulsar una tecla.
-- Sin esto, forcejear es matemáticamente imposible: el contador solo baja.
-- Se engancha aquí, incrementándolo al pulsar E mientras el jugador está
-- agarrado (mismo patrón que la restauración de armas de arriba: parchear el
-- bug del addon de terceros desde el schema, sin tocar sus archivos).
hook.Add("KeyPress", "ixEFG_DemonStruggle", function(client, key)
	if (key != IN_USE) then return end
	if (!IsValid(client) or !client:IsPlayer()) then return end

	local interactionEnt = client:GetNW2Entity("metro_2033_animation")
	if (!IsValid(interactionEnt) or interactionEnt:GetClass() != "lima_demon_interaction") then return end

	interactionEnt.KeyPresses = (interactionEnt.KeyPresses or 0) + 8
end)

-- ============================================================================
-- RESTAURAR ARMAS TRAS UNA LIMPIEZA DE MAPA.
--
-- game.CleanUpMap() (lo lanza, p.ej., el comando "mapreset" de SAM) borra de
-- golpe TODAS las entidades de limpieza del mundo, y las armas que cada jugador
-- lleva en la mano SON entidades del mundo: el cleanup las elimina con Remove()
-- directo, así que todo el servidor pierde sus armas a la vez. Los ítems del
-- inventario NO se pierden porque son datos del personaje, no entidades.
--
-- Aquí, tras cada limpieza, reponemos a cada jugador vivo lo que el cleanup le
-- quitó: manos, llaves, armas de facción/clase, las armas equipadas del
-- inventario (CW, etc.) y las herramientas de admin. Solo damos lo que falta,
-- así que no duplica nada.
-- ============================================================================
do
	local function RestorePlayerWeapons(client)
		if (!IsValid(client) or !client:Alive()) then return end
		-- Si está en ragdoll, su propia restauración se encarga al terminar.
		if (IsValid(client.ixRagdoll)) then return end

		local character = client:GetCharacter()
		if (!character) then return end

		if (!client:HasWeapon("ix_hands")) then client:Give("ix_hands") end
		if (!client:HasWeapon("ix_keys")) then client:Give("ix_keys") end

		local faction = ix.faction.indices[client:Team()]
		if (faction and faction.weapons) then
			for _, wepClass in ipairs(faction.weapons) do
				if (!client:HasWeapon(wepClass)) then client:Give(wepClass) end
			end
		end

		local class = ix.class.list[character:GetClass()]
		if (class and class.weapons) then
			for _, wepClass in ipairs(class.weapons) do
				if (!client:HasWeapon(wepClass)) then client:Give(wepClass) end
			end
		end

		-- Armas equipadas del inventario (CW y demás ítems-arma): el ítem sigue
		-- marcado como equip=true pero la entidad del arma fue borrada, así que la
		-- reponemos con el mismo OnLoadout que usa Helix en el respawn.
		local inv = character:GetInventory()
		if (inv) then
			for item in inv:Iter() do
				if (item.isWeapon and item:GetData("equip") and !client:HasWeapon(item.class)) then
					item:Call("OnLoadout", client)
				end
			end
		end

		-- Herramientas: solo si el personaje tiene la flag correspondiente
		-- (p = physgun, t = toolgun), igual que el sistema de flags de Helix.
		if (character:HasFlags("p") and !client:HasWeapon("weapon_physgun")) then
			client:Give("weapon_physgun")
		end

		if (character:HasFlags("t") and !client:HasWeapon("gmod_tool")) then
			client:Give("gmod_tool")
		end
	end

	-- El cleanup elimina las entidades de forma síncrona; reponemos un instante
	-- después para asegurarnos de correr cuando ya no queda nada por borrar.
	hook.Add("PostCleanupMap", "ixEFGRestoreWeaponsAfterCleanup", function()
		timer.Simple(0.5, function()
			for _, client in ipairs(player.GetAll()) do
				RestorePlayerWeapons(client)
			end
		end)
	end)
end

-- Protege las áreas de tipo "loot_zone" del borrado accidental desde el area edit de Helix.
-- Reemplazamos el net.Receive del framework para añadir la validación de tipo.
net.Receive("ixAreaRemove", function(length, client)
	if (!client:Alive() or !CAMI.PlayerHasAccess(client, "Helix - AreaEdit", nil)) then
		return
	end

	local id = net.ReadString()

	if (!ix.area.stored[id]) then
		client:NotifyLocalized("areaDoesntExist")
		return
	end

	if (ix.area.stored[id].type == "loot_zone") then
		client:Notify("No se pueden borrar áreas de loot desde el editor.")
		return
	end

	ix.area.Remove(id)
	ix.log.Add(client, "areaRemove", id)
end)

function Schema:PlayerSpray()
	return true
end

function Schema:OnItemTransferred(item, oldInv, newInv)
	if (not item.maxstack or item.maxstack <= 1) then return end
	if (item.invID == 0) then return end

	local itemID = item.id
	local invID  = item.invID

	timer.Simple(0, function()
		local theItem = ix.item.instances[itemID]
		if (not theItem or theItem.invID ~= invID) then return end

		local inv = ix.item.inventories[invID]
		if (not inv or not inv.GetItems) then return end

		local maxS  = theItem.maxstack or 64
		local myAmt = theItem:GetData("Amount", 1)

		for _, v in pairs(inv:GetItems()) do
			if (v.uniqueID == theItem.uniqueID and v.id ~= theItem.id) then
				local otherAmt = v:GetData("Amount", 1)
				local combined = myAmt + otherAmt

				if (combined <= maxS) then
					v:SetData("Amount", combined)
					inv:Remove(theItem.id)
					return
				else
					v:SetData("Amount", maxS)
					myAmt = combined - maxS
					theItem:SetData("Amount", myAmt)
				end
			end
		end
	end)
end

-- Change death sounds of people in the police faction to the metropolice death sound.
function Schema:GetPlayerDeathSound(client)
	local character = client:GetCharacter()

	if (character and character:IsPolice()) then
		return "NPC_MetroPolice.Die"
	end
end

-- ============================================================================
-- FORZAR REAPARICIÓN — un rato después de que aparece el texto de "Estás
-- inconsciente" (no desde que mueres), mantener F durante "forceRespawnHold"
-- segundos salta el resto de la espera de "spawnTime" (60s por defecto,
-- pensada para dar margen a un médico). Autoritativo: el temporizador del
-- hold corre aquí y se cancela si el jugador suelta F antes de tiempo (mismo
-- patrón que el arrastre de handcuffs). El feedback visual va en
-- menu_ui/derma/cl_skin.lua (SKIN:PaintDeathScreen), no en HUDPaint, porque
-- el panel de la pantalla de inconsciencia se pinta encima de HUDPaint.
-- ============================================================================

-- El texto de ixDeathScreen empieza a aparecer en progress > 0.3, es decir a
-- spawnTime * 0.3 segundos desde la muerte (ver cl_deathscreen.lua de Helix).
local function GetForceRespawnThreshold()
	local textDelay = ix.config.Get("spawnTime", 60) * 0.3
	return textDelay + ix.config.Get("forceRespawnDelay", 10)
end

function Schema:PlayerButtonDown(client, button)
	if (button != KEY_F) then return end
	if (!IsValid(client) or client:Alive()) then return end
	if (!client:GetCharacter()) then return end

	local deathStart = client:GetNetVar("deathStartTime", 0)
	if (CurTime() - deathStart < GetForceRespawnThreshold()) then return end

	local uniqueID = "ixForceRespawn_" .. client:SteamID64()
	timer.Create(uniqueID, ix.config.Get("forceRespawnHold", 10), 1, function()
		if (!IsValid(client) or client:Alive()) then return end
		client:SetNetVar("deathTime", CurTime())
	end)
end

function Schema:PlayerButtonUp(client, button)
	if (button != KEY_F) then return end
	if (!IsValid(client)) then return end

	timer.Remove("ixForceRespawn_" .. client:SteamID64())
end

-- ============================================================================
-- Armas "Redux" de NPCs de VJ Base (weapon_vj_*): son exclusivas para NPCs y no
-- se pueden usar ni recoger (el propio VJ Base las quita con "It's made for
-- NPCs only!"), así que al morir el NPC no dejamos el pickup inservible tirado
-- en el suelo: se borra directamente. Con una probabilidad pequeña, en su lugar
-- suelta un poco de munición (fusil, escopeta o pistola a partes iguales); lo
-- normal es que no suelte nada.
-- ============================================================================

local NPC_WEAPON_AMMO_DROPCHANCE = 0.25 -- 25% de soltar munición; el resto (75%) no suelta nada
local NPC_WEAPON_AMMO_TYPES = {"ammo_pistol", "ammo_ar2", "ammo_buckshot"}

-- Barrido periódico en vez de OnEntityCreated: el arma del NPC ya existe desde
-- que se le da al spawnear (con dueño), y sigue siendo la MISMA entidad tras
-- morir — solo se le queda sin dueño. OnEntityCreated nunca vuelve a dispararse
-- para ella, así que hay que revisar activamente las que ya están sueltas.
timer.Create("ixEFG_NPCWeaponDropSweep", 1, 0, function()
	for _, ent in ipairs(ents.FindByClass("weapon_vj_*")) do
		if (IsValid(ent) and !IsValid(ent:GetOwner())) then
			local pos = ent:GetPos()
			ent:Remove()

			if (math.random() <= NPC_WEAPON_AMMO_DROPCHANCE) then
				local ammoID = NPC_WEAPON_AMMO_TYPES[math.random(#NPC_WEAPON_AMMO_TYPES)]
				ix.item.Spawn(ammoID, pos)
			end
		end
	end
end)

-- ============================================================================
-- Límite de borrado de personaje: solo UNA vez por cuenta en toda su vida (evita
-- abusar de mecánicas ligadas a crear/borrar personajes, p. ej. recibir de nuevo
-- el equipo inicial de una facción una y otra vez). net.Receive no encadena
-- receptores (sobreescribe), así que envolvemos el handler original de Helix:
-- si la cuenta ya gastó su borrado, se rechaza aquí sin más; si no, se marca
-- como gastado y se deja pasar al comportamiento normal de Helix.
-- Un admin puede resetear el límite de un jugador con "CharResetDeleteLimit"
-- (ver schema/sh_hooks.lua).
local ixOriginalCharacterDelete = net.Receivers["ixcharacterdelete"]

if (!isfunction(ixOriginalCharacterDelete)) then
	ErrorNoHalt("[EFG] No se pudo capturar el receptor original de 'ixCharacterDelete'; el límite de borrado único no funcionará.\n")
end

net.Receive("ixCharacterDelete", function(length, client)
	if (!IsValid(client)) then return end

	local steamID = client:SteamID64()
	local used = ix.data.Get("charDeletesUsed", {}, true, true)

	if (used[steamID]) then
		client:Notify("Ya has usado tu única oportunidad de borrar un personaje.")
		return
	end

	used[steamID] = true
	ix.data.Set("charDeletesUsed", used, true, true)

	if (isfunction(ixOriginalCharacterDelete)) then
		ixOriginalCharacterDelete(length, client)
	end
end)
