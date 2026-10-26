PLUGIN.name = "Macro Weapon Register"
PLUGIN.author = "Black Tea (Edited by Taxin2012)"
PLUGIN.description = "Gun Jesus have arrived."

if (!CustomizableWeaponry) then return end

local function normalizeMods(mods)
	if (!mods) then return {} end
	local out = {}
	for k, v in pairs(mods) do
		out[tostring(k)] = v
	end
	return out
end

-- Munición realmente cargada ahora mismo: si el arma está equipada, el dato
-- item:GetData("ammo") es solo la última "foto" (se guarda al desequipar/OnSave),
-- no se actualiza en vivo mientras disparas/recargas. Mientras está en la mano,
-- la fuente de verdad es el propio arma (weapon:Clip1()).
local function GetLoadedAmmo(item)
	if (item:GetData("equip")) then
		local client = item.player

		if (IsValid(client)) then
			local weapon = client:GetWeapon(item.class)

			if (IsValid(weapon)) then
				return weapon:Clip1()
			end
		end
	end

	return item:GetData("ammo", 0)
end

/*
	MODIFICATION TUTORIAL
		- sh_config
		 This file contains ammo structure.
		- sh_languages
		 This file contains language sets for the weapons.
		- cl_cw3d2d
		 This file contains modification for CW 2.0 HUDs
		- sh_attachments
		 This file contains information and of attachment items.
*/

ix.util.Include("sh_configs.lua")
ix.util.Include("sh_languages.lua")
ix.util.Include("cl_cw3d2d.lua")
ix.util.Include("sh_worldattachments.lua")
ix.util.Include("sh_attachments.lua")
ix.util.Include("cl_iconedit.lua")

local function getWeaponDurability(client, weapon)
	if (not IsValid(client) or not IsValid(weapon)) then return 100 end
	local char = client:GetCharacter()
	if (not char) then return 100 end
	local inv = char:GetInventory()
	if (not inv) then return 100 end
	local class = weapon:GetClass():lower()
	-- Priorizar el ítem equipado (equip=true) por si hay duplicados del mismo tipo
	local fallback = nil
	for k, item in pairs(inv:GetItems()) do
		if (item.isCW and item.class == class) then
			if (item:GetData("equip") == true) then
				return item:GetData("durability", 100)
			end
			fallback = item
		end
	end
	return fallback and fallback:GetData("durability", 100) or 100
end

