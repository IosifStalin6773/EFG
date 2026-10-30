PLUGIN.name = "Simple Radio"
PLUGIN.author = "EFG Project" -- original: Hoooldini
PLUGIN.description = "Simple radios for Helix."

-- [[ GLOBAL VARIABLES ]] --

-- Optional color table for giving frequencies different colors.
local colorTable = {
	General = Color(255, 255, 85),
	Polis = Color(80, 180, 255),
	LR = Color(178, 34, 34),
    Reich = Color(70, 130, 180),
    Hanza = Color(255, 215, 0),
    Sindicato = Color(100, 255, 50)
}

-- Default radio color if none is provided or part of the table.
local RADIO_CHATCOLOR = Color(100, 255, 50)

-- Distancia (unidades) a la que se puede escuchar una radio ajena encendida en la misma frecuencia.
local RADIO_HEAR_RANGE = 300

-- Distancia (unidades) a la que se puede oír hablar directamente a quien usa la radio.
local RADIO_SPEAKER_HEAR_RANGE = 280

-- Color de la etiqueta "Radio:" / "X dice por radio:" que ven quienes escuchan sin tener su propia radio.
local RADIO_OVERHEAR_COLOR = Color(170, 170, 170)

-- [[ CHAT SETUP ]] --

--[[
	CHAT: Radio
	DESCRIPTION: Allows the user, provided they have an active radio,
	to broadcast messages to others on the same frequency. Because we
	are allowing users to be on, and speak over, multiple frequencies,
	we have to use this chat through the commands setup below.

	Adicionalmente, cualquier jugador que esté físicamente cerca de quien
	habla, o cerca de OTRO jugador con una radio encendida en la misma
	frecuencia, también puede escuchar la transmisión aunque él mismo no
	tenga radio. Quien ya tiene su propia radio encendida NO recibe estos
	mensajes "de reojo" (solo escucha lo que entra por su propia frecuencia)
	para no floodear su chat.

	Hay tres formas de recibir el mensaje, cada una con su propio formato:
	1. Por tu propia radio sintonizada: "[FACCION]: mensaje" (el canal
	   identifica la facción/frecuencia, pero no revela quién habla).
	2. Físicamente cerca de quien habla (sin radio propia): se le puede ver,
	   así que se aplica el reconocimiento normal de personajes -
	   "Nombre/Descripción dice por radio: mensaje".
	3. De reojo, cerca de la radio encendida de un tercero (sin radio propia
	   y sin ver a quien habla): "Radio: mensaje", completamente anónimo.
]]--

ix.chat.Register("radio", { -- Sets up and registers the radio chat.
	indicator = "chatTalking",
	CanHear = function(self, speaker, listener)
		if (!IsValid(speaker) or !IsValid(listener)) then
			return false
		end

		local speakerChar = speaker:GetCharacter()
		local listenerChar = listener:GetCharacter()

		if (!speakerChar or !listenerChar) then
			return false
		end

		local speakerRadio = speakerChar:GetData("RadioInfo")

		if (!speakerRadio) then
			return false
		end

		local listenerRadio = listenerChar:GetData("RadioInfo")

		if (listenerRadio) then -- Si ya tiene su propia radio, solo escucha si está sintonizado en la misma frecuencia (nunca "de reojo").
			return table.HasValue(listenerRadio.freqList, speakerRadio.lastFreq)
		end

		if (listener:GetPos():DistToSqr(speaker:GetPos()) <= (RADIO_SPEAKER_HEAR_RANGE * RADIO_SPEAKER_HEAR_RANGE)) then -- Sin radio propia, pero físicamente cerca de quien habla: se le oye/ve directamente.
			return true
		end

		for _, other in ipairs(player.GetAll()) do -- Si no tiene radio ni está cerca de quien habla, puede escuchar de reojo si está cerca de una radio ajena encendida en la misma frecuencia.
			if (IsValid(other) and other != listener and other != speaker) then
				local otherChar = other:GetCharacter()
				local otherRadio = otherChar and otherChar:GetData("RadioInfo")

				if (otherRadio and table.HasValue(otherRadio.freqList, speakerRadio.lastFreq)) then
					if (listener:GetPos():DistToSqr(other:GetPos()) <= (RADIO_HEAR_RANGE * RADIO_HEAR_RANGE)) then
						return true -- Basta con una radio cercana; el mensaje se manda una sola vez.
					end
				end
			end
		end

		return false
	end,
	CanSay = function(self, speaker, text)
		local speakerRadio = speaker:GetCharacter():GetData("RadioInfo")
		local canSpeak = false
		
		local character = speaker:GetCharacter()
		local radioInfo = character:GetData("RadioInfo")
		
		self.lastFreq = radioInfo.lastFreq

		if (speakerRadio) then -- If the speaker has RadioInfo set up, they have a radio and can speak.
			canSpeak = true
		end

		return canSpeak
	end,
	OnChatAdd = function(self, speaker, text, anonymous, info)
		local character = speaker:GetCharacter()

		if (!character) then
			return
		end

		if (speaker != LocalPlayer()) then
	        surface.PlaySound( "npc/metropolice/vo/off" .. math.random(1, 3) .. ".wav" )
	    end

		local localChar = LocalPlayer():GetCharacter()
		local ownRadio = localChar and localChar:GetData("RadioInfo")
		local isTunedIn = ownRadio and table.HasValue(ownRadio.freqList, info.channel)

		local freqColor = colorTable[info.channel] or self.color

		if (isTunedIn) then -- Por tu propia radio sintonizada: se indica la facción/frecuencia, pero la voz es anónima.
			chat.AddText(freqColor, "[" .. string.upper(info.channel) .. "]: " .. text)
			return
		end

		local nearSpeaker = LocalPlayer():GetPos():DistToSqr(speaker:GetPos()) <= (RADIO_SPEAKER_HEAR_RANGE * RADIO_SPEAKER_HEAR_RANGE)

		if (nearSpeaker) then -- Físicamente cerca de quien habla: se le puede ver, aplica reconocimiento normal.
			local name = character:GetName()

			if (localChar and !localChar:DoesRecognize(character)) then
				name = character:GetDescription()
			end

			chat.AddText(RADIO_OVERHEAR_COLOR, name .. " dice por radio: ", freqColor, text)
		else -- De reojo, cerca de la radio encendida de un tercero: no hay forma de identificar a quien habla.
			chat.AddText(RADIO_OVERHEAR_COLOR, "Radio: ", freqColor, text)
		end
	end
})

