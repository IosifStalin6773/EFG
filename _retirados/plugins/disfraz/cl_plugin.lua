function PLUGIN:GetCharacterName(client, chatType)
	if (client != LocalPlayer() and IsValid(client) and client:GetCharacter() and client:GetNetVar("faceHidden", false)) then
		return "Desconocido"
	end
end

function PLUGIN:GetCharacterDescription(client)
	if (client != LocalPlayer() and IsValid(client) and client:GetCharacter() and client:GetNetVar("faceHidden", false)) then
		return ""
	end
end
