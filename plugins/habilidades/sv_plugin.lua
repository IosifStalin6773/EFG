local PLUGIN = PLUGIN

util.AddNetworkString("habilidades_Open")
util.AddNetworkString("habilidades_AdminData")
util.AddNetworkString("habilidades_AdminRefresh")
util.AddNetworkString("habilidades_AdminSet")

-- Límites anti-farm globales (suma de XP de todos los perks) tomados del CSV.
PLUGIN.maxXPPerHour = 1100
PLUGIN.maxXPPerDay  = 5500

-- XP total para alcanzar el nivel máximo (tope por perk).
local function maxPerkXP()
	return ix.perks.GetXPForLevel(ix.perks.maxLevel)
end

-- ── Métodos de personaje (servidor) ─────────────────────────────────────────────
do
	local CHAR = ix.meta.character

	-- Establece directamente el XP de un perk (sin anti-farm). Uso admin/interno.
	function CHAR:SetPerkXP(id, xp)
		if (!ix.perks.IsValidID(id)) then return end

		local perks = self:GetPerks() or {}
		perks[id] = math.Clamp(math.floor(xp or 0), 0, maxPerkXP())
		self:SetPerks(perks)
	end

	-- Suma XP a un perk respetando los topes anti-farm. Devuelve el XP realmente otorgado.
	function CHAR:AddPerkXP(id, amount)
		if (!ix.perks.IsValidID(id)) then return 0 end

		amount = math.floor(amount or 0)
		if (amount <= 0) then return 0 end

		local client = self:GetPlayer()
		local now = os.time()

		local hourStart = self:GetData("perkHourStart", 0)
		local hourXP    = self:GetData("perkHourXP", 0)
		local dayStart  = self:GetData("perkDayStart", 0)
		local dayXP     = self:GetData("perkDayXP", 0)

		if (now - hourStart >= 3600) then
			hourStart = now
			hourXP = 0
		end

		if (now - dayStart >= 86400) then
			dayStart = now
			dayXP = 0
		end

		local allowed = math.min(amount, PLUGIN.maxXPPerHour - hourXP, PLUGIN.maxXPPerDay - dayXP)
		allowed = math.max(0, math.floor(allowed))

		-- Los contadores anti-farm no se replican al cliente (no los necesita).
		if (allowed <= 0) then
			self:SetData("perkHourStart", hourStart, true)
			self:SetData("perkHourXP", hourXP, true)
			self:SetData("perkDayStart", dayStart, true)
			self:SetData("perkDayXP", dayXP, true)
			return 0
		end

		self:SetData("perkHourStart", hourStart, true)
		self:SetData("perkHourXP", hourXP + allowed, true)
		self:SetData("perkDayStart", dayStart, true)
		self:SetData("perkDayXP", dayXP + allowed, true)

		local perks = self:GetPerks() or {}
		local oldXP = perks[id] or 0
		local oldLevel = ix.perks.GetLevelFromXP(oldXP)
		local newXP = math.min(oldXP + allowed, maxPerkXP())

		perks[id] = newXP
		self:SetPerks(perks)

		local newLevel = ix.perks.GetLevelFromXP(newXP)
		if (newLevel > oldLevel and IsValid(client)) then
			local def = ix.perks.byID[id]
			client:NotifyLocalized("perkSubeNivel", def and def.name or id, newLevel)
			client:EmitSound("ambient/levels/labs/teleport_preblast_initialize1.wav", 60)

			hook.Run("PerkLevelUp", client, self, id, newLevel, oldLevel)

			if (newLevel % 10 == 0) then
				hook.Run("PerkLevelReward", client, self, id, newLevel)
			end
		end

		return allowed
	end
end

-- ── Comando del jugador: abrir el menú de habilidades ───────────────────────────
ix.command.Add("Habilidades", {
	description = "Abre el menú de tus habilidades y su progreso.",
	OnRun = function(self, client)
		net.Start("habilidades_Open")
		net.Send(client)
	end
})

-- ── Admin: snapshot de los perks de todos los jugadores conectados ──────────────
local function sendAdminData(client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local players = {}
	for _, ply in player.Iterator() do
		local character = ply:GetCharacter()
		if (!character) then continue end

		players[#players + 1] = {
			index = ply:EntIndex(),
			name  = character:GetName(),
			perks = character:GetPerks() or {}
		}
	end

	net.Start("habilidades_AdminData")
		net.WriteString(util.TableToJSON(players))
	net.Send(client)
end

net.Receive("habilidades_AdminRefresh", function(_, client)
	sendAdminData(client)
end)

net.Receive("habilidades_AdminSet", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local targetIndex = net.ReadUInt(16)
	local perkID = net.ReadString()
	local level = math.Clamp(net.ReadUInt(8), 1, ix.perks.maxLevel)

	if (!ix.perks.IsValidID(perkID)) then return end

	local target = Entity(targetIndex)
	if (!IsValid(target) or !target:IsPlayer()) then return end

	local character = target:GetCharacter()
	if (!character) then return end

	character:SetPerkXP(perkID, ix.perks.GetXPForLevel(level))

	local def = ix.perks.byID[perkID]
	client:Notify("Has establecido " .. (def and def.name or perkID) .. " de " .. target:Name() .. " al nivel " .. level .. ".")
	target:Notify("Un administrador ha cambiado tu habilidad " .. (def and def.name or perkID) .. " al nivel " .. level .. ".")

	sendAdminData(client)
end)

-- Comando admin: abrir el panel de administración de habilidades.
ix.command.Add("HabilidadesAdmin", {
	description = "Abre el panel de administración de habilidades de los jugadores.",
	adminOnly = true,
	OnRun = function(self, client)
		sendAdminData(client)
	end
})

-- Comando admin por chat: /setperk <jugador> <perkId> <nivel>
ix.command.Add("SetPerk", {
	description = "Establece el nivel de una habilidad de un personaje.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.string,
		ix.type.number,
	},
	OnRun = function(self, client, target, perkID, level)
		perkID = perkID:lower()

		if (!ix.perks.IsValidID(perkID)) then
			local validos = {}
			for _, perk in ipairs(ix.perks.list) do
				validos[#validos + 1] = perk.id
			end
			return client:Notify("Habilidad inválida. Opciones: " .. table.concat(validos, ", "))
		end

		level = math.Clamp(math.Round(level), 1, ix.perks.maxLevel)

		local character = target:GetCharacter()
		if (!character) then
			return client:Notify("El jugador no tiene un personaje activo.")
		end

		character:SetPerkXP(perkID, ix.perks.GetXPForLevel(level))

		local def = ix.perks.byID[perkID]
		target:Notify("Un administrador ha cambiado tu habilidad " .. def.name .. " al nivel " .. level .. ".")
		client:Notify("Habilidad " .. def.name .. " de " .. target:Name() .. " establecida al nivel " .. level .. ".")
	end
})
