local PLUGIN = PLUGIN

PLUGIN.name = "EFG Perfil"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Estadísticas del PMC (raids, supervivencia, bajas, salud, combate y botín) y la pestaña PERSONAJE del TAB al estilo de EFT."

ix.efg = ix.efg or {}
ix.efg.profile = ix.efg.profile or {}

local PROFILE = ix.efg.profile

-- Datos del personaje "efgProfile" (se envían solo al dueño):
--   pmc / scav = {raids, survived, kia, mia, awol, runthrough, kills, killsPMC,
--                 killsScav, killsAI, headshots, streak, bestStreak, lifeTime}
--   online, xp = {kill, loot, heal, survival, task}
--   health = {taken, lost, fractures, bleeds, healed, meds, food, drink}
--   combat = {dealt, absorbed}, loot = {distance (m), items}
function PROFILE.Get(character)
	local data = character and character:GetData("efgProfile")
	return istable(data) and data or {}
end

local function num(t, key) return tonumber(t and t[key]) or 0 end

-- suma de PMC y Scav (pestaña GENERAL)
function PROFILE.Side(data, side)
	if (side != "overall") then return data[side] or {} end

	local out = {}

	for _, key in ipairs({"pmc", "scav"}) do
		for stat, value in pairs(data[key] or {}) do
			if (stat == "bestStreak") then
				out[stat] = math.max(out[stat] or 0, tonumber(value) or 0)
			elseif (stat != "streak") then
				out[stat] = (out[stat] or 0) + (tonumber(value) or 0)
			end
		end
	end

	out.streak = num(data.pmc, "streak")
	return out
end

-- Logros: se desbloquean al cumplir la condición con las estadísticas guardadas.
PROFILE.achievements = {
	{id = "first_raid", name = "Bautismo de fuego", desc = "Completa tu primera raid.", check = function(d) return num(PROFILE.Side(d, "overall"), "raids") >= 1 end},
	{id = "survivor", name = "Superviviente", desc = "Sobrevive a 10 raids como PMC.", check = function(d) return num(d.pmc, "survived") >= 10 end},
	{id = "streak5", name = "Racha", desc = "Sobrevive 5 raids seguidas.", check = function(d) return num(PROFILE.Side(d, "overall"), "bestStreak") >= 5 end},
	{id = "hunter", name = "Cazador", desc = "Abate a 25 enemigos.", check = function(d) return num(PROFILE.Side(d, "overall"), "kills") >= 25 end},
	{id = "pmc_killer", name = "Sin piedad", desc = "Abate a 10 PMC.", check = function(d) return num(PROFILE.Side(d, "overall"), "killsPMC") >= 10 end},
	{id = "marksman", name = "Tiro a la cabeza", desc = "Consigue 20 bajas a la cabeza.", check = function(d) return num(PROFILE.Side(d, "overall"), "headshots") >= 20 end},
	{id = "scav_life", name = "Vida de Scav", desc = "Sobrevive a 10 raids como Scav.", check = function(d) return num(d.scav, "survived") >= 10 end},
	{id = "medic", name = "Manos de cirujano", desc = "Cura 1000 puntos de vida.", check = function(d) return num(d.health, "healed") >= 1000 end},
	{id = "unbreakable", name = "Huesos de acero", desc = "Sufre 25 fracturas y sigue en pie.", check = function(d) return num(d.health, "fractures") >= 25 end},
	{id = "walker", name = "Caminante", desc = "Recorre 50 km en raid.", check = function(d) return num(d.loot, "distance") >= 50000 end},
	{id = "looter", name = "Saqueador", desc = "Recoge 500 objetos en raid.", check = function(d) return num(d.loot, "items") >= 500 end},
	{id = "veteran", name = "Veterano", desc = "Juega 100 horas.", check = function(d) return num(d, "online") >= 360000 end},
}

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_html.lua")
ix.util.Include("cl_plugin.lua")
