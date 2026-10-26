local PLUGIN = PLUGIN

PLUGIN.name = "Intercambio"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Ventana de intercambio seguro de items entre jugadores. Apunta a alguien y usa /intercambiar."

ix.intercambio = ix.intercambio or {}

ix.intercambio.config = {
	useRange = 220,        -- distancia máxima para iniciar y mantener un intercambio
	maxItems = 12,         -- items máximos por lado
	requestTimeout = 30,   -- segundos que dura una solicitud sin responder
}

-- Net strings
PLUGIN.netRequest = "Trade.Request"   -- sv → cl : alguien te quiere intercambiar
PLUGIN.netRespond = "Trade.Respond"   -- cl → sv : aceptar / rechazar
PLUGIN.netState = "Trade.State"       -- sv → cl : estado completo del intercambio
PLUGIN.netOffer = "Trade.Offer"       -- cl → sv : añadir / quitar item de tu oferta
PLUGIN.netConfirm = "Trade.Confirm"   -- cl → sv : confirmar / desconfirmar
PLUGIN.netCancel = "Trade.Cancel"     -- cl → sv : cancelar el intercambio
PLUGIN.netClose = "Trade.Close"       -- sv → cl : el intercambio terminó (cerrar UI)

ix.command.Add("Intercambiar", {
	description = "Solicita un intercambio de items con el jugador al que estás mirando.",
	OnRun = function(self, client)
		if (SERVER) then
			ix.intercambio.Request(client)
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
