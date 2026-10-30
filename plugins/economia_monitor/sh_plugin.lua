local PLUGIN = PLUGIN

PLUGIN.name = "Monitor de Economía"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Comando admin que desglosa la masa monetaria total del servidor: personajes online, offline, taquillas y arcas de Hanza."

ix.economia = ix.economia or {}

-- Cuántos personajes mostrar en el ranking de más ricos.
ix.economia.topRichCount = 10

ix.command.Add("EconomiaTotal", {
	description = "Muestra un desglose de la masa monetaria total del servidor y el ranking de personajes más ricos.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			client:Notify("Calculando la masa monetaria total del servidor, esto puede tardar unos segundos...")

			ix.economia.ComputeTotal(function(totals)
				if (not IsValid(client)) then return end

				local total = totals.online + totals.offline + totals.lockers + totals.arcas

				client:ChatPrint("═══════ DINERO DEL SERVIDOR ═══════")
				client:ChatPrint(("Personajes ONLINE (%i): %s Rublos"):format(totals.onlineCount, string.Comma(totals.online)))
				client:ChatPrint(("Personajes OFFLINE (%i): %s Rublos"):format(totals.offlineCount, string.Comma(totals.offline)))
				client:ChatPrint(("Taquillas (online + offline): %s Rublos"):format(string.Comma(totals.lockers)))
				client:ChatPrint(("Arcas de Hanza: %s Rublos"):format(string.Comma(totals.arcas)))
				client:ChatPrint(("TOTAL EN CIRCULACIÓN: %s Rublos"):format(string.Comma(total)))

				local topCount = math.min(#totals.richest, ix.economia.topRichCount)
				client:ChatPrint(("═══════ MÁS RICOS (top %i) ═══════"):format(topCount))

				if (topCount == 0) then
					client:ChatPrint("No hay personajes registrados.")
				else
					for i = 1, topCount do
						local entry = totals.richest[i]
						client:ChatPrint(("%i. %s — %s Rublos"):format(i, entry.name, string.Comma(entry.amount)))
					end
				end
			end)
		end
	end
})

ix.util.Include("sv_plugin.lua")
