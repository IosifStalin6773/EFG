local PLUGIN = PLUGIN

PLUGIN.name = "EFG Mensajes y manual"
PLUGIN.author = "EFG"
PLUGIN.description = "Mensajes de comerciantes (seguro, mercadillo, tareas), manual de objetos con precios y pasos audibles según el material, como en EFT."

ix.efg = ix.efg or {}
ix.efg.messages = ix.efg.messages or {}

local MSG = ix.efg.messages

ix.config.Add("efgFootstepLoudness", 1.0, "Volumen de los pasos de los jugadores (EFT: se oyen lejos).", nil, {
	data = {min = 0, max = 2, decimals = 2}, category = "EFG Sonido"
})

ix.command.Add("Mensajes", {
	description = "Abre los mensajes de los comerciantes.",
	OnRun = function(self, client)
		net.Start("ixEFGMessagesOpen")
		net.Send(client)
	end
})

ix.command.Add("Manual", {
	description = "Abre el manual de objetos (handbook) con sus precios.",
	OnRun = function(self, client)
		net.Start("ixEFGHandbookOpen")
		net.Send(client)
	end
})

-- ─── Pasos (sonido por material, volumen según velocidad) ───────────────────
-- GMod ya elige el sonido por material; aquí se emite más fuerte para que se
-- oiga a distancia como en EFT, y casi nada al ir agachado o caminando lento.
function PLUGIN:PlayerFootstep(client, pos, foot, sound, volume, filter)
	local loud = ix.config.Get("efgFootstepLoudness", 1)
	if (loud <= 0) then return end

	-- en el cliente se silencia el paso por defecto: suena el que emite el servidor
	if (CLIENT) then return true end

	local speed = client:GetVelocity():Length2D()
	local level = client:Crouching() and 55 or (speed > 220 and 85 or (speed > 120 and 75 or 62))

	client:EmitSound(sound, math.floor(level * math.min(loud, 1.2)), math.random(95, 105), math.Clamp(volume * loud * 1.4, 0, 1))

	return true
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
