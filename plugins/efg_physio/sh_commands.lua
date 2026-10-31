local PH = ix.efg.physio

ix.command.Add("RCP", {
	description = "Haz la reanimación cardiopulmonar al herido que tienes delante (míralo de cerca).",
	OnRun = function(self, client)
		local patient, entity = PH.GetPatient(client)
		if (!patient) then return "Mira al herido desde cerca." end

		local state = client.efgPhysio
		if (state and state.unconscious) then return "Estás inconsciente." end

		local ok, reason = PH.CanTreat(patient, "cpr")
		if (!ok) then return reason end

		if ((client.efgNextCPR or 0) > CurTime()) then return end
		client.efgNextCPR = CurTime() + 1

		client:SetAction("Reanimación cardiopulmonar...", 6)
		client:DoStaredAction(entity, function()
			local done, message = PH.Treat(patient, "cpr")
			if (message) then client:Notify(message) end
			if (done) then hook.Run("EFGPhysioTreated", client, patient, "cpr") end
		end, 6, function()
			if (IsValid(client)) then client:SetAction() end
		end, 110)
	end
})

ix.command.Add("GrupoSanguineo", {
	description = "Muestra tu grupo sanguíneo (viene en tu chapa de identificación).",
	OnRun = function(self, client)
		local character = client:GetCharacter()
		return "Tu grupo sanguíneo es " .. ((character and character:GetEfgBloodType() != "") and character:GetEfgBloodType() or "desconocido") .. "."
	end
})

ix.command.Add("EFGFisiologia", {
	description = "[Admin] Pone tus constantes en un estado de prueba: sangre, neumo, tension, parada, leve, grave (sangrado) o normal.",
	adminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, mode)
		local state = PH.Get(client)

		if (mode == "sangre") then
			state.blood = PH.BLOOD_MAX * 0.62
		elseif (mode == "neumo") then
			state.pneumo, state.pneumoSince = 1, CurTime()
		elseif (mode == "tension") then
			state.pneumo = 2
		elseif (mode == "parada") then
			PH.Arrest(client)
		elseif ((mode == "leve" or mode == "grave") and ix.efg.health) then
			-- sangrado en la pierna izquierda para probar la pérdida de sangre
			ix.efg.health.GetStatus(client).bleed.lleg = mode == "grave" and "heavy" or "light"
			ix.efg.health.Sync(client)
		else
			PH.Reset(client)
		end

		PH.Sync(client)
		return "Fisiología: " .. mode .. "."
	end
})
