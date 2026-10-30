local PLUGIN = PLUGIN

PLUGIN.name = "EFG Admin"
PLUGIN.author = "EFG"
PLUGIN.description = "Comandos de administración para probar el modo: dinero, nivel, experiencia, lealtad, tareas y tiempo de raid."

-- comerciante por clave (prapor) o por nombre visible (Prapor)
local function findTrader(text)
	text = string.lower(string.Trim(text or ""))

	for _, key in ipairs(ix.traders and ix.traders.factions or {}) do
		local name = string.lower(ix.traders.names[key] or "")

		if (key == text or name == text or (text != "" and name:find(text, 1, true))) then
			return key
		end
	end
end

ix.command.Add("EFGDarDinero", {
	description = "Da rublos a un jugador (cantidad negativa para quitar).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},
	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()
		if (!character) then return "Ese jugador no tiene personaje." end

		amount = math.Round(amount)
		character:SetMoney(math.max(0, character:GetMoney() + amount))
		return ("%s tiene ahora %s ₽."):format(target:Name(), string.Comma(character:GetMoney()))
	end
})

ix.command.Add("EFGNivel", {
	description = "Pone a un PMC en un nivel (1-79). La experiencia queda al principio de ese nivel.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},
	OnRun = function(self, client, target, level)
		local character = target:GetCharacter()
		if (!character or !ix.efg.levels) then return "Ese jugador no tiene personaje." end

		level = math.Clamp(math.floor(level), 1, #ix.efg.levels)
		character:SetData("efgXP", ix.efg.levels[level])
		return ("%s es ahora nivel %d."):format(target:Name(), level)
	end
})

ix.command.Add("EFGDarXP", {
	description = "Da experiencia a un PMC (con aviso de subida de nivel).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},
	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()
		local raids = ix.plugin.Get("efg_raids")
		if (!character or !raids or !raids.GiveXP) then return "No se puede dar experiencia." end

		raids:GiveXP(character, math.max(0, math.floor(amount)))
		return ("%s: %s XP (nivel %d)."):format(target:Name(), string.Comma(character:GetEFGXP()), character:GetEFGLevel())
	end
})

ix.command.Add("EFGLealtad", {
	description = "Fija la reputación (0-1000) de un jugador con un comerciante. LL2 = 200, LL3 = 500, LL4 = 800 (y el nivel de PMC que pida cada LL).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string, ix.type.number},
	OnRun = function(self, client, target, trader, rep)
		local character = target:GetCharacter()
		if (!character or !character.GetTraderRep) then return "Ese jugador no tiene personaje." end

		local key = findTrader(trader)
		if (!key) then
			return "Comerciante desconocido. Usa: " .. table.concat(ix.traders.factions, ", ")
		end

		local reps = character:GetTraderRep() or {}
		reps[key] = math.Clamp(math.floor(rep), 0, 1000)
		character:SetTraderRep(reps)

		return ("%s: reputación %d con %s."):format(target:Name(), reps[key], ix.traders.names[key] or key)
	end
})

ix.command.Add("EFGCompletarTarea", {
	description = "Completa la tarea activa de un jugador y le da la primera recompensa.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		local character = target:GetCharacter()
		if (!character or !ix.missions or !ix.missions.GetActive) then return "No hay sistema de tareas." end

		local active, mission = ix.missions.GetActive(character)
		if (!active or !mission) then return target:Name() .. " no tiene ninguna tarea activa." end

		ix.missions.Complete(target, character, mission)
		return ("Tarea \"%s\" completada para %s."):format(mission.name or mission.id, target:Name())
	end
})

ix.command.Add("EFGTiempoRaid", {
	description = "Cambia los minutos que le quedan de raid a un jugador.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},
	OnRun = function(self, client, target, minutes)
		local raids = ix.plugin.Get("efg_raids")
		local raid = raids and raids.raiders and raids.raiders[target]
		if (!raid) then return target:Name() .. " no está en una raid." end

		raid.endTime = CurTime() + math.max(0.1, minutes) * 60
		target:SetNetVar("efgRaidEnd", raid.endTime)
		return ("A %s le quedan %s min de raid."):format(target:Name(), minutes)
	end
})
