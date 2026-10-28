local PLUGIN = PLUGIN

PLUGIN.name = "Arcas de Hanza"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Tesoro compartido de la facción Hanza. Recibe la tasa del Tablón de Encargos y puede ser retirado por cualquier miembro de Hanza."

ix.arcas = ix.arcas or {}
ix.arcas.hanza = ix.arcas.hanza or 0
ix.arcas.huchas = ix.arcas.huchas or {}

-- Merma al retirar: quien saca Balas de las arcas pierde este porcentaje (se
-- destruye, no va a nadie), para que el tesoro no sea un simple "aparcamiento"
-- que devuelve el 100% de lo depositado a la circulación.
ix.arcas.withdrawFeeRate = 0.10

-- Corte de Hanza sobre lo que un jugador vende a CUALQUIER trader (no solo
-- los de Hanza): un 20% del valor de venta se deposita aquí, igual que la
-- tasa del Tablón de Encargos. Es dinero ADICIONAL (Hanza se queda su parte
-- sin que el jugador reciba menos), no una merma sobre lo que cobra el
-- vendedor — mismo criterio que ya usan los traders al "crear" el dinero que
-- pagan por la compra.
ix.arcas.traderSellCutRate = 0.20

-- Net strings
PLUGIN.netOpen = "ArcasHanza.Open"
PLUGIN.netWithdraw = "ArcasHanza.Withdraw"

-- Deposita Balas en las arcas de Hanza. Lo usa el Tablón de Encargos para
-- mandar aquí la tasa que antes se destruía; cualquier otro plugin puede
-- llamarlo igual para alimentar el tesoro de la facción.
function ix.arcas.Deposit(amount)
	if (SERVER) then
		amount = math.floor(math.abs(tonumber(amount) or 0))
		if (amount <= 0) then return end

		ix.arcas.hanza = ix.arcas.hanza + amount

		local plugin = ix.plugin.Get("arcas_hanza")
		if (plugin) then plugin:SaveData() end
	end
end

-- Comandos admin
ix.command.Add("ColocarArcasHanza", {
	description = "Coloca una Hucha de Hanza (tesoro compartido de la facción).",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local trace = client:GetEyeTraceNoCursor()
			local pos = trace.HitPos + trace.HitNormal * 5
			local ang = (client:GetPos() - pos):Angle()
			ang.pitch = 0
			ang.roll = 0

			local ent = ents.Create("ix_arcas_hanza")
			if (not IsValid(ent)) then
				return client:Notify("No se pudo crear la entidad.")
			end

			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:Activate()

			ix.arcas.SaveHuchas()
			client:Notify("Hucha de Hanza colocada.")
		end
	end
})

ix.command.Add("QuitarArcasHanza", {
	description = "Elimina la Hucha de Hanza a la que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local ent = client:GetEyeTrace().Entity
			if (not IsValid(ent) or ent:GetClass() != "ix_arcas_hanza") then
				return client:Notify("No estás mirando a ninguna Hucha de Hanza.")
			end

			ix.arcas.RemoveHucha(ent)
			ent:Remove()
			client:Notify("Hucha de Hanza eliminada.")
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
