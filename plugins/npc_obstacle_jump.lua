PLUGIN.name   = "NPC Obstacle Jump"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.schema = "Any"

-- NPCs matching these prefixes will jump over obstacles to reach enemies
local JumpNPCs = {
	["npc_nosach"] = true,
	["npc_murzik"] = true,
	["npc_churzik"] = true,
}

local function shouldJump(npc)
	for prefix in pairs(JumpNPCs) do
		if (string.find(npc:GetClass(), prefix, 1, true) == 1) then
			return true
		end
	end
	return false
end

local function doJump(npc, targetPos, data)
	local npcPos = npc:GetPos()
	local dir = (targetPos - npcPos)
	dir.z = 0
	dir:Normalize()

	local trWall = util.TraceLine({
		start = npcPos + Vector(0, 0, 10),
		endpos = npcPos + Vector(0, 0, 10) + dir * 80,
		filter = npc,
	})

	if (not trWall.Hit) then return false end

	local trTop = util.TraceLine({
		start = trWall.HitPos + Vector(0, 0, 200),
		endpos = trWall.HitPos + Vector(0, 0, -10),
		filter = npc,
	})

	if (not trTop.Hit) then return false end

	local jumpHeight = trTop.HitPos.z - npcPos.z
	if (jumpHeight < 20 or jumpHeight > 250) then return false end

	local landingPos = trTop.HitPos + dir * 60
	local gravity = 600
	local height = jumpHeight + 50

	local speed = math.sqrt(2 * gravity * height)
	local time = speed / gravity
	time = time + math.sqrt(2 * 50 / gravity)

	local vecJumpVel = (landingPos - npcPos) / time
	vecJumpVel.z = speed

	-- MOVETYPE_FLY so MOVETYPE_STEP doesn't kill the velocity mid-air
	npc:SetMoveType(MOVETYPE_FLY)
	npc:SetGroundEntity(nil)
	npc:SetLocalVelocity(vecJumpVel)

	local pushDir = dir * 300
	local pushID = "npc_jump_push_" .. npc:EntIndex()
	timer.Create(pushID, 0.05, 60, function()
		if (not IsValid(npc)) then
			timer.Remove(pushID)
			return
		end

		-- Manual gravity since MOVETYPE_FLY has none
		local vel = npc:GetVelocity()
		vel.x = pushDir.x
		vel.y = pushDir.y
		vel.z = vel.z - (600 * 0.05)
		npc:SetLocalVelocity(vel)

		-- Detect landing
		local tr = util.TraceLine({
			start = npc:GetPos() + Vector(0, 0, 5),
			endpos = npc:GetPos() - Vector(0, 0, 10),
			filter = npc,
		})

		if (tr.Hit and vel.z < 0) then
			npc:SetPos(tr.HitPos)
			npc:SetMoveType(MOVETYPE_STEP)
			npc:SetLocalVelocity(Vector(0, 0, 0))
			timer.Remove(pushID)
		end
	end)

	data.stuckTime = 0
	data.nextJump = CurTime() + 3

	print("[NPC Jump] " .. npc:GetClass() .. " jumped obstacle (height=" .. math.Round(jumpHeight) .. ")")
	return true
end

if (SERVER) then
	local TrackedNPCs = {}

	hook.Add("OnEntityCreated", "npc_obstacle_jump", function(ent)
		timer.Simple(0.1, function()
			if (not IsValid(ent)) then return end
			if (not ent:IsNPC()) then return end
			if (not shouldJump(ent)) then return end

			TrackedNPCs[ent] = {
				lastPos = ent:GetPos(),
				stuckTime = 0,
				nextJump = 0,
				lastEnemy = nil,
				lastEnemyPos = nil,
				lostAgroTime = 0,
			}
		end)
	end)

	hook.Add("EntityRemoved", "npc_obstacle_jump", function(ent)
		TrackedNPCs[ent] = nil
	end)

	hook.Add("Think", "npc_obstacle_jump", function()
		local curTime = CurTime()

		for npc, data in pairs(TrackedNPCs) do
			if (not IsValid(npc)) then
				TrackedNPCs[npc] = nil
				continue
			end

			if (curTime < data.nextJump) then continue end
			if (not npc:IsOnGround()) then
				data.stuckTime = 0
				continue
			end
			if (npc.IsCurrentlyBusy) then continue end

			local npcPos = npc:GetPos()
			local ene = npc:GetEnemy()

			-- Lost aggro: enemy was above and NPC dropped target
			if (not IsValid(ene)) then
				if (data.lastEnemyPos and data.lostAgroTime == 0) then
					local heightDiff = data.lastEnemyPos.z - npcPos.z
					if (heightDiff > 30) then
						data.lostAgroTime = curTime
					end
				end

				-- Jump toward last known position after losing aggro
				if (data.lostAgroTime > 0 and data.lastEnemyPos) then
					local waitTime = 0.3
					if (curTime - data.lostAgroTime > waitTime) then
						if (doJump(npc, data.lastEnemyPos, data)) then
							data.lostAgroTime = 0
							data.lastEnemyPos = nil
						elseif (IsValid(data.lastEnemy) and data.lastEnemy:Alive()) then
							-- Can't jump but last enemy still alive: re-acquire via SNPC API
							if (npc.BecomeHostile and npc.RegisteredEnts and npc.RegisteredEnts[data.lastEnemy] != D_HT) then
								npc:BecomeHostile(data.lastEnemy)
							else
								npc:UpdateEnemyMemory(data.lastEnemy, data.lastEnemy:GetPos())
								npc:SetEnemy(data.lastEnemy)
							end
							data.lostAgroTime = 0
						end
					end
				end

				data.stuckTime = 0
				continue
			end

			-- Has enemy: track it
			data.lastEnemy = ene
			data.lastEnemyPos = ene:GetPos()
			data.lostAgroTime = 0

			local enePos = ene:GetPos()
			local heightDiff = enePos.z - npcPos.z

			if (heightDiff < 30) then
				data.stuckTime = 0
				data.lastPos = npcPos
				continue
			end

			-- Detect if stuck — shorter threshold when target is above
			local moved = npcPos:Distance2D(data.lastPos)
			if (moved < 15) then
				data.stuckTime = data.stuckTime + FrameTime()
			else
				data.stuckTime = math.max(0, data.stuckTime - FrameTime())
			end
			data.lastPos = npcPos

			-- Lower stuck threshold for large height diffs (faster reaction)
			local stuckThreshold = heightDiff > 100 and 0.4 or 0.7
			if (data.stuckTime < stuckThreshold) then continue end

			doJump(npc, enePos, data)
		end
	end)
end
