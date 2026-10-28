local PLUGIN = PLUGIN

PLUGIN.name = "Bridas"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Sistema de inmovilización con bridas: atar, forcejear, forzar la atadura y liberar."

--[[ Declaración de Variables ]]--

ix.char.RegisterVar("tying", {
	field = "tying",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("sh_commands.lua")

-- ─── Bloqueo de correr/saltar para jugadores restringidos (componible) ─────
-- SetupMove corre en cliente y servidor para que la predicción coincida con
-- la autoridad. Usa SetMaxClientSpeed y quita IN_JUMP del comando en vez de
-- SetRunSpeed/SetJumpPower: guardar el valor "original" al esposar y
-- restaurarlo al soltar es frágil porque, si ese guardado llega a capturar un
-- valor ya corrompido (p. ej. por otro sistema pisando la misma caché, como
-- pasaba con la ralentización por radiación de badair), el jugador se queda
-- con el movimiento reducido para siempre. Bloqueando por input nunca se
-- toca el stat real, así que no hay nada que se pueda quedar "pegado".
local JUMP_POWER_DEFAULT = 200 -- gamemodes/base/gamemode/player_class/player_default.lua

hook.Add("SetupMove", "ixHandcuffs_speed", function(client, mv)
	if (SERVER and client:GetJumpPower() < 100 and not client:IsRestricted()) then
		-- Auto-repara a cualquiera que se quedara con el salto en 0 por el
		-- antiguo sistema de guardado/restaurado (ver comentario arriba).
		client:SetJumpPower(JUMP_POWER_DEFAULT)
	end

	if (not client:IsRestricted()) then return end

	mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), client:GetWalkSpeed()))
	mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
end)