function PLUGIN:InitializedPlugins()
	--table.Merge(ix.lang.stored["korean"], self.koreanTranslation)
	table.Merge(ix.lang.stored["english"], self.englishTranslation)

	-- Create Items with Lua
	do
		-- ammunition
		for name, data in pairs(self.ammoInfo) do
			local uniqueID = "ammo_"..name:lower()
			local ammoInfo = data

			local ITEM = ix.item.Register(uniqueID, "base_ammo", nil, nil, true)
			ITEM.name = ammoInfo.name
			ITEM.category = "Municion"
			ITEM.ammo = name
			ITEM.ammoAmount = ammoInfo.amount or 30
			ITEM.price = ammoInfo.price or 200
			ITEM.model = ammoInfo.model or AMMO_BOX
			ITEM.width = ammoInfo.width or 1
			ITEM.isAmmo = true
			ITEM.height = 1

			if (CLIENT and ix.lang.stored["english"]) then
				ix.lang.stored["english"][uniqueID] = ammoInfo.name
			end

			function ITEM:GetDescription()
				local rounds = self:GetData("rounds", self.ammoAmount)
				return L("cwAmmoDesc", rounds, self.ammoAmount)
			end

			-- La munición es fisicalizada: las reservas se gestionan automáticamente.
			-- Eliminar la función "Load" heredada de base_ammo para que no aparezca en el inventario.
			ITEM.functions.use = nil

			-- Arrastrar un cargador parcial sobre otro del mismo calibre transfiere las
			-- balas que quepan, para no ocupar varios huecos con cargadores a medias.
			ITEM.functions.combine = {
				OnRun = function(item, data)
					local other = ix.item.instances[data[1]]

					if (!other or !other.isAmmo or other.ammo != item.ammo) then
						return false
					end

					local itemRounds  = item:GetData("rounds", item.ammoAmount)
					local otherRounds = other:GetData("rounds", other.ammoAmount)
					local space       = item.ammoAmount - itemRounds

					if (space <= 0 or otherRounds <= 0) then
						return false
					end

					local transfer = math.min(space, otherRounds)

					item:SetData("rounds", itemRounds + transfer)

					local remaining = otherRounds - transfer

					if (remaining <= 0) then
						other:Remove()
					else
						other:SetData("rounds", remaining)
					end

					if (item.player) then
						item.player:EmitSound("items/ammo_pickup.wav", 60)
					end

					return false
				end,
				OnCanRun = function(item, data)
					if (IsValid(item.entity)) then return false end

					local other = ix.item.instances[data[1]]

					if (!other or other == item or !other.isAmmo or other.ammo != item.ammo) then
						return false
					end

					local itemRounds = item:GetData("rounds", item.ammoAmount)

					return itemRounds < item.ammoAmount and other:GetData("rounds", other.ammoAmount) > 0
				end
			}
		end

		-- they were ass.
		local assWeapons = {
			["cw_ber_cz75"] = "muzzleflash_6",
			["cw_ber_deagletoast"] = "muzzleflash_6",
			["cw_ber_fnp45"] = "muzzleflash_6",
			["cw_ber_m9"] = "muzzleflash_6",
			["cw_ber_p220"] = "muzzleflash_6",
			["cw_ber_model620"] = "muzzleflash_6",
			["cw_ber_usp"] = "muzzleflash_6",
		}

		for k, v in ipairs(weapons.GetList()) do
			local class = v.ClassName
			local prefix

			if (class:find("cw_")) then
				prefix = "cw_"
			elseif (class:find("ma85_")) then
				prefix = "ma85_"
			end
			
			if (prefix and !class:find("base")) then
				-- Configure Weapon's Variables
				v.CanRicochet = false
				v.isGoodWeapon = true
				v.canPenetrate = function() return false end
				v.canRicochet = function() return false end
				--v.MuzzleEffect = "muzzleflash_ak74" -- lol jk
				v.Primary.DefaultClip = 0

				--[[if v.WMAng and v.WMPos then
					if not v.IsFixed then
						v.WMAng = Vector(4, -8, 0)
					elseif v.IsFixed then
						v.WMPos = Vector(-1, 1.5, -2)
						v.WMAng = Vector(35, -5, -5)
					elseif v.IsFixed2 then
						v.WMAng = Vector(0, 170, 0)
					elseif v.IsFixed3 then
						v.WMPos = Vector(-2, -1, -2.1)
						v.WMAng = Vector(0, -90, 0)
					end
				end]]

				if v.AddSafeMode then
					v.AddSafeMode = false
				end

				if v.Primary.Ammo and self.changeAmmo[ v.Primary.Ammo ] then
					v.Primary.Ammo = self.changeAmmo[ v.Primary.Ammo ]
				end

				-- El Ventil pasa a usar munición de francotirador, sea cual sea su calibre nativo.
				if (class:find("ventil")) then
					v.Primary.Ammo = "sniperround"
				end

				v.VelocitySensitivity = 2

				if (v.MaxSpreadInc) then
					if (!v.neat_MaxSpreadInc) then
						v.neat_MaxSpreadInc = v.MaxSpreadInc
					end
					v.MaxSpreadInc = ((v.neat_MaxSpreadInc or v.MaxSpreadInc) or 0.1) * 3 
				end
				
				if (v.SpreadPerShot) then
					if (!v.neat_SpreadPerShot) then
						v.neat_SpreadPerShot  = v.SpreadPerShot or 0.1
					end

					v.SpreadPerShot = (v.neat_SpreadPerShot or v.SpreadPerShot) * 10

					if (v.FireDelay) then
						v.SpreadCooldown = (v.FireDelay or 0)*0.3
					end
					v.AddSpreadSpeed = v.SpreadPerShot*5
				end

				-- lol fuck you
				function v:detachSpecificAttachment(attachmentName)
					-- since we don't know the category, we'll just have to iterate over all attachments, find the one we want, and attach it there
					for category, data in pairs(self.Attachments) do
						for key, attachment in ipairs(data.atts) do
							if attachment == attachmentName then
								self:detach(category, key - 1, false)
							end
						end
					end
				end

				-- Compat VManip: cuando SWEP.UseHands=true, CW2 dibuja las manos del jugador
				-- como una entidad aparte bonemergeada a CW_VM (ver cl_model.lua:_drawViewModel).
				-- El bonemerge copia la pose de CW_VM en el instante en que se dibujan las
				-- manos, así que el gesto de VManip debe aplicarse ANTES de esa línea, no en
				-- el PostDrawViewModel normal (que corre después y llega demasiado tarde).
				if (CLIENT) then
					function v:_drawViewModel()
						if (self.ViewModelFlip) then
							render.CullMode(MATERIAL_CULLMODE_CW)
						end

						self.CW_VM:FrameAdvance(FrameTime())
						self.CW_VM:SetupBones()
						self.CW_VM:DrawModel()

						if (VManip) then
							VManip.UpdateAndApply(self.CW_VM, self.Owner, self)
						end

						if (self.UseHands) then
							local hands = self.Owner:GetHands()

							if (IsValid(hands)) then
								hands:SetParent(self.CW_VM)
								hands:AddEffects(EF_BONEMERGE)
								hands:DrawModel()
							end
						end

						if (self.ViewModelFlip) then
							render.CullMode(MATERIAL_CULLMODE_CCW)
						end

						self:drawAttachments()
						self:drawInteractionMenu()

						if (self.reticleFunc) then
							self.reticleFunc(self)
						end

						if (GetConVarNumber("cw_customhud_ammo") >= 1) then
							self:draw3D2DHUD()
						end
					end
				end

				-- A code to get rid of fucking movement/sway disability.
				function v:getFinalSpread(vel, maxMultiplier)
					maxMultiplier = maxMultiplier or 1
					
					local final = self.BaseCone
					local aiming = self.dt.State == CW_AIMING
					-- take the continuous fire spread into account
					final = final + self.AddSpread
					
					-- and the player's velocity * mobility factor
					
					if aiming then
						-- irl the accuracy of your weapon goes to shit when you start moving even if you aim down the sights, so when aiming, player movement will impact the spread even more than it does during hip fire
						-- but we're gonna clamp it to a maximum of the weapon's hip fire spread, so that even if you aim down the sights and move, your accuracy won't be worse than your hip fire spread
						final = math.min(final + (vel / 10000 * self.VelocitySensitivity) * self.AimMobilitySpreadMod, self.HipSpread)
					else
						final = final + (vel / 10000 * self.VelocitySensitivity)
					end
					
					if self.ShootWhileProne and self:isPlayerProne() then
						final = final + vel / 1000
					end
					
					-- lastly, return the final clamped value
					return math.Clamp(final, 0, 0.09 + self:getMaxSpreadIncrease(maxMultiplier))
				end

				function v:recalculateDamage()
					if not self.Damage_Orig then return end
						
					local mult = hook.Run("GetSchemaCWDamage", self, self.Owner) or 1

					self.Damage = self.Damage_Orig * self.DamageMult * mult
				end

				function v:recalculateRecoil()
					if not self.Recoil_Orig then return end

					local mult = hook.Run("GetSchemaCWRecoil", self, self.Owner) or 1

					self.Recoil = self.Recoil_Orig * self.RecoilMult * mult
				end

				function v:recalculateFirerate()
					if not self.FireDelay_Orig then return end

					local mult = hook.Run("GetSchemaCWFirerate", self, self.Owner) or 1

					self.FireDelay = self.FireDelay_Orig * self.FireDelayMult * mult
				end

				function v:recalculateVelocitySensitivity()
					if not self.VelocitySensitivity_Orig then return end

					local mult = hook.Run("GetSchemaCWVel", self, self.Owner) or 1

					self.VelocitySensitivity = self.VelocitySensitivity_Orig * self.VelocitySensitivityMult * mult
				end

				function v:recalculateAimSpread()
					if not self.AimSpread_Orig then return end

					local mult = hook.Run("GetSchemaCWAimSpread", self, self.Owner) or 1

					self.AimSpread = self.AimSpread_Orig * self.AimSpreadMult * mult
				end

				function v:recalculateHipSpread()
					if not self.HipSpread_Orig then return end

					local mult = hook.Run("GetSchemaCWHipSpread", self, self.Owner) or 1

					self.HipSpread = self.HipSpread_Orig * self.HipSpreadMult * mult
				end

				function v:recalculateDeployTime()
					if not self.DrawSpeed_Orig then return end

					local mult = hook.Run("GetSchemaCWDeployTime", self, self.Owner) or 1

					self.DrawSpeed = self.DrawSpeed_Orig * self.DrawSpeedMult * mult
				end

				function v:recalculateReloadSpeed()
					if not self.ReloadSpeed_Orig then return end

					local mult = hook.Run("GetSchemaCWReloadSpeed", self, self.Owner) or 1

					self.ReloadSpeed = self.ReloadSpeed_Orig * self.ReloadSpeedMult * mult
				end

				function v:recalculateMaxSpreadInc()
					if not self.MaxSpreadInc_Orig then return end

					local mult = hook.Run("GetSchemaCWMaxSpread", self, self.Owner) or 1

					self.MaxSpreadInc = self.MaxSpreadInc_Orig * self.MaxSpreadIncMult * mult
				end

				-- Solo generar ítem si el arma tiene entrada explícita en gunData (presets/sh_new.lua).
				local uniqueID   = string.Replace(class, prefix, ""):lower()
				local gunDataKey = prefix .. uniqueID
				local dat        = self.gunData[gunDataKey]

				if (dat) then
					local dataSlot = dat.slot or 2
					-- Tecla 1 → rifles (dat.slot=2), tecla 2 → pistolas (dat.slot=1), tecla 3 → pesadas (dat.slot=3)
					local keyRemap = { [2] = 0, [1] = 1, [3] = 2 }
					v.Slot = keyRemap[dataSlot] or dataSlot

					local ITEM = ix.item.Register(class:lower(), "base_weapons", nil, nil, true)
					ITEM.name          = dat.name or v.PrintName
					ITEM.price         = dat.price or 4000
					ITEM.exRender      = dat.exRender or false
					ITEM.iconCam       = dat.iconCam or self.modelCam[v.WorldModel:lower()]
					ITEM.class         = gunDataKey
					ITEM.isCW          = true
					ITEM.DoEquipSnd    = true
					ITEM.bDropOnDeath  = true
					ITEM.weight        = dat.weight or 3
					ITEM.model         = v.WorldModel
					ITEM.loreDesc      = dat.desc

					local slot = self.slotCategory[dataSlot]
					ITEM.width         = dat.width or 1
					ITEM.height        = dat.height or 1
					ITEM.weaponCategory = slot or "primary"
					ITEM.ammoType       = v.Primary.Ammo  -- tipo de munición ya remapeado por changeAmmo

					if (dat.DurCh) then ITEM.DurCh = dat.DurCh end

					ITEM:Hook("drop", function(item)
						item.player:EmitSound("volmos/mzone/interface/inv_drop.ogg", 80)
					end)

					function ITEM:OnEquipWeapon(client, weapon)
						if (SERVER and self:GetData("broken")) then
							timer.Simple(0, function()
								if (IsValid(client)) then
									client:StripWeapon(self.class)
									client:Notify("Esta arma está rota. Repárala antes de usarla.")
								end
							end)
						end
					end

					function ITEM:PaintOver(item, w, h)
						local x, y = w - 14, h - 14
						if item:GetData("equip") then
							surface.SetDrawColor(110, 255, 110, 100)
							surface.DrawRect(x, y, 8, 8)
							x = x - 8 * 1.6
						end
						if (table.Count(normalizeMods(item:GetData("mod", {}))) > 0) then
							surface.SetDrawColor(255, 255, 110, 100)
							surface.DrawRect(x, y, 8, 8)
							x = x - 8 * 1.6
						end
						if (item:GetData("durability")) then
							local tex    = tostring(item:GetData("durability"))
							surface.SetFont("ixChatFont")
							local wi, _ = surface.GetTextSize(tex)
							surface.SetTextColor(255, 255, 255, 255)
							surface.SetTextPos(w - (14 + wi), 14)
							surface.DrawText(tex)
						end
					end

					function ITEM:GetDescription()
						if (!self.entity or !IsValid(self.entity)) then
							local text = ""
							if (self.loreDesc) then
								text = self.loreDesc .. "\n\n"
							end
							text = text .. L("gunInfoDesc", L(v.Primary.Ammo)) .. "\n"
							text = text .. L("gunInfoStat", v.Damage, L(self.weaponCategory), v.Primary.ClipSize) .. "\n"
							if (self:GetData("broken")) then
								text = text .. "Condición: ROTA\n"
							elseif (self:GetData("durability")) then
								local dur = self:GetData("durability", 100)
								text = text .. "Condición: " .. dur .. "%"
							end
							local mods = normalizeMods(self:GetData("mod", {}))
							if (table.Count(mods) > 0) then
								local attText = ""
								for _, att1 in pairs(mods) do
									attText = attText .. "\n<color=39, 174, 96>" .. (att1[3] or "ERROR") .. "</color>"
								end
								text = text .. "\n\n" .. L("gunInfoAttachments", attText)
							end
							return text
						else
							return (self.loreDesc and (self.loreDesc .. "\n\n") or "") .. L("gunInfoDesc", L(v.Primary.Ammo))
						end
					end

					function ITEM:OnInstanced()
						if (self:GetData("durability") == nil) then
							self:SetData("durability", 100)
						end
					end

					ITEM.functions.use = {
						name = "Quitar Accesorio",
						tip  = "useTip",
						icon = "icon16/wrench.png",
						isMulti = true,
						multiOptions = function(item, client)
							local targets = {}
							for k, mod in pairs(normalizeMods(item:GetData("mod", {}))) do
								table.insert(targets, {name = mod[3] or "ERROR", data = {k}})
							end
							return targets
						end,
						OnCanRun = function(item)
							-- table.Count en lugar de # porque tras JSON las claves son strings
							if (table.Count(normalizeMods(item:GetData("mod", {}))) <= 0) then return false end
							local client = item.player
							if (not IsValid(client)) then return false end
							local char = client:GetCharacter()
							if (not char) then return false end
							local inv = char:GetInventory()
							if (not inv) then return false end
							return !IsValid(item.entity) and item.invID == inv:GetID()
						end,
						OnRun = function(item, data)
							local client = item.player
							if (data) then
								local char = client:GetCharacter()
								if (char) then
									local inv = char:GetInventory()
									if (inv) then
										local mods    = normalizeMods(item:GetData("mod", {}))
										local modKey  = tostring(data[1])
										local attData = mods[modKey]
										if (attData) then
											if (not inv:Add(attData[1])) then
												ix.item.Spawn(attData[1], client:GetPos())
											end
											local wepon = client:GetActiveWeapon()
											if (IsValid(wepon) and wepon:GetClass() == item.class) then
												wepon:detachSpecificAttachment(attData[2])
												if (wepon.recalculateStats) then
													wepon:recalculateStats()
													netstream.Start(client, "nutUpdateWeapon", wepon)
												end
											end
											mods[modKey] = nil
											item:SetData("mod", table.Count(mods) == 0 and nil or mods)
											for _, wep in pairs(client:GetWeapons()) do
												if (wep:GetClass() == item.class) then
													wep.attLoadedHash = nil
												end
											end

											-- Resincroniza los accesorios restantes al modelo de
											-- mundo (ver sh_worldattachments.lua).
											if (ix.cwsupport and ix.cwsupport.SyncWorldAttsForPlayer) then
												local attNames = {}
												for _, m in pairs(mods) do
													table.insert(attNames, m[2])
												end
												ix.cwsupport.SyncWorldAttsForPlayer(client, item.class, attNames)
											end

											client:EmitSound("stalkersound/inv_attach_addon.mp3")
										else
											client:NotifyLocalized("notAttachment")
										end
									end
								end
							else
								client:NotifyLocalized("detTarget")
							end
							return false
						end,
					}

					ITEM.functions.Repair = {
						name = "Reparar",
						tip  = "equipTip",
						icon = "icon16/bullet_wrench.png",
						OnRun = function(item)
							local client = item.player
							local char   = client:GetCharacter()
							if (not char) then return false end
							local inv = char:GetInventory()
							if (not inv) then return false end
							local itm = inv:HasItem("weptools")
							if (itm) then
								if (item:GetData("durability", 100) < 100) then
									itm:Remove()
									client:EmitSound("volmos/mzone/interface/inv_restorearm.ogg", 80)
									client:Notify('Reparaste "' .. item.name .. '" usando "' .. itm.name .. '"')
									item:SetData("durability", math.Clamp(60, 1, 100))
									item:SetData("broken", nil)
									local wepon = client:GetActiveWeapon()
									if (IsValid(wepon) and wepon:GetClass() == item.class and wepon.recalculateStats) then
										wepon:recalculateStats()
										netstream.Start(client, "nutUpdateWeapon", wepon)
									end
								else
									client:Notify("No puedes reparar un arma que no está rota")
								end
							else
								client:Notify("No tienes los materiales necesarios para reparar el arma")
							end
							return false
						end,
						OnCanRun = function(item)
							local client = item.player
							if (not IsValid(client)) then return false end
							local char = client:GetCharacter()
							if (not char) then return false end
							local inv = char:GetInventory()
							if (not inv) then return false end
							return !IsValid(item.entity) and item:GetData("equip") == true and
								hook.Run("CanPlayerUnequipItem", client, item) != false and
								item.invID == inv:GetID() and
								(not client.ixRagdoll or not client.ixRagdoll:IsValid())
						end,
					}

					-- Descargar el cargador: la munición que el arma tiene cargada
					-- (item:GetData("ammo"), la misma que se guarda al guardar el arma
					-- en base_weapons:Unequip) se convierte en un ítem de munición
					-- suelto en el inventario. Si el arma está en mano, también vacía
					-- el cargador real.
					ITEM.functions.Descargar = {
						name = "Descargar",
						tip  = "unloadTip",
						icon = "icon16/bullet_go.png",
						OnRun = function(item)
							local client = item.player
							local char   = client:GetCharacter()
							if (not char) then return false end
							local inv = char:GetInventory()
							if (not inv) then return false end

							local rounds = GetLoadedAmmo(item)
							if (rounds <= 0) then return false end

							local ammoUniqueID = "ammo_" .. tostring(item.ammoType):lower()
							local ammoItemTable = ix.item.list[ammoUniqueID]
							if (not ammoItemTable) then
								client:Notify("No se reconoce el tipo de munición de esta arma.")
								return false
							end

							if (item:GetData("equip")) then
								local weapon = client:GetWeapon(item.class)
								if (IsValid(weapon)) then
									weapon:SetClip1(0)
								end
							end

							item:SetData("ammo", 0)

							local maxStack = ammoItemTable.ammoAmount or 30
							local remaining = rounds

							while (remaining > 0) do
								local chunk = math.min(remaining, maxStack)

								if (not inv:Add(ammoUniqueID, 1, {rounds = chunk})) then
									ix.item.Spawn(ammoUniqueID, client:GetItemDropPos(), nil, nil, {rounds = chunk})
								end

								remaining = remaining - chunk
							end

							client:EmitSound("items/ammo_pickup.wav", 60)
							client:Notify("Descargaste " .. rounds .. " balas de \"" .. item.name .. "\".")

							return false
						end,
						OnCanRun = function(item)
							return !IsValid(item.entity) and GetLoadedAmmo(item) > 0
						end,
					}

					if (CLIENT) then
						if (ix.lang.stored["english"]) then
							ix.lang.stored["english"][gunDataKey] = dat.name or v.PrintName
						end
					end
				end
			end
		end
	end

	-- Reconfigure Customizable Weaponry in here	
	do	
		-- There is no Customization Keys.
		CustomizableWeaponry.customizationMenuKey = "" -- the key we need to press to toggle the customization menu
		CustomizableWeaponry.canDropWeapon = false
		CustomizableWeaponry.enableWeaponDrops = false
		CustomizableWeaponry.quickGrenade.enabled = false
		CustomizableWeaponry.quickGrenade.canDropLiveGrenadeIfKilled = false
		CustomizableWeaponry.quickGrenade.unthrownGrenadesGiveWeapon = false
		CustomizableWeaponry.physicalBulletsEnabled = false
		CustomizableWeaponry.customizationEnabled = false

		hook.Remove("PlayerInitialSpawn", "CustomizableWeaponry.PlayerInitialSpawn")
		hook.Remove("PlayerSpawn", "CustomizableWeaponry.PlayerSpawn")
		hook.Remove("AllowPlayerPickup", "CustomizableWeaponry.AllowPlayerPickup")

		if (CLIENT) then
			local up = Vector(0, 0, -100)
			local shellMins, shellMaxs = Vector(-0.5, -0.15, -0.5), Vector(0.5, 0.15, 0.5)
			local angleVel = Vector(0, 0, 0)

			function CustomizableWeaponry.shells:finishMaking(pos, ang, velocity, soundTime, removeTime)
				velocity = velocity or up
				velocity.x = velocity.x + math.Rand(-5, 5)
				velocity.y = velocity.y + math.Rand(-5, 5)
				velocity.z = velocity.z + math.Rand(-5, 5)
				
				local time = soundTime or 0.5
				local removetime = removeTime or 5
				
				local t = self._shellTable or CustomizableWeaponry.shells:getShell("mainshell") -- default to the 'mainshell' shell type if there is none defined

				local ent = ClientsideModel(t.m, RENDERGROUP_BOTH) 
				ent:SetPos(pos)
				ent:PhysicsInitBox(shellMins, shellMaxs)
				ent:SetAngles(ang + AngleRand())
				ent:SetModelScale((self.ShellScale*.9 or .7), 0)
				ent:SetMoveType(MOVETYPE_VPHYSICS) 
				ent:SetSolid(SOLID_VPHYSICS) 
				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				
				local phys = ent:GetPhysicsObject()
				phys:SetMaterial("gmod_silent")
				phys:SetMass(10)
				phys:SetVelocity(velocity)
				
				angleVel.x = math.random(-500, 500)
				angleVel.y = math.random(-500, 500)
				angleVel.z = math.random(-500, 500)
				
				phys:AddAngleVelocity(ang:Right() * 100 + angleVel + VectorRand()*50000)

				timer.Simple(time, function()
					if t.s and IsValid(ent) then
						sound.Play(t.s, ent:GetPos())
					end
				end)
				
				SafeRemoveEntityDelayed(ent, removetime)
			end
		end

		do
			CustomizableWeaponry.callbacks:addNew("finishReload", "nutExperience", function(weapon)
				if (CLIENT) then return end

				local owner = weapon.Owner

				if (IsValid(owner) and owner:IsPlayer()) then
					local char = owner:GetCharacter()

					if (char) then
						if (char:GetAttribute("gunskill", 0) < 5) then
							char:UpdateAttrib("gunskill", 0.003)
						end
					end
				end
			end)

			if (CLIENT) then
				netstream.Hook("nutUpdateWeapon", function(weapon) if (weapon and weapon:IsValid() and weapon.recalculateStats) then weapon:recalculateStats() end end)
			end

			function CustomizableWeaponry:hasAttachment(ply, att, lookIn)		
				return true
			end

			-- La detección de disparos se hace server-side monitorizando Clip1()
			-- (ver hook "ixCWSupportDurabilityDegrade" en el bloque if SERVER al final).

			CustomizableWeaponry.callbacks:addNew("deployWeapon", "uploadAttachments", function(weapon)
				-- Forzar Slot en la instancia (cliente Y servidor): CW2 sobreescribe self.Slot
				-- en Initialize(), haciendo que GetSlot() ignore el v.Slot de clase.
				-- El selector de armas corre client-side, así que el fix debe correr aquí también.
				do
					local class  = weapon:GetClass():lower()
					local prefix = class:find("cw_") and "cw_" or (class:find("ma85_") and "ma85_" or nil)
					if (prefix) then
						local uniqueID = string.Replace(class, prefix, ""):lower()
						local dat      = self.gunData[prefix .. uniqueID]
						if (dat) then
							local keyRemap = { [2] = 0, [1] = 1, [3] = 2 }
							weapon.Slot = keyRemap[dat.slot or 2] or (dat.slot or 2)
						end
					end
				end

				if (CLIENT) then
					weapon.FireModeDisplay = ""
					weapon.BulletDisplay = 0
					return
				end

				timer.Simple(.1, function()
					if (IsValid(weapon)) then
						if (weapon.recalculateStats) then
							weapon:recalculateStats()
							
							netstream.Start(weapon.Owner, "nutUpdateWeapon", weapon)
						end
					end
				end)

				local class = weapon:GetClass():lower()
				local client = weapon.Owner

				if (!client) then return end

				local char = client:GetCharacter()
				if (!char) then return end

				local inv = char:GetInventory()
				if (!inv) then return end

				local attList = {}
				local foundItem = nil

				for k, v in pairs(inv:GetItems()) do
					if (v.isCW and v.class == class) then
						if (v:GetData("equip")) then
							foundItem = v
							break
						end
						if (!foundItem) then
							foundItem = v
						end
					end
				end

				if (!foundItem) then return end

				local attachments = normalizeMods(foundItem:GetData("mod"))
				if (attachments) then
					for modKey, modData in pairs(attachments) do
						table.insert(attList, modData[2])
					end
				end

				local attHash = table.concat(attList, ",")

				-- Sincroniza los accesorios al modelo de mundo al desplegar el arma
				-- (ver sh_worldattachments.lua). Antes del early-return de abajo para
				-- que la NWString quede puesta aunque los stats no hayan cambiado.
				if (ix.cwsupport and ix.cwsupport.SyncWorldAtts) then
					ix.cwsupport.SyncWorldAtts(weapon, attList)
				end

				if (weapon.attLoadedHash == attHash) then return end

				for cat, data in pairs(weapon.Attachments or {}) do
					if (data.last) then
						weapon:detach(cat)
					end
				end

				timer.Simple(0.2, function()
					if (IsValid(weapon) and weapon:GetClass() == class and weapon.attachSpecificAttachment) then
						for _, b in ipairs(attList) do
							weapon:attachSpecificAttachment(b)
						end
					end
				end)

				weapon.attLoadedHash = attHash
			end)
		end
	end
