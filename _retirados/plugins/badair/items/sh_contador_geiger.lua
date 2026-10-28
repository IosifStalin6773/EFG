ITEM.name = "Contador Geiger"
ITEM.weight = 0.5
ITEM.model = Model("models/lostsignalproject/items/devices/dosimeter.mdl")
ITEM.description = "Un dosímetro Geiger-Müller soviético, recubierto de cinta aislante. Detecta radiación ionizante en tiempo real. Pulsa G para leer tus niveles. También permite medir la radiación de cualquier persona frente a ti."
ITEM.category = "Equipamiento"
ITEM.width = 1
ITEM.height = 2
ITEM.noBusiness = false

-- Medir la radiación del jugador que tienes enfrente (trace server-side directo).
ITEM.functions.Medir = {
	OnRun = function(item)
		local client = item.player
		local tr = util.TraceLine({
			start = client:GetShootPos(),
			endpos = client:GetShootPos() + client:GetAimVector() * 200,
			filter = client,
			mask = MASK_SOLID,
		})

		if (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then
			local targetChar = tr.Entity:GetCharacter()
			if (targetChar) then
				netstream.Start(client, "badair_geigerResult", tr.Entity:Nick(), targetChar:GetRadiation())
			else
				client:Notify("Esta persona no tiene personaje activo.")
			end
		else
			client:Notify(L("geigerNoTarget", client))
		end
		return false
	end
}
