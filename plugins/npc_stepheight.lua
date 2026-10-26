PLUGIN.name   = "NPC Override"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.schema = "Any"

-- Toggle en vivo para aislar si CAP_OPEN_DOORS está atascando a los monstruos
-- de base Metro contra las puertas. Afecta solo a los NPCs que spawneen DESPUÉS
-- de cambiar el valor (los ya vivos conservan la capacidad con la que nacieron).
ix.config.Add("npcMetroOpenDoors", true, "Permite a los NPCs de base Metro cruzar door-links del nodegraph (CAP_OPEN_DOORS).", nil, {
	category = "NPCs"
})

-- distLook: detection range in units (default ~1200-1800)
-- peneDist: awareness/alert range before becoming hostile
local NPCConfig = {
	["npc_nosach"]            = { stepHeight = 120, distLook = 8096, peneDist = 3000, hull = HULL_HUMAN },
	["npc_murzik"]            = { stepHeight = 120, distLook = 8096, peneDist = 3000 },
	["npc_churzik"]           = { stepHeight = 120, distLook = 8096, peneDist = 3000, hull = HULL_HUMAN },
}

local function getConfig(class)
	for prefix, cfg in pairs(NPCConfig) do
		if (string.find(class, prefix, 1, true) == 1) then
			return cfg
		end
	end
end

local baseSetStepHeight = FindMetaTable("NPC").SetStepHeight
local baseSetMaxLookDistance = FindMetaTable("NPC").SetMaxLookDistance
local baseSetFOV = FindMetaTable("NPC").SetFOV