end

function PLUGIN:GetSchemaCWVel(weapon, client)
	return 10
end

-- Durabilidad < 60% → mayor dispersión
function PLUGIN:GetSchemaCWAimSpread(weapon, client)
	local dur = getWeaponDurability(client, weapon)
	return (dur < 60) and 1.5 or 1
end

function PLUGIN:GetSchemaCWHipSpread(weapon, client)
	local dur = getWeaponDurability(client, weapon)
	return (dur < 60) and 1.5 or 1
end

function PLUGIN:GetSchemaCWMaxSpread(weapon, client)
	local dur = getWeaponDurability(client, weapon)
	return (dur < 60) and 1.5 or 1
end

-- Durabilidad < 40% → menor cadencia de fuego (FireDelay más alto)
function PLUGIN:GetSchemaCWFirerate(weapon, client)
	local dur = getWeaponDurability(client, weapon)
	return (dur < 40) and 1.3 or 1
end

-- Durabilidad < 20% → recoil doble
function PLUGIN:GetSchemaCWRecoil(weapon, client)
	local dur = getWeaponDurability(client, weapon)
	return (dur < 20) and 2 or 1
end

-- Munición premium (cargada con Balas manteniendo R, ver bloque SERVER más
-- abajo): mientras el cargador actual sea premium, x1.2 de daño.
local PREMIUM_AMMO_DAMAGE_MULT = 1.2

