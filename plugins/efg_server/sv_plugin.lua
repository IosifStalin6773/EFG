local PLUGIN = PLUGIN

if (!SERVER) then return end

-- ─── Wipe ───────────────────────────────────────────────────────────────────
local wipeKeys = {
	"efgXP", "efgStats", "efgProfile", "efgHideout", "efgExamined", "efgInsurance", "efgFuel", "efgGPUs", "efgBTC",
	"efgScavCase", "efgKarma", "efgProduction", "efgMessages", "efgInRaid", "efgProd_water_collector", "efgProd_booze"
}

local function clearInventory(inventory)
	if (!inventory) then return end

	for _, item in pairs(inventory:GetItems(false)) do
		if (!item.isSecureContainer) then
			item:Remove()
		end
	end
end

function PLUGIN:WipeCharacter(client, character)
	for _, key in ipairs(wipeKeys) do
		character:SetData(key, nil)
	end

	clearInventory(character:GetInventory())
	clearInventory(ix.strongbox and ix.strongbox.GetStash and ix.strongbox.GetStash(character))

	character:SetMoney(ix.config.Get("efgWipeMoney", 500000))
	character:SetData("efgWipe", ix.config.Get("efgWipeID", 1))

	hook.Run("EFGCharacterWiped", client, character)
	client:Notify("Wipe: tu personaje empieza de cero.")
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	local wipe = ix.config.Get("efgWipeID", 1)
	local mine = character:GetData("efgWipe")

	-- personajes de antes del primer wipe: se marcan sin borrar nada
	if (mine == nil) then
		character:SetData("efgWipe", wipe)
	elseif (mine < wipe) then
		timer.Simple(1, function()
			if (IsValid(client) and client:GetCharacter() == character) then
				self:WipeCharacter(client, character)
			end
		end)
	end
end

-- ─── Búsqueda de grupo ──────────────────────────────────────────────────────
PLUGIN.queue = PLUGIN.queue or {}

function PLUGIN:ToggleQueue(client)
	for i, other in ipairs(self.queue) do
		if (other == client) then
			table.remove(self.queue, i)
			return "Has salido de la cola de grupo."
		end
	end

	if (client:InRaid()) then return "Estás en una raid." end

	table.insert(self.queue, client)
	self:MatchQueue()

	return "Buscando grupo… (" .. #self.queue .. " en cola)"
end

