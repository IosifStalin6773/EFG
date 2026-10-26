
hook.Add("LoadFonts", "nutCW3D2D", function(font, genericFont)
	surface.CreateFont("CW_HUD72", {font = font, extended = true, size = 72, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD60", {font = font, extended = true, size = 60, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD52", {font = font, extended = true, size = 52, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD48", {font = font, extended = true, size = 48, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD40", {font = font, extended = true, size = 40, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD38", {font = font, extended = true, size = 38, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD36", {font = font, extended = true, size = 36, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD32", {font = font, extended = true, size = 32, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD28", {font = font, extended = true, size = 28, weight = 700, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD24", {font = font, extended = true, size = 24, weight = 500, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD22", {font = font, extended = true, size = 22, weight = 500, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD20", {font = font, extended = true, size = 20, weight = 500, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD16", {font = font, extended = true, size = 16, weight = 500, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD14", {font = font, extended = true, size = 14, weight = 500, blursize = 0, antialias = true, shadow = false})
	surface.CreateFont("CW_HUD12", {font = font, extended = true, size = 12, weight = 500, blursize = 0, antialias = true, shadow = false})
end)

local function CW20_HUD_REPLACEMENT()
		local translated = {
			["ar2"] = true,
			["ar2altfire"] = true,
			["pistol"] = true,
			["smg1"] = true,
			["357"] = true,
			["xbowbolt"] = true,
			["buckshot"] = true,
			["rpg_round"] = true,
			["smg1_grenade"] = true,
			["grenade"] = true,
			["slam"] = true,
			["alyxgun"] = true,
			["sniperround"] = true,
			["sniperpenetratedround"] = true,
			["thumper"] = true,
			["gravity"] = true,
			["battery"] = true,
			["gaussenergy"] = true,
			["combinecannon"] = true,
			["airboatgun"] = true,
			["striderminigun"] = true,
			["helicoptergun"] = true,
			["9mmround"] = true,
			["mp5_grenade"] = true,
			["hornet"] = true,
			["striderminigundirect"] = true,
			["combineheavycannon"] = true,
		}

		surface.CreateFont("CW_KillIcons", {font = "csd", extended = true, size = ScreenScale(20), weight = 500, blursize = 0, antialias = true, shadow = false})
		surface.CreateFont("CW_SelectIcons", {font = "csd", extended = true, size = ScreenScale(60), weight = 500, blursize = 0, antialias = true, shadow = false})

		surface.CreateFont("CW_KillIcons2", {font = "HalfLife2", extended = true, size = ScreenScale(30), weight = 500, blursize = 0, antialias = true, shadow = false})
		surface.CreateFont("CW_SelectIcons2", {font = "HalfLife2", extended = true, size = ScreenScale(60), weight = 500, blursize = 0, antialias = true, shadow = false})

		local SWEP = weapons.GetStored("cw_base")
			
		local Deploy, UnDeploy = surface.GetTextureID("cw2/gui/bipod_deploy"), surface.GetTextureID("cw2/gui/bipod_undeploy")
		local deployedOnObject = surface.GetTextureID("cw2/gui/deployonobject")
		local scopeTemplate = surface.GetTextureID("cw2/gui/scope_template")

		SWEP.CrossAmount = 0
		SWEP.CrossAlpha = 255
		SWEP.FadeAlpha = 0
		SWEP.AimTime = 0

		local ClumpSpread = surface.GetTextureID("cw2/gui/clumpspread_ring")
		local Bullet = surface.GetTextureID("cw2/gui/bullet")
		local GLCrosshair = surface.GetTextureID("cw2/gui/crosshair_gl")
		local Vignette = surface.GetTextureID("cw2/effects/vignette")

		local White, Black = Color(255, 255, 255, 255), Color(0, 0, 0, 255)
		local x, y, x2, y2, lp, size, FT, CT, tr, x3, x4, y3, y4, UCT, sc1, sc2
		local td = {}

		local surface = surface
		local math = math
		local draw = draw
		local dst = draw.SimpleText

		SWEP.HUD_BreathAlpha = 1

		function draw.ShadowText(text, font, x, y, colortext, colorshadow, dist, xalign, yalign)
			dst(text, font, x + dist, y + dist, colorshadow, xalign, yalign)
			dst(text, font, x, y, colortext, xalign, yalign)
		end

		-- pre-define strings to not generate them every frame and make life unbearable for gc
		local cwhud24 = "CW_HUD24"
		local cwhud22 = "CW_HUD22"
		local cwhud20 = "CW_HUD20"
		local cwhud16 =	"CW_HUD16"
		local cwhud14 = "CW_HUD14"
		local bullet = surface.GetTextureID("cw2/gui/bullet")

		local Vec0, Ang0 = Vector(0, 0, 0), Angle(0, 0, 0)
		local TargetPos, TargetAng, cos1, sin1, tan, ws, rs, mod, EA, delta, sin2, mul, vm, muz, muz2, tr, att, CT
		local td = {}
		local LerpVector, LerpAngle, Lerp = LerpVector, LerpAngle, Lerp

		local reg = debug.getregistry()
		local GetVelocity = reg.Entity.GetVelocity
		local Length = reg.Vector.Length
		local Right = reg.Angle.Right
		local Up = reg.Angle.Up
		local Forward = reg.Angle.Forward
		local RotateAroundAxis = reg.Angle.RotateAroundAxis
		local GetBonePosition = reg.Entity.GetBonePosition

		-- El contador 3D junto al arma queda suprimido: el HUD propio del schema
		-- ya muestra la munición en el panel inferior-derecho.
		function SWEP:draw3D2DHUD()
			return
		end

		

		function SWEP:DrawHUD()
			FT, CT, x, y = FrameTime(), CurTime(), ScrW(), ScrH()
			UCT = UnPredictedCurTime()
			
			if self.dt.State == CW_AIMING then
				-- if we have M203 mode enabled, but have no rounds in it, OR if we don't have M203 enabled, let us draw the overlays
				if (self.dt.M203Active and (not self.M203Chamber or CustomizableWeaponry.grenadeTypes:canUseProperSights(self.Grenade40MM))) or not self.dt.M203Active then
					local simpleTelescopics = not self:canUseComplexTelescopics()
					
					local hasZoom = (self.SimpleTelescopicsFOV)
					local canUseSimpleTelescopics = (simpleTelescopics and hasZoom)
					
					if UCT > self.AimTime or self.InstantDissapearOnAim then
						if self.DrawBlackBarsOnAim or canUseSimpleTelescopics then
							surface.SetDrawColor(0, 0, 0, 255)
							
							if self.ScaleOverlayToScreenHeight then
								x3 = (x - y) / 2
								y3 = y / 2
								x4 = x - x3
								y4 = y - y3
								
								surface.DrawRect(0, 0, x3, y)
								surface.DrawRect(x4, 0, x3, y)
							else
								x3 = (x - 1024) / 2
								y3 = (y - 1024) / 2
								x4 = x - x3
								y4 = y - y3
								
								surface.DrawRect(0, 0, x3, y)
								surface.DrawRect(x4, 0, x3, y)
								surface.DrawRect(0, 0, x, y3)
								surface.DrawRect(0, y4, x, y3)
							end
						end
					end
					
					if self.AimOverlay or canUseSimpleTelescopics then
						if UCT > self.AimTime or self.InstantDissapearOnAim then
							surface.SetDrawColor(255, 255, 255, 255)
							
							if canUseSimpleTelescopics then
								surface.SetTexture(scopeTemplate)
								surface.DrawTexturedRect(x * 0.5 - 512, y * 0.5 - 512, 1024, 1024)
							else
								surface.SetTexture(self.AimOverlay)
							end
							
							if self.StretchOverlayToScreen then
								if canUseSimpleTelescopics then
									for k, v in ipairs(self.ZoomTextures) do
										if v.color then
											surface.SetDrawColor(v.color)
										else
											surface.SetDrawColor(255, 255, 255, 255)
										end
										
										surface.SetTexture(v.tex)
										surface.DrawTexturedRect(v.offset[1], v.offset[2], x, y)
									end
								else
									surface.DrawTexturedRect(0, 0, x, y)
								end
								
							elseif self.ScaleOverlayToScreenHeight then
								if canUseSimpleTelescopics then
									for k, v in ipairs(self.ZoomTextures) do
										surface.SetTexture(v.tex)
										surface.DrawTexturedRect(x * 0.5 - y * 0.5 + v.offset[1], y * 0.5 - y * 0.5 + v.offset[2], y, y)
									end
								else
									surface.DrawTexturedRect(x * 0.5 - y * 0.5, y * 0.5 - y * 0.5, y, y)
								end
							else
								if canUseSimpleTelescopics then
									for k, v in ipairs(self.ZoomTextures) do
										local xSize, ySize = 1024, 1024
										
										if v.size then
											xSize, ySize = v.size[1], v.size[2]
										end
										
										
										if v.color then
											surface.SetDrawColor(v.color)
										else
											surface.SetDrawColor(255, 255, 255, 255)
										end
										
										surface.SetTexture(v.tex)
										surface.DrawTexturedRect(x * 0.5 - xSize * 0.5 + v.offset[1], y * 0.5 - ySize * 0.5 + v.offset[2], xSize, ySize)
									end
								else
									surface.DrawTexturedRect(x * 0.5 - 512, y * 0.5 - 512, 1024, 1024)
								end
							end
						end
					end
					
					if self.FadeDuringAiming or canUseSimpleTelescopics then
						if UCT < self.AimTime then
							self.FadeAlpha = math.Approach(self.FadeAlpha, 255, FT * 1500)
						else
							self.FadeAlpha = LerpCW20(FT * 10, self.FadeAlpha, 0)
						end
						
						surface.SetDrawColor(0, 0, 0, self.FadeAlpha)
						surface.DrawRect(0, 0, x, y)
					end
				end
			else
				self.FadeAlpha = 0
			end
			
			if not self.dt.BipodDeployed then 
				if self.BipodInstalled then
					if self:CanRestWeapon(self.BipodDeployHeightRequirement) then
						-- lang: cwUse = "[USE]", 
						draw.ShadowText(L"cwUse", cwhud24, x / 2, y / 2 + 100, White, Black, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						
						surface.SetTexture(Deploy)
						
						surface.SetDrawColor(0, 0, 0, 255)
						surface.DrawTexturedRect(x / 2 - 47, y / 2 + 126, 96, 96)
						
						surface.SetDrawColor(255, 255, 255, 255)
						surface.DrawTexturedRect(x / 2 - 48, y / 2 + 125, 96, 96)
					end
				else
					if self.dt.State == CW_AIMING then
						if self.CanRestOnObjects then
							if self:CanRestWeapon(self.WeaponRestHeightRequirement) then
								surface.SetTexture(deployedOnObject)
								
								surface.SetDrawColor(0, 0, 0, 255)
								surface.DrawTexturedRect(x / 2 - 47, y / 2 + 150, 96, 96)
								
								surface.SetDrawColor(255, 255, 255, 255)
								surface.DrawTexturedRect(x / 2 - 48, y / 2 + 150, 96, 96)
							end
						end
					end
				end
			else
				draw.ShadowText(L"cwUse", cwhud24, x / 2, y / 2 + 100, White, Black, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					
				surface.SetTexture(UnDeploy)
					
				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawTexturedRect(x / 2 - 47, y / 2 + 126, 96, 96)
					
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(x / 2 - 48, y / 2 + 125, 96, 96)
			end
			
			if self.AimBreathingEnabled then
				self.HUD_BreathAlpha = LerpCW20(FT * 10, self.HUD_BreathAlpha, (1 - self.BreathLeft))

				if self.BreathLeft < 1 then
					surface.SetDrawColor(0, 0, 0, 255 * self.HUD_BreathAlpha)
					surface.SetTexture(Vignette)
					surface.DrawTexturedRect(0, 0, x, y)
				end
				
				if self.dt.State == CW_AIMING then
					if self.Owner:GetVelocity():Length() < self.BreathHoldVelocityMinimum then
						local finalColorMain = White
						local finalColorSecondary = White
						
						if self.noBreathHoldingUntilKeyRelease then
							finalColorMain = self.HUDColors.deepRed
						end
						
						if not self.holdingBreath and self.BreathLeft < 0.5 then
							finalColorSecondary = self.HUDColors.red
						end
						
						-- lang: cwStablize = "%s - Stabilize",
						draw.ShadowText(L("cwStablize", self:getKeyBind("+speed")), cwhud24, x / 2, y / 2 + 120, finalColorMain, Black, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.ShadowText(math.Round(self.BreathLeft * 100) .. "%", cwhud24, x / 2, y / 2 + 140, finalColorSecondary, Black, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				else
					if self.holdingBreath then
						self:stopHoldingBreath(nil, nil, 0)
					end
				end
			end
		end
end
timer.Simple(1, CW20_HUD_REPLACEMENT)