function PLUGIN:GetSchemaCWDamage(weapon, client)
	if (IsValid(weapon) and weapon.ixPremiumAmmo) then
		return PREMIUM_AMMO_DAMAGE_MULT
	end
end

if (SERVER) then
	-- Munición premium: trazadora, y prende fuego 1s a lo que impacte
	-- (jugador o NPC). Se engancha en EntityFireBullets (mismo hook que usa
	-- npc_presets para el spread de los francotiradores VJ), que se dispara
	-- para cualquier FireBullets, incluidas las armas CW2.
	local PREMIUM_AMMO_IGNITE_TIME      = 1
	local PREMIUM_AMMO_BURN_DAMAGE_MULT = 1  -- el fuego dura igual (1s) pero hace menos daño

	hook.Add("EntityFireBullets", "ixCWSupportPremiumTracerIgnite", function(ent, bulletData)
		if (not IsValid(ent) or not ent:IsPlayer()) then return end

		local wep = ent:GetActiveWeapon()
		if (not IsValid(wep) or not wep.ixPremiumAmmo) then return end

		bulletData.Tracer = 1

		local prevCallback = bulletData.Callback
		bulletData.Callback = function(attacker, tr, dmgInfo)
			if (prevCallback) then prevCallback(attacker, tr, dmgInfo) end

			local target = tr.Entity
			if (IsValid(target) and (target:IsPlayer() or target:IsNPC())) then
				-- Marca temporal para que el hook de abajo sepa que ESTE fuego
				-- concreto viene de munición premium (y no de otra fuente) y
				-- reduzca su daño sin tocar la duración, que ya gestiona Ignite.
				target.ixPremiumBurningUntil = CurTime() + PREMIUM_AMMO_IGNITE_TIME
				target:Ignite(PREMIUM_AMMO_IGNITE_TIME, 0)
			end
		end
	end)

	-- El daño periódico del fuego (DMG_BURN) se reduce mientras dure la marca
	-- de arriba, sin acortar el tiempo que el objetivo pasa ardiendo.
	hook.Add("EntityTakeDamage", "ixCWSupportPremiumBurnDamageReduce", function(target, dmgInfo)
		if (not IsValid(target)) then return end
		if (not target.ixPremiumBurningUntil or CurTime() > target.ixPremiumBurningUntil) then return end
		if (not dmgInfo:IsDamageType(DMG_BURN)) then return end

		dmgInfo:ScaleDamage(PREMIUM_AMMO_BURN_DAMAGE_MULT)
	end)

	local ammoTypes = PLUGIN.ammoInfo  -- capturar antes de que PLUGIN sea nil
	local deductFromPackages -- declaración adelantada (se usa en el sync de abajo)

	-- Ajusta las reservas de GMod para que coincidan con los paquetes del inventario.
	-- Si reserves > paquetes → RemoveAmmo (anti-dupe).
	-- Si reserves < paquetes → GiveAmmo SOLO si bAllowGive (cargar personaje). En los
	-- syncs de juego NO se rellena: rellenar enmascararía el consumo de una recarga y
	-- los paquetes no se descontarían (munición infinita).
	local function syncAmmoReservesForClient(client, _source, bAllowGive)
		local char = client:GetCharacter()
		if (not char) then return end
		local inv = char:GetInventory()
		if (not inv) then return end

		local totals = {}
		-- onlyMain = true: la munición guardada dentro de una mochila NO cuenta
		-- para las reservas del arma, solo la que está suelta en el inventario.
		for _, item in pairs(inv:GetItems(true)) do
			if (item.isAmmo and item.ammo) then
				if (item:GetData("rounds") == nil) then
					item:SetData("rounds", item.ammoAmount)
				end
				local rounds = item:GetData("rounds", item.ammoAmount)
				totals[item.ammo] = (totals[item.ammo] or 0) + rounds
			end
		end

		for ammoType, _ in pairs(ammoTypes) do
			local target  = totals[ammoType] or 0
			local current = client:GetAmmoCount(ammoType)
			if (current == target) then continue end
			if (current > target) then
				-- No reducir reservas mientras CW2 esté en animación de recarga:
				-- finishreload necesita GetAmmoCount > 0 para cargar el arma.
				if (client.ixCWSPendingReload) then
					print("[ixCWS] SYNC BLOQUEADO ("..(_source or "?")..") ammo="..ammoType.." current="..current.." target="..target.." pendingReload=true")
					continue
				end
				print("[ixCWS] SYNC RemoveAmmo ("..(_source or "?")..") ammo="..ammoType.." current="..current.."→"..target.." pendingReload=nil")
				client:RemoveAmmo(current - target, ammoType)
			else
				-- reservas < paquetes
				if (client.ixCWSPendingReload) then
					-- esperar a que termine la recarga en curso (evita descontar a medias)
					continue
				end
				if (bAllowGive) then
					-- al cargar personaje: restaurar reservas desde los paquetes
					print("[ixCWS] SYNC GiveAmmo ("..(_source or "?")..") ammo="..ammoType.." current="..current.."→"..target)
					client:GiveAmmo(target - current, ammoType, true)
				else
					-- en juego: las reservas bajaron (la recarga consumió balas) pero los
					-- paquetes no se descontaron → descontar paquetes para igualarlos.
					-- Es la red de seguridad cuando la detección de recarga no salta.
					local char2 = client:GetCharacter()
					local inv2 = char2 and char2:GetInventory()
					if (inv2) then
						print("[ixCWS] SYNC deduct ("..(_source or "?")..") ammo="..ammoType.." reservas="..current.." paquetes="..target.." → descontar "..(target - current))
						deductFromPackages(inv2, ammoType, target - current)
					end
				end
			end
		end
	end

	util.AddNetworkString("ixCWAmmoSync")
	net.Receive("ixCWAmmoSync", function(_, client)
		if (not IsValid(client)) then return end
		if ((client.ixLastAmmoSync or 0) > CurTime() - 2) then return end
		client.ixLastAmmoSync = CurTime()
		syncAmmoReservesForClient(client, "inventario_abierto")
	end)

	-- Deduce balas del paquete más usado (menos balas restantes) primero.
	deductFromPackages = function(inv, ammoType, amount)
		if (amount <= 0) then return end
		local packages = {}
		-- onlyMain = true: no descontar de cargadores que están dentro de una mochila.
		for _, item in pairs(inv:GetItems(true)) do
			if (item.isAmmo and item.ammo == ammoType) then
				table.insert(packages, item)
			end
		end
		table.sort(packages, function(a, b)
			return (a:GetData("rounds", a.ammoAmount)) < (b:GetData("rounds", b.ammoAmount))
		end)
		print("[ixCWS] deductFromPackages ammo="..tostring(ammoType).." amount="..amount.." paquetes="..#packages)
		local remaining = amount
		for _, pkg in ipairs(packages) do
			if (remaining <= 0) then break end
			local rounds = pkg:GetData("rounds", pkg.ammoAmount)
			local consume = math.min(rounds, remaining)
			remaining = remaining - consume
			local newRounds = rounds - consume
			if (newRounds <= 0) then
				print("[ixCWS] deduct: paquete VACIADO ("..rounds.."→0) eliminado")
				pkg:Remove()
			else
				pkg:SetData("rounds", newRounds)
				print("[ixCWS] deduct: paquete "..rounds.."→"..newRounds)
			end
		end
	end

	-- Vida útil (disparos totales antes de romperse del todo) por clase de
	-- arma CW. La durabilidad se guarda en 0-100 (ver getWeaponDurability),
	-- así que el umbral real de disparos-por-punto es "vida útil / 100"; sin
	-- entrada aquí se usa DEFAULT_DURABILITY_SHOTS (el valor que ya tenía
	-- TODA arma antes de este cambio: 6 disparos/punto = 600 totales).
	local DEFAULT_DURABILITY_SHOTS = 600
	local WEAPON_DURABILITY_SHOTS = {
		["cw_kry_metro_2k33_revolver"] = 400, -- Revolver
		["cw_kry_metro_2k33_duplet"]   = 400, -- Duplet

		["cw_kry_metro_tikhar"]        = 600, -- Tikhar
		["cw_metro2033_hellsing"]      = 600, -- Hellsing
		["cw_kry_metro_2k33_uboynik"]  = 600, -- Shambler
		["cw_metro2033_abzats"]        = 600, -- Abzats
		["cw_kry_metro_2k33_ventil"]   = 600, -- Ventil

		["cw_kry_metro_2k33_ak"]       = 1500, -- Kalash
		["cw_kry_metro_2k33_ak2012"]   = 1500, -- Kalash 2012
		["cw_kry_metro_2k33_aksu"]     = 1000, -- Kalash su
		["cw_kry_metro_2k33_rpk"]      = 1500, -- RPK
		["cw_kry_metro_2k33_ubludok"]  = 1000, -- Bastarda
		["cw_metro2033_vsv"]           = 1500, -- VSV
		["cw_kry_metro_2k33_gatling"]  = 1000, -- Gatling
	}

	local function GetShotsPerDurabilityPoint(class)
		local totalShots = WEAPON_DURABILITY_SHOTS[class] or DEFAULT_DURABILITY_SHOTS
		return math.max(1, math.floor(totalShots / 100))
	end

	-- Monitoriza Clip1() a 20 Hz: subida = recarga (descuenta paquetes), bajada = disparo (degrada durabilidad).
	do
		local _lastClip = {}
		local _shots    = {}

		timer.Create("ixCWSupportDurabilityDegrade", 0.05, 0, function()
			for _, ply in ipairs(player.GetAll()) do
				if (not IsValid(ply) or not ply:Alive()) then
					_lastClip[ply] = nil ; _shots[ply] = nil ; continue
				end

				-- Detectar cuándo CW2 llama RemoveAmmo en finishreload:
				-- las reservas bajan por debajo del valor pre-recarga.
				-- Descuenta de paquetes exactamente lo que CW2 consumió.
				if (ply.ixCWSPendingReload and ply.ixCWSPreReloadRes) then
					for aType, preAmount in pairs(ply.ixCWSPreReloadRes) do
						local nowAmount = ply:GetAmmoCount(aType)
						if (nowAmount < preAmount) then
							local consumed = preAmount - nowAmount
							ply.ixCWSPendingReload = nil
							ply.ixCWSPreReloadRes = nil
							local sid2 = ply:SteamID64()
							timer.Remove("ixCWSPostReloadSync_" .. sid2)
							-- Descontar exactamente lo que CW2 consumió
							local char2 = ply:GetCharacter()
							if (char2) then
								local inv2 = char2:GetInventory()
								if (inv2) then
									deductFromPackages(inv2, aType, consumed)
								end
							end
							print("[ixCWS] finishreload: ammo="..aType.." consumed="..consumed.." preAmount="..preAmount.."→"..nowAmount)
							local cleanKey = "ixCWSPostReloadCleanup_" .. sid2
							timer.Remove(cleanKey)
							timer.Create(cleanKey, 0.3, 1, function()
								if (not IsValid(ply)) then return end
								syncAmmoReservesForClient(ply, "post_reload_cleanup")
							end)
							break
						end
					end
				end

				local wep = ply:GetActiveWeapon()
				if (not IsValid(wep)) then
					_lastClip[ply] = nil ; _shots[ply] = nil ; continue
				end

				local class = wep:GetClass():lower()
				if (not class:find("cw_") and not class:find("ma85_")) then
					_lastClip[ply] = nil ; _shots[ply] = nil ; continue
				end

				local curClip  = wep:Clip1()
				local prevClip = _lastClip[ply]
				_lastClip[ply] = curClip

				-- El cambio de modo de munición (normal ↔ premium) fuerza el
				-- cargador directamente con SetClip1, fuera de disparo/recarga;
				-- sin este aviso ese salto se leería como disparos y degradaría
				-- la durabilidad de golpe.
				if (ply.ixCWSIgnoreNextClipDelta) then
					ply.ixCWSIgnoreNextClipDelta = nil
					continue
				end

				if (prevClip == nil) then continue end

				local delta = curClip - prevClip

				if (delta > 0) then
					continue
				end
				if (delta == 0) then continue end

				-- delta < 0: disparos → degradar durabilidad
				local fired = -delta

				local shotsPerPoint = GetShotsPerDurabilityPoint(class)
				_shots[ply] = (_shots[ply] or 0) + fired
				if (_shots[ply] < shotsPerPoint) then continue end
				_shots[ply] = _shots[ply] - shotsPerPoint

				local char = ply:GetCharacter()
				if (not char) then continue end
				local inv = char:GetInventory()
				if (not inv) then continue end

				-- Buscar el ítem equipado (equip=true) de esa clase.
				-- Si hay dos armas del mismo tipo, solo degrada la que está en mano.
				local target = nil
				for _, item in pairs(inv:GetItems()) do
					if (item.isCW and item.class == class and item:GetData("equip") == true) then
						target = item
						break
					end
				end
				-- Fallback: si por alguna razón equip no está marcado, usar el primero que coincida
				if (not target) then
					for _, item in pairs(inv:GetItems()) do
						if (item.isCW and item.class == class) then
							target = item
							break
						end
					end
				end

				if (target) then
					local dur    = target:GetData("durability", 100)
					local newDur = math.max(0, dur - 1)
					target:SetData("durability", newDur)
					if (wep.recalculateStats) then
						wep:recalculateStats()
						netstream.Start(ply, "nutUpdateWeapon", wep)
					end
					if (newDur <= 0) then
						ply:Notify("Tu " .. target.name .. " se ha roto y ya no puede usarse.")
						target:SetData("broken", true)
						timer.Simple(0.1, function()
							if (IsValid(ply)) then ply:StripWeapon(class) end
						end)
					end
				end
			end
		end)
	end


	-- Al pulsar R en un arma CW: activa ixCWSPendingReload y guarda las reservas
	-- actuales. La deducción de paquetes ocurre en la detección de RemoveAmmo de CW2
	-- (usando exactamente lo que CW2 consumió), evitando errores con armas con bala
	-- en recámara (GetMaxClip1 = 31 pero CW2 consume 30).
	hook.Add("KeyPress", "ixCWSupportReloadDeduct", function(ply, key)
		if (key != IN_RELOAD) then return end
		if (not IsValid(ply) or not ply:Alive()) then return end

		local wep = ply:GetActiveWeapon()
		if (not IsValid(wep)) then return end
		local class = wep:GetClass():lower()
		if (not class:find("cw_") and not class:find("ma85_")) then return end

		-- Marca que hubo un R genuino en ESTE arma justo ahora: el Reload()
		-- envuelto de SwitchToPremiumAmmo (más abajo) solo recarga/cobra si ve
		-- esta marca reciente, para no confundir un R real con las llamadas a
		-- Reload() que CW2 hace también solo por disparar (sin esto, cada
		-- disparo con el arma en modo militar cobraba un cargador entero).
		wep.ixCWSGenuineReloadPress = CurTime()

		-- CW2 dispara KeyPress R varias veces en escopetas shell-by-shell;
		-- bloqueamos si ya hay una recarga en curso.
		if (ply.ixCWSPendingReload) then return end

		-- En modo militar la recarga la gestiona el Reload envuelto de
		-- SwitchToPremiumAmmo (cobra Balas, no toca las reservas normales de
		-- munición) — descontar aquí también duplicaría el gasto por el mismo R.
		if (wep.ixPremiumAmmo) then return end

		local reloadAmount = wep:GetMaxClip1() - wep:Clip1()
		if (reloadAmount <= 0) then return end

		local char = ply:GetCharacter()
		if (not char) then return end

		-- Tipo de munición: primero desde el ítem de arma equipado, luego GMod
		local ammoType = nil
		local inv = char:GetInventory()
		if (inv) then
			for _, wepItem in pairs(inv:GetItems()) do
				if (wepItem.isCW and wepItem.class == class and wepItem:GetData("equip")) then
					ammoType = wepItem.ammoType
					break
				end
			end
		end
		if (not ammoType) then
			local rawName = game.GetAmmoName(wep:GetPrimaryAmmoType())
			ammoType = rawName and rawName:lower() or nil
		end
		if (not ammoType) then return end

		local reserves = ply:GetAmmoCount(ammoType)
		if (reserves <= 0) then return end

		print("[ixCWS] KeyPress R: arma="..class.." ammo="..ammoType.." maxClip="..wep:GetMaxClip1().." clip1="..wep:Clip1().." reloadAmount="..reloadAmount.." reserves="..reserves)

		-- Guardar reservas previas; la deducción de paquetes ocurre en la detección.
		ply.ixCWSPreReloadRes = {}
		ply.ixCWSPreReloadRes[ammoType] = reserves

		-- Marcar recarga en curso: el sync diferido queda bloqueado.
		ply.ixCWSPendingReload = true
		local sid = ply:SteamID64()
		timer.Remove("ixCWSPostReloadSync_" .. sid)
		timer.Create("ixCWSPostReloadSync_" .. sid, 5, 1, function()
			if (not IsValid(ply)) then return end
			ply.ixCWSPendingReload = nil
			syncAmmoReservesForClient(ply, "fallback_5s")
		end)
	end)

	-- ============================================================
	-- MUNICIÓN PREMIUM — cambio de modo con una tecla dedicada (B), en vez de
	-- mantener R (recarga) 3 segundos. El sistema anterior "piggybackeaba"
	-- sobre la recarga nativa de CW2 (no se puede interceptar su Reload() de
	-- forma fiable) y esa era la raíz de casi todos sus fallos: KeyPress
	-- duplicado en escopetas shell-by-shell, estados a medias si soltabas R
	-- antes/después de tiempo, y cero feedback de qué modo tenías cargado
	-- hasta soltar la tecla. Ahora B gestiona el cargador directamente sin
	-- tocar Reload de CW2: una pulsación = un cambio de modo, instantáneo y
	-- sin ambigüedad de "toque vs mantener".
	-- ============================================================
	local PREMIUM_AMMO_RATE          = 1    -- Balas por bala premium cargada
	local AMMO_MODE_TOGGLE_COOLDOWN  = 0.5  -- anti-spam de la tecla B
	local GENUINE_RELOAD_PRESS_WINDOW = 3    -- ventana tras un R real (ixCWSGenuineReloadPress) en la que Reload() SÍ recarga/cobra

	-- Solo estas armas pueden usar Munición militar.
	local PREMIUM_AMMO_WEAPONS = {
		["cw_kry_metro_2k33_ak"]      = true, -- Kalash
		["cw_kry_metro_2k33_ak2012"]  = true, -- Kalash 2012
		["cw_metro2033_vsv"]          = true, -- VSV
		["cw_kry_metro_2k33_ubludok"] = true, -- Bastarda
	}

	local function GetWeaponAmmoType(weapon)
		local ammoType = weapon.ixItem and weapon.ixItem.ammoType

		if (not ammoType) then
			local rawName = game.GetAmmoName(weapon:GetPrimaryAmmoType())
			ammoType = rawName and rawName:lower() or nil
		end

		return ammoType
	end

	-- Anim de recarga en tercera persona como feedback visual del cambio de
	-- modo (para que OTROS jugadores lo vean). CW2 no usa el sistema estándar
	-- de animaciones de GMod (SendWeaponAnim/ACT_VM_RELOAD no le hace nada);
	-- su propio SWEP:sendWeaponAnim() solo dibuja el view model si se llama
	-- en cliente (en servidor esa función no hace nada), así que la vista en
	-- primera persona se dispara desde el cliente (ver bloque CLIENT al
	-- final del archivo) y aquí solo se cubre la tercera persona, exactamente
	-- como hace CW2 en su propio beginReload() (self.Owner:SetAnimation(PLAYER_RELOAD)).
	local function PlayAmmoModeReloadAnim(ply, weapon)
		ply:SetAnimation(PLAYER_RELOAD)
	end

	-- Añade `rounds` balas de `ammoType` al inventario como ítem(s) de munición,
	-- partiendo en varios cargadores si excede el tamaño de pila. Se usa en
	-- ambas direcciones del cambio de modo para no perder las balas que
	-- hubiera físicamente en el cargador al convertirlo.
	local function RefundAmmoToInventory(ply, inv, ammoType, rounds)
		if (rounds <= 0 or not ammoType) then return end

		local ammoUniqueID = "ammo_" .. tostring(ammoType):lower()
		local ammoItemTable = ix.item.list[ammoUniqueID]
		if (not ammoItemTable) then return end

		local maxStack  = ammoItemTable.ammoAmount or 30
		local remaining = rounds
		while (remaining > 0) do
			local chunk = math.min(remaining, maxStack)
			if (not inv:Add(ammoUniqueID, 1, {rounds = chunk})) then
				ix.item.Spawn(ammoUniqueID, ply:GetItemDropPos(), nil, nil, {rounds = chunk})
			end
			remaining = remaining - chunk
		end
	end

	-- Recarga con MÁS munición militar sin cambiar de modo (R con el arma YA
	-- en modo militar): a diferencia de SwitchToPremiumAmmo (pensada para el
	-- cambio de modo con B, siempre rellena y cobra el cargador ENTERO desde
	-- cero), esto solo cobra y añade las balas que de verdad faltan para
	-- llenarlo — si ya tenías 29 de 31, recargar cuesta 2 Balas, no 31.
	local function TopUpPremiumAmmo(ply, weapon, char)
		local maxClip     = weapon:GetMaxClip1()
		local currentClip = weapon:Clip1()
		local missing     = maxClip - currentClip
		if (missing <= 0) then return end

		local money = char:GetMoney()
		local roundsToLoad = math.min(missing, math.floor(money / PREMIUM_AMMO_RATE))
		if (roundsToLoad <= 0) then return end

		local cost        = roundsToLoad * PREMIUM_AMMO_RATE
		local moneyBefore = char:GetMoney()
		char:TakeMoney(cost)
		local actuallyCharged = moneyBefore - char:GetMoney()

		if (actuallyCharged < cost) then
			if (actuallyCharged > 0) then
				char:GiveMoney(actuallyCharged)
			end
			return
		end

		ply.ixCWSIgnoreNextClipDelta = true
		weapon:SetClip1(currentClip + roundsToLoad)

		if (weapon.recalculateStats) then
			weapon:recalculateStats()
			netstream.Start(ply, "nutUpdateWeapon", weapon)
		end

		PlayAmmoModeReloadAnim(ply, weapon)
		ply:EmitSound("items/ammo_pickup.wav", 70)
	end

	-- Carga el cargador con munición premium pagada con Balas, reembolsando al
	-- inventario las balas reales que hubiera cargadas.
	local function SwitchToPremiumAmmo(ply, weapon, char, inv)
		local maxClip = weapon:GetMaxClip1()
		local money = char:GetMoney()
		local roundsToLoad = math.min(maxClip, math.floor(money / PREMIUM_AMMO_RATE))

		if (roundsToLoad <= 0) then
			return
		end

		-- Cobrar ANTES de tocar el arma, y verificar que se cobró de verdad:
		-- char:TakeMoney() no devuelve nada, así que se comprueba comparando
		-- el saldo antes/después.
		local cost        = roundsToLoad * PREMIUM_AMMO_RATE
		local moneyBefore = char:GetMoney()
		char:TakeMoney(cost)
		local actuallyCharged = moneyBefore - char:GetMoney()

		if (actuallyCharged < cost) then
			if (actuallyCharged > 0) then
				char:GiveMoney(actuallyCharged)
			end
			return
		end

		-- Devolver al inventario las balas reales que hubiera en el cargador.
		-- Si el cargador YA era munición militar (R para recargar mientras
		-- estabas en ese modo, ver el Reload envuelto más abajo), no hay nada
		-- real que devolver: serían las mismas balas militares que se acaban
		-- de volver a pagar.
		if (not weapon.ixPremiumAmmo) then
			local currentClip = weapon:Clip1()
			local ammoType    = GetWeaponAmmoType(weapon)
			RefundAmmoToInventory(ply, inv, ammoType, currentClip)
		end

		ply.ixCWSIgnoreNextClipDelta = true
		weapon:SetClip1(roundsToLoad)
		weapon.ixPremiumAmmo = true
		weapon:SetNWBool("ixPremiumAmmo", true)

		-- CW2 llama a Reload() por su cuenta en más momentos de los que
		-- parece (incluso solo por disparar, no solo al vaciar el cargador o
		-- pulsar R) — así que Reload() por sí solo NO distingue un R real.
		-- Solo se recarga/cobra si ixCWSGenuineReloadPress (marcada por el
		-- KeyPress real de R, ver ixCWSupportReloadDeduct más arriba) está
		-- reciente; cualquier otra llamada a Reload() se ignora sin más
		-- (ni cobra, ni cambia de modo, ni toca el cargador).
		if (not weapon._ixPremiumReloadWrapped) then
			weapon._ixPremiumReloadWrapped = true
			local origReload = weapon.Reload
			weapon.Reload = function(self, ...)
				local genuinePress = self.ixCWSGenuineReloadPress
					and (CurTime() - self.ixCWSGenuineReloadPress < GENUINE_RELOAD_PRESS_WINDOW)

				if (genuinePress) then
					self.ixCWSGenuineReloadPress = nil
				end

				if (self.ixPremiumAmmo and genuinePress and self:Clip1() < self:GetMaxClip1()) then
					local owner = self.Owner
					local ownerChar = IsValid(owner) and owner:IsPlayer() and owner:GetCharacter()

					if (ownerChar) then
						TopUpPremiumAmmo(owner, self, ownerChar)
						return
					end

					-- Sin personaje válido para cobrar: cae a munición normal
					-- en vez de dejar el arma en un estado roto.
					self.ixPremiumAmmo = false
					self:SetNWBool("ixPremiumAmmo", false)
					if (self.recalculateStats) then
						self:recalculateStats()
						if (IsValid(self.Owner) and self.Owner:IsPlayer()) then
							netstream.Start(self.Owner, "nutUpdateWeapon", self)
						end
					end
				end
				return origReload(self, ...)
			end
		end

		if (weapon.recalculateStats) then
			weapon:recalculateStats()
			netstream.Start(ply, "nutUpdateWeapon", weapon)
		end

		PlayAmmoModeReloadAnim(ply, weapon)
		ply:EmitSound("items/ammo_pickup.wav", 70)
	end

	-- Reembolsa en Balas (no en munición real) las balas premium que quedaran
	-- en el cargador -- son munición comprada con dinero, no balas físicas
	-- que hubiera en el inventario, así que lo que se devuelve es su coste,
	-- al mismo cambio (PREMIUM_AMMO_RATE) al que se cobraron. char:GiveMoney
	-- ya está reescrito por el plugin "money_items" para añadir directamente
	-- el objeto "bala" (dark_child_ammo.mdl) al inventario.
	-- Luego recarga el cargador con munición real de las reservas.
	local function SwitchToNormalAmmo(ply, weapon, char, inv)
		local currentClip = weapon:Clip1()
		if (currentClip > 0) then
			char:GiveMoney(currentClip * PREMIUM_AMMO_RATE)
		end

		local ammoType     = GetWeaponAmmoType(weapon)
		local maxClip      = weapon:GetMaxClip1()
		local reserves     = ammoType and ply:GetAmmoCount(ammoType) or 0
		local roundsToLoad = math.min(maxClip, reserves)

		if (roundsToLoad > 0 and ammoType) then
			deductFromPackages(inv, ammoType, roundsToLoad)
		end

		ply.ixCWSIgnoreNextClipDelta = true
		weapon:SetClip1(roundsToLoad)
		weapon.ixPremiumAmmo = false
		weapon:SetNWBool("ixPremiumAmmo", false)

		if (weapon.recalculateStats) then
			weapon:recalculateStats()
			netstream.Start(ply, "nutUpdateWeapon", weapon)
		end

		PlayAmmoModeReloadAnim(ply, weapon)
		ply:EmitSound("items/ammo_pickup.wav", 70)
	end

	netstream.Hook("ixCWSToggleAmmoMode", function(ply)
		if (not IsValid(ply) or not ply:Alive()) then return end
		if ((ply.ixCWSLastAmmoToggle or 0) > CurTime() - AMMO_MODE_TOGGLE_COOLDOWN) then return end
		ply.ixCWSLastAmmoToggle = CurTime()

		local weapon = ply:GetActiveWeapon()
		if (not IsValid(weapon)) then return end

		local class = weapon:GetClass():lower()
		if (not PREMIUM_AMMO_WEAPONS[class]) then
			return
		end

		if (ply.ixCWSPendingReload) then
			return
		end

		local char = ply:GetCharacter()
		if (not char) then return end
		local inv = char:GetInventory()
		if (not inv) then return end

		if (weapon.ixPremiumAmmo) then
			SwitchToNormalAmmo(ply, weapon, char, inv)
		else
			SwitchToPremiumAmmo(ply, weapon, char, inv)
		end
	end)

	-- Devuelve el personaje propietario de un inventario dado su ID.
	local function getCharFromInventory(inventory)
		for _, char in pairs(ix.char.loaded or {}) do
			local inv = char:GetInventory()
			if (inv and inv:GetID() == inventory:GetID()) then
				return char
			end
		end
	end

	-- Munición fisicalizada: el paquete queda en inventario.
	-- Se añaden sus balas a las reservas de GMod para que CW2 pueda recargar.
	-- Hook real de Helix: InventoryItemAdded(oldInv, newInv, item)
	function PLUGIN:InventoryItemAdded(_, inventory, item)
		if (not item.isAmmo or not item.ammo) then return end
		local char = getCharFromInventory(inventory)
		if (not char) then return end
		local client = char:GetPlayer()
		if (not IsValid(client)) then return end
		-- Limpiar referencia de entidad de suelo inmediatamente: Helix la deja apuntando
		-- a la entidad ya destruida y crashea al intentar tirar el ítem con GetPos.
		item.entity = nil
		if (item:GetData("rounds") == nil) then
			item:SetData("rounds", item.ammoAmount)
		end
		local rounds = item:GetData("rounds", item.ammoAmount)
		print("[ixCWS] InventoryItemAdded ammo="..tostring(item.ammo).." rounds="..tostring(rounds).." reserves_antes="..tostring(client:GetAmmoCount(item.ammo)))
		if (rounds > 0) then
			client:GiveAmmo(rounds, item.ammo, true)
			client:EmitSound("volmos/mzone/interface/inv_reload.ogg", 80)
		end
	end

	-- Si el jugador tira o un paquete es vaciado por una recarga, ajustar reservas
	-- mediante un sync diferido. El sync comprueba ixCWSPendingReload: si está activo
	-- (recarga en curso) omite el RemoveAmmo para no quitar las reservas que CW2
	-- necesita en finishreload. Para tiradas normales (sin recarga) el flag está nil
	-- y el sync llama RemoveAmmo correctamente.
	-- Hook real de Helix: InventoryItemRemoved(inventory, item)
	function PLUGIN:InventoryItemRemoved(inventory, item)
		if (not item.isAmmo or not item.ammo) then return end
		local char = getCharFromInventory(inventory)
		if (not char) then return end
		local client = char:GetPlayer()
		if (not IsValid(client)) then return end
		print("[ixCWS] InventoryItemRemoved ammo="..tostring(item.ammo).." rounds="..tostring(item:GetData("rounds", item.ammoAmount)).." pendingReload="..tostring(client.ixCWSPendingReload).." reserves="..tostring(client:GetAmmoCount(item.ammo)))
		local timerKey = "ixCWSAmmoRemovedSync_" .. client:SteamID64()
		timer.Remove(timerKey)
		timer.Create(timerKey, 0.1, 1, function()
			if (not IsValid(client)) then return end
			syncAmmoReservesForClient(client, "item_removido")
		end)
	end

	-- Recalcula las reservas de UN solo calibre a partir de lo que hay en el
	-- inventario principal (onlyMain = true, ignora mochilas). A diferencia de
	-- syncAmmoReservesForClient (que nunca regala munición fuera de bAllowGive,
	-- para evitar duplicados por recarga), aquí SÍ hace falta poder subir las
	-- reservas: sacar un cargador de la mochila debe devolverle sus balas.
	local function resyncAmmoTypeForTransfer(client, ammoType)
		if (client.ixCWSPendingReload) then return end

		local char = client:GetCharacter()
		local inv = char and char:GetInventory()
		if (not inv) then return end

		local total = 0
		for _, itm in pairs(inv:GetItems(true)) do
			if (itm.isAmmo and itm.ammo == ammoType) then
				total = total + itm:GetData("rounds", itm.ammoAmount)
			end
		end

		local current = client:GetAmmoCount(ammoType)
		if (current == total) then return end

		if (current > total) then
			print("[ixCWS] transfer RemoveAmmo ammo="..ammoType.." "..current.."→"..total)
			client:RemoveAmmo(current - total, ammoType)
		else
			print("[ixCWS] transfer GiveAmmo ammo="..ammoType.." "..current.."→"..total)
			client:GiveAmmo(total - current, ammoType, true)
		end
	end

	-- Mover un cargador entre el inventario principal y una mochila (en cualquier
	-- dirección) no dispara InventoryItemAdded/Removed (eso es un "transfer", no
	-- un add/remove), así que sin esto las reservas no se corrigen hasta reabrir
	-- el inventario. Resincroniza en cuanto cruza esa frontera.
	function PLUGIN:OnItemTransferred(item, old, new)
		if (not item.isAmmo or not item.ammo) then return end

		local char = (old and getCharFromInventory(old)) or (new and getCharFromInventory(new))
		if (not char) then return end

		local client = char:GetPlayer()
		if (not IsValid(client)) then return end

		local ammoType = item.ammo

		timer.Simple(0, function()
			if (IsValid(client)) then
				resyncAmmoTypeForTransfer(client, ammoType)
			end
		end)
	end

	function PLUGIN:PlayerDisconnected(client)
		if (not IsValid(client)) then return end
		local sid = client:SteamID64()
		timer.Remove("ixCWSAmmoRemovedSync_" .. sid)
		timer.Remove("ixCWSPostReloadSync_" .. sid)
		timer.Remove("ixCWSPostReloadCleanup_" .. sid)
		timer.Remove("ixPremiumAmmoHold_" .. sid)
	end

	-- Al cargar personaje: sincronizar reservas exactas desde los paquetes del inventario.
	function PLUGIN:CharacterLoaded(character)
		local client = character:GetPlayer()
		if (not IsValid(client)) then return end
		timer.Simple(1.5, function()
			if (not IsValid(client)) then return end
			syncAmmoReservesForClient(client, "char_loaded", true) -- restaurar reservas al spawnear
		end)
	end

	function PLUGIN:OnCharAttribUpdated(client, character, key, value)
		if (!client) then
			client = (character and character:getPlayer())
		end

		if (client and client:IsValid()) then
			local weapon = client:GetActiveWeapon()

			if (key == "gunskill") then
				if (weapon and weapon:IsValid() and weapon.recalculateStats) then
					weapon:recalculateStats()

					netstream.Start(client, "nutUpdateWeapon", weapon)
				end
			end
		end
	end

	function PLUGIN:OnCharAttribBoosted(client, character, attribID, boostID, boostAmount)
		if (!client) then
			client = (character and character:getPlayer())
		end

		if (client and client:IsValid()) then
			local weapon = client:GetActiveWeapon()

			if (attribID == "gunskill") then
				if (weapon and weapon:IsValid() and weapon.recalculateStats) then
					weapon:recalculateStats()

					netstream.Start(client, "nutUpdateWeapon", weapon)
				end
			end
		end
	end

end

if (CLIENT) then
	-- Sincronizar reservas con el servidor al abrir el inventario (anti-dupe)
	do
		local wasOpen = false
		hook.Add("Think", "ixCWSupportAmmoSyncOnOpen", function()
			local isOpen = IsValid(ix.gui.metroInventory)
			if (isOpen and not wasOpen) then
				net.Start("ixCWAmmoSync")
				net.SendToServer()
			end
			wasOpen = isOpen
		end)
	end

	-- Tecla B: cambia de modo de munición (normal ↔ Munición militar) del
	-- arma equipada. Solo se envía en el flanco de pulsado (no en mantener),
	-- así una pulsación siempre es exactamente un cambio de modo.
	do
		local function isTyping()
			local focus = vgui.GetKeyboardFocus()
			if (IsValid(focus) and focus:GetName() == "DTextEntry") then return true end
			return IsValid(ix.gui.chat) and ix.gui.chat:GetActive()
		end

		local wasDown = false
		hook.Add("Think", "ixCWSupportAmmoModeKey", function()
			if (isTyping()) then wasDown = false return end

			local isDown = input.IsKeyDown(KEY_B)

			if (isDown and not wasDown) then
				local ply = LocalPlayer()
				local wep = IsValid(ply) and ply:GetActiveWeapon()

				if (IsValid(wep)) then
					local class = wep:GetClass():lower()
					if (class:find("cw_") or class:find("ma85_")) then
						-- CW2 gestiona su view model con sendWeaponAnim() propio
						-- (minúscula), que solo dibuja algo si se llama en cliente;
						-- por eso el feedback en primera persona se dispara aquí y
						-- no desde el servidor. Misma lógica que usa CW2 en su
						-- propio beginReload() para elegir "reload" o "reload_empty".
						if (wep.sendWeaponAnim and wep.Animations) then
							local anim = (wep.Animations.reload_empty and wep:Clip1() == 0) and "reload_empty" or "reload"
							wep:sendWeaponAnim(anim, wep.ReloadSpeed)
						end

						netstream.Start("ixCWSToggleAmmoMode")
					end
				end
			end

			wasDown = isDown
		end)
	end

	-- R con el arma en modo militar: el Reload() envuelto que recarga en el
	-- servidor (ver SwitchToPremiumAmmo/sh_plugin.lua) no dispara la
	-- animación de CW2 por sí solo (misma razón que con B, arriba: su
	-- sendWeaponAnim() solo pinta algo si se llama en cliente). Se replica
	-- aquí el mismo disparo de animación para que R también se vea.
	hook.Add("KeyPress", "ixCWSupportPremiumReloadAnim", function(ply, key)
		if (key != IN_RELOAD or ply != LocalPlayer()) then return end

		local wep = ply:GetActiveWeapon()
		if (not IsValid(wep)) then return end

		local class = wep:GetClass():lower()
		if (not class:find("cw_") and not class:find("ma85_")) then return end
		if (not wep:GetNWBool("ixPremiumAmmo", false)) then return end

		if (wep.sendWeaponAnim and wep.Animations) then
			local anim = (wep.Animations.reload_empty and wep:Clip1() == 0) and "reload_empty" or "reload"
			wep:sendWeaponAnim(anim, wep.ReloadSpeed)
		end
	end)
end
