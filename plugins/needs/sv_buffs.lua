
local PLUGIN = PLUGIN

util.AddNetworkString("ixNeedsNausea")

--- Aplica el buff "Nutrido": reduce el desgaste de hambre/sed durante un tiempo.
-- Se llama al comer comida cocinada o ya preparada (conservas, raciones...).
function ix.needs.ApplyNutrido(client)
	if (!IsValid(client) or !client:Alive()) then return end

	local duration = ix.config.Get("nutridoDuration", 300)
	client:SetNetVar("nutridoEnd", CurTime() + duration)
end

--- Se llama al comer/beber algo crudo o en mal estado: siempre castiga la
-- sed y la stamina (comer crudo sienta mal al cuerpo), provoca una náusea
-- breve en cámara y, con cierta probabilidad, una intoxicación real que
-- drena salud y saciedad mientras dura.
function ix.needs.TryIntoxicate(client)
	if (!IsValid(client) or !client:Alive()) then return end

	local char = client:GetCharacter()
	if (char) then
		local saturationCap = ix.config.Get("rawFoodSaturationCap", 20)
		if (char:GetSaturation() > saturationCap) then
			char:SetSaturation(saturationCap)
		end
	end

	local staminaCap = ix.config.Get("rawFoodStaminaCap", 15)
	if (client:GetLocalVar("stm", 100) > staminaCap) then
		client:SetLocalVar("stm", staminaCap)
	end

	net.Start("ixNeedsNausea")
	net.Send(client)

	local chance = ix.config.Get("intoxChance", 75) / 100
	if (math.random() > chance) then return end

	local duration = ix.config.Get("intoxDuration", 60)
	client:SetNetVar("intoxicadoEnd", CurTime() + duration)
	client.ixIntoxicadoActive = true
end

-- Drena salud y saciedad mientras dura la intoxicación; avisa una sola vez al remitir.
timer.Create("ixNeedsIntoxTick", ix.config.Get("intoxTickInterval", 5), 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client) or !client:Alive()) then continue end

		local endTime = client:GetNetVar("intoxicadoEnd", 0)

		if (endTime > CurTime()) then
			local char = client:GetCharacter()
			if (char) then
				char:DowngradeSatiety(ix.config.Get("intoxSatietyDrain", 2))
				client:SetHealth(math.max(client:Health() - ix.config.Get("intoxHealthDrain", 1), 1))
			end
		elseif (client.ixIntoxicadoActive) then
			client.ixIntoxicadoActive = nil
			client:SetNetVar("intoxicadoEnd", 0)
		end
	end
end)
