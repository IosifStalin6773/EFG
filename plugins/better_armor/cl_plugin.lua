local PLUGIN = PLUGIN

-- Sonidos de respiración ligera (sin esfuerzo)
local BREATH_LIGHT = {
	"avoxgaming/gas_mask/gas_mask_light/gas_mask_light_breath1.wav",
	"avoxgaming/gas_mask/gas_mask_light/gas_mask_light_breath2.wav",
	"avoxgaming/gas_mask/gas_mask_light/gas_mask_light_breath3.wav",
	"avoxgaming/gas_mask/gas_mask_light/gas_mask_light_breath4.wav",
	"avoxgaming/gas_mask/gas_mask_light/gas_mask_light_breath5.wav",
}

-- Sonidos de respiración fuerte (corriendo/sprint)
local BREATH_HEAVY = {
	"avoxgaming/gas_mask/gas_mask_middle/gas_mask_middle_breath1.wav",
	"avoxgaming/gas_mask/gas_mask_middle/gas_mask_middle_breath2.wav",
	"avoxgaming/gas_mask/gas_mask_middle/gas_mask_middle_breath3.wav",
	"avoxgaming/gas_mask/gas_mask_middle/gas_mask_middle_breath4.wav",
	"avoxgaming/gas_mask/gas_mask_middle/gas_mask_middle_breath5.wav",
}

-- Caché de durabilidad de armadura (evita iterar inventario cada frame)
local _cachedArmor     = 100
local _lastArmorCheck  = 0

function PLUGIN:RenderScreenspaceEffects()
	local client = LocalPlayer()

	if (client:GetNetVar("gasmask") != true) then
		client.enresp = false
		return
	end

	local character = client:GetCharacter()
	if (not character) then return end

	local inventory = character:GetInventory()
	if (not inventory) then return end

	-- Actualizar durabilidad de armadura cada 0.5 s (no en cada frame)
	if (CurTime() - _lastArmorCheck > 0.5) then
		_lastArmorCheck = CurTime()
		_cachedArmor    = 100
		for _, v in pairs(inventory:GetItems()) do
			if (v.base == "base_armor" and v:GetData("equip")) then
				_cachedArmor = v:GetData("Durability", 100)
				break
			end
		end
	end

	-- Overlay de daño en la máscara según durabilidad (metromask1=limpio, metromask6=muy dañado)
	if (_cachedArmor <= 10) then
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask6", 0.2)
	elseif (_cachedArmor <= 20) then
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask5", 0.2)
	elseif (_cachedArmor <= 40) then
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask4", 0.2)
	elseif (_cachedArmor < 60) then
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask3", 0.2)
	elseif (_cachedArmor < 80) then
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask2", 0.2)
	else
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask1", 0.2)
	end

	-- Respiración periódica: más rápida al correr.
	-- timer.Create con nombre único evita acumulación de timers si se re-equipa la máscara.
	if (not client.enresp) then
		client.enresp = true
		local timerName = "GasMaskBreath_" .. client:EntIndex()
		local duration
		if (client:KeyDown(IN_BULLRUSH)) then
			surface.PlaySound(BREATH_HEAVY[math.random(1, #BREATH_HEAVY)])
			duration = 2.5
		else
			surface.PlaySound(BREATH_LIGHT[math.random(1, #BREATH_LIGHT)])
			duration = 3.5
		end
		timer.Create(timerName, duration, 1, function()
			if IsValid(client) then client.enresp = false end
		end)
	end
end