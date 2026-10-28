do
	local COMMAND = {}
	COMMAND.description = "Busca en el cuerpo de un sujeto atado."
	function COMMAND:OnRun(client, arguments)
		local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client
		local target = util.TraceLine(data).Entity

		if (IsValid(target) and target:IsPlayer() and target:IsRestricted()) then
			if (!client:IsRestricted()) then
				Schema:SearchPlayer(client, target)
			else
				return "@notNow"
			end
		end
	end

	ix.command.Add("CharSearch", COMMAND)
end

ix.command.Add("Forcejear", {
	description = "Intenta zafarte de las bridas que te inmovilizan.",
	OnRun = function(self, client)
		if (!client:IsRestricted()) then
			return "@notNow"
		end

		if (client.ixNextStruggle and client.ixNextStruggle > CurTime()) then
			client:NotifyLocalized("bridasStruggleCooldown", math.ceil(client.ixNextStruggle - CurTime()))
			return
		end

		client.ixNextStruggle = CurTime() + 20

		client:SetAction("Forcejeando", 3)
		client:Say("/me forcejea intentando zafarse de las bridas")

		timer.Simple(3, function()
			if (!IsValid(client) or !client:IsRestricted()) then return end

			if (math.random(100) <= 18) then
				client:SetRestricted(false)
				client:NotifyLocalized("bridasStruggleSuccess")
			else
				client:NotifyLocalized("bridasStruggleFail")
			end
		end)
	end
})

ix.command.Add("DesesposarForzado", {
	description = "Fuerza la liberación de un jugador atado con bridas.",
	adminOnly = true,
	arguments = {
		ix.type.player,
	},
	OnRun = function(self, client, target)
		if (!target:IsRestricted()) then
			return client:Notify("Ese jugador no está atado.")
		end

		target:SetRestricted(false)

		target:Notify("Un administrador te ha liberado de las bridas.")
		client:Notify("Has liberado a " .. target:Name() .. " de las bridas.")
	end
})

ix.command.Add("QuitarSaco", {
	description = "Le quita el saco de la cabeza a la persona a la que apuntas.",
	OnRun = function(self, client)
		local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client
		local target = util.TraceLine(data).Entity

		if (!IsValid(target) or target == client or !target:IsPlayer() or !target:GetNetVar("bagged")) then
			return "@sacoNoTarget"
		end

		local plugin = ix.plugin.Get("handcuffs")
		if (plugin) then plugin:QuitarSacoDe(client, target) end
	end
})
