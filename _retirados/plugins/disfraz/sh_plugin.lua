PLUGIN.name = "Disfraces"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Permite ocultar la identidad del jugador mediante prendas que cubren el rostro, como el pasamontañas."

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")

-- Mientras el rostro está cubierto, los sonidos de vocalización del jugador suenan más graves y amortiguados.
function PLUGIN:EntityEmitSound(data)
	local client = data.Entity

	if (IsValid(client) and client:IsPlayer() and client:GetNetVar("faceHidden", false)) then
		local soundName = data.SoundName:lower()

		if (soundName:find("vo/") or soundName:find("pain") or soundName:find("death") or soundName:find("breath") or soundName:find("drown")) then
			data.Pitch = math.max(50, data.Pitch - 15)

			return true
		end
	end
end
