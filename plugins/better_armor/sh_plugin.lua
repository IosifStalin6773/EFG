local PLUGIN = PLUGIN
PLUGIN.name = "Better Armor"
PLUGIN.author = "Subleader and Alexgrist (Outfit base used)"
PLUGIN.desc = "Compatible with bad air and localized damage, plus it adds damage resistance"

ix.util.Include("cl_plugin.lua")

function PLUGIN:PlayerSetHandsModel(client, entity)
	local customHands = client:GetNetVar("customHands")

	if (!customHands) then
		local character = client:GetCharacter()
		if (character) then
			local inventory = character:GetInventory()
			if (inventory) then
				for _, v in pairs(inventory:GetItems()) do
					if (v.base == "base_armor" and v:GetData("equip") and v.handsModel) then
						customHands = v.handsModel
						client:SetNetVar("customHands", customHands)
						break
					end
				end
			end
		end
	end

	if (customHands) then
		entity:SetModel(customHands)
		return true
	end
end

function PLUGIN:PlayerDeath(client)
	client:SetNetVar("customHands", nil)
end

function PLUGIN:EntityTakeDamage( target, dmginfo )
	if ( target:IsPlayer() ) then
		if ( target:GetNetVar("resistance") == true ) then
			if (dmginfo:IsDamageType(DMG_BULLET)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_bullet"))
			elseif (dmginfo:IsDamageType(DMG_SLASH)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_slash"))
			elseif (dmginfo:IsDamageType(DMG_SHOCK)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_shock"))
			elseif (dmginfo:IsDamageType(DMG_BURN)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_burn"))
			elseif (dmginfo:IsDamageType(DMG_RADIATION)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_radiation"))
			elseif (dmginfo:IsDamageType(DMG_ACID)) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_acid"))
			elseif (dmginfo:IsExplosionDamage()) then
				dmginfo:ScaleDamage(target:GetNWFloat("dmg_explosive"))
			end
		end
	end
end

function PLUGIN:PlayerHurt( client, attacker, health, damageTaken )
	if (client:IsPlayer()) then
		local character = client:GetCharacter()
		if (!character) then return end
		local inventory = character:GetInventory()
		local items = inventory:GetItems()

		-- Las armaduras equipadas viven en el inventario de equipo (ix_equipinv),
		-- no en el principal (ver plugins/ix_invkey). Sin esto, el desgaste nunca
		-- se aplica porque el ítem no aparece en inventory:GetItems().
		local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(character)
		if (equipInv) then
			items = table.Merge(table.Copy(items), equipInv:GetItems())
		end

		for k, v in pairs(items) do
			if (v.base == "base_armor" and v:GetData("equip")) then
				local durability = v:GetData("Durability", 100)
				if (durability > 0) then
					local lossRate = v.durabilityLoss or 0.1
					-- Mantenimiento: reduce el desgaste de la armadura.
					local lossMult = hook.Run("AdjustArmorDurabilityLoss", client, character) or 1
					local newDurability = math.max(0, durability - math.floor(damageTaken * lossRate * lossMult))
					v:SetData("Durability", newDurability)
					if (newDurability <= 0) then
						client:Notify("Tu armadura ha quedado destruida. Repárala con un Kit de Reparación.")
					end
				end
			end
		end
	end
end

ix.command.Add("Gasmask", {
	description = "Ponerse o quitarse la máscara de gas.",
	adminOnly = false,
	OnRun = function(self, client)
		local character = client:GetCharacter()
		local inventory = character:GetInventory()
		local items = inventory:GetItems()
		for k, v in pairs(items) do
			if (v.base == "base_armor") and (v.gasmask == true) then
				if client:GetNetVar("gasmask") then
					client:SetNetVar("gasmask", false)
					client:Notify("Te has quitado la máscara de gas.")
				else
					client:SetNetVar("gasmask", true)
					client:Notify("Te has puesto la máscara de gas.")
				end
			end
		end
	end
})