if (SERVER) then
	local TrackedNPCs = {}

	-- Better LOS check that handles height differences
	-- The original self:Visible(ent) traces EyePos→EyePos which hits platform edges
	local function heightAwareVisible(npc, ent)
		if (npc:Visible(ent)) then return true end

		local heightDiff = math.abs(ent:GetPos().z - npc:GetPos().z)
		if (heightDiff < 40) then return false end

		-- Try alternative trace targets when the default trace fails
		local eyePos = npc:EyePos()
		local targets = {
			ent:WorldSpaceCenter(),
			ent:GetPos() + Vector(0, 0, 10),
		}

		for _, targetPos in ipairs(targets) do
			local tr = util.TraceLine({
				start = eyePos,
				endpos = targetPos,
				filter = npc,
				mask = MASK_SHOT,
			})

			if (tr.Entity == ent or not tr.Hit) then
				return true
			end
		end

		return false
	end

	-- View cone check that works with vertical angles
	-- The engine's IsInViewCone uses 3D dot product, so targets directly above
	-- have dot≈0 which fails even with 160° FOV (threshold cos(80°)=0.17)
	local function heightAwareViewCone(npc, ent)
		if (npc:IsInViewCone(ent)) then return true end

		local heightDiff = math.abs(ent:GetPos().z - npc:GetPos().z)
		if (heightDiff < 40) then return false end

		-- Use 2D yaw-only check for targets at significant height differences
		local dir = (ent:GetPos() - npc:GetPos())
		dir.z = 0
		if (dir:LengthSqr() < 1) then return true end -- directly above/below
		dir:Normalize()

		local forward = npc:GetForward()
		local forward2D = Vector(forward.x, forward.y, 0)
		if (forward2D:LengthSqr() < 0.01) then return true end
		forward2D:Normalize()

		local dot = forward2D:Dot(dir)
		-- ~160° horizontal cone
		return dot > -0.17
	end

	hook.Add("OnEntityCreated", "npc_stepheight_override", function(ent)
		local cfg = getConfig(ent:GetClass())
		if (not cfg) then return end

		timer.Simple(0, function()
			if (not IsValid(ent)) then return end

			if (cfg.stepHeight) then
				baseSetStepHeight(ent, cfg.stepHeight)
				ent.SetStepHeight = function(self)
					baseSetStepHeight(self, cfg.stepHeight)
				end
			end

			if (cfg.distLook) then
				baseSetMaxLookDistance(ent, cfg.distLook)
				ent.SetMaxLookDistance = function(self)
					baseSetMaxLookDistance(self, cfg.distLook)
				end
			end

			if (cfg.hull) then
				ent:SetHullType(cfg.hull)
			end

			-- PeneDist controls the awareness range in the SNPC's own aggro logic
			if (cfg.peneDist and ent.PeneDist) then
				ent.PeneDist = cfg.peneDist
			end

			-- FOV: widen so they spot players from the sides
			baseSetFOV(ent, 160)
			ent.SetFOV = function(self)
				baseSetFOV(self, 160)
			end

			-- Override IsActuallyVisible to:
			-- 1. Hide observers/noclip players (SNPC ignores FL_NOTARGET)
			-- 2. Handle height differences (Visible + IsInViewCone both fail at height diffs)
			if (ent.IsActuallyVisible) then
				local origIsActuallyVisible = ent.IsActuallyVisible
				ent.IsActuallyVisible = function(self, target)
					if (not IsValid(target) or not target:Alive()) then return false end

					-- Block detection of observers/noclip/notarget players
					if (target:IsPlayer()) then
						if (target:GetMoveType() == MOVETYPE_NOCLIP) then return false end
						if (target:IsFlagSet(FL_NOTARGET)) then return false end
					end

					if (origIsActuallyVisible(self, target)) then return true end

					local heightDiff = math.abs(target:GetPos().z - self:GetPos().z)
					if (heightDiff < 40) then return false end

					if (not heightAwareVisible(self, target)) then return false end
					if (not heightAwareViewCone(self, target)) then return false end

					-- Darkness check for players (same as original)
					if (target:IsPlayer() and self.GetDarkness and self.DarkLevel) then
						if (self:GetDarkness(target) < self.DarkLevel) then return false end
					end

					return true
				end
			end

			TrackedNPCs[ent] = cfg
		end)
	end)

	-- ── CAP_OPEN_DOORS para cualquier SNPC de lima_metro_base ──
	-- Los enlaces del nodegraph que cruzan una puerta se marcan como door-link
	-- y el pathfinder solo los recorre si el NPC tiene CAP_OPEN_DOORS, AUNQUE la
	-- puerta esté físicamente abierta. Sin esta capacidad los monstruos descartan
	-- la ruta por el umbral y se quedan al otro lado. Aplica a toda la base Metro
	-- (nosach, murzik, churzik, sus variantes y cualquier bicho futuro), no solo
	-- a las clases del NPCConfig.
	local metroBaseCache = {}
	local function derivesFromMetroBase(class)
		local cached = metroBaseCache[class]
		if (cached != nil) then return cached end

		local result = false
		local current = class
		local guard = 0
		while (current and guard < 16) do
			if (current == "lima_metro_base") then
				result = true
				break
			end
			local stored = scripted_ents.GetStored(current)
			if (!stored or !stored.t) then break end
			current = stored.t.Base
			guard = guard + 1
		end

		metroBaseCache[class] = result
		return result
	end

	hook.Add("OnEntityCreated", "npc_stepheight_opendoors", function(ent)
		if (!IsValid(ent) or !ent:IsNPC()) then return end
		if (!derivesFromMetroBase(ent:GetClass())) then return end

		timer.Simple(0, function()
			if (IsValid(ent) and ix.config.Get("npcMetroOpenDoors", true)) then
				ent:CapabilitiesAdd(CAP_OPEN_DOORS)
			end
		end)
	end)

	hook.Add("EntityRemoved", "npc_stepheight_heightagro", function(ent)
		TrackedNPCs[ent] = nil
	end)

	-- Keep enemy memory fresh for targets at different heights
	-- Prevents the engine from clearing the enemy due to Visible() returning false
	local nextScan = 0
	hook.Add("Think", "npc_stepheight_heightagro", function()
		local curTime = CurTime()
		if (curTime < nextScan) then return end
		nextScan = curTime + 0.5

		for npc, cfg in pairs(TrackedNPCs) do
			if (not IsValid(npc)) then
				TrackedNPCs[npc] = nil
				continue
			end

			if (npc:Health() <= 0) then continue end

			local enemy = npc:GetEnemy()
			if (IsValid(enemy)) then
				local heightDiff = math.abs(enemy:GetPos().z - npc:GetPos().z)
				if (heightDiff > 40 and heightAwareVisible(npc, enemy)) then
					npc:UpdateEnemyMemory(enemy, enemy:GetPos())
				end
				continue
			end

			-- No enemy: use BecomeHostile (the SNPC's own API) for players at height diffs
			if (not npc.BecomeHostile) then continue end
			if (npc.IsCurrentlyBusy) then continue end

			local npcPos = npc:GetPos()

			for _, ply in ipairs(player.GetAll()) do
				if (not IsValid(ply) or not ply:Alive()) then continue end
				if (ply:GetMoveType() == MOVETYPE_NOCLIP) then continue end

				local plyPos = ply:GetPos()
				local heightDiff = math.abs(plyPos.z - npcPos.z)
				if (heightDiff < 40) then continue end

				local dist2D = npcPos:Distance2D(plyPos)
				if (dist2D > (cfg.peneDist or 2500)) then continue end

				if (not heightAwareVisible(npc, ply)) then continue end

				-- Check the SNPC's own disposition — only aggro neutrals
				if (npc.RegisteredEnts and npc.RegisteredEnts[ply] == D_HT) then
					-- Already hostile but lost enemy — re-acquire
					npc:UpdateEnemyMemory(ply, ply:GetPos())
					npc:SetEnemy(ply)
					break
				end

				-- BecomeHostile handles all internal state (RegisteredEnts, relationship, etc.)
				npc:BecomeHostile(ply)
				break
			end
		end
	end)
end
