local TIMBRE_SOUND = "musikmetro/metroll/bell.wav"
local TIMBRE_COOLDOWN = 3
local TIMBRE_MATCH_DIST_SQ = 50 * 50

local cooldowns = {}

util.AddNetworkString("timbres_PointsData")

function PLUGIN:LoadData()
	self.timbres = ix.data.Get("timbres") or {}
end

function PLUGIN:SaveTimbres()
	ix.data.Set("timbres", self.timbres)
end

function PLUGIN:GetTimbreByEntity(entity)
	if (!self.timbres) then return end

	-- Entidades del mapa: identificar por MapCreationID (único y estable)
	local mapID = entity:MapCreationID()
	if (mapID and mapID >= 0) then
		for id, data in pairs(self.timbres) do
			if (data.mapCreationID == mapID) then
				return id, data
			end
		end
	end

	-- Fallback por posición (entidades spawneadas o datos legacy sin mapCreationID)
	local pos = entity:WorldSpaceCenter()
	for id, data in pairs(self.timbres) do
		if (!data.mapCreationID) then
			local timbrePos = Vector(data.pos[1], data.pos[2], data.pos[3])

			if (pos:DistToSqr(timbrePos) < TIMBRE_MATCH_DIST_SQ) then
				return id, data
			end
		end
	end
end

function PLUGIN:PlayerUse(client, entity)
	if (!IsValid(entity)) then return end

	local id = self:GetTimbreByEntity(entity)
	if (!id) then return end

	if (!cooldowns[id] or cooldowns[id] <= CurTime()) then
		cooldowns[id] = CurTime() + TIMBRE_COOLDOWN
		entity:EmitSound(TIMBRE_SOUND, 85, 100, 1)
	end

	return false
end

