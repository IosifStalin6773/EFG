
local PLUGIN = PLUGIN

ix.config.Add("primaryNeedsDelay", 180, "How long does it take to calculate the character's primary needs? (In seconds)", function(oldValue, newValue)
	if (SERVER) then
		for _, pl in ipairs(player.GetAll()) do
			if IsValid(pl) and pl:GetCharacter() then
				if timer.Exists("ixPrimaryNeeds." .. pl:AccountID()) then timer.Remove("ixPrimaryNeeds." .. pl:AccountID()) end
				PLUGIN:CreateNeedsTimer(pl, pl:GetCharacter())
			end
		end
	end
end, {data = {min = 1, max = 1000}, category = PLUGIN.name})

ix.config.Add("deathCountdown", 300, "How long will it take for a character to die if starving", nil, {
	data = {min = 0, max = 1000},
	category = PLUGIN.name
})

ix.config.Add("saturationConsume", 2, "How much saturation will be taken from the character", nil, {
	data = {min = 0, max = 100},
	category = PLUGIN.name
})

ix.config.Add("satietyConsume", 1, "How much satiety will be taken from the character", nil, {
	data = {min = 0, max = 100},
	category = PLUGIN.name
})

ix.config.Add("foodRestoreMult", 1, "Multiplicador global de la saciedad (comida) que restauran los consumibles", nil, {
	data = {min = 0, max = 10, decimals = 2},
	category = PLUGIN.name
})

ix.config.Add("drinkRestoreMult", 1, "Multiplicador global de la saturacion (bebida) que restauran los consumibles", nil, {
	data = {min = 0, max = 10, decimals = 2},
	category = PLUGIN.name
})

ix.config.Add("nutridoDuration", 300, "Duración en segundos del buff 'Nutrido' al comer algo cocinado/preparado", nil, {
	data = {min = 30, max = 1800},
	category = PLUGIN.name
})

ix.config.Add("nutridoConsumeMult", 0.5, "Multiplicador de desgaste de hambre/sed mientras el buff 'Nutrido' está activo", nil, {
	data = {min = 0, max = 1, decimals = 2},
	category = PLUGIN.name
})

ix.config.Add("intoxChance", 100, "Probabilidad (%) de intoxicarse al comer/beber algo crudo o en mal estado", nil, {
	data = {min = 0, max = 100},
	category = PLUGIN.name
})

ix.config.Add("intoxDuration", 60, "Duración en segundos de la intoxicación por comida cruda", nil, {
	data = {min = 10, max = 600},
	category = PLUGIN.name
})

ix.config.Add("intoxTickInterval", 5, "Cada cuántos segundos se aplica el desgaste de la intoxicación", nil, {
	data = {min = 1, max = 30},
	category = PLUGIN.name
})

ix.config.Add("intoxSatietyDrain", 2, "Saciedad perdida por tick mientras dura la intoxicación", nil, {
	data = {min = 0, max = 20},
	category = PLUGIN.name
})

ix.config.Add("intoxHealthDrain", 1, "Vida perdida por tick mientras dura la intoxicación", nil, {
	data = {min = 0, max = 10},
	category = PLUGIN.name
})

ix.config.Add("rawFoodSaturationCap", 20, "Al comer/beber algo crudo, la sed (saturation) nunca se queda por encima de este valor", nil, {
	data = {min = 0, max = 100},
	category = PLUGIN.name
})

ix.config.Add("rawFoodStaminaCap", 15, "Al comer/beber algo crudo, la stamina nunca se queda por encima de este valor", nil, {
	data = {min = 0, max = 100},
	category = PLUGIN.name
})