-- [[ COMMANDS ]] --

--[[
	NOTE: Radios, the way they are set up right now, may only have up to
	3 frequencies at a time. These frequencies are accessed through the
	commands below. Where /r would be the default frequency, /r1 would
	be additional channel 1, and /r2 would be additional channel 2.
]]

--[[
	COMMAND: /r
	DESCRIPTION: Broadcasts a message over the equipped radio's primary frequency.
]]--

ix.command.Add("r", {
	description = "Radio over your primary frequency.",
	superAdminOnly = false,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, client, text)
		local char = client:GetCharacter()
		local radioInfo = char:GetData("RadioInfo")

		if (radioInfo) then
			radioInfo.lastFreq = radioInfo.freqList[1]
			char:SetData("RadioInfo", radioInfo) 

			ix.chat.Send(client, "radio", text, false, nil, { channel = radioInfo.lastFreq })

			client:EmitSound("npc/metropolice/vo/on" .. math.random(1, 2) .. ".wav", math.random(50, 60), math.random(80, 120))
		end
	end
})

--[[
	COMMAND: /r1
	DESCRIPTION: Broadcasts a message over the equipped radio's first additional channel.
]]--

ix.command.Add("r1", {
	description = "Radio over additional channel 1.",
	superAdminOnly = false,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, client, text)
		local char = client:GetCharacter()
		local radioInfo = char:GetData("RadioInfo")

		if (radioInfo and #radioInfo.freqList > 1) then
			radioInfo.lastFreq = radioInfo.freqList[2]
			char:SetData("RadioInfo", radioInfo) 

			ix.chat.Send(client, "radio", text, false, nil, { channel = radioInfo.lastFreq })

			client:EmitSound("npc/metropolice/vo/on" .. math.random(1, 2) .. ".wav", math.random(50, 60), math.random(80, 120))
		end
	end
})

--[[
	COMMAND: /r2
	DESCRIPTION: Broadcasts a message over the equipped radio's second additional channel.
]]--

ix.command.Add("r2", {
	description = "Radio over additional channel 2.",
	superAdminOnly = false,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, client, text)
		local char = client:GetCharacter()
		local radioInfo = char:GetData("RadioInfo")

		if (radioInfo and #radioInfo.freqList > 2) then
			radioInfo.lastFreq = radioInfo.freqList[3]
			char:SetData("RadioInfo", radioInfo) 

			ix.chat.Send(client, "radio", text, false, nil, { channel = radioInfo.lastFreq })

			client:EmitSound("npc/metropolice/vo/on" .. math.random(1, 2) .. ".wav", math.random(50, 60), math.random(80, 120))
		end
	end
})

-- [[ FUNCTIONS ]] --

--[[
	FUNCTION: PLUGIN:HUDPaint()
	DESCRIPTION: Draws text in the top right. Code is nearly identical to the hud element
	from ZeMysticalTaco's radio plugin.
]]--

function PLUGIN:HUDPaint()
	local scrw = ScrW()
	local char = LocalPlayer():GetCharacter()

	if (char and char:GetData("RadioInfo")) then
		local freqList = char:GetData("RadioInfo").freqList
		draw.SimpleText("Frecuencias: " .. table.concat(freqList, ", "), "BudgetLabel", scrw - 50, 0, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT)
	end
end