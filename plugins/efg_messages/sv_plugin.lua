local PLUGIN = PLUGIN

if (!SERVER) then return end

local MSG = ix.efg.messages

util.AddNetworkString("ixEFGMessagesOpen")
util.AddNetworkString("ixEFGHandbookOpen")
util.AddNetworkString("ixEFGMessageNew")

-- Guarda un mensaje en el personaje (los 60 últimos) y avisa si está conectado
function MSG.Send(character, from, text)
	if (!character) then return end

	local list = character:GetData("efgMessages", {})
	table.insert(list, 1, {from = from, text = text, time = os.time()})

	while (#list > 60) do table.remove(list) end

	character:SetData("efgMessages", list)

	local client = character:GetPlayer()

	if (IsValid(client)) then
		net.Start("ixEFGMessageNew")
			net.WriteString(from)
			net.WriteString(text)
		net.Send(client)
	end
end

function PLUGIN:OnMissionCompleted(client, character, mission)
	MSG.Send(character, mission and mission.giver or "Tareas", "Tarea completada: " .. (mission and (mission.name or mission.title) or "?"))
end

function PLUGIN:EFGInsuranceReturned(client, character, returned, lost)
	if (returned > 0) then MSG.Send(character, "Seguro", ("Te devolvemos %d objeto(s) asegurado(s). Están en tu alijo."):format(returned)) end
	if (lost > 0) then MSG.Send(character, "Seguro", ("No hemos recuperado %d objeto(s): alguien se los llevó."):format(lost)) end
end

function PLUGIN:EFGFleaSold(character, itemName, amount)
	MSG.Send(character, "Mercadillo", ("Has vendido %s por %s RUB."):format(itemName, string.Comma(amount)))
end
