local PLUGIN = PLUGIN
local PMC = ix.efg.pmc

util.AddNetworkString("ixEFGOpenLobby")
util.AddNetworkString("ixEFGLobbyAction")
util.AddNetworkString("ixEFGSetVoice")

-- ─── Creación del PMC ────────────────────────────────────────────────────────
-- Nombres de PMC ya usados (guardados con los datos del plugin, para que la
-- comprobación funcione aunque el dueño esté desconectado).
function PLUGIN:LoadData()
	self.names = self:GetData() or {}
end

function PLUGIN:SaveNames()
	self:SetData(self.names or {})
end

local function nameKey(name)
	return string.lower(string.Trim(tostring(name or "")))
end

function PLUGIN:IsNameTaken(name)
	local key = nameKey(name)

	if ((self.names or {})[key]) then
		return true
	end

	-- personajes de antes de esta lista que estén cargados ahora mismo
	for _, character in pairs(ix.char.loaded) do
		if (nameKey(character:GetName()) == key) then
			return true
		end
	end

	return false
end

-- Validación en servidor: bando, nombre, cara, voz y un solo PMC por cuenta.
-- Se ejecuta con el payload tal y como llega del cliente.
function PLUGIN:CanPlayerCreateCharacter(client, payload)
	local sideKey = PMC.GetSideKey(tonumber(payload.faction))

	if (!sideKey) then
		-- el staff puede crear personajes de otras facciones (Scav de pruebas, staff)
		if (client:IsAdmin()) then return end

		return false, "efgInvalidSide"
	end

	local ok, fault = PMC.ValidateNickname(payload.name)

	if (!ok) then
		return false, fault
	end

	if (self:IsNameTaken(payload.name)) then
		return false, "efgNameTaken"
	end

	local face = tonumber(payload.efgFace)

	if (!face or face < 1 or face > PMC.sides[sideKey].faces) then
		return false, "efgInvalidFace"
	end

	if (!PMC.voices[tonumber(payload.efgVoice) or 0]) then
		return false, "efgInvalidVoice"
	end

	if (!client:IsAdmin()) then
		for _, id in pairs(client.ixCharList or {}) do
			local other = ix.char.loaded[id]

			if (other and PMC.GetSideKey(other:GetFaction())) then
				return false, "efgOnePMC"
			end
		end
	end
end

function PLUGIN:OnCharacterCreated(client, character)
	if (PMC.GetSideKey(character:GetFaction())) then
		self.names = self.names or {}
		self.names[nameKey(character:GetName())] = character:GetID()
		self:SaveNames()
	end
end

function PLUGIN:CharacterDeleted(client, id)
	for key, charID in pairs(self.names or {}) do
		if (charID == id) then
			self.names[key] = nil
			self:SaveNames()
			break
		end
	end
end

-- ─── Cara ────────────────────────────────────────────────────────────────────
-- Se aplica en cada aparición: el modelo se reinicia al reaparecer.
function PLUGIN:ApplyFace(client)
	local character = client:GetCharacter()
	if (!character or !PMC.GetSideKey(character:GetFaction())) then return end

	local headID = client:FindBodygroupByName("Head")

	if (headID and headID >= 0) then
		local option = math.Clamp((character:GetEfgFace() or 1) - 1, 0, client:GetBodygroupCount(headID) - 1)
		client:SetBodygroup(headID, option)
	end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	timer.Simple(0.2, function()
		if (IsValid(client)) then self:ApplyFace(client) end
	end)

	-- como en EFT, al entrar se abre el menú principal si no estás en una raid
	timer.Simple(1.5, function()
		if (IsValid(client) and client:GetCharacter() == character and !(client.InRaid and client:InRaid())) then
			net.Start("ixEFGOpenLobby")
			net.Send(client)
		end
	end)
end

function PLUGIN:PostPlayerLoadout(client)
	timer.Simple(0.2, function()
		if (IsValid(client)) then self:ApplyFace(client) end
	end)
end

-- ─── Voz ─────────────────────────────────────────────────────────────────────
function PLUGIN:SetVoice(client, voice)
	local character = client:GetCharacter()
	voice = tonumber(voice)

	if (!character or !PMC.GetSideKey(character:GetFaction())) then
		return "Solo los PMC tienen voz configurable."
	end

	if (!voice or !PMC.voices[voice]) then
		return "Elige la voz 1 o la 2."
	end

	character:SetEfgVoice(voice)
	self:PlayVoice(client, "yes", true)

	return "Voz cambiada a " .. PMC.voices[voice].name .. "."
end

net.Receive("ixEFGSetVoice", function(_, client)
	if ((client.efgNextVoiceChange or 0) > CurTime()) then return end
	client.efgNextVoiceChange = CurTime() + 1

	local result = PLUGIN:SetVoice(client, net.ReadUInt(4))

	if (result) then
		client:Notify(result)
	end
end)

