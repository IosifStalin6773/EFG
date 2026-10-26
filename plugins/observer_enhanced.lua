
PLUGIN.name = "Observer Enhanced"
PLUGIN.author = "Iosif Stalin#6773"
PLUGIN.description = "Añade un sistema avanzado en el modo observador."

CAMI.RegisterPrivilege({
	Name = "Helix - Observer",
	MinAccess = "admin"
})

CAMI.RegisterPrivilege({
	Name = "Helix - Observer Extra ESP",
	MinAccess = "superadmin"
})

ix.option.Add("observerTeleportBack", ix.type.bool, true, {
	bNetworked = true,
	category = "observer",
	hidden = function()
		return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
	end
})

if (CLIENT) then
	ix.option.Add("observerESP", ix.type.bool, true, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("itemESP", ix.type.bool, true, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("trashESP", ix.type.bool, false, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("connectorESP", ix.type.bool, false, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("npcESP", ix.type.bool, false, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("lootESP", ix.type.bool, true, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	ix.option.Add("observerLight", ix.type.bool, true, {
		category = "observer",
		hidden = function()
			return !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
		end
	})

	local dimDistance = 1024
	local aimLength = 128
	local barHeight = 2
	local espcol = Color(255,255,255,255)
	local espcols = {
		["Оружие"] = Color(255,78,69),
		["Боеприпасы"] = Color(255,78,69),
		["Медицина"] = Color(138,200,97),
		["Ремесло"] = Color(255,204,0)
	}

	function PLUGIN:HUDPaint()
		local client = LocalPlayer()

		if (ix.option.Get("observerESP", true) and client:GetMoveType() == MOVETYPE_NOCLIP and
			!client:InVehicle() and CAMI.PlayerHasAccess(client, "Helix - Observer", nil)) then
			local scrW, scrH = ScrW(), ScrH()

			for _, v in ipairs(player.GetAll()) do
				if (v == client or !v:GetCharacter() or client:GetAimVector():Dot((v:GetPos() - client:GetPos()):GetNormal()) < 0.65) then
					continue
				end

				local screenPosition = v:GetPos():ToScreen()
				local aimPosition = (v:GetPos() + v:GetAimVector() * aimLength):ToScreen()

				local marginX, marginY = scrH * .1, scrH * .1
				local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
				local aimX, aimY = math.Clamp(aimPosition.x, marginX, scrW - marginX), math.Clamp(aimPosition.y, marginY, scrH - marginY)

				local teamColor = team.GetColor(v:Team())
				local distance = client:GetPos():Distance(v:GetPos())
				local factor = 1 - math.Clamp(distance / dimDistance, 0, 1)
				local size = math.max(10, 32 * factor)
				local alpha = math.max(255 * factor, 80)
				local aimAlpha = (1 - factor * 1.5) * 80

				surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, alpha)
				surface.SetFont("ixGenericFont")

				local text = v:Name()
				if (ix.fights and v:GetCharacter():GetFight() and v:GetCharacter():GetFight() != 0) then
					text = text.." - FF:"..(v:GetCharacter():GetFight() % 100)
				end
				local textWidth, textHeight = surface.GetTextSize(text)
				local barWidth = math.Clamp((v:Health() / v:GetMaxHealth()) * textWidth, 0, textWidth)

				surface.DrawRect(x - size / 2, y - size / 2, size, size)

				-- we can assume that if we're using cheap blur, we'd want to save some fps here
				if (!ix.option.Get("cheapBlur", false)) then
					local data = {}
					data.start = client:EyePos()
					data.endpos = v:EyePos()
					data.filter = {client, v}

					if (util.TraceLine(data).Hit) then
						aimAlpha = alpha
					else
						aimAlpha = (1 - factor * 4) * 80
					end
				end

				if (aimPosition.visible) then
					surface.SetDrawColor(teamColor.r * 1.2, teamColor.g * 1.2, teamColor.b * 1.2, aimAlpha)
					surface.DrawLine(x, y, aimX, aimY)
					surface.DrawLine(x, y + 1, aimX, aimY + 1)
				end

				surface.SetDrawColor(teamColor.r * 1.6, teamColor.g * 1.6, teamColor.b * 1.6, alpha)
				surface.DrawRect(x - barWidth / 2, y - size - textHeight / 2, barWidth, barHeight)

				ix.util.DrawText(text, x, y - size, ColorAlpha(teamColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, alpha)
			end

			if (CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer Extra ESP", nil) and (ix.option.Get("itemESP") or ix.option.Get("trashESP") or ix.option.Get("connectorESP") or ix.option.Get("npcESP") or ix.option.Get("lootESP"))) then
				local espRangeSq = (dimDistance * 3) * (dimDistance * 3)
				local espClientPos = client:GetPos()
				for _, v in pairs(ents.GetAll()) do
					if (espClientPos:DistToSqr(v:GetPos()) > espRangeSq) then continue end
					if (v:GetClass() == "ix_item" and ix.option.Get("itemESP")) then
						local screenPosition = v:GetPos():ToScreen()
						local marginX, marginY = scrH * .1, scrH * .1
						local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
						local factor = 1 - math.Clamp(client:GetPos():Distance(v:GetPos()) / dimDistance, 0, 1)
						local itemTable = v:GetItemTable()

						ix.util.DrawText(itemTable.name, x, y - math.max(10, 32 * factor), espcols[itemTable.category] or espcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, math.max(255 * factor, 80))
					elseif (v:GetClass() == "ix_connector" and ix.option.Get("connectorESP")) then
						local screenPosition = v:GetPos():ToScreen()
						local marginX, marginY = scrH * .1, scrH * .1
						local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
						local factor = 1 - math.Clamp(client:GetPos():Distance(v:GetPos()) / dimDistance, 0, 1)

						ix.util.DrawText(
							"Server Connector",
							x,
							y - math.max(10, 32 * factor),
							Color(128, 0, 128),
							TEXT_ALIGN_CENTER,
							TEXT_ALIGN_CENTER,
							nil,
							math.max(255 * factor, 80)
						)
					elseif (v:GetClass() == "ix_trashspawner" and ix.option.Get("trashESP")) then
						local screenPosition = v:GetPos():ToScreen()
						local marginX, marginY = scrH * .1, scrH * .1
						local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
						local factor = 1 - math.Clamp(client:GetPos():Distance(v:GetPos()) / dimDistance, 0, 1)
						local text = ""
						local nextSpawn = v:GetNetVar("ixNextTrashSpawn")
						if (nextSpawn) then
							if (nextSpawn == -1) then
								text = " (x)"
							elseif (nextSpawn > 0) then
								local timeLeft = nextSpawn - CurTime()
								if (timeLeft <= 60) then
									text = " (<1m)"
								else
									text = " ("..math.Round(timeLeft / 60).."m)"
								end
							end
						end
						ix.util.DrawText(
							"Точка мусора"..text,
							x,
							y - math.max(10, 32 * factor),
							Color(120,0,240),
							TEXT_ALIGN_CENTER,
							TEXT_ALIGN_CENTER,
							nil,
							math.max(255 * factor, 80)
						)
					elseif (v:IsNPC() and ix.option.Get("npcESP")) then
						local screenPosition = v:GetPos():ToScreen()
						local marginX, marginY = scrH * .1, scrH * .1
						local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
						local factor = 1 - math.Clamp(client:GetPos():Distance(v:GetPos()) / dimDistance, 0, 1)

						ix.util.DrawText(
							v:GetClass(),
							x,
							y - math.max(10, 32 * factor),
							Color(255, 0, 128),
							TEXT_ALIGN_CENTER,
							TEXT_ALIGN_CENTER,
							nil,
							math.max(255 * factor, 80)
						)
					elseif (v:GetClass() == "ix_loot" and ix.option.Get("lootESP")) then
						local screenPosition = v:GetPos():ToScreen()
						local marginX, marginY = scrH * .1, scrH * .1
						local x, y = math.Clamp(screenPosition.x, marginX, scrW - marginX), math.Clamp(screenPosition.y, marginY, scrH - marginY)
						local factor = 1 - math.Clamp(client:GetPos():Distance(v:GetPos()) / dimDistance, 0, 1)
						local tierID = v:GetNetVar("tier", "t1")
						local tierDef = ix.loot.GetTierData(tierID)
						local tierName = tierDef and tierDef.name or tierID
						local tierCol = ix.loot.GetTierColor(tierID)

						ix.util.DrawText(
							v:GetNetVar("name", "?") .. " [" .. tierName .. "]",
							x,
							y - math.max(10, 32 * factor),
							tierCol,
							TEXT_ALIGN_CENTER,
							TEXT_ALIGN_CENTER,
							nil,
							math.max(255 * factor, 80)
						)
					end
				end
			end

			hook.Run("DrawESP")
		end
	end

	function PLUGIN:ShouldPopulateEntityInfo(entity)
		if (IsValid(entity)) then
			if ((entity:IsPlayer() or IsValid(entity:GetNetVar("player"))) and entity:GetMoveType() == MOVETYPE_NOCLIP) then
				return false
			end
		end
	end

	function PLUGIN:DrawPhysgunBeam(client, physgun, enabled, target, bone, hitPos)
		if (client != LocalPlayer() and client:GetMoveType() == MOVETYPE_NOCLIP) then
			return false
		end
	end

	function PLUGIN:PrePlayerDraw(client)
		if (client:GetMoveType() == MOVETYPE_NOCLIP and !client:InVehicle()) then
			return true
		end
	end

	local _obsLight = nil

	hook.Add("Think", "observerEnhanced_Light", function()
		local client = LocalPlayer()
		if (!IsValid(client)) then return end

		local active = ix.option.Get("observerLight", true) and
		               client:GetMoveType() == MOVETYPE_NOCLIP and
		               !client:InVehicle()

		if (active) then
			if (!_obsLight) then
				_obsLight = ProjectedTexture()
				_obsLight:SetTexture("effects/flashlight/soft")
				_obsLight:SetFOV(150)
				_obsLight:SetFarZ(800)
				_obsLight:SetBrightness(2)
				_obsLight:SetNearZ(8)
				_obsLight:SetColor(Color(255, 245, 210))
			end
			_obsLight:SetPos(client:EyePos())
			_obsLight:SetAngles(client:EyeAngles())
			_obsLight:Update()
		else
			if (_obsLight) then
				_obsLight:Remove()
				_obsLight = nil
			end
		end
	end)
else
	ix.log.AddType("observerEnter", function(client, ...)
		return string.format("%s entered observer.", client:Name())
	end)

	ix.log.AddType("observerExit", function(client, ...)
		if (ix.option.Get(client, "observerTeleportBack", true)) then
			return string.format("%s exited observer.", client:Name())
		else
			return string.format("%s exited observer at their location.", client:Name())
		end
	end)

	function PLUGIN:CanPlayerEnterObserver(client)
		if (CAMI.PlayerHasAccess(client, "Helix - Observer", nil)) then
			return true
		end
	end

	function PLUGIN:CanPlayerEnterVehicle(client, vehicle, role)
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then
			return false
		end
	end

	function PLUGIN:PlayerNoClip(client, state)
		if (hook.Run("CanPlayerEnterObserver", client)) then
			if (state) then
				client.ixObsData = {client:GetPos(), client:EyeAngles()}

				-- Hide them so they are not visible.
				client:SetNoDraw(true)
				client:SetNotSolid(true)
				client:DrawWorldModel(false)
				client:DrawShadow(false)
				client:GodEnable()
				client:SetNoTarget(true)

				hook.Run("OnPlayerObserve", client, state)
			else
				if (client.ixObsData) then
					-- Move they player back if they want.
					if (ix.option.Get(client, "observerTeleportBack", true)) then
						local position, angles = client.ixObsData[1], client.ixObsData[2]

						-- Do it the next frame since the player can not be moved right now.
						timer.Simple(0, function()
							client:SetPos(position)
							client:SetEyeAngles(angles)
							client:SetVelocity(Vector(0, 0, 0))
						end)
					end

					client.ixObsData = nil
				end

				-- Make the player visible again.
				client:SetNoDraw(false)
				client:SetNotSolid(false)
				client:DrawWorldModel(true)
				client:DrawShadow(true)
				client:GodDisable()
				client:SetNoTarget(false)

				hook.Run("OnPlayerObserve", client, state)
			end

			return true
		end
	end

	function PLUGIN:OnPlayerObserve(client, state)
		if (state) then
			ix.log.Add(client, "observerEnter")
		else
			ix.log.Add(client, "observerExit")
		end
	end
end