function PLUGIN:MatchQueue()
	local raids = ix.plugin.Get("efg_raids")
	if (!raids) then return end

	for i = #self.queue, 1, -1 do
		local client = self.queue[i]
		if (!IsValid(client) or client:InRaid()) then table.remove(self.queue, i) end
	end

	local size = math.min(ix.config.Get("efgGroupMax", 5), 4)
	if (#self.queue < 2) then return end

	local members = {}

	for _ = 1, math.min(size, #self.queue) do
		members[#members + 1] = table.remove(self.queue, 1)
	end

	local leader = members[1]
	local joined = {leader}

	for i = 2, #members do
		raids:GroupInvite(leader, members[i])
		raids:GroupAccept(members[i])

		-- quien ya estaba en otro grupo no entra: vuelve a la cola
		local group = raids:GetGroup(members[i])

		if (group and group.leader == leader) then
			joined[#joined + 1] = members[i]
		else
			table.insert(self.queue, members[i])
		end
	end

	if (#joined < 2) then
		table.insert(self.queue, 1, leader)
		return
	end

	for _, member in ipairs(joined) do
		member:Notify("Grupo formado. Líder: " .. leader:Name() .. ". El líder despliega con /Raid.")
	end
end

function PLUGIN:PlayerDisconnected(client)
	table.RemoveByValue(self.queue, client)
end

-- ─── Anticheat ──────────────────────────────────────────────────────────────
local nextCheck = 0

function PLUGIN:Think()
	if (!ix.config.Get("efgAntiSpeed", true) or nextCheck > CurTime()) then return end
	nextCheck = CurTime() + 0.5

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive() and client:GetMoveType() == MOVETYPE_WALK and !client:InVehicle() and client:IsOnGround()) then
			local limit = math.max(client:GetRunSpeed(), client:GetWalkSpeed()) * 1.6 + 40
			local speed = client:GetVelocity():Length2D()

			if (speed > limit) then
				client.efgSpeedStrikes = (client.efgSpeedStrikes or 0) + 1

				if (client.efgSpeedStrikes >= 3 and client.efgLastGoodPos) then
					client:SetPos(client.efgLastGoodPos)
					client:SetVelocity(-client:GetVelocity())
					ix.log.AddRaw(("[EFG anticheat] %s (%s) velocidad %d > %d"):format(client:Name(), client:SteamID(), speed, limit))
					client.efgSpeedStrikes = 0
				end
			else
				client.efgSpeedStrikes = 0
				client.efgLastGoodPos = client:GetPos()
			end
		end
	end
end

-- no se cogen objetos a distancia
function PLUGIN:CanPlayerTakeItem(client, item)
	local entity = isentity(item) and item or (istable(item) and item.entity)

	if (IsValid(entity) and client:GetPos():Distance(entity:GetPos()) > ix.config.Get("efgLootDistance", 160)) then
		ix.log.AddRaw(("[EFG anticheat] %s intentó coger un objeto a %d unidades"):format(client:Name(), client:GetPos():Distance(entity:GetPos())))
		return false
	end
end

-- ─── Descarga del contenido propio (FastDL) ────────────────────────────────
local function addFolder(path)
	local files, folders = file.Find(path .. "/*", "GAME")

	for _, name in ipairs(files or {}) do
		local ext = name:match("%.(%w+)$")

		if (ext and ({vmt = true, vtf = true, png = true, wav = true, mp3 = true, ogg = true, mdl = true, ttf = true})[ext:lower()]) then
			resource.AddFile(path .. "/" .. name)
		end
	end

	for _, folder in ipairs(folders or {}) do
		addFolder(path .. "/" .. folder)
	end
end

-- Los addons de la colección que monta el servidor (host_workshop_collection)
-- se mandan a cada jugador al entrar: nadie tiene que suscribirse a nada.
local function addWorkshopAddons()
	if (!ix.config.Get("efgAutoWorkshop", true)) then return end

	local n = 0

	for _, addon in ipairs(engine.GetAddons()) do
		if (addon.mounted and addon.wsid and tostring(addon.wsid) != "0") then
			resource.AddWorkshop(tostring(addon.wsid))
			n = n + 1
		end
	end

	MsgC(Color(227, 114, 45), ("[EFG] %d addons de Workshop se descargarán al entrar.\n"):format(n))
end

function PLUGIN:InitializedPlugins()
	if (!ix.efg.SendContent()) then return end

	addWorkshopAddons()

	for _, root in ipairs({"materials/efg", "sound/efg", "models/efg", "resource/fonts",
		-- medicinas en primera persona (efg_health/sh_medanim.lua)
		"models/weapons/sweps/eft", "materials/models/weapons/sweps/eft", "sound/weapons/eft"}) do
		addFolder(root)
	end
end

-- ─── Autodiagnóstico ────────────────────────────────────────────────────────
function PLUGIN:Diagnose(client)
	local function say(ok, text)
		client:ChatPrint((ok and "[OK] " or "[FALTA] ") .. text)
	end

	say(ARC9 != nil, "ARC9 (armas)")
	say(VJ != nil or file.Exists("lua/autorun/vj_base_autorun.lua", "GAME"), "VJ Base (IA)")

	local location = ix.efg.maps and ix.efg.maps.Current()
	say(location != nil, "Mapa de EFT reconocido: " .. (location and location.name or game.GetMap()))

	local counts = {ammo = 0, key = 0, stim = 0, arc9 = 0}

	for uniqueID, item in pairs(ix.item.list) do
		if (item.isAmmo) then counts.ammo = counts.ammo + 1 end
		if (item.isEFGKey) then counts.key = counts.key + 1 end
		if (item.efgStim) then counts.stim = counts.stim + 1 end
		if (uniqueID:find("^arc9_")) then counts.arc9 = counts.arc9 + 1 end
	end

	say(counts.ammo > 100, ("Munición: %d objetos"):format(counts.ammo))
	say(counts.key > 20, ("Llaves: %d"):format(counts.key))
	say(counts.stim > 10, ("Estimulantes: %d"):format(counts.stim))
	say(counts.arc9 > 0, ("Armas ARC9 como objetos: %d"):format(counts.arc9))

	local ai = ix.plugin.Get("efg_ai")
	local missing = {}

	for _, zoneType in pairs(ai and ai.zoneTypes or {}) do
		for _, class in ipairs(table.Add({zoneType.boss}, zoneType.classes or {})) do
			if (!list.Get("NPC")[class] and !scripted_ents.GetStored(class)) then
				missing[#missing + 1] = class
			end
		end
	end

	say(#missing == 0, ("Clases de NPC: faltan %d%s"):format(#missing, #missing > 0 and (" (" .. table.concat(missing, ", ", 1, math.min(6, #missing)) .. "…)") or ""))

	local raids = ix.plugin.Get("efg_raids")
	local data = raids and raids:GetMapData()
	say(data and data.hideout != nil, "Escondite colocado en este mapa")
	say(data and #data.spawns > 0, ("Spawns de raid: %d"):format(data and #data.spawns or 0))
	say(data and #data.extracts > 0, ("Extracciones: %d"):format(data and #data.extracts or 0))

	local zones = ai and ai.zones and #ai.zones or 0
	say(zones > 0, ("Zonas de IA: %d"):format(zones))

	local doors = ix.efg.maps and table.Count(ix.efg.maps.doors or {}) or 0
	say(doors > 0, ("Puertas con llave: %d"):format(doors))
end
