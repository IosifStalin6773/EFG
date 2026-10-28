-- Restaura la ocultación de identidad si el jugador llevaba el pasamontañas equipado al desconectarse.
function PLUGIN:PlayerLoadedCharacter(client, character)
	local items = character:GetInventory():GetItems()

	for _, item in pairs(items) do
		if (item.uniqueID == "pasamontanas" and item:GetData("equip")) then
			client:SetNetVar("faceHidden", true)

			return
		end
	end

	client:SetNetVar("faceHidden", false)
end