-- Reproduce una línea de voz del PMC. Hay un tiempo mínimo entre frases para
-- que no se pisen; bForce se lo salta salvo el anti-spam corto.
function PLUGIN:PlayVoice(client, event, bForce)
	if (!IsValid(client) or !client:Alive()) then return end

	local character = client:GetCharacter()
	local sideKey = character and PMC.GetSideKey(character:GetFaction())
	if (!sideKey) then return end

	local now = CurTime()
	if ((client.efgVoiceSpam or 0) > now) then return end
	if (!bForce and (client.efgVoiceNext or 0) > now) then return end

	local path = PMC.RandomVoicePath(sideKey, event)
	if (!path) then return end

	local voice = PMC.voices[character:GetEfgVoice() or 1] or PMC.voices[1]

	client:EmitSound(path, 80, voice.pitch, 1, CHAN_VOICE)
	client.efgVoiceSpam = now + 1.5
	client.efgVoiceNext = now + 4
end

-- herido / poca vida
function PLUGIN:PlayerHurt(client, attacker, health, damage)
	if (health <= 0) then return end

	if (health < client:GetMaxHealth() * 0.3 and (client.efgNextLowHP or 0) < CurTime()) then
		client.efgNextLowHP = CurTime() + 25
		self:PlayVoice(client, "lowhp")
	elseif (damage >= 5 and math.random() < 0.5) then
		self:PlayVoice(client, "wound")
	end
end

-- muerte: el grito sale del jugador justo antes del ragdoll
function PLUGIN:DoPlayerDeath(client)
	local character = client:GetCharacter()
	local sideKey = character and PMC.GetSideKey(character:GetFaction())
	local path = sideKey and PMC.RandomVoicePath(sideKey, "death")

	if (path) then
		local voice = PMC.voices[character:GetEfgVoice() or 1] or PMC.voices[1]
		client:EmitSound(path, 80, voice.pitch, 1, CHAN_VOICE)
	end
end

-- baja enemiga (jugador o NPC)
function PLUGIN:PlayerDeath(victim, inflictor, attacker)
	if (IsValid(attacker) and attacker:IsPlayer() and attacker != victim and math.random() < 0.6) then
		timer.Simple(0.6, function() self:PlayVoice(attacker, "enemydown") end)
	end
end

function PLUGIN:OnNPCKilled(npc, attacker)
	if (IsValid(attacker) and attacker:IsPlayer() and math.random() < 0.5) then
		timer.Simple(0.6, function() self:PlayVoice(attacker, "enemydown") end)
	end
end

-- recarga (solo si el cargador no está lleno)
function PLUGIN:KeyPress(client, key)
	if (key != IN_RELOAD or math.random() > 0.4) then return end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon.Clip1 and weapon:GetMaxClip1() > 0 and weapon:Clip1() < weapon:GetMaxClip1()) then
		self:PlayVoice(client, "reload")
	end
end

-- grito de guerra al desplegar en raid
function PLUGIN:EFGRaidStarted(client, side)
	if (side == "pmc") then
		timer.Simple(3, function() self:PlayVoice(client, "spawn", true) end)
	end
end

-- ─── Lobby ───────────────────────────────────────────────────────────────────
-- Las acciones del lobby reutilizan los comandos (misma validación: raid,
-- nivel del mercadillo, etc.). Solo se aceptan las de esta lista.
local LOBBY_COMMANDS = {
	raid = "Raid",
	scav = "RaidScav",
	hideout = "Escondite",
	flea = "Mercadillo",
}

net.Receive("ixEFGLobbyAction", function(_, client)
	if ((client.efgNextLobbyAction or 0) > CurTime()) then return end
	client.efgNextLobbyAction = CurTime() + 0.5

	if (!client:GetCharacter()) then return end

	local action = net.ReadString()
	local argument = net.ReadString()

	if (LOBBY_COMMANDS[action]) then
		ix.command.Run(client, LOBBY_COMMANDS[action], {})
		return
	end

	-- comerciar desde el menú (como en EFT): solo fuera de raid
	if (action == "trader") then
		if (client.InRaid and client:InRaid()) then
			client:Notify("No puedes hablar con los comerciantes durante una raid.")
			return
		end

		for _, entity in ipairs(ents.FindByClass("ix_trader")) do
			if ((entity.factionKey or entity:GetNetVar("factionKey")) == argument) then
				client.efgLobbyTrader = entity
				client.efgLobbyTraderUntil = CurTime() + 900
				entity:Use(client)
				return
			end
		end

		client:Notify("Ese comerciante no está disponible en este mapa.")
	end

	if (action == "stash") then
		if (ix.strongbox and ix.strongbox.OpenRemote) then
			ix.strongbox.OpenRemote(client)
		else
			client:Notify("El alijo no está disponible.")
		end
	end
end